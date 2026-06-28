---
name: pr-to-branch
description: Tạo MR/PR vào nhánh target bằng glab/gh, tự phát hiện platform, đọc template repo, sinh title và description từ git log.
---

# Workflow: Tạo MR/PR bằng glab/gh với title/description tự động

**Prerequisite:** Chạy `auto-push` trước: code committed + pushed.

## 1. Detect platform

```bash
git remote get-url origin
```

Parse output:

- Has `gitlab` or self-hosted GitLab → use `glab`
- Has `github.com` → use `gh`
- Both exist → prefer `glab`

## 2. Check CLI

```bash
which glab 2>/dev/null || which gh 2>/dev/null
```

Useful flags:

- `glab mr create`: `--title`, `--description`, `--source-branch`, `--target-branch`, `--draft`, `--label`, `--milestone`, `--assignee`, `--reviewer`, `--template`
- `gh pr create`: `--title`, `--body`, `--base`, `--head`, `--draft`, `--label`, `--assignee`, `--reviewer`, `--template`

Workflow defaults:

- Always assign MR/PR to current CLI user
- Always attach at least 1 label
- Ask user only if assignee/label cannot be resolved

Missing CLI:

- `glab`: https://gitlab.com/gitlab-org/cli#installation
- `gh`: https://cli.github.com/

## 3. Xác định target branch và source branch

```bash
git branch --show-current
```

Ask target branch. If absent:

- Detect from `.gitlab-ci.yml` or `CONTRIBUTING.md` if useful
- Fallback: `develop`

## 3.5. Resolve assignee và label mặc định

### Assignee

Goal: assign MR/PR to self.

**GitLab (`glab`):**

```bash
glab auth status
```

Get current username, pass `--assignee`.

**GitHub (`gh`):**

```bash
gh api user --jq .login
```

Get current login, pass `--assignee`.

If CLI cannot return username/login, ask user before create.

### Label

Goal: always attach label.

Priority:

1. User-provided label
2. Branch prefix label:
   - `feat/*` → `feature`
   - `fix/*` → `bug`
   - `refactor/*` → `refactor`
   - `docs/*` → `documentation`
   - `test/*` → `test`
   - `chore/*` → `chore`
   - `build/*` → `build`
   - `ci/*` → `ci`
   - `perf/*` → `performance`
   - `revert/*` → `revert`
3. Optional repo convention scope/team label: `hr`, `shell`, `shared`, `ui`

Before create, verify label exists. If inferred label missing, fallback to nearest generic repo label. If no valid label, ask user.

## 4. Sinh title và description từ git log

```bash
git log --pretty=format:"%s%n%b%n---" <target-branch>..HEAD
```

Title:

- 1 commit: use subject
- Many commits same type + scope: `type(scope): mô tả tổng quát`
- Mixed types: dominant type + summary
- Always conventional commits. No `[FEAT]`, `[FIX]`

Description:

1. Use commit body if useful
2. List changes:
   ```
   ## Changes
   - feat(scope): description
   - fix(scope): description
   ```
3. Merge with repo template in step 5

## 5. Đọc template MR/PR trong repo

**GitLab:**

```bash
ls .gitlab/merge_request_templates/ 2>/dev/null
```

Repo may have: `default.md`, `hotfix.md`.

**GitHub:**

```bash
ls .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || ls .github/pull_request_template.md 2>/dev/null
```

If template exists, ask choose or use `default`. Read + merge into description:

- Replace `## 📝 Mô tả` section with git-log changes
- Keep checklist
- Do not use both `--template` and `--description`
  - Want checklist kept: read template → merge → use `--description`
  - Want raw template only: use `--template`

> [!WARNING]
> **Windows & PowerShell Encoding Issue**:
> Trên Windows, PowerShell 5.1 mặc định sử dụng mã hóa hệ thống (ANSI/UTF-16) khi đọc file bằng `Get-Content`. Nếu file mô tả (ví dụ `mr-description.md`) chứa tiếng Việt hoặc biểu tượng cảm xúc (emoji), lệnh `Get-Content mr-description.md` sẽ bị lỗi hiển thị (Mojibake) trên GitLab/GitHub.
>
> **Giải pháp**: Luôn chỉ định mã hóa `-Encoding utf8` khi đọc file bằng `Get-Content` trong PowerShell và gán vào biến trước khi truyền:
> ```powershell
> $desc = Get-Content mr-description.md -Raw -Encoding utf8
> glab mr create --title "..." -d $desc
> ```

## 6. Tạo MR/PR

Required: pass self assignee + at least 1 valid label.

**GitLab (glab) — merged description:**

```bash
glab mr create \
  --title="<title>" \
  --description="<description>" \
  --source-branch="<source-branch>" \
  --target-branch="<target-branch>" \
  --assignee="<current-username>" \
  --label="<label1>" \
  <additional-flags>
```

**GitLab template direct:**

```bash
glab mr create \
  --title="<title>" \
  --source-branch="<source-branch>" \
  --target-branch="<target-branch>" \
  --assignee="<current-username>" \
  --label="<label1>" \
  --template="<template-name>" \
  <additional-flags>
```

**GitHub (gh):**

```bash
gh pr create \
  --title="<title>" \
  --body="<description>" \
  --base="<target-branch>" \
  --head="<source-branch>" \
  --assignee "<current-login>" \
  --label "<label1>" \
  <additional-flags>
```

Optional flags ask user:

- `--draft`
- `--reviewer`
- extra labels beyond default

## 7. Xác nhận và mở link

After create, confirm:

- assignee = self
- label attached correctly
- MR/PR URL created

If assignee/label missing, update via CLI/API before report done.

Then show URL. If browser needed:

```bash
glab mr view --web   # GitLab
gh pr view --web     # GitHub
```

## 8. Kiểm tra pipeline/CI

```bash
glab pipeline list  # GitLab
gh pr checks        # GitHub
```

CI runs: `lint`, `typecheck`, `trivy scan`. If fail, inspect logs + fix.
