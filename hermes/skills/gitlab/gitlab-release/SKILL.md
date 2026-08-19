---
name: gitlab-release
description: "Weekly GitLab release for erp-admin (SemVer vX.Y.Z): changelog from develop↔main, tag, release notes, release branch from main, MR into main."
version: 2.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitLab, Release, GitFlow, erp-admin, Merge-Request]
    related_skills: ["gitlab-issues"]
---

# GitLab Release Workflow (erp-admin / vppos)

Use for weekly releases on `gitlab.vppos.vn` project `vppos-team/erp-admin` (`project_id=9`).

**Naming convention — LUÔN verify thực tế trước khi tạo:** đọc `git ls-remote --tags origin` + `list_releases` (release gần nhất) để xem quy ước đang dùng, bám theo release trước đó. Thực tế đến 2026-08-04: team VẪN dùng `release/YYYY-MM-DD` cho CẢ branch lẫn tag (branch `release/2026-08-04` VÀ tag `release/2026-08-04`), Release name `Release YYYY-MM-DD`. **CHUYỂN SEMVER BẮT ĐẦU 2026-08-05:** user đã tạo milestone `v1.0.0` đầu tiên (release tuần 05→06/08, due thứ 5) và CI đã wire `release/v*` → build prod + deploy manual blocking (MR !541/!542) — từ đây branch/tag/milestone theo `vX.Y.Z` (`release/vX.Y.Z` / tag `vX.Y.Z` / milestone `vX.Y.Z` cùng tên), release đầu tiên từ CalVer là `v1.0.0`. VẪN verify thực tế trước mỗi release.

**Branch trùng tên tag → ambiguous refspec:** `git push origin release/2026-08-04` fail với `src refspec ... matches more than one` vì tag cùng tên tồn tại. Push luôn dùng refspec tường minh:
```bash
git push origin refs/heads/release/YYYY-MM-DD
git push origin refs/tags/release/YYYY-MM-DD
```
GitLab `create_release(tag_name=...)` không bị ảnh hưởng — API nhận tag name (chuỗi trùng tên branch vẫn OK).

**PROD deploy = pipeline MAIN (từ v1.0.3, case 2026-08-10):** release branch KHÔNG còn build/deploy (bỏ rule `release/v*` ở triggers + `.deploy_job`). Lý do: merge MR xóa source branch → pipeline release/v* chết giữa chừng (`fatal: couldn't find remote ref`) → `issue:lifecycle:prod` (post-deploy) không bao giờ chạy. Thiết kế mới:
- Merge `release/vX.Y.Z` → `main` → pipeline main: scan → triggers TỰ chạy (child build + `deploy:app` manual blocking `allow_failure: false`) → play deploy từng app → `issue:lifecycle:prod` (stage post-deploy, rule `$CI_COMMIT_BRANCH == "main"`) tự chạy → close issues milestone.
- Milestone suy từ `package.json` version trên main (`1.0.3` → `v1.0.3`), script `gitlab-update-milestone-issues.py` đã có fallback — KHÔNG cần set biến.
- Đừng quên push BOTH branch và tag khi retag: `git push origin refs/heads/release/vX.Y.Z` + `refs/tags/vX.Y.Z` (case 2026-08-10: chỉ push tag, branch lỡ thiếu commit disable CRM → MR head cũ).

## Authoritative flow (user-corrected)

**Do NOT** open MR `develop → main` as the release vehicle.

Correct sequence:

```text
develop: bump package.json version (SemVer policy, step 0) → commit
main ──checkout──> release/vX.Y.Z
                      ↑
                 merge origin/develop  (resolve conflicts here)
                      │
                      ├── tag vX.Y.Z (on release HEAD after merge)
                      ├── GitLab Release notes "Release vX.Y.Z — YYYY-MM-DD"
                      └── MR release/vX.Y.Z → main  (must be mergeable)
```

After main is merged: sync `main → develop` (separate step).

## Steps

### 0. Version bump policy (SemVer)

Bump root `package.json` version **trước khi tạo branch**, theo SemVer:

- Weekly release có feature mới → **MINOR** (`1.0.0 → 1.1.0`)
- Hotfix / bản chỉ sửa bug → **PATCH** (`1.1.0 → 1.1.1`)
- Breaking change (đổi API contract, DB migration, UI overhaul) → **MAJOR** (`2.0.0`)

