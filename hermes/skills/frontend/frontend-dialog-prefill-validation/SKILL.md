---
name: frontend-dialog-prefill-validation
description: Use for dialog form prefill and realtime validation.
---

# Frontend Dialog Prefill & Validation

## Workflow

1. Trace row DTO → callback → store → composition props → form initialization → rendered fields.
2. Keep realtime `onChange` validation for inline errors; do not disable it to hide open-time errors.
3. Seed prefilled values atomically with `reset`/`initialize`; repeated `setFieldValue` calls during opening can validate incomplete intermediate state.
4. Never pass a store action with an optional prefill argument directly as an event handler: React supplies a `MouseEvent`. Wrap it: `onClick={() => openDialog()}`.
5. Normalize table placeholders with shared constants, especially `EMPTY_TIME_VALUE` (`--:--`), not hardcoded `--`.
6. Pass both check-in and check-out when available. If neither exists, derive `absent`; otherwise derive `present`.
7. Reset transient store state on unmount and form state on close.

## Review checklist

- [ ] Date is `Date | undefined`, with correct property name.
- [ ] Check-in/out survive callback and store.
- [ ] Empty placeholders become empty strings before validation.
- [ ] No-punch rows open as `absent`.
- [ ] Blank dialog opens without required-field errors.
- [ ] Prefilled dialog validates on change and submit.
- [ ] Tests cover happy path, no-punch path, event-handler pollution, close reset, and store reset.

## Pitfalls

- Typecheck does not prove runtime prefill; a click event can pollute a structurally accepted optional object.
- Comparing `'--'` misses the canonical `'--:--'` placeholder.
- Removing `validators.onChange` is usually the wrong fix; fix initialization timing/state writes instead.
- Re-read live files before editing when an IDE or another agent may modify the working tree.
