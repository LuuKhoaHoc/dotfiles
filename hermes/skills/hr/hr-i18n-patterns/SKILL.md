---
name: hr-i18n-patterns
description: i18n patterns for HR MFE — adding translations, label key maps, and helper functions for enums/constants.
triggers:
  - adding multi-language support to HR constants or enums
  - mapping backend enum values to translation keys
  - using useTranslations in HR components
---

# HR i18n Patterns

## Translation infrastructure

- Package: `@hilo/locales`
- Hook: `useTranslations('hr')` → `t(key)`
- Namespace files: `packages/locales/src/translations/{en,vi}/hr.json`
- Always update BOTH `en` and `vi` together (locales AGENTS.md rule).

## Enum → i18n label key pattern

When a constant file (e.g. `request-types.ts`) needs multi-language labels:

1. Keep the raw enum/const unchanged.
2. Add a `LABEL_KEYS` map typed as `Record<EnumType, string>` pointing to existing translation keys.
3. Add an `isXxx` type guard and a `getXxxLabelKey(value: string): string` helper that falls back to the raw value.
4. Export all three from the same file.

```typescript
export const REQUEST_TYPE_LABEL_KEYS: Record<RequestType, string> = {
  [REQUEST_TYPES.OT]: 'features.requestManagement.create.requestTypes.ot',
  [REQUEST_TYPES.WFH]: 'features.requestManagement.create.requestTypes.wfh',
  [REQUEST_TYPES.BUSINESS_TRIP]:
    'features.requestManagement.create.requestTypes.businessTrip',
  [REQUEST_TYPES.ATTENDANCE_ADJUSTMENT]:
    'features.requestManagement.create.requestTypes.attendanceAdjustment',
  [REQUEST_TYPES.OTHER]: 'features.requestManagement.create.requestTypes.other',
  [REQUEST_TYPES.LEAVE]: 'features.requestManagement.create.requestTypes.leave',
} as const;

function isRequestType(value: string): value is RequestType {
  return value in REQUEST_TYPE_LABEL_KEYS;
}

export function getRequestTypeLabelKey(type: string): string {
  if (isRequestType(type)) return REQUEST_TYPE_LABEL_KEYS[type];
  return type;
}
```

## Consuming in components

```typescript
import { getRequestTypeLabelKey } from '@hr/shared/constants/request-types';
import { useTranslations } from '@hilo/locales';

const { t } = useTranslations('hr');
// ...
t(getRequestTypeLabelKey(item.requestType))
```

## Translation key location for request types

Existing keys live under `features.requestManagement.create.requestTypes.*` in both `en/hr.json` and `vi/hr.json`:

| Value                  | Key suffix              | EN                      | VI                |
|------------------------|-------------------------|-------------------------|-------------------|
| `ot`                   | `ot`                    | OT                      | OT                |
| `wfh`                  | `wfh`                   | Work from home          | Làm việc tại nhà |
| `business_trip`        | `businessTrip`          | Business trip           | Công tác          |
| `attendance_adjustment`| `attendanceAdjustment`  | Attendance adjustment   | Chỉnh công        |
| `other`                | `other`                 | Other                   | Khác              |
| `leave`                | `leave`                 | Leave                   | Nghỉ phép         |

Note: backend uses `snake_case`, i18n keys use `camelCase`.

## Pitfalls

- Backend enum values are `snake_case` (`business_trip`), i18n keys are `camelCase` (`businessTrip`) — the LABEL_KEYS map bridges this.
- Do NOT hardcode display strings in components; always go through `t(getXxxLabelKey(...))`.
- `training` exists in the i18n file but NOT in `REQUEST_TYPES` constant — do not add it to the map unless the backend contract includes it.
- `emptyOutDir: false` in locales build — safe to rebuild without wiping other artifacts.

## Verification

```bash
pnpm --filter hr-dashboard typecheck
pnpm --filter @hilo/locales build
```
