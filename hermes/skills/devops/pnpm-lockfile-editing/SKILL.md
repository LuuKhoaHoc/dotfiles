---
name: pnpm-lockfile-editing
description: "Use when pnpm rewrites lockfiles or deps need hand-editing."
---

# pnpm Lockfile Editing

Use when adding/removing a dependency in a pnpm monorepo, or when `pnpm add`/`install` rewrites the lockfile far beyond your change.

## Pitfall: lockfile reformat noise from pnpm version mismatch

`pnpm add`/`install` may **re-serialize the whole lockfile** (~thousands of lines: `resolution:` blocks collapse from multi-line to inline) when the pnpm version actually running differs from the one that wrote the lockfile. Real case (erp-admin 2026-08-10): repo pins `pnpm@11.1.3` (packageManager + AGENTS.md) but `pnpm` on PATH resolved through **mise to 11.21.0** → every `pnpm add` rewrote 7256 lines.

Check BEFORE touching deps:
1. `pnpm --version` — confirm the version actually in play (mise/corepack can override).
2. `git diff --stat pnpm-lock.yaml` after any pnpm command — if it shows mass reformat (thousands of lines, no real change), do NOT commit it into a small MR.

## Rules

- **Never commit a whole-lockfile reformat inside a feature/bug MR** — 5000+ line noise, merge conflicts with every other MR touching package.json.
- Hand-edit the lockfile in the repo's existing format instead, then verify (below). If `pnpm install --frozen-lockfile` accepts it, it's valid regardless of style.
- If the situation is already tangled (multiple failed attempts, half-applied patches): **`git reset` your commits and redo cleanly** — user explicitly prefers this over patching around mistakes ("chỉ cần reset HEAD~2 là xong").

## Hand-editing a dep into pnpm-lock.yaml (3 blocks)

For dep `pkg@X.Y.Z` with peer `peer@V` (e.g. `embla-carousel-wheel-gestures@8.1.0(embla-carousel@8.6.0)`):

1. **Importers** (`importers.<workspace>.dependencies`): `specifier: ^X.Y.Z` + `version: X.Y.Z(peer@V)` — quote key if it starts with `@`/special chars, matching neighboring entries.
2. **Packages entry** (`pkg@X.Y.Z:`): `resolution: {integrity: ...}` + `peerDependencies:` with resolved version. Integrity from `curl -s https://registry.npmjs.org/<pkg>/<ver> | jq -r .dist.integrity`.
3. **Snapshot entry** (`pkg@X.Y.Z(peer@V):`): `dependencies:` — **MUST include ALL transitive deps the package imports at runtime** (copy from the package's own package.json dependencies, resolved). Skipping a transitive dep (e.g. `wheel-gestures` for the embla plugin) makes `--frozen-lockfile` pass but the package silently vanishes from node_modules → runtime crash.

Verify: `pnpm install --frozen-lockfile` (pass = lockfile consistent; it never writes). Then `git diff --stat pnpm-lock.yaml` must show only your few lines.

## Pitfall: unused dependency left in package.json

If code stops using a dep (e.g. you replaced a plugin with a hand-rolled handler), remove it from package.json + all 3 lockfile blocks immediately — a leftover unused dep gets flagged in review. Don't assume a collaborator's `pnpm add` of it is intentional; confirm intent before keeping it.
