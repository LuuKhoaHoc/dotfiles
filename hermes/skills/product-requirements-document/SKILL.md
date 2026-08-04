---
name: product-requirements-document
description: Turn the current conversation into a PRD and publish it to the project issue tracker — synthesis only, no interview. Use when user says "PRD", "product requirements", "write spec", "document this feature", or after planning discussion to capture requirements as a durable artifact.
---

# Product Requirements Document

This skill takes the current conversation context and project understanding
and produces a PRD. Do NOT interview the user — just synthesize what you already know.

## Process

1. Explore the repo/project to understand the current state.
   Use any domain glossary vocabulary throughout the PRD.
   Respect ADRs in the area you're touching.

2. Sketch the seams at which you're going to verify the feature.
   Existing seams should be preferred to new ones.
   Use the highest seam possible. If new seams are needed,
   propose them at the highest point you can.
   The fewer seams across the codebase, the better.

3. Write the PRD using the template below,
   then publish it to the project issue tracker if one is configured.
   Otherwise save it as a markdown artifact at the agreed path.

## PRD Template

```
## Problem Statement

The problem the user is facing, from the user's perspective.

## Solution

The solution to the problem, from the user's perspective.

## User Stories

A long, numbered list of user stories in the format:

1. As an <actor>, I want a <feature>, so that <benefit>

Example:

1. As a mobile bank customer, I want to see balance on my accounts, so that I can make better informed decisions about my spending

## Implementation Decisions

A list of implementation decisions that were made.
This can include:

- The modules that will be built/modified
- The interfaces of those modules
- Technical clarifications from the developer
- Architectural decisions
- Schema changes
- API contracts
- Specific interactions

Do NOT include specific file paths or code snippets — they go stale fast.
Exception: if a prototype produced a snippet that encodes a decision
more precisely than prose can (state machine, reducer, schema, type shape),
inline it within the relevant decision and note briefly that it came from a prototype.

## Testing Decisions

A list of testing decisions that were made. Include:

- What makes a good test (only test external behavior, not implementation details)
- Which modules will be tested
- Prior art for the tests (similar types of tests in the codebase)

## Out of Scope

Explicitly list what is NOT being built so reviewers don't request drift later.

## Further Notes

Any further observations or follow-ups that don't fit above.
```

## Rules

- Don't invent requirements that weren't discussed
- If acceptance criteria exist in conversation, include them
- Prefer "as an actor, I want..." format over task lists
- Keep each section concise; a PRD should be readable in a few minutes
- Don't ask the user to review before publishing unless required by workflow;
  instead present the PRD summary and ask for direction
