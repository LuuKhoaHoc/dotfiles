---
name: qa-session
description: Run an interactive QA session where the user reports bugs or issues, you clarify lightly, inspect the codebase/domain docs, and create durable project issues. Use when the user says "QA session", "báo lỗi", "report bug", "file issues", "user x feedback", or wants to triage project issues conversationally.
---

# QA Session

Run an interactive QA session. The user describes problems they are encountering.
You clarify, explore the project/domain context, and produce durable issues.

## For each issue the user raises

### 1. Listen and lightly clarify

Let the user describe the problem in their own words.
Ask **at most 2-3 short clarifying questions** focused on:

- What they expected vs what actually happened
- Steps to reproduce (if not obvious)
- Whether it is consistent or intermittent

Do not over-interview. If the description is clear enough to issue, move on.

### 2. Explore for context

While talking to the user, inspect the codebase and any domain docs
(`CONTEXT.md`, `docs/adr/`, relevant specs) to understand:

- The user-facing behavior boundary
- The domain language used in that area
- What the feature is supposed to do

The issue itself should **not** reference specific files, line numbers, or internal implementation details.

### 3. Assess scope: single issue or breakdown

Before creating, decide whether this is a **single issue** or needs to be **broken down** into multiple issues.

Break down when:

- The fix spans multiple independent areas (e.g. validation is wrong AND success message is missing AND redirect is broken)
- There are clearly separable concerns that different people could work on in parallel
- The user describes something that has multiple distinct failure modes or symptoms

Keep as a single issue when:

- It is one behavior that is wrong in one place
- The symptoms are all caused by the same root behavior

### 4. Create the issue(s)

Create issues on the project tracker.
If the project uses GitLab, use the GitLab issue workflow the repo has configured;
otherwise create the issue in the workflow documented in the project `AGENTS.md`.

**Rules for all issue bodies:**

- No file paths or line numbers — these go stale
- Use the project's domain language from context/docs, not internal module names
- Describe behaviors, not code snippets
- Reproduction steps are mandatory
- Keep it concise — a developer should be able to read the issue in 30 seconds

Use this template for a single issue:

```
## What happened

[Describe the actual behavior the user experienced, in plain language]

## What I expected

[Describe the expected behavior]

## Steps to reproduce

1. [Concrete, numbered steps]
2. [Use domain terms from the project]
3. [Include relevant inputs, flags, or configuration]

## Additional context

[Any extra observations that help frame the issue — e.g. "this only happens in the finance MFE, not sale" — use domain language but don't cite files]
```

Use this template when breaking down a sub-issue:

```
## Parent issue

[Reference to the parent issue, if any]

## What's wrong

[Describe this specific behavior problem — just this slice]

## What I expected

[Expected behavior for this specific slice]

## Steps to reproduce

1. [Steps specific to THIS issue]

## Blocked by

- [Reference to the blocking issue, if any]
Or "None — can start immediately" if no blockers.

## Additional context

[Any extra observations relevant to this slice]
```

When creating a breakdown:

- **Prefer many thin issues over few thick ones** — each should be independently fixable and verifiable
- **Create issues in dependency order** so you can reference real issue numbers in "Blocked by"
- **Mark blocking relationships honestly**

### 5. Continue the session

Keep going until the user says they are done.
Each issue is independent — don't batch them into one long summary.
