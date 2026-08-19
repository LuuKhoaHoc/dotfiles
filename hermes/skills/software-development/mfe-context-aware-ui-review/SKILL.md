---
name: mfe-context-aware-ui-review
description: Review MFE UI with active context, guards, and scoped data.
---

# MFE Context-Aware UI Review

Review cross-cutting tenant/context features across Shell and remote MFEs: context selectors, route guards, context-scoped caches, recovery flows, and active-organization display.

## Review the observable flow

Trace:

```text
module metadata -> router/guard -> active context state -> Shell display slot
-> picker/switch interaction -> API selection/recovery -> remote query keys/UI
```

Verify each acceptance criterion at its actual consumer. A new `ContextSwitcher` rendering successfully does not prove that the existing company/organization display was replaced as required.

## Shell display-slot rule

When the product asks to replace the company name inside context-aware modules, reuse the existing organization/company display slot. Do not automatically add a second context pill beside the company name.

Expected behavior:

- Context-aware route + selected context: display `crmContext.displayName`, falling back to `contextName`.
- HR/non-context route: display `user.organizationName`.
- Context-aware route with no context: do not render remote content; show actionable guard/picker UI and avoid stale company text implying a selected context.
- CRM-to-HR and HR-to-CRM transitions update immediately from route and store state.
- If the display is the switcher in the intended UX, it opens the picker.

Check avatar labels, user-menu headers, tooltips, and mobile/desktop topbars. Centralize or reuse route classification to avoid divergent CRM checks.

## Context/API contract

Keep identifiers distinct:

- `membershipId`: selection payload and cache scope when product chooses membership-scoped isolation.
- `contextId`: underlying tenant/organization identity.
- `CrmContextSummary`: full display/authorization DTO.

Never confuse context DTOs with permission option DTOs such as `{ id, value }`. Verify the actual `ApiResponse<T>` contract. If `select-context` returns login-shaped `AuthLoginData`, verify user state is updated from that response and context metadata comes from the selected context DTO without inventing fields.

## Guard and picker behavior

Verify only modules with `requiresCrmContext: true` are guarded; HR routes remain non-blocking; deep links preserve the original URL; missing context renders guard state instead of remote content; cancel preserves the route and leaves an actionable guard; persisted context avoids an unnecessary boot fetch; deliberate switching and recovery refetch the list.

Do not put global navigation policy inside a low-level Dialog. Prefer callbacks and let the guard/flow controller decide navigation.

## Interceptor and queue review

For `403 CRM-403-004`, verify:

- only `/crm/*` requests are intercepted;
- concurrent failures trigger one picker flow;
- queued requests all replay or reject;
- per-request retry marker prevents loops;
- queue controls are exported through the public shared package boundary, never deep-imported;
- cancellation cannot leave requests pending;
- cache removal targets the intended membership scope.

## Verification matrix

| Case | Expected result |
|---|---|
| CRM route + context | context replaces company; remote renders |
| HR route + context | company returns; no picker |
| CRM route without context | guard + picker; remote hidden |
| picker cancel | route preserved; guard actionable |
| deliberate switch | contexts refetch; display and store update |
| CRM 403 | one flow; queue replay/reject; bounded retry |
| concurrent CRM 403 | one event; all requests handled |
| permission option DTO | never parsed as context summary |

## Pitfalls

- Treating a new adjacent pill as proof the old company display was replaced.
- Checking only `crmContext !== null`, causing HR to show CRM context.
- Mixing `contextId` and `membershipId` in keys and payloads.
- Assuming generic `CRM-403-004` specifically means revoke when BE has no revoke signal.
- Claiming acceptance from a checked box without verifying the existing consumer.

See `references/context-aware-ui-review.md` for the concrete checklist from this review.
