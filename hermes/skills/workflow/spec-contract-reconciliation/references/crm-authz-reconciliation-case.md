# CRM Authz / Onboarding Reconciliation Case

> Session-specific reference. The BE documents are external source material; this file records the reconciliation method and the conflict shape, not a permanent CRM contract.

## Context

Three CRM authorization documents were reviewed together:

- `crm-authz-overview.md`
- `crm-authz-integration-api.md`
- `crm-authz-flows.md`
- later supplemented by `crm-onboarding-integration-guide.md`

The goal was to derive FE issues for `erp-admin` without treating diagrams, API prose, and user decisions as interchangeable evidence.

## Confirmed FE-impacting rules from the onboarding guide

- A HR token without a selected CRM membership cannot call `/crm/*`; the expected recovery is `GET /auth/crm/contexts`, then `POST /auth/crm/select-context` with `membershipId`.
- Explicit selection is required even when the user has only one context.
- `POST /crm/partners` creates an `INACTIVE` partner; activation is a separate operation.
- Activation may create a user/membership/assignment and may return a one-time `temporaryPassword`.
- `PARTNER` and `PARTNER_TREE` are distinct scopes; role/permission and scope must be modeled separately.
- Partner staff creation supports only the documented staff roles, and existing-user and new-user responses differ in whether a temporary password is returned.

## Role/template contradiction

The onboarding guide contained blanket prohibitions that conflicted with the user’s explicit business decision.

### Evidence found in the document

- In the scope/role section: “admin cũng **không gán được template/system role** …” and the table says an admin assigning `PARTNER_OWNER` with `PARTNER_TREE` is rejected.
- In the authorization API section: “Clone role tùy chỉnh …” followed by “**Không clone/assign template/system role**”.
- In the older Flow B: `Verify source is not system/template (or caller is admin)`, which explicitly suggests an admin exception.

### User decision

The user explicitly corrected the working rule:

- `CRM_SYSTEM_ADMIN` may clone system/template roles.
- `CRM_SYSTEM_ADMIN` may assign system/template roles.
- Non-admins may not clone or assign system/template roles.

### Correct reconciliation

Do not claim that the onboarding guide already contains the admin exception. Record it as a conflict and use the explicit user decision as the working contract for FE planning. Require BE to update the guide and make endpoint behavior/tests match.

### FE consequence

Action visibility is actor-aware:

- Admin: clone/assign custom, system, and template roles.
- Non-admin: clone/assign custom roles only.
- Backend remains the security boundary; FE gating is only UX.

Do not hardcode “all templates are always forbidden” after the user has supplied an explicit exception.

## FE repository evidence used in the review

`erp-admin` already has:

- cookie-oriented Axios configuration with `withCredentials: true`;
- a shared Zustand auth store persisting user/language, not raw tokens;
- centralized `API_ENDPOINTS.AUTH` and existing `/crm/*` endpoint constants;
- a repository convention of raw `ApiResponse<T>`, list arrays directly in `data`, and pagination under the agreed `meta.pagination` shape;
- shell-owned auth entry/guards and shared auth contracts.

Therefore the likely FE foundation is shared CRM-context metadata plus shell context guard/recovery, not a second local token store.

## Review lesson

When a user asks “where does the doc say that?”, search the exact source and answer with the precise section/statement. If the source contradicts the user’s correction, say so plainly: “the document says X; your decision changes the working contract to Y.” Do not retroactively reinterpret an unconditional sentence as if it had contained the exception.
