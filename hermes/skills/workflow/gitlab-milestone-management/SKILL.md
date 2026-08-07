---
name: gitlab-milestone-management
description: "Use when updating GitLab release milestones: sync, close."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitLab, Milestone, Release, erp-admin]
    related_skills: ["gitlab-issue-workflow", "gitlab-release"]
---

# GitLab Milestone Management (erp-admin)

Use for milestone lifecycle: tạo/assign issue vào milestone, **cập nhật milestone theo issues `status::done` trước release**, tick release checklist, và quyết định thời điểm close.

Milestone quen thuộc: `v1.0.0` (id=2) — release SemVer tuần 05→06/08/2026, due thứ 5. Policy chuẩn trong description: **issue `status::done` = UAT-ready nhưng vẫn OPEN, chỉ close sau khi prod deploy thành công** (post-production automation).

## Prerequisites

- Activate milestone tools: `mcp__gitlab__discover_tools category=milestones` → `list_milestones`, `get_milestone`, `edit_milestone`, `get_milestone_merge_requests`.
- Tools: `list_issues` (milestone filter), `list_merge_requests` (search), git clone dùng chung `~/Dev-Work/Hilo/erp-admin`.

## Pre-release milestone update (theo issues đánh done)

Worked case 2026-08-06 (v1.0.0: 18/18 issues done, tất cả MR merged):

1. **Đọc policy + checklist từ milestone description** (`list_milestones(project_id=9, search=<title>)`) — description chứa release checklist `[ ]` items; đây là nguồn sự thật cho việc tick gì.
2. **List issues trong milestone:** `list_issues(project_id=9, milestone=<title>, scope=all, state=all)`. Payload 100KB+ bị persist ra file → parse bằng Python (`json.loads` của `result` string) in compact `iid / state / status::* label / closed_at / title`. Xác nhận: mọi issue đều `status::done`? Issue nào chưa done bị sót?
3. **Verify feature MRs merged vào develop:**
   - `get_milestone_merge_requests(milestone_id=..., per_page=100)` + **page 2** — NHIỀU MR feature KHÔNG gắn milestone (`milestone=null`), list này thiếu.
   - Git là nguồn đáng tin hơn: `git log --merges --format='%h %ci %s' origin/develop --since=<release trước>` — subject merge commit chứa **branch name**, branch name chứa issue number (`feat/143-customer-filter-sort`) → map issue→MR merged không cần API.
   - **Pitfall:** commit subject thường KHÔNG chứa `#NN` (squash=false merge commits) — grep subject theo `#NN` miss nhiều; grep branch name mới đáng tin.
   - MR lẻ không tìm được trong git → `list_merge_requests(project_id=9, search=<keyword từ title issue>, state=merged)`.
4. **Update checklist:** `edit_milestone(description=<full new>)` — giữ nguyên toàn bộ description cũ, tick `[x]` CHỈ các mục verify được (vd: `All intended issues are assigned`, `Feature MRs are merged into develop`, `Issues moved to status::done while remaining open`) + thêm section `## Status snapshot (YYYY-MM-DD)` ghi số liệu (18/18 issues done, danh sách issue→MR). **KHÔNG tick** UAT/prod-deploy/release-created khi chưa xảy ra.
5. **Close timing:** milestone chỉ `state_event=close` SAU prod deploy hoàn tất — close sớm gây hiểu nhầm "đã release xong". Issue cũng vậy: chỉ close sau prod deploy (xem strict UAT lifecycle trong `gitlab-issue-workflow`).

## Release timing (khi user hỏi "nên release lúc nào")

Prod deploy: **NGOÀI giờ làm** — SAU khi user chấm công ra hết (18h–20h) hoặc trước giờ vào làm (~6h). KHÔNG trong giờ hành chính, vì:

- Attendance ghi dữ liệu liên tục suốt giờ làm → downtime/cắt session giữa giờ = mất dữ liệu chấm công, phải sửa tay.
- Release thường đụng module chấm công (vd v1.0.0: #129 lock/unlock theo `attendanceSheetId`, #128 freeze/unfreeze — vùng từng gây prod bug `HRM-400-1490` do FE gửi payload cũ).
- Merge vào develop ban ngày OK; chỉ prod deploy cần chờ hết giờ chấm công.

## Pitfalls

- ❌ Close issue/milestone sớm khi issue mới `status::done` — done ≠ released; close xảy ra sau prod deploy.
- ❌ Tick checklist items chưa xảy ra (UAT, prod deploy, GitLab Release) — chỉ tick cái verify được từ dữ liệu.
- ❌ Chỉ dựa vào `get_milestone_merge_requests` để kết luận "mọi feature đã merged" — nhiều MR không gắn milestone.
- ❌ Grep git log theo `#NN` trong subject — miss; dùng branch name trong merge commit subject.
- ❌ `list_issues`/`get_milestone_merge_requests` payload lớn đọc trực tiếp vào context — parse bằng Python, chỉ giữ field compact.

## References

- `references/milestone-v1.0.0-status-2026-08-06.md` — snapshot đầy đủ: bảng issue→MR mapping (kèm MR có `milestone=null`), checklist state sau update, python parse snippet.
