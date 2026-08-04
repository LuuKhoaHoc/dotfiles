---
name: feature-merge
description: Merge overlapping MFE feature folders into one.
---

# Feature Merge — Consolidating Feature Folders Within an MFE

## When to Use

- Two feature folders serve overlapping/same domain (e.g., salary-fund-management + salary-management)
- Duplicate APIs, types, or i18n keys across features
- Multiple routes/menu items for the same business domain
- User wants to consolidate for better code organization

## Workflow

### Phase 1: Reconnaissance

1. Read both features' index.ts (public API boundary)
2. Map shared dependencies (types, APIs, hooks) - which are duplicated vs unique
3. Check i18n locale files for overlapping keys
4. Check navigation.ts + paths.ts for route/menu entries
5. Search for cross-feature imports (e.g., employees importing from one of the features)

### Phase 2: Structure

1. Create unified feature folder with sub-domain sub-directories
2. Move files preserving relative paths where possible
3. Keep API files separate if they serve different DTOs/use cases; only merge if same params + return types

### Phase 3: i18n Migration

**CRITICAL - this step is frequently missed and causes runtime bugs**

1. Merge locale keys under unified namespace in JSON files (vi + en)
2. Search ALL .tsx files for old t() calls referencing old feature keys - not just the feature itself
3. Add new keys for newly-created tabs or renamed sections
4. Run pnpm --filter @hilo/locales build to verify no broken keys

### Phase 4: Route and Navigation

1. Add new route constant in paths.ts, remove old ones
2. Update navigation.ts with single menu entry
3. Update App.tsx routes
4. Delete old page components

### Phase 5: Cross-feature Import Resolution

1. Search entire codebase for imports from old feature paths
2. Update all import paths to unified feature
3. Update feature's index.ts exports

### Phase 6: Layout Consistency (if tabs involved)

**PITFALL - tab layout jumps are a common mistake**

1. Tab list always at same vertical position - never conditionally hide/show the header
2. Move action buttons from child list views to parent header component
3. Tabs wrapper must ALWAYS be mounted to prevent layout jumps
4. Each tab's content renders inside the Tabs wrapper, not outside as a separate branch

Pattern for tab action buttons:

BAD: action buttons inside child component + conditional header in parent
GOOD: header + tab list always rendered, action buttons in header per tab via child component

### Phase 7: Cleanup

1. Delete old feature folders
2. Delete old page components
3. Run eslint to catch unused imports from removed code
4. Verify: typecheck, lint, tests, build
5. Update GitLab issue checklist with checkmarks

### Phase 8: Completeness Verification (Post-Merge Audit)

Run this after cleanup — especially when auditing a merge performed by another agent or team member — to confirm nothing was lost.

#### A. Directory Structure vs Plan

```bash
find apps/hr/src/features/{feature} -type d | sort
```

Verify every directory from the proposed structure exists. Note extras (like `stores/`, `constants/`) as acceptable unless they violate conventions.

#### B. Git-Based Old-vs-New Completeness

Enumerate every file that existed in the old features and verify it has a home:

```bash
# 1. Find a commit where old features were still intact
git log --oneline --all -- 'apps/hr/src/features/old-1/*' 'apps/hr/src/features/old-2/*' | head -5

# 2. List every file in the old features at that commit
git ls-tree -r {hash} --name-only | grep 'features/old-' | sort > /tmp/old-files.txt

# 3. List every file in the new merged feature
find apps/hr/src/features/new-feature -type f | sort > /tmp/new-files.txt

# 4. Cross-reference — every old file should map to a new one
comm -23 /tmp/old-files.txt /tmp/new-files.txt  # files in old but NOT in new → GAPS
comm -13 /tmp/old-files.txt /tmp/new-files.txt  # files in new but NOT in old → new additions
```

**Common migration outcomes per old file:**
- Same name in new path → straightforward move ✅
- Renamed file → verify content migrated ✅
- Content merged into a larger file → verify exports/functions all present ✅
- Not found in new structure → ❌ **GAP — must account for it**

#### C. index.ts Public Boundary Audit

```bash
git show {hash}:apps/hr/src/features/old-1/index.ts
git show {hash}:apps/hr/src/features/old-2/index.ts
cat apps/hr/src/features/new-feature/index.ts
```

Every export that was public from old features must be present in the new boundary (same or renamed). Missing exports break callers outside the feature.

#### D. Stale Import Scan

```bash
grep -r 'from.*old-feature-name' src/ --include='*.{ts,tsx}'
grep -r 'oldNamespace' . --include='*.json'
```

Every match must be patched to the new path before the old directories are removed.

#### E. Domain Logic Placement Check

After all files are in place, verify each belongs in its layer:

| Layer | Belongs | Doesn't Belong |
|-------|---------|---------------|
| `apis/` | HTTP calls, param types, response normalizers | React hooks, JSX, business calculations |
| `hooks/` | React Query wrappers, URL state, UI state | HTTP calls, pure calculations |
| `types/` | DTOs, param interfaces, enum/types | Functions, constants |
| `utils/` | Pure transformations, calculations, formatting | Side effects, React hooks |
| `components/` | JSX components, sub-components | API calls, type definitions |
| `stores/` (if present) | Zustand: pure set/merge/clear only | Domain logic, entity normalization |
| `constants/` | Enums, config objects, i18n key maps | Business logic |

#### F. Old Directory Removal Check

```bash
test -d apps/hr/src/features/old-1 && echo "EXISTS" || echo "REMOVED"
test -d apps/hr/src/features/old-2 && echo "EXISTS" || echo "REMOVED"
```

Both must say REMOVED. If any old directory persists, delete it.

#### G. Verification Gate

| Gate | Command | Expectation |
|------|---------|-------------|
| TypeScript | `pnpm --filter {app} typecheck` | ✅ pass |
| Tests | `pnpm --filter {app} exec vitest run src/features/{feature}/` | ✅ all pass |
| Lint | `npx eslint src/features/{feature}/` | ✅ 0 errors |
| Locale build | `pnpm --filter @hilo/locales build` | ✅ pass |

## Pitfalls

### i18n locale keys not updated everywhere

When renaming locale keys:
- Update the JSON files (vi + en)
- Search ALL .tsx files for old t() calls using regex
- Do not forget tab keys if adding new tabs
- Run pnpm --filter @hilo/locales build to verify

### Tab layout jumps when switching tabs

If using Radix UI Tabs with conditional content:
- NEVER conditionally render Tabs wrapper - keep it always mounted
- NEVER conditionally hide/show the header based on active tab
- Use a child component that returns different buttons based on activeTab prop
- Do not pass conditional JSX as props - extract into a small component

### Raw hex colors in helper components

After moving components between features, check for inline style with raw hex colors. Replace with design token constants (e.g., PAYSLIP_COLORS.muted).

### Unused imports after removing code

After removing headers/buttons from child components, run eslint to auto-fix.

### API file merge decision

Keep API files separate if they serve different DTOs or use cases. Only merge into one file if they share the exact same params and return types.

## Verification

pnpm --filter @hilo/locales build
pnpm --filter hr-dashboard typecheck
pnpm --filter hr-dashboard lint
pnpm --filter hr-dashboard exec vitest run src/features/merged/
pnpm --filter @hilo/shared typecheck
