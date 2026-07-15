---
name: compound
description: Document and compound learnings, code patterns, and bug solutions into the repository's docs/solutions/ structure. Use when the user requests to save a learning, document a solution, run a compound action, or after successfully resolving a bug or completing a refactoring task.
---

# Compound Learnings Skill

Tự động hóa việc ghi nhận bài học kinh nghiệm, giải pháp sửa lỗi, và các code pattern tốt/xấu vào cấu trúc lưu trữ tri thức `docs/solutions/` của dự án.

## Quick Start

Khi nhận thấy có một bài học đắt giá cần ghi lại hoặc khi user yêu cầu:
1. Đọc [TEMPLATE.md](TEMPLATE.md) để lấy cấu trúc file mẫu.
2. Xác định các trường frontmatter cần thiết (xem thêm [REFERENCE.md](REFERENCE.md)).
3. Viết file solution mới vào thư mục tương ứng trong `docs/solutions/`.

## Workflows

### 1. Thu thập thông tin (Fact Gathering)
- **Vấn đề (Context):** Lỗi là gì? Tại sao cách làm cũ không hoạt động hoặc không tối ưu?
- **Giải pháp (Guidance):** Cách viết code chuẩn là gì? Đưa ra ví dụ Code cụ thể (Good vs Bad).
- **Phân loại:**
  - `category`: `best-practices`, `build-errors`, `conventions`, `integration-issues`, `architecture-patterns`.
  - `module`: `employee`, `hr`, `shared`, `infra`, `shell`, v.v.
  - `problem_type`: `best_practice`, `bug_fix`, `architecture`, `convention`, `integration`.
  - `severity`: `low`, `medium`, `high`, `critical`.

### 2. Tạo File Solution
Tạo file markdown mới tại:
`docs/solutions/<category>/<YYYY-MM-DD>-<slug>.md`
Hoặc đặt tên theo format `docs/solutions/<category>/<slug>-<YYYY-MM-DD>.md` tùy theo các file sẵn có trong thư mục đó.

*Lưu ý:*
- Tên file viết thường, nối nhau bằng dấu gạch ngang `-`.
- Ví dụ: `docs/solutions/best-practices/2026-07-03-use-centralized-query-keys.md`.

### 3. Điền nội dung và định dạng
- Copy cấu trúc trong [TEMPLATE.md](TEMPLATE.md).
- Thay thế các placeholder bằng thông tin thực tế.
- Viết rõ ràng phần lý do tại sao phương án "Good" lại tốt hơn "Bad".

## Advanced Guidelines

Xem hướng dẫn chi tiết cách viết frontmatter hiệu quả và các ví dụ nâng cao tại [REFERENCE.md](REFERENCE.md).
