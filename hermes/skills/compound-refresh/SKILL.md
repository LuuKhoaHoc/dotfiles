---
name: compound-refresh
description: Maintenance skill for docs/solutions/. Use when the user wants to audit knowledge docs, clean up stale learnings, or run a refresh sweep.
disable-model-invocation: true
---

# Compound Refresh

`compound-refresh` là skill bảo trì kho tri thức `docs/solutions/`. Theo thời gian, tài liệu **drift**: path thay đổi, giải pháp thành anti-pattern, hai docs mô tả cùng vấn đề bắt đầu mâu thuẫn nhau. Skill này dọn sạch **drift** để docs trở nên đáng tin cậy.

Pairs với `compound`: `compound` _ghi nhận_ bài học mới; `compound-refresh` _bảo trì_ bài học cũ.

## Modes

Mặc định chạy **Interactive** — hỏi user ở mỗi case mơ hồ, đưa ra recommendation, chờ xác nhận trước khi thực hiện.

Thêm `mode:autofix` để bỏ qua tương tác: áp dụng toàn bộ action không mơ hồ, đánh dấu `status: stale` với `stale_reason` + `stale_date` cho case cần human review. Autofix report gồm 2 section: **Applied** (đã ghi) và **Recommended** (cần human apply, kèm full rationale).

---

## Phase 1 — Per-doc Investigation

Với mỗi file trong `docs/solutions/` (bao gồm `_archived/`):

1. Đọc frontmatter và body.
2. Grep tất cả file paths, class names, function names, import paths được nhắc đến trong doc.
3. Kiểm tra các reference đó có tồn tại trong codebase hiện tại không.
4. Ghi lại **evidence**: cụ thể những gì drift, những gì vẫn còn đúng.

**Completion criterion**: mỗi doc có một evidence list — không bỏ qua doc nào, kể cả `_archived/`.

---

## Phase 1.75 — Cross-doc Analysis

Nhìn toàn bộ document set như một nhóm:

- **Overlap**: 2+ docs cùng mô tả problem statement, solution shape, hoặc referenced files giống nhau.
- **Supersession**: doc mới hơn subsumes doc cũ hơn (doc cũ là subset của doc mới).
- **Conflict**: 2 docs hướng dẫn khác nhau cho cùng tình huống.

Ghi lại mọi cluster cần xử lý. Đây là bước mà per-doc review bỏ sót.

---

## Phase 2 — Classify với 5 Outcomes

Dùng evidence từ Phase 1 + 1.75, gán **outcome** cho từng doc. Mỗi outcome có **evidence bar** riêng:

| Outcome | Điều kiện áp dụng | Evidence bar |
|---|---|---|
| **Keep** | Accurate, useful, không overlap | Không cần action |
| **Update** | Solution đúng, nhưng paths/names drift | Có ≥1 reference cụ thể cần fix |
| **Consolidate** | 2+ docs overlap nặng | Có canonical doc được xác định; unique content trong doc bị merge không bị mất |
| **Replace** | Core guidance là misleading hoặc anti-pattern | Code hiện tại cho thấy approach hoàn toàn khác; subagent viết successor |
| **Delete** | Code đã xóa; problem domain không còn; không có citation đến doc này | Grep codebase xác nhận zero inbound reference thực chất |

**Interactive**: Với case mơ hồ, đề xuất outcome + lý do, hỏi user xác nhận trước khi sang Phase 3.

**Autofix**: Tự áp dụng Keep/Update/Delete nếu evidence rõ ràng. Consolidate/Replace → mark `status: stale` để human review.

---

## Phase 3 — Execute

Thực hiện theo outcome đã classify:

- **Update**: Sửa in-place — chỉ đụng vào phần drift, không rewrite toàn bộ.
- **Consolidate**: Merge unique content vào canonical doc, xóa doc bị subsumed. Cập nhật inbound links nếu có.
- **Replace**: Dispatch subagent (xem [REFERENCE.md](REFERENCE.md)). Xóa doc cũ sau khi subagent confirm xong.
- **Delete**: Xóa file. Không cần archive — git history là archive.

Sau khi thực hiện, sinh **Maintenance Report** (xem template ở [REFERENCE.md](REFERENCE.md)).

---

## Stale Marking

Khi drift quá sâu mà không đủ context để viết replacement ngay (subsystem đã thay đổi hoàn toàn), thêm vào frontmatter:

```yaml
status: stale
stale_reason: "[Mô tả cụ thể tại sao doc này không còn tin cậy]"
stale_date: YYYY-MM-DD
```

Không xóa content — giữ nguyên để human review sau.

---

Hướng dẫn chi tiết cách viết subagent prompt cho Replace, và Maintenance Report template: [REFERENCE.md](REFERENCE.md).
