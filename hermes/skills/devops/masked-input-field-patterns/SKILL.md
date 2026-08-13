---
name: masked-input-field-patterns
description: Use when building typed/masked input fields in ERP forms.
---

# Masked Input Field Patterns

Patterns for building text inputs that accept typed values in a structured format (time `HH:MM`, durations, numeric codes) with native-input UX, inside erp-admin's `@hilo/ui` (React + Tailwind). Use when converting a picker/trigger to a typed input, or adding a masked field.

## Core pattern (worked example: TimePicker typed input, issue #156, 2026-08-07)

Three layers, each a separate pure function/testable unit:

1. **Mask while typing** (`format<X>Draft(raw)`): shape the keystrokes as they arrive.
2. **Loose parse + commit on blur/Enter** (`parse<X>Input(raw)`): accept partial input, normalize, emit only when the value actually changed; invalid → revert, no emit.
3. **Controlled-value resync**: draft follows the parent `value` without setState-in-effect loops.

### 1. Mask — auto-format digits, PRESERVE explicit separators

Native `type=time` feel: first 2 digits = hour, next 2 = minutes, `:` auto-inserted. **The naive mask (strip non-digits then insert the separator after position 2) is WRONG** — it destroys an explicitly typed separator: `9:5` → `95` (invalid), `08:` → `08` (colon vanishes, cursor jumps). Branch on the separator FIRST when present:

```ts
export function formatTimePickerDraft(raw: string): string {
  if (!raw) return '';
  if (raw.includes(':')) {
    const [hPart, ...rest] = raw.split(':');
    const mPart = rest.join(':');
    const hh = hPart.replace(/[^0-9]/g, '').slice(0, 2);
    const mm = mPart.replace(/[^0-9]/g, '').slice(0, 2);
    return mm ? `${hh}:${mm}` : `${hh}:`;
  }
  const digits = raw.replace(/[^0-9]/g, '').slice(0, 4);
  if (digits.length === 0) return '';
  if (digits.length <= 2) return digits; // hour not finished — keep editable
  return `${digits.slice(0, 2)}:${digits.slice(2)}`;
}
```

- Out-of-range values mid-typing (`25`, `25:0`) are KEPT so the user can backspace — rejected at commit, not at keystroke.
- Input attrs: `inputMode="numeric"`, `autoComplete="off"`, `spellCheck={false}`, `maxLength` = final formatted length (5 for `HH:MM`).

### 2. Loose parse + commit on blur/Enter

```ts
// `8`, `8:3`, `08:30` accepted; minute defaults 0; null for empty/out-of-range
export function parseTimePickerInput(raw: string): { hour: number; minute: number } | null {
  const t = raw.trim();
  if (!t) return null;
  const m = /^(\d{1,2})(?::(\d{1,2}))?$/.exec(t);
  if (!m) return null;
  const hour = Number(m[1]);
  const minute = m[2] === undefined ? 0 : Number(m[2]);
  if (hour > 23 || minute > 59) return null;
  return { hour, minute };
}
```

Commit handler (blur/Enter):
- Parse → round sub-unit to the nearest step (reuse the wheel's index math, e.g. `minuteIndexFromValue` for `minuteStep`) → format canonical (`HH:MM`).
- `setDraft(formatted)`; emit `onChange(formatted)` **only if `formatted !== value`**.
- Parse null → `setDraft(displayValue)` (revert to committed), no emit. Empty input → revert (field cannot be cleared — decide per use case; flag it in review if clearing matters).

### 3. Controlled-value resync — render-phase setState (React-sanctioned)

Draft must follow the parent `value` (wheel selection, parent reset) without a setState-in-effect cascade:

```ts
const [prevValue, setPrevValue] = useState(value);
if (prevValue !== value) {
  setPrevValue(value);
  setDraft(displayValue); // derived from value during this render
}
```

This is React's official "adjusting state during render" pattern — legal when guarded by a previous-value comparison.

## Picker-trigger conversion specifics (TimePicker)

- Trigger `<button>` → `<input type="text">` inside `PopoverTrigger asChild`; the clock icon becomes a separate absolutely-positioned `<button tabIndex={-1} aria-hidden="true">` (opens popover on click; the input stays the accessible trigger via `aria-label`, default `"Time"`).
- Keyboard: Enter = commit + open popover; ArrowDown = open popover (preserve the old button-trigger keys).
- Wheel popover sync on open: normalize the draft (`normalizeDraft() ?? parse(value)`) and scroll the wheels to it, so typed values and the wheel stay consistent.
- `readOnly` branch stays a non-interactive div — the input path is only for editable mode.

## Tests (23 in TimePicker.test.tsx — all passing)

- Mask: no-colon flow `"0"`→`"08"`→`"08:3"`→`"08:30"` asserted after each `fireEvent.change`; explicit colon preserved (`9:5`, `08:`); non-digits stripped (`08a30` → `08:30`).
- Parse: accepts loose (`8`, `8:3`, `08:30`, ` 9:05 `); rejects (`24:00`, `12:60`, `8:`, `:30`, `830`, `8 : 30`).
- Commit: blur/Enter emits normalized; invalid/empty → no emit + revert; `minuteStep` rounding (`8:22` step 15 → `08:15`); no emit when unchanged; popover opens on Enter/ArrowDown; disabled input; aria-label.

## Verification

```bash
pnpm --filter @hilo/ui exec vitest run src/components/ui/TimePicker.test.tsx
pnpm --filter @hilo/ui typecheck
```

## Files (worked example)

- `packages/ui/src/components/ui/TimePicker.tsx`
- `packages/ui/src/lib/time-picker-utils.ts` (`formatTimePickerDraft`, `parseTimePickerInput`, `formatTimePickerValue`)
- `packages/ui/src/components/ui/TimePicker.test.tsx`
