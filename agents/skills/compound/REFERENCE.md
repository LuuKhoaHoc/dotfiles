# Compound Skill - Reference Guide

Tài liệu này cung cấp hướng dẫn chi tiết cho AI Agent về cách phân loại, đặt tên và điền metadata cho tài liệu tri thức trong thư mục `docs/solutions/`.

---

## 1. Phân loại Thư mục (`category`)

Chọn 1 trong các thư mục con trong `docs/solutions/` để lưu trữ file solution:

| Thư mục (`category`) | Mô tả |
| :--- | :--- |
| `best-practices` | Các mẫu code tốt (design patterns, idioms, React/TypeScript best practices) đã được thống nhất áp dụng. |
| `build-errors` | Cách giải quyết các lỗi biên dịch, lỗi bundling (Vite, Turbo, ESbuild), cấu trúc monorepo bị hỏng. |
| `conventions` | Quy định đặt tên, cấu trúc thư mục, quy ước giao tiếp API, i18n, router. |
| `integration-issues` | Các vấn đề liên quan tới tích hợp Micro-Frontend (remotes, shell), CI/CD, docker, hoặc môi trường dev. |
| `architecture-patterns` | Các quyết định kiến trúc lớn, cấu trúc feature boundaries, dùng Zustand, React Query. |
| `ui-patterns` | Tùy chỉnh UI/UX, Design Tokens, Tailwind utility patterns, Layout responsiveness. |

---

## 2. Điền các trường Frontmatter

### `problem_type`
- `best_practice`: Hướng dẫn lập trình tốt hơn.
- `bug_fix`: Sửa một lỗi cụ thể đã xảy ra.
- `architecture`: Quyết định thiết kế/kiến trúc.
- `convention`: Quy định, chuẩn hóa.
- `integration`: Lỗi tích hợp hệ thống/môi trường.

### `severity`
- `low`: Ảnh hưởng nhỏ, code smell hoặc cải thiện hiệu năng nhỏ.
- `medium`: Ảnh hưởng tới độ duy trì (maintainability) hoặc chất lượng của một module.
- `high`: Gây lỗi chạy ứng dụng hoặc vi phạm nghiêm trọng quy chuẩn codebase.
- `critical`: Gây sập ứng dụng, chặn đứng luồng build, lỗi bảo mật.

### `applies_when`
Đây là trường cực kỳ quan trọng cho **Semantic Search**. Hãy viết các điều kiện dưới dạng các mệnh đề rõ ràng để Agent dễ dàng khớp ngữ nghĩa khi đọc hệ thống tri thức.
*Ví dụ tốt:*
```yaml
applies_when:
  - Khi làm việc với HR Dashboard Carousel Stat Cards, icon mapping và i18n foot keys
  - Khi tùy chỉnh UI/UX cho DateRangePicker và Calendar range selection trong @hilo/ui
```

### `tags`
Sử dụng các tag chung về công nghệ (`react`, `typescript`, `vite`, `tailwind`, `zustand`, `react-query`) kết hợp với các tag về domain/module nghiệp vụ (`employee`, `hr`, `shared`, `auth`).

---

## 3. Cách đặt tên file

Đặt tên file tuân thủ quy tắc sau:
- Sử dụng chữ thường, không có dấu, các từ nối nhau bằng dấu gạch ngang `-`.
- Nếu thư mục đích đã có sẵn các file bắt đầu bằng ngày tháng (như `2026-06-01-tên.md`), hãy sử dụng định dạng: `<YYYY-MM-DD>-<tên-ngắn-gọn>.md`.
- Nếu không có, đặt tên mô tả trực tiếp vấn đề: `<tên-ngắn-gọn>-<YYYY-MM-DD>.md`.
- Hãy kiểm tra các file sẵn có trong thư mục bằng `list_dir` trước khi quyết định đặt tên.

---

## 4. Kiến trúc lưu trữ tri thức (Generic Skill vs Local Store)

- **Generic Skill**: Quy trình `/compound` và bộ template là công cụ tổng quát, dùng chung được cho bất kỳ dự án nào.
- **Local Knowledge Repository**: Mỗi dự án (repository) sở hữu thư mục `docs/solutions/` riêng. Tri thức lưu trong đó là tài sản của dự án đó, giúp bất kỳ Agent AI hoặc Dev nào join dự án đều có thể tra cứu và tuân thủ.

---

## 5. Checklist khi viết giải pháp (Compound Checklist)

Khi Agent tạo tài liệu giải pháp, phải đảm bảo:
- [ ] Code ví dụ trong `Good` và `Bad` phải là code thực tế hoặc rút gọn tối đa từ code thực tế trong dự án (tránh code lý thuyết suông).
- [ ] Không rò rỉ thông tin nhạy cảm (API keys, thông tin cá nhân của user).
- [ ] Cung cấp lý giải kỹ thuật rõ ràng, không chỉ nói "đây là quy chuẩn".
