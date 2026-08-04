# Employee Documents & Certificates — BE-spec → multi-MFE integration (issue #95, MR !523)

Architecture used to integrate the BE documents API (`employee-documents-scalar-test-report.md`)
across 2 MFEs (hr-dashboard + shell). This is the reference pattern for ANY future BE sub-resource
API that must live outside the parent employee/profile payload.

## BE contract (from spec)

- `GET /hr/employees/{employeeId}/documents` → `EmployeeDocumentDto[]` (`{id, employeeId, documentType, documentName, description, attachments[{id, fileName, fileUrl, createdAt}]}`)
- `POST /hr/employees/{employeeId}/documents/attachments/upload` → multipart, field name `attachments`, multiple files per request, ≤5 MB each → `[{fileName, fileUrl}]`
- `POST /hr/employees/{employeeId}/documents` (201) → batch create `{documents: [{documentType, documentName, description, attachments[]}]}`
- `PATCH /hr/employees/{employeeId}/documents` → batch update `{documents: [{id, ..., attachments[] (NEW uploads only), attachmentIdsToDelete[]}]}`
- `DELETE /hr/employees/{employeeId}/documents` → `{documentIds: []}` (cascade deletes attachments)
- `DocumentType` = `'CERTIFICATE' | 'DEGREE' | 'OTHER'` — NOTE: uppercase, distinct from the legacy `EMPLOYEE_DOCUMENT_TYPE_VALUES` (lowercase `cv|cover_letter|...` used by the old form).
- Batch semantics: one invalid element → whole batch rolls back. FE must NOT mark rows saved individually; key off the shared response.

## Architecture decisions (why)

| Layer | Where | Why |
|---|---|---|
| Endpoints + query key | `packages/shared/src/api/endpoints.ts`, `query-keys.ts` (`HR.EMPLOYEE_DOCUMENTS`) | Centralized API contracts (repo rule: endpoints/query-keys live in shared) |
| Dumb API client | `packages/shared/src/api/employee-documents.ts` (5 functions) | 2 MFEs consume it (hr + shell); follows the `employee-dependents.ts` precedent already in shared — do NOT duplicate API clients per app when shared already hosts the sibling resource's client |
| Types + form-item model | `packages/shared/src/utils/employee-documents.ts` | `EmployeeDocumentFormItem` per spec §3: `localId, id?, documentType, documentName, description, existingAttachments[], pendingFiles[], uploadedAttachments[], attachmentIdsToDelete[], uploadStatus` |
| React Query hooks | PER-APP duplicate: `apps/hr/.../hooks/useEmployeeDocuments.ts` + `apps/shell/.../hooks/useProfileEmployeeDocuments.ts` | Cross-MFE imports are forbidden; hooks are feature-owned, so each MFE gets its own thin hooks over the shared client (same as `useEmployeeDependents` vs `useProfileDependents`) |
| UI tab | PER-APP duplicate: `employee-detail/tabs/DocumentsCertificatesTab.tsx` + `profile/components/tabs/DocumentsCertificatesTab.tsx` | Same rule: no deep-import across MFE boundaries; UI duplicated per app |
| i18n | `common.json` `employeeForm.documents.*` (en + vi) | Both MFEs already use `useTranslations('common')` for `employeeForm.*` — one shared namespace, no per-app dup |

## Key implementation details

- **Mirroring a user's hand-edit across duplicated MFE tabs** (real case, MR !523) — the user hand-refactored `apps/hr/.../DocumentsCertificatesTab.tsx` (payloads → `useMemo`, `hasChanges` gate, empty-state Add+Save) and asked: *"I just update DocumentsCertificatesTab in hr module and I need you update too in shell app"*. Workflow: `git diff` the user-edited file first → extract the STRUCTURAL delta (not the markup) → apply the same structural refactor to the sibling duplicate → verify BOTH apps (typecheck + eslint + build). The duplicated-tabs rule means any refactor to one MFE's copy must be mirrored to the other — check for uncommitted user edits with `git status` before assuming HEAD is current.
- **`hasChanges` save-gate pattern** (from that refactor) — batch-save forms should compute `createPayloads`/`updatePayloads` via `useMemo` (not inside the save handler), derive `hasChanges = createPayloads.length > 0 || updatePayloads.length > 0 || hasUnsavedUploads`, and drive BOTH `saveDisabled` and the handler guard (`if (!employeeId || !hasChanges) return`) from it. Empty state must still render Add+Save so users can start from zero documents; the Add button should gate on `isSaving` (not `saveDisabled`) so adding a first row is never blocked by `!hasChanges`.
- **Form-payload detach**: the tab was previously a `FormField name="certificates"` inside the employee/profile form (1 doc = 1 file). With a dedicated documents API, the tab became standalone (own state, own Save button) AND `certificates` was REMOVED from the shell profile update payload (`PROFILE_UPDATE_FIELDS` in `personal-information-schema.ts`) + its 2 spec tests updated (`expect(payload.certificates).toBeUndefined()`). Without this, saving the parent profile re-sends stale `certificates` and clobbers documents managed via the new API. HR employee-update DTO never carried `certificates` (only create did), so only shell needed the detach.
- **Upload-before-save flow** (per spec §5): for each row with `pendingFiles` → `uploadEmployeeDocumentAttachments` → append result to that row's `uploadedAttachments` (per-row `uploadStatus: 'uploading'|'success'|'error'`); only POST/PATCH when all uploads succeed. On batch error AFTER successful uploads, keep `uploadedAttachments` in state so retry does NOT re-upload (avoids duplicate files).
- **PATCH payload**: `attachments` contains ONLY freshly uploaded files — never resend `existingAttachments` (would duplicate records). `attachmentIdsToDelete` only old ids. Both empty = keep everything.
- **Delete**: rows with backend id → `ConfirmActionDialog` (cascade warning) → `DELETE {documentIds}`; rows without id just drop from local state. On delete failure, restore the row.
- **ApiResponse envelope**: fabricated empty responses need `meta: { timestamp: '', path: '' }` (type requires it; `{}` fails). See `uploadEmployeeDocumentAttachments` files.length===0 branch.
- **`crypto.randomUUID` guard**: use `typeof crypto !== 'undefined' && typeof crypto.randomUUID === 'function'` fallback (pattern from `packages/shared/src/location/native-bridge-contract.ts:135`) — do NOT call `crypto.randomUUID()` bare in shared utils.
- **Rebuild shared dist before consumer typecheck**: after editing `packages/shared/src`, consumers resolve `@hilo/shared` against `dist/` — `pnpm --filter @hilo/shared build` first, else LSP/tsc reports missing exports (`Property 'EMPLOYEE_DOCUMENTS' does not exist`).
- **LocalId generation**: `crypto.randomUUID()` with fallback — used as React key before backend id exists.

## Verification commands used

```bash
pnpm --filter @hilo/shared typecheck && pnpm --filter @hilo/shared build
pnpm --filter hr-dashboard typecheck && pnpm --filter hr-dashboard build
pnpm --filter shell typecheck && pnpm --filter shell build
pnpm --filter shell exec vitest run src/features/profile/hooks/useUpdateProfileMutation.spec.ts
pnpm --filter hr-dashboard exec vitest run src/features/employees/schemas/
pnpm exec eslint <changed files> && pnpm exec prettier --check <changed files>
```

## Review checkpoints for MR !523 (when it comes up)

1. **Payload correctness**: create/update payloads exclude `existingAttachments`; `attachmentIdsToDelete` only old ids; per-row state isolation (no shared file array).
2. **Batch error handling**: uploadedAttachments preserved on metadata failure (no re-upload); single-row upload error keeps other rows intact + retry per row; no per-row "saved" marking on batch failure.
3. **5 MB validation** enforced client-side (DocumentUploadZone maxFileSizeMB + explicit check).
4. **Form detach side effects**: `certificates` gone from `PROFILE_UPDATE_FIELDS`; employee-create flow still uses legacy certificates form (out of scope — confirm it still compiles/specs pass).
5. **i18n parity**: `employeeForm.documents.*` in en AND vi; `document_upload.fileTooLarge` reused for size errors.
6. **4 UI states** on the tab: Skeleton (loading), error + Retry, EmptyView, success list. Empty state must still expose Add+Save actions in edit mode (user can start from zero documents).
7. **`hasChanges` gate** (user's refactor): Save disabled until create/update payloads or pending uploads exist; Add button gates on `isSaving` only, so a first row can always be added.
8. **Query key + cache sync**: `setQueryData` from create/update response; `invalidateQueries` fallback — no stale documents after save.
9. Pre-existing spec failures are NOT regressions: `profile-mappers.spec.ts` fails on `digitalSignatureStatus` on develop too (verified via `git show develop:file` comparison — never via `git stash`).
