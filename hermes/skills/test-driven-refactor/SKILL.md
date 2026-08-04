---
name: test-driven-discipline
description: Preserve behavior while refactoring by verifying call sites before and after and keeping changes surgical. Use when user says "refactor", "rename", "extract", "restructure", "clean up", or wants to reorganize code without changing behavior.
---

# Test-Driven Refactor

Preserve behavior. Verify call sites before and after. Touch only what you must.
Refactoring should make code better without breaking anything. This skill enforces that discipline.

**Tradeoff:** Full rigor is for non-trivial refactors.
Renaming a local variable in a single function does not need a call-site audit.

## When to Use

- User asks to refactor, rename, extract, restructure, or clean up code
- You're changing code organization without changing behavior
- A rename affects public APIs or shared interfaces

## Before Refactoring

### 1. Establish the Baseline

**Prove it works before you change it.**

- Run the existing tests — they must pass before you start
- If tests are missing for the area being refactored, note that first; don't assume it is safe
- Note the current public API surface (function signatures, exports, types)

### 2. Map the Blast Radius

**Know what depends on what you're changing.**

- Search for every call site, import, and reference
- For renames: list all files that reference the symbol
- For signature changes: list all callers and check compatibility
- For structural changes: identify modules that import from affected files

### 3. Plan the Steps

**Small, verifiable steps — not one big rewrite.**

```
1. [Rename symbol X] → verify: search confirms no remaining references to old name
2. [Update call sites] → verify: typecheck passes
3. [Move file] → verify: imports resolve, tests pass
```

## During Refactoring

### Surgical Changes Only

- Don't "improve" adjacent code — refactor only what was asked
- Don't change behavior — the same inputs should produce the same outputs
- Match existing style — even if you'd format it differently
- Don't remove pre-existing dead code unless asked

### Preserve Public Contracts

- Don't rename public APIs without listing and updating all call sites
- Don't change function signatures without checking every caller
- If a rename is too wide-reaching, suggest an alias instead

### Clean Up Your Own Mess

- Remove imports/variables/functions that your changes made unused
- Don't remove dead code that existed before your changes
- Update docs/comments that reference renamed entities

## After Refactoring

### Verify

1. Run the full test suite for affected modules
2. Run typecheck / linter if applicable
3. Confirm the public API is unchanged (or list intentional changes)

### Summarize

1. **What was refactored**: brief description of the structural change
2. **Blast radius**: number of files/symbols affected
3. **Verification**: tests run and their results
4. **API changes**: any public-facing changes (should be none, or explicitly requested)

## Anti-Patterns

| Don't | Do instead |
|-------|------------|
| Refactor and add features in the same change | Separate refactor from feature work |
| Rename without checking call sites | Search first, rename second |
| "Improve" code while refactoring | Refactor only what was asked |
| Skip the pre-refactor test run | Establish baseline first |
| Remove pre-existing dead code | Mention it, don't delete it |
