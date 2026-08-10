---
name: secret-leak-recovery
description: "Use when a secret was pushed to a remote or push rejected."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [security, git, secrets, leak, force-push, rotation]
---

# Secret Leak Recovery

Use when a real credential (API key, PAT, token) is committed and pushed to a remote — especially a **public** repo — or GitHub/GitLab secret scanning rejects a push. Also use BEFORE pushing anything that syncs configs (dotfiles, agent configs) to check for secrets.

## Golden rules

1. **Fix the SOURCE first, never the copy.** If the secret lives in a live config (e.g. `~/AppData/Local/hermes/config.yaml`, `~/.omp/agent/mcp.json`) that a sync script copies into the repo, redacting only the repo copy is pointless — the next sync overwrites it and republishes the secret. Replace the secret with an env-var reference (`${MY_API_KEY}`) in the source, put the real value in `.env` (gitignored), THEN sync.
2. **Never run a sync `push` as a verification step.** A verify script that calls `sync-*.sh push` commits+publishes whatever the source currently holds — that is exactly how a leak gets re-introduced. Verification must be state-only.
3. **A key already in old history cannot be un-leaked by deleting files.** Rewriting history removes it from the current tip, but scrapers may have it. ROTATE the key (generate a new one) whenever a real secret ever reached a public remote.

## Detection (strong patterns)

Weak patterns (e.g. `sk-[a-z0-9]{20}`) miss 16-char keys. Use:

```bash
grep -rniE 'glpat-[A-Za-z0-9]{8}|ctx7sk-[A-Za-z0-9]{8}|sk-[a-z0-9]{16}|ghp_[A-Za-z0-9]{8}|ntn_[A-Za-z0-9]{8}|figd_[A-Za-z0-9]{8}|squ_[A-Za-z0-9]{8}' \
  --include='*.md' --include='*.yml' --include='*.yaml' --include='*.json' --include='*.sh' --include='*.ts' --include='*.py' --include='*.toml' --include='*.lock' . \
  | grep -viE '<redacted>|sk-[x]{8,}'   # filter placeholders
```

Scan AFTER each sync (sync copies fresh secrets in) and check BOTH per-OS config files, not just the current OS's. Check what a commit actually contains with `git show <sha>:<path>`.

## Recovery when the leak already reached the remote

1. Identify the bad commits: `git log --oneline` + check each: `git show <sha>:<path> | grep <secret>`.
2. Fix the source + `.env` (golden rule 1). For dotfiles-style repos: sanitize `config.<os>.yaml` files too.
3. Reset to the last good commit: `git reset --soft <good-sha>` (keeps working tree), re-sync/re-commit a single clean commit.
4. `git push --force-with-lease origin <branch>` — ONLY safe on solo/single-user repos. If others may have cloned, warn first; rewriting published history breaks their clones.
5. Verify the remote tip is clean: `git fetch origin && git log origin/main --format='%h %s' -3`, plus the strong scan on the working tree, plus `git status` clean and `git rev-list --count origin/main..HEAD` = 0.
6. Tell the user to ROTATE the leaked key (it remains in old history; public repos get scraped within minutes).

## GitHub push protection rejection

If a push is rejected by secret scanning, the offending commit stays in local history. Squash it locally: `git reset --soft <good-commit> && git add -A && git commit -m ...`, then push again. Never retry the same push.

## Pitfalls

- **One-way sync scripts silently undo repo-side redactions** — see golden rule 1. Symptom: a key you replaced with `${VAR}` is back in the repo after the next sync run.
- **MSYS/git-bash quirks**: native Windows python3 can't read `/c/...` paths in sync scripts (run with `HOME="C:/Users/<user>"` or cygpath); `process substitution` (`<(cmd)`) fails in `diff` — write to a temp file instead.
- **`sed -i` on CRLF files** rewrites every line (diff balloons to N/N). Restore CRLF via python, and confirm the real change with `git diff --cached --ignore-space-at-eol`.
- **Force-push is not history cleanup** — `git push --force-with-lease` removes commits from the remote branch, but GitHub keeps unreachable objects briefly; treat any key that touched a public remote as compromised regardless.

## References

- `references/dotfiles-9router-leak-2026-08-07.md` — worked example: sync-verify loop republished a real key, reset+force-push recovery, per-OS config contamination.
