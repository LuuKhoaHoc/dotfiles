---
name: issue-to-tickets
description: Turn a plan or requirement into individually assignable tickets or issues with acceptance criteria and blocking relationships. Use when user says "break into issues", "tạo task", "lập task list", "assign work", or needs shippable work packages from a PRD/spec.
---

# Issue to Tickets

Break a plan, PRD, or requirement into independently assignable tickets.

## When to Use

- PM/BA provided a feature description or PRD
- You reviewed code/requirements and extracted actionable tickets
- The team needs a work breakdown for parallel development

## Rules

- Each ticket should cover **one slice** of end-to-end verifiable behavior
- Prefer vertical slices over horizontal layers
- Each ticket must have:
  - Title
  - One-line description
  - Acceptance criteria
  - Blocked by (if any)
  - Suggested assignee role (FE / BE / QA / PO)

### Ticket format

```
## <Ticket-TYPE>-<slug>

**Type:** issue
**Priority:** P0 | P1 | P2
**Role:** FE | BE | QA | PO
**Blocked by:** <ticket-id-or-none>

### Description
One or two sentences describing the slice from the product perspective.

### Acceptance criteria
- [ ] <verifiable outcome>
- [ ] <verifiable outcome>

### Verification
<command / steps / ticket link used to verify>
```

### Breakdown principles

- Each ticket should be deployable/verifiable on its own where possible
- Maximize parallelism by minimizing cross-ticket runtime dependencies
- Mark blockers honestly; if two tickets are independent, both list "None — can start immediately"

### Process

1. **Analyze codebase first** — Before writing any issue description, search the codebase for:
   - Existing patterns/files related to the feature (find, search_files)
   - Existing dialogs, hooks, types, constants that follow the same pattern
   - Which MFEs are affected (HR, Employee, Shell, etc.)
   - Reference files with exact paths in the description
2. Read the source requirement/PRD/ticket.
3. Derive end-to-end slices that map cleanly to team roles.
4. List acceptance criteria for each slice.
5. Present the breakdown, ask for calibration, then prepare the issues.

### Codebase Analysis Checklist

Before creating an issue, gather:
- **Existing pattern reference**: "Mirror pattern từ `<existing-file>`" (e.g. ApplyWorkScheduleDialog)
- **Affected MFEs**: List all MFEs that need changes
- **File paths**: Exact paths of files to create/modify
- **Types/constants to extend**: Which existing types need new fields
- **API endpoints**: Existing or new API contracts

This ensures descriptions are actionable with exact file references, not vague requirements.

### Assignee Separation Rule

When user says "thêm item" or "bổ sung" to an existing issue:
- CHECK the current issue's assignee first
- If the new item belongs to a DIFFERENT person → create a SEPARATE issue
- If same person → add as checklist item in the existing issue
- Never mix work items for different assignees in one issue

Stay close to the QA/team workflow used by this project.
Do not over-interview; move when sufficient info exists.
