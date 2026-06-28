---
name: plan-first
description: Stop and think before coding. Restate the goal, inspect the codebase, produce a plan with verification steps, then execute. Use when user asks to build a feature, implement a change, or tackle a non-trivial task — especially when the scope is ambiguous or the approach is unclear.
---

# Plan First

**Don't assume. Don't hide confusion. Surface tradeoffs before writing code.**

This skill enforces a think-before-you-code discipline for non-trivial tasks.

**Tradeoff:** For trivial tasks (typo fixes, obvious one-liners, simple config changes), skip the plan and just do it. Use judgment.

## When to Use

- User asks to build a feature, add a capability, or implement a change
- The scope is ambiguous or multiple approaches exist
- The change touches multiple files or systems
- You're unsure about the existing architecture or patterns

## Before Editing

### 1. Restate the Goal

Summarize what the user wants in your own words. If the request is ambiguous:
- Present multiple interpretations — don't pick silently
- Ask specific clarifying questions rather than making assumptions
- Push back if a simpler approach would serve the goal better

### 2. Inspect the Codebase

**Understand the terrain before you move.**

- Read the relevant files and their surrounding context
- Identify existing patterns, conventions, and abstractions to follow
- Check for related tests, configs, or documentation
- Look for prior art — has something similar been done before?

### 3. Produce a Plan

**A brief, numbered plan with verification at each step.**

```
1. [Step] → verify: [how you'll confirm it worked]
2. [Step] → verify: [how you'll confirm it worked]
3. [Step] → verify: [how you'll confirm it worked]
```

Keep it short — 3-7 steps for most tasks. The plan is a tool, not a deliverable.

### 4. Confirm or Proceed

- If the plan is straightforward and low-risk: proceed
- If the change is risky, irreversible, or ambiguous: ask for confirmation
- If you discover something that changes the plan mid-execution: stop and re-plan

## During Editing

- **Make small, reviewable changes** — each step should be independently understandable
- **Prefer existing patterns** — match the codebase's style, even if you'd do it differently
- **Run the narrowest relevant checks** after each meaningful step (typecheck, lint, tests)
- **Don't gold-plate** — solve the stated problem, not hypothetical future ones

### Simplicity Check

After implementing each step, ask:
- Did I add anything beyond what was asked?
- Could this be simpler?
- Would a senior engineer say this is overcomplicated?

If yes to any, simplify before moving on.

## After Editing

Summarize:
1. **What changed**: list modified files with a one-line description each
2. **Verification**: what tests/checks were run and their results
3. **Risks or follow-ups**: anything the user should know about

## Anti-Patterns

| Don't | Do instead |
|-------|------------|
| Pick an interpretation silently | Present options and ask |
| Start coding immediately | Inspect first, plan second |
| Add features "for the future" | Solve only what was asked |
| Ignore existing patterns | Match the codebase style |
| Skip verification | Run checks after each step |
