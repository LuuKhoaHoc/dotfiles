# Orchestrator batch run — dispatch prompt + post-run verification

Worked example: erp-admin MFE monorepo, 28 AGENTS.md files, 4 parallel subagents (2026-07-31).
Outcome: 18 files edited (60+/51− then prettier reflow), 10 verified OK untouched, commit `b20b685c` pushed to develop. All 16 spot-checked claims matched code.

## Dispatch prompt skeleton (per task)

Context block must contain:
- Repo path + branch + "working tree CLEAN — do NOT commit/branch, edit files in place".
- Mandatory per-file procedure: read → verify every claim with real code (file:line evidence) → patch only stale/wrong → preserve structure & language → no rewrite-from-scratch, no unverified additions.
- Source-of-truth priority: (1) real code, (2) `docs/solutions` + `docs/adr` (newest filename date wins; `replaces:` frontmatter supersedes), (3) real config (`package.json`, `vite.config.ts`, `pnpm-workspace.yaml`, `.nvmrc`, `lefthook.yml`).
- Known-stale hotspots (e.g. "apps/hr/AGENTS.md ~line 66 still calls `use*DataSource` canonical — superseded by `canonical-list-wiring-pattern-2026-07-27.md`").
- Off-limits files owned by other agents (prevents parallel-edit races on shared reads like root AGENTS.md).
- Forbidden: commit/push, code edits, .env, deleting AGENTS.md, creating new files.
- Report contract: 3-col table (File | đã sửa + lý do + bằng chứng file:line | Verified OK) + "uncertain, needs human review" list.

## Post-run verification commands (batch into 2 terminal calls)

```bash
git status --short && git diff --stat   # actual changes vs claimed union
git diff                                # full review of every edit

# spot-verify highest-risk claims:
grep -n "Page" apps/hr/src/App.tsx              # dead-vs-alive route triage
grep -n "MFE_LOADERS\|MFE_REMOTE_CONFIGS" apps/shell/src/registry/entries.tsx  # remote mount claims
ls apps/hr/src/features/                       # STRUCTURE tree claims
grep -n "shamefullyHoist" pnpm-workspace.yaml  # config-location claims
ls packages/ui/src/components/                 # folder-existence claims
grep -rn "MFE_STYLE_LOADERS" apps/shell/src --include="*.ts*"   # symbol-only-in-guide check (expect empty)
grep -n "exposes" apps/employee/vite.config.ts # expose-list claims
```

## Format + commit sequence

```bash
pnpm exec prettier --check $(git diff --name-only)   # expect 9/18 files misaligned after agent edits
pnpm exec prettier --write $(git diff --name-only)   # fix BEFORE commit → predictable diff
git add <dirs> && git commit -m "docs: refresh AGENTS.md files to match current codebase"
git push origin <branch>    # pre-push hook runs typecheck; budget minutes
```

## Lessons from the run

- The delegation file-mutation warning ("1 file(s) NOT modified" / "Found 2 matches for old_string") was a FALSE ALARM: the agent retried with more context and the file WAS edited (12 lines changed per `git diff --stat`). Check git diff, don't redo.
- Memory said `change-management` was a dead module; the agent found route `PATHS.HR_CHANGE_MANAGEMENT` → `ChangeManagementPage` at `apps/hr/src/App.tsx:71`. Code won; memory entry updated. Codebase facts in memory rot — re-verify before relying, especially when a subagent contradicts them with file:line evidence.
- 16/16 spot-checked claims verified correct → a strict dispatch prompt produces trustworthy edits; spend verification effort on claims that contradict memory or rewrite repo-wide statements (remote lists, canonical patterns, routes), not on every path fix.
