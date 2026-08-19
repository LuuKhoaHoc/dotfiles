---
name: ba-status-report
description: "Compile GitLab progress reports for BA. Exports docx/pdf."
version: 1.0.0
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [gitlab, report, ba, docx, pdf, status]
    related_skills: ["gitlab-issues", "docx", "erp-crm-onboarding"]
---

# BA Status Report (GitLab → .docx/.pdf)

## When to Use

- User asks to compile a GitLab progress/status report to send to BA/management (HRM & CRM scope: đầu mục đang làm, ai làm gì, trạng thái, dự kiến tuần sau).
- User asks for a .docx/.pdf deliverable from project tracking data instead of a chat summary.
- Weekly planning/reporting rhythm on erp-admin (gitlab.vppos.vn, project 9).

Recurring class for Hilo ERP: user asks to compile a progress/status report to send to BA — "liệt kê đầu mục tính năng đang làm (HRM và CRM), ai làm gì - trạng thái tới đâu, dự kiến task tuần sau". Deliverable is a **.docx or .pdf file**, never markdown (user preference, corrected 2026-08-14).

## 1. Pull the data plane (glab CLI — token ở `~/.config/glab-cli/config.yml`)

```bash
# Milestone due dates (trạng thái active = chưa release)
glab api "projects/9/milestones?state=active&per_page=50" | python3 -c "import json,sys; [print(m['title'],'| due:',m.get('due_date')) for m in json.load(sys.stdin)]"
# Release mới nhất → quyết định "chờ release" vs "đã lên prod"
glab api "projects/9/releases?per_page=10" | python3 -c "import json,sys; [print(r['tag_name'], r['released_at'][:10]) for r in json.load(sys.stdin)]"
# MR mở (kèm detailed_merge_status — phát hiện conflict)
glab api "projects/9/merge_requests?state=opened&per_page=100" | ...
# MR đã merge gần đây → "ai đã merge gì" (tuần vừa rồi)
glab api "projects/9/merge_requests?state=merged&per_page=25&order_by=updated_at&sort=desc" | ...
# Lý do blocked của từng issue (đọc description, không đoán)
glab issue view 159 -R vppos-team/erp-admin -F json | ...
```

## 2. Issues opened — parse compact

MCP `mcp__gitlab__list_issues` với scope=all trả output rất lớn (39 issues ≈ 156 KB) → được persist vào `/tmp/hermes-results/*.txt` dạng `{"result": "<json string>"}` (escape). Đọc bằng python với **2 lần `json.loads`**, in bảng gọn: iid/title/assignee/labels/milestone/updated_at. Không đọc file raw.

Phân loại theo label: HRM = `HR|employee|MFE::hr`, CRM = `crm` (+ `sale`/`cks` liên quan), ngoài lề = shell/shared/apps-dashboard.

## 3. Semantics báo cáo (bẫy BA hay hỏi)

- `status::done` = **đã merge vào develop**, CHƯA release. Issue chỉ close sau prod release thành công.
- So sánh milestone (v1.0.4 due 17/08) với release tag mới nhất (v1.0.3) → câu trạng thái đúng là "Hoàn thành - chờ release v1.0.4".
- `status::blocked` / `ready-for-human` → quote blocker thực tế từ description (vd #151 cần họp bàn vướng pháp lý; #159 blocked chưa rõ lý do → đưa thành câu hỏi cho BA).
- Thêm section "Câu hỏi cần BA xác nhận" (numbered list) — gom blocker + backlog chưa phân bổ + task chờ BE.

## 4. Export .docx / .pdf (user preference — KHÔNG .md cho file gửi ngoài)

1. Viết JSON spec (docx skill): `page` A4, `footer_page_numbers: true`, custom styles, blocks: paragraph/heading/table/numbered_list.
2. **Thay emoji trạng thái (✅⛔🔵⚪🕐) bằng text plain** — Word render emoji xấu. Ví dụ: "Hoàn thành - chờ release v1.0.4", "Đang làm", "Blocked - chờ BE", "Chưa bắt đầu".
3. Tạo docx: `python ~/.hermes/skills/productivity/docx/scripts/docx_create.py spec.json out.docx`
4. Convert PDF: `soffice --headless --convert-to pdf --outdir <dir> out.docx` (LibreOffice có trên máy).

### docx pitfalls đã gặp

- `heading` với `level: 0` **invalid** → dùng `paragraph` + custom title style (`styles` với font/size/bold/color).
- `docx_read.py --text` trả `{"body": [...list...], "tables": [...], "headers": [...], "footers": [...]}` — body là LIST dưới key `body`, không phải dict `paragraphs`.
- Verify sau tạo: `docx_read.py out.docx --text` (đủ headings/tables) + `file out.pdf` (báo cáo này ≈ 7 trang, 130 KB).
- JSON spec phải UTF-8 (tiếng Việt) — script đọc UTF-8 explicit, không lỗi.

## Verification

- Nội dung dựa trên dữ liệu GitLab thực (issues/MRs/milestones/releases), không suy đoán trạng thái.
- Nêu rõ ngày snapshot + nguồn trong header báo cáo.
- Trả file qua MEDIA: path để user tải/gửi ngay.
