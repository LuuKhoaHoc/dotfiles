---
name: kanban-branch-naming
description: "Branch naming conventions for Hermes kanban tasks."
version: 1.0.0
author: hermes-agent
license: MIT
metadata:
  hermes:
    tags: [kanban, git, branch, conventions]
    related_skills: [kanban, github-pr-workflow]
---

# Kanban Branch Naming

## When to Use
Use when creating kanban tasks that need worktrees (implementation tasks).
Do NOT use for review tasks (they use scratch workspace, no branch).

## Branch Convention

### Implementation tasks (cần worktree + branch)
```
feat/{issue}-{short}     → feat/184-roles-crud
fix/{issue}-{short}      → fix/192-topbar-overlap
```

### Review tasks (KHÔNG cần branch)
```
workspace: scratch (không dùng worktree)
```

## Cách dùng

```bash
# Implementation — CẦN branch
hermes kanban create "#184 Roles CRUD" \
  --branch feat/184-roles-crud \
  --assignee implementer \
  --project erp-admin

# Review — KHÔNG cần branch
hermes kanban create "Review MR !604" \
  --workspace scratch \
  --assignee reviewer \
  --project erp-admin
```

## Quy tắc

1. Implementation: luôn `--branch` với format `feat/{issue}-{short}`
2. Review: dùng `--workspace scratch`, KHÔNG `--branch`
3. Short description: lowercase, hyphen-separated, max 30 chars
