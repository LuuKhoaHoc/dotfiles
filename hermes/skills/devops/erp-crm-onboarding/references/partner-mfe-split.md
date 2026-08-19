# Tách MFE mới trong erp-admin (case study: partner, 14/08/2026)

Khi nào tách: BA xác nhận module riêng + sidebar có mục riêng + domain lớn (nhiều feature area). Trong repo này **module == MFE** (navigation.ts `mfeMatchPath` khớp remote shell) — BA nói "module" nghĩa là tách MFE.

Thời điểm rẻ nhất: **TRƯỚC khi commit** code feature (working tree) — move folder, không rewrite. Chờ spec feature sau về rồi tách = khối lượng di chuyển gấp 2-3 lần.

## Checklist (pattern `apps/product` — MFE CRM nhỏ nhất có requiresCrmContext)

1. **Workspace** `apps/<name>/`: package name = `<name>`; copy `vite.config.ts`, `tsconfig{,.app,.node}.json`, `eslint.config.mjs`, `index.html` từ apps/product; sửa base path.
2. **Shell registry** — `apps/shell/src/registry/mfe-manifest.ts`: thêm `{ id, federationName, envKey: 'VITE_<NAME>_REMOTE_URL', fallbackBase: '/apps/<name>' }` + route loader `apps/shell/src/registry/entries.tsx`.
3. **Navigation** — `packages/shared/src/config/navigation.ts`: module mới `{ id, path: PATHS.<NAME>, mfeMatchPath: '<name>/*', categoryId, requiresCrmContext: true, features: [...] }`; bỏ feature entry khỏi module cũ.
4. **PATHS** — `packages/shared/src/constants/paths.ts`: thêm `<NAME>: '/<name>'` + `<NAME>_DETAIL: '/<name>/:id'`; XÓA path cũ (vd `SALE_PARTNERS`).
5. **Locales** — namespace `<name>.json` mới (vi+en): move toàn bộ keys từ namespace cũ; đăng ký namespace vào i18n bundle `packages/locales`; nav nameKey `modules.<name>.*` vào common.json.
6. **Shared components** — component feature đang import từ `apps/<old>/src/shared` (vd `StatusBadge`) → move lên `@hilo/ui` khi ≥2 MFE dùng.
7. **CI/deploy** — image tag cho apps mới theo convention GitLab CI hiện có.
8. **Label GitLab** — tạo `MFE::<id>`: `glab label create --name "MFE::<id>" --color "#6699cc"` (bắt buộc `--name`, không positional); đổi labels issue: `glab issue update <iid> --label "MFE::<id>" --unlabel <label-cũ>`.
9. **Dọn MFE cũ** — xóa routes khỏi App.tsx cũ, bỏ nav feature entry, xóa PATHS cũ, xóa imports.
10. **Verify** — vitest feature + shared endpoints test; typecheck cả 2 MFE + shared + locales; `pnpm --filter <new> build`.

## Lưu ý quan trọng

- **Contracts đã ở @hilo/shared** (endpoints, DTO types, `QUERY_KEYS.CRM.*`) → MFE mới gọi trực tiếp; "gọi API bên product" = `import { API_ENDPOINTS, QUERY_KEYS } from '@hilo/shared'` (vd `API_ENDPOINTS.PRODUCT.PRODUCTS` + `product.types.ts`), KHÔNG có khái niệm MFE gọi API của MFE khác.
- FSD feature folder + `index.ts` public boundary → move nguyên cục, không sửa logic.
- Khi code feature đang nằm trong working tree chưa commit của người khác: nhắc agy **tạo branch từ working tree**, và chỉ rõ các file modified của công việc khác (hr/employee/shell...) **không được đụng**.
- Issue scope-change: ghi `## Scope change (BA chốt <date>)` + `[!IMPORTANT]` block vào đầu description, giữ AC cũ + bổ sung AC mới (chuyển issue thành "base" cho module mới).
