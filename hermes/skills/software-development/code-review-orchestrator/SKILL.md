---
name: code-review-orchestrator
description: "Parallel subagents for MR review. Diff + conventions + web."
tags: [code-review, orchestrator, parallel, subagent, mr-review, pr-review]
related_skills: [pr-review, gitlab-mr-review, gitlab-mr-review-feedback, github-code-review, requesting-code-review]
---

# Code Review Orchestrator

Dispatch **3 parallel subagents** for MR/PR review, then synthesize into one
verified, convention-compliant, evidence-based review comment.

**Core principle:** Orchestrator verifies every subagent claim before publishing.
No blind trust.

## When to Use

- User says "review MR !NNN", "review this PR", "review this merge request"
- **For large MRs (30+ files, cross-MFE, refactor)** — small MRs use single-agent
- User wants evidence-based review (project conventions + best practices)

## Workflow

```
User → Orchestrator → dispatch 3 subagents (parallel) → verify → compose → post 1 comment
```

### 1. Parse & Scope

```python
# From user: "review MR !508"
MR_IID = 508
PROJECT_ID = "9"  # or "vppos-team/erp-admin"
BRANCH = "hotfix/bug4"

# Decide scope:
# - changes_count < 30 → single-agent (load pr-review + gitlab-mr-review)
# - changes_count >= 30 → orchestrator mode (this skill)
```

### 2. Dispatch 3 Subagents (Parallel)

```python
delegate_task(tasks=[
    {
        "goal": "MR Context & Diff Analysis",
        "context": f"""
Analyze GitLab MR !{MR_IID} on project_id={PROJECT_ID}.
Read the diff, list changed files, identify the core pattern change.
Return structured:
- MR title and description summary
- List of changed files grouped by pattern (new files, url-state changes, data-source changes, component changes, i18n)
- Key architectural decisions visible in the diff
- Any blockers (bugs, missing error handling, wrong imports)

CRITICAL: Read files from the MR branch via get_file_contents(ref='{BRANCH}').
Do NOT read from local checkout.
"""
    },
    {
        "goal": "Codebase Convention Survey",
        "context": f"""
Survey project conventions for MR !{MR_IID} on project_id={PROJECT_ID}.

Must read:
1. Root AGENTS.md — repo-wide conventions (DTO-first, i18n flatten, URL state, mutation+toast, 4 UI states)
2. packages/ui/AGENTS.md — UI component conventions
3. packages/shared/AGENTS.md — cross-MFE boundary rules
4. docs/solutions/ — any relevant learnings
5. Search for existing patterns of similar changes in apps/hr/ and apps/employee/

Return structured:
- List of relevant conventions from AGENTS.md files
- Existing patterns in codebase for the same type of change
- Any anti-patterns from AGENTS.md that the MR might violate

CRITICAL: Read files from the MR branch via get_file_contents(ref='{BRANCH}').
"""
    },
    {
        "goal": "Web Research — Best Practices",
        "context": f"""
Search the web for CURRENT best practices relevant to this MR.

Based on the MR title and changes, identify the tech stack involved
(React, TanStack Query, Tailwind, shadcn/ui, etc.) and search for:
- Latest best practices for each technology
- Common pitfalls for the patterns being changed
- Community-recommended approaches (TkDodo, React docs, TanStack docs)

Return structured per finding:
- Topic: what was searched
- Source: URL or maintainer name
- Finding: what the best practice says
- Relevance: how it applies to this MR

Search topics (adapt based on actual MR content):
"TanStack Query URL search params debounce best practice"
"React DataTable search input pattern"
"shadcn/ui DataTable search filter pattern"
"""
    },
])
```

### 3. Cross-Verify Subagent Claims

Before composing the final review, the orchestrator MUST verify:

| Claim type | Verify by |
|------------|-----------|
| Code claims from Agent A | Read the actual file from branch via `get_file_contents(ref=BRANCH, file_path=X)` |
| Convention claims from Agent B | Read the AGENTS.md directly |
| Best practice claims from Agent C | Check if source is reputable (TkDodo, TanStack docs, React docs) |
| "This file has issue X" | Always read the file + line to confirm |
| "This pattern breaks convention Y" | Read AGENTS.md + grep for similar patterns |
| False negatives | If Agent A says "all clean", spot-check 1-2 key files |

**Why this matters:** An agent once claimed "this file still uses the old path"
after reading the local `develop` copy. The branch had *already* been fixed.
Verify everything against the branch.

### 4. Compose Final Review

Format follows `pr-review` structure (for consistency):

```markdown
## 🔍 Code Review: MR !{IID} — {title}

### 📋 Project Conventions Check
- ✅ Convention A — complied
- ⚠️ Convention B — minor deviation (see Suggestion)

### 🔴 Blocking Issues
*[None, or file:line + problem + concrete fix]*

### 🟡 Suggestions
*[From Agent A analysis + Agent C best practices]*

### 💡 Best Practices (Web Researched)
- **{technology}** — {finding} (source: {url})
  → Applicable: {how it relates to MR}

### 📊 Overall Assessment
- **Risk**: Low / Medium / High
- **Consistency**: ✅ Good / ⚠️ Needs alignment
- **Recommendation**: Approve / Request Changes / Comment
```

### 5. Post ONE Consolidated Comment

Delegate to `gitlab-mr-review-feedback` for publishing discipline:

- ONE comment, not split
- No tool attribution (no "Hermes Agent reviewed")
- Concrete file:line + fix for every issue

If on GitHub, delegate to `github-code-review` for posting.

---

## Decision: Orchestrator vs Single-Agent

| Factor | Single-Agent | Orchestrator |
|--------|-------------|--------------|
| Changes < 30 files | ✅ Fast | ❌ Overkill (token waste) |
| Changes >= 30 files | ⚠️ Context overflow | ✅ Parallel focus |
| Cross-MFE changes | ⚠️ Misses patterns | ✅ Agent B surveys both MFEs |
| Simple bug fix | ✅ 1 file, 5 lines | ❌ Don't bother |
| Refactor with new patterns | ❌ No convention check | ✅ Agent B checks AGENTS.md |

---

## Anti-Patterns

| Don't | Do instead |
|-------|------------|
| Trust subagent claims blindly | Cross-verify by reading the branch file |
| Dispatch orchestrator for 5-line fixes | Use single-agent `pr-review` |
| Post review with "Agent A found..." | Synthesize as one voice |
| Let Agent C cite random blog posts | Prefer official docs + maintainer advice |
| Forget to read AGENTS.md | Agent B MUST read conventions first |
| Read local `develop` | Read `ref=<branch>` on GitLab MCP |

## Pitfalls

- **Subagent hallucination** — Agent A might claim a bug that doesn't exist.
  Always verify by reading the actual file from the branch.
- **Token cost** — 3 subagents = 3x tokens. Only use for large MRs.
- **Timeouts** — set delegate_task timeout generous (120s+) for parallel agents.
- **Agent C stale info** — web search might return 2023 articles. Prefer sources
  dated within last 12 months.
- **Orchestrator bias** — don't unconsciously favor one agent's output. If
  Agent A and Agent B disagree on a pattern, check the AGENTS.md yourself.

## References

- `pr-review` — review criteria (4 lenses, output format)
- `gitlab-mr-review` — GitLab MR mechanics (MCP tools, blast radius, i18n)
- `gitlab-mr-review-feedback` — publishing discipline (one comment, concrete fix)
- `github-code-review` — GitHub PR mechanics (gh CLI, inline comments)
- `requesting-code-review` — pre-commit verification pipeline
