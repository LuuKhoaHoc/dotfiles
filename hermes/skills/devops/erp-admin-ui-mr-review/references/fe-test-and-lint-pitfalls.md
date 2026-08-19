# FE test & lint pitfalls (erp-admin) — verified 2026-08-14 (issue #182 ship)

## Testing axios interceptors that touch the zustand persist auth store

The CRM-403-004 interceptor in `packages/shared/src/api/axios.ts` calls
`useAuthStore.getState().setCrmContext(null)` → zustand `persist` writes to localStorage.

**Trap:** zustand's `createJSONStorage(() => localStorage)` resolves the `localStorage`
global at MODULE IMPORT time (when `auth/store.ts` is first evaluated), not at call time.
Mocking `window.localStorage` inside `beforeEach` is TOO LATE — the storage wrapper was
already created. In the jsdom vitest env the global getter returns `undefined` (Node 26
experimental localStorage, no `--localstorage-file`), so `setItem` throws
`Cannot read properties of undefined (reading 'setItem')` inside the interceptor — which
silently skips every line AFTER the store call (e.g. the `window.dispatchEvent` of the
context-required event), producing baffling "event never dispatched" test failures.

**Fix — hoisted mock before imports:**

```ts
// MUST be hoisted: zustand persist resolves `localStorage` at module import time,
// so it has to exist before any import below runs.
const { localStorageMock } = vi.hoisted(() => {
  const storage = new Map<string, string>();
  const localStorageMock = {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => { storage.set(key, value); },
    removeItem: (key: string) => { storage.delete(key); },
    clear: () => storage.clear(),
  };
  Object.defineProperty(globalThis, 'localStorage', { writable: true, configurable: true, value: localStorageMock });
  return { localStorageMock };
});
import { apiClient, ... } from './axios';
```

Also re-point `window.localStorage` in `beforeEach` (avoids unused-var lint and keeps
window/global consistent). `vi.hoisted` executes before ALL imports, so the store module
sees a working storage.

## Testing the interceptor flow itself (queue / replay / loop breaker)

Recipe that worked (`packages/shared/src/api/axios.crm-context.test.ts`):

- Drive the REAL singleton `apiClient` with a custom adapter: `apiClient.defaults.adapter = async (config) => { ... }` (save + restore `originalAdapter` in afterEach, and drain the queue with `rejectCrmContextQueue()`).
- First call throws `new AxiosError('Request failed with status code 403', 'ERR_BAD_REQUEST', config as never, undefined, { status: 403, statusText: 'Forbidden', data: { success: false, error: { code: 'CRM-403-004', ... } }, headers: {}, config } as never)` — the interceptor reads `error.response.data.error.code` and `error.config.url`.
- Replay is a SECOND adapter call (not third): `resolveCrmContextQueue()` → `retryPromise.then(() => apiClient(originalRequest))` → adapter runs again → return a normal response. Counting: 1 fail + 1 replay = 2 calls total for a single request.
- Concurrent batch: 2 requests → adapter calls 1,2 fail (queue grows, ONE event dispatched), resolve → calls 3,4 succeed.
- Loop breaker: adapter always fails → after resolve, replay fails again but `_crmRetry` is already set → rejects without re-queueing; event fired exactly once.
- Test file needs `// @vitest-environment jsdom` at top (window event). Put it in a SEPARATE file from the old axios tests — adding jsdom to the shared file breaks its `isOnGuestRoute` SSR test which asserts `window` is undefined.

## eslint-plugin-react-hooks v7: `react-hooks/set-state-in-effect` (new default, pre-existing code trips it)

- Trigger: `setState(...)` synchronously inside a `useEffect` body (e.g. closing a portaled dropdown when crossing a breakpoint). Hits OLD code the moment the file is staged — `lint-staged` runs eslint on every staged file, so committing a feature that touches such a file fails the commit.
- **Disable placement trap:** `// eslint-disable-next-line` must sit on the line of the `setState` CALL inside the effect body, NOT on the `useEffect(` line — the rule reports the setState line, and a misplaced directive yields `Unused eslint-disable directive` (warning) while the error stays.
- Pattern that works (and passed review as honest, scoped suppression):
  ```ts
  useEffect(() => {
    if (!isDesktop) {
      // eslint-disable-next-line react-hooks/set-state-in-effect -- pre-existing pattern, out of scope for #182
      setDropdownOpen(false);
    }
  }, [isDesktop]);
  ```
- Don't refactor pre-existing behavior to satisfy the rule inside a feature MR; suppress with a reason and leave a follow-up.

## `vi.importActual<typeof import('@hilo/shared')>` trips `@typescript-eslint/consistent-type-imports`

The inline `import()` type annotation is forbidden (rule has NO auto-fixer because it must
create a new import). Fix:

```ts
import type * as SharedModule from '@hilo/shared';
...
const actual = await vi.importActual<typeof SharedModule>('@hilo/shared');
```

## lint-staged commit abort — index survives, just fix and recommit

When `pre-commit` lint-staged finds unfixable eslint errors: `git commit` exits 1, the
commit is aborted, and lint-staged REVERTS its own --fix formatting. The index keeps
everything staged. Do NOT `git add` everything again — fix the reported errors, then
`git commit` the same message. Don't be fooled by "N files changed" appearing in the
output (it's lint-staged's backup/restore chatter, not a successful commit); confirm with
`git log --oneline develop..HEAD`.

## Proving a test failure is pre-existing (not caused by the diff)

`git stash push -u -m <note>` → run the failing tests → `git stash pop`. Fails identically
on the clean base = pre-existing; report it in the MR notes as pre-existing (name the
verified files) instead of blocking. `-u` is required — untracked new files (fresh specs,
new feature dirs) must leave the tree too. After pop, rebuild workspace dist before
re-trusting test runs (see SKILL.md Test traps: stale-dist trap).
