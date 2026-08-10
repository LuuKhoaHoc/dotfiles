# Placeholder-class audit — recipe + sweep 2026-08-10

Mục tiêu: tìm input/textarea/select/date-picker có class placeholder "màu đậm" (đậm gần bằng text value → user tưởng value đã nhập). READ-ONLY task.

## Grep (bắt buộc qua terminal MSYS — search_files hay lỗi IO os error 3 với path Windows)

```bash
cd /c/Users/luukhoahoc/Dev-Work/Hilo/erp-admin
# pattern chính — nhớ !? để bắt biến thể important "placeholder:text-text-caption!"
grep -rnE "placeholder:text-(text-caption!?|text-subtitle|subtitle|text-muted|text-body)" \
  apps/hr apps/employee apps/shell --include="*.tsx" --include="*.ts" \
  | grep -vE "/dist/|__mf__temp"
# variant shadcn Select trigger (data-attribute, KHÔNG phải pseudo-class) — grep riêng
grep -rn "data-placeholder:text" apps/hr apps/employee apps/shell --include="*.tsx" | grep -vE "/dist/|__mf__temp"
```

Lọc thêm: bỏ các file đã biết đã sửa xong (vd `BulkAttendanceCreateDialog.tsx`). File .ts cũng bắt (className constant có thể nằm ở constants/styles.ts).

## Context quanh match — loop per-file

`${f%%:*}` = file, `${f##*:}` = line (format `file:line`). In `-B3 -A4` để biết element tag + prop `placeholder=...`:

```bash
for f in "path/File.tsx:112" "path/Other.tsx:49"; do
  echo "===== ${f%%:*} (line ${f##*:}) ====="
  grep -n -B4 -A3 -E "placeholder:text-..." "${f%%:*}"
done
```

## Resolve i18n literal — recursive JSON walk, KHÔNG dotted-path lookup

Dotted-path lookup theo `t('features.x.y.placeholders.note')` TRẢ `{}` ÂM THẦM khi cấu trúc lệch: keys nằm rải ở nhiều file `packages/locales/src/translations/vi/{hr,employee,shell,common}.json`, prefix `features.` không nhất quán giữa các namespace. Dùng walk đệ quy match tail segment:

```python
import json, os
base = r'...\packages\locales\src\translations\vi'
targets = {"searchPlaceholder","note","approvalWorkflowNote","attachmentsDescriptionPlaceholder",
           "reasonPlaceholder","businessTripReason","leaveReason","reason","wfhReason",
           "country","currentPassword","newPassword","confirmNewPassword"}
def walk(node, path, out):
    if isinstance(node, dict):
        for k,v in node.items(): walk(v, path+[k], out)
    elif isinstance(node, str):
        if path and path[-1] in targets and len(path) >= 4:
            out.append((".".join(path[-5:]), node[:100].replace('\n',' ')))
out = []
for fn in ['hr.json','employee.json','shell.json']:
    walk(json.load(open(os.path.join(base,fn), encoding='utf-8')), [], out)
```

Kết quả dùng đánh giá ưu tiên (placeholder ngắn "Tìm kiếm" vs câu hướng dẫn dài "Tối thiểu 6 ký tự, gồm chữ in hoa...").

## Phân loại ưu tiên

- **P1**: field trong dialog form (textarea ghi chú lý do, password) — placeholder đậm trong dialog dễ nhầm value nhập sẵn; placeholder là câu hướng dẫn dài (vd quy tắc password) càng P1.
- **P2**: search input (placeholder ngắn rõ ràng là hint), display read-only, select disabled/view-mode.

## Pitfalls đã học

- `placeholder:` pseudo-class **inert trên plain div** — div display-only (box hiển thị thời gian/lý do kèm span text thay placeholder) có class `placeholder:text-text-muted` là class chết, xóa được; KHÔNG coi là input thật.
- **Hằng class dùng chung**: `DIALOG_TEXTAREA_CLASS` (apps/hr/src/features/organizations/constants/styles.ts:34, import qua `@hilo/shared`, ~7 dialog departments/job-ranks dùng), `textAreaClassName` (apps/employee/.../CreateAttendanceAdjustmentRequestDialog.tsx:174). Sửa 1 chỗ = sạch nhiều dialog; khi liệt kê chỗ cần sửa, chỉ liệt kê định nghĩa + số usage.
- Textarea placeholder value `DEFAULT_PLACEHOLDER_STRING` = `'---'` (packages/shared/src/constants/common.ts:4) — dùng ở edit-request-dialogs khi không có value.
- Element type: className có `min-h-2x` + `resize-none` ⇒ Textarea; có `suffix=` prop ⇒ Input (search); `data-placeholder:` ⇒ Select trigger; `type="password"` ⇒ password Input.

## Kết quả sweep 2026-08-10 (24 chỗ, 15 P1 / 9 P2)

File:line (đầy đủ class trong SKILL context trước đó):
- P1 — apps/hr: EffectiveAndNoteSection.tsx:113 (textarea note), BasicInfoSection.tsx:279 (textarea note), ApprovalWorkflowNoteField.tsx:24 (textarea), CreateWorkScheduleDialog.tsx:428 (CountrySelect "Chọn quốc gia..."), styles.ts:34 hằng DIALOG_TEXTAREA_CLASS, LeaveRequestAttachmentsBlock.tsx:78 (textarea).
- P1 — apps/employee: CreateAttendanceAdjustmentRequestDialog.tsx:174 (hằng textAreaClassName), AttendanceAdjustmentFields.tsx:96, BusinessTripFields.tsx:49, LeaveFields.tsx:183, OvertimeFields.tsx:51, RemoteWorkFields.tsx:110 (textarea reason).
- P1 — apps/shell: ResetPasswordDialog.tsx:163/179/195 (password inputs — 179 là câu hướng dẫn dài).
- P2 — search: BulkAttendanceEmployeeTab.tsx:112, FieldSelector.tsx:127, TopbarSearch.tsx:25. Display read-only: EarlyLeaveFields.tsx:37/52, LateArrivalFields.tsx:40/55 (div + textarea '---'), InfoField.tsx:69. Select disabled: CreateWorkScheduleDialog.tsx:418.

Lần sweep sau: chạy lại grep, so kèm danh sách này, mục tiêu còn lại = các dòng P1 chưa sửa.