# MR !527 — receivables / payment receipts API migration (finance)

**Review round:** independent deep re-review at head `a4041b8ac0f111b7f5eb643ad81e5b024d1d0a90`, base `e98978d1…`, 64 files, +4289/−1343. Worked example for the §9 patterns: search-mapped-into-ID, missing status gating, client-side summary from capped page, upload-zone payload drop, shared URL state across tabs, scope-creep path rename.

## Verdict
Request Changes. 4 🔴 (2 inherited from prior review round + 2 new) + 8 🟡.

## Confirmed prior-review findings (still valid at head)
- **Search `q` → `customerId` / `receivableId`**: `useReceivablesTableController.ts:84` `customerId: q || undefined`; `usePaymentReceiptsTableController.ts:72` `receivableId: q || undefined`; `apis/receivables.ts` has no `q`/`search` param. **Placeholder copy proves intent**: `features.receivables.searchPlaceholder` = "Search customer ID"/"Tìm mã khách hàng", `paymentReceipts.searchPlaceholder` = "Search receivable ID"/"Tìm mã công nợ". Free-text box that only matches exact ID → garbage into UUID field, empty/400.
- **Confirm/Reject not status-gated**: `useReceivablesColumns.tsx:170-198` always renders RECORD_COLLECTION/CONFIRM_COLLECTION/REJECT even for `CLOSED`; `usePaymentReceiptsColumns.tsx:181-199` always renders CONFIRM_REQUEST/REJECT even for `CONFIRMED`/`REJECTED`. `disabled` (from `isPending`) only blocks double-submit, not invalid transitions.

## New blockers
- **Summary cards from capped page**: `ReceivablesSummary.tsx:107` `useReceivablesQuery({ page: 1, pageSize: 100 })` then `buildSummaryValues` sums `outstandingAmount` over ≤100 rows → totals understated past 100 receivables; also ignores table filters (status/date) so cards disagree with the list. MR **deleted** `RECEIVABLES_SUMMARY` endpoint constant without replacement.
- **Upload proof dropped**: `ReceivableCollectionFormSection.tsx:113-124` collects `files: File[]` via `DocumentUploadZone`; `RecordReceivableCollectionPayload` has no file field; `ReceivableCollectionRecordDialog.tsx:49-57` sends JSON only → user payment proofs silently discarded.

## New 🟡 findings
- Transition target optional id: Confirm/Reject uses `getInvoiceRequestActionId` = `invoiceRequest?.id || invoiceRequestId` (`useReceivablesTableController.ts:60-63`); receivable without invoiceRequest → API call with `undefined` id. Gate on presence too.
- Summary renders on both tabs (`ReceivablesView.tsx:21`) — irrelevant aging cards + extra fetch on payment-receipts tab.
- Shared URL state across tabs: `useReceivablesUrlState` schema shared; `setTab` resets only `page` — `q` typed on tab A leaks into tab B where it maps to a different param.
- Scope-creep route rename: `FINANCE_INVOICE_REQUESTS` → `FINANCE_INVOICE_MANAGEMENT` (`/finance/invoice-requests` → `/finance/invoice-management`) while `navigation.ts:288` keeps feature path `/invoice-requests` → shell hrefs/deep links hit catch-all. Finance module `enabled: false` so nav hidden, but deep links break.
- `INVOICE_REQUESTS_SUBMIT` endpoint added (`endpoints.ts:208`) with no app consumer — dead code.
- `paymentDate` sent via `toIsoDateTime(formatDateValue(date), '00:00')` → `2026-08-02T17:00:00Z` for 03/08 (UTC+7). Fine for HR datetime convention, risky if BE reads date-only.
- `amount` prefill raw from `outstandingAmount`; old mock stripped non-digits (`remainingAmount.replace(/\D/g,'')`) because mock data was formatted — verify BE returns plain decimal.
- DTO `PaymentReceiptDto.receivableID` (capital ID) inconsistent with `receivableId` everywhere else.

## Verified clean
- i18n: all ~200+ `t()` keys in feature present in en+vi (script: `scripts/verify_i18n_keys.py`); old `debtReconciliation` keys removed with no dangling refs.
- 4 UI states present (table + detail dialogs), mutation+toast, dumb api layer (no try/catch), double-submit guarded (`disabled`+`loading` from `isPending`), endpoints.test.ts updated to `/crm/finance/*`.
- debt-reconciliation feature fully removed (mocks, hooks, pages, constants) — zero `debt-reconciliation`/`debtReconciliation` refs left.

## Diagnostic recipe that worked
1. `git fetch origin <branch> develop` in `~/Projects/Hilo-Vppos/erp-admin-review`; verify `git rev-parse origin/<branch>` == MR head_sha.
2. Read controllers → columns → query hook → apis in one pass (the whole wiring chain).
3. `git diff <base> <head> -- packages/shared/...` for endpoint/path/nav/type changes; then `git grep` branch for consumers of renamed/removed constants.
4. i18n: run `scripts/verify_i18n_keys.py` (regex-extract all `t()` keys from feature files → traverse en+vi JSON). Both directions: keys referenced must exist; keys added must be referenced.
5. Compare new code against the OLD mock implementation (`git show <base>:<old-path>`) — the mock's search semantics, amount prefill, and summary source reveal intended behavior vs regressions.

