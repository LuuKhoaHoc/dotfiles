---
name: gitlab-issue-workflow
description: Create GitLab issues via MCP tools with to-tickets format.
---

# GitLab Issue Workflow

Create well-structured issues on GitLab using the MCP toolset, following the `.dotfiles/agents/skills/to-tickets` ticket format.

## Prerequisites

- `mcp__gitlab__*` tools must be available (discover by category if needed)
- API doc files to attach should exist on disk or be uploaded first

## Process

### 1. Activate needed tools via discover_tools

Before creating milestones or listing milestone-scoped issues, activate the tool category:

```text
mcp__gitlab__discover_tools(category="milestones")
```

This adds: `list_milestones`, `create_milestone`, `edit_milestone`, `get_milestone_issue`, etc.

### 2. Upload reference docs (optional)

When an issue references a spec or API doc:

```text
mcp__gitlab__upload_markdown(project_id="<id>", file_path="<path>")
```

This returns a markdown link like `[file.md](/uploads/<hash>/file.md)` that can be embedded in issue descriptions.

**Fallback when `upload_markdown` fails** (e.g. MCP server error): upload via curl with the glab token. `glab api "projects/9/uploads" -f file=@...` returns `"file is invalid"` — use curl instead (never print the token):

```bash
TOKEN=$(python3 -c "import yaml; c=yaml.safe_load(open('$HOME/.config/glab-cli/config.yml')); print(c['hosts']['gitlab.vppos.vn']['token'])")
curl -sS -H "PRIVATE-TOKEN: $TOKEN" -F "file=@<path>" "https://gitlab.vppos.vn/api/v4/projects/9/uploads"
```

Response JSON has a `markdown` field — embed that link in the issue's References.

**Fallback khi `create_issue`/`create_merge_request` (tool_call MCP) fail `arguments is not valid JSON: Extra data`** — xảy ra với description dài/tiếng Việt/backtick, lặp lại cả khi đã lọc ký tự đặc biệt → đừng retry MCP, chuyển REST API qua script Python chạy bằng terminal (env có `GITLAB_TOKEN`; execute_code KHÔNG có user env):

```bash
# write_file /tmp/create-issue.py (description đọc từ /tmp/issue-description.md), rồi:
python3 /tmp/create-issue.py
```

Script: `POST https://gitlab.vppos.vn/api/v4/projects/9/issues` (hoặc `/merge_requests` với `source_branch`, `target_branch`, `remove_source_branch`), header `PRIVATE-TOKEN: $GITLAB_TOKEN`, body JSON `{ title, description, labels }`; in `iid` + `web_url`. Lưu ý: GitLab API dùng **`/api/v4`** — `/api/v1` là BE ERP nội bộ (Bruno), không phải GitLab.

### 3. Check existing milestones

```text
mcp__gitlab__list_milestones(project_id="<id>")
```

If the target milestone does not exist:

```text
mcp__gitlab__create_milestone(project_id="<id>", title="<name>", description="<scope>", start_date="...", due_date="...")
```

### 4. Create issues in dependency order

**Search for an existing issue first**: `list_issues(project_id, scope='all', state='all', search='<topic>')` — try both EN and VI keywords (e.g. `salary` and `bậc lương`). Reuse an open issue that already covers the change (update its description); only create a new one when nothing matches.

Publish issues **blockers first** so each subsequent issue can reference real IDs.

#### Issue structure (per to-tickets format)

```
## Parent (optional)

Reference to parent issue or milestone.

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective.

## Acceptance criteria

- [ ] Verifiable outcome 1
- [ ] Verifiable outcome 2

## Blocked by

- #<id> — <title> of blocking issue, or "None — can start immediately"

## References

- [file.md](/uploads/<hash>/file.md) — relevant section
```

