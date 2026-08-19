# DataTable Keyboard Guard Pattern

## The Bug (MR !623, commit ded916f3)

`stopRowClickFromInteractiveTarget` in `packages/ui/src/components/ui/DataTable.tsx` uses `event.target.closest(ROW_CLICK_IGNORED_SELECTOR)` to detect interactive elements.

- **`onClick`**: `event.target` = clicked element → `closest()` works ✓
- **`onKeyDown`**: `event.target` = focused element (the `<td>` itself) → `closest('button')` returns `null` → propagation NOT stopped → row click fires unexpectedly

## The Fix

```tsx
function stopRowClickFromInteractiveTarget(
  event: React.MouseEvent<HTMLTableCellElement> | React.KeyboardEvent<HTMLTableCellElement>,
) {
  const target =
    event.type === 'keydown'
      ? (event.currentTarget.querySelector(':focus') ?? event.target)
      : event.target;

  if (target instanceof Element && target.closest(ROW_CLICK_IGNORED_SELECTOR)) {
    event.stopPropagation();
  }
}
```

Key: `event.currentTarget` = the `<td>` (always), `querySelector(':focus')` = the focused child inside it.

## Test Pattern

```tsx
it('does not fire row click when a focused data-cell control receives a key event', () => {
  const onRowClick = vi.fn();
  // render DataTable with button in cell...
  const button = screen.getByRole('button', { name: 'Open control' });
  const cell = button.closest('td');
  button.focus();
  fireEvent.keyDown(cell, { key: 'Enter' });
  fireEvent.keyDown(cell, { key: ' ' });
  expect(onRowClick).not.toHaveBeenCalled();
});
```

## ROW_CLICK_IGNORED_SELECTOR

```tsx
const ROW_CLICK_IGNORED_SELECTOR = [
  'a', 'button', 'input', 'select', 'textarea',
  '[contenteditable="true"]', '[data-row-click-ignore="true"]',
  '[role="button"]', '[role="checkbox"]', '[role="link"]',
  '[role="menuitem"]', '[role="option"]', '[role="switch"]',
].join(',');
```

Action columns (`ACTION_COLUMN_IDS = ['action', 'actions', 'select', '__expand']`) always get `stopPropagation()` regardless of target.
