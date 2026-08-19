# Auto-Review Pipeline Pattern

## Overview

Automated code review workflow using cron + kanban + reviewer bot.

## Setup

### 1. Cron Job (detects MRs, creates kanban tasks)

```bash
hermes cron create \
  --name "auto-review-mr" \
  --schedule "0 9,11,14,16 * * 1-5" \
  --deliver all \
  --workdir /path/to/repo \
  --prompt 'Detect MRs needing review on GitLab. For each MR:
1. Check if kanban task already exists (skip duplicates)
2. Create kanban task: "Review MR !{iid} — {author} — {title}"
3. Assign to reviewer profile
4. Body: MR URL + summary of changes'
```

### 2. Reviewer Profile (SOUL.md additions)

```markdown
## When reviewing a kanban task (MR review)
1. Read MR diff via MCP GitLab tools
2. Check: i18n, patterns, security, breaking changes
3. Comment on GitLab MR with prefixes:
   - `nit:` — minor style issues
   - `suggestion:` — improvement ideas
   - `blocker:` — must fix before merge
   - `praise:` — good code
4. Complete kanban task when done
```

### 3. Benefits

- Review happens automatically, user only approves/rejects
- Multiple MRs reviewed in parallel
- Progress tracked on kanban board
- Review findings persist as GitLab comments
- User gets DM summary of findings

## Trade-offs

- Free/cheap models may miss subtle issues
- Need GitLab MCP with write permissions
- Reviewer needs project context (AGENTS.md, conventions)

## Verification

- Check GitLab MR for bot comments
- Verify kanban task status changes to "done"
- Confirm no duplicate tasks created
