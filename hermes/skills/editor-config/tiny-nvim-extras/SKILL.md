---
name: tiny-nvim-extras
description: Enable and manage optional plugins in tiny-nvim config via vim.g.enable_extra_plugins. Use when toggling copilot, blink-copilot, codecompanion, avante, claude-code, or any plugin under lua/plugins/extra/.
triggers:
  - "enable copilot nvim"
  - "bật copilot"
  - "enable extra plugin"
  - "tiny-nvim plugin"
  - ".nvim-config.lua"
---

# tiny-nvim Extra Plugins

## How it works

tiny-nvim uses an opt-in system. Plugins under `lua/plugins/extra/` are NOT loaded by default.
They load only when listed in `vim.g.enable_extra_plugins` inside `.nvim-config.lua` (gitignored).

**Two locations are auto-loaded:**
1. Global — `~/.config/nvim/.nvim-config.lua` (nvim config root)
2. Project-local — `.nvim-config.lua` in the current working directory (cwd when nvim starts)

Project-local is ideal for per-project LSP servers, extra plugins, and workspace-specific settings.

`lua/config/lazy.lua` reads `vim.g.enable_extra_plugins` and imports `plugins.extra.<name>` for each entry. Keys must match filenames exactly (see Pitfalls).

## .nvim-config.lua location

File lives at the root of the nvim config dir, e.g.:
  /home/khoahoc/Dev-Work/dotfiles/nvim/.nvim-config.lua

If missing, NO extra plugins load — not even copilot.

Project-local template for monorepo:
  `templates/nvim-config-monorepo.lua` — copy to `./.nvim-config.lua` and uncomment as needed.

## Available extras (known)

| key            | what it does                                              |
|----------------|-----------------------------------------------------------|
| copilot-nvim   | github/copilot.vim — inline ghost-text autocomplete (file: copilot-nvim.lua) |
| blink-copilot  | fang2hou/blink-copilot — Copilot source inside blink.cmp |
| copilot-chat   | CopilotChat.nvim — chat UI, depends on copilot.vim        |
| codecompanion  | CodeCompanion — AI coding assistant, uses copilot adapter |
| avante         | Avante — AI sidebar, uses zbirenbaum/copilot.lua          |
| claude-code    | Claude Code integration                                   |
| claudecode     | Alternative Claude Code plugin                            |

## Copilot setup (recommended combo)

```lua
-- .nvim-config.lua
vim.g.enable_extra_plugins = {
  "copilot-nvim",  -- engine (file: copilot-nvim.lua)
  "blink-copilot", -- bridge for blink.cmp integration
}
```

After saving, inside Neovim:
1. `:Lazy sync` — install plugins
2. `:Copilot auth` — authenticate with GitHub

**Key must match file name**: `vim.g.enable_extra_plugins` entries map directly to files under `lua/plugins/extra/`. Example: `"copilot-nvim"` → `copilot-nvim.lua`. Mismatch causes "No specs found for module" errors.

## Tailwind CSS LSP

Configured in `lsp/tailwindcss.lua`. Supports Tailwind v4 via `@tailwindcss/language-server`.

Install server:
```bash
npm install -g @tailwindcss/language-server@latest
```

LSP auto-enables for: html, css, scss, sass, less, postcss, and JS/TS with React/Vue filetypes (if added to `init.lua` `lsp_by_ft`).

For Tailwind v4, no extra config needed — LSP handles `@import "tailwindcss"` syntax.

## Pitfalls

- File must exist even if empty — if missing, `vim.g.enable_extra_plugins` is nil and nothing loads.
- `avante` disables `github/copilot.vim` and uses `zbirenbaum/copilot.lua` instead — don't mix with `copilot` key.
- `blink-copilot` without `copilot` = broken, needs the engine.