Bump trên `develop` (commit type `chore(release): v1.1.0` — commitlint cho phép `chore`), release branch merge develop sẽ mang theo version mới; sau khi merge release → main, sync main → develop giữ đồng bộ.

```bash
git checkout develop && git pull
pnpm version --no-git-tag-version minor   # hoặc patch / major
git add package.json pnpm-lock.yaml && git commit -m "chore(release): v1.1.0"
git push origin develop
```

**Pitfall `pnpm git:release`:** script `git:release` (`git checkout -b release/v$(node -p "require('./package.json').version")`) tạo branch từ **current HEAD** — chạy từ develop sẽ tạo branch base develop (sai). Luôn tạo branch base `origin/main` tường minh (step 3). Script chỉ dùng được khi đã bump version xong VÀ đang đứng trên `origin/main`-based HEAD.

### 1. Collect changelog (develop vs main)

```text
mcp__gitlab__get_branch_diffs  from=main  to=develop  (exclude lockfiles)
mcp__gitlab__list_commits      ref_name=develop  (filter meaningful commits)
mcp__gitlab__list_commits      ref_name=main     (baseline)
```

Summarize by conventional commit type: Features / Bug Fixes / Refactors / Docs. Ignore pure `chore(*): update image tag` noise unless needed for deploy context.

**Large-result discipline:** `get_branch_diffs` and unbounded MR/issue lists can exceed the tool response limit. Treat persisted output as an input artifact: parse it with a small Python script and emit only compact fields (`iid`, `title`, state, timestamps, URLs, labels). Use first-parent commits plus merged MR titles for the human changelog. Do not paste raw 400KB responses into context. See `references/release-aggregation-and-tag-verification.md`.

**Release-window accounting:** use the previous release's actual `released_at` as the lower bound, not an arbitrary midnight. For MRs, filter on `merged_at`; exclude the previous release MR itself and image-tag-only commits. For issues, report separately: (a) issues created in window and their current state, and (b) older issues closed in window. Never describe the second group as new release scope.

**`list_merge_requests` windowing pitfall:** the MCP tool has NO `merged_after` param (passing one is silently ignored) and `sort=asc` returns the OLDEST MRs first — querying with `sort=desc, per_page=100, state=merged` and filtering client-side on `merged_at` is the reliable pattern. The 100+ MR payload exceeds the tool response limit and gets persisted to a file: parse with a small Python script (json.loads of the `result` string) and print only `iid / merged_at / source_branch / target_branch / labels / title`.

**"Release này có đụng API/feature X không?" — investigation (case 2026-08-04, Chốt công lỗi):** dùng git log theo window release + per-file:
```bash
git log --oneline <tag-release-trước>..<origin/release-YYYY-MM-DD> -- <dir-feature>   # window có đụng feature không
git show --stat <sha> | grep <file-cụ-thể>                                            # commit đó đụng file nào
git log --oneline <tag-release-trước>..<release> -- <file-lock-cụ-thể>                # trống = KHÔNG bị đụng
```
Kết luận KHÔNG đụng ≠ không lỗi: **BE có thể đổi contract độc lập** — case thật: lock attendance fail `HRM-400-1490 Attendance sheet ID is required` vì BE bắt buộc `attendanceSheetId` composite `{orgId}:{year}:{month}:{unitId}` (bỏ `lockYear`/`lockMonth`), FE vẫn gửi payload cũ. Check docs mapping trong `~/Projects/Hilo-Vppos/Documents/ERP/.hermes/desktop-attachments/` (vd `attendance-sheet-lock-unlock-fe-mapping.md`) trước khi kết luận regression FE. Unlock cũng đổi: dùng `attendanceSheetId` encode trên URL, không phải `data.id`/periodLockId.

### 2. Activate release MCP tools if missing

```text
mcp__gitlab__discover_tools category=releases
mcp__gitlab__discover_tools category=tags
```

### 3. Create release branch FROM main

Remote:

```text
mcp__gitlab__create_branch  branch=release/vX.Y.Z  ref=main  project_id=9
```

Local (when repo available, e.g. `/home/luukhoahoc/Projects/Hilo-Vppos/erp-admin`):

```bash
git fetch origin
# stash WIP on develop if dirty
git checkout -b release/vX.Y.Z origin/main   # LUÔN base origin/main, không phải develop
git merge origin/develop --no-edit
# resolve conflicts (often only helm/frontend/values-*.yaml image tags → take develop/theirs)
git add -A && git commit --no-edit   # if merge commit needed
git push -u origin release/vX.Y.Z
```

