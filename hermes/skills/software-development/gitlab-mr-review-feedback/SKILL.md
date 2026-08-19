---
name: gitlab-mr-review-feedback
description: Class-level discipline for reviewing and publishing review feedback on GitLab merge requests via the GitLab MCP — verify against the MR branch (not local), post ONE consolidated comment, and write concrete file:line fixes with correct architectural placement. Use alongside pr-review when the target is a GitLab MR.
---

# GitLab MR Review Feedback

Companion to `pr-review` (the analysis lens). This skill governs the **verification + publishing + formatting discipline** specific to GitLab MRs reviewed through the GitLab MCP tools. Load it whenever you are asked to "review MR !NNN", "review this merge request", or post review feedback to GitLab.

## When to Use

- The user points you at a GitLab MR URL or `merge_request_iid` in project `vppos-team/erp-admin` (project_id `9`) or any GitLab project reachable via MCP.
- You will read diffs via `mcp__gitlab__get_merge_request_diffs` / `list_merge_request_changed_files` / `get_file_contents` and publish findings via `mcp__gitlab__create_merge_request_note`.

## Git Convention Checks (check before code review)

**Do not skip these — the user has explicitly corrected multiple reviews for missing them.** Check MR metadata before diving into code diffs. Add any violations as 🔴 blocking items in the consolidated comment.

### 1. MR title must follow conventional commits

Format: `type(scope): description`

Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

Watch for:
- `fix` used for new features (inline create, new banner, new state) → should be `feat`
- `[Module]` prefix instead of `type(scope)` → should be `feat(module):`
- Title too vague to understand what changed
- **Title under-describes scope** — title names 1 change while the MR ships 2–3 user-visible ones (real case MR !550: title "limit category dialog combobox dropdown height" but the MR also aligned field heights and relocated tax-rate creation into the combobox create-flow; description How section likewise omitted them). Count the MR's behavioral changes and require the title + How to name every one — release notes/audit read the title, and a "fix" title hiding a flow move misleads reviewers too. Same family as the description-template check: both are 🔴-level description hygiene per the rulebook.

### 2. Branch name must follow convention

Pattern: `type/short-description` (e.g. `feat/hr-search-date-filter`, `fix/leave-hours-calculation`)

Watch for:
- `hotfix/` used for non-urgent features — `hotfix/` is for production emergencies only
- `bugN` / `bug-*` as the entire branch — name must describe content (hard to trace later)

### 3. MR description must be filled in

The template has sections (What / Why / How / Testing / Screenshot). If any section still contains raw template text (`<!-- ... -->` comments or sample placeholders), flag it as blocking. For UI changes, screenshots are expected.

### 4. Scope must be focused

If the MR touches 90+ files or crosses multiple unrelated domains (e.g. payroll + search filter + leave calculation + error handling in one branch), flag as scope creep. Recommend splitting.

## Critical: Verify Against the MR Branch, Not Local

- **Always read changed files from the branch**: `mcp__gitlab__get_file_contents` with `ref=<mr-branch-name>` (e.g. `ref='hotfix/bug'`). Never assume a local `develop`/working-tree checkout matches the branch.
- **Why it matters (real incident):** A reviewer read the local `develop` copy of `leave-mappers.ts`, saw the old `Number(totalDays)` (no ×8), and posted "this file still uses the old path / inconsistent with the ×8 elsewhere". The branch had *already* been fixed to `Math.round(totalLeaveDays * 8)`. The false claim forced a public correction note and eroded trust.
- **`search_files` / `read_file` on the local clone are also unsafe for review** — they read the working tree (which may be on `develop` or any other branch), not the MR branch. Use them only for "does the symbol exist anywhere in the repo" questions. For "what does the MR's file X look like", always use `mcp__gitlab__get_file_contents ref=<branch>`. Real case MR !617: local develop still referenced `features.requestManagement.summary.*` (stale, from a previous MR that didn't clean up) — looked like dead-code leftovers in the diff, but the branch had already removed them. Wasted `get_file_contents` calls to confirm.
- **If you already posted a wrong note:** call `mcp__gitlab__delete_merge_request_note` on the bad note(s), then post the corrected comment. Do not leave a "review" + "correction" + "correction #2" trail.

## Run the test before posting any code-derived finding

A code-reading finding is a *hypothesis* until the test (or a runtime trace) confirms it. For MRs that ship new/modified tests in the branch (most FE MRs do), check out the branch into a worktree and run the focused test file before you post a 🔴. Real case MR !617: reading `useUrlState.setState` (in `packages/shared`) suggested the legacy-key strip wouldn't work because keys not in schema aren't deleted — but the function **rebuilds `newSearchParams = new URLSearchParams()` from scratch**, so undefined-merge values for non-schema keys are simply skipped (not preserved). The shipped spec passed 4/4. The wrong 🔴 would have been posted.

**Rule:** any finding whose root-cause argument depends on multi-function control flow, rebuild semantics, or a custom Zod/`useEffect`/merge quirk → run the test before posting. Use `mr-local-verification` (worktree + `pnpm --filter <pkg> exec vitest run <path>`). Findings grounded in direct, single-function reading (e.g. "this line is missing a null check", "this import is wrong") are safe to post without a test run.

**Cheap verification commands** (run them in this order, stop at first signal):
1. `pnpm --filter <pkg> exec vitest run <test-path>` — focused test of the new behavior
2. `pnpm --filter <pkg> typecheck` — does it even compile on the branch
3. `git show origin/<branch>:<file>` — verify the line you're flagging actually reads the way you think on the branch (cheap, no worktree needed)

## Publishing: ONE Consolidated Comment

- The user explicitly prefers **one clean comment**, not an edit history.
- Do not split findings across multiple notes.
- If you need to revise after posting: delete the old note(s) and repost a single corrected comment.
- Keep it scannable: 1–2 line intro → small set of issues (🔴/🟡) each with `file:line` + fix → one-line verdict.
- **Comment authorship**: Do NOT mention the agent or tool in the comment body (e.g. "Hermes Agent reviewed this"). The MCP creates the note under the authenticated user's name automatically — keep the text as if the reviewer wrote it directly. No preamble, no signature, no disclaimer.
- **@mention the MR author** (e.g. `@QuyCN`) at the top of every review/guidance note — the user's teammates act on review comments only when tagged (user explicitly asked "tag Quý vào giúp tôi"). One tag per note, at the intro line.
- **Report the note URL + WHICH MR in chat after posting**: `https://gitlab.vppos.vn/<project>/-/merge_requests/<iid>#note_<id>`. When the user says "sao tôi chưa thấy", verify via `mr_discussions` and hand them the direct note link — they are usually looking at the WRONG MR (two MRs under review at once is the norm) or a stale browser tab; do not assume the post failed.

## Concrete-Fix Standard (no vague advice)

Every issue MUST give the reader (often a teammate, e.g. Quý) something they can act on without guessing:

1. **File and location** — `apps/employee/src/features/.../leave-mappers.ts` — line `leaveDays: Math.round(totalLeaveDays * 8)`
2. **Problem** — what's wrong and why it matters (correctness / CI / consistency).
3. **Literal fix** — the exact code change.
4. **Architectural placement, justified** — state *where* the fix belongs and why:
   - A value used across MFEs (hours-per-day, status enums, shared keys) → put it in the **cross-project shared package** (`packages/shared`, exported via `packages/shared/src/index.ts`), NOT an MFE-local folder (`apps/hr/...`, `apps/employee/...`). A constant in one MFE is effectively not shared.
   - Don't just say "extract a constant" — say which file to add it to and that it must be imported from `@hilo/shared`.
5. **CI impact** — if the change flips existing test expectations (e.g. `×8` makes `expect(item.leaveDays).toBe(2)` fail → should be `16`), name the **test file + line** to update so CI doesn't go red.

## Readability Template for the Consolidated Comment (user preference, MR !529)

User explicitly asked to "re-write comment to make it more easy to understand" after the first draft; the structure below was approved and posted to MR !529 (one resolvable thread). Repeat it for every teammate review:

1. **Intro ≤ 2 lines** — tag `@author` + what's good + what blocks merge: *"@QuyCN review xong MR này 👍. Hướng chuẩn hoá rất đúng... Nhưng có 2 vấn đề lớn về filter ngày — cần fix trước khi merge."* Also state the verified basis: branch name + head sha (`head 39fa959a`).
2. **Per item, repeat this block shape**:
   - **1-line problem + blast radius** — e.g. "Filter khoảng ngày không hoạt động (silent no-op) — 7 màn"
   - **Location TABLE for multi-file issues** (screen × file:line) — tables scan far better than sentence lists; single-file issues get a bare `file:line` mention in prose
   - **Nguyên nhân (root cause) in ONE sentence** — teammates fix faster when they understand why (e.g. "zod tự động vứt key lạ, nên dates biến mất trước khi gọi HTTP")
   - **Literal fix code** + name a WORKING in-repo reference to copy from (`getEmployeeList` line, `TimeOffManagementFiltersPanel:99`) — close with "copy theo là được"
   - **⚠️ "Đừng làm X" callouts** for wrong fix directions — the user's teammates fix wrong when left to guess (e.g. "đừng sửa `sharedListQuerySchema` — dùng chung toàn bộ MFE", "đừng tăng pageSize lên 1000")
3. **📌 Tóm tắt at the end** — fix-before-merge list vs "sau đó" list, plus note that working references exist.
4. **Language**: Vietnamese for this team's MRs; code/identifiers stay English.
5. For **re-review rounds** the same template adapts: intro → per-item status table (✅ FIXED with file:line evidence / ❌ still open) → "đạt điều kiện merge về mặt code" verdict → list only the remaining items. Never re-litigate confirmed-fixed items; do NOT trust the fix commit's message — verify each flagged item independently at the new tip (see Post-Review Follow-Up).

## Verify Symbols Before Claiming

- Grep/verify a symbol is exported and used before claiming it's missing or duplicated (a false "this isn't exported" breaks the build and your credibility).
- Use `search_files` / `read_file` on the repo, and `get_file_contents` on the branch, to confirm.

## Tool Params (GitLab MCP)

- Use **snake_case**: `project_id` (`"9"` or `"vppos-team/erp-admin"`), `merge_request_iid`, `ref`, `file_path`, `note_id`.
- `list_merge_request_changed_files` returns `new_path`/`old_path`; diff hunks come from `get_merge_request_diffs`. Pass `view: "inline"` (or `"parallel"`) for diff rendering.
- Read a full file on the branch: `get_file_contents` with `ref=<branch>` and `file_path=<new_path>`. Required: `file_path` (or its alias `path`) — both the project path and the file path are required, `ref` defaults to the default branch if omitted.
- **`excluded_file_patterns` on `get_merge_request_diffs` is currently flaky** — passing `["^package-lock\\.json$", "\\.png$", "\\.svg$"]` can fail with `Invalid arguments: excluded_file_patterns.0: Expected string, received object` despite the schema declaring `items: string`. Workaround: omit the param, then post-filter the response client-side (`[c for c in changes if not re.match(r"^package-lock\\.json$|\\.png$|\\.svg$", c["new_path"])]`). The diff tool itself returns a manageable size for most MRs; the filter is a nice-to-have.

### Prefer MCP over `glab` CLI for review work

When the project is reachable via `mcp__gitlab__*` (this user's setup for `vppos-team/erp-admin`), prefer MCP tools for review workflow — `get_merge_request`, `list_merge_request_changed_files`, `get_merge_request_diffs`, `get_file_contents`, `mr_discussions`, `create_merge_request_note`, `approve_merge_request`, `merge_merge_request`. Two reasons `glab` CLI is the wrong first tool here:

1. **Stale token in `~/.config/glab-cli/config.yml`** — glab's per-host config file is NOT auto-updated when the user rotates the env var `GITLAB_PAT`. Result: `glab mr view` returns `401 Unauthorized` while the env token works fine. `git fetch` + `curl -H "PRIVATE-TOKEN: $GITLAB_PAT"` would work, but those don't have the same one-call ergonomics as MCP.
2. **No note-management** — `glab` cannot post review notes, set approval state, or merge with `should_remove_source_branch`. MCP is the only path that does it all.

**MCP tools loading quirk (this profile):** the `mcp__gitlab__*` tools are **deferred** — they don't appear in the active toolset, but they ARE reachable. Discovery + invoke pattern:
```python
tool_describe("mcp__gitlab__get_merge_request")   # load schema
tool_call(name="mcp__gitlab__get_merge_request", arguments={"project_id": "vppos-team/erp-admin", "merge_request_iid": "617"})
```
Direct `mcp__gitlab__*` invocations from a fresh turn can fail with "Tool does not exist" — that error means "load the schema via `tool_describe` first", not "the tool is gone". Once loaded in a turn, the same tool stays callable for that turn.

## Scope Confirmation Before Blocking Findings

When the author clarifies that a seemingly unrelated diff is intentional and in-scope (for example, enabling modules in a shared navigation registry), update the MR description and review assessment accordingly instead of retaining the stale blocking finding. Reframe it as an explicit scope item and mark it as accepted. Before changing an issue/MR description, verify the exact target; if issue search is ambiguous or returns no direct match, ask for the issue IID rather than guessing.

### Search wiring and status-gated actions

For list/table MRs, trace search end-to-end before approving: toolbar input → URL state → controller params → API request. Never accept `q` being stuffed into an identifier field such as `customerId` or `receivableId`; verify the BE contract for `q`/`search`, and if text search is unsupported, remove the search UI rather than shipping a misleading no-op.

For row workflow actions, inspect the full action list against the row status. `disabled` only prevents duplicate submission; it does not replace status gating. Confirm/reject/approve/record actions must be rendered only for statuses where the BE transition is valid (for example, payment receipt transitions only from `PENDING_CONFIRM`).

When reviewing a teammate's MR, post one consolidated note tagged with the actual author, with file/path evidence and concrete fix guidance. If the MR is self-authored, keep review findings in the MR description instead of posting a review note.

## Post-Review Follow-Up

After the review comment is posted, the author may push updates. Handle the lifecycle:

1. **Re-verify after push** — when the user says "check lại MR, vừa push lên": re-fetch the MR (`get_merge_request`), read the updated diffs, and verify each previous issue against the new branch state. Confirm fix or note remaining gaps in a reply to the original note (delete + repost the consolidated comment if the user prefers one clean thread). Also re-check the ORIGINAL items themselves: prior review claims can be false positives (real case: an i18n "double namespace" 🔴 that was actually fine — `ns:key` resolves explicitly in i18next, so the prefix is redundant, not broken). Verify each claim against the implementation (consuming hook + i18n config) before demanding a fix, and explicitly mark corrected items as ✅ in the new comment instead of silently dropping them — that documents the retraction and stops the author from "fixing" non-bugs.
   - **Check the fix commit's ACTUAL scope, not its message** — a commit titled `fix(...): address review feedback` / `restore missing ... translations` may only partially address the flagged list (real case MR !514 round 3: the commit added 2 of 7 missing i18n keys; 1 key stayed missing while 5 components still referenced it). Look at the commit's diff (`git show <sha> -- <files>`) to see which items it really touched, then re-enumerate EVERY flagged item against branch state — references via `git grep -n "searchPlaceholder" FETCH_HEAD -- <dirs>` + presence via nested locale traversal (a parent namespace object existing with unrelated keys does NOT mean the key exists). Report the remaining gap as still-open ❌ with fresh file:line evidence.
   - **First check `head_sha` actually changed.** If unchanged, the author did NOT push to this MR — and "vừa push lên" may refer to a *different* MR under review (real case: user was discussing MR !514 but the new push was on MR !512; the branch fetch showed the same tip). Before reporting "no changes", check metadata of every MR currently under review. Cheap confirmation: `git fetch origin <branch>` + `git rev-parse FETCH_HEAD` vs the MR `head_sha`.
   - **Watch `merge_status`** — when develop moves past the branch, the MR flips to `cannot_be_merged` (conflict) with zero code changes; tell the author to re-merge develop alongside the review status.
   - **Reply with a per-issue status table** (issue → ✅ FIXED with evidence `file:line` / ❌ still open), then offer to replace the old consolidated comment (delete + repost) so the thread stays one clean comment.

2. **Request changes / approve status transitions** — when the user asks to post the review "dạng request changes" (or to clear it after fixes):
   - **Request changes**: the REST endpoint `POST /projects/:id/merge_requests/:iid/request_changes` returned **404 even on GitLab 18.11.1-ee** — don't chase it; use the GraphQL mutation (works, verified on MR !535):
     ```bash
     curl -s "https://<host>/api/graphql" -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -H "Content-Type: application/json" \
       -d '{"query":"mutation { mergeRequestRequestChanges(input: { projectPath: \"<ns>/<proj>\", iid: \"<iid>\" }) { mergeRequest { state approved } errors } }"}'
     ```
     No `sha` arg — `MergeRequestRequestChangesInput` rejects it. Confirm `errors: []` and `approved: false`. The token lives in `~/AppData/Local/hermes/.env` as **`GITLAB_PAT`** (NOT `GITLAB_TOKEN` — not exported in the terminal env by default; source it with `export GITLAB_PAT=$(grep -oP '(?<=^GITLAB_PAT=).*' ~/AppData/Local/hermes/.env | tr -d '"')`).
   - **Clearing it / approving after a clean re-review**: `mcp__gitlab__approve_merge_request` — but ASK the user first; "changes requested" is often deliberately left on until the author resolves the threads.

3. **Merge + close issue** — when the user says "merge + kéo issue sang close":
   - Merge via `mcp__gitlab__merge_merge_request` (use `should_remove_source_branch: true`).
   - Find the corresponding issue by searching with `mcp__gitlab__list_issues` (search term matching the MR scope, or check MR description for issue reference).
   - Close the found issue via `mcp__gitlab__update_issue` with `state_event: 'close'`.

3. **Fix-guidance follow-up note** — when the user asks to add "hướng sửa đúng" for the author (e.g. "sợ ảnh sửa bậy bạ"), post ONE follow-up note with per-item instructions so the author doesn't guess: exact `file:line`, copy-paste code/JSON/TSX snippets (including suggested en+vi translations), and explicit **"do NOT do X"** warnings. Before telling them to wire a filter/param, verify the backend contract yourself — e.g. check the API `*ListParams` interface and the URL-state schema: if `fromDate`/`toDate` are absent from both, the correct fix is to REMOVE the dead props from the parent + child interfaces, not wire them (real case MR !514: org backend doesn't support date filtering, so the guidance was "bỏ dateRange, chỉ wire search `q`" with a copy-from `EmployeeListView.tsx` reference). Also warn about merge conflicts (develop moved → `cannot_be_merged`) so they rebase before pushing.

4. **Finding voided by business intent** — when the user says a flagged change was intentional (BA/QC requested it, e.g. a value-semantics formula swap like leaveDays), post a SHORT follow-up note marking that item void ("mục #4 bỏ qua — chủ ý BA/QC, không cần sửa", tag the author). Without it, the author "fixes" a requested behavior using your stale guidance. Related rule: before flagging a behavior/value change as a 🔴 regression, frame it as "confirm business intent" — a changed formula is often a product decision, not a bug.

## Anti-Patterns

| Don't | Do instead |
|-------|------------|
| Review against local `develop`/main | Read every changed file via `get_file_contents ref=<branch>` |
| Use `search_files` / `read_file` to verify a symbol's branch state | `mcp__gitlab__get_file_contents ref=<branch>` (local clone may be on a different branch) |
| Reach for `glab` CLI first | `mcp__gitlab__*` tools (deferred but reachable; `glab` config.yml has stale token) |
| Post a 🔴 derived from multi-function code reading without running the test | Check out the branch into a worktree and run the focused spec; cite the test output in the finding |
| Post review, then a correction, then another | Delete old note(s), post ONE corrected comment |
| "Extract a constant" / "make it configurable" | Give file:line + literal code + justify placement (shared pkg vs MFE-local) |
| Leave the reader to find the test that breaks | Name the test file + line that needs updating |
| Claim a symbol is missing without grepping | Verify export/usage first |
| Sign the comment with "Hermes Agent reviewed" | The MCP post appears under the user's name — keep it clean, no tool attribution |
| Skip git convention checks (title, branch, description) | Always check title type+scope, branch naming, and description completeness |
