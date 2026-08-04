---
name: bug-triage
description: Disciplined triage for reported bugs and regressions. Use when the user says "bug này sao", "investigate this crash", "regression", "something broke", or needs a structured investigation into a fault before assigning it.
---

# Bug Triage

Triage a reported or observed fault in four phases:

1. **Reproduce**
2. **Minimize**
3. **Hypothesise**
4. **Fix + regression-test**

## When to Use

- User reports a bug, crash, wrong output, or performance regression
- A test or behavior is failing and the cause is not immediately obvious
- You need to trace a problem through multiple integration layers before assigning the work

## 1. Reproduce

**Make the failure visible before touching anything.**

- Run the failing scenario, command, request, or test
- Capture the exact error message, stack trace, wrong output, or timing
- If you cannot reproduce it, say so — do not proceed to fixing
- Confirm: same failure mode the user described, not some nearby unrelated failure

## 2. Minimise

**Reduce to the smallest case that still fails.**

- Strip inputs, data, environment, and config until you can't cut any further
- Identify the exact area or layer where behavior diverges from expected
- Done when every remaining element is load-bearing

## 3. Hypothesise

**State ranked root-cause hypotheses before changing anything.**

- State the likely root cause explicitly
- List alternatives ranked by likelihood
- If multiple causes are plausible, note what would distinguish them
- Push back if the reported symptom appears to come from a different layer than expected

## 4. Fix + regression-test

**Make the smallest change that addresses the root cause.**

- Match existing code style and patterns
- Don't bundle unrelated changes
- If feasible, add a regression test that would have caught this failure earlier
- Re-run the original reproduction — it should now pass

## Summary format

After the fix, summarize:

- **Root cause**: one sentence
- **Fix**: what changed and why
- **Verification**: how you confirmed it
- **Regressions**: tests added or skipped, with reason

## Anti-patterns

- Don't guess and patch — reproduce first
- Don't fix symptoms instead of root cause
- Don't bundle unrelated fixes
- Don't skip the regression test when there is a natural seam for it