## Round 2 (04/08) — Scalar correction + full blocker resolution

Fix commit `74d5dbde` (`refactor(finance): update invoice management path and improve receivables components`) resolved ALL 4 blockers + 5 suggestions at head `99e878fe`:
- Search: dropped entirely (both tables, controllers, `q`/`useDebouncedSearch`/`customerId: q` removed) — per round-1 advice based on a STALE contract.
- Status gating: RECORD_COLLECTION only `OPEN`; Confirm/Reject only `OPEN && hasInvoiceRequestId`; payment receipts only `PENDING_CONFIRM`; handlers guard `if (!invoiceRequestId) return`.
- Upload proof: `DocumentUploadZone` + `files` removed from the form.
- Summary: `useReceivablesSummaryQuery` fetches ALL pages via `meta.pagination.totalPages` (pageSize 100 = BE max), binds `fromDate/status/toDate`; mutations invalidate `RECEIVABLE_QUERY_KEYS.all`.
- Also fixed: summary only on receivables tab; `setTab` resets filters; path revert `FINANCE_INVOICE_REQUESTS`; `receivableID` → `receivableId`; `paymentDate` date-only. i18n verify: 74 keys clean en+vi (script exit 0).

### Scalar docs vs stale contract — the correction

LIVE Scalar docs for `GET /crm/finance/receivables` + `payment-receipts`: `page`, `pageSize` (max 100), `sort`, `order` (asc/desc), `search`, `searchFields`, `customerId`/`orderId` (receivables) or `receivableId`/`confirmedBy` (payment-receipts). **No `fromDate`/`toDate`/`status`.** The uploaded `finance.md` (2026-07-21, issue #112) predates these — never treat it as the current contract.
- Round-1 "bỏ search" was wrong: BE DOES support `search`/`searchFields` — the fix commit removed a supported feature. Correct wiring: `search: q` (never `customerId: q`), optional `searchFields: 'code,customerName'`.
- MR sends `fromDate`/`toDate`/`status` for receivables — NOT in the live contract → BE ignores → DateRangePicker + summary filter = silent no-op. Fix: drop the filter UI + params, or wait for BE to add them.
- Correction flow used: updated the round-1 approve note (`update_merge_request_note`) to retract the wrong "bỏ search" claim, then posted 2 new findings as fresh resolvable threads (`create_merge_request_thread`, one per finding).

### Attachment download recipe (issue #112 `finance.md`)

MCP `download_attachment` errored (invalid local_path / EISDIR). Working path — curl the upload URL with the API token (secret+filename come from the issue description's `[/uploads/{secret}/{filename}]` link):

```bash
curl -sS -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.vppos.vn/api/v4/projects/vppos-team%2Ferp-admin/uploads/{secret}/{filename}" \
  -o /tmp/api.md
```

## Round 3-4 (04/08) — search restored + dead filters removed; merged

Fix commit `a479dda0` (`refactor(finance): replace date filters with search functionality`) at head `7e4500f` resolved BOTH new threads:
- **Search restored, correctly wired**: `apis/receivables.ts` sends `search` + `searchFields` for both endpoints; both tables re-added the search box (`useDebouncedSearch` → `search: q`); placeholders updated to match real scope ("Tìm mã công nợ và đơn hàng" / "Tìm mã yêu cầu thu và mã công nợ", en+vi). This is the correct final shape: `search: q`, never `customerId: q`.
- **Ghost params removed**: `fromDate`/`status`/`toDate` dropped from `receivableUrlSchema`; `ReceivablesFiltersDialog.tsx` + `useReceivablesFiltersPanel.tsx` (137 lines) + header Filter button deleted; summary query is now param-less (global totals — consistent with the unfiltered list).
- **Nice pattern — stale URL param cleanup**: `STALE_RECEIVABLE_FILTER_PARAMS = ['fromDate','status','toDate']`; an effect strips them from `window.location.search` (`setSearchParams`, `replace: true`) so deep links/bookmarks from the old filter era don't inject dead state.
- Dead keys after the removal (nitpick-level, 🟢): `constants/receivables.ts:155-156` `FROM_DATE`/`TO_DATE` + `features.receivables.filtersPanel.*` + `actions.filter` in locale en/vi have 0 consumers.

### Finale executed (what "approve + merge" actually took)
1. Resolved the 2 discussion threads (`resolve_merge_request_thread` with the discussion ids from the create responses), posted one confirmation thread (verdict + remaining nitpick).
2. POST `approve` → **401** twice; curl with `GITLAB_TOKEN` → also 401. `GET /user` + `GET members` + `GET approvals` all fine → MR had been **already approved** (`approved: true`, `approved_by: [luukhoahoc]` since 02:49, `approvals_left: 0`). Lesson: GET approvals state first; approve-401 = already approved / can't approve, not a token failure.
3. `list_merge_request_pipelines` → head-sha pipeline `13651` = success.
4. `merge_merge_request(should_remove_source_branch: true)` → `state: merged`, `merge_commit_sha 572bca76`.
5. Verify: `git fetch origin develop` → tip = `572bca76 Merge branch 'feature/connect-receivables-api' into 'develop'`; `feature/connect-receivables-api` still listed on remote (deleted async, not an error).
