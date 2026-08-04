#!/usr/bin/env python3
"""
Verify i18n parity for a GitLab MR branch: enumerate EVERY t('...') key
referenced in the changed feature/app code and check it exists in BOTH en and vi
locale files. Nested-dict traversal (dotted grep is unreliable — see §6b/§7).

Real case: MR !527 (apps/finance receivables) — found ZERO missing keys across
~40 files / 200+ keys, proving parity clean. MR !514 would have caught 7 missing
placeholder keys this way.

Usage:
  python3 verify_i18n_keys.py <head_sha> <path1> [<path2> ...]
    path  = repo-relative dir or file to scan for t() keys (e.g. apps/finance/src/features/receivables)
  python3 verify_i18n_keys.py <head_sha> <path1> ... --ns=employee  # check one exact namespace file in en + vi
  python3 verify_i18n_keys.py <head_sha> <locale_dir> --en en --vi vi  # custom locale layout
    locale_dir default: packages/locales/src/translations

Notes:
  - Run inside a git worktree/clone with the MR branch fetched (git show <sha>:<path>).
  - BEST PRACTICE: pass ONLY the MR's changed .ts/.tsx files
    (git diff --name-only <base>...<head> | grep -E '\.(ts|tsx)$' | grep -v locales)
    — scanning whole feature dirs pulls test fixtures / PDF strings as false keys.
  - Two-arg t('key', 'fallback') forms are detected and reported SEPARATELY: they
    render the literal fallback (wrong-language text) instead of a raw key when
    missing, but are still convention violations (real case MR !529: 12 missing
    dashboard.filters.* keys with Vietnamese fallbacks slipped the single-arg check).
  - Keys are matched against EVERY locale file under the translations dir (both
    finance.json and common.json), so namespace-agnostic existence checks work
    even when components mix useTranslations('finance') and useTranslations('common').
  - Optional per-namespace mode: pass --ns finance to restrict the candidate set.
"""
import json
import re
import subprocess
import sys

T_KEY_RE = re.compile(r"""t\(\s*(['"])([^'"]+)\1\s*\)""")
# Two-arg form: t('key', 'literal fallback') — i18next defaultValue. Keys used this
# way must STILL exist in en+vi (missing -> wrong-language fallback text, not raw key).
T_KEY_DEFAULT_RE = re.compile(r"""t\(\s*(['"])([^'"]+)\1\s*,\s*(['"])([^'"]*)\3\s*\)""")
# Object form: t('key', { defaultValue: '...' }) — same wrong-language trap,
# different syntax. Missed by T_KEY_DEFAULT_RE (real case MR !531:
# directory.toolbar.clearSearch missing in en+vi, only caught manually).
T_KEY_DEFAULT_OBJ_RE = re.compile(r"""t\(\s*(['"])([^'"]+)\1\s*,\s*\{""")


def git_show(sha: str, path: str) -> str:
    proc = subprocess.run(
        ["git", "show", f"{sha}:{path}"], capture_output=True, text=True
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout


def nested_get(obj, dotted: str):
    cur = obj
    for part in dotted.split("."):
        if isinstance(cur, dict) and part in cur:
            cur = cur[part]
        else:
            return None
    return cur


def collect_keys(sha: str, paths, regex=T_KEY_RE):
    keys = set()
    for path in paths:
        if not (path.endswith(".ts") or path.endswith(".tsx")):
            continue
        content = git_show(sha, path)
        matches = regex.findall(content)
        for match in matches:
            # Single-arg regex returns (quote, key); the two-arg regex has
            # additional capture groups, so the key is still at index 1.
            keys.add(match[1] if isinstance(match, tuple) else match)
    return keys


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    if len(args) < 2:
        print(__doc__)
        sys.exit(2)
    sha, targets = args[0], args[1:]

    locale_dir = "packages/locales/src/translations"
    namespace = None
    for f in flags:
        if f.startswith("--locale-dir="):
            locale_dir = f.split("=", 1)[1]
        elif f.startswith("--ns="):
            namespace = f.split("=", 1)[1]

    # locate locale JSON files (en/vi subdirs)
    locale_files = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", sha, locale_dir],
        capture_output=True, text=True,
    ).stdout.split()
    json_files = [p for p in locale_files if p.endswith(".json")]
    if not json_files:
        print(f"WARN: no locale JSON found under {locale_dir} at {sha}")
        json_files = []

    if namespace:
        json_files = [p for p in json_files if p.rsplit("/", 1)[-1] == f"{namespace}.json"]
        if not json_files:
            print(f"ERROR: no locale JSON found for namespace '{namespace}' under {locale_dir}")
            sys.exit(2)

    locales = {}
    locales_by_language = {}
    for p in json_files:
        raw = git_show(sha, p)
        try:
            data = json.loads(raw)
            locales[p] = data
            parts = p.split("/")
            language = next((part for part in parts if part in {"en", "vi"}), "unknown")
            locales_by_language.setdefault(language, []).append(data)
        except json.JSONDecodeError as exc:
            print(f"WARN: could not parse {p}: {exc}")

    # collect keys from target paths (dirs -> list tree, files -> direct)
    scan_paths = []
    for t in targets:
        if t.endswith((".ts", ".tsx")):
            scan_paths.append(t)
        else:
            tree = subprocess.run(
                ["git", "ls-tree", "-r", "--name-only", sha, t],
                capture_output=True, text=True,
            ).stdout.split()
            scan_paths.extend(tree)
    keys = collect_keys(sha, scan_paths)
    keys_with_defaults = collect_keys(sha, scan_paths, regex=T_KEY_DEFAULT_RE)
    keys_with_obj_defaults = collect_keys(sha, scan_paths, regex=T_KEY_DEFAULT_OBJ_RE)

    def exists_for_language(language: str, key: str) -> bool:
        # With --ns=employee, this checks employee.json separately in en/vi.
        # Without --ns, the key may live in any namespace file for that language.
        return any(nested_get(d, key) is not None for d in locales_by_language.get(language, []))

    missing = {}
    for language in ("en", "vi"):
        miss = [k for k in sorted(keys) if not exists_for_language(language, k)]
        if miss:
            missing[language] = miss
    missing_defaults = sorted(
        k
        for k in keys_with_defaults
        if not all(exists_for_language(language, k) for language in ("en", "vi"))
    )
    missing_obj_defaults = sorted(
        k
        for k in keys_with_obj_defaults
        if not all(exists_for_language(language, k) for language in ("en", "vi"))
    )

    if missing_defaults:
        print(
            "KEYS USED WITH 2-ARG DEFAULTS BUT MISSING (render literal fallback instead of "
            "raw key — still a convention violation, wrong-language text in the other locale):"
        )
        for k in missing_defaults:
            print(f"  {k}")

    if missing_obj_defaults:
        print(
            "KEYS USED WITH OBJECT-FORM DEFAULT ({ defaultValue: ... }) BUT MISSING — "
            "same wrong-language fallback trap, object syntax:"
        )
        for k in missing_obj_defaults:
            print(f"  {k}")

    if missing:
        print("MISSING KEYS:")
        for lang_key, miss in sorted(missing.items()):
            print(f"  {lang_key}: {miss}")
        sys.exit(1)
    summary = f"OK: {len(keys)} unique t() keys all present in en + vi"
    if missing_defaults:
        summary += f"; {len(missing_defaults)} two-arg keys missing (listed above)"
    if missing_obj_defaults:
        summary += f"; {len(missing_obj_defaults)} object-form two-arg keys missing (listed above)"
    print(summary)


if __name__ == "__main__":
    main()
