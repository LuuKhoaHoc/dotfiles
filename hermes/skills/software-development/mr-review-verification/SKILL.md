---
name: mr-review-verification
description: "Use when verifying MR claims: i18n, query keys, grep."
related_skills: [gitlab-mr-review-feedback, pr-review]
---

# MR Review — Technical Verification

Verification techniques for reviewing teammate MRs, learned from real reviews
(MR !587 apps-dashboard UI sync, MR !582 HR attendance email flow). These are
the checks that catch real bugs BEFORE posting — and the traps that produce
false-positive 🔴s.

## 1. i18n Consistency Check (UI-sync MRs)

When an MR synchronizes UI state (tabs/filters/badges/status labels), the same
concept must read the SAME way everywhere it renders — in BOTH languages. The
mismatch hides in namespace split, not just in the texts.

Real case MR !587: tab filter used `common.filter.disabled` ("Đã tạm dừng" /
Paused) while the module badge used `appsDashboard.module.disabled`
("Chưa kích hoạt" / Inactive) — two different terms for the same
`enabled: false`. The MR made the tab actually show cards, exposing a mismatch
that was invisible while the tab was empty. The user's question "đồng bộ
content i18n chưa" pointed at exactly this; answering "they share the same
data source" missed the point.

Checklist:
1. Find every label rendering the concept (tab, badge, dialog title, tooltip);
   note which i18n namespace + key each uses (shared `common.*` vs feature
   namespace `appsDashboard.*`, `hr.*`, ...).
2. Compare vi AND en texts — same meaning required, not just same key name.
3. Blast radius: grep who else uses the shared `common.*` keys before
   suggesting a text change. If only the MR's own screen uses them, the
   cleaner fix is switching the component to the feature-namespace keys (one
   source of truth with the badge), NOT editing `common.json` — shared keys
   carry generic semantics and another screen may legitimately need "Paused".
4. In the review comment, state both forbidden directions ("đừng đổi
   common.json", "đừng đổi badge theo tab") with the reason, plus literal
   before/after code.
5. Keys added to `errorCodes.*` but not mapped in a feature's feedback util
   are NOT dead — they are usually resolved via the generic path
   (`resolveApiErrorMessage` / `resolveToastErrorDescription` look up
   `errorCodes.<code>`). Verify that path before flagging unused i18n keys.

## 2. Query-Key Invalidation Verification

For mutations that invalidate a query after success:
- Find the REAL `useQuery` consuming the key; confirm the id/params passed to
  `invalidateQueries` match what the query actually uses. Real case MR !582:
  hook invalidated `TIMESHEETS.DETAIL(record.id)`; the detail rows query was
  `useAttendanceTimesheetDetailRows(record.id, ...)` — matched. If the hook
  used `attendanceSheetId` (`org-1:2026:8:unit-1`) instead of `record.id`, the
  invalidation would silently no-op.
- React Query invalidates by PREFIX: a key without params still matches a
  same-prefix query with params — don't flag that as a mismatch.
- Verify "kept old flow" claims: grep that the old API/hook is still called
  somewhere before accepting a description that says it was preserved, and
  before claiming dead code.

## 3. Grep vs Tree Arbitration

When grep output contradicts the diff, read the file directly
(`git show <ref>:<path>`) to arbitrate BEFORE posting anything. `git grep`
patterns with `\b`/word boundaries can silently match/miss in ways that look
like a real bug. Real case MR !582: grep claimed the new hook imported the
OLD API function (`sendAttendanceConfirmationEmail`); `git show
FETCH_HEAD:<file>` proved it imported the new one
(`sendAttendanceSheetConfirmationEmail`). Posting that as 🔴 would have been a
false accusation — and after review comments are public, retractions erode
trust. Rule: ambiguous grep = read the file, never assume.

## 4. Unclear MR Number → Probe the API, Don't Ask

When the user gives an MR/issue number that seems implausible (e.g. "5802" for
a project whose MRs are in the 500s), probe directly: `get_merge_request`
returns 404 cheaply. Try the plausible variant once, then let the user correct
— asking first wastes a round-trip.

## Pitfalls

| Don't | Do |
|---|---|
| Flag i18n mismatch by texts alone | Check namespace split first (common vs feature) |
| Suggest editing shared `common.json` texts | Prefer feature-namespace keys; verify who else uses the shared key |
| Trust a grep hit for a 🔴 claim | `git show <ref>:<path>` the file; grep `\b` patterns are unreliable |
| Assume invalidation works | Trace the real useQuery + its id/params; remember prefix matching |
| Assume added error-code keys are unused | Check the generic `errorCodes.<code>` resolution path |
