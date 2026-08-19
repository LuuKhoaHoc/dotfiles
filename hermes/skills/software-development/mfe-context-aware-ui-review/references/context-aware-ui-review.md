# Context-Aware MFE Review Checklist

Use this checklist when reviewing a Shell + remote-MFE context feature.

## Existing display slot

1. Find the current company/organization display consumer.
2. Confirm CRM routes replace that value with `crmContext.displayName` or `contextName`.
3. Confirm HR routes restore `user.organizationName`.
4. Check desktop, mobile, avatar, user-menu header, and tooltip consumers.
5. Reject an implementation that only adds a second adjacent context pill when the requirement says to replace the company display.

## Contract checks

- `GET /auth/crm/contexts`: `ApiResponse<CrmContextSummary[]>` with `membershipId`, `contextType`, `contextId`, `contextCode`, `contextName`, `displayName`, `roles`, `isDefault`.
- Permission option DTOs shaped `{ id, value }` are a separate contract.
- `POST /auth/crm/select-context` returns login-shaped `AuthLoginData`.
- Keep `membershipId` and `contextId` semantically distinct; use the product-approved one consistently in cache keys.

## Guard and recovery checks

- Only `requiresCrmContext` modules are blocked.
- HR routes render normally.
- Missing context hides the remote and leaves an actionable guard.
- Cancel preserves the route and cannot leave queued requests pending.
- Persisted context skips boot list fetch; explicit switch/recovery fetches the list.
- Generic `CRM-403-004` must not be labeled as a specific revoke unless BE provides a distinct signal.

## Queue checks

- Intercept only CRM URLs.
- One event for concurrent failures.
- Resolve/reject all queued requests.
- Retry at most once per original request.
- Export controls from public `@hilo/shared`; never deep-import package internals.
