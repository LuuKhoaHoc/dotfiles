---
name: erp-admin-mfe-boundaries
description: Use when working with erp-admin MFE cache/auth boundaries.
version: 1.0.0
author: hermes-curator
license: internal
metadata:
  tags: [erp-admin, micro-frontend, react-query, cache, auth, shell-remote]
  related_skills: [grilling, erp-admin-fe-workflow, codebase-reconnaissance]
---

# erp-admin MFE Runtime Boundaries

## When to Use

- Cache invalidation / data isolation phải chạm nhiều MFE (switch context, đổi scope làm việc) — biết rằng mỗi MFE có QueryClient riêng.
- Hỏi "shell có xóa được cache/state của remote không" hay thiết kế cơ chế shell → remote.
- Làm việc với auth (cookie, refresh, interceptor queue pattern) hoặc `useAuthStore` persist.
- Tiếp tục một issue từ handoff file `~/Documents/ERP/issue-<id>-*.md` (grill/implement tiếp).

Facts verified from code (2026-08-12) — architecture ground truth for any task touching shell↔remote state, cache, or auth in the erp-admin monorepo (`~/Projects/Hilo-Vppos/erp-admin`).

## 1. Mỗi remote MFE có QueryClient RIÊNG (module scope)

- Mỗi `apps/<mfe>/src/main.tsx` tạo `new QueryClient(...)` ở module scope + `QueryClientProvider` riêng.
- Shell KHÔNG với tay vào cache của remote: `queryClient.removeQueries(...)` chạy ở shell chỉ tác động lên client của shell.
- QueryClient module-scope **sống sót qua remount React tree** — đổi `key` trên container remote KHÔNG xóa cache của nó.
- Query keys các MFE là feature-local, KHÔNG có prefix chung (vd `['orders']` trong sale, `REPORTS_DASHBOARD_QUERY_KEY` trong finance); `packages/shared/src/api/query-keys.ts` chưa có prefix `crm` hay `['crm', ...]` nào.

## 2. Auth model: cookie-based, không token trong localStorage

- `apiClient` dùng `withCredentials: true` (cả `packages/shared/src/api/axios.ts` và `createApiClient`); BE ưu tiên cookie `access_token`.
- `useAuthStore` persist key `hilo-auth-v2` chỉ lưu `user` + `language` qua `partialize` — KHÔNG có token.
- 401 → refresh qua `/auth/refresh` + failedQueue pattern đã có sẵn trong axios response interceptor (kèm cờ `_retry`, chống loop). Mẫu này dùng lại được cho bất kỳ interceptor "giữ request + chờ hành động user + replay" nào (vd 403 CRM-403-004).

## 3. Hệ quả thiết kế — context-scoped data isolation

Khi cần nuke dữ liệu theo scope (switch CRM context, đổi đơn vị làm việc) và dữ liệu nằm trong cache của remote MFE:

- **Option A (khuyến nghị, KISS)**: full `window.location.reload()` sau màn hình chuyển trạng thái/animation — nuke sạch cache mọi MFE, zero refactor, không thể rò rỉ dữ liệu giữa 2 scope.
- **Option B**: refactor toàn bộ query keys về prefix chung + mỗi MFE tự gọi `removeQueries` trên client của chính nó (effect subscribe vào shared store) — đụng nhiều MFE, chỉ đáng làm khi thao tác switch tần suất cao cần giữ SPA state.
- Không có cách nào từ shell xóa cache remote "sạch" mà không reload.

## 4. Cross-agent handoff pattern

- Handoff file: `~/Documents/ERP/issue-<id>-<slug>-handoff.md` (markdown: decisions đã chốt + câu hỏi dang dở + suggested skills + domain terms).
- Flow: agent trước (agy/antigravity IDE) grill → ghi handoff → Hermes đọc + tiếp tục (skill `grilling`).
- Khi tiếp tục grill: tra cứu fact trong repo/BE spec TRƯỚC khi hỏi (fact → tự look up; decision → hỏi user), KHÔNG hỏi lại điều handoff đã chốt; trạng thái repo kiểm tra lại bằng grep vì có thể chưa có gì được implement.

## Tracing regressions in shell chrome (git archaeology)

When a user reports shell UI vanished/regressed (bell, topbar item, nav behavior) and current code no longer has it, find the exact commit BEFORE writing the issue:

1. `git log --all --oneline -S "SymbolName" -- apps/shell/src` — commits that added/removed the symbol (component/import/CSS-class names all work).
2. `git show <commit>` — exact diff; `git grep -l "SymbolName" <commit>` — usages at that point in time (symbol found only in its own file = dead code, its deletion is NOT the regression).
3. `git show <commit>^:<path>` — file content before the change → the "restore spec" for the issue body.
4. Cite commit + author in the issue's References so the regression is attributable. Same-author consecutive commits often pair an intended change with a collateral one (worked example: bell regression `0b0b5749f` vs dead-code cleanup `3356be031`, issue #186 — see `references/shell-mobile-navigation.md`).

## References

- `references/crm-context-selection.md` — BE contract + FE state cho issue #182 (CRM context selection & guard).
- `references/shell-mobile-navigation.md` — shell mobile topbar/bottom-nav/profile anatomy + noti bell regression commits (issue #186).
