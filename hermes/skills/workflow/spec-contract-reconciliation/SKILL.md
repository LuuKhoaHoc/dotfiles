---
name: spec-contract-reconciliation
description: Use when reconciling BE specs before creating FE tickets.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [workflow, api-contracts, frontend-planning]
    related_skills: [implementation-plan, issue-to-tickets]
---

# Spec Contract Reconciliation

Review multiple backend/API documents, reconcile contradictions, and turn the verified contract into frontend-ready issues without silently inventing behavior.

## When to use

Use when:

- BE sends a new integration guide that supplements or conflicts with earlier specs.
- The user needs FE issues/tasks from business flows, API references, or onboarding documents.
- Several documents describe the same endpoint, role, permission, scope, token, or lifecycle rule.
- The user is correcting an interpretation and the contract needs to be re-established.

Do not jump directly to issue creation. First establish the contract and unresolved decisions.

## Core principle: evidence before interpretation

For every important rule:

1. Locate the exact source passage or code evidence.
2. Quote or paraphrase it with the document/section/endpoint.
3. Compare it with other sources.
4. Classify the result as:
   - **consistent** — sources agree;
   - **conflicting** — sources explicitly disagree;
   - **underspecified** — the behavior is missing or ambiguous;
   - **user decision** — the user explicitly chooses the desired behavior.
5. Never present a user decision as if it were already written in the BE docs.
6. Never say a document contains an exception unless the exception is actually present in the text.
7. When a user corrects the rule, update the working contract immediately and keep the conflicting document statement visible as a BE-doc gap.

A blanket sentence such as “do not clone/assign system or template roles” must be treated as a blanket rule unless an explicit admin exception appears nearby. If the user later decides that admins are allowed, record it as a decision that overrides the current document and request BE documentation/API alignment.

## Source precedence

Use this precedence for planning, while preserving the conflict ledger:

1. Explicit user/PO decision made in the current discussion.
2. Verified live API behavior or BE code/test evidence, if the user asks to rely on it.
3. Latest BE contract document, identified by date/version or the user’s statement that it is current.
4. Older documents and diagrams.
5. Agent inference — only when clearly labelled as an assumption.

Do not silently discard a lower-precedence contradiction. Put it in “BE clarification/blocker” with the exact evidence and expected resolution.

## Q&A mode

When the user wants to discuss the spec before ticket creation:

- Ask one decision question at a time.
- Give a recommended answer before the question.
- Do not ask questions whose answer can be found in the supplied documents or codebase.
- Do not create issues, modify code, or claim a final plan until the user confirms the relevant decisions.
- Keep the question narrowly scoped: one rule, endpoint, actor, or dependency.

## Reconciliation workflow

### 1. Build a contract matrix

Track at least:

| Area | Current contract | Evidence | Conflict/gap | FE consequence | Decision needed |
|---|---|---|---|---|---|
| Auth/context |  |  |  |  |  |
| Role/template |  |  |  |  |  |
| Permission ceiling |  |  |  |  |  |
| Scope |  |  |  |  |  |
| Lifecycle/status |  |  |  |  |  |
| Error/envelope |  |  |  |  |  |

Prioritize identity/context, authorization rules, and lifecycle transitions before UI details.

### 2. Separate authorization dimensions

Always model these independently:

- **Role**: which actions/permissions are available.
- **Scope**: which resources those permissions apply to.
- **Context**: the selected ORGANIZATION/PARTNER/CUSTOMER membership.
- **Field security**: whether sensitive fields can be read/written.
- **Actor class**: CRM system admin versus ordinary partner/customer user.

Do not gate FE behavior by role code alone when the contract exposes permissions and scopes. FE gating is UX only; BE remains the security boundary.

### 3. Trace complete lifecycles

For onboarding resources, distinguish each transition:

```text
create → INACTIVE → activate → user/membership/assignment → login/select-context → ACTIVE use
```

For each transition record:

- endpoint and method;
- required permission;
- input source (previous response, route, form, or current context);
- resulting status and credentials;
- one-time or sensitive outputs;
- retry/idempotency/conflict behavior;
- who can perform it.

Do not collapse create and activate into one FE task if they have different actors, permissions, or outputs.

### 4. Treat security-sensitive outputs explicitly

Temporary passwords and tokens are one-time/sensitive values. Issue acceptance criteria must require:

- show only when returned;
- no persistence in URL, localStorage, query cache, or logs;
- copy/reveal UX and a warning when the value will not be recoverable;
- no automatic retry that could create a second credential;
- clear handling of the “existing user” path where no temporary password is returned.

### 5. Verify FE repository assumptions

Before proposing implementation units, inspect the FE’s existing contracts:

- auth store and cookie/token strategy;
- API endpoint constants;
- response envelope and pagination shape;
- existing permission/role utilities;
- shell guards and route ownership;
- existing MFE/API patterns and local AGENTS.md/docs/solutions.

Respect repository conventions: dumb API functions returning raw `ApiResponse<T>`, list data directly in `data`, pagination in the agreed `meta.pagination`, URL-backed list filters, and shared auth state at the shared boundary.

If the repo convention disagrees with the new BE document, do not write a compatibility normalizer by default. Flag the contract for BE confirmation.

## Contradiction ledger format

Use this format for every meaningful conflict:

```markdown
### Conflict: <short title>
- Source A: `<file/section>` — “<exact statement>”
- Source B: `<file/section>` — “<exact statement>”
- User decision: <if any>
- Working contract: <what FE should implement>
- BE follow-up: <what document/API/test must be aligned>
- FE block: <yes/no and why>
```

For the CRM role case, a correct ledger may look like:

```markdown
- Older/newer guide says system/template roles cannot be cloned or assigned.
- User decision says CRM_SYSTEM_ADMIN may clone and assign them.
- Working FE rule: admin may; non-admin may not.
- BE follow-up: update docs and ensure API behavior/error cases match.
```

Do not rewrite the source as if it already contained the user’s exception.

## Turning the reconciled contract into FE issues

Prefer vertical slices over one issue per endpoint:

1. Context discovery/selection and recovery.
2. Resource lifecycle (create/list/detail/activate where applicable).
3. Staff/user onboarding and one-time credentials.
4. Custom/system/template role management, with actor-specific actions.
5. Membership/assignment/access preview/revoke/lock.
6. Permission-aware navigation/actions and field-security display.

Every issue should contain:

- scope and explicit non-goals;
- APIs and DTOs used;
- dependency/blocker list;
- actor/permission/scope rules;
- loading, empty, error, conflict, and success states;
- verifiable acceptance criteria;
- exact BE clarification required when the issue is blocked.

Do not create a permission selector issue until the permission catalog endpoint or equivalent source is defined. Do not implement a role/template exception from inference alone.

## Common pitfalls

- Claiming “the docs say X” without quoting the exact section.
- Treating a blanket prohibition as though it contains an admin exception.
- Treating a user correction as proof that the document was already correct.
- Treating the newest filename as automatically authoritative without checking the user’s intended precedence.
- **Replacing doc references for unchanged flows.** BE often sends new docs per-flow (e.g. new docs for the sale/CKS sale flow, old docs kept for the CA-dossier flow). When the user says “luồng X giữ docs cũ”, keep the old reference in that issue and only update references for the changed flows — do not blanket-swap all References.
- **Endpoint used by flows but missing from the API reference often exists** — it is just undocumented. Ask BE before treating it as a blocker (real case: `GET /authorization/permissions` was confirmed to exist on 2026-08-12). When confirmed, keep an AC “curl xác nhận response shape trước khi code” instead of removing the verification step (user convention: BE/API mới → curl trước, ghi status vào issue).
- Gating by `roleCodes` while ignoring permission ceiling or scope.
- Assuming a single CRM context may be auto-selected when the contract requires explicit selection.
- Assuming create implies active/login-ready state.
- Showing temporary credentials on every success response.
- Writing FE compatibility code for multiple undocumented response shapes.
- Splitting a single business slice into endpoint-only tickets that omit actor, scope, and lifecycle behavior.

## Output order

For a spec-review session, return:

1. Confirmed contract.
2. Contradiction ledger.
3. FE impact and dependencies.
4. BE questions/blockers.
5. Proposed vertical-slice issues.
6. One next decision question, if Q&A is still in progress.

## Supporting reference

- `references/crm-authz-reconciliation-case.md` — condensed evidence and lessons from the CRM authz/onboarding discussion; use as a pattern, not as a source of truth for future BE contracts.
- `references/gitlab-issue-creation-mechanics.md` — GitLab (vppos.vn) issue-creation mechanics: block-link license 403 → text `Blocked by #N` convention, work-item "task" board visibility, dependent-issue placeholder + sed pattern, milestone vs due_date, mass-assignment confirmation, team versioning convention (v1.0.x patch cadence → minor only when module complete).
