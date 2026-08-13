# Worked example #158 — salary grade BHXH / công đoàn annotations

2026-08-07. User đính kèm ảnh `CreateSalaryGradeView` với 4 annotation đỏ → tạo issue #158.

## Annotations trên ảnh

| # | Loại | Vị trí | Nội dung annotation | Ô thực tế |
|---|------|--------|---------------------|-----------|
| 1 | Hộp + text đỏ | Nhân viên đóng → dòng Công đoàn → TÊN THÀNH PHẦN | "Đoàn phí công đoàn" | "Công đoàn" |
| 2 | Hộp đỏ (không text) | Nhân viên đóng → dòng Công đoàn → SỐ TIỀN + % | — (chỉ highlight) | 0 / 0 |
| 3 | Hộp + text đỏ | Công ty đóng → dòng Công đoàn → TÊN THÀNH PHẦN | "Kinh phí công đoàn" | "Công đoàn" |
| 4 | Mũi tên + text đỏ | Công ty đóng → dòng Công đoàn → % | "2% quỹ lương đóng BHXH" | 2 |

## Hiện trạng code tìm được (create-salary-grade-sections.ts + vi/hr.json)

- `employee-union-1` và `company-union-1` **cùng dùng chung i18n key `rows.union`** ("Công đoàn") và **cùng mã `CONG_DOAN`**.
- `company-insurance-1` có `percent: '10,5'` — copy nhầm từ nhân viên (bug ẩn, ảnh không nói thẳng).
- i18n tooltips: `tooltips.socialInsuranceSalaryPercent`, `tooltips.contributionPercent` ("Tỷ lệ đóng được tính trên lương đóng BHXH").

## Domain defaults đã user xác nhận (durable)

- **BHXH công ty đóng mặc định = 21,5%** = BHXH 17,5 + BHYT 3 + BHTN 1. KHÔNG copy 10,5 của nhân viên (10,5 = 8 + 1,5 + 1).
- Union nhân viên = **"Đoàn phí công đoàn"** (gợi ý mã `DOAN_PHI_CONG_DOAN`), union công ty = **"Kinh phí công đoàn"** (gợi ý mã `KINH_PHI_CONG_DOAN`) — convention mã tiếng Việt không dấu.
- Kinh phí công đoàn = **2% quỹ lương đóng BHXH** (`LUONG_DONG_BHXH`), không phải lương gross → ghi chú cột % cần nói rõ cơ sở này.
- Quy tắc consistency (user): tên hiển thị khác nhau giữa 2 section → **mã cũng phải khác nhau**, không dùng chung 1 mã.
- ⚠️ Đổi `code` field ảnh hưởng payload `buildPayrollTemplateConfig` gửi BE → verify BE contract trước khi đổi mã.

## Issue kết quả

- Title: `[HR] Phân biệt tên hiển thị + mã Đoàn phí công đoàn / Kinh phí công đoàn, BHXH công ty đóng 21,5%`
- Labels: `HR, MFE::hr, feature, frontend, priority::medium, ready-for-agent`; assignee luukhoahoc (id=8); chưa gắn milestone (issue mới chưa vào scope v1.0.0).
- Ảnh upload qua `POST /projects/9/uploads` (`curl -F file=@...`) → nhúng `![...](/uploads/<hash>.png)` vào References.
- Sau khi user bổ sung "mã sửa theo tên hiển thị" + "BHXH công ty 21,5%" → **UPDATE description (PUT full body)** + mở rộng title, KHÔNG tạo note.
