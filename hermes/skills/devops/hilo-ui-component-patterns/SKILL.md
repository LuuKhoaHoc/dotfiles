---
name: hilo-ui-component-patterns
description: Use when editing shared @hilo/ui components in packages/ui.
---

# @hilo/ui Component Patterns

Use when modifying or building shared components in `packages/ui/src/components/` (TimePicker, DatePicker, Input, comboboxes...) or their lib helpers (`packages/ui/src/lib/`). TimePicker is used by ~15+ attendance/time forms across employee + hr MFEs — changes here ripple wide.

## Ground rules (packages/ui AGENTS.md)

- Primitives in `components/ui/`, project-specific visual composites in `components/customs/`; no domain/business logic in the package.
- Export public surface via `src/index.ts`.
- Shared behavior → test inside `packages/ui` (component-level); feature wrappers stay thin.
- Gate after touching the package: `pnpm --filter @hilo/ui test` + `pnpm --filter @hilo/ui typecheck` + `pnpm --filter @hilo/ui build` (eslint + prettier on changed files too). MFE builds resolve `@hilo/ui` from **dist** — rebuild the package BEFORE building MFEs (see gitlab-issue-workflow pitfall).

## TimePicker typed input (native `<input type="time">` UX)

TimePicker trigger is a real text input (since #156): type directly AND/OR open the wheel popover. UX requirement (user, 2026-08-07): behave like a native time input — first 2 digits = hour, next 2 = minute, colon auto-inserted; typing `:` explicitly must still work.

- `formatTimePickerDraft(raw)` — while-typing mask, wired into `onChange`:
  - No colon in raw: strip non-digits, ≤2 digits as-is, 3–4 digits → `HH:M` / `HH:MM` (`0830` → `08:30`).
  - Colon in raw: split on `:`, sanitize each side separately, keep `HH:` when minute empty — `9:5` stays `9:5`.
  - ⚠️ Naive `raw.replace(/[^0-9]/g, '')` on the WHOLE string corrupts explicit-colon input (`9:5` → `95` → parse fails → blur reverts). Always preserve the separator the user typed.
- `parseTimePickerInput(raw)` — loose parse on commit (blur/Enter): `8` → `{8, 0}`, `8:3` → `{8, 3}`, `08:30` ok; null for empty / `24:00` / `12:60` / `830` / `abc`. Commit normalizes to `HH:mm`, emits only if different from current `value`; invalid → revert draft, no emit.
- `minuteStep` rounding: minutes snap to the nearest wheel step on commit (`8:22` + step 15 → `08:15`).
- Popover wheel sync: on open, seed wheels from `normalizeDraft() ?? parseTimePickerValue(value)` — typed-but-uncommitted draft wins over the committed value.
- Controlled resync: `prevValue` state + setState-during-render when the `value` prop changes (React-sanctioned adjust-state-during-render pattern) keeps the draft in sync with wheel emits / parent resets.
- Input attrs: `maxLength={5}`, `inputMode="numeric"`, `autoComplete="off"`, `spellCheck={false}`.
- Helpers live in `packages/ui/src/lib/time-picker-utils.ts` (`formatTimePickerValue`, `parseTimePickerValue`, `parseTimePickerInput`, `formatTimePickerDraft`) — reuse before writing local parsing in apps.

## Pitfalls

- **Dead exports block merge**: a helper added to `lib/` but never wired into the component (real case #156: `formatTimePickerDraft` sat uncommitted+unused — typed `0830` reverted on blur because `onChange` still set the raw draft). Wire it or delete it before commit.
- **Don't review only commits in a WIP worktree** — uncommitted diffs carry the real state; see mr-local-verification skill.
- Form wiring (FormField / useStore / read-only states) lives in hr-form-patterns skill — component internals vs form wiring are separate concerns.
