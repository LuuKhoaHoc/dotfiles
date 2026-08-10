# Placeholder color conventions (erp-admin)

**Token placeholder chuẩn của design system = `placeholder:text-muted-foreground`** (mặc định có sẵn trong `@hilo/ui` `Textarea`/`Input`). Các class `placeholder:text-text-caption` / `placeholder:text-text-subtitle` / `placeholder:text-text-muted` / `placeholder:text-text-body` / `placeholder:text-subtitle` là **màu đậm gần giống value thật** — user nhìn nhầm placeholder thành giá trị đã nhập (bug UX, real case 2026-08-10: Textarea "Lý do thực hiện chấm công hàng loạt..." trong BulkAttendanceCreateDialog).

## Quy tắc

- Mọi input/textarea/select khi cần override placeholder → dùng `placeholder:text-muted-foreground`. Không dùng token `text-text-*` cho placeholder.
- Custom select dùng `data-placeholder:text-*` variant (vd CountrySelect) → đổi cả 2: `data-placeholder:text-muted-foreground` + `placeholder:text-muted-foreground` (nếu có).
- Bỏ class placeholder trên **div/span** — vô tác dụng (không phải input), không gây nhầm.

## Đòn bẩy (sửa 1 chỗ chạm nhiều nơi)

- `apps/hr/src/features/organizations/constants/styles.ts` — `DIALOG_TEXTAREA_CLASS` (~13+ org dialogs). Kiểm tra có bản sao trong `@hilo/shared` không.
- `@hilo/ui` `Textarea`/`Input` mặc định đã có `placeholder:text-muted-foreground` — component wrapper KHÔNG override (vd `DayDialogTextareaFormField`) đã chuẩn, không cần sửa.
- `DateSelectPicker` render placeholder qua span riêng (`text-muted-foreground/40` khi empty) — class `placeholder:*` truyền từ ngoài áp lên Button wrapper, vô tác dụng; sửa không hại.

## Quét toàn repo (pattern tìm chỗ còn đậm)

```bash
grep -rnE "placeholder:text-(text-caption!?|text-subtitle|subtitle|text-muted|text-body)" apps/ --include="*.tsx" | grep -v dist
```

Xử lý batch: `sed -i` per-file với 5 pattern → `placeholder:text-muted-foreground` (danh sách file từ subagent scan, không sed toàn app — tránh đụng chỗ chưa xác nhận). Verify: prettier --check + eslint + `tsc -b` 3 apps (hr/employee/shell).
