---
name: qa-bug-list-to-issues
description: QA bug list → recon & group into GitLab fix issues.
---

# QA Bug List → GitLab Issues

Khi user đưa danh sách bug UI (QA log, thường dạng code block liệt kê) và yêu cầu "tạo/cập nhật issues fix". Pattern lặp lại nhiều lần (2 batch/ngày 2026-08-10, 17 bug → 12 issues). Issue format/labels chuẩn: đọc thêm skill `gitlab-issue-workflow`; release policy: `gitlab-release` (cả 2 user-owned — cần `hermes curator adopt` để patch).

## 1. Recon song song (dùng skill `orchestrate`)

- Chia bug thành nhóm theo khu vực (MFE/component liên quan), spawn **≤5 subagent song song** (delegate_task batch), mỗi agent 1 nhóm.
- Brief agent PHẢI self-contained (agent không có context hội thoại), tiếng Việt output:
  - Repo path + **READ-ONLY tuyệt đối** (cấm sửa file/checkout/commit — clone dùng chung, có thể có IDE/agent khác chạy)
  - **Đọc code từ `origin/develop` bằng `git show origin/develop:<path>`** — main local thường STALE sau release (behind 100+ commits); working tree chỉ để suy đường dẫn
  - codegraph-first: có `.codegraph/` ở root → `codegraph_explore` (projectPath=repo root) trước grep
  - Mỗi bug: (1) MFE + file path, (2) component, (3) root cause, (4) hướng fix + file cần đụng, (5) pattern chuẩn để đồng bộ; kết luận nhóm/gộp thế nào
- Trong lúc chờ agent: check GitLab duplicate (`list_issues` search theo từ khóa EN+VI, `state=opened`) + `list_labels` + đọc các issue mở có liên quan (vd refactor đang thay thế component).

## 2. Nhóm + tạo issue

- **1 issue/nhóm bug liên quan** (cùng component/file, cùng MFE). Không tách từng bug lẻ.
- **Bug nằm trong component đang bị refactor thay thế** (issue refactor đã mở, case #168 sidebar shadcn) → hỏi user qua `clarify`: gộp vào refactor làm AC bổ sung (tránh fix code sắp bị xóa) hay issue riêng. User thường chọn gộp.
- **Bug đã được fix trên develop** (recon thấy wiring đúng / key i18n đã tồn tại) → issue vẫn tạo nhưng ghi "verify trên env deploy hiện tại + hardening", không giả định lỗi còn (QA có thể đang nhìn bản deploy cũ — case filter dashboard hr, placeholder, key `waiting`).
- Format: `## What to build` (hiện trạng + root cause ngắn) / `## Acceptance criteria` / `## Blocked by` / `## References` (trích QA log). KHÔNG ghi file path (stale nhanh) — ghi tên component.
- Labels bug: `bug, frontend, priority::medium, ready-for-agent` + label MFE (`MFE::shell`+`shell`, `HR`+`MFE::hr`, `employee`, `remote-apps` cho apps-dashboard, `Shared`). Chưa gắn milestone/assignee trừ khi user yêu cầu.
- Sau khi tạo: link `relates_to` các cặp cùng MFE/khu vực (bắt buộc `target_project_id`).
- **User sửa vị trí bug** ("waiting là HR không phải employee") → cập nhật description issue ngay (không dùng note), chuyển mục sang issue đúng vùng theo rule cùng file/assignee; báo lại rõ ràng.

## 3. Assignee — user giữ quyền phân phát

- Đừng tự assign bừa; khi user nói "phân phát cho Tôi, Cường và Quý" → đề xuất + assign theo domain: **Quý(31)** = shell/apps-dashboard + HR attendance; **Cường(10)** = HR employee-scoped + request-management; **luukhoahoc(8)** = shared/architecture + PO quyết định (ẩn feature). Verify bằng response update_issue.

## 4. Version release khi user hỏi

- Thực tế 08-2026: **hotfix-on-demand**, mỗi đợt bump PATCH (v1.0.0 07/08 → v1.0.1 08/08 → v1.0.2 + v1.0.3 10/08). Batch bug fix → v1.0.4.
- MINOR (1.1.0) khi release có **feature mới** (vd bật CRM prod); MAJOR (2.0.0) khi **breaking** (đổi API contract, DB migration, UI overhaul). Refactor giữ nguyên visual (#168) KHÔNG phải MAJOR — vẫn PATCH.

## Pitfalls

- Summary subagent bị truncate → đọc file summary đầy đủ (path in footer) trước khi viết issue.
- Bug mơ hồ ("list các card của các page danh sách") → agent phải xác định màn cụ thể + nêu caveat diễn giải.
- Recon kết luận "không lệch trên 4 tiêu chí" nhưng QA báo lệch → viết issue theo hướng chống drift (duplication → wrapper hóa) + ghi rõ hiện trạng thật, đừng chép nguyên câu QA.
