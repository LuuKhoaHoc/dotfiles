# Compound Refresh — Reference

## 1. Replace via Subagent

Khi outcome là **Replace**, orchestrator dispatch một subagent riêng (tuần tự, không song song — replacement có thể cần đọc nhiều code, parallel gây context exhaustion).

Subagent nhận:
- Nội dung doc cũ (full text).
- Evidence từ Phase 1 (những gì đã drift).
- Target path (`docs/solutions/<category>/<YYYY-MM-DD>-<slug>.md`).
- Các contract files: TEMPLATE.md từ skill `compound`, category mapping từ REFERENCE.md của `compound`.

Subagent chỉ làm một việc: viết successor hoàn chỉnh theo template chuẩn. Không cho phép nó modify doc cũ — orchestrator sẽ xóa doc cũ sau khi confirm subagent đã hoàn thành.

---

## 2. Maintenance Report Template

Sau Phase 3, tạo report (in ra terminal hoặc append vào temp file):

```markdown
## Compound Refresh Report — YYYY-MM-DD

### Summary
- Files scanned: N
- Keep: N | Update: N | Consolidate: N | Replace: N | Delete: N | Stale-marked: N

### Applied Changes

#### Updated
- `docs/solutions/<path>` — [Lý do cụ thể: file X đã được đổi tên thành Y]

#### Consolidated
- `docs/solutions/<path-A>` merged into `docs/solutions/<path-B>` — [Unique content được giữ lại: ...]
- Deleted: `docs/solutions/<path-A>`

#### Replaced
- `docs/solutions/<old-path>` → `docs/solutions/<new-path>` — [Tại sao guidance cũ là misleading]

#### Deleted
- `docs/solutions/<path>` — [Lý do: code đã xóa / không còn inbound reference]

#### Stale-marked
- `docs/solutions/<path>` — [stale_reason: ...]

### Recommended (mode:autofix only)
[Các case mà autofix không apply được, kèm full rationale để human xử lý]
```

---

## 3. Evidence Bar Quick Reference

| Outcome | Cần confirm gì trước khi thực hiện |
|---|---|
| Update | Grep tìm được path/name cũ ≠ path/name hiện tại |
| Consolidate | Xác định được canonical doc; liệt kê unique content từ doc bị merge |
| Replace | Code scan cho thấy approach khác hoàn toàn; không thể Update in-place |
| Delete | `grep -r "<slug>" docs/` trả về zero inbound citation thực chất (không tính self-reference) |

---

## 4. Scope của mỗi Phase

Trong Interactive mode, luôn khai báo scope trước khi bắt đầu:

```
Phase 1: Đang scan N docs trong docs/solutions/ (bao gồm _archived/).
Phase 1.75: Cross-doc analysis trên N docs.
Phase 2: Classify — trình bày kết quả, hỏi user với case mơ hồ.
Phase 3: Execute — thực hiện sau khi user confirm toàn bộ classify.
```

Không bắt đầu Phase 3 khi còn case chưa được user xác nhận trong Interactive mode.
