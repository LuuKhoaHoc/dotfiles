---
name: verify-branch-without-checkout
description: "Use when verifying branch/MR tests without checkout."
tags: [git, branch, verification, mr-review, monorepo, pnpm, windows]
category: workflow
---

# Verify branch code without checkout

Use when you need to RUN the tests/lint/typecheck of a branch or MR head (e.g. verifying an MR review with real tool output) but the repo is a shared clone you must not checkout, and a worktree would need its own node_modules.

## Core pattern: overlay → verify → restore

```bash
cd <shared-clone>
B=origin/<branch>
# 1. Confirm diff is small/contained first
git diff <base_sha>...<head_sha> --name-only
# 2. Overlay each changed file from the branch head
git show $B:<path> > <path>
# 3. Run the narrowest real verification (test / eslint / tsc)
#    e.g. pnpm --filter @hilo/ui exec vitest run <new-test-file>
# 4. Restore existing files, delete branch-only (untracked) files
git checkout -- <path> ...
rm <new-untracked-file>
# 5. MUST end clean
git status -sb
```

## Rules

- Safe only when the diff is small AND overlaid files don't import other files that are also changed-but-not-overlaid. Check `--name-only` first; if the dependency graph is large, don't overlay — fall back to `git worktree add` + `pnpm install` (slow but correct).
- A new test file exists ONLY on the branch — overlay it too, then delete it after (it's untracked, `git checkout --` won't remove it).
- Never run a branch's new test against the base version of the component — it verifies nothing.
- Report what actually ran: test count, eslint exit, typecheck exit — plus confirmation the clone was restored clean.

## Scope-check habit (MR reviews)

`git log --oneline <base>...<head>` is the ground truth for an MR's scope. MR descriptions frequently document only ONE of several bundled concerns (UI fix + refactor + shared-package change). Flag stale descriptions, especially when the diff touches `packages/*` (shared boundary). `diverged_commits_count` from the GitLab API is NOT the branch's commit count — read `git log base...head`.

## Windows toolchain (this machine)

- The nvm4w `pnpm` shim fails in MSYS shells with `Cannot find module 'C:\c\nvm4w\...\corepack\dist\pnpm.js'` (path mangling). Working invocation — hermes bundled node's corepack (node v22 = repo pin):
  ```bash
  node "C:/Users/<user>/AppData/Local/hermes/node/node_modules/corepack/dist/corepack.js" pnpm <cmd>
  ```
- Pass Windows-style paths (`C:/...`) to node — MSYS paths (`/c/...`) get mangled into `C:\c\...`.
- nvm4w's `nvm use` requires an explicit version (`nvm use 22`), it does not read `.nvmrc`; if the wanted Node isn't installed, the hermes bundled node (v22, ships corepack) is a valid substitute.

## Related

- `gitlab-mr-review` (user-owned): diff-reading mechanics, MCP metadata, blast-radius checks — load it for MR reviews, this skill supplies the verification step.
- `monorepo-build-triage` (user-owned): build-failure triage loops.
