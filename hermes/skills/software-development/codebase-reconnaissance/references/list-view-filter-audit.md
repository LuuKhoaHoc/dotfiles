# List-View Filter Standardization Audit (erp-admin)

Use when the task is: "tìm feature/page list nào có button filter, chưa có filter, hoặc filter lệch chuẩn (không dùng component chuẩn)" — then create tickets. Worked example: 2026-08-03 scan of all MFEs → issues #122–#125.

## Canonical standard (erp-admin)

- **Filter panel chuẩn:** `TableFiltersPanel` — `packages/ui/src/components/customs/TableFiltersPanel.tsx`, exported via `@hilo/ui` (file is NOT named TableFiltersPanel.tsx at the import site — grep by content).
  Props: `open`, `onOpenChange`, `title`, `categories` (`TableFilterCategory[]`), `sections` (`TableFilterSection[]`: id/title/icon/fields), `value` (`TableFiltersValueMap`), `onApply`, `labels`.
- **NOT the standard:** `DataTable`'s built-in toolbar (search Input + `DateRangePicker`) is search/date-range only — a list view with just that classifies as NONE. Quick-filter `Select` bars, filter chips, hand-rolled `ResponsiveModal`/`Popover`/`RadioGroup` dialogs = CUSTOM (lệch chuẩn).
- **Dead filter buttons** (button exists, no onClick / no-op / "coming soon" toast) = NONE with a note — cheapest wins, just wire the panel to the existing trigger.

## Classification per list view

- ✅ STANDARD — filter UI uses `TableFiltersPanel` from `@hilo/ui`. Verify the TRIGGER wiring (header button → open state → panel rendered), not just that a panel file exists.
- ⚠️ CUSTOM — has filter UI but hand-rolled (dialog/sheet/chips/inline bar), not TableFiltersPanel.
- ❌ NONE — no filter panel (search-only or nothing). Dead Filter buttons count as NONE.
- 🔍 SUB — sub-list inside a detail dialog/modal (employee pickers, detail-tab tables, price history). Usually out of scope; note briefly.

## Prep before dispatch

```bash
cd <repo> && git fetch origin -q && git merge --ff-only origin/develop -q  # subagents read the working tree
grep -rl "DataTable" apps/<mfe>/src/features --include="*.tsx" | grep -v -E "test|spec"  # build per-MFE file lists
```

## Subagent dispatch (parallel, 1 per MFE)

Context block per task must include: repo path, canonical component path + props, the 4 classification definitions, the exact file list to scan, and the output format:

```text
OUTPUT (tiếng Việt):
1. Bảng markdown: | # | Feature/List view | File (relative) | Trạng thái | Evidence (file:line + tên component) | Ghi chú |
2. Tóm tắt: tổng số list view, số STANDARD, số CUSTOM, số NONE, số SUB.
3. Liệt kê riêng các list view NONE và CUSTOM (đây là mục tiêu để tạo ticket).
Chỉ đọc file, không sửa gì.
```

- Split rules: 1 task per MFE; HR is the biggest → split in two (e.g. attendances+salary+dashboard+employees vs hrm-settings+organizations+insurance-tax+offboarding+request/change/time-off). 5 concurrent max.
- Role = leaf (read-only reporting).
- Tell subagents to check trigger wiring AND host files (view/header) — panel exists but never opened = not STANDARD.

## Consolidation → tickets (user preference, erp-admin)

- **1 issue per MFE**, even for one assignee — devs never touch the same files. Title `[<MFE>] ...`.
- **Skip MFEs already fully standard** (e.g. Finance was 2/2 STANDARD → no issue); report the skip.
- Link ALL issues with `mcp__gitlab__create_issue_link` (link_type=`relates_to`, all pairs).
- Labels: MFE label (`HR`, `employee`, `crm` for sale/product/finance) + `Refactor` + `frontend`; assignee QuyCN (id=31) for HR/product work.
- Description: `## What to build` (hiện trạng quét + checklist per list view with current state) / `## Acceptance criteria` (TableFiltersPanel everywhere, filter state in URL query params via useUrlState + createSharedListUrlStateSchema, reset page on filter change, i18n en+vi, typecheck) / `## Blocked by: None` / `## References` (canonical component path).
- Post ONE consolidated note on the biggest issue tagging `@QuyCN`: sibling issues, priority order (dead buttons/no-ops first → migrate CUSTOM → add NONE, big business list views before config tabs), reference components to copy, and a "Đừng làm" section (no new hand-rolled filters, no touching other MFE files, no parallel date-range when the panel has a date-range section).

## Pitfalls

- Grep the canonical component by content, not filename (it's exported from `index.ts`).
- Sync local branch to origin/develop BEFORE dispatching (subagents read the working tree).
- Report/base tables: fix at the base wrapper once (e.g. `ReportDataTable`) — not per child table.
- Filter button rendered conditionally per tab (e.g. product categories tab) — flag that the trigger must be hoisted to cover all tabs.
- Inline filter bars (search/status/dateType/sort in the same row) are still CUSTOM even if they look tidy.
