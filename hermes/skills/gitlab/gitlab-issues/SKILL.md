---
name: gitlab-issues
description: "Create, update, triage, and manage GitLab issues via MCP GitLab tools."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitLab, Issues, Project-Management, Bug-Tracking, Triage]
    related_skills: ["github-issues"]
---

# GitLab Issues Management

Create, update, and manage GitLab issues using MCP GitLab tools. For GitHub issues, see `github-issues` skill instead.

## Prerequisites

- GitLab MCP server configured in `~/.hermes/config.yaml` with a valid token
- Target project accessible via MCP (e.g. `gitlab.vppos.vn`)
- Know the `project_id` or project path (e.g. `vppos-team/erp-admin` id=9)

## Core MCP Tools

| Action | MCP Tool | Key params |
|--------|----------|------------|
| Create issue | `mcp__gitlab__create_issue` | `project_id`, `title`, `description` |
| Add comment/note | `mcp__gitlab__create_issue_note` | `project_id`, `issue_iid`, `body` |
| Update issue | `mcp__gitlab__update_issue` | `project_id`, `issue_iid`, + any field |
| Patch description | `mcp__gitlab__update_issue_description_patch` | `project_id`, `issue_iid`, `patch_type`, `patch` |
| Get issue | `mcp__gitlab__get_issue` | `project_id`, `issue_iid` |
| List issues | `mcp__gitlab__list_issues` | `project_id`, filters |
| Close/reopen | `mcp__gitlab__update_issue` | `state_event: "close"/"reopen"` |
| Assign | `mcp__gitlab__update_issue` | `assignee_ids: [...]` |
| Add labels | `mcp__gitlab__create_label` or update issue | `labels: [...]` |

## Workflow: Code-Informed Issue Creation

When writing issues about code changes, bugs, or UI discrepancies:

1. **Explore codebase first** — don't guess file paths or column structures
   - `search_files` to find relevant files
   - `read_file` to read current implementations
   - `mcp__codegraph__codegraph_explore` for symbol-level exploration (if indexed)
2. **Verify branch** — `git branch --show-current` before auditing. Local checkout may differ from `develop`. Cross-check key files via `terminal cat` after analysis to confirm findings match the target branch.
3. **Upload reference documents** (if any) — Use `mcp__gitlab__upload_markdown` to upload API docs, specs, or design files. Collect the returned markdown links for embedding in issues.
4. **Compare current vs desired state** — write concrete diffs in the description
5. **Draft issues in dependency order** — sequence tickets so blockers come first. This lets each issue reference real IDs in its `## Blocked by`:
   - Start with issues that have no dependencies
   - Each subsequent issue can reference earlier issues' IDs
6. **Publish to GitLab in dependency order** — create issues one by one. Later issues can reference earlier issues' IDs in their `## Blocked by` section.
7. **Close completed blocker issues** — after all issues are created and a blocker issue is resolved (e.g. a shared-infrastructure task), use `mcp__gitlab__update_issue` with `state_event: "close"` to mark it done.
8. **Add tasks incrementally into the description body** (see Incremental Issue Building) — **not** via notes

## Issue Description Structure — erp-admin Templates

The erp-admin repo has canonical templates in `.gitlab/issue_templates/`:

| Template | File | When to use |
|----------|------|-------------|
| Feature Request | `.gitlab/issue_templates/feature_request.md` | New feature, enhancement, refactor |
| Bug Report | `.gitlab/issue_templates/bug_report.md` | Bug, regression, unexpected behaviour |

**Always start from these templates.** They define the canonical sections and ensure consistency across the team. The sections below document the conventions and label rules layered on top.

### Title convention

All issues must start with a `[MODULE]` prefix. Recognised modules:

`HR` / `Employee` / `Sale` / `Finance` / `Shell` / `Shared` / `Organization` / `UX` / `Refactor`

Example: `[HR] Gộp salary-fund-management và salary-management thành 1 feature salary`

**Never use commit-convention style (`fix(scope): ...`, `feat(hr): ...`) for issue titles** — that format belongs to commits/MRs. Real case: issue #118 was created as `fix(employee): Calculate leaveDays...` and had to be corrected to `[Employee] Sửa cách tính leaveDays theo startTime/endTime`. When asked to "sửa title/description cho đúng chuẩn" on an existing issue: rewrite title with `[MODULE]` + Vietnamese user-perspective summary, restructure description to the team format (What to build / Acceptance criteria / Blocked by / References), keep AC checkbox states (`[x]` for completed), and **verify referenced function/file names against the code before writing them** (`search_files`/`grep` — never guess; e.g. confirm the real mapper name exists in the repo).

