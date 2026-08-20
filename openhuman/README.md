# OpenHuman Config

OpenHuman configuration for the `6a85f4f7018099b972f6ae17` user profile.

## Layout
```
openhuman/
├── active_user.toml                      # points at the active profile id
├── window_state.toml                     # window geometry
└── users/6a85f4f7018099b972f6ae17/
    ├── config.toml                        # main config (models, providers, memory, features)
    └── auth-profiles.json                 # provider auth profiles (tokens are null here)
```

## Secrets — IMPORTANT
API keys are stored in `~/.openhuman/dev-keychain.json` (gitignored, never committed).
This repo only stores the non-secret config. After cloning:

1. Install OpenHuman and launch it once to create `~/.openhuman/`.
2. Copy this tree over your `~/.openhuman/` (preserving `dev-keychain.json` if it exists).
3. In OpenHuman → Settings → Providers → 9router, paste your 9router API key
   (the key lives on the VM gateway `https://router.luukhoahoc.me/v1`).

## What's configured
- **Model**: `9router:ocg/muse-spark-1.2` (1M context) for all routes
  (chat / reasoning / agentic / coding / vision / memory / heartbeat / learning / subconscious).
- **Provider 9router**: endpoint `https://router.luukhoahoc.me/v1`, auth_style `bearer`.
- **Memory**: local sqlite (no remote agentmemory dependency).
- **Features enabled**: learning, heartbeat, subconscious (local), super_context,
  autonomy=autonomous (workspace_only), TokenJuice, orchestration, cron, mcp_client.
- **Integrations**: connect via UI (Gmail / Calendar / Notion / Telegram etc. need OAuth).

## VM dependency
All models route through the 9router gateway on the Azure VM. If `router.luukhoahoc.me`
returns Cloudflare 1033, the VM / cloudflared tunnel is down — start it via the
`azure-vm-start` GitHub Action in this repo.
