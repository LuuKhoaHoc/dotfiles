# BE Spec → GitLab Issue Delivery Reference

Reusable checklist for converting backend API documents into verified FE issues.

## 1. Inspect the actual checkout

For `vppos-team/erp-admin`, use the code checkout at `~/Projects/Hilo-Vppos/erp-admin`, not the docs directory under `Documents/ERP`. Search at least:

- shared endpoint constants
- feature API functions
- request/response DTOs
- mutation/query hooks
- components that trigger the flow
- nearby `AGENTS.md` and `docs/solutions/`

When a semantic index is unavailable, literal `search_files` plus targeted `read_file` is an acceptable fallback. Capture concrete current-vs-spec gaps in the issue.

## 1b. Classify the FE gap — greenfield vs gap-fill vs migration

Before drafting, determine which FE layer is missing. Grep the feature folder for the API function name, the mutation hook, and UI callers:

- **API function exists, hook + UI missing** → **gap-fill issue**: state clearly in the issue body ("API function `X` đã có, cần hook + UI + restore flow") so the dev does not rewrite the HTTP layer. Worked example (2026-08, issue #130): `deleteEmployee(id)` already existed in `apps/hr/src/features/employees/apis/employee.ts` but nothing imported it — no mutation hook, no UI action, no restore endpoint wrapper. Issue was scoped as complete-the-flow, not build-from-zero.
- **Nothing exists** → greenfield: include the API layer in scope.
- **Callers exist but use an old contract** → migration: document old-vs-new payload/identifier mapping (see Versioned API migration section).

Also verify **who the spec owner is** before drafting: HR employee-scoped specs (freeze/unfreeze, delete/restore) route to Cường (id 10); HR attendance-sheet-scoped specs (period lock/unlock) route to Quý (id 31). Issue descriptions are written in Vietnamese following the `## What to build` format (English only for code/identifiers).

## 2. Upload reference files

Preferred: `mcp__gitlab__upload_markdown(project_id, file_path)`.

If the MCP upload client is unavailable, use the GitLab REST endpoint:

```bash
TOKEN=$(python3 -c "import yaml; c=yaml.safe_load(open('$HOME/.config/glab-cli/config.yml')); print(c['hosts']['gitlab.vppos.vn']['token'])")
curl -sS -H "PRIVATE-TOKEN: $TOKEN" \
  -F "file=@/absolute/path/to/spec.md" \
  "https://gitlab.vppos.vn/api/v4/projects/9/uploads"
```

Never print the token. Parse the JSON response and use its `markdown` field in the issue description. Verify that the returned path/hash is non-empty before creating the issue.

## 3. Draft each issue as a vertical slice

Required content:

- user-facing end-to-end outcome
- exact request paths and payloads
- current FE gap and migration notes
- permission/auth constraints relevant to FE
- acceptance criteria covering success, error, loading, empty, and edge/business-result states
- explicit out-of-scope boundaries
- blockers (`None` when no dependency exists)
- uploaded reference links
- focused verification commands/manual smoke steps

Important contract traps to preserve:

- composite domain IDs are not interchangeable with internal persistence UUIDs
- idempotent HTTP 200 is still success and must not create duplicate local audit entries
- union business results such as `blocked_by_issues` are not transport errors
- identity context owned by BE must not be redundantly sent by FE
- after a mutation, refresh only the target entity when the contract is target-scoped; do not invent broad client-side updates

## 4. Duplicate and ownership checks

Search issue tracker with both English and Vietnamese terms and inspect open results. Reuse an existing open issue only when scope and ownership match. Keep separate issues for separate assignees or independently verifiable features.

## 5. Post-create verification

Fetch every created issue and verify:

- correct IID/title and open state
- expected assignee ID/name
- intended labels
- complete description, including uploaded reference link
- no accidental blocker dependency

For sibling issues with the same parent context, create a `relates_to` link only after both exist, then verify the link response. Report created IIDs and URLs in the final response.
