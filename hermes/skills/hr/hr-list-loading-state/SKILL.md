---
name: hr-list-loading-state
description: >
  Add TableLoadingRows skeleton to HR feature list views. Canonical pattern lives in
  AttendanceListCard.tsx. Follow this exact wiring: hook exposes isLoading → list view
  prop → TableBody conditional render.
triggers:
  - "add TableLoadingRows"
  - "add loading skeleton"
  - "add isLoading to list"
  - "skeleton rows for table"
category: hr
---

# HR List Loading State — TableLoadingRows Wiring

## Trigger

Add skeleton loading rows to any HR feature table when API call fires (isLoading).

## Canonical Reference

`apps/hr/src/features/attendances/components/tabs/attendance-lists/AttendanceListCard.tsx`

Pattern already proven here. Use it as template.

## Steps

### 1. List View Component

**a. Import**
```ts
import {
  // ... existing imports
  TableLoadingRows,
} from '@hilo/ui';
```

**b. Add prop to interface**
```ts
interface XxxListViewProps {
  // ... existing props
  isLoading?: boolean;
}
```

**c. Destructure in function signature**
```ts
export function XxxListView({
  // ... existing destructure
  isLoading,
}: XxxListViewProps) {
```

**d. Guard early empty-state return**
```ts
// Before
if (items.length === 0) {

// After
if (!isLoading && items.length === 0) {
```

**e. Conditional TableBody render**
```ts
<TableBody>
  {isLoading ? (
    <TableLoadingRows colSpan={visibleColumnIds.length} />
  ) : (
    currentItems.map((item) => (
      <TableRow key={item.id} ...>
        {/* cells */}
      </TableRow>
    ))
  )}
</TableBody>
```

### 2. Wrapper Component

**a. Pull isLoading from data source hook**
```ts
// Hook already exposes isLoading — just destructure it
const { data, isLoading } = useXxxDataSource();
const { data: inboxData, isLoading: inboxIsLoading } = useXxxInboxDataSource();
```

**b. Pass to list view**
```ts
< XxxListView
  // ... existing props
  isLoading={
    activeTab === TAB.NEED_APPROVAL ? inboxIsLoading : isLoading
  }
/>
```

### 3. Verify

```bash
pnpm --filter hr-dashboard typecheck
```

## Pitfalls

- **Missing early return guard** → skeleton and empty view both render simultaneously on first load. Must add `!isLoading &&` to the empty check.
- **colSpan mismatch** → skeleton rows span wrong column count. Use `visibleColumnIds.length` for dynamic columns, or `columnCount` constant for fixed columns.
- **isLoading undefined** → TableLoadingRows handles optional gracefully (default behavior), but wrapper should always pass explicit value from hook.

## Files in Scope

| File | Change |
|------|--------|
| `features/*/components/*ListView.tsx` | Add prop, conditional render |
| `features/*/components/*ViewWrapper.tsx` | Destructure isLoading, pass to list view |
