---
title: '[feat/refactor/fix/chore]: [Tên ngắn gọn của plan]'
type: [feat | refactor | fix | chore]
status: active
date: YYYY-MM-DD
---

# [feat/refactor/fix/chore]: [Tên ngắn gọn của plan]

## Summary

[Tóm tắt ngắn gọn mục tiêu của plan, thay đổi này làm gì và giải quyết vấn đề gì].

---

## Requirements

- R1. [Yêu cầu 1]
- R2. [Yêu cầu 2]

---

## Scope Boundaries

- [Những gì nằm ngoài phạm vi, không làm trong plan này]
- [Giới hạn biên dịch hoặc biên kiến trúc]

---

## Context & Research

### Relevant Code and Patterns

- [Đường dẫn file liên quan 1](file:///đường-dẫn-tuyệt-đối) — [Giải thích liên quan]
- [Đường dẫn file liên quan 2](file:///đường-dẫn-tuyệt-đối) — [Giải thích liên quan]

### Institutional Learnings

- [Các bài học kinh nghiệm tìm được từ docs/solutions/ hoặc AGENTS.md liên quan trực tiếp đến vấn đề này].

---

## Key Technical Decisions

- **[Quyết định kỹ thuật 1]**: [Mô tả và lý do chọn giải pháp này thay vì giải pháp khác, tradeoffs].
- **[Quyết định kỹ thuật 2]**: ...

---

## Implementation Units

---

- U1. **[Tên đơn vị thực thi 1]**

**Goal:** [Mục tiêu của unit]

**Requirements:** R1...

**Dependencies:** [Các unit phụ thuộc trước đó]

**Files:**
- Modify: `[file path]`
- New: `[file path]`

**Approach:**
[Cách tiếp cận chi tiết, giải thuật, hàm cần sửa/viết]

**Verification:**
- [Lệnh test hoặc các bước kiểm tra thủ công để xác minh U1 hoạt động]

---

- U2. **[Tên đơn vị thực thi 2]**
...

---

## System-Wide Impact

- **Interaction graph**: [Tương tác với các module/component khác trong monorepo thế nào]
- **API surface parity**: [Thay đổi API thế nào nếu có]
- **Unchanged invariants**: [Những gì sẽ KHÔNG bị thay đổi hoặc phá vỡ]

---

## Risks & Dependencies

| Risk | Mitigation |
| :--- | :--- |
| [Rủi ro tiềm ẩn] | [Biện pháp giảm thiểu] |
