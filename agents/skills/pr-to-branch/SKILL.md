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

Description (raw content for merging with template in step 5):

1. Use commit body if useful
2. List changes:
   ```
   - feat(scope): description
   - fix(scope): description
   ```

## 5. Đọc và sử dụng repo MR template (BẮT BUỘC)

> [!IMPORTANT]
> **Luôn ưu tiên dùng template có sẵn của repo.** Không bao giờ tạo MR với description freeform khi repo có template.

### 5.1. Phát hiện template

**GitLab:**

```bash
ls .gitlab/merge_request_templates/ 2>/dev/null
```

**GitHub:**

```bash
ls .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || ls .github/pull_request_template.md 2>/dev/null
```

Nếu không có template → skip step 5, dùng description freeform từ step 4.

### 5.2. Chọn template phù hợp

GitLab repos thường có nhiều template. Auto-chọn theo branch prefix:

| Branch prefix | Template ưu tiên | Fallback |
|---|---|---|
| `feat/*` | `feature.md` | `default.md` |
| `fix/*` | `bugfix.md` | `default.md` |
| `hotfix/*` | `hotfix.md` | `bugfix.md` → `default.md` |
| `refactor/*` | `refactor.md` | `default.md` |
| `release/*` | `release.md` | `default.md` |
| Khác | `default.md` | — |

Nếu template ưu tiên không tồn tại → dùng fallback. Nếu không có template nào match → ask user chọn.

### 5.3. Đọc template và merge

Đọc nội dung template đã chọn. Merge với content từ step 4:

1. **Giữ nguyên** các section checklist, verification, conventions của template (đánh dấu `[x]` nếu đã làm, `[ ]` nếu chưa)
2. **Thay thế** section mô tả (`## 📝 Mô tả` hoặc `## What`) bằng nội dung từ git log (step 4)
3. **Thêm** link Issue/Ticket nếu có (từ branch name hoặc user cung cấp)
4. **Giữ nguyên** các section UI/UX, Testing, Checklist — chỉ tick `[x]` cho các mục đã hoàn thành

> [!WARNING]
> **KHÔNG dùng `--template` flag của glab** — nó chỉ insert raw template mà không fill nội dung.
> **Luôn dùng `--description`** với merged content.

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
