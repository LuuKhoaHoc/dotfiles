---
name: session-handoff
description: Compact the current conversation into a handoff document so a fresh agent or human can continue the work. Redact secrets, avoid duplicating artifacts already saved, add suggested next skills. Use when user says "handoff", "pass to someone", "save context", or finishes a planning/triage session.
---

# Session Handoff

Compact the current conversation into a handoff document.
Save it to a temp path outside the current workspace so it is easy to find and attach later.

## Document structure

- **Summary**: context, decision made, and current state
- **Current task / blocker**: what is in progress and what's blocking progress
- **Decision map / plan references**: link to existing docs instead of duplicating them
- **Key artifacts**: by path or URL:
  - issues
  - PRDs
  - ADRs
  - plans
- **Next steps**: ordered, concrete next actions
- **Suggested skills**: skills the next session should invoke
- **Redactions**: strip API keys, passwords, tokens, PII

## Rules

- Do not duplicate content already captured in artifacts; reference them instead
- Keep the document portable — assume the next person does not share this chat history
- Focus on load-bearing context only; omit discussion noise

If the user passed an additional description of what the next session will focus on, tailor the document accordingly.
