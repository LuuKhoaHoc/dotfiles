---
name: coding-agent-setup
description: "Configure coding agents (omp/opencode): persona, MCP."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, Setup, Configuration, Persona, omp, opencode, Model-Routing]
    related_skills: [opencode, claude-code, codex, hermes-agent, zed-agent-integration]
---

# Coding Agent Setup (persona + config)

Use when the user wants to set up / configure terminal AI coding agents — oh-my-pi (omp), opencode, claude-code, codex, gemini CLI — especially requests like *"set up X đỉnh như hermes / hiểu tôi như hermes"*. Two halves: (1) make the agent understand the **codebase** (AGENTS.md, MCP servers), (2) make it understand the **user** (persona, rules, memory).

## Core recipe: persona transfer ("hiểu tôi như Hermes")

1. **Inventory installs + versions first.** `which -a omp pi opencode`, then `~/.bun/bin/omp --version`, `mise ls`. Multiple installs of the same tool under different names/bins are the norm (see Pitfalls). Identify the NEWEST binary and which agent dir it uses (`~/.omp/agent` vs `~/.pi/agent`).
2. **Write the user persona into the agent's GLOBAL context file** (user-level, highest priority):
   - omp: `~/.omp/agent/AGENTS.md` (native, shadows `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md` inside omp)
   - opencode: `~/.config/opencode/AGENTS.md`
   - claude-code: `~/.claude/CLAUDE.md`
   - codex: `~/.codex/AGENTS.md`
   Persona content — **UNIVERSAL ONLY** (source: Hermes user profile + memory): who the user is (company/role), communication language + brevity (this user: tiếng Việt, ngắn gọn; code/commit tiếng Anh), general tech preferences (React 19 best practices, Tailwind thay inline style, search-before-code). Keep ~20-40 lines.
   ⚠️ **USER CORRECTION (2026-08): project-specific conventions must NOT go into global files** — they load in EVERY project and pollute other work; user objected "quá specify quá vào 1 dự án". Issue-management conventions, spec owners, MFE layout → project scope (step 2b).
   ⚠️ Because the native file shadows others, copy any needed bits (e.g. CodeGraph instructions) into it.
2b. **Project-scoped conventions live in the REPO, not global** (prefer gitignored dirs):
   - omp + claude-code: `repo/.claude/CLAUDE.md`
   - opencode: `repo/.opencode/opencode.json` → `{"instructions": [".opencode/conventions.md"]}` (paths resolve relative to the config file)
   - Check the repo `.gitignore` first: erp-admin already ignores `.claude/` + `.opencode/`; `.omp/` is NOT ignored (untracked noise).
   - Don't duplicate the repo's committed AGENTS.md — supplement only what's missing (e.g. GitLab issue/MR workflow: umbrella issue, DELETE không close, cấm "Closes #N", labels, spec owners).
   - Leak check: probe INSIDE the repo (agent knows the conventions) AND in a throwaway dir OUTSIDE (agent must NOT quote them).
2c. **Cross-harness global context (2026-08, khoahoc machine):** ONE canonical file `dotfiles/agents/global-context.md` (persona + communication + tech prefs + supermemory memory directive) injected into ALL harness instruction files between `<!-- GLOBAL-CONTEXT-START/END -->` markers. Files: `~/.config/opencode/AGENTS.md`, `~/.omp/agent/AGENTS.md`, `~/.config/zed/AGENTS.md`, `~/.gemini/GEMINI.md`, `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`. Sync with `agents-sync push|pull` (`~/.local/bin/agents-sync` → `dotfiles/agents/sync-agents.sh`; `apply` re-injects canonical idempotently, keeps harness-specific sections intact). Edit the CANONICAL, then `agents-sync push` — never edit each file by hand. Note: `sync-omp.sh`/`sync-opencode.sh` strip secrets on push (patterns: glpat-/ctx7sk-/sk- + sm_/figd_/ntn_ prefixes); GitHub secret scanning will reject pushes that miss a new token prefix — extend the pattern when adding new API keys to mcp.json.
3. **Sticky rules** where supported: omp `~/.omp/agent/RULES.md` — short hard requirements re-attached near the current turn (survive long conversations).
4. **Cross-session memory**: omp `memory.backend: mnemopi` (local SQLite retain/recall/reflect + first-turn auto-recall; `local` = static summary only) + `autolearn.enabled: true`. This is omp's analogue of Hermes memory.
5. **Mirror MCP servers** the user relies on: gitlab, context7, codegraph, sonarqube, etc. omp: `~/.omp/agent/mcp.json` (also auto-discovers `.claude/`, `.cursor/`, `.vscode/`, `.gemini/`, `opencode.json`); opencode: `"mcp"` key in `~/.config/opencode/opencode.json`.
6. **VERIFY with a persona probe** — run in the target repo so AGENTS.md loads:
   - `omp -p "Theo quy ước làm việc của tôi, khi refactor cùng 1 feature thì xử lý issue thế nào? Trả lời 2-3 câu tiếng Việt."`
   - `opencode run '...'`
   Pass criteria: correct language + the user's ACTUAL conventions (e.g. issue umbrella, DELETE không close, `Issue / Ticket: #N`), not generic advice. Probe repo knowledge too ("repo này là gì?").
   Project-scope check: probe from OUTSIDE the repo (e.g. `mkdir -p /tmp/probe && cd /tmp/probe && omp -p "Bạn có quy ước gì về cách tôi quản lý issue trên GitLab không?"`) — must NOT leak project conventions; probe BOTH tools in-repo.
