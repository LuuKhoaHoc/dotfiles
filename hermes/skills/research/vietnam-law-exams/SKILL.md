---
name: vietnam-law-exams
description: "Answer Vietnamese law exams/homework (tình huống pháp luật)."
version: 1.0.0
author: hermes-curator
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [vietnam, law, education, exams, legal-analysis]
    category: research
---

# Vietnam Law Exams (Pháp luật đại cương & related)

Write submission-ready Vietnamese law exam/homework answers with **verified** statutory citations, then deliver as .docx/.pdf.

## When to use

- User asks to complete/help with Vietnamese university law coursework: midterms, homework, tình huống pháp luật (Pháp luật đại cương, Luật Hình sự, Luật Dân sự, Hiến pháp...).
- Deliverable: essay-style answers in Vietnamese, usually as a Word/PDF file to submit.

## Workflow

1. **Parse the question type.** Vietnamese law exams use a few recurring shapes:
   - *Khái niệm/dấu hiệu*: define the concept + enumerate dấu hiệu + phân loại.
   - *Tình huống*: identify the violation type (hình sự/hành chính/dân sự/kỷ luật) → analyze cấu thành vi phạm pháp luật (4 yếu tố) → conclude with tội danh + điều/khoản + khung hình phạt.
   - *Quan điểm* (opinion): bản chất pháp lý của hành vi → tính hợp lệ/thủ tục → hậu quả pháp lý → đánh giá chung.
2. **Verify provisions BEFORE writing** — never cite điều/khoản/điểm from memory; Vietnamese statutes change (BLHS 2015 was amended in 2017; points get re-lettered):
   - Search the exact quoted phrase (e.g. `"đầu thú là việc người phạm tội"`) — quoted statute text in results is reliable.
   - Prefer thuvienphapluat.vn, kiemsat.vn (Tạp chí Kiểm sát), official court/prosecutor sites.
   - ⚠️ Articles analyzing *draft* amendments quote NON-CURRENT text (a VKS Gia Lai piece quoted "điểm q" — that was a draft). Confirm the source discusses the current consolidated text.
   - Verify the *current* letter of each điểm (a–v) — the 2017 amendment moved provisions around.
3. **Write the structured answer** in Vietnamese, full sentences, direct-submission quality. See templates below.
4. **Deliver as file** — use the `docx` skill: write a JSON spec (custom styles `Body` Times New Roman 13pt, bold `H1/H2/H3` via paragraph blocks — paragraph blocks don't create Word outline, which is fine for exams), `docx_create.py spec.json out.docx`, validate with `docx_validate.py`, convert to PDF with `soffice --headless --convert-to pdf`. Leave a "Họ và tên / Lớp" placeholder line.
5. **Remind the student**: read and understand the answer, align wording with their giáo trình, fill in name/class — they submit under their own name.

## Answer templates

### Cấu thành vi phạm pháp luật (4 yếu tố)
1. **Khách thể** — quan hệ xã hội bị xâm hại (được pháp luật bảo vệ; name the specific right/property).
2. **Mặt khách quan** — hành vi trái pháp luật (with characteristic thủ đoạn, e.g. "lén lút" for trộm cắp) + hậu quả + quan hệ nhân quả + công cụ/phương tiện/thời gian/địa điểm.
3. **Chủ thể** — năng lực trách nhiệm pháp lý: đủ tuổi (Điều 12 BLHS: từ đủ 16 mọi tội; 14–16 chỉ tội rất nghiêm trọng trở lên hoặc tội được quy định), đủ năng lực nhận thức.
4. **Mặt chủ quan** — lỗi (cố ý trực tiếp/gián tiếp, vô ý), động cơ, mục đích.
Then kết luận: tội danh + điều khoản cụ thể + khung hình phạt.

### Dấu hiệu vi phạm pháp luật
① hành vi xác định của con người (hành động/không hành động — ý nghĩ thì không) → ② trái pháp luật → ③ có lỗi (cố ý/vô ý; loại trừ: sự kiện bất ngờ, tình thế cấp thiết, phòng vệ chính đáng) → ④ chủ thể có năng lực trách nhiệm pháp lý → ⑤ xâm hại quan hệ xã hội được pháp luật bảo vệ. Phân loại: hình sự/hành chính/dân sự/kỷ luật.

## Pitfalls

- **Đầu thú vs tự thú** (Điều 4 BLTTHS 2015): tự thú = khai báo *trước khi* tội phạm hoặc người phạm tội bị phát hiện (điểm h); đầu thú = *sau khi bị phát hiện*, tự nguyện ra trình diện (điểm i). This distinction is a classic exam trap — check the timeline in the situation.
- **Điều 51 BLHS after the 2017 amendment**: "tự thú" (điểm r khoản 1) is an automatic mitigating circumstance; "đầu thú" is only under khoản 2 — Tòa án *có thể coi* là tình tiết giảm nhẹ, phải ghi rõ lý do trong bản án. Older sources still merge them ("tự thú hoặc đầu thú") — use the current split.
- **Trộm cắp tài sản (Điều 173 BLHS)**: khoản 1 needs giá trị từ 2.000.000đ đến dưới 50.000.000đ; under 2 triệu only if aggravating points a–đ apply. Compute the value threshold before concluding.
- Đầu thú does not erase the crime — the offender still bears trách nhiệm hình sự; it only grounds leniency.
- Delivery path: `Họ và tên` placeholder + both .docx and .pdf so the user picks; name files with full diacritics (UTF-8 paths are fine).
- Academic integrity: writing the full answer is fine, but always tell the user to review, understand, and adapt it to their course materials before submitting.

## References

- `references/vietnam-law-core-provisions.md` — verified quotes of core provisions (Điều 4, 12, 17, 29, 51, 173 BLHS/BLTTHS) with amendment caveats.
