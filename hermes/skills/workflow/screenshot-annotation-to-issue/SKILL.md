---
name: screenshot-annotation-to-issue
description: Create GitLab issues from annotated UI screenshots.
triggers:
  - user attaches a UI screenshot with red annotations and asks to create a fix issue
  - creating an issue from visual QA feedback instead of a written spec
---

# Screenshot Annotation → GitLab Issue

User thường chụp UI, khoanh đỏ / ghi chú bằng tay, rồi nhờ tạo issue sửa. Workflow này đảm bảo issue mô tả đúng annotation + đúng hiện trạng code, kèm ảnh gốc làm bằng chứng.

## Steps

1. **Enumerate annotations with `vision_analyze`** — ask a STRUCTURED question so the model doesn't merge or drop notes:
   > "Liệt kê từng annotation riêng biệt: loại (hộp đỏ / mũi tên / text đỏ), vị trí (bảng → dòng → cột), nội dung annotation, và nội dung ô thực tế."
   
   Cột annotation thành bảng so sánh (STT / loại / vị trí / nội dung / giá trị ô thực tế) — phân biệt text đỏ (yêu cầu) với hộp đỏ không text (chỉ highlight).

2. **Cross-check annotation against REAL code before writing the issue** — search the named component (`search_files` content, not just files), read the section factories + i18n keys:
   - Xác định hiện trạng thật (vd: 2 dòng dùng chung 1 i18n key / 1 mã `code` → mô tả vào issue, không chỉ chép ảnh).
   - Phát hiện bug ẩn mà ảnh không nói thẳng (vd: section công ty đóng copy `percent` của nhân viên).
   - Tìm row id / key / mã hiện tại để dev khỏi đoán.

3. **Upload the annotated image BEFORE creating the issue** so the markdown link is ready for References:
   ```bash
   curl -sS -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -F "file=@<path>" \
     "https://gitlab.vppos.vn/api/v4/projects/9/uploads"
   ```
   Response field `markdown` → embed in issue description: `![name](/uploads/<hash>/file.png)`.

4. **Create the issue** (search existing first — EN + VI keywords; to-tickets format; labels/assignee per project conventions; see `gitlab-issue-workflow` skill for the general flow — it's user-owned, so this skill carries the screenshot-specific parts).

5. **User follow-up corrections → UPDATE the issue description (PUT full body), never a note** — and widen the title to match the new scope (case #158: title extended when mã + default % were added).

## Pitfalls

- Hộp đỏ KHÔNG text ≠ yêu cầu đổi giá trị — nó chỉ highlight dòng. Chỉ text đỏ + mũi tên là yêu cầu thật; ghi rõ trong issue để dev không tự ý đổi giá trị highlight.
- Đừng viết "mã giữ nguyên" khi user sau đó muốn đổi mã — nếu tên hiển thị 2 dòng khác nhau thì mã cũng phải khác (user preference: "mã sửa theo tên hiển thị cho consistent"). Ghi luôn cả mã gợi ý theo convention (tiếng Việt không dấu: `DOAN_PHI_CONG_DOAN`) + cảnh báo verify BE contract khi đổi `code` field trong payload.
- Một ảnh có thể chứa nhiều annotation trên nhiều section — liệt kê đủ từng cái, không gộp.
- Default % sai kiểu "công ty copy của nhân viên" (vd 10,5 thay vì 21,5) — khi thấy 2 section cùng giá trị, kiểm tra xem có phải copy nhầm không.

## References

- `references/worked-example-158.md` — case #158 (salary grade BHXH/công đoàn): annotation đỏ → hiện trạng code → issue, kèm domain defaults đã xác nhận.
