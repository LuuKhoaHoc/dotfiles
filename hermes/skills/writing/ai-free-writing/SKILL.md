---
name: ai-free-writing
description: Use when writing reports, docs, emails, not chat replies.
version: 1.1.0
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [writing, ai-ism, anti-slop, report, prose, vietnamese]
    category: writing
    related_skills: [humanizer]
---

# AI-Free Writing: Hard-Ban Rules

## When to Use

Load skill này khi user nhờ viết **deliverable**: báo cáo, tài liệu, email gửi người khác, MR/PR description, bài viết, tóm tắt dài. Không dùng cho chat vận hành ngắn (status update, xác nhận, hỏi đáp); chỗ đó chỉ cần 3 luật lõi ở "Phạm vi áp dụng". Không dùng để rewrite text AI có sẵn; đó là việc của `humanizer`.

## Phạm vi áp dụng (3 tầng)

1. **Mọi lúc, kể cả chat (3 luật lõi):** không em dash có khoảng trắng hai bên; không bịa dữ kiện; không "đẹp nhưng rỗng" trong văn bản người khác đọc thay user (puffery, kết luận tóm tắt lại, khuôn "không chỉ...mà còn").
2. **Deliverable (full workflow + script):** báo cáo, docs, email, MR/PR description, bài viết. Chạy đủ 4 bước workflow và checklist.
3. **Chat vận hành:** giữ ngắn, thẳng, cấu trúc ("robot hiệu quả"). Đây là register chuẩn của senior dev; không cần humanize từng reply.

Viết như người thật, không như model. Áp dụng cho văn bản phát hành (deliverable): báo cáo, tài liệu, email, MR/PR description, bài viết. Không ngoại lệ, kể cả văn bản "nội bộ".
Nguồn: Wikipedia:Signs of AI writing (WP:AISIGNS); bản đầy đủ 17 mục: `~/Documents/AI-free-writing-rules.md`.
Text AI có sẵn cần sửa → dùng skill `humanizer` (rewrite + voice calibration), không phải skill này.

## Workflow bắt buộc

1. Viết draft với nội dung thật: số liệu, tên, ngày, nguồn. Không có dữ kiện → nói thẳng "chưa có số liệu", không bịa, không thay bằng tính từ.
2. Tự kiểm tra: chạy `python3 ~/.hermes/skills/writing/ai-free-writing/scripts/check_ai_isms.py <file>` (hoặc dán text vào stdin). Sửa mọi vi phạm tìm thấy.
3. Quét tay các mục HARD BAN mà script không bắt được (khuôn câu, giọng điệu, rule of three).
4. Chỉ giao bài khi checklist "Trước khi giao" sạch 100%.

## HARD BAN: từ vựng (cấm tuyệt đối, EN + VI)

- **Từ nối đầu câu:** Additionally, Moreover, Furthermore, Consequently, Notably, "Đáng chú ý là", "Hơn nữa", "Ngoài ra"/"Bên cạnh đó" (quá 1 lần/đoạn), "Tóm lại", "Có thể thấy rằng".
- **Từ vựng AI:** delve, tapestry, testament, pivotal, crucial, vital, underscore, emphasize, highlight, showcase, vibrant, bolster, foster, enhance, garner, intricate, interplay, meticulous, enduring, deep dive, align with, boasts, features (nghĩa "has"), serves as, stands as, functions as, key (thay "important"), evolving landscape, groundbreaking, seamless, cutting-edge.
- **Tiếng Việt:** "đóng vai trò then chốt", "minh chứng rõ ràng", "bước ngoặt", "bức tranh toàn cảnh", "dấu ấn khó phai", "ăn sâu", "chìa khóa thành công", "nền tảng vững chắc", "đồng hành cùng", "thúc đẩy"/"nâng cao"/"tăng cường" (khi thừa), "không ngừng phát triển", "khẳng định vị thế".
- **Thay bằng:** nói thẳng "là/có"; từ đơn giản trước (used/utilized, wrote/authored, làm/"triển khai thực hiện").

## HARD BAN: khuôn câu & giọng điệu

- Cấm: "không chỉ X mà còn Y", "không phải X mà là Y" (đính chính kịch tính), "not only X but also Y".
- Cấm rule of three: 3 tính từ / 3 cụm cân đối đứng cạnh nhau. Phá nhịp hoặc liệt kê 2/4 mục.
- Cấm elegant variation: đổi từ đồng nghĩa chỉ để né lặp; lặp từ là tự nhiên.
- Cấm ca ngợi/nhấn mạnh tầm quan trọng không kèm dữ kiện; cấm nối chủ đề với "xu hướng lớn hơn / ngành / xã hội" không nguồn.
- Cấm khẳng định tuyệt đối không nguồn: "duy nhất", "tốt nhất", "đầu tiên".
- Cấm kết luận tóm tắt lại phần thân; kết luận phải chứa thông tin mới.
- Cấm "canned list": header đậm + dấu hai chấm + dòng mô tả đều tăm tắp (trừ khi user yêu cầu format list).

## HARD BAN: dấu câu

- Cấm em dash có khoảng trắng hai bên (space + em dash + space). Dấu hiệu AI số 1.
- Tối đa 1 em dash / 500 từ; cấm 2 em dash trong 1 câu. Ưu tiên: dấu phẩy > ngoặc đơn > dấu hai chấm > em dash.

## Bắt buộc phải làm

- Câu ngắn (≤12 từ) xen câu dài; cấm 3 câu liên tiếp cùng cấu trúc.
- Hedging thật khi không chắc: "có thể", "theo dữ liệu hiện có", "chưa rõ".
- Mỗi đoạn 3+ câu phải có ≥1 chi tiết không đoán trước được (số, tên, ngày).
- Đọc to trước khi gửi; câu nào ChatGPT sinh ra nguyên vẹn được → phải viết lại.

## Trước khi giao: checklist sạch 100%

- [ ] Không từ nào trong blacklist (script chạy exit 0).
- [ ] Không em dash spaced; ≤1 em dash / 500 từ.
- [ ] Không khuôn "không chỉ…mà còn" / "không phải…mà là".
- [ ] Không rule of three / elegant variation.
- [ ] Mọi ca ngợi đều có dữ kiện kèm.
- [ ] Không khẳng định tuyệt đối không nguồn.
- [ ] Kết luận có thông tin mới, không tóm tắt lại.
- [ ] Có hedging thật; câu ngắn xen câu dài.
- [ ] Mỗi đoạn 3+ câu có chi tiết cụ thể.

## Pitfalls

- "Đẹp" là dấu hiệu nguy: câu càng trôi chảy, cân đối, nhịp nhàng, càng phải soi kỹ.
- Không bịa dữ kiện để "cụ thể hóa"; thiếu thì nói thiếu.
- Script bắt từ vựng + dấu câu, KHÔNG bắt được giọng điệu/khuôn câu; bước 3 workflow là bắt buộc, không bỏ qua.
- Viết ngôn ngữ nào cũng quét cả blacklist EN lẫn VI (AI-ism tiếng Việt: "đóng vai trò then chốt", "minh chứng"...).
- User yêu cầu giọng "trang trọng" không phải giấy phép dùng blacklist; trang trọng ≠ AI-ism.
- Lặp từ là tự nhiên; không "làm giàu vốn từ" bằng từ điển đồng nghĩa.
