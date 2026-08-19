# Review-of-Reviews: Verifying EXISTING Review Comments

Real case: MRs !603/!604/!612 (erp-admin sale/product CKS chain, 2026-08-18).
User asked "check xem review có đúng không" — verify review comments that a
previous auto-review round had posted, before the author acts on them.

## Core workflow

1. **List ALL notes per MR** (`get_merge_request_notes`, sort asc). Only the
   LATEST review note is the "live" one — earlier notes are historical rounds
   whose claims the author may already have fixed. Treating every note as
   current double-reports fixed items.
2. **Pin each claim to a head_sha.** `get_merge_request` →
   `diff_refs.head_sha`; `git rev-parse origin/<branch>` must equal it.
   Claims verified against a different sha are stale; `git log --oneline
   <old-head>..<new-head>` names the fix commits.
3. **Verify against branch code, not the note's own file:line** — a review
   cites the version it saw. `git show origin/<branch>:<path>` /
   `git grep -n <pattern> origin/<branch> -- <dirs>`.
4. **Probe the false-positive patterns** (below) before accepting OR
   rejecting a claim.
5. **Classify every claim** ✅ confirmed (with code evidence) / ❌ false
   positive (with proof) / ⚠️ already fixed (name the commit). Report
   per-MR with note IDs so the user can decide cleanup (delete stale notes,
   keep one consolidated comment).

## False-positive patterns that actually fired

### i18n "missing keys" claim — WRONG (MR !604 note 14023)
Review claimed 8 keys missing from `common.json` ("UI sẽ hiển thị raw key"),
blocking. Verification: `git show <head_sha>:packages/locales/src/translations/en/common.json`
+ a Python JSON traversal (NOT text grep — `errors.generic` vs
`errorCodes.generic` differ only by prefix and both exist as substrings).
All 8 keys existed at the exact sha under review; head had NOT moved since MR
creation (06:42) though the review was written at 08:27. → false positive.
A wrong i18n blocker makes the author add duplicate keys.
Correct check: `def has(o,p)` walking `d[k]` per dot-segment.

### "interface missing prop" claim — WRONG (MR !603 note 14022 #13)
Review claimed `OrderItemListProps` didn't list `onDeleteItem`. Verification:
`git log -S 'onDeleteItem' origin/<branch> -- <file>` dated the prop to the
original feature commit (a90ea3a30) — present the whole time. → false
positive.

### "build/typecheck chưa xác nhận sạch" — STALE (MR !612 note 14077 tail)
Review claimed the MR's build was unverified / earlier run had dependency
errors. Verification: `list_commit_statuses` (sha + pipeline_id) shows the
repo's MR pipelines run ONLY `trivy:iac` + `sonarqube:scan`
(sonarqube `allow_failure: true`). Pipeline "success" ≠ build/typecheck
proof — but the head's pipeline WAS green, so the claim was stale. Verify
compile-relevant suspicions by grepping dead code / cross-feature imports
instead of repeating the claim.

## Re-review after author fixes

- Author pushed fix commits; re-fetch branch, verify each flagged item at the
  NEW head. Read the fix commit's diff (`git show <sha>`), never trust
  "fix: address review findings" messages — scope them item by item.
- Keep ONE consolidated comment: delete old notes, post a status table
  (✅ FIXED with evidence / 🟡 remaining), verdict "đạt điều kiện merge".

## Multi-MR dependency chains

Stacked MRs (!603→develop, !604→!603-branch, !612→!603-branch): before
re-reviewing a top MR, check `git merge-base --is-ancestor <base-head>
<top-head>`. Real case: !612 head `2c5a6b93` did NOT contain !603's fix
commits (`0cc457101` etc.) — its `OrderDetailPage` still used the old
`DigitalSignatureDossierModal` while !603 had switched to navigate. Flag
"rebase sau khi base MR merge" instead of reviewing as final.

After a file moves features (upload API `orders/` →
`digital-signature-dossier/`): `git grep -n "from '../../orders'"` on the
branch to catch stale cross-feature imports; `git grep -n "<deleted-symbol>"`
to catch dead references the MR pipeline won't (no build job).
