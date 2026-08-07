---
name: branch-code-verification
description: Run branch tests without checkout (overlay, run, restore).
---

# Branch Code Verification (no-checkout overlay)

Use when you must RUN a branch's tests/lint/typecheck but the local clone sits on another branch (typically `develop`) and must not be disturbed (shared clone, worktree not set up, pnpm install too heavy for a fresh worktree).

## Recipe

```bash
B=origin/<branch>
git fetch origin <branch>
# overlay EVERY MR-changed file (see pitfall #1) with branch-head content:
git show $B:<path> > <path>
# run the focused checks:
node "C:/Users/luukhoahoc/AppData/Local/hermes/node/node_modules/corepack/dist/corepack.js" pnpm --filter @hilo/ui exec vitest run <test-file>
node "C:/Users/luukhoahoc/AppData/Local/hermes/node/node_modules/corepack/dist/corepack.js" pnpm --filter <app> exec eslint <files>
node "C:/Users/luukhoahoc/AppData/Local/hermes/node/node_modules/corepack/dist/corepack.js" pnpm --filter <app> typecheck
# restore immediately:
git checkout -- <overlaid paths>
rm <untracked test files>        # test files added by the branch don't exist on develop
git status -sb                   # MUST end clean
```

Untracked test files created by overlay are removed with `rm`; tracked files restored with `git checkout --`.

## Pitfalls

1. **Overlay ALL MR-changed files, not just the file under review.** Real case (MR !550): overlaying only `ProductCategoryDialog.tsx` while develop's `ProductCatalogView.tsx` still passed the old prop produced a FALSE typecheck error (`Property 'onAddTaxRate' does not exist`) — the branch itself was clean. Mixing develop's sibling files with branch-head files creates phantom errors. When a typecheck error appears after overlay, FIRST check you overlaid every file in the MR's changed list (or at least the whole feature set referencing the changed props).
2. **After the author rebases, `old_head...new_head` range diffs are contaminated** with the target branch's new commits (unrelated files appear). Isolate the author's fix with `git show <fix-commit>`; a changed `base_sha` in `get_merge_request` means rebase, not just a push.
3. **Windows pnpm shim is broken in git-bash** (corepack MSYS path mangling: `Cannot find module 'C:\c\nvm4w\nodejs\...'`; nvm4w ships only Node 24 while the repo pins Node 22 via `.nvmrc`). `nvm use` fails (no default version). Working invocation: Hermes' bundled Node 22 + its corepack, passed as a Windows-style path to avoid MSYS mangling — see Recipe. `node -v` check: hermes node = 22.x (correct), `/c/nvm4w/nodejs/node` = 24.x.
4. **Restore immediately after verifying** — the shared clone must end clean (`git status -sb` shows no changes, no untracked files).

## Verification ladder

- After restore: `git status -sb` clean → overlay was safe.
- If typecheck fails: re-verify overlay completeness (pitfall #1) before trusting the error.
- Report honestly in the review: what ran and passed (test count, eslint, tsc) vs what was skipped.