**Rules:**
- Title format: `[<MODULE>] <Mô tả ngắn>` for Vietnamese projects
- Do NOT include exact file paths or code snippets — they go stale fast
- Exception: inline a state machine, schema, or type shape that encodes a decision more precisely than prose
- **Một feature audit / chuẩn hóa ra nhiều nhóm vi phạm → GỘP thành 1 issue umbrella** (user correction 2026-08-05, customers feature: 5 issue bị hỏi "tại sao tạo 5 issue" → gộp còn 2): 1 issue duy nhất với các mục đánh số (1. i18n, 2. constants, 3. FSD boundary, ...), acceptance criteria gộp theo mục, và ghi rõ "làm tuần tự, không chạy song song" vì các mục thường chồng file (cùng assignee + cùng feature). Chỉ tách issue riêng khi: (a) cần human/BE decision (`ready-for-human`, vd contract BE chưa chốt — tách hẳn khỏi việc agent làm được ngay), hoặc (b) khác assignee. Khi gộp: update 1 issue sẵn có làm umbrella (title + description thay thế toàn bộ), các issue còn lại xóa/đóng (xem pitfall delete-vs-close).
- **Follow-up issue cho case BE contract bị sót khi implement** (issue cũ đã đóng): tạo issue MỚI + link `relates_to` issue gốc, KHÔNG mở lại issue cũ. Xác minh rule chính xác trước khi viết — spec FE integration thường KHÔNG ghi đủ validation BE (vd. spec employee-documents không ghi `documentName` required/max 255 dù BE enforce). Nếu spec không có rule → hỏi user qua `clarify` (offer sẵn lựa chọn phổ biến: required + max 255/100, có regex...) thay vì đoán. Ghi rõ nguồn rule trong issue ("BE contract đã xác nhận: ...") + hiện trạng bug (payload vẫn gửi dữ liệu không hợp lệ) để dev hiểu lý do.

### 5. Assign to milestone + people

```text
mcp__gitlab__update_issue(
  project_id="<id>",
  issue_iid="<iid>",
  milestone_id="<milestone_id>",
  assignee_ids=[<user_id>]
)
```

Find user IDs via `mcp__gitlab__list_project_members(project_id="<id>")`.

Sau khi update milestone/assignee, verify lại bằng `get_issue` — response của `update_issue` rất slim (không echo `milestone`), dễ tưởng chưa set.

### 6. Update after creation

If format corrections are needed:

```text
mcp__gitlab__update_issue(
  project_id="<id>",
  issue_iid="<iid>",
  description="<full new description>"
)
```

Note: `update_issue` replaces the entire description — pass the complete new body.

**Thêm task vào issue user đang làm (user preference 2026-08-05):** khi user nói "thêm task vào issue X mà tôi đang làm luôn" — làm theo user kể cả khi scope khác issue gốc (user instruction thắng rule tạo-issue-mới). Cập nhật **description trực tiếp, không dùng note** (user preference): GET issue → lấy `description` → append section `---\n## Bổ sung task (YYYY-MM-DD): <tên>` (vấn đề + bằng chứng + fix + AC) → PUT toàn bộ description + mở rộng title nếu cần → verify bằng `get_issue`.

### 7. Link related issues + consolidated note

For independent-but-related issues (e.g. one per MFE of the same standardization effort), link them so each issue shows its siblings:

```text
mcp__gitlab__create_issue_link(
  project_id="9", issue_iid="<src>",
  target_project_id="9", target_issue_iid="<dst>",
  link_type="relates_to"   # or blocks / is_blocked_by
)
```

Create links for ALL pairs after every issue exists (no dependency on creation order). Then post ONE consolidated note on the biggest issue tagging the assignee — `@Username` in the body notifies them on GitLab. Note content: sibling issue list, suggested priority order (dead buttons/no-ops → migrate custom code → add new), reference components/patterns, and a "Đừng làm" section.