Verify branch tip is **not** accidentally develop-only before merge.

### 4. Tag + GitLab Release

**Pitfall:** branch `release/vX.Y.Z` và tag `vX.Y.Z` là hai tên khác nhau — không còn collision như thời `release/YYYY-MM-DD`, nhưng đừng đặt tag trùng tên branch.

```bash
# create/push TAG explicitly
git tag vX.Y.Z <release-head-sha>
git push origin refs/tags/vX.Y.Z

# push BRANCH explicitly if needed
git push origin refs/heads/release/vX.Y.Z
```

If a tag was created too early on develop HEAD before release-branch merge, delete and recreate on correct SHA:

```bash
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
# then retag on release HEAD
```

**Stale tag thiếu fix mới (case 2026-08-04):** khi fix được cherry-pick lên release branch SAU khi tag đã được tạo, tag remote vẫn trỏ commit cũ → Release record sẽ gắn artifact thiếu fix. Trước `create_release`, verify peeled SHA của tag == HEAD release branch:

```bash
git ls-remote origin refs/tags/release/2026-08-04^{}   # peeled commit
git rev-parse origin/release/2026-08-04                # HEAD release branch
```

Lệch → xóa tag cũ (local + remote), tạo lại annotated tag trên HEAD release, push, verify lại rồi mới tạo Release. Tag cũ thường là lightweight (`git cat-file -t` = `commit`); tag release mới nên là annotated (`tag`).

**MR description = nguồn duy nhất của release description:** team soạn sẵn description đầy đủ trong MR release (`chore(release): release YYYY-MM-DD`). Dùng ĐÚNG description đó cho `create_release`, rồi nếu có thay đổi sau (fix build mới, retag SHA) → `update_merge_request` description song song để MR và Release record khớp nhau. Format chuẩn: `references/release-description-format.md`.

MCP: `create_tag` then `create_release` (or update release description if 409 already exists). Release name: `Release vX.Y.Z — YYYY-MM-DD` (giữ ngày trong tên/nội dung để tra cứu theo thời gian vẫn được) — thực tế 2026-08: `Release 2026-08-04`.

**GẮN MILESTONE vào release record (bắt buộc, user-corrected 2026-08-15):** khi tạo release PHẢI kèm `milestones: [<tên milestone>]` (vd `["v1.0.4"]`) — convention team từ v1.0.0 (vd release v1.0.0 → milestone v1.0.0). Release record không milestone = thiếu.

**Pitfall: retag (xóa tag) → GitLab XÓA LUÔN release record** (case v1.0.4, 2026-08-15): `git push origin :refs/tags/v1.0.4` khi retag khiến release record gắn với tag đó biến mất. Sau retag PHẢI tạo LẠI release từ đầu (không chỉ update). Pattern đã chạy được (token hiện tại PUT /releases bị 403):
```bash
# body JSON (description + milestones) — dùng python json.dumps để escape description
glab api projects/9/releases --method POST --header "Content-Type: application/json" --input /tmp/release-body.json
# glab --field "milestones[]=..." KHÔNG nạp array; --input + header mới ăn milestones
```
Nếu POST trả 409 (release đã tồn tại) → `glab api projects/9/releases/v1.0.4 --method DELETE` rồi POST lại.

Release Evidence JSON on the Releases page is normal GitLab auto-snapshot — not an error.

### 5. MR release → main

**UAT promotion gate:** After the fix MR into `develop` is merged, keep the release MR open until `develop` has actually deployed to UAT and the user-facing scope has an explicit UAT-pass confirmation. A green MR/CI pipeline proves build and automated checks only; it does not prove UAT deployment or runtime behavior. Merge the release MR into `main` only after UAT passes, unless the user explicitly accepts an emergency bypass.

For frontend/API changes, UAT should cover the actual user contract: responsive table behavior, new labels in every supported locale, validation behavior, download/blob response handling, and the endpoint's real authentication mode (cookie credentials vs bearer header).

For a narrow hotfix, a release branch from `origin/main` with only the exact fix commits cherry-picked is valid. Verify its diff excludes unrelated `develop` commits, especially automated image-tag chores.

```text
mcp__gitlab__create_merge_request
  source_branch=release/vX.Y.Z
  target_branch=main
  title=Release vX.Y.Z → main
  labels=["release"]
```

Wait until `merge_status=can_be_merged` / `detailed_merge_status=mergeable`. Close mistaken `develop→main` MRs.

MR description: structured release notes (ghi cả ngày phát hành) + checklist (review, pipeline, merge, sync main→develop).

### 5-pre. "Should X go into today's release?" — scope-decision protocol (case 2026-08-04, MR !536)

When the user asks whether an OPEN MR should be added to a release that is already being
finalized (tag pushed, release MR open):

1. **Read the release MR description FIRST** — the `chore(release): ...` MR → main is the
   locked scope and normally carries an "Issue snapshot" section that names what was
   deliberately EXCLUDED and why (real case: BA excluded #123 employee filters/!531 and #124
   sale filters/!535 as "còn mở — sẽ release sau"). The decision may already exist; don't
   reverse it without a new requirement.
2. **Score with 4 criteria**: (a) MR merged into develop yet? (no → must merge it, then merge
   develop into the release branch, dragging image-tag chores along); (b) real UAT done? (unit
   tests + typecheck ≠ UAT — §5 gate); (c) size — a multi-screen UI feature is not a hotfix;
   (d) urgency — feature consistency is not a prod blocker.
3. **If it must go in**: the pushed tag is now stale → retag on the new release HEAD (§4
   stale-tag recipe) + update release description so MR and Release record stay in sync.
4. **Default answer for a finalized release: no** — merge the MR into develop normally, let it
   soak one UAT cycle, release next week.

### 5a. Prod release prep: disable CRM modules (team convention — "như mọi lần")

Khi release đưa develop mới nhất lên main mà CRM chưa hoàn thiện: **code CRM vẫn ship lên main, nhưng module ẩn trên prod**.

- File: `packages/shared/src/config/navigation.ts` — set `enabled: false` cho `sale`, `product`, `finance` (chỉ 3 module CRM; `hr`/`employee`/`apps-dashboard` giữ `enabled: true`).
- Commit riêng trên **release branch** (KHÔNG lên develop — develop giữ `enabled: true`): `chore(release): disable CRM modules for production`.
- Ghi rõ trong MR description: modules bị `enabled: false` trên release branch, code vẫn nằm trong main, sẽ bật lại khi CRM sẵn sàng.
- Verify: `pnpm --filter @hilo/shared typecheck` + `eslint src/config/navigation.ts` (đủ scope cho thay đổi config); pre-push hook typecheck toàn repo khi push.

### 5b. Hotfix release variant (single fix bug → main, fix MR chưa merge)

Khi user muốn ship 1 bundle bug fix lên prod trong khi MR fix → develop vẫn mở ("tạo release fix bug lên main (prod)"): **cherry-pick, KHÔNG merge develop/fix-branch**.

1. Đánh giá gap: `git rev-list --count origin/main..origin/develop`; xác nhận mọi file fix tồn tại trên main: `git cat-file -e origin/main:<path>` (file thiếu → cherry-pick conflict hoặc feature chưa có trên prod). Xác định version patch: đọc version hiện tại trên main (`git show origin/main:package.json`), bump patch → `vX.Y.Z`.
2. `git checkout -b release/vX.Y.Z origin/main` (patch bump) rồi `git cherry-pick <fix-sha>`. Nếu commit fix chưa bump version thì thêm commit `chore(release): vX.Y.Z` trên release branch (bump package.json) — main luôn mang đúng version đã phát hành. Fix branch base trên origin/develop nên merge nó sẽ kéo theo TOÀN BỘ develop commits từ main; cherry-pick giữ release phẫu thuật, MR diff chỉ chứa đúng commit fix.
3. Push → MR release → main (labels bug + MFE tag). MR description: summary fix + checklist (cherry-pick sạch, review, pipeline, merge, sync main→develop).
4. **Review feedback tạo commit MỚI trên fix branch** → cherry-pick commit đó lên release branch, push lại; MR tự cập nhật, pipeline chạy lại trên head mới (`list_merge_request_pipelines` để xác minh success trên head mới nhất).
5. **Local review checkout**: branch release có thể đang bị check out ở MAIN worktree → Git cấm cùng branch ở 2 worktree. Switch main worktree về develop trước (`git checkout develop`), rồi trong worktree review: `git checkout -B release/vX.Y.Z origin/release/vX.Y.Z`; verify `git rev-parse HEAD` == MR head_sha trước khi đọc local.
6. Sau khi prod merge: sync main → develop như §8 step 3.

### 6. Conflict patterns (erp-admin)

Most common conflicts when merging develop into release-from-main:

- `helm/frontend/values-{shell,hr,employee,finance,sale,product,dashboard}.yaml` — image tags  (commit SHA)
  **Resolution:** take **develop** (`git checkout --theirs` during merge into release branch, since develop is incoming)

**Pitfall: conflict markers sót trong helm values (case v1.0.4, 2026-08-15):** `git merge` output tail chỉ hiện vài conflict đầu; THỰC TẾ gần như MỌI values-*.yaml đều conflict (main tag khác develop tag). Nếu chỉ resolve những file nhìn thấy rồi `git add -A` → markers của các file còn lại bị commit nguyên vẹn, CI build PASS vì helm không thuộc build graph — chỉ fail khi deploy (helm template). Quy trình bắt buộc sau merge:
1. `git diff --name-only --diff-filter=U | wc -l` — ĐẾM conflict thật, không tin output merge.
2. `git checkout --theirs helm/frontend/values-*.yaml` cho TẤT CẢ file helm (luôn lấy develop).
3. Trước khi commit: `git grep -lE "^(<<<<<<<|=======|>>>>>>>)" -- .` — phải RỖNG. File đã commit (không còn unmerged) thì `checkout --theirs` KHÔNG ăn ("Updated 0 paths") → dùng `git checkout origin/develop -- <paths>`.
4. Sau fix, verify `git diff origin/develop -- helm/` rỗng.

**Retag sau amend (case 2026-08-15):** amend merge commit → HEAD mới → tag cũ sai SHA. Trình tự: `git push --force-with-lease origin refs/heads/release/vX.Y.Z` (branch release chỉ mình dùng, an toàn) → xóa tag cũ local+remote → tạo lại annotated trên HEAD mới → `create_release`/`update_release` description. Lưu ý: token GitLab có thể bị 403 khi UPDATE release (PUT /releases) dù POST tạo được — MR description là nguồn chuẩn, cập nhật MR qua MCP `update_merge_request` (hoạt động), release record lệch SHA chấp nhận được.

App code rarely conflicts if main was only behind develop.

### 7. Local repo hygiene

- Working tree often has unrelated WIP on `develop` → preserve it before release branch work; do not reset, clean, or overwrite unrelated edits
- `lefthook` pre-push runs monorepo typecheck — expect ~1–2 min on tag/branch push
- **Pre-push hook hangs silently (pnpm 11, non-TTY shell):** the hook's `pnpm -r --parallel run typecheck` triggers pnpm's deps-status check, which prompts to purge `node_modules` and stalls forever without a TTY (`ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`). Fix: `export CI=true` before `git push` (auto-confirms purge). Run pushes as background processes with `notify_on_complete` — hook can take minutes; don't wait inline.
- **Verify `git branch --show-current` before EVERY commit in release flows.** The `patch` tool edits files on disk regardless of the checked-out branch, and the terminal session cwd can drift (e.g. left in `Documents/ERP`). Real case: a release-only commit landed on local `develop` instead of the release branch. Recovery (only after confirming the commit was never pushed, via `git ls-remote origin | grep <sha>`): `git checkout develop && git reset --hard origin/develop` → recreate release branch from `origin/main` → re-merge `origin/develop` → re-apply the patch → commit → push.
- Close accidental MRs created during exploration; don't leave draft release MRs open against wrong target

### 8. Post-deploy closeout (after production is deployed from `main`)

When the user confirms production deploy, finish release checklist instead of stopping at “deployed”:

0. **`issue:lifecycle:prod` tự chạy trên pipeline main** (từ v1.0.3): sau khi play deploy xong hết, job ở stage post-deploy tự chạy → close issues `status::done` của milestone (suy từ package.json version). Verify trong pipeline main (`/pipelines/:id/jobs` — tìm `issue:lifecycle:prod` status success + log liệt kê issue đã close). Nếu không thấy job (triggers chưa play hết / pipeline cũ) → run pipeline mới trên main hoặc chạy script tay.

1. **Verify merged MR and production commit from GitLab**
   - `get_merge_request(project_id=9, merge_request_iid=<release-MR>)`
   - Require `state=merged`, `target_branch=main`, and record `merge_commit_sha`.
   - Do not infer deployment from the MR page or user statement alone.
