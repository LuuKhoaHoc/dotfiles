#!/usr/bin/env python3
"""Diff two Hermes skill trees (source machine vs migrated target).

Why Python and not bash: on Windows git-bash/MSYS, `ls` output carries CRLF
which silently breaks `grep -qx` name comparisons, and backslash paths
mis-expand in globs. os.listdir + os.walk avoid all of that.

Usage:
    python verify_skills_sync.py <source_skills_root> <target_skills_root>
    python verify_skills_sync.py C:/path/to/linux-home/.hermes/skills C:/Users/<user>/AppData/Local/hermes/skills

Optional: pass a third root (canonical library, e.g. dotfiles agents/skills)
to also report skills that exist only on the target but not in the canonical
library (candidates for dedup / stale leftovers).
"""
import os
import sys


def top_level_dirs(root):
    if not os.path.isdir(root):
        print(f"  ! root not found: {root}")
        return set()
    return {d for d in os.listdir(root)
            if os.path.isdir(os.path.join(root, d)) and not d.startswith(".")}


def skillmd_count(root, name):
    base = os.path.join(root, name)
    return sum(1 for r, _, fs in os.walk(base) if "SKILL.md" in fs)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    src, tgt = sys.argv[1], sys.argv[2]
    extra = sys.argv[3] if len(sys.argv) > 3 else None

    src_dirs, tgt_dirs = top_level_dirs(src), top_level_dirs(tgt)
    print(f"source top-level: {len(src_dirs)}   target top-level: {len(tgt_dirs)}")
    print(f"source SKILL.md:  {sum(skillmd_count(src, d) for d in src_dirs)}"
          f"   target SKILL.md: {sum(skillmd_count(tgt, d) for d in tgt_dirs)}")

    missing = sorted(src_dirs - tgt_dirs)
    print(f"\n=== MISSING on target ({len(missing)}) ===")
    for d in missing:
        print(f"  {d}: {skillmd_count(src, d)} SKILL.md")

    only_tgt = sorted(tgt_dirs - src_dirs)
    print(f"\n=== ONLY on target ({len(only_tgt)}) ===")
    for d in only_tgt:
        print(f"  {d}: {skillmd_count(tgt, d)} SKILL.md")

    if extra:
        can = top_level_dirs(extra)
        stray = [d for d in only_tgt if d not in can]
        print(f"\n=== ONLY on target AND not in canonical library ({len(stray)}) ===")
        for d in sorted(stray):
            print(f"  {d}: {skillmd_count(tgt, d)} SKILL.md")

    print("\n" + ("OK: no missing skills" if not missing else
                  f"WARNING: {len(missing)} skills missing on target"))


if __name__ == "__main__":
    main()
