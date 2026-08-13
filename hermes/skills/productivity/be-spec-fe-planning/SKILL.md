---
name: be-spec-fe-planning
description: Use when BE spec docs need FE issue planning.
---

# BE Spec → FE Issue Planning

Trigger: user drops BE spec files (authz overview / integration API / flows / onboarding guide) and wants FE issues, milestone planning, or challenges a claim about what a doc says.

## 1. Quote discipline (user-corrected 2026-08-12)

When asserting what a doc says:

- **Quote verbatim + cite location** (mục/§, dòng nếu biết). Never paraphrase into an absolute claim.
- **Distinguish 3 layers**: (a) doc says (verbatim), (b) my interpretation, (c) business rule user/PO confirmed. When (a) and (c) conflict → present both, treat (c) as the rule, mark "spec conflict cần BE sửa" — never silently pick a side.
- **User challenges a claim → re-search the doc immediately** (search_files with a specific pattern in that file), never re-assert from memory.
- Real failures this session: claimed Flow B "allows cloning any role" (wrong — it only says "Verify source is not system/template (or caller is admin)"); claimed onboarding guide says "admin cannot clone templates" (doc has only a blanket "Không clone/assign template/system role" §2.4 with no admin exception). Both corrections were user-driven.

## 2. Multi-doc reconciliation

BE sends overlapping docs (overview + integration API + flows + onboarding guide). For each conflicting rule build an **actor × rule table** (admin vs non-admin; scope types) recording per-doc wording. Typical conflict shape: exception clause in one doc ("or caller is admin"), blanket statement in another, E2E-verified results in a third.

## 3. Contract facts to verify before FE planning (checklist)

- **Auth contract changes that gate ALL downstream features** — e.g. CRM context selection: token without membershipId → `403 CRM-403-004` → `GET /auth/crm/contexts` → `POST /auth/crm/select-context` (even for a single context). Check whether existing in-flight FE issues (sale/CKS API wiring) depend on it.
- **Missing endpoints referenced by flows but absent from API reference** (e.g. `GET /authorization/permissions` needed by a permission selector) — BE blocker, file early.
- **Response envelope/pagination consistency** (`meta.pagination` vs flat meta) — repo convention wins unless BE confirms otherwise; never write FE that accepts both shapes.
- **Validation errors returning 500** (binding bug) — file as BE bug; do not map in FE.
- **One-time sensitive data** (`temporaryPassword` from activate/staff) — one-time display modal with copy + warning; never persist to URL/localStorage/query cache; never re-call the API to re-show it (409).
- **FE gating by permission, not role code**; BE remains the enforcement layer.

## 4. Issue decomposition rules

- Vertical slices, not per-endpoint issues.
- Dependency-first ordering: foundation slices (auth/context) before feature slices they gate; flag when "later" features silently depend on foundation (real case: #108/#109 sale+CKS API wiring blocked by missing context selection).
- Role vs scope are independent axes (role = can do; scope = on whose data) — keep them separate in UI planning.

## References

- `references/crm-authz-contract-2026-08-12.md` — CRM authz/onboarding contract reconciliation: spec file locations, key business rules (incl. user-confirmed admin clone/assign rule), conflicts, FE impact notes.
