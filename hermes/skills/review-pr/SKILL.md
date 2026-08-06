---
name: review-pr
description: Review code changes like a senior engineer — correctness, security, edge cases, performance, maintainability. Use when user says "review this", "review the PR/MR", "check my changes", or wants a code review of a branch, diff, or set of changes.
---

# Review PR

**Review like a senior engineer who will be maintaining this code.**

Focus on real problems, not style nitpicks. Every issue should explain why it matters.

**Tradeoff:** For small, low-risk changes (config tweaks, copy updates, simple bug fixes), a lightweight review is fine. Reserve full rigor for logic changes, new features, and security-sensitive code.

## When to Use

- User asks to review a PR, MR, branch, or set of changes
- User wants feedback before merging or pushing
- User asks "does this look right?" about a code change

## Review Process

### 1. Understand the Context

Before reviewing code:
- What was the goal of this change? (issue, ticket, or user description)
- What's the scope? (new feature, bug fix, refactor, config change)
- What systems does it touch? (API, database, frontend, infra)

### 2. Review Through Four Lenses

Apply the Karpathy principles as review criteria:

#### Correctness
- Does the code do what it claims to do?
- Are there off-by-one errors, race conditions, or null handling issues?
- Are edge cases covered? (empty input, zero, negative, overflow, unicode)
- What happens on failure? (network timeout, disk full, malformed data)

#### Security
- Is user input validated and sanitised?
- Are there injection vectors? (SQL, XSS, command injection, path traversal)
- Are secrets/credentials handled safely? (not logged, not in error messages)
- Are permissions checked correctly?

#### Simplicity
- Is there unnecessary complexity that could be simplified?
- Are there abstractions for single-use code?
- Is error handling proportional to real risks (not impossible scenarios)?
- Could 200 lines be 50?

#### Surgical Changes
- Does the diff contain only changes related to the stated goal?
- Are there drive-by refactors, formatting changes, or unrelated "improvements"?
- Does it match existing code style and patterns?
- Are there changes to code the author shouldn't have touched?

### 3. Check for Missing Coverage

- Are there tests for the new/changed behavior?
- Do tests cover the happy path and failure paths?
- Are there integration points that need testing?
- Is test setup/teardown clean?

## Output Format

Structure your review as:

### 🔴 Blocking Issues
Must fix before merge. Each issue includes:
- **File and location**: where the problem is
- **Problem**: what's wrong and why it matters
- **Suggestion**: concrete fix (not just "this should be better")

### 🟡 Suggestions
Should fix, but not blocking. Lower severity issues:
- Maintainability improvements
- Potential edge cases worth considering
- Minor performance concerns

### 🟢 Nitpicks (optional)
Only include if genuinely helpful:
- Naming improvements
- Minor readability tweaks

### 📝 Suggested Tests
Tests that should be added to cover:
- Edge cases discovered during review
- Failure paths not currently tested
- Integration scenarios

### 📊 Overall Assessment
- **Risk level**: Low / Medium / High
- **Summary**: one-paragraph verdict
- **Recommendation**: Approve / Request Changes / Needs Discussion

## Anti-Patterns

| Don't | Do instead |
|-------|------------|
| Flag style issues the linter should catch | Focus on logic and design |
| Say "this could be better" | Say what's wrong and suggest a fix |
| Review what's not in the diff | Review only the changes |
| Nitpick naming in a 5-line PR | Reserve nitpicks for large reviews |
| Approve without understanding the goal | Understand context first |
