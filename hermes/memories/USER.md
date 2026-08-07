Hilo ERP (công ty) = ERP Admin gitlab.vppos.vn. MFE: sale/finance/product/employee/hr/apps-dashboard/shell.
§
User preference: response ngắn gọn (đọc dài mệt); agent-to-agent: caveman/terse. Vietnamese cho hội thoại, English cho code. Update issue descriptions (không notes) khi thêm task. Research web cho tech stack mới.
§
User prefers clean architecture over fear of breaking changes — 'không sợ breaking changes', ưu tiên React 19 best practices (SRP, composition) kể cả refactor lớn. Chốt 2026-08-06: zustand cho feature-local UI state (store per feature) + memo/stable callbacks; URL-backed list/filter state giữ URL.
§
Thích dùng Tailwind CSS thay inline style (kể cả màu dynamic: CSS vars + arbitrary values trên root).
§
Hilo = CÔNG TY CỔ PHẦN DỊCH VỤ T-VAN HILO, trụ sở 18 Đoàn Trần Nghiệp, Hai Bà Trưng, HN.
§
Issue management (erp-admin): refactor cùng 1 feature → ưu tiên 1 issue umbrella (gộp các scope chạm cùng file/assignee, làm tuần tự), không tách nhỏ nhiều issue; issue mới tạo bị thay thế → XÓA hẳn (DELETE API), không close — close mang nghĩa "đã release" gây hiểu nhầm.
§
Dùng antigravity IDE implement, Hermes review/verify.
§
Phản đối over-abstraction (tách component code tầm thường) — KISS, chỉ tách khi duplication đáng kể.