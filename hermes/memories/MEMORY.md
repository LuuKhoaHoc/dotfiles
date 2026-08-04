Helio ERP = dự án CÁ NHÂN (~170 users; Next.js + Supabase + aube + shadcn/ui + Tailwind v4; AI Qwen/DeepSeek).
§
BE/PO feature request: tạo issue MỚI thay vì gộp vào issue cũ, trừ khi cùng scope + cùng assignee + follow-up nhỏ.
§
Re-verify sau push (ls-remote/fetch).
§
cuongt(id=10, Trần Cường)=Finance + HR employee-scoped specs (freeze/unfreeze, delete/restore); QuyCN(id=31, Cao Quý)=Product + HR attendance-sheet-scoped specs (period lock/unlock).
§
Issue template: `.gitlab/issue_templates/feature_request.md`. Labels: ready-for-agent|ready-for-human + MFE tag.
§
erp-admin(id=9): Locale JSON cleanup: dùng Python json module (load→modify→dump), không sed (breaks JSON). Validate bằng `python -m json.tool`.
§
execute_code chạy trong sandbox cô lập KHÔNG có user env vars (GITLAB_TOKEN → KeyError). Muốn dùng env vars: write_file script ra /tmp rồi chạy qua terminal (`python3 /tmp/script.py`).
§
ERP i18n: defaultNS='common'; prefix 'common:' redundant nhưng KHÔNG phải bug.
§
ERP có 2 checkout: erp-admin (chính) + erp-admin-review (worktree) — review MR hay cd qua erp-admin-review. Documents/ERP không phải git repo.
§
BE/API mới: gọi curl trước, ghi status/trace vào issue, không lưu token; khác scope → tách MR/release.
§
Trước khi tạo MR mới check MR open cũ — user hay tạo MR v2 thay vì sửa v1 (v1 bị bỏ quên → conflict).
§
Zed global AGENTS.md (~/.config/zed/AGENTS.md): rule chung, KHÔNG nhắc project công ty; Zed agent dùng RTK CLI proxy + Caveman Lite (Hermes vẫn normal/verbose).
§
erp-admin release: SemVer từ 08/2026 — branch release/vX.Y.Z, tag vX.Y.Z (không trùng tên), bump package.json trước khi tạo branch; git:release script base theo HEAD hiện tại (phải base origin/main).
§
ERP API: ApiResponse<T[]> trả array ở `.data` (không `.items`).
§
Chốt công/Unlock attendance (erp-admin): BE contract mới bắt buộc attendanceSheetId composite {orgId}:{year}:{month}:{unitId} (bỏ lockYear/lockMonth); FE chưa migrate → HRM-400-1490. FE mapping doc: Documents/ERP/.hermes/desktop-attachments/attendance-sheet-lock-unlock-fe-mapping.md