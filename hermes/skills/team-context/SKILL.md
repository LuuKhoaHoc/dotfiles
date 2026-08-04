---
name: team-context
description: Mirror the project's domain docs and execution conventions into load-bearing session context so every agent reachable from this workspace uses the same glossary and rules. Use when user says "set up workspace context", "sync team semantics", "update ADR", "update product glossary", or after onboarding new language/domain changes.
---

# Team Context

Mirror the project's external domain context into Hermes agent context.

This skill does not duplicate artifacts already saved elsewhere.
It references existing docs and gives the agent lightweight conventions for using them consistently.

## Project References

- `CONTEXT.md` or `docs/agents/domain.md` — project glossary
- `docs/adr/` — architectural decision records
- `docs/plans/` — approved implementation plans
- `docs/agents/issue-tracker.md` — where issues live
- `docs/agents/triage-labels.md` — canonical label vocabulary

## Usage Rules

- Read these docs when entering a story or task, don't memorize them
- When naming behavior, use the glossary term; when the user uses a conflicting term, surface the conflict
- When revisiting an older plan, check whether recent ADRs invalidate any assumption in that plan
- When creating issues or answering PM/BA questions, use domain terms from these docs, not internal module names

## When to Update

- After a new ADR is merged
- After a glossary term is resolved in a `/domain-modeling` session
- When onboarding onto a new module, read the matching CONTEXT/ADR bundle before editing

## Do Not

- Invent new terms freely; propose them through `/domain-modeling` style discussion and record them before using them as authoritative
- Use this skill to generate novel content; it is a routing / referencing wrapper, not content creation
