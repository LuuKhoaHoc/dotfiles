# Post-Migration Verification Checklist

Use after a subagent, external tool (antigravity, Codex), or automated script has performed a large codebase merge, move, or refactor. This is the systematic cleanup pass — the merge itself is done, but loose ends are guaranteed.

## Phase 1: Structural Integrity

Check the resulting file/directory structure against the planned structure:

```
find . -type f | sed 's|[^/]*/|  |g' | sort
```

**Red flags:**
- Missing `stores/` directory (zustand store commonly forgotten)
- Missing spec files (`.spec.ts`) — search for them in the old locations
- Files at wrong depth (e.g. components mixed with utils)

## Phase 2: Dead Reference Scan

Search for references to old paths, old exports, and old feature names:

```
# Old import paths
grep -r 'from.*old-feature-name' src/ --include='*.{ts,tsx}'

# Old path constants
grep -r 'OLD_CONSTANT_NAME' . --include='*.{ts,tsx}'

# Old locale keys
grep -r 'feature\.oldNamespace' . --include='*.json'
grep -r 'features\.oldKey' . --include='*.{ts,tsx}'
```

**Key areas to check:**
- `packages/shared/src/constants/paths.ts` — old constants may still exist alongside new ones
- `packages/shared/src/config/navigation.ts` — old menu items silently coexist
- `packages/locales/src/translations/{vi,en}/` — old translation sections not migrated
- `apps/{mfe}/src/App.tsx` — old routes still mounted
- Cross-feature imports (e.g. `features/employees` imports from a now-deleted feature)

## Phase 3: Locale Migration

After JSON deep-merge of locale sections:

- Verify the merged section has **all** keys from both sources (use `jq` keys comparison)
- Check that component code references `features.{newNamespace}.*` not `features.{oldNamespace}.*`
- **Both** `vi/` and `en/` must be migrated together
- Add missing keys for NEW features that didn't exist before (e.g. new tabs, new actions)

## Phase 4: Verify

| Gate | Command | Expectation |
|------|---------|-------------|
| TypeScript | `pnpm --filter {app} typecheck` | ✅ pass |
| Tests | `pnpm --filter {app} exec vitest run src/features/{feature}/` | ✅ all pass |
| Lint | `npx eslint src/features/{feature}/` | ✅ 0 errors |
| Shared packages | `pnpm --filter @hilo/locales build` or `pnpm --filter @hilo/shared typecheck` | ✅ pass |

## Phase 5: Component-Level Cleanup (large files)

After structural merge, check for files that were large before the split:

```
find . -name '*.tsx' -o -name '*.ts' | xargs wc -l | sort -rn | head -10
```

**Extraction pattern for large files:**

1. Identify pure-helper functions (no hooks, no JSX, no component state)
2. Identify standalone constants (config objects, enum maps, color palettes)
3. Extract to `utils/` or `constants/` — one file per cohesive concern
4. Identify variant-specific render blocks → extract to sub-files per variant
5. Keep the component file focused on: hooks/state wiring + layout + event handlers

**Signs a function should be extracted:**
- It takes data in and returns data out (no side effects, no hooks)
- It's defined **above** the component, not inside it
- It's >20 lines of pure logic
- It would be useful in tests independently of the component

**Signs a function should stay in the component:**
- It uses hooks (`useState`, `useEffect`, `useMemo`, `useCallback`)
- It accesses component-local state via closure
- It's a JSX rendering helper that uses component-local data

## Phase 6: UI Consistency

- Tab components: all tabs should render inside the **same** `<Tabs>` wrapper (Radix-based). If some tabs are outside the `<Tabs>` component, clicking them resets layout state and causes visual jumps.
- Inline styles: prefer design-token constants over raw hex strings
- i18n keys: every new UI element (tabs, buttons, modals) must have corresponding keys in both locale files
