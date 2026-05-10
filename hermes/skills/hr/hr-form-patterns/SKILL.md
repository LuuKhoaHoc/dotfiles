---
name: hr-form-patterns
description: Reusable form patterns for HR MFE including DatePicker integration, date conversion, and read-only handling.
triggers:
  - adding or modifying forms in apps/hr
  - replacing standard Inputs with DatePickers
  - handling record read-only/detail mode in dialogs
---

# HR Form Patterns

## DatePicker Integration

`FormField` from `@hilo/ui` does NOT support render props. Always use `useStore` + `form.setFieldValue`.

### Standard Conversion Pattern

The API provides dates as `yyyy-MM-dd` strings. `DatePicker` expects a `Date` object and returns one.

1. Import helpers + `useStore`:
   ```ts
   import { formatDateValue, parseDateValue } from '@hilo/shared';
   import { DatePicker, FormField } from '@hilo/ui';
   import { useStore } from '@tanstack/react-form';
   ```
2. Extract form values with `useStore`:
   ```ts
   const values = useStore(form.store, (state) => state.values);
   ```
3. Use `DatePicker` inside `FormField` WITHOUT render prop — read from `values`, update via `form.setFieldValue`:
   ```tsx
   <FormField
     name="requestDate"
     label={t('fields.requestDate')}
     required
   >
     <DatePicker
       disabled={isReadOnly}
       value={parseDateValue(values.requestDate)}
       onChange={(date) => form.setFieldValue('requestDate', formatDateValue(date))}
       displayFormat="dd/MM/yyyy"
       className="border-border-default bg-surface-default min-h-13.5 rounded-lg shadow-none"
     />
   </FormField>
   ```
4. Use `disabled` for read-only states — DatePicker has no `readOnly` prop.

## Input vs DatePicker for Dates

- ❌ Do NOT use `<Input />` for date fields if the user needs to edit them.
- ✅ Always use `<DatePicker />` for date fields to ensure correct formatting and user experience.
- When a record is in "Detail" mode (`isReadOnly`), ensure components like `DatePicker` or `Select` use the `disabled` prop to prevent interaction.

## Pitfalls

- ❌ **Do NOT use raw `<div>` wrapper with manual label + Input for status fields.** The correct approach is `FormField` with conditional rendering inside. This ensures proper label association, validation, and consistent styling.
- ❌ **Do NOT use render prop on `FormField`** — it doesn't support it. Use `useStore(form.store)` to access current values.
- ❌ **Do NOT hard-code status values** — import from `../../constants/` (e.g., `REQUEST_MANAGEMENT_STATUS_OPTIONS`).

When a field needs to show a fixed list of options and may be read-only or editable:

1. Import Select components:
   ```ts
   import {
     FormField,
     Select,
     SelectContent,
     SelectItem,
     SelectTrigger,
     SelectValue,
   } from '@hilo/ui';
   ```

2. Use conditional rendering based on `isReadOnly`:
   ```tsx
   <FormField
     name="status"
     label={t('fields.status')}
     required
   >
     {isReadOnly ? (
       <Input
         value={t(`labels.${values.status}`)}
         readOnly
         className="border-border-default bg-surface-default min-h-13.5 rounded-lg shadow-none"
       />
     ) : (
       <Select
         value={values.status}
         onValueChange={(value) => form.setFieldValue('status', value)}
       >
         <SelectTrigger className="border-border-default bg-surface-default min-h-13.5 rounded-lg shadow-none">
           <SelectValue />
         </SelectTrigger>
         <SelectContent>
           {STATUS_OPTIONS.map((status) => (
             <SelectItem key={status} value={status}>
               {t(`labels.${status}`)}
             </SelectItem>
           ))}
         </SelectContent>
       </Select>
     )}
   </FormField>
   ```

3. Keep `Select` in sync with form state using `onValueChange` + `form.setFieldValue`.

## Common Shared Helpers

| Helper | Source | Purpose |
|--------|--------|---------|
| `parseDateValue(string)` | `@hilo/shared` | Converts `yyyy-MM-dd` to `Date | undefined` |
| `formatDateValue(Date)` | `@hilo/shared` | Converts `Date` to `yyyy-MM-dd` string |

## Verification

```bash
pnpm --filter hr-dashboard typecheck
```