**User preference (erp-admin):** for cross-MFE work ("chuẩn hóa X cho mọi module") create ONE issue per MFE — even same assignee — so devs never touch the same files. Skip MFEs already compliant; report the skip to the user. (Overlaps with the `issue-to-tickets` skill's assignee-separation rule.)

### 8. Create the MR (issue-ship)

**User bắt buộc: tạo issue TRƯỚC khi ship; KHÔNG bao giờ push thẳng lên main** — ship = branch mới từ `origin/develop` + MR target `develop`, main chỉ nhận qua release flow. **KHÔNG dùng `Closes #<iid>` trong MR description — strict UAT lifecycle cho MỌI loại issue** (user correction 2026-08-05, "cho thống nhất flow"): xem bước 5.

Full flow từ tách worktree → implement → verify → rebase/conflict → merge: xem `references/worktree-implementation.md` (worked example #143, 2026-08-05 — gồm setup worktree an toàn với main clone dùng chung, DataTable server-side sorting technique, stale package dist pitfall, concurrent-refactor rebase).

1. Check for an existing open MR first: `list_merge_requests(project_id, state='opened')` — the user tends to create MR v2 instead of fixing v1; never ship a second MR for the same topic while one is open.
2. Base the branch on **fresh `origin/develop`** (see the stale-develop pitfall below).
3. Use the repo MR template `.gitlab/merge_request_templates/feature.md` (sections: 📝 Mô tả thay đổi (What) / 💡 Ngữ cảnh & Tài liệu liên quan (Why) with `**Issue / Ticket**: #<iid>` / 🛠️ Giải pháp & Kiến trúc / 🧪 Bằng chứng kiểm thử / ✅ Checklist cơ bản). Title: `feat(scope): <summary>`.
4. After creation, re-fetch the MR (`get_merge_request`) and confirm `detailed_merge_status: mergeable` (not `cannot_be_merged`) before reporting success — CI pipeline result comes later.
5. **Strict UAT lifecycle — NO `Closes #<iid>` trong MR description, cho MỌI loại issue** (user correction 2026-08-05, issue #134 / MR !545 — "Vẫn strict theo uat lifecycle, cho thống nhất flow"): `Closes #N` auto-close khi merge develop phá vỡ flow — issue phải sống đến prod deploy. Docs/convention issue cũng KHÔNG ngoại lệ. Thay vào đó:
   - MR description: `**Issue / Ticket**: #<iid>` (theo template) — đủ để GitLab hiển thị MR trong issue + CI job `issue:lifecycle:merge` tự set `status::done` sau khi merge.
   - Gắn milestone release tuần hiện tại (vd `v1.0.0`, id=2) cho **cả issue lẫn MR** (`update_issue` + `update_merge_request` với `milestone_id`) cho thống nhất flow.
   - Verify linkage từ phía ISSUE, không chỉ nhìn description:
   ```bash
   curl -sS -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "https://gitlab.vppos.vn/api/v4/projects/9/issues/<iid>/related_merge_requests"
   ```
   Shipping MR phải xuất hiện (GitLab ghi nhận relation). Issues bị nhắc ở nơi khác (vd case-study MR trong description issue) cũng hiện ở đây — informational, không phải close link. Verify thêm: description MR KHÔNG còn chuỗi `Closes #N`.
   - Tracking issue cho work đã ship sẵn qua MR đang mở: reference MR trong từng acceptance criterion (`— MR !NNN`) để checklist đọc như shipped-at-open; issue đóng chỉ sau prod deploy.

## Pitfalls

- ❌ Giả định spec file còn trên GitLab khi issue chỉ nhắc tên spec — nhiều issue ghi tên file nhưng KHÔNG upload (`/uploads/` link), và file local có thể đã bị dọn. Recovery từ session history: `session_search(query="<tên file>")` tìm session từng đính kèm, rồi scroll `session_search(session_id=..., around_message_id=<id message user>)` lấy nguyên văn nội dung (attachment nhúng đầy đủ vào message — nội dung dài bị truncate ở discovery view nhưng scroll về đúng message sẽ có đủ).
- ❌ `create_issue_link` thiếu `target_project_id` — bắt buộc kể cả khi link 2 issue cùng project; thiếu arg → tool không invoke, phải retry với đủ args.
- ❌ Creating issues in the wrong order (not blockers-first) — you won't know the blocking issue IDs yet
- ❌ Adding file paths or code snippets to descriptions — they go stale when the codebase evolves
- ❌ Forgetting `project_id` in get/update calls (easy to miss when batching)
- ❌ Listing milestones without activating the category first via `discover_tools`
- ❌ Assigning a milestone to a closed issue — verify the issue is open first
- ❌ Putting different assignees' work items in the same issue — create separate issues instead
- ❌ **Close issue bị superseded khi issue vừa tạo, chưa có lịch sử** (user correction 2026-08-05: "tại sao ko xóa luôn mà closed nó như đã được release") — close mang nghĩa "đã hoàn thành/released", gây hiểu nhầm trong tracker. Issue mới tạo (không comment/activity đáng giữ) bị thay thế → **DELETE thẳng**: `curl -X DELETE -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "https://gitlab.vppos.vn/api/v4/projects/9/issues/{iid}"` (trả 204; link `relates_to` tự biến mất). Chỉ close + note "Superseded" khi issue đã có lịch sử/được reference mà cần giữ vết.
- ❌ **`Closes #<iid>` trong MR description = auto-close sai lifecycle** (real correction, 2026-08-05): merge develop đóng issue ngay thay vì để `status::done` (UAT-ready, vẫn mở) → phá strict UAT flow, kể cả với docs/tracking issues. Chỉ giữ `**Issue / Ticket**: #<iid>` cho automation `issue:lifecycle:merge`; close xảy ra ở prod deploy.
- ❌ **Issue-shipping WIP from a STALE local `develop`** — if `git status` shows `[behind N]`, base the ship branch on fresh `origin/develop`: `git fetch origin` → `git checkout -b fix/<iid>-<slug> origin/develop`. Git carries uncommitted WIP across the switch when the dirty files are identical between branches (verify with `git status` after; helm image-tag commits are the usual diff). A branch based on stale local develop produces confusing MR diffs the moment the same files moved on origin, and shows as "behind" forever.
  - When dirty files DID move on origin (pre-check: `git diff <old-branch> origin/develop -- <dirty files>`), use the stash sequence: `git stash push -m "<desc>"` → `git checkout -b feat/<iid>-<slug> origin/develop` → `git stash pop`. The 3-way merge usually auto-resolves when your edits and origin's edits touch different regions; resolve manually if not. Then verify `git status` lists exactly your intended files and `git diff origin/develop --stat` shows ONLY them before committing.
  - The stash list is SHARED across worktrees of the same repo — after a successful pop, `git stash show -p stash@{0}` may show an unrelated older stash; verify your WIP via `git status`/`git diff`, not stash inspection.
- ❌ Shipping an issue whose working tree contains an EMPTIED test file (0B) — vitest hard-fails `No test suite found in file`; `git rm` the file as part of the fix commit.
- ❌ **Sửa `packages/*` rồi build MFE mà không rebuild package đó** (real case #143, 2026-08-05): MFE build resolve `@hilo/ui` từ **dist** chứ không phải source → `pnpm --filter sale typecheck` (tsc --noEmit) có thể PASS nhưng `pnpm --filter sale build` (tsc -b) FAIL với type cũ. Sau khi đụng packages: `pnpm --filter @hilo/ui build` (hoặc `pnpm build-infra`) TRƯỚC, rồi build MFE làm gate cuối. Xem `references/worktree-implementation.md`.
- ❌ **Committing on the WRONG branch when multiple sessions share the main clone** — the user's other Hermes session can switch `~/Projects/Hilo-Vppos/erp-admin` to another branch mid-task (real case: created `chore/issue-lifecycle-api-scan`, then the other session's git ops moved HEAD to `develop` → the commit landed on local develop, and `git push -u origin <feature>` silently created the remote feature branch at the OLD base). **Before commit AND before push: `git status -sb`** (branch + ahead/behind) and confirm HEAD. Post-hoc fix: `git branch -f <feature> <commit-sha>` (valid when the commit's parent == the branch tip), `git checkout develop && git reset --hard origin/develop` (after confirming the only delta is your stray commit), re-push the feature branch.
  - Corollary: if the pre-commit hook fails with `MODULE_NOT_FOUND` (e.g. `prettier/bin/prettier.cjs` — main clone node_modules can be incomplete), don't fight the environment: `git commit --no-verify` + `git push --no-verify`, then validate through the gates that DO apply to the changed files (GitLab CI Lint for `.gitlab-ci.yml`, `python3 -m py_compile` + functional run for `.py`, prettier from the review worktree's node_modules for yml). No TS/JS changed → `pnpm lint/typecheck/build` don't cover the change.
- ❌ **CI jobs scanning git history on GitLab runners (shallow-clone trap)** — runner fetches with `GIT_DEPTH=20` (see `Fetching changes with git depth set to 20` in the job trace), so `git log -n 30` windows are cut and MRs merged minutes earlier are invisible (real case: issue:lifecycle:merge found only the MR in `CI_COMMIT_MESSAGE`, missed !535/!537/!538/!541 though all 4 merge commits were within 20 commits locally). Use the GitLab API instead (`GET /merge_requests?state=merged&order_by=updated_at&sort=desc&per_page=50` + `merged_at` window). And when auto-marking issues done from MR descriptions: **skip `release`-labeled MRs** — release MRs embed issue-snapshot lists ("còn mở, không đưa vào phạm vi: #NNN") that falsely mark pending issues done (real case: MR !520 → #108/#109). Reference impl: `scripts/gitlab-update-milestone-issues.py` (jobs `issue:lifecycle:merge` / `issue:lifecycle:prod`, DRY_RUN gate).

## Project-specific conventions (erp-admin)

- **Labels available:** `crm`, `cks`, `finance`, `Shared`, `frontend`, `feature`, `chore`, `priority::medium`, `ready-for-agent`; MFE labels `HR`, `employee`, `hrm-settings`, `MFE::hr`, `MFE::shell`; work-type `Refactor`, `enhancement`, `bug`
  - Bộ label chuẩn cho issue HR feature: `HR, MFE::hr, feature, frontend, priority::medium, ready-for-agent`
- **Module prefixes:** `[Sale]`, `[Product]`, `[Finance]`, `[Shared]`, `[HR]`
- **Milestones:** `CRM Module v1` (id=1) — scope covers sales, product, finance, CKS features; **`v1.0.0` (id=2) — release milestone tuần này** (SemVer releases từ 2026-08-05, due thứ 5 hàng tuần; "đánh MR + issue vào milestone tuần này" = gắn milestone này cho cả issue lẫn MR qua `update_issue`/`update_merge_request`)
  - **Quyết định issue có thuộc milestone tuần này không** (worked example #130 → v1.0.0, 2026-08-05): (1) đọc policy trong milestone `description` (vd v1.0.0: "scope: issues `status::done` hoặc `in-progress` at planning time"); (2) check tiền lệ — issue CÙNG trạng thái (vd `status::review` + MR đã mở) đã nằm trong milestone chưa; nếu có → gắn cho nhất quán; (3) đối chiếu due date (rủi ro trượt nếu MR chưa merge kịp — nêu rõ cho user, gắn milestone không đảm bảo kịp); (4) gắn milestone cho CẢ issue lẫn MR liên quan (`update_issue` + `update_merge_request`), verify lại từ response API (response echo milestone title).
- **People:** luukhoahoc (id=8, Sale), cuongt (id=10, Finance), QuyCN (id=31, Product)
- **Project ID:** `9` (`vppos-team/erp-admin`)