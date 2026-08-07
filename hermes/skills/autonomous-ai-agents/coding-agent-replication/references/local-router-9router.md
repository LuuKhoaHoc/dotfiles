# Local router pattern: "9router" (2026-08-06)

A local OpenAI-compatible router at `http://127.0.0.1:20128/v1` (models: `opencode-premium`, `opencode-fast`, plus `hermes-agent-combo`, `pi-coder-premium`, etc.). Used when a coding-plan provider (opencode-go workspace) balance-gates some models. Router must be RUNNING on the machine (`curl -s -m 6 http://127.0.0.1:20128/v1/models` with Bearer key).

## omp: `~/.omp/agent/models.yml`

```yaml
providers:
  9router:
    baseUrl: http://127.0.0.1:20128/v1
    auth: apiKey
    apiKey: sk-...            # from the user's existing config
    api: openai-completions
    discovery:
      type: openai-models-list
    models:
      - id: opencode-premium
        name: opencode-premium
        reasoning: false
        input: [text, image]
        cost: {input: 0, output: 0, cacheRead: 0, cacheWrite: 0}
        contextWindow: 128000
        maxTokens: 16384
      - id: opencode-fast      # same shape
```

Wire roles in `~/.omp/agent/config.yml` (direct YAML edit — `omp config set modelRoles.advisor` is REJECTED as "Unknown setting" for nested record keys):

```yaml
modelRoles:
  advisor: 9router/opencode-premium
```

Advisor runtime is OFF by default: enable per session with `omp --advisor` or `/advisor`; global default = `advisor.enabled: false`.

## opencode: provider block in `~/.config/opencode/opencode.json`

```json
{
  "provider": {
    "9router": {
      "npm": "@ai-sdk/openai-compatible",
      "options": { "baseURL": "http://127.0.0.1:20128/v1", "apiKey": "sk-..." },
      "models": { "opencode-premium": { "name": "opencode-premium", "modalities": { "input": ["image","text"], "output": ["text"] } } }
    }
  }
}
```

NOTE: with a preset plugin (oh-my-opencode-slim) the top-level `"model"` is ignored — patch `presets.<active>.orchestrator.model` instead (that's where `opencode-go/glm-5.1` → `9router/opencode-premium` was fixed).

## Verification probes (free — no model call)

- Router up: `curl -s -m 6 http://127.0.0.1:20128/v1/models -H "Authorization: Bearer sk-..." | head -c 200`
- omp model works: `omp -p --model 9router/opencode-premium 'Reply with exactly: PREMIUM_OK'`
- opencode model works: `opencode run --model 9router/opencode-premium 'Reply with exactly: ROUTER_OK'` (flag override beats preset)
- Config read-back from native PowerShell: `powershell -NoProfile -Command 'omp config get modelRoles'` → grep `"advisor":"9router/opencode-premium"`

## Cross-machine gotchas

- `zereight-mcp-gitlab` was a direct binary on Linux (`~/.local/share/mise/.../bin/zereight-mcp-gitlab`); on Windows it does not exist → use `npx -y zereight-mcp-gitlab --token=... --api-url=https://gitlab.vppos.vn/api/v4`.
- MSYS: `cat /c/Users/<user>/...` can fail with "os error 3" while relative paths (after `cd`) work; PowerShell `Test-Path` on the native path is the ground truth.
