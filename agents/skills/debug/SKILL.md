---
name: debug
description: Disciplined diagnosis loop for hard bugs and performance regressions. Reproduce → minimise → hypothesise → instrument → fix → regression-test. Use when user says "diagnose this" / "debug this", reports a bug, says something is broken/throwing/failing, or describes a performance regression.
---

# Debug

A disciplined diagnosis loop. Do not guess and patch — gather evidence, form a hypothesis, verify, then fix.

**Tradeoff:** This loop adds overhead. For trivial typos or obvious one-liners, skip straight to the fix and confirm with a test.

## When to Use

- User reports a bug, crash, wrong output, or performance regression
- A test is failing and the cause is not immediately obvious
- You need to trace a problem through multiple layers of code

## The Diagnosis Loop

### 1. Reproduce

**Make the failure visible before you touch anything.**

- Run the failing test, command, or request the error output
- If the user described the issue, reproduce it with a minimal input
- Capture the exact error message, stack trace, or unexpected output
- Note: if you cannot reproduce it, say so — do not proceed to fixing

### 2. Minimise

**Reduce to the smallest case that still fails.**

- Strip away unrelated inputs, configs, or code paths
- Identify the exact line or function where behavior diverges from expected
- If the failure involves data, find the minimal dataset that triggers it

### 3. Hypothesise

**State the likely root cause before editing any code.**

- Present your hypothesis explicitly: "I believe X is happening because Y"
- If multiple causes are plausible, list them ranked by likelihood
- If you're uncertain, say what additional information would resolve it
- Push back if the root cause seems to be in a different layer than reported

### 4. Instrument (if needed)

**Add targeted logging or assertions to confirm your hypothesis.**

- Add the minimum instrumentation to prove or disprove the hypothesis
- Use structured output (logs, assertions, print statements) — not guesswork
- Remove instrumentation after confirming (don't leave debug prints)

### 5. Fix

**Make the smallest change that addresses the root cause.**

- Fix the root cause, not the symptom
- One fix per hypothesis — don't bundle unrelated changes
- Match existing code style and patterns
- Don't "improve" adjacent code while you're there

### 6. Verify

**Prove the fix works and nothing else broke.**

- Run the original failing case — it should now pass
- Run the broader test suite for the affected module
- Add a regression test that captures this specific failure mode
- If no test infrastructure exists, describe how to verify manually

## After the Fix

Summarize:
1. **Root cause**: one sentence
2. **Fix**: what changed and why
3. **Verification**: tests run and their results
4. **Regression test**: added or skipped (with reason)

## Anti-Patterns

| Don't | Do instead |
|-------|------------|
| Guess and patch | Reproduce first, then hypothesise |
| Fix symptoms | Fix root causes |
| Bundle unrelated fixes | One fix per hypothesis |
| Leave debug prints | Remove instrumentation after confirming |
| Skip the regression test | Add a test that would have caught this |
