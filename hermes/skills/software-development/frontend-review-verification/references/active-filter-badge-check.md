# Active-filter badge review recipe

Use this recipe when an MR claims to fix a filter count/badge.

## Reproduction matrix

For the feature's default card/screen, inspect the value exposed to the component and the rendered count for:

1. URL with no `sort` parameter.
2. URL with `sort=all` (or the feature sentinel).
3. URL with a non-default sort such as `name-desc`.
4. URL with status/search/date active and default sort.
5. Apply filters, clear filters, refresh, and navigate back.

Expected sort contribution is usually `0, 0, 1, 0` for cases 1–4. The exact grouping of search/status/date depends on product semantics.

## Static trace

Read, in order:

- feature constants: sentinel and `DEFAULT_*_SORT`;
- URL hook: raw state, resolved return value, setters, reset;
- component: `activeFilterCount` or badge predicate;
- request builder/query key: confirm the same filter still affects the data request.

If the hook returns `resolveSort(card, state.sort)`, the component cannot tell omitted sort from a chosen default by reading only `url.sort`. For the usual semantics, treat the canonical default as inactive. If explicit-vs-omitted matters, preserve raw state instead.

## Evidence format

Record the exact expression and line, then state:

- observable impact (“badge shows 1 on initial render”);
- root cause (“resolved default is non-sentinel”);
- literal fix (`!isSortAll(sort) && sort !== DEFAULT_SORT`);
- regression test location and scenario.

A URL-state test asserting `sort === DEFAULT_SORT` does not prove the UI badge is correct. Add a component/helper test or an equivalent observable assertion.
