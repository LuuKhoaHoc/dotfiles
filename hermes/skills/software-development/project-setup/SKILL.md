---
name: project-setup
description: "Initialize new personal/side projects: naming, architecture docs, tech stack decisions, documentation structure. For greenfield projects, not existing codebases."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [project-setup, initialization, architecture, tech-stack, documentation]
    related_skills: [plan, codebase-design]
---

# Project Setup

Use this skill when starting a new personal/side project from scratch.

## Workflow

1. **Understand requirements** - What problem does this solve? Who is the user?
2. **Brainstorm names** - Creative options, user picks one
3. **Research tech stack** - Search web for latest versions of candidate tools
4. **Present options** - Clear comparison tables, user decides
5. **Document decisions** - Save to docs/ folder alongside code
6. **Create folder structure** - Minimal, no over-engineering
7. **Start coding** - Only after docs are ready

## Tech Stack Decision Framework

Research before deciding. Search GitHub releases, check latest versions.

For each candidate tool, compare:
- Stars/community size
- Maturity (battle-tested vs new)
- Free tier (for MVP/demo)
- Integration with existing stack

Present as comparison tables. User picks.

## Documentation Structure

Store docs in project folder, not separate location:

```
project/
├── apps/
│   ├── web/
│   └── api/
├── docs/
│   ├── architecture.md    # Tech stack, structure, scope
│   ├── requirements.md    # MVP scope, user roles, phases
│   └── database.md        # Schema, RLS, indexes
└── README.md
```

### architecture.md should include:
- Target users/company context
- Tech stack with versions
- Project structure
- MVP scope (phased)
- Pricing ideas
- Demo strategy

## Folder Structure Principles

- Accessible from multiple OS (Linux + Windows)
- Clear separation: apps/, docs/, supabase/ or db/
- No over-engineering (MFE only if 10+ modules)
- Reserved folders for future needs (apps/api/)

## Communication Style

- Vietnamese for conversation
- English for code/technical terms
- Friendly but concise
- Research-backed decisions (search web, don't guess)

## Pitfalls

- Don't over-plan before coding. Docs = sufficient detail, not exhaustive.
- Don't add MFE unless actually needed (multiple teams, 10+ modules)
- Don't choose new/unproven tools without clear rollback plan
- Don't skip docs "to save time" - they're the source of truth

## Example Tech Stack Research

```bash
# Check latest versions
browser_navigate: https://github.com/vercel/next.js/releases
browser_navigate: https://github.com/supabase/supabase/releases

# Compare tools
Present comparison table with: stars, maturity, features, risk
User picks → document in architecture.md
```
