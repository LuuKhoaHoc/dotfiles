---
name: mfe-feature-audit
description: >
  Perform a comprehensive architecture and production-readiness audit of a feature in an MFE/FSD monorepo. 
  Focuses on boundary violations, mock leakage, and logic duplication before final code review.
---

This skill defines the procedure for auditing a feature module (especially in Feature-Sliced Design) to ensure it meets architectural standards and is safe for production deployment.

## Trigger Conditions
- User asks to "review a feature", "audit a PR", or "check if a feature is production-ready".
- Working in a monorepo with MFE (Module Federation) and FSD (Feature-Sliced Design).
- Reviewing a large set of files where manual one-by-one reading is inefficient.

## Audit Workflow

### 1. Context Gathering
- **Pattern Discovery**: Search `docs/solutions/conventions/` for any feature-specific or UI-pattern documentation related to the module.
- **Boundary Definition**: Read the feature's `AGENTS.md` and root `AGENTS.md` to identify the expected public API boundary (`index.ts`) and the required adapter layer (`apis/` $\rightarrow$ `adapters/` $\rightarrow$ UI).

### 2. Parallel Audit Passes (Delegation)
Instead of reading files sequentially, execute parallel "Audit Passes" using delegation to identify specific classes of issues:

#### Pass A: Boundary & FSD Violations
- **Deep Imports**: Search for imports that bypass the `index.ts` public boundary (e.g., importing from `../components/dialogs/X` from a page).
- **Missing Exports**: Verify that all public-facing components/hooks are exported via the feature's `index.ts`.
- **Layer Leakage**: Check for raw API calls in UI components (should be in `apis/` hooks) and raw API responses in UI (should be processed by `adapters/`).

#### Pass B: Production Leakage & Stubs
- **Mock Leakage**: Identify imports of `.mock.ts` files or calls to `getMock...()` functions.
- **Guard Check**: Ensure mock-path logic is strictly wrapped in `if (import.meta.env.DEV)` guards.
- **Coming Soon**: Search for `toast.info("coming soon")` or `() => undefined` callbacks in action handlers.

#### Pass C: Logic Duplication & DRY
- **UI Patterns**: Identify repeated client-side logic for pagination, searching, or filtering across multiple tabs/views.
- **Utility Duplication**: Look for common helper functions (e.g., `parseIsoDate`, `rgbaToHex`) duplicated across multiple files.
- **State Selector Bloat**: Check for excessive individual selectors from a single Zustand store (e.g., 20+ separate `useStore` calls) that should be bundled.

#### Pass D: I18n & Styling
- **Hardcoded Strings**: Search for raw text (especially in non-English languages) in JSX.
- **Magic Colors**: Identify hardcoded hex colors (e.g., `#DF6612`) that should be design tokens or Tailwind classes.

### 3. Synthesis & Reporting
Summarize findings by severity:
- `🔴 Bug/Risk`: Production leakage, boundary breaks that cause runtime errors, or data-loss risks.
- `🟡 Pattern Violation`: FSD breaks, missing adapters, hardcoded strings.
- `🔵 Nit/Optim`: Logic duplication, selector bloat, dead constants.

## Pitfalls to Watch For
- **The "Page-Only" Export**: Developers often export the `View` component but forget to export necessary `types` or `constants` required by the shell or other features.
- **Mock-Driven Development**: Features that "look" finished but are entirely powered by `constants/*.mock.ts` without corresponding `apis/` implementation.
- **The "Coming Soon" Trap**: Stubbed functions that return `undefined` or a toast, which are easily missed during manual testing but block production value.
- **The "Fake-Data Form Field" Trap** (real case, sale customers AgentTransferModal 2026-08-05): a form field can be `required` in the schema, render options from hardcoded fake names (verifier list: 3 fabricated people), and still be silently DROPPED on submit — because the BE contract doesn't include the field at all. Verify every submitted field against the real BE contract: the Swagger UI at `https://api-erp.vppos.vn/docs` is a Scalar HTML shell that loads `/openapi.yaml` — curl that YAML and grep the request schema (`TransferCustomerPartnerRequest { partnerId, reason }` had no `verifierId`). A required UI field that never reaches the request = either missing BE endpoint (needs human/BE decision) or dead field to remove; create a `ready-for-human` issue, don't let an agent silently drop it.
- **Verify-the-verifiers**: after delegation passes, spot-check the 🔴 claims yourself (read the flagged file/lines) before writing issues — subagent line numbers are usually right, but severity framing needs first-hand confirmation.
- **URL-state wiring gap (the page is the last hop)**: when adding a URL-state param (sort/order/filter), the chain is `setter → URL → page destructure → query params → React Query key`. The most common miss is the PAGE hop: the URL-state hook + table get updated, but the page never destructures/passes the new param into `useQuery` → URL changes, key doesn't, no refetch (real case: #143 sort columns — table sorted visually via controlled state but API never re-called until `sort`/`order` were forwarded in `CustomerListPage`). Audit checklist: for every URL-state param, grep the page for `params.X` being passed to the query hook.

## References
- See `references/gitlab-mr-fetch.md` for accessing merge requests when CLI tools are blocked.
