# Agent config map (verified 2026-08-05, Hilo ERP workstation)

## omp / oh-my-pi (can1357 fork of Pi, binary `omp`)

| Item | Location |
|---|---|
| Binary (bun install) | `~/.bun/bin/omp` — NOT in Hermes-terminal PATH; IS in `~/.zshrc` (`export PATH="$HOME/.bun/bin:$PATH"`) |
| Agent dir | `~/.omp/agent/` (new 17.x) vs `~/.pi/agent/` (old 0.83.0) |
| Main config | `~/.omp/agent/config.yml` (YAML; `omp config set <dotted.key> <value>` validates schema) |
| User-level context (persona) | `~/.omp/agent/AGENTS.md` — native, HIGHEST priority, shadows `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, `~/.config/opencode/AGENTS.md` |
| Sticky rules | `~/.omp/agent/RULES.md` (always-apply, survives compaction) |
| MCP | `~/.omp/agent/mcp.json` (`mcpServers` + `disabledServers`); auto-discovers `.claude/`, `.cursor/`, `.vscode/`, `.gemini/`, `.windsurf/`, `opencode.json` |
| Custom providers | `~/.omp/agent/models.yml` (`providers:` with baseUrl/api/apiKey/models) |
| Memory | `memory.backend: off\|local\|hindsight\|mnemopi`; `autolearn.enabled: true`; `/memory view\|clear\|enqueue`, `memory://root` readable via `read` tool |
| TTSR rules | `~/.omp/agent/rules/*.md` (user) / `.omp/rules/*.md` (project); frontmatter `condition: "<regex>"` hoặc `astCondition:`; `omp ttsr list\|test\|scan`; bad frontmatter → rule drop SILENT |
| Model roles | `modelRoles: default/smol/slow/plan/vision/task/tiny/advisor/commit`; `defaultProvider`+`defaultModel` legacy keys |
| One-shot | `omp -p "<prompt>"` (old pi: `pi -p`); context files load by default (`--no-context-files`/`-nc` disables) |
| Auth | `~/.omp/agent/agent.db` (OAuth, `/login`); old pi kept `auth.json` with provider keys |

Key config seen on this machine: `defaultProvider: opencode-go`, `defaultModel: deepseek-v4-flash`, `modelRoles.default: opencode-go/deepseek-v4-flash:max`, `plan: opencode-go/kimi-k2.7-code`, `advisor: opencode-go/kimi-k2.7-code` (đổi từ `xai-oauth/grok-4.5:xhigh` vì xai KHÔNG có auth — advisor/build trỏ provider chưa login sẽ fail "server error"; `omp config set` từ chối record key như `modelRoles.advisor`, phải sửa YAML trực tiếp), `theme.dark: titanium`. TTSR rule user-level: `~/.omp/agent/rules/no-ai-slop.md` (condition regex chống AI-slop).

## opencode (SST)

| Item | Location |
|---|---|
| Global config | `~/.config/opencode/opencode.json` (also reads `config.json`, `opencode.jsonc`) |
| Global context | `~/.config/opencode/AGENTS.md` (user-level) — repo `AGENTS.md` also loads |
| Project instructions | `repo/.opencode/opencode.json` → `{"instructions": [".opencode/conventions.md"]}` (paths relative to config file); repo `.gitignore` của erp-admin đã ignore `.opencode/` + `.claude/` (KHÔNG ignore `.omp/`) |
| Custom agents | `"agent": { "<name>": { "mode": "subagent", "model": "...", "prompt": "...", "permission": {"edit": "deny"} } }` — reviewer pattern verified |
| Agent models | `"agent": { "build": {...}, "plan": {...}, "general": {...}, "explore": {...}, "title": {...} }` |
| MCP | `"mcp": { "<name>": { "type": "local", "command": [...], "env": {...}, "enabled": true } }` |
| Plugins | `"plugin": ["@dietrichgebert/ponytail", "/abs/path/plugin.ts"]` (local TS plugins in `~/.config/opencode/plugins/`) |
| Skills dir | `~/.config/opencode/skills/` |
| Logs | `~/.local/share/opencode/log/opencode.log` |
| One-shot | `opencode run '<prompt>'` (uses `agent.build.model` by default!) |

## The RegionError case (why the old `pi` 403'd)

Symptom: `pi -p` (0.83.0) → `403 RegionError: "The latest version of this model is only available hosted in China and requires explicit opt in"` + workspace URL. Same credentials worked in opencode CLI (`opencode run --model opencode-go/deepseek-v4-flash` → OK) and Hermes.

Debug path that worked:
1. `pi doctor` + `pi -p` reproduce the 403.
2. `opencode run '...'` WITHOUT `--model` failed differently (`UnknownError: Unexpected server error`) — led to discovering `agent.build.model = xai/grok-4.5` was the default for `run`; explicit `--model opencode-go/deepseek-v4-flash` succeeded. Root cause #1: default agent model pointed at an erroring provider.
3. `mise ls` showed `pi 0.83.0 ... latest`; `mise upgrade pi` said "All tools are up to date" (FALSE — mise resolved the stale registry entry).
4. `mise ls-remote github:can1357/oh-my-pi` showed 17.2.4-17.2.7; GitHub releases API (`/repos/can1357/oh-my-pi/releases/latest`) → `v17.2.9`. Conclusion: installed `pi` was months old; gateway changed model serving → stale client 403. Root cause #2: version drift.
5. `~/.bun/bin/omp` (17.2.9) worked immediately with `opencode-go/deepseek-v4-flash:max`.

Lesson: when the SAME provider+model works in one client and 403s/errors in another, suspect (a) per-client default-model routing (check agent-specific model config), (b) stale client version vs gateway changes. `mise upgrade` "up to date" is not trustworthy for github: sources.

## Persona probe questions (verification)

- Repo knowledge: "Bạn đang ở repo nào? Mô tả 1-2 câu bằng tiếng Việt, ngắn gọn."
- Convention knowledge: "Theo quy ước làm việc của tôi: tôi đang refactor tính năng X chạm nhiều file trong 1 MFE. Tôi nên tạo issue thế nào? Nếu tạo nhầm 1 issue thì xử lý sao?"
- Expected answer (this user): 1 issue umbrella; issue thay thế → DELETE không close; MR ghi `Issue / Ticket: #N`, cấm "Closes #N"; label `ready-for-agent` + MFE tag.
