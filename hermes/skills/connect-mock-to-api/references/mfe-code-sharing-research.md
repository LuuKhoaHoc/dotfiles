# MFE Code Sharing — When to Harvest into @hilo/shared (research notes, 2026-08-05)

Condensed from web research (Martin Fowler/Thoughtworks + Luis Atencio) validating the repo's
"MFE-first / duplicate until ≥3 stable consumers" rule in AGENTS.md. Use when deciding whether a
new hook/component/type belongs in `@hilo/shared` or duplicated locally in the MFE.

## Consensus (authoritative sources)

**Martin Fowler — "Micro Frontends" + bliki HarvestedPlatform** (the canonical take):
> "We prefer to let teams create their own components within their codebases as they need them,
> even if that causes some duplication initially. Allow the patterns to emerge naturally, and once
> the component's API has become obvious, you can **harvest** the duplicate code into a shared library."

- Easiest thing to get wrong: creating too many shared components **too early** → API churn.
- Only share **UI logic + contracts**, never domain/business logic: "When domain logic is put into a
  shared library it creates a high degree of coupling across applications."
- Ownership: custodian model (anyone can contribute, one custodian keeps quality).

**Luis Atencio — "Microfrontends in Depth"** (best practices #10–11):
> "Accept and embrace duplicated code across MFEs. The less you share, the less impact one change
> has on other parts. Only when absolutely necessary... consider using a shared library."
- Prefer larger MFE bundles with their own copies over smaller bundles sharing libraries
  (exception: view framework + shared component library, loaded once by the shell).

**Module Federation side**: shared runtime deps (react, react-dom) singleton via `shared` config;
version-lock shared libraries tightly. This decides HOW to share infra, not WHAT to share.

## Rule of thumb applied to this repo (worked example: employee-search for Sale)

| Layer | Location | Why |
|---|---|---|
| Endpoint constants (`API_ENDPOINTS.HR.EMPLOYEES`) | `@hilo/shared` (already) | Infrastructure, zero coupling risk |
| DTO types (BE contract) | `@hilo/shared` (already) | BE contract is stable, same shape for all consumers |
| Query hooks (React Query + params) | **Local per MFE until stable** | 3 consumers with DIFFERENT param shapes (hr payroll vs employee directory vs sale combobox) = API not yet "obvious" → duplicate now, harvest later |

Decision checklist before harvesting a hook/component into `@hilo/shared`:
1. ≥3 MFEs use it with the SAME stable shape (params + mapping)?
2. Content is UI logic / contract only — no domain branching?
3. Is there a custodian who will own it (else it becomes a hodge-podge)?
4. If yes to all → harvest. Otherwise duplicate locally (explicitly allowed by repo AGENTS.md).

Cross-MFE import is FORBIDDEN (apps can't import from each other's internals — only via
`@hilo/*` packages), so "it already exists in HR MFE" is NOT a reason to skip writing it in Sale —
write the local copy using the shared endpoint constant.
