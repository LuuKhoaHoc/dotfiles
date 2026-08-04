---
name: implementation-runner
description: Execute a PRD, plan, or approved ticket list through implementation with lightweight checks — typecheck, lint, targeted tests, then final review. Use when user says "implement", "execute the plan", "start building", or wants hands-on execution after planning is approved.
---

# Implementation Runner

Execute the work described by a PRD, plan, or approved set of tickets.
Use TDD-style checks where the project supports it, but do not skip validation.

## When to Use

- A plan or PRD has been approved
- QA/tickets are ready to be turned into code
- You need fast, bounded execution with verification checkpoints

## Process

### 1. Choose the authoritative source

Prefer one source of truth, in this order:

1. Approved PRD
2. Approved implementation plan
3. Approved ticket list with ACs

Do not combine vague memory with outdated docs.

### 2. Work in small verifiable steps

For each implementation unit:

- Make the smallest change that satisfies the AC
- Prefer behavioral tests at the highest testable seam
- Keep changes local to the unit unless a cross-file refactor is unavoidable
- Do not expand scope beyond the AC

### 3. Validate as you go

Run:

- narrowest failing-test or targeted test after each change when applicable
- file-level typecheck / linter when language permits it
- project-wide checks only at the end, not after each tiny change

Document what you ran and the result.

### 4. Review your own work

Before saying done, walk through:

- Did each unit satisfy its AC?
- Are there untested boundaries that need test coverage?
- Did any step silently change behavior outside the AC?

If possible, run `/pr-review` style self-check on the final diff.

### 5. Mark status

Update task status to indicate completion:

```
x Status: completed
--------------------------------------------------------------------
--------------------------------------------------------------------
```

### 6. Report

Output a compact summary:

- Units implemented
- Validation commands and results
- Outstanding risks or follow-ups
- Suggested next step: `/pr-review` if applicable

## Boundaries

- If acceptance criteria are unclear, stop and ask for clarification before coding
- Do not implement speculative features
- Do not silently upgrade dependencies or change unrelated config as part of an implementation unit
