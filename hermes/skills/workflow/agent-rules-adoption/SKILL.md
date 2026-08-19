---
name: agent-rules-adoption
description: "Use when a teammate shares agent-rules packs for adoption."
---

# Agent Rules Adoption — Evaluate Third-Party Rule Bundles Before Adopting

Class of task: someone (a teammate, a blog, a tool vendor) shares a bundle of agent-facing rules — `CLAUDE.md` / `AGENTS.md` / `.cursorrules` / a `dev-rules.zip` with an audit script — and the user wants to know what, if anything, to adopt for a repo or for the global harness setup. The trap: reading the markdown tells you intent; only running the bundle's audit tooling against the REAL codebase tells you applicability and current compliance.

## Workflow

1. **Inventory the bundle.** Unzip, list files, read `README`/LICENSE/frontmatter first. Identify the four typical parts: a framework-agnostic core rules file, a framework add-on (e.g. Next.js App Router — irrelevant for Vite/MFE repos), a per-project conventions template, and an audit script. Note the author's declared install targets (Claude Code `~/.claude/CLAUDE.md`, Codex `~/.codex/AGENTS.md`, Cursor `.cursorrules`) so you can tell the user where something WOULD go — without putting it there.

2. **Baseline what the repo already has BEFORE judging the bundle.** Read the repo's root `AGENTS.md`/`CLAUDE.md` (size says a lot: Hilo erp-admin carries a 17.7K AGENTS.md + 12.6K CLAUDE.md with ApiResponse envelope, DTO-first display, MFE boundaries, URL-backed filter state — generic third-party rules are mostly redundant against that) and the dotfiles canonical global context (`dotfiles/agents/global-context.md`, synced to `~/.claude/CLAUDE.md` + `~/.codex/AGENTS.md`). A rule already covered there is not an adoption gain.

3. **Run the bundle's audit script against a REAL source folder, using the repo's OWN config file:** `bash audit-rules.sh apps/hr/src --config CLAUDE.md`. If the bundle has no audit script, the markdown alone is only worth a skim — the durable value of these packs is usually the greppable checks, not the prose.

4. **Read the audit script SOURCE before trusting counts.** Look for sections whose checks are hardcoded instead of driven by the declared conventions block. Example (evondev's audit-rules.sh): section 1's kebab-case filename regex **never reads the `Filenames:` convention** — a PascalCase project gets hundreds of false hits (599 on apps/hr/src alone) while section 4/5 (raw button/img) DO respect the conventions via `case "$CONV_BUTTON"`. Hardcoded sections are the false-positive factory.

5. **Reduce output to a per-section hit table, not raw output.** Pair each `== N.` section title with its hit count (small python/awk pass over the output). Counts per section are what you judge; the raw dump is noise.

6. **Classify each section into three buckets:**
   - **False positives** — hardcoded-default checks that clash with the repo's real conventions (kebab-case regex vs PascalCase components). Report with the diagnosis, don't fix the codebase.
   - **Heuristic noise** — style-only guesses with huge counts (e.g. "blank line before return" awk heuristic = 460 hits). Weight sections, never the total.
   - **Real signal** — maintainability issues linters don't catch: `export * from` barrels (94), helper functions declared inside component files (87), boolean state without `is/has/should` prefix (119), component files >300 lines (60), `eslint-disable` without a reason comment, generic `Props` interfaces.
   - Zero-hit sections are also findings: they prove the repo already complies (e.g. cross-feature imports = 0 on erp-admin) — say so.

7. **Shape the recommendation.** Typical outcome for a mature repo: adopt the (adapted) audit script as a review tool, skip the markdown wholesale, fold only genuinely-missing micro-rules into the canonical global context, drop framework add-ons that don't apply. **Never auto-install into `~/.claude` / `~/.codex` / repo guides** — the user controls global setup and merge/commit; deliver analysis + offer the adapted artifact, don't write config.

## Pitfalls

- **Email-delivered bundles: download links can be sender-truncated.** If the link's signed token contains `...` inside the email body (e.g. Supabase signed URL token cut to `eyJraW...oc4g`), fetching the raw `.eml` (`https://object.testmail.app/api/<oid>.eml`) still shows the token truncated — the sender's template truncated it, not the mailbox. Supabase then answers `InvalidJWT`. This is unrecoverable from the email; ask the user to download the zip manually and attach it (worked case: dev-rules.zip claimed via GitHub-Edu testmail).
- **`web_extract` refuses URLs carrying credential-like query params** (`apikey=...`) — use `curl` directly for API endpoints with keys in the query string.
- **testmail.app JSON API shape** (for claiming GitHub-Edu / disposable inboxes): `api.testmail.app/api/json?apikey=...&namespace=...&pretty=true` → `emails[]` with `text`, `html` (link inside), `downloadUrl` (`object.testmail.app/api/<oid>.eml` for the raw message). Long URLs in the `.eml` are quoted-printable line-wrapped — decode before parsing.
- **A repo's existing conventions outrank third-party rules.** If a bundle rule contradicts the repo's AGENTS.md (ApiResponse envelope, UI-state placement), the repo wins; the bundle must be adapted, not applied.
- **Don't fix the codebase to satisfy the bundle.** The deliverable is an adoption analysis; flagging a PascalCase project for kebab-case because the audit script hardcodes it is the classic misstep.

## Support files

- `references/evondev-dev-rules-hr-audit.md` — worked example: full 25-section audit table for erp-admin `apps/hr/src` against evondev's dev-rules bundle, noise-vs-signal classification, and the Hilo convention mapping.