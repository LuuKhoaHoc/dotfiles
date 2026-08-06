---
name: compound
description: Document and compound learnings, code patterns, architectural decisions, and bug solutions into the repository's docs/solutions/ structure. Use when the user requests to save a learning, document a solution, run a compound action, or after successfully resolving a bug or completing a refactoring task.
---

# Compound Learnings Skill

Tự động hóa việc trích xuất bài học kinh nghiệm, giải pháp sửa lỗi và code pattern vào kho tri thức `docs/solutions/` của repository.

## Progressive Disclosure & Reference Pointers

Skill này sử dụng các tài liệu tham chiếu phụ thuộc:
- Khi cần tạo nội dung file solution: Đọc [TEMPLATE.md](TEMPLATE.md).
- Khi cần tra cứu Taxonomy (`category`, `problem_type`, `severity`) hoặc quy tắc `applies_when`: Đọc [REFERENCE.md](REFERENCE.md).

## Execution Steps

### Step 1: Fact Gathering (Thu thập thực tế)
Trích xuất thông tin cốt lõi từ ngữ cảnh làm việc vừa qua:
1. **Context**: Mô tả bối cảnh, lỗi hoặc rủi ro của cách làm cũ.
2. **Guidance**: Nguyên tắc/cách làm chuẩn mới.
3. **Examples**: Tạo cặp mã nguồn **Good vs Bad** bám sát code thực tế trong repo.

### Step 2: Formulate Metadata & File Path
1. Chọn `category` phù hợp từ [REFERENCE.md](REFERENCE.md) (vd: `best-practices`, `build-errors`, `conventions`, `integration-issues`, `architecture-patterns`, `ui-patterns`).
2. Xác định `module` hiện tại (vd: `hr`, `employee`, `shared`, `ui`, `infra`).
3. Đặt tên file theo cú pháp: `docs/solutions/<category>/<YYYY-MM-DD>-<slug>.md` (hoặc `<slug>-<YYYY-MM-DD>.md` tùy cấu trúc hiện có trong thư mục mục tiêu).

### Step 3: Write & Verify Solution File
1. Đọc mẫu tại [TEMPLATE.md](TEMPLATE.md) và ghi nội dung hoàn chỉnh vào file solution.
2. Kiểm tra lại Frontmatter YAML, đảm bảo không còn text placeholder và đầy đủ các trường bắt buộc.
3. Tạo clickable links (`file:///...`) cho các file và mã nguồn liên quan.

## Completion Criteria

Việc thực thi `/compound` hoàn tất khi:
- [ ] File solution đã được tạo tại `docs/solutions/<category>/...`.
- [ ] Frontmatter YAML chứa đầy đủ các trường bắt buộc và đúng taxonomy trong `REFERENCE.md`.
- [ ] Cung cấp clickable link dẫn tới file solution vừa tạo cho User.