**AC checkbox claims are NOT evidence — verify the claimed state against `origin/develop` and report drift in chat** (real case, issue #127): a self-authored WIP issue listed every item `[x]` ("Removed unused toolbarExtra dropdown filters…") but `git fetch origin develop` + `git grep origin/develop` showed the refactor nowhere — `SalaryFundListEnvelope`/`SalaryFundListPayload` still in `apis/salary-fund.ts:59-66`, `toolbarExtra` still in `SalaryGradesListView.tsx:398,473`, and `list_merge_requests(state=opened, search=<keyword>)` returned zero MRs. The issue described local/unmerged work as done. Protocol when standardizing: (1) `git fetch origin develop` first (local working tree may sit on another branch); (2) for each `[x]` item, check the claimed symbol/file state on `origin/develop` via `git grep`/`git show origin/develop:<path>`; (3) check for an open MR (title search + `list_issue_links`); (4) keep the checkbox states as the author wrote them (the issue is their tracker), but report the drift explicitly in the chat reply — "các thay đổi chưa có trên develop, chưa có MR — nhớ tạo branch + MR" — so the tracker doesn't silently claim done work that exists nowhere. Also verify assumed file locations: a hook can live outside the feature folder it's named after (e.g. `useSalaryGradeOptions.ts` actually lives in `apps/hr/src/features/employees/hooks/`, not `features/salary/hooks/`).

### Template sections (Feature Request)

| Section | Purpose |
|---------|---------|
| `✨ Feature Summary` | 1–2 sentence tóm tắt |
| `🎯 Problem / Motivation` | Vấn đề gì, tại sao cần |
| `💡 Proposed Solution` | Giải pháp đề xuất |
| `🔄 Alternatives Considered` | Cách khác và lý do chọn |
| `📦 Scope` | App/package, breaking change, effort |
| `✅ Acceptance Criteria` | Checklist công việc |
| `📎 Additional Context` | Design, link, ghi chú |
| `🔗 Blocked by` | Issue dependencies (see Rules below) |

### Template sections (Bug Report)

| Section | Purpose |
|---------|---------|
| `🐛 Bug Description` | Mô tả bug |
| `🔁 Steps to Reproduce` | Các bước reproduce |
| `✅ Expected Behavior` | Hành vi đúng |
| `❌ Actual Behavior` | Hành vi thực tế |
| `📸 Screenshots / Logs` | Ảnh chụp, log, stack trace |
| `🌍 Environment` | OS, browser, app, branch |
| `📎 Additional Context` | Workaround, link liên quan |
| `🔗 Blocked by` | Issue dependencies |

### Rules

- **`🔗 Blocked by`** — reference real issue IDs created in dependency order. Write `- #NNN` (bare reference, GitLab auto-links). If no blockers, delete the section or write "None".
- **Avoid specific file paths or code snippets in the issue body** — they go stale fast. Exception: API contract docs uploaded to the tracker (stable references).
- **User perspective first** — `✨ Feature Summary` and `🎯 Problem / Motivation` describe what the user sees, not implementation layers.

### Format B: Multi-Step Task Breakdown

Use when an issue contains multiple sub-tasks for the **same assignee**:

```markdown
## Mô tả
<1-2 sentence summary>

---

### Task N — <Title>

**Yêu cầu:**
- [ ] Action item 1
- [ ] Action item 2

**Files involved:**
- `path/to/file.tsx` — what changes needed

---

### Yêu cầu khác
> _Cập nhật thêm khi có yêu cầu mới_
```

### For UI discrepancy / inventory issues, include comparison tables:

```markdown
| Feature | Current | Reference |
|---------|---------|-----------|
| Columns | A, B, C | X, Y, Z |
| Widths | none | w-62, w-50 |
```

Also useful for codebase audits: helper inventory, call-site counts, out-of-scope rows (e.g. leave `HH:mm` / `formatTime` alone when standardizing dates).

## Incremental Issue Building (HARD RULE — user preference)

User often provides requirements in batches. **Always append into the issue `description` — never as a note/comment** unless the user explicitly wants a discussion thread.

Pattern:

1. Create issue with first batch of tasks in `description`
2. More requirements → `get_issue` → merge new `### Task N` → `update_issue(description=...)` or `update_issue_description_patch`
3. Each task block is self-contained: paths, checklists, acceptance, verification commands
4. `create_issue_note` is **only** for chatter/status — durable work lives in the description

## Task Status Tracking in Issue Descriptions

When updating issue descriptions after verification/review, mark each task's status clearly:

```markdown
### Task N — Task title

**⚠️ Chưa hoàn thành — reason/evidence found during code review**
**✅ Đã hoàn thành — verified on codebase**
**⏳ Đang chờ — not started yet**
```

Add brief evidence inline:
```markdown
**File hiện tại:** `path/to/file.tsx`
- Specific finding: what was found
- Specific finding: what was found

**Work:** (remaining work items if not complete)
- [ ] What still needs to be done
```

### Updating AC checklist

Update acceptance criteria in parallel — remove completed items, add verification notes:

```markdown
- [x] Tab "Chốt công" đã bị xóa ✅ Done
- [ ] Cột status/scope hiển thị tiếng Việt
```

Keep `[ ]` un-ticked for items that still need action. Mark `[x]` with `✅ Done` for completed items so the team can see progress at a glance.

### Assigning

1. `mcp__gitlab__get_users` with `usernames: ["cuongt"]` (Trần Cường id=10 on vppos)
2. `update_issue` with `assignee_ids: [<id>]`

### Labels (erp-admin)

`feature`, `bug`, `refactor`, `frontend`, `shell`, `shared`, `hr`, `employee`, `sale`, `finance`, `priority::*`, `status::todo`, `ready-for-agent`, `release`

## Board triage: status::done semantics (user-corrected)

When asked to review closed issues and move "chưa vào main" ones to `status::done` (board cleanup), the semantics are:

- `status::done` = **implementation finished**, NOT "released/merged to main".
- Issue **closed + merged into main** (or covered by a release MR) → keep closed, ensure `status::done`.
- Issue **closed but NOT merged into main / NOT mentioned in any release** → **REOPEN it and keep/add `status::done`**. It stays open until it actually ships to main. Do NOT leave it closed with only a label — user explicitly wants `open + status::done` so the board shows it as finished-but-unreleased work.

Verification procedure before moving anything:

1. Fetch closed issues: `list_issues(state=closed, scope=all, with_labels_details=true)` — persist + parse compactly (iid/title/labels).
2. Determine what actually reached main: `list_merge_requests(state=merged, target_branch=main)` + read the latest release MR description (release MRs list their issue snapshot — e.g. "Issue mới đã đóng: #102, #103..." and "còn mở, không đưa vào phạm vi deploy: #95..."). A feature MR into `develop` with `Closes #N` does NOT mean the issue reached main.
3. For closed issues with no `status::done`: merged → add label only; unmerged → `update_issue(state_event="reopen", labels=[...existing + "status::done"])`. When updating labels, pass the FULL existing label set plus the new one (update replaces the set).
4. Re-verify after updating: re-list and confirm counts (e.g. all closed+done now carry `status::done`; unmerged ones are open+done).

## Attaching Reference Files to Issues

When creating issues grounded in external reference documents (BE API docs, spec PDFs, design files, architecture notes):

1. **Upload each reference file** via `mcp__gitlab__upload_markdown(project_id, file_path)` — this uploads to GitLab's file system and returns a markdown link like `[file.md](/uploads/hash/file.md)`
2. **Collect all markdown links** before creating the issue so you can embed them immediately
3. **Embed links in the issue `description`** under a `## References` section at the bottom
4. **Create issues one per feature** — each with its own set of relevant reference links

Benefits over inline content:
- Issue stays concise and scannable
- Maintainers can click through to the full doc
- Multiple issues can share the same uploaded file reference
- File content is versioned on GitLab alongside the project

```markdown
## References

- [sales.md](/uploads/687731b05ed95bbf00fb5c2ccc7382e0/sales.md) — Order endpoints (section 5)
- [finance.md](/uploads/db0077ce1be026d683a81d4170171af1/finance.md) — Receivable (section 3)
```

**Pitfalls:**
- Upload files **first** (all at once), create issues second — you need the markdown links for the descriptions
- Files must exist on disk; desktop-attachment content from `@file:` annotations may not have been written to a real path. Always check `ls -la` before calling `upload_markdown`
- Use short, descriptive alt text so the link is readable in the issue body
- Group multiple refs under a single `## References` heading per issue

## Spec → FE issue (from BE API docs)

1. Upload reference doc files to GitLab first → collect markdown links
2. Scan erp-admin for existing related code (store, endpoints, UI, ADR)
3. **Before writing tasks: verify endpoint paths in `packages/shared/src/api/endpoints.ts`** and DTO fields in the MFE's `types/` folders — do not assume an endpoint or DTO field exists because a plan or report mentions it.
4. Gap table: Current FE vs Spec (include DTO field-name mismatches explicitly)
5. Field-mapping mismatches (e.g. REST `id`/`type` vs FE `notificationId`/`eventType`)
6. **Pagination / N+1 risk gate:** if a new sub-list (e.g. "direct reports", "dependents", "items") cannot be derived from the already-paginated client list, the issue must explicitly stop at "per-row API required" and **ask the user to choose a UI pattern** before rendering cells. Acceptable patterns: (A) cell button/badge → drawer/slide-over, (B) expandable row, (C) hover/click popover, (D) visible-only prefetch. Do NOT prescribe `Promise.all` per-row when pageSize can be ~100. Add the chosen pattern to Tasks + Acceptance.
7. Ordered tasks + acceptance + verify commands
8. Embed reference doc links in a `## References` section
9. Open questions for BA/BE in **one batch** (not one-at-a-time)

## Versioned API migration (v1 → v2) → FE issue pattern

When BE ships a NEW VERSION of endpoints the FE already calls (e.g. `?v2=true` switch,
or `/v2/...` path), the issue is a **gap migration**, not a greenfield build. Discipline:

1. **Read the current FE data plane end-to-end first** — for erp-admin dashboard-style features
   the chain is: `apis/` (dumb HTTP) → `utils/*-request-params.ts` (URL state → BE query) →
   `hooks/use*Queries.ts` (React Query) → `hooks/use*Controller.ts` + `components/`. Read the
   `constants/` (card keys, group maps, sort allow-lists, status sentinels) and `types/` DTOs too.
   Do NOT write tasks until you've read the real code — verify, never assume.
2. **Build a Gap table** with columns `| Aspect | FE hiện tại (v1) | Spec v2 | File |`. One row per
   changed dimension: request flag, enum/code set, key renames, group/category mapping, sort
   options, new response fields the FE must read, new UI toggles. Cite exact file:line.
3. **Split into numbered tasks that follow the data plane**, each self-contained with Files +
   checklist + which i18n keys to add. Typical order: (1) add version flag to request-param
   builders + types (and which endpoints must NOT get it), (2) rename/remap constants + group map,
   (3) sort options, (4) status/enum codes (watch for BE rejecting old-locale values → 400),
   (5) read new response fields, (6) icons/tones/labels, (7) new UI controls, (8) OPTIONAL column
   expansion (mark "confirm with BA" if DTO already has fields but product scope is unclear).
4. **Backward-compat gate:** if a new response field (e.g. `filters.cardKeys`) may be absent,
   the task must specify a fallback to current behavior — don't hard-require it.
5. **Out of scope must list endpoints that stay on v1** (e.g. notifications, stats-cards) so the
   implementer doesn't migrate them by reflex.
6. **i18n discipline:** every new enum value / sort option / label needs keys in BOTH
   `packages/locales/src/translations/vi/*.json` and `en/*.json`. Grep the existing `dashboard.*`
   / `status.*` namespace to confirm what already exists before listing keys to add.
7. Batch open questions for BA/BE at the end (field scope, whether BE always returns the new field,
   ordering source of truth).

## BE payroll/salary API spec → FE issue pattern

When the source of truth is a BE API doc/scalar report rather than an existing FE feature:

1. **Extract the contract, not just the endpoints.** Capture: base path, auth/role matrix, request/response DTOs, null/empty semantics, pagination shape, forbidden fields, error codes. Do not paste the whole report into description — summarize as FE-impactful rules only.
2. **Classify endpoints by FE surface.**
   - **New FE screens**: payroll management group CRUD, group member assignment, employee assignment by org/unit/ids → these usually need new feature folders or dialog shells.
   - **Existing FE extensions**: employee list/detail/create/update already call `/hr/employees`; new salary fields/`PATCH /hr/payroll/employees/{id}` must be mapped onto existing tabs/forms instead of creating parallel flows.
   - **Shell self-service impact**: if the new DTO exposes fields shown in `PersonalInformationDialog`, shell mapper/mutation/tabs must be updated too; keep shell logic shell-local.
3. **Map old vs new payload explicitly.** Example: payroll template assign often has old FE payload `{payrollTemplateId, employeeIds, scope}` but new BE wants `{payrollTemplateId, startDate}` with org/unit/employeeIds scoped differently. The issue must call out: reuse existing API wrapper vs rewrite payload.
4. **Issue body structure for this class:**
   - Scope: which MFE(s) and tabs/screens touch this.
   - Permission matrix from BE → who can view/edit what in FE.
   - New endpoints to implement.
   - Existing endpoints to extend (forms, schemas, list filters, detail DTO).
   - Shell/profile delta, if any.
   - Acceptance criteria split by surface: HR list/detail/form, shell profile, payroll template flow.
   - Out of scope: explicitly list fields/modules BE said are excluded (e.g. attendance, work location).
   - Verification: scalar steps or inline API checks.
5. **Files-section discipline:** only list files that actually need to change. Do not include files that merely *consume* a DTO unchanged. Use short paths relative to repo root.

### Pitfalls

- **Do not conflate group-management endpoints with employee-salary endpoints.** `POST /management-groups/{id}/hr-members` ≠ `PATCH /payroll/employees/{id}`. Separating them in the issue prevents mixed acceptance criteria.
- **Do not assume the employee detail API already returns new payroll fields.** BE may split `GET /hr/employees/{id}` and `GET /hr/payroll/employees/{id}`. The issue must state which call populates salary fields and whether detail view needs a second fetch or merged payload.
- **Template lookup is a separate flow from template assignment.** `GET /payroll/templates` and `GET /payroll/templates/employee/{id}/assigned` are read/search concerns; assignment is `POST` to `/employees/{id}/payroll-template` with BE-specific body.
- **Shell profile save must not send payroll-only fields unless BE allows it.** `PROFILE_UPDATE_FIELDS` may legitimately exclude `baseSalary`; if BE wants those editable only by HR through payroll endpoints, shell form must stop sending them.

## Replace client-side aggregation with BE endpoint → FE issue pattern

When BE ships a **new dedicated endpoint** that replaces client-side computation the FE already performs (e.g. FE currently filters/maps a list to derive stats, and BE now exposes pre-aggregated data):

1. **Read the current FE implementation end-to-end.** Understand what data is fetched vs what is computed client-side:
   - `hooks/use*Query.ts` — what endpoint/hook the FE currently calls
   - `components/*.tsx` — where the computation happens (useMemo, reduce, filter)
   - `types/*.ts` — the DTOs involved
   - `constants/*.ts` — card configs, key maps, i18n labels
   - `mock/` — mock data shapes that may need updating
2. **Build a field-mapping table.** BE field names often differ from existing FE card keys:

   | BE field | FE card key | i18n key | Action |
   |---|---|---|---|
   | `overtimeRequestsThisMonth` | `otThisMonth` | `requests.statistics.otThisMonth` | Map rename (config only) |
   | `totalRequestsThisMonth` | *(new)* | `requests.statistics.totalRequestsThisMonth` | Add card + i18n + layout |

3. **Classify each BE field into one of:**
   - **Direct map** — existing FE card key matches; update config to read from new DTO
   - **Rename map** — BE field differs from FE key; add mapping in component or hook
   - **New field** — no existing FE card; needs new card config, icon, i18n, and possibly grid layout change
   - **Dropped field** — existed in client-side computation but not in BE response; mark as removed
4. **Order tasks by data plane dependency:** endpoint → DTO → API function → hook → component → consumer page → i18n → constants → mock data
5. **Include grid layout consideration** — adding a new card may need `grid-cols-N` bump (e.g. `xl:grid-cols-4` → `xl:grid-cols-5`)
6. **Note the staleTime** — stats endpoints should refresh after mutations (create/approve/reject request). Set an appropriate `staleTime` (e.g. 30s) so the UI feels reactive without over-fetching.
7. **Mark the old hook/function for removal** — create a follow-up task to delete the obsolete client-side code after migration is verified.

## BE Spec → Issue Delivery Gate

Use this gate when a backend API spec or FE mapping document is being turned into one or more GitLab issues:

1. **Reconnaissance before drafting** — inspect the real target checkout (not the docs directory) for current endpoints, DTOs, API functions, mutation hooks, and UI callers. Record the current gap explicitly; do not repeat the spec as if the FE were greenfield. If CodeGraph is unavailable, fall back to `search_files`/`read_file` and continue with verifiable evidence. Classify the gap as **greenfield / gap-fill / migration** (e.g. API function exists but no hook/UI → gap-fill issue, worked example in `references/spec-to-issue-delivery.md` §1b).
2. **One vertical issue per scope/assignee** — keep separate issues when ownership or feature scope differs. Do not combine unrelated employee-management and attendance-sheet work merely because both came from one BE handoff.
3. **Upload references before creating issues** — obtain the GitLab markdown links first and embed them under `## References`; do not leave only a local `@file:` path. If the MCP upload operation fails because of server setup, use the tested REST fallback documented in `references/spec-to-issue-delivery.md`, keep the token out of output, parse the returned `markdown` field, and verify the upload response before proceeding.
4. **Duplicate gate** — search open and all issues using both English and Vietnamese/domain terms. A closed historical issue is not a blocker to creating a new issue, but an open issue with the same scope should be reused or escalated before creating another.
5. **Create only after the body is complete** — each issue should contain user-perspective outcome, exact API contract, current FE gap, acceptance criteria, out-of-scope rules, blockers, verification steps, and uploaded references. Explicitly preserve migration traps such as composite identifiers versus internal record UUIDs, idempotent success, and business-result unions like `blocked_by_issues`.
6. **Assign and verify** — verify assignee IDs via project members, create independent issues in parallel only after references and drafts are ready, then fetch each created issue to confirm title, open state, assignee, labels, description references, and sibling relation links.

See `references/spec-to-issue-delivery.md` for the reusable upload fallback and post-create verification checklist.

## MCP Failure Fallback

When GitLab MCP tools are unreachable (server down, auth expired, network issue):

1. **Do not retry endlessly** — 3+ consecutive MCP failures means the server is down. Switch strategy.
2. **Use `delegate_task` with curl** — spawn a leaf subagent that calls the GitLab REST API directly:
   - Base URL: `https://gitlab.vppos.vn/api/v4`
   - Auth: `PRIVATE-TOKEN` header from `~/.hermes/secrets/gitlab-pat`
   - Project path: `/projects/9` (erp-admin) or URL-encoded path `/projects/vppos-team%2Ferp-admin`
   - Include `title`, `description`, `labels`, `assignee_ids` as form data
   - The subagent runs in a free terminal (no security-consent blocking) and returns the issue URL/IID
3. **Verify the result** — the subagent returns a self-report; confirm by checking the returned IID or URL
4. **Template access fallback** — when `mcp__gitlab__get_file_contents` fails for `.gitlab/issue_templates/`, read the template from the local checkout at `~/Projects/Hilo-Vppos/erp-admin/.gitlab/issue_templates/`

## Pitfalls

- **Don't fabricate file paths or code details.** Explore codebase first. If codegraph isn't indexed, use `search_files` + `read_file`.
- **Find the real repo before exploring.** The Hermes session CWD for erp-admin work often points at the `Documents/ERP` spec/docs folder (only `.md`/`.csv`/`.xlsx`), NOT the code. The actual checkout is `~/Projects/Hilo-Vppos/erp-admin`. Symptom of wrong dir: `search_files` for a known symbol returns 0 hits. See `references/hilo-erp-projects.md` for exact paths, the `hr-dashboard` filter name, and the codegraph-init pitfall.
- **`project_id` vs `issue_iid`**: project numeric id (e.g. 9) vs issue number (e.g. 62).
- **Description, not notes:** User corrected "update description, not note" — notes bury tasks; description is source of truth.
- **Description patching:** small inserts → `update_issue_description_patch`; large multi-task rewrite → full `update_issue` description.
- **Wrong platform skill:** vppos erp-admin is GitLab MCP, not `github-issues`.
- **Cross-cutting UI audits:** state out-of-scope explicitly (e.g. time-only `HH:mm` / `formatTime` when converting dates to `dd/mm/yyyy`).
