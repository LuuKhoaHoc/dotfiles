---
name: frontend-review-verification
description: "Use when reviewing frontend MRs for state and filters."
tags: [frontend, code-review, mr-review, url-state, react-query, verification]
related_skills: [mr-review-verification, gitlab-mr-review-feedback, pr-review]
---

# Frontend Review Verification

Review frontend changes by tracing behavior through the whole data plane, not by accepting a local code shape or a passing unit test at face value. This skill is for React/MFE reviews involving URL-backed state, filter panels, active-filter badges, debounced search, pagination, and React Query refetching.

## Trigger

Use when an MR changes any of:

- list/table filters, search, sort, tabs, date ranges, or pagination;
- URL/query-param state hooks;
- filter badges or active-filter counts;
- React Query request params or query keys;
- frontend review claims such as “filter fixed”, “refetch works”, or “tests pass”.

## Review workflow

1. **Pin the review target.** Record the MR source branch and head SHA. Read changed files from that branch, never from a potentially stale local `develop` checkout.
2. **Map the data plane.** Trace the user interaction through:
   `UI control → local/controller handler → URL state → request-param builder → query key → API call → rendered result`.
3. **Separate raw state from normalized state.** Identify whether a hook exposes the URL's raw value or a canonical/resolved value. Defaults and sentinels can collapse distinct user states; do not use a normalized value to infer user intent without checking the product semantics.
4. **Verify the claim at the consumer.** A URL-state unit test may prove that a value is persisted while the component still displays the wrong badge or omits a control. Test the observable consumer behavior as well as the state helper.
5. **Check the full edge-state matrix.** For filter changes, cover initial/omitted values, explicit “all”, one active value, clearing all values, back/refresh/deep-link state, and pagination reset. For search, cover debounce and clearing. For query wiring, confirm every request input is represented in the query key.
6. **Run narrow gates on the pinned branch.** Prefer the feature's focused tests, typecheck, lint, and build. Report actual command results and distinguish a setup blocker from a code failure.
7. **Publish concrete feedback.** Every blocking finding needs file:line, observable impact, root cause, literal fix, and a test case that would prevent regression. Keep related findings in one consolidated review note when the MR workflow requires it.

## Active-filter badge rule

An active-filter count must represent user-selected filters, not merely non-empty normalized values. A common failure is:

- URL omitted or sentinel sort is normalized to a default such as `name-asc`;
- the consumer checks only `sort !== 'all'`;
- the default is counted as active, so the badge still shows `1` on initial render.

Verify at minimum:

| State | Expected count contribution |
|---|---:|
| sort omitted / initial default | 0 |
| explicit `all` sentinel | 0 |
| explicit non-default sort | 1 |
| search/status/date filter active | 1 per product-defined filter group |

If the feature's semantics treat the default sort as inactive, the predicate must account for both the sentinel and the default, for example:

```tsx
!isSortAll(sort) && sort !== DEFAULT_SORT ? 1 : 0
```

Import the feature's default from its owning constants module. Do not weaken a shared sentinel helper to solve one feature's default semantics. If the product needs to distinguish “explicitly selected default” from “omitted default”, preserve raw state or add an explicit selection flag instead of guessing from the resolved value.

## Query/refetch verification

- Locate the real `useQuery` call and its query key factory.
- Confirm every request parameter that can change data participates in the key, including status, search, sort, date type, unit, dates, page, and page size where applicable.
- Remember that React Query prefix matching can make a broader invalidation valid; do not flag it without tracing the actual key.
- Confirm the request-param builder omits empty values and maps UI sentinel values to the backend contract intentionally.
- Verify debounced search separately from filter-panel Apply: a panel Apply should not accidentally trigger stale search state or multiple URL updates that overwrite each other.

## Description and evidence hygiene

A checked box is not evidence. For UI MRs, the description should state the concrete commands, scope, and results. Raw template comments, placeholder commands such as `<workspace>`, and an empty screenshot section do not demonstrate that a UI acceptance criterion was verified. Ask the author to record the deployment/environment used for manual verification, or explicitly mark screenshots as unavailable with a reason.

## Finding format

Use this compact shape:

```markdown
### 🔴 Problem title — blast radius

**Location:** `path/to/file.tsx:line`

**Problem:** observable behavior and why it matters.

**Root cause:** one sentence connecting the code to the behavior.

**Fix:** literal code change or exact placement, plus a regression test.
```

## Verification checklist

- [ ] Correct branch and head SHA recorded
- [ ] UI → URL → params → query key → API traced
- [ ] Raw and resolved/default values distinguished
- [ ] Initial, sentinel, active, clear, refresh/back cases checked
- [ ] Tests cover the observable consumer behavior
- [ ] Focused tests/typecheck/lint/build results are real and reported honestly
- [ ] Review note has concrete file:line fixes and no vague “make it configurable” advice

## References

- `references/active-filter-badge-check.md` — worked review recipe for default-vs-sentinel filter counts and evidence capture.
