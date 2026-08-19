---
name: kanban-workflow
description: "Kanban task design for parallel agents on shared codebases."
version: 1.0.0
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [kanban, workflow, multi-agent, coordination, parallel]
    related_skills: [orchestrate, subagent-driven-development]
---

# Kanban Workflow Design

## When to Use

- Creating kanban tasks for multi-agent implementation work
- Structuring parallel worker tasks on a shared codebase
- Setting up Hermes projects and boards for a new repository
- Coordinating multiple workers that modify shared files

## Core Principles

### 1. One Project = One Repository

Hermes projects map to **individual repositories**, not companies or organizations.

```
❌ WRONG: Project "Hilo-Vppos" → contains erp-admin, vppos-admin, dotfiles
✅ RIGHT: Project "erp-admin" → primary: /path/to/erp-admin
          Project "vppos-admin" → primary: /path/to/vppos-admin
```

**Why:** Kanban worktrees are deterministic per project. The dispatcher creates branches under the project's primary repo. Different repos have different AGENTS.md, build commands, and conventions.

**Setup pattern:**
```bash
hermes project create erp-admin
hermes project add-folder erp-admin /path/to/erp-admin
hermes project set-primary erp-admin /path/to/erp-admin
hermes kanban boards create erp-admin
hermes project bind-board erp-admin erp-admin
```

### 2. Shared Files = Single Owner

When multiple workers run in parallel on a monorepo, they MUST NOT all modify the same shared files. This causes merge conflicts.

**Problem pattern:**
```
Worker A (Roles)     → modifies packages/shared/src/api/endpoints.ts
Worker B (Permissions) → modifies packages/shared/src/api/endpoints.ts
Worker C (Memberships) → modifies packages/shared/src/api/endpoints.ts
                         ↓
                         CONFLICT: 3 branches, same file, different namespaces
```

**Solution patterns (pick one):**

| Pattern | When to Use | Trade-off |
|---------|-------------|-----------|
| **Serial execution** | Shared files are critical path | Slower, no conflicts |
| **File-level isolation** | Each worker owns specific files | Requires upfront planning |
| **Consolidation worker** | Parallel + post-merge reconciliation | Extra merge step |
| **Single canonical branch** | One worker owns shared layer | Others only modify feature code |

**Recommended:** Use "Single canonical branch" — one worker consolidates the shared layer (endpoints, types, query keys), other workers only modify feature code in their respective `apps/*/src/features/` directories.

### 3. Task Scope = Feature Isolation

Each kanban task should be scoped to a **specific feature in a specific app**, not touching shared layers.

```
✅ GOOD: "Roles CRUD in apps/sale/src/features/authorization/"
   - Only modifies: apps/sale/src/features/authorization/**
   - Does NOT modify: packages/shared/**

❌ BAD: "Implement roles API layer"
   - Modifies: packages/shared/src/api/endpoints.ts (shared!)
   - Modifies: packages/shared/src/api/query-keys.ts (shared!)
   - Conflicts with: every other task that adds endpoints
```

**Task template:**
```
Title: #ISSUE Feature name in apps/APP/src/features/FEATURE/
Body: Implement [feature] in [app]. Files to modify:
  - apps/APP/src/features/FEATURE/apis/*.ts
  - apps/APP/src/features/FEATURE/hooks/*.ts
  - apps/APP/src/features/FEATURE/types/*.ts
  DO NOT modify packages/shared/** (canonical branch handles shared layer)
```

### 4. Dependency Links = Review Gate

Link the review task as a child of ALL implementation tasks. This ensures review runs only after all code is consolidated.

```bash
hermes kanban link t_implementation1 t_review
hermes kanban link t_implementation2 t_review
# ... repeat for all implementation tasks
```

The review task will be `blocked` until all parents complete.

### 5. Workdir = Project Root

When setting workdir for cron jobs or kanban tasks, use the **project root**, not a subdirectory.

```
❌ WRONG: /home/user/Projects/Hilo-Vppos/Documents/ERP
✅ RIGHT: /home/user/Projects/Hilo-Vppos/erp-admin
```

**Why:** The project root contains AGENTS.md, .git, and the full repo structure. Subdirectories may be docs-only or lack build configuration.

## Pitfalls

1. **Parallel workers on shared files → merge conflicts.** Always check if a task modifies `packages/shared/**` before dispatching multiple workers.

2. **Missing commits on branches.** Workers that don't commit+push their changes leave "ghost" branches. Always verify `git log develop..HEAD` shows commits before marking a task done.

3. **Duplicate type definitions.** Multiple workers defining the same types (e.g., `SCOPE_TYPES`, `ROLE_TYPES`) with different values causes runtime errors. Consolidate types in one canonical location.

4. **Namespace sprawl.** Different workers creating different namespace names for the same API (e.g., `CRM_AUTH` vs `AUTHORIZATION` vs `CRM_AUTHORIZATION`) causes confusion. Agree on canonical namespace before dispatching.

5. **Desktop UI cron scoping.** Desktop app shows cron jobs scoped to the active project, not global CLI-created jobs. To see jobs in desktop UI, create them with `--workdir` pointing to the project path.

## Verification

After parallel workers complete:
1. Check each branch has commits: `git log develop..HEAD`
2. Check shared file conflicts: `git diff develop -- packages/shared/`
3. Run review task to catch consolidation issues
4. Verify typecheck passes on consolidated branch
