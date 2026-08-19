---
name: cross-mfe-parity-audit
description: "Audit two MFEs for feature drift and create sync issues."
version: 1.0.0
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [erp-admin, mfe, parity, audit, drift]
    related_skills: [gitlab-issues, hilo-erp-hrm]
---

# Cross-MFE Parity Audit

Systematically compare two MFEs in the erp-admin monorepo to find feature drift, trace root causes via git history, and create issues to sync them.

## When to use

- User reports two similar screens in different MFEs look/act differently
- QA finds inconsistent labels, actions, or layouts between HR and Employee
- After one MFE evolves (new tabs, stats, actions) and the other doesn't follow
- User says "đồng bộ", "sync", "nhất quán", "giống nhau" across MFEs

## Workflow

### Phase 1: Recon both codebases

1. **Identify the feature folders** in each MFE:
   - `apps/hr/src/features/{feature-name}/`
   - `apps/employee/src/features/{feature-name}/`
   - Check `references/hilo-erp-projects.md` for known paths

2. **Read AGENTS.md** in each feature folder — they document structure and conventions.

3. **Map the equivalent components:**
   | Aspect | HR file | Employee file |
   |--------|---------|---------------|
   | Main view/wrapper | `*ViewWrapper.tsx` | `*Overview.tsx` |
   | Table columns | `hooks/use*Columns.tsx` | `hooks/use*Columns.tsx` |
   | Row actions | `*RowActionDropdown.tsx` | inline in columns |
   | Summary/stats | `*Summary.tsx` | `*Statistics.tsx` |
   | Tabs | `types/*` (tab constants) | `constants/*-tabs.ts` |

### Phase 2: Compare dimensions

Check each dimension systematically. Use comparison tables in the issue:

| Dimension | What to check | Common drift |
|-----------|---------------|-------------|
| **Tab structure** | Number of tabs, tab labels, tab values | HR has 2 tabs, Employee has 4 |
| **Summary/stat cards** | StatCard components, API endpoints | Employee added stats, HR didn't follow |
| **Action dropdown** | Menu items per status, role gating | HR missing cancel; reject gated differently |
| **i18n labels** | Same concept, different translations | "Chỉnh công" vs "Điều chỉnh chấm công" |
| **Header elements** | Create button, filters, settings | HR create button commented out |
| **StatusBadge colors** | Status → tone mapping | `waiting` mapped to SUCCESS instead of WARNING |
| **Columns** | Column order, widths, render logic | Usually synced first (lowest effort) |

### Phase 3: Trace git history

Find WHEN and WHY the drift happened:

```bash
# Find first commits for each feature
git log --reverse --oneline -- apps/hr/src/features/{feature}/ | head -5
git log --reverse --oneline -- apps/employee/src/features/{feature}/ | head -5

# Find when a specific capability was added to one but not the other
git log --oneline -S "Statistics" -- apps/employee/src/features/{feature}/
git log --oneline -S "handled" -- apps/employee/src/features/{feature}/

# Check if there was a sync attempt
git log --oneline --grep="sync" --grep="parity" --grep="đồng bộ" -- apps/

# Blame specific drift points
git blame -L <line> <file>
```

### Phase 4: Verify against origin/develop

**ALWAYS** verify claims against `origin/develop`, not the local branch:

```bash
git fetch origin develop
git show origin/develop:<file-path> | head -20
git grep origin/develop '<pattern>'
```

Local checkout may be on a feature branch with different state.

### Phase 5: Create issues

Use `gitlab-issues` skill for issue creation. Key conventions:

- **Title:** `[MODULE] Mô tả ngắn gọn tiếng Việt`
- **Labels:** `HR` or `Employee` + `MFE::hr` or `MFE::employee` + `frontend` + `bug` or `feature` + `priority::*` + `ready-for-agent` + `status::todo`
- **Description:** Include comparison table, root cause (git commit hash + author), proposed fix
- **Assign:** Feature owner per team conventions (see `gitlab-issues` skill)
- **Blocked by:** Reference conflicting issues (e.g. #159 proposes opposite direction)

## Pitfalls

1. **Don't assume both MFEs should be identical.** HR is admin view (all employees), Employee is self-service (own requests). Labels like "của nhân viên" vs "của bạn" are intentional differences. Only sync UI patterns, not semantics.

2. **Check for conflicting open issues.** Before creating a sync issue, search for issues that propose a DIFFERENT direction for the same area (e.g. #159 proposed merging tabs into 1 DataTable, while the sync issue proposes 4 tabs). Reference the conflict in `Blocked by`.

3. **Verify BE contract before claiming missing features.** If Employee has a stat card but HR doesn't, check if BE has the equivalent endpoint for HR scope. Don't assume HR can reuse Employee's API — they have different data scope (org-level vs personal).

4. **StatusBadge color issues are common.** The `getStatusStyles` function maps status strings to colors. Different MFEs may have different StatusBadge copies. Check BOTH files when tracing color bugs.

5. **Action dropdown permission gating differs.** HR may gate reject to HR_MANAGER role while Employee shows it for all approvers. This may be intentional (BE enforcement) — verify before flagging as bug.

## Example output (from session 2026-08-17)

Issues created via this workflow:
- #189: HR sync with Employee (tabs, stats, labels, actions)
- #190: Leave days label fix (BE returns days, label said hours)
- #191: StatusBadge `waiting` color (SUCCESS → should be WARNING)
- #194: Missing cancel action in attendance adjustment list