7. If you changed config files, verify with an ad-hoc script under `mktemp` (JSON validity + behavioral run), then clean up.

## Pitfalls

- **opencode `run` uses `agent.build.model`, NOT the top-level `"model"` key.** `opencode run 'hi'` failing with `Unexpected server error` while `--model <working-model>` succeeds → check `agent.build.model` in `~/.config/opencode/opencode.json`. Fix by pointing build (and plan/explore/etc.) at a model that actually works.
- **Same provider, one client 403s, another works → version drift.** Old omp (`pi` 0.83.0 via mise) got `403 RegionError: model only available hosted in China, requires explicit opt in` from the opencode-go gateway while opencode CLI + Hermes + new omp (17.x) worked with the same credentials. Gateway changed how the model is served; stale client catalog breaks. Fix: update the agent; `mise upgrade` may falsely report "up to date" — cross-check `mise ls-remote github:can1357/oh-my-pi` and GitHub releases API (`/repos/can1357/oh-my-pi/releases/latest`), and prefer the newer install (bun: `~/.bun/bin/omp`).
- **`zsh -lc` does NOT source `.zshrc`** (non-interactive). `zsh -lc 'which omp'` fails even though the interactive shell has it. Use the full binary path for testing.
- **Flag drift across versions**: old pi's `-a`/`--approve` no longer exists in omp 17.x (`Error: unknown flag: -a`). Check `omp --help` for the installed version.
- **omp config edits: use `omp config set <dotted.key> <value>`** — schema-validated. A hand-edited malformed `config.yml` makes omp log a warning and silently ignore the whole file. Validate with `omp config list`/`omp config get` after editing.
- **`--no-context-files`** exists on omp (`-nc`) — AGENTS.md/CLAUDE.md load by default; don't disable when testing persona.

## TTSR rules (omp time-traveling stream rules)

- Files: `~/.omp/agent/rules/*.md` (user) / `.omp/rules/*.md` (project). Frontmatter key: `condition: "<regex>"` or `astCondition:` (ast-grep pattern) — NOT `ttsrtrigger` (older third-party docs are wrong).
- Bad frontmatter → rule SILENTLY dropped from `omp ttsr list` — always `omp ttsr list` + `omp ttsr test '<snippet>'` after adding; `omp ttsr test -r <rulefile> '...'` tests one rule in isolation.
- ~27 builtin-default rules (Go/TS/Rust hygiene) ship with the agent; `omp ttsr list` prints to STDOUT.
- Starter: `templates/ttsr-rule.md`.

## Pitfalls (extra)

- **`omp config set` rejects nested record keys** (`modelRoles.advisor` → "Unknown setting") — edit `config.yml` directly for records; scalar keys via `omp config set` (schema-validated).
- **pipefail + `grep -q` false negative**: `set -o pipefail` + `cmd | grep -q x` fails spuriously — grep -q exits on first match → writer gets SIGPIPE (141) → pipefail surfaces 141. Capture first: `OUT=$(cmd 2>&1)`; then `echo "$OUT" | grep -q x`.
- **opencode custom agents**: reviewer pattern `{"mode": "subagent", "permission": {"edit": "deny"}}`; community rule: AGENTS.md SHORT + imperative (handful of hard rules), not a wiki. Optional preset: oh-my-openagent (skill sets: git-master, review-work, remove-ai-slops).

## Reference

- `references/agent-config-map.md` — per-agent config paths/keys + the RegionError debugging case (2026-08-05).
