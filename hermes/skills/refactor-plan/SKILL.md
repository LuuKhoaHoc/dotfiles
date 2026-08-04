---
name: refactor-plan
description: Create a detailed refactor plan with tiny commit steps, then file it as an issue for execution. Use when user wants to plan a safe refactor, create an RFC, or decompose refactor work into reviewable steps.
---

# Refactor Plan

Create a detailed refactor plan with tiny commit steps, then file it as an issue.

## When to Use

- User wants to plan a refactor before touching code
- Team needs a reusable refactor ticket for review and assignment
- The change requires human judgment about cross-file consistency

## Process

### 1. Understand the scope

Ask for or gather:

- What behavior must be preserved?
- What is the motivation? (performance, clarity, migration, removal of dependency...)
- What borders may be touched, and what must stay stable?
- What existing test coverage exists in the area?

### 2. Propose alternatives

If there are multiple promising directions, summarize them with tradeoffs before committing to one.

### 3. Break into tiny commits

Each commit must leave the codebase in a working state.
Sequence commits so review can happen in small units:

1. Structure or rename changes
2. Call-site updates
3. Behavioral improvements
4. Test updates/new tests

### 4. Document the plan

Use this structure when filing or documenting the plan:

```
## Problem Statement

What is painful about the current structure, from the team's perspective.

## Solution

What end-state looks like and why it is better.

## Commits

A long, detailed implementation plan in tiny commit steps.

## Decisions

- Modules touched or added
- Interfaces changed or preserved
- Technical clarifications that affect the plan
- Schema/API behavior that must not change
- Interaction patterns with callers

## Testing

- What makes a good test for this area
- Which seams will be tested
- Existing test patterns to follow or extend

## Out of Scope

Either empty or explicitly called out so reviewers don't request drift.

## Further Notes

Assumptions, risks, and follow-up work.
```

### 5. Mark ownership and review needs

If any step needs human approval, mark it explicitly rather than silently delegating.
