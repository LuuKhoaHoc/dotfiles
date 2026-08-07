# Milestone v1.0.0 — status snapshot 2026-08-06 (pre-release)

Milestone id=2, project 9, due 2026-08-06. 18/18 issues `status::done`, all OPEN (close only after prod deploy).

## Issue → MR mapping (all merged into develop)

| Issue | MR | Branch |
|---|---|---|
| #110 Product Connect Catalog API | !512 | feature/connect-product-catalog-api (merged 08-03, milestone=null) |
| #116 Employee GET /me/requests/stats | !516 | feature/me-requests-stats (07-30, milestone=null) |
| #123 Employee filter panel | !531 | feat/employee-issue-123-tabl... |
| #124 Sale filter panel | !535 | feat/sale-issue-124-table-fi... (milestone-assigned) |
| #128 HR freeze/unfreeze | — | feature/hr-freeze-unfreeze-e... (milestone=null) |
| #129 Lock/unlock theo attendanceSheetId | !544 | feat/hr-attendance-lock-by-a... (milestone-assigned) |
| #130 HR delete/restore employee | !547 | feature/hr-delete-restore-em... (milestone-assigned) |
| #131 Payroll slip branding | — | feature/hr-131-payroll-slip-... |
| #132 Validate document/certificate name | !546 | feat/hr-132-document-name-va... (milestone-assigned) |
| #133 Product sync CRM API + empty cache | !539 | feat/product-crm-api-update-empty-cache (milestone=null) |
| #134 ApiResponse<T> contract | !545 | docs/api-response-envelope-c... (milestone-assigned) |
| #135 Avatar cache-busting | — | fix/avatar-cache-busting (merged 08-06 14:01) |
| #136 Customer form *Id fields | !548 | fix/sale-136-customer-form-v... (milestone-assigned) |
| #137 Sale customers refactor | — | refactor/sale-customer-compl... |
| #141 Shared finance DTOs | — | refactor/normalize-finance-d... |
| #143 Customer filter/sort | !552 | feat/143-customer-filter-sor... (milestone-assigned) |
| #144 Product combobox/danh mục | !550 | hotfix/crm-product-input-alignment (08-06 07:21 UTC, milestone=null) |
| #145 Typecheck no-op fix | — | fix/dev-infra-typecheck-145 |

Chỉ 7 MR gắn milestone (get_milestone_merge_requests page 1+2) — các MR còn lại `milestone=null`; tìm bằng git merge-commit branch names hoặc `list_merge_requests(search=...)`.

## Milestone release checklist (state after update)

- [x] All intended issues are assigned to this milestone
- [x] Feature MRs are merged into develop
- [ ] UAT deployment passes
- [x] Issues moved to `status::done` while remaining open
- [ ] Release branch/tag `v1.0.0` prepared
- [ ] Production deployment passes
- [ ] Issues closed by post-production automation
- [ ] GitLab Release `v1.0.0` created

## Python parse snippet (list_issues persisted payload)

```python
import json
with open("<persisted-file>.txt", encoding="utf-8") as f:
    data = json.loads(f.read())
issues = json.loads(data["result"])
for i in issues:
    labels = i.get("labels") or []
    status = next((l for l in labels if l.startswith("status::")), "-")
    print(f"#{i['iid']} state={i['state']:<7} {status:<22} closed_at={i.get('closed_at') or '-':<25} {i['title'][:90]}")
```

## Release timing answer (user question 2026-08-06)

Prod deploy sau khi user chấm công ra hết (18h–20h) hoặc trước giờ vào (~6h); không trong giờ hành chính — attendance ghi liên tục, release đụng #129/#128 (lock/unlock, freeze) — vùng từng gây `HRM-400-1490`.
