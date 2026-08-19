---
name: i18n-raw-key-debugging
description: Use when UI shows a raw i18n key instead of translated text.
---

# Debug raw i18n key rendering

## Trigger

User reports "text hiện nguyên key" / "render raw" / "thiếu i18n" — a value like
`requests.actions.viewDetail` or `common.status.waiting` appears verbatim in the UI instead
of a translated label. Common in i18next + React (useTranslations / t('key')) apps.

## Root cause — namespace mismatch (most common)

The component calls `t('<namespaceA>.<leaf>')` but the locale file defines the key under a
**different namespace `<namespaceB>.<leaf>`**. `t()` returns the key string when the path is
missing, so a single wrong-namespace call silently renders the raw key. The header/confirm
labels in the same component may look fine (correct namespace) while menu items are broken
(wrong namespace) — a tell-tale mixed pattern.

## Debug workflow

1. **Confirm the symptom is real** — read the component's `t('...')` calls and the exact key it emits.
2. **Locate the locale file(s)** — often NOT app-local. Find with
   `find <repo> -path '*translations*' -name '<lang>.json'` (e.g. `packages/locales/src/translations/{vi,en}/*.json`).
3. **Prove which namespace actually exists** — do NOT trust a dotted-path string lookup (it silently returns `{}` on a missing branch). Use a recursive JSON walk or parse:
   ```bash
   cat <lang>.json | python3 -c "import sys,json;d=json.load(sys.stdin);r=d.get('requests',{});print('actions:', 'actions' in r, 'actionMenu:', 'actionMenu' in r, list(r.get('actionMenu',{}).keys()))"
   ```
   This gives a hard True/False for the suspect namespaces.
4. **Grep the codebase for the CORRECT namespace** — the deciding signal:
   ```bash
   grep -rn "<namespaceB>\." apps/*/src   # correct namespace, used in many places
   grep -rn "<namespaceA>\." apps/*/src   # wrong namespace, isolated to 1 place
   ```
   If the wrong namespace appears in exactly one component while the right one is used
   everywhere else, that component is almost certainly the bug.
5. **Fix**: rewrite the `t()` keys to the namespace that exists. Confirm the key (vi AND en) after fixing.

## Check both locales + cross-MFE

- Verify the key in **both** `vi` and `en` — a missing `en` key renders raw only in English.
- The same component may be **duplicated across MFEs** (e.g. an `ApprovalListSection` in both
  employee and hr apps) — one version may use a different label resolver than the other.
  Check both before assuming the bug is isolated.

## Fallback-chain resolution

Status/label mappers often use a fallback chain (`feature-specific key → shared map → common.*`).
When reporting "raw key", check each link:
- Is the leaf present in the feature namespace? (if yes, earlier link resolves → likely already fixed)
- Is it in the shared map constant?
- Is it in the common/global namespace?
If the first link exists, the symptom may already be resolved on the latest branch — verify
against the newest code before filing the fix, and add the missing leaf to the shared map /
common namespace as hardening against the link being removed.

## Shared status-label util vs inline interpolation (Hilo ERP, 2026-08)

Two render patterns with different failure modes — check BOTH when sweeping "status shows raw":

1. **Inline interpolation without fallback** → FULL raw key in UI (worst): `t(\`features.X.statuses.${status}\`)` — e.g. `useLeaveRequestColumns.tsx` (`timeOffManagement.statuses`), `useChangeManagementColumns.tsx` + filters + change-content section (`changeManagement.statuses`).
2. **Shared `getStatusLabel` (`packages/shared/src/utils/status.ts`)** → renders the **raw status string** (not the key): `tCommon(\`status.${key}\`, { defaultValue: status })` — i18next 2-arg fallback. Consumers: HR request-management columns, employee requests columns/inbox/handled, `ApprovalListSection` (HR + employee), dashboard summaries.

**BE status-code drift (real case, issue #188):** BE trả `canc` (không phải `cancelled` như `REQUEST_STATUS.CANCELLED`) cho đơn bị hủy → raw key ở pattern 1, "canc" thô ở pattern 2. Fix family: thêm `canc` key vào namespace liên quan (`timeOffManagement.statuses`, `changeManagement.statuses`, `common.status`) en+vi, + `cancelled` hardening, + xác nhận BE canonical value. Sweep cả 2 MFE (HR + employee) khi cùng 1 status enum.

## Erp-admin worked example

Real case: `requests.actions.*` vs `requests.actionMenu.*` namespace mismatch in the employee
MFE attendance-adjustment list action column — details in `references/erp-employee-mfe-2026-08-10.md`.

## References

- `references/erp-employee-mfe-2026-08-10.md` — full worked example: i18n raw-key + standard
  row-action component (`TableOptionMenu` vs inline DropdownMenu) + approval-status fallback
  chain + nav-button-on-list pattern findings in the Hilo ERP employee MFE.
