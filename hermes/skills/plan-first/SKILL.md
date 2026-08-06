---
name: plan-first
description: Stop and think before coding. Restate the goal, inspect the codebase, produce a plan as a file in docs/plans/, then execute. Use when user asks to build a feature, implement a change, or tackle a non-trivial task — especially when the scope is ambiguous or the approach is unclear.
---

# Plan First

**Không giả định. Không che giấu sự mơ hồ. Trình bày tradeoffs trước khi viết code.**

Skill này áp dụng quy trình lập kế hoạch nghiêm túc cho các tác vụ không tầm thường (non-trivial).

---

## When to Use

- User yêu cầu thêm tính năng, thay đổi cấu trúc hoặc sửa đổi hành vi codebase.
- Phạm vi công việc mơ hồ hoặc có nhiều hướng tiếp cận khác nhau.
- Thay đổi chạm tới nhiều tệp tin hoặc hệ thống.

---

## Workflows

### 1. Khảo sát thực địa (Inspect the Terrain)
Trước khi lập kế hoạch, hãy tìm hiểu kỹ hiện trạng:
- Đọc các tệp tin liên quan và bối cảnh xung quanh chúng.
- Tìm kiếm các giải pháp tương tự đã có sẵn trong `docs/solutions/` hoặc `AGENTS.md` (institutional learnings) để đảm bảo tính nhất quán.

### 2. Xác định cấu trúc file kế hoạch (Identify Deliverable Name)
Xác định tên tệp kế hoạch theo định dạng:
`docs/plans/<YYYY-MM-DD>-<seq>-<type>-<slug>-plan.md`

Trong đó:
- `<YYYY-MM-DD>`: Ngày hiện tại (Local time: 2026-07-03).
- `<seq>`: Số thứ tự 3 chữ số bắt đầu từ `001`. Quét thư mục `docs/plans/` để tìm file có số thứ tự lớn nhất trong ngày hôm nay, tăng lên 1 (ví dụ `002`).
- `<type>`: Loại kế hoạch (`feat`, `refactor`, `fix`, `chore`).
- `<slug>`: Tên ngắn gọn nối bằng dấu gạch ngang (ví dụ `add-auth-flow`).

*Ví dụ:* `docs/plans/2026-07-03-001-feat-add-auth-flow-plan.md`

### 3. Tạo Kế hoạch (Write the Deliverable)
Tạo tệp tin kế hoạch mới dựa trên cấu trúc của [TEMPLATE.md](TEMPLATE.md).

**Completion Criteria:**
- File plan được ghi thành công vào đúng đường dẫn trong `docs/plans/`.
- File plan chứa đầy đủ các phần: `Summary`, `Requirements`, `Scope Boundaries`, `Context & Research`, `Key Technical Decisions`, `Implementation Units`.
- Các bước thực thi (`U1`, `U2`, ...) ghi rõ tệp tin cần sửa/tạo và cách kiểm tra xác minh (`Verification`).

### 4. Đợi phê duyệt (Checkpoint Approval)
Trình bày liên kết markdown trực tiếp tới file plan vừa tạo cho người dùng click xem và duyệt.
*Ví dụ:* `Tôi đã tạo kế hoạch chi tiết tại [tên-file.md](file:///path/to/docs/plans/tên-file.md). Vui lòng duyệt qua để tôi tiếp tục.`

**Completion Criteria:**
- **Dừng lại ngay lập tức** (Stop and end turn). KHÔNG ĐƯỢC phép sửa code trước khi User duyệt kế hoạch (phản hồi trực tiếp hoặc bấm nút duyệt).
- Nếu User có feedback, cập nhật trực tiếp file plan đó rồi trình bày link mới để xin phê duyệt lại.

### 5. Thực thi và Kiểm thử (Execute & Verify)
Sau khi kế hoạch được phê duyệt:
- Thực hiện từng bước nhỏ, có thể kiểm thử độc lập.
- Chạy các lệnh kiểm tra hẹp nhất có thể (lint, typecheck, tests) sau mỗi bước.
- Cập nhật trạng thái `status: completed` trong frontmatter của file plan khi hoàn thành.
