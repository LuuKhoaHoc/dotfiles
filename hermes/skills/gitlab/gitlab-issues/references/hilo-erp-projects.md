# Hilo ERP — GitLab Project Reference

## Projects

| Project | ID | Path | GitLab URL |
|---------|----|------|------------|
| ERP Admin | 9 | `vppos-team/erp-admin` | `gitlab.vppos.vn/vppos-team/erp-admin` |

## Local checkout path (IMPORTANT — do not re-discover every session)

- **Actual repo (edit/read code here):** `/home/luukhoahoc/Projects/Hilo-Vppos/erp-admin`
- **Review checkout:** `/home/luukhoahoc/Projects/Hilo-Vppos/erp-admin-review`
- **Spec/docs folder (NOT the repo):** `/home/luukhoahoc/Projects/Hilo-Vppos/Documents/ERP`
  — the Hermes session CWD often points here; it holds `.md`/`.csv`/`.xlsx` planning docs, no source code.
  When a task references code (`apps/hr/...`), `cd` to the real repo path above first.
  Symptom of being in the wrong place: `search_files` for `HrDashboard`/`dashboard/hr` returns 0 hits.

## codegraph init pitfall

`codegraph init` runs against the path you pass. If the session CWD is the `Documents/ERP`
spec folder, you'll index an empty docs tree (`1 nodes, 0 edges`). Always
`codegraph init /home/luukhoahoc/Projects/Hilo-Vppos/erp-admin` (the real repo root) and
pass that same path as `projectPath` to `codegraph_explore`. Delete a stray `.codegraph/`
created in the wrong dir (`rm -rf .../Documents/ERP/.codegraph`).

## MFE Structure (erp-admin)

```
apps/
├── shell/          # Host shell, routing, MFE registry (active remotes: hr, employee)
├── hr/             # HR MFE (employee mgmt, attendance, HR dashboard) — filter name: hr-dashboard
├── employee/       # Employee self-service MFE
├── sale/           # Sale MFE
├── finance/        # Finance MFE
├── product/        # Product MFE
└── apps-dashboard/ # Dashboard MFE (in MFE_REMOTE_CONFIGS, not yet mounted in MFE_LOADERS)
packages/
├── shared/         # @hilo/shared — PATHS, endpoints.ts, query-keys, auth (cross-MFE contract)
├── ui/             # @hilo/ui — shared components
├── icons/          # @hilo/icons
└── locales/        # @hilo/locales — src/translations/{vi,en}/*.json
```

Note: the HR MFE app dir is `apps/hr` but its pnpm filter name is **`hr-dashboard`**
(`pnpm --filter hr-dashboard ...`). Endpoints live in `packages/shared/src/api/endpoints.ts`;
i18n JSON in `packages/locales/src/translations/{vi,en}/{hr,common,employee,...}.json`.
Each app/feature has a local `AGENTS.md` — read it before changing internals.

## Key Feature Paths

| Feature | HR MFE | Employee MFE |
|---------|--------|-------------|
| Request mgmt (YCCV) | `apps/hr/src/features/request-management/` | `apps/employee/src/features/requests/` |
| Attendance | `apps/hr/src/features/attendances/` | `apps/employee/src/features/attendance/` |
| Employees | `apps/hr/src/features/employees/` | — |
| Time-off | `apps/hr/src/features/time-off-management/` | — |
| Org structure | `apps/hr/src/features/organizations/` | — |
| HR Dashboard | `apps/hr/src/features/dashboard/` | `apps/employee/src/features/dashboard/` |

## Common Dev Commands

```bash
pnpm --filter hr-dashboard dev     # HR MFE dev
pnpm --filter employee dev         # Employee MFE dev
pnpm --filter hr-dashboard build   # HR build
pnpm --filter hr-dashboard typecheck
pnpm --filter hr-dashboard exec vitest run src/features/dashboard   # focused tests
pnpm --filter @hilo/shared typecheck   # when touching endpoints/query-keys
```
