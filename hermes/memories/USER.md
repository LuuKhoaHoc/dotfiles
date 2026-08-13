Hilo ERP (công ty) = ERP Admin gitlab.vppos.vn. MFE: sale/finance/product/employee/hr/apps-dashboard/shell.
§
Vietnamese hội thoại — cấm 'mày/tao' (xưng hô còn lại thoải mái); user hay gọi assistant 'ní'/'sốp' (thân mật); English cho code.
§
User prefers clean architecture over fear of breaking changes — 'không sợ breaking changes', ưu tiên React 19 best practices (SRP, composition) kể cả refactor lớn. Chốt 2026-08-06: zustand cho feature-local UI state (store per feature) + memo/stable callbacks; URL-backed list/filter state giữ URL.
§
Thích dùng Tailwind CSS thay inline style (kể cả màu dynamic: CSS vars + arbitrary values trên root).
§
Hilo = CÔNG TY CỔ PHẦN DỊCH VỤ T-VAN HILO.
§
refactor cùng feature → 1 issue umbrella (gộp scope chạm cùng file/assignee, làm tuần tự), không tách nhỏ; issue mới thay thế → XÓA hẳn (DELETE API), không close (close = 'đã release', gây hiểu nhầm).
§
Dùng antigravity IDE implement, Hermes review/verify.
§
Phản đối over-abstraction (tách component code tầm thường) — KISS, chỉ tách khi duplication đáng kể.
§
Payroll: user nghiêm về sai số tiền (percent cắt precision → BE tính ngược = đền tiền) — round đồng, rate payload derive từ amount full precision.
§
User làm tại chi nhánh Hilo: BH4, Block B, Toà nhà Sky Center, 5B Phổ Quang, P. Tân Sơn Hòa, TP.HCM (không phải trụ sở Hà Nội)