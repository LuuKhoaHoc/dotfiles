# Issue #184 Parallel Workers Conflict Resolution

## Problem

6 workers ran in parallel on issue #184 (CRM Authorization). All modified shared files:
- `packages/shared/src/api/endpoints.ts` (5 branches)
- `packages/shared/src/api/query-keys.ts` (5 branches)
- `packages/shared/src/constants/paths.ts` (3 branches)
- `packages/shared/src/constants/error-codes.ts` (2 branches)

Each worker created different namespace names:
- t_967096c8: `AUTHORIZATION_ROLES` (flat, no namespace)
- t_c340bbaf: `AUTHORIZATION` (wrong path `/authorization/...`)
- t_38aa0562: `CRM_AUTH` (most complete, correct path `/crm/authorization/...`)
- t_95a51ae2: `AUTHORIZATION` (duplicate of t_c340bbaf)
- t_7bc7b333: `CRM_AUTHORIZATION` (different name)

## Resolution

1. **Identified canonical branch:** t_38aa0562 had most complete `CRM_AUTH` namespace
2. **Consolidated shared layer:** Committed all changes to t_38aa0562
3. **Pushed missing branches:** t_967096c8 and t_7bc7b333 had 0 commits (uncommitted work)
4. **Unblocked review:** `hermes kanban unblock t_bf440332`
5. **Reviewer re-ran:** Found issues were resolved

## Lessons

- Always verify branches have commits before marking tasks done
- Agree on canonical namespace before dispatching parallel workers
- Use "single canonical branch" pattern for shared layer
- Feature workers should only modify their own `apps/*/src/features/` directory
