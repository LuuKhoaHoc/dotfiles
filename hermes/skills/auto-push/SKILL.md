---
name: auto-push
description: Kiểm tra git status, tách branch nếu cần, chia commit atomic theo conventional commits, commit và push lên remote.
---

# Workflow: Atomic Git Commit & Push

Dùng khi cần chuẩn bị code push lên remote.

## 1. Check trạng thái

```bash
// turbo
git status
// turbo
git diff --stat
// turbo
git branch --show-current
```

Identify:

- Staged/unstaged files
- Current branch base? (`main`, `develop`, `master`)
- Conflict or merge in progress?

## 2. Tạo branch mới nếu cần

```bash
// turbo
git fetch origin
// turbo
git checkout -b <type>/<short-description>
```

Branch naming:

- `feat/ten-tinh-nang`
- `fix/mo-ta-loi`
- `refactor/ten-refactor`
- `docs/ten-doc`
- `style/ten-style`
- `perf/ten-perf`
- `test/ten-test`
- `build/ten-build`
- `ci/ten-ci`
- `chore/ten-chore`
- `revert/ten-revert`

Skip if already on feature branch.

## 3. Chia thay đổi atomic pattern

View `git diff`, split by logical group:

- **feat**: add/modify feature
- **fix**: bug fix
- **refactor**: restructure, no behavior change
- **style**: format, whitespace, semicolon
- **docs**: docs, comments, README
- **test**: new/fix tests
- **build**: build config, deps
- **ci**: CI/CD config
- **chore**: routine task
- **perf**: optimize performance
- **revert**: revert prior commit

Use `git add -p` or `git add <file-path>` per group.

One commit = one purpose. Do not mix `feat` with `fix`.

## 4. Commit từng nhóm

```bash
git commit -m "<type>(<scope>): <description>"
```

Rules:

- Type: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- `scope` optional: `hr`, `shell`, `shared`, `ui`, `organizations`, `employees`
- Description lowercase, no trailing period
- Header max 120 chars
- Body if needed: explain "why", not restate "what"

Repo uses Lefthook:

- `pre-commit`: `lint-staged`
- `commit-msg`: `commitlint --edit`

Let hooks run. Fix if fail.

## 5. Check lại history

```bash
// turbo
git log --oneline -<n>
```

Confirm:

- Commits atomic
- No `WIP`, `tmp`, `fix`, `update` vague
- Messages conventional commits

If fix message or squash:

```bash
git rebase -i HEAD~<n>
```

## 6. Push lên remote

Pre-push hook runs `pnpm -r --parallel run typecheck`. Fail = fix then push again.

```bash
// turbo
git push origin <branch-name>
```

If pushed before + rebase:

```bash
// turbo
git push origin <branch-name> --force-with-lease
```

## 7. Tạo MR/PR nếu cần

After push, run `pr-to-branch` to auto-create MR/PR.

## 8. Check CI/CD

```bash
// turbo
glab pipeline list
```

CI runs: `lint`, `typecheck`, `trivy scan`. Fail = fix + push again.
