---
name: refactor-safe
description: (no description)
disable-model-invocation: true
---

Refactor workflow:
- Preserve public behavior unless explicitly asked.
- Do not rename public APIs without listing call sites first.
- Use grep/search before changing symbols.
- Keep commits/review chunks small.
- Run typecheck and relevant tests after changes.
