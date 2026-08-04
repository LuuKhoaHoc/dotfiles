# Worked example: Hilo erp-admin MFE monorepo AGENTS.md audit

Repo: `apps/shell` (host) + remotes (`hr`, `employee`, `sale`, `finance`, `product`, `apps-dashboard`). AGENTS.md hierarchy: root guide, `apps/*/AGENTS.md`, `packages/*/AGENTS.md`, `apps/*/src/features/*/AGENTS.md`. Local overrides root, nearest wins.

## The 3-way remote-status check (source-of-truth files that must agree)

To know whether an MFE is configured/active/mounted, read all three:

1. `apps/shell/src/registry/mfe-manifest.ts` → `MFE_REMOTE_CONFIGS` (Vite remote config; `apps/shell/vite.config.ts` imports it and generates remotes).
2. `apps/shell/src/registry/entries.tsx` → `MFE_LOADERS` (host-side dynamic imports) + `MFERegistry` (filters `APP_MODULES` by `enabled` && loader present).
3. `packages/shared/src/config/navigation.ts` → `APP_MODULES` (`enabled`, `mfeMatchPath`, `showInCatalog`).

Root AGENTS.md claimed "remotes active are hr + employee; apps-dashboard in MFE_REMOTE_CONFIGS but not in MFE_LOADERS (not mounted)". That was STALE: by audit time `MFE_LOADERS` had all 6 remotes (`apps-dashboard, hr, employee, sale, finance, product`) and all were `enabled: true` in `APP_MODULES`. → apps-dashboard is mounted. Flag for the root-guide owner (out of a subagent's scope).

## Stale claims found and the evidence

| Guide | Stale claim | Evidence it was stale | Fix |
|---|---|---|---|
| `apps/shell/AGENTS.md` | STRUCTURE lists `services/ # Shell-only services` | `search_files` on `src/services` → "Path not found" | Swap line for real sibling `features/` (exists, holds login/profile/init-password/forgot-password) |
| `apps/shell/AGENTS.md` | "Add remote declaration → `vite.config.ts`"; "`vite.config.ts` is host source of truth for federation remotes" | `shell/vite.config.ts:7` imports `MFE_REMOTE_CONFIGS` from manifest | Point to `src/registry/mfe-manifest.ts` |
| `apps/shell/src/registry/AGENTS.md` | Role mentions "style loader wiring"; WHERE TO LOOK row "Add remote stylesheet support → `entries.tsx` / `MFE_STYLE_LOADERS`"; convention "keep component + stylesheet loading aligned"; verification "or style wiring" | Grep whole shell: `MFE_STYLE_LOADERS` exists ONLY in AGENTS.md. `entries.tsx` has `MFE_LOADERS` only. Shell doesn't inject styles; remotes self-import via mfe-entry side-effect (e.g. `apps-dashboard/src/mfe-entry.tsx:1` imports `./federated.css`) | Remove all style-loader references |
| `apps/shell/src/features/profile/AGENTS.md` | "Change loading states → `components/skeletons/`" | No `skeletons/` dir in feature; loading skeleton rendered inline in `PersonalInformationDialog.tsx` via `ProfileFormDialogSkeleton` from `@hilo/ui` | Point to the dialog file + shared component |
| `apps/shell/src/features/profile/AGENTS.md` | "Change alert/unsaved flow → `components/PersonalAlertDialog.tsx`" | File does not exist; unsaved flow uses `UnsavedChangesDialog` from `@hilo/ui` in `PersonalInformationDialog.tsx` | Point to dialog file + shared component |
| `apps/shell/src/features/profile/AGENTS.md` | Convention "Skeletons and alert flows ... keep them colocated here" | Both are shared `@hilo/ui` components now, not colocated | Reword to "implement via shared @hilo/ui, no local duplicates" |
| `apps/apps-dashboard/AGENTS.md` | Role "Small workspace today"; STRUCTURE missing `ModuleDetail.tsx`, `main.tsx`, `federated.css`, `config/`; WHERE TO LOOK only lists `AppsDashboard.tsx` | App grew: `App.tsx` has routes index → AppsDashboard + `:moduleId` → ModuleDetail; `main.tsx` standalone bootstrap (`MfeStandaloneWrapper`); `federated.css` imported by mfe-entry; `config/icon-registry.ts` | Drop "small workspace", add real files/pages to STRUCTURE + WHERE TO LOOK |

## Claims that verified OK (left untouched — "accurate but incomplete" is not stale)

- `apps/shell/src/features/login/AGENTS.md` — every file/symbol/constant matched (`useLoginFlow.ts`, `api/auth.ts`, `constants/index.ts` = `LOGIN_STEPS` check/password, `schemas/login-schema.ts`, OAuth/step-form/notification components, `types/`). `useLoginFlow.ts` uses `PATHS.FORGOT_PASSWORD` from `@hilo/shared` (no hardcoded routes). Minor: `LoginNotificationCard.tsx` actually handles 3 variants (accessDenied, initPassword, resetPassword) while the guide lists 2 — not wrong, flag only.
- apps-dashboard contract numbers: `name:'appsDashboard'`, `base:'/apps/dashboard/'`, `port:5004`, expose `./App` → `src/mfe-entry.tsx` — all confirmed in `apps/apps-dashboard/vite.config.ts`. `package.json` has no `test` script, so "No dedicated local test command" stayed true even though `src/pages/AppsDashboard.spec.tsx` exists (spec unrunnable locally → flag).

## Report format (delivered in Vietnamese for this repo)

Per-file table: `File | Đã sửa gì (dòng cũ → mới + lý do + bằng chứng) | Verified OK`.
End with a "Điểm CHƯA chắc chắn — cần human review" section (out-of-scope stale root guide, unrunnable spec, incomplete-but-not-wrong claims). State clearly: no commit, no branch, `git status` shows only the assigned AGENTS.md files changed.

## Later audit: `apps/employee` guide set (4 files)

Assigned as one subagent; the sibling `root`, `hr`, `shell`, `apps-dashboard`, `locales`, `ui` guides were being edited by parallel subagents simultaneously — scope `git diff` to your own files only.

| Guide | Stale claim | Evidence | Fix |
|---|---|---|---|
| `apps/employee/AGENTS.md` | Routes listed `dashboard, organization, labor contract, leave, requests, attendance` | `App.tsx:14-21` routes are `directory`, `organization`, `labor-contract`, `requests`, `time-off-management`, `attendance`. Page `LeavePage.tsx` sits at route path `time-off-management`. No `leave` route. | Replace route list; note route-vs-filename drift |
| `apps/employee/AGENTS.md` | Remote exposure = `./App` only | `vite.config.ts:39-43` also exposes `./LeaveBalanceDialog` from `src/features/time-off-management/components/dialogs/LeaveBalanceDialog.tsx` | Add the second expose (flag as an addition beyond correction) |
| `apps/employee/src/features/requests/AGENTS.md` | WHERE TO LOOK pointed at `apis/requests.ts`, `hooks/useCreateAttendanceAdjustmentRequest.ts`, `components/CreateAttendanceAdjustmentRequestDialog.tsx`, `types/attendance-adjustment-request.ts` | None exist in `features/requests`. The attendance-adjustment *create* dialog + mutation moved to `features/attendance/` (`CreateAttendanceAdjustmentRequestDialog.tsx`, `hooks/useCreateAttendanceAdjustmentRequest.ts`). `requests/apis/` has only `request-approvals.ts`. Real query options live in `hooks/useMeRequests.ts`; detail/edit dialogs in `components/detail-request-dialogs/` + `edit-request-dialogs/` | Rewrite those rows to the real files; note the moved create-flow |
| `apps/employee/src/features/attendance/AGENTS.md` | WHERE TO LOOK row `utils/attendance-display.ts`; verification path `useEmployeeAttendanceAction.test.ts` | Feature `utils/` has `attendance-history.ts` + `sync.ts` only; `attendance-display.ts` lives in `packages/shared/src/utils/attendance/`. Test file is `useEmployeeAttendanceAction.test.tsx` (`.tsx`, not `.ts`) | Point to `utils/attendance-history.ts`; fix extension |

Employee i18n note: employee uses a **dedicated `employee` namespace** — `translations/en/employee.json` + `translations/vi/employee.json` both exist. Not shared with the `hr` namespace. Verify by listing the namespace JSON files, not by guessing from key shape.

