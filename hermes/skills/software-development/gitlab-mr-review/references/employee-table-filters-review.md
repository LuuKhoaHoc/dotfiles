# Employee `TableFiltersPanel` migration review checklist

Use this reference when an Employee/HR MFE migrates `DataTable` toolbar filters to `TableFiltersPanel`.

## 1. Verify date-only serialization end to end

`TableFiltersPanel` delegates date selection to `DateSelectPicker`, which creates local-midnight dates (`new Date(year, month - 1, day)`). Never serialize a date-only filter with `toISOString().split('T')[0]`: in UTC+7, local `2026-04-15 00:00` becomes ISO date `2026-04-14`.

For every changed `onApply`, enumerate the date serializer. The repository helper is:

```ts
import { formatDateValue } from '@hilo/shared';

const formatDate = (value?: Date) => (value ? formatDateValue(value) : undefined);
```

Check all six links: picker → panel draft → `onApply` → URL state → query key → HTTP params. A date shown in the panel is not proof that the backend receives the same day.

## 2. Check URL-state and API plumbing

- Filter changes must reset the relevant page to `1`.
- Filter params must be included in the React Query key.
- If an API uses `buildSharedListQueryRequest`, inspect the resulting object: the shared Zod schema only preserves its declared fields. Resource-specific `fromDate`/`toDate` must be spread into the final axios params after the builder, or passed through an API-specific schema.
- For tabs sharing URL state but querying different resources, verify that changing tabs cannot carry a search/type/date value into an incompatible query.

## 3. Check exact i18n namespace, not substring presence

Read the component's `useTranslations('<namespace>')` call and traverse that exact locale JSON namespace in both `en` and `vi`. A locale diff can add keys under `features.directory.filters` while the component calls `t('directory.filters.*')`; those are different paths and render missing keys.

Run the verifier with an explicit namespace for Employee code:

```bash
python3 scripts/verify_i18n_keys.py <head_sha> <changed-ts-tsx-files> --ns=employee
```

Use changed files only. Verify object-form defaults too (`t('key', { defaultValue: '...' })`): missing keys silently render the literal fallback, which can be the wrong language. The checker is namespace-aware only when `--ns=<namespace>` is supplied; without it, it performs language-level, namespace-agnostic checks.

## 4. Test behavior, not only prop renames

When a table receives a panel, update tests beyond interface props:

- Stub `window.matchMedia` in the Employee test setup because `TableFiltersPanel` renders `ResponsiveModal`/`useMediaQuery` even when the panel is closed.
- Test apply/clear date values, page reset, query params, and active-count behavior.
- If a modal's old close behavior reset page/filter state and the migration removes it, either restore the reset or intentionally update the test and document the new persistence behavior. Never leave the implementation and existing test asserting opposite contracts.
- Run the focused tests on the MR branch after building the workspace packages required by package `exports`; report real failures rather than relying on a typecheck alone.

## 5. Review hygiene

- Remove unrelated locale changes with no consumer (for example, an orphaned label added to another MFE namespace).
- Conventional title format remains `type(scope): description`, e.g. `feat(employee): standardize list filters with TableFiltersPanel`.
