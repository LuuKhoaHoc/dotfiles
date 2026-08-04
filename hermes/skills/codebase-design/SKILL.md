---
name: codebase-design
description: Shared vocabulary for designing deep modules — depth, seam, interface, adapter, leverage, locality. Use when the user wants to design or improve a module's interface, find deepening opportunities, decide where a seam goes, make code more testable or AI-navigable, or when another skill needs the deep-module vocabulary.
---

# Codebase Design

Design **deep modules**: a lot of behaviour behind a small interface,
placed at a clean seam, testable through that interface.

Use this vocabulary and these principles wherever code is being designed
or restructured. The aim is leverage for callers, locality for maintainers,
and testability for everyone.

## Why this vocabulary matters

Consistent language is the whole point.
Use these terms exactly — don't substitute "component," "service,"
"API," or "boundary."

| Term | Meaning |
|------|---------|
| **Module** | Anything with an interface and an implementation. Scale-agnostic: function, class, package, or tier-spanning slice. |
| **Interface** | Everything a caller must know to use the module correctly: type signature, invariants, ordering constraints, error modes, required config, performance. |
| **Implementation** | What is inside a module — its body of code. Distinct from **Adapter**: a thing can be a small adapter with a large implementation or a large adapter with a small implementation. |
| **Depth** | Leverage at the interface: the amount of behaviour a caller can exercise per unit of interface they have to learn. |
| **Seam** | A place where you can alter behaviour without editing in that place; the location at which a module's interface lives. |
| **Adapter** | A concrete thing that satisfies an interface at a seam. Describes role, not substance. |
| **Leverage** | What callers get from depth: more capability per unit of interface they learn. |
| **Locality** | What maintainers get from depth: change, bugs, knowledge, and verification concentrate in one place. |

## Deep module

Small interface + lots of implementation:

```
┌─────────────────────┐
│   Small Interface   │  ← Few methods, simple params
├─────────────────────┤
│                     │
│  Deep Implementation│  ← Complex logic hidden
│                     │
└─────────────────────┘
```

## Shallow module (avoid)

Large interface + little implementation:

```
┌─────────────────────────────────┐
│       Large Interface           │  ← Many methods, complex params
├─────────────────────────────────┤
│  Thin Implementation            │  ← Just passes through
└─────────────────────────────────┘
```

When designing an interface, ask:

- Can I reduce the number of methods?
- Can I simplify the parameters?
- Can I hide more complexity inside?

## Principles

- **Depth is a property of the interface, not the implementation.**
  A deep module can be internally composed of small, mockable, swappable parts —
  they just aren't part of the interface.
- **The deletion test.**
  Imagine deleting the module. If complexity vanishes, it was a pass-through.
  If complexity reappears across N callers, it was earning its keep.
- **The interface is the test surface.**
  Callers and tests cross the same seam. If you want to test *past* the interface,
  the module is probably the wrong shape.
- **One adapter means a hypothetical seam. Two adapters means a real one.**
  Don't introduce a seam unless something actually varies across it.

## Designing for testability

1. **Accept dependencies, don't create them.**
2. **Return results, don't produce side effects.**
3. **Small surface area.** Fewer methods = fewer tests. Fewer params = simpler setup.

## Relationships

- A **Module** has exactly one **Interface** (surface to callers and tests).
- **Depth** is a property of a **Module**, measured against its **Interface**.
- A **Seam** is where a **Module**'s **Interface** lives.
- An **Adapter** sits at a **Seam** and satisfies the **Interface**.
- **Depth** produces **Leverage** and **Locality**.

## Rejected framings

- **Depth as ratio of implementation-lines to interface-lines** — rewards padding.
- **"Interface" as only a type keyword or public methods** — too narrow.
- **"Boundary"** — overloaded with DDD's bounded context. Say **seam** or **interface**.

## When to deepen

- When callers bounce between many small modules to understand one concept
- When modules are shallow — interface nearly as complex as implementation
- When bugs hide in how callers use a module, not in the module itself
- When the seam is leaking internal details across its boundary