2. **Verify pipeline and deployment statuses for the exact merge SHA**
   - Read the `main` pipeline with `get_pipeline` / `list_pipelines`.
   - Read commit statuses with `list_commit_statuses`; report every MFE trigger job separately.
   - Distinguish overall `success` / `passed with warnings` from failed jobs with `allow_failure=true`. A warning is not the same as a fully green pipeline; name the failed allowed job in the release notes.
   - Check deployment records/environments when available; do not report “prod deployed” solely because a pipeline passed.
3. **Sync `main` back into `develop`**
   ```bash
   git fetch origin
   git checkout develop
   git merge origin/main --no-edit
   # For Helm image-tag conflicts during this direction (main → develop), take origin/main/theirs:
   git checkout --theirs helm/frontend/values-*.yaml
   git add -A
   git commit --no-edit
   git push origin refs/heads/develop
   ```
   Use the exact conflict direction: release branch merging `develop` takes `develop`; `develop` syncing from `main` takes `main`. Verify no unmerged paths and run the repository pre-push checks.
   **CRM re-enable sau sync (bắt buộc, case 2026-08-04):** merge `main` → `develop` kéo theo commit `chore(release): disable CRM modules for production` → develop mất sale/product/finance (`enabled: false`), phá vỡ convention §5a (develop giữ `enabled: true` để UAT/dev thấy CRM). Sau sync phải sửa `packages/shared/src/config/navigation.ts`: set `enabled: true` cho đúng 3 module `sale` (sau `icon: 'Restaurant'`), `product` (`icon: 'Invoicing'`), `finance` (`icon: 'Accounting'`) — KHÔNG đụng `project`/`inventory` (`showInCatalog: false`, vốn false sẵn). Commit riêng: `chore(release): sync main to develop after release YYYY-MM-DD` (pattern cũ: `6ecf4e39`, lần này `8fe54f51`). Verify bằng exit code tường minh: `pnpm --filter @hilo/shared typecheck > /tmp/t.log 2>&1; echo TYPECHECK_EXIT=$?` + `npx eslint packages/shared/src/config/navigation.ts > /tmp/e.log 2>&1; echo ESLINT_EXIT=$?` — commit riêng với chứng cứ exit code 0.
   **Pitfall rerere khi sync (case 2026-08-15):** sau khi release branch đã resolve conflict, `git merge origin/main` trên develop có thể tự staged "previous resolution" (rerere) — resolution cũ là `enabled: false` từ release branch → develop bị CRM disable mà không hề có conflict báo. SAU merge PHẢI grep verify: `git show HEAD:packages/shared/src/config/navigation.ts | grep -B9 requiresCrmContext | grep -cE "enabled: true"` (phải = 3) trước khi push.
4. **Update release description directly**
   - Fetch the current release description first.
   - Mark review, pipeline, merge, and sync checklist items complete with evidence: pipeline ID, merge SHA, sync commit SHA.
   - Make replacements idempotent: skip items already checked; normalize stale text such as “MR created and mergeable” to “MR merged”. Never append status as a note when the durable checklist belongs in release description.
5. **Verify final state**
   - Confirm `origin/main` and `origin/develop` refs, sync commit, and updated release description.
   - Preserve any unrelated local WIP; report it rather than including it in the sync commit.

### 9. Tag creation side-effect check

If a tag creation MCP call returns an argument/API error, query the remote tag before retrying. The API may have created the tag despite returning an error. Compare both tag target SHA and peeled commit; never force-delete/recreate a tag until the existing target is verified.

## Anti-patterns

- ❌ MR `develop → main` as the release path
- ❌ Creating `release/*` branch from `develop` then pretending it's based on main (kể cả chạy `pnpm git:release` khi đang đứng trên develop)
- ❌ Quên bump `package.json` version trước khi tạo branch/tag — tag không khớp version trong repo
- ❌ Đặt tag trùng tên branch (`release/v1.0.0` cho cả hai) — tag phải là `v1.0.0`, branch là `release/v1.0.0`
- ❌ Tagging develop HEAD before develop is merged into the release branch (wrong SHA for release artifact)
- ❌ Force-push main

## Related

- Issue tracking: `gitlab-issues`
- Project notes: `gitlab-issues/references/hilo-erp-projects.md`
- Checklist: `references/erp-admin-release-checklist.md`
