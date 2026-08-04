---
name: implementation-plan
description: Produce a compact, tiered implementation plan with traceability from ticket to acceptance test. Use when user says "lập kế hoạch", "plan first", "task list", "estimate this", "decompose into tasks", or needs a breakdown of non-trivial work before coding.
---

# Implementation Plan

Produce a compact, tiered implementation plan from a requirement or ticket.

## When to Use

- User or PM/BA shared a ticket, story, or requirement
- Scope is non-trivial and touches multiple layers/files
- Team needs understand owner responsibilities, dependencies, or estimation

## Output

### Summary

One paragraph: what is being built, why, and whose domain it belongs to.

### Tier overview

Map each layer to responsible role:

- Frontend layer
- Backend/API layer
- Database/domain layer
- Integration/sync layer
- QA/bug-fix layer

### Acceptance criteria

Write criteria as **verifiable outcomes**, not todo lists.

Format:

```
AC-<slug> <status>: <verifiable outcome>
```

Statuses: proposed | approved | done

Example:

```
AC-create-order approved: placing an order returns 201 with order id and visible in order list within 1 refresh
AC-create-order done: true when confirmed by QA pass
```

### Implementation units

Break into small verifiable pieces. Prefer vertical slices.

Each unit:

- Short title
- Type: `feat` | `fix` | `refactor` | `chore`
- Files/dirs most likely involved
- Verification: how to confirm this unit is complete
- Blocked by: empty or comma-separated unit IDs

### Estimates

If user enables estimates, add:

- Complexity: low | medium | high
- Risk: low | medium | high
- Owner role: FE | BE | QA | PO/BA review

## Spec Review (before planning)

Before creating an implementation plan from a business flow doc (drawio, markdown, PDF), review the spec first:
- Read and parse the flow diagram into human-readable steps
- Cross-reference with codebase (types, schemas, constants) to verify/answer questions
- Compile remaining gaps as questions for BA

See `references/spec-review-workflow.md` for detailed workflow.

## Rules

- Keep the plan scannable; don't write novel prose where a table or list suffices
- Trace acceptance criteria back to tiered work packages
- Don't invent unsupported estimates if no info is available
- If user says "decompose further", split the largest unit into smaller units with explicit verifications
