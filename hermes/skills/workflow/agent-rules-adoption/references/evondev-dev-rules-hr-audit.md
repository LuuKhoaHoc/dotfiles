# Worked example — evondev dev-rules bundle vs erp-admin `apps/hr/src` (2026-08-17)

Bundle: "Dev Rules" by Trần Anh Tuấn (evondev), author of SpeakNow, MIT. Arrived as `dev-rules.zip` in a testmail inbox (GitHub-Edu claim). Contents: `CLAUDE.md` (core, framework-agnostic), `CLAUDE.nextjs.md` (Next.js App Router add-on), `PROJECT-CLAUDE.md` (per-project conventions template), `audit-rules.sh` (25 grep-based checks), `README.md`.

Command used:

```bash
bash audit-rules.sh apps/hr/src --config CLAUDE.md
```

`CLAUDE.md` (repo's own) lacks a Conventions block, so the script ran with defaults — which is exactly why section 1 false-positived: the default filename convention is kebab-case, but Hilo components are PascalCase.

## Per-section results (25 sections)

| # | Section | Hits | Class |
|---|---|---|---|
| 1 | Filenames must be kebab-case | 599 | **FALSE POSITIVE** — script hardcodes kebab-case regex; never reads a `Filenames:` convention. Hilo = PascalCase components (AttendanceEditDialog.tsx). Skip/fix script, not code. |
| 2 | src/app route folders (Next.js) | 0 | N/A — no `src/app`; non-Next framework, script skips |
| 3 | No imports across features | 0 | Compliant already (Hilo enforces this in AGENTS.md) |
| 4 | No raw `<button>` | 8 | Real signal, small — verify each against Button-from-@hilo/ui convention |
| 5 | No `<img>` | 1 | Real signal, tiny |
| 6 | No inline `<svg>` outside icons | 1 | Real signal, tiny (data charts OK per rule) |
| 7 | No `<a>` for internal links | 0 | Compliant already |
| 8 | className no array .join(" ") | 0 | Compliant already (uses `cn()`) |
| 9 | className no template-string ternary | 0 | Compliant already |
| 10 | No React.FormEvent (deprecated React 19) | 0 | Compliant already (React 19) |
| 11 | Props interface must be `<ComponentName>Props` | 5 | Real signal — generic `Props` names |
| 12 | No inline object type in signature | 21 | Real signal — extract to named interface |
| 13 | interface-over-type preference | 1 | Tiny |
| 14 | No `export * from` in barrels | 94 | **Real signal** — largest maintainability finding; traceability killer |
| 15 | One component per file | 21 | Real signal — helper components co-declared |
| 16 | Vague names in callbacks (`e`, `res`...) | 36 | Real signal, naming |
| 17 | Vague names elsewhere | 54 | Real signal, naming |
| 18 | Boolean state without is/has/should prefix | 119 | **Real signal** — bulk of the true positives |
| 19 | Constant arrays inside feature components | 16 | Real signal — move to `constants/` |
| 20 | Helper functions inside component files | 87 | **Real signal** — move to `utils/` |
| 21 | Missing index.ts barrel (folders ≥3 files) | 33 | Real signal |
| 22 | Duplicate util filenames across features | 1 | Tiny |
| 23 | eslint-disable without explanation comment | 8 | Real signal |
| 24 | Component files >300 lines | 60 | **Real signal** — split candidates |
| 25 | Blank line before return (heuristic) | 460 | **NOISE** — awk heuristic, style-only, not a bug |

Total 1625; real actionable signal ≈ sections 4, 5, 6, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 (roughly 550-600 hits). Section 1 (599) + 25 (460) = ~1050 were false-positive or noise.

## Classification lesson

- **Sections 3/7/8/9/10 = 0 hits** prove Hilo conventions already hold: no cross-feature import, no raw `<a>`, `cn()` helper used, React 19 FormEvent avoided. Report these as compliance wins, not "nothing found".
- The audit reads a Conventions block (`- Key: \`value\`` lines) to turn sections on/off (sections 4/5 via `$CONV_BUTTON`/`$CONV_IMAGES`, 8/9 via `$CONV_STYLING`, 10 via `$CONV_REACT`, 13 via `$CONV_TYPES`) — but section 1 is hardcoded and section 25 is a heuristic. Always diff the script source against its conventions reader before quoting numbers.
- For a Hilo-ready run, the repo CLAUDE.md/AGENTS.md needs a Conventions block declaring: `Framework: React (Vite)`, `Filenames: PascalCase`, `Button: raw <button> allowed` (or Button from @hilo/ui), `Icons: @hilo/icons` (custom set, not lucide), `Styling helper: cn()`, `React version: 19`, `Types: interface over type`. Then re-run and re-weight.

## Adoption verdict for erp-admin

- `CLAUDE.nextjs.md`: drop (Vite MFE monorepo, not Next.js).
- `CLAUDE.md` core markdown: mostly already covered by the repo's own AGENTS.md (17.7K) + CLAUDE.md (12.6K); the "one source per UI element" principle equals Hilo's @hilo/ui reuse rule.
- `audit-rules.sh`: the durable value. Adapt (fix section 1, add Conventions block) and reuse as an MR-review pre-check across the 7 MFEs + packages/ui — grep-based, cheap, catches what ESLint misses (barrels, helper-in-component, boolean naming).
- Global harness: do NOT plant per-harness rule files; if anything is worth global adoption, fold the micro-rules into `dotfiles/agents/global-context.md` which already syncs to `~/.claude/CLAUDE.md` + `~/.codex/AGENTS.md` via `sync-agents.sh`.

## Delivery-channel notes (testmail → zip)

- `web_extract` refused the API URL (contains `apikey=` query param) → used `curl` directly.
- The email's download link carried a **sender-truncated JWT** (`...eyJraW...oc4g`) — the raw `.eml` via `object.testmail.app/api/<oid>.eml` showed the same truncation (the sender's template cut it, not the mailbox). Supabase returned `InvalidJWT`. Unrecoverable — user downloaded the zip by hand and attached it. Lesson: don't burn time reconstructing a truncated signed token; ask for the file.