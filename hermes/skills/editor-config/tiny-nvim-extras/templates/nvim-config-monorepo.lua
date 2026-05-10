-- Project-local Neovim config template for monorepo projects
-- Copy to <project-root>/.nvim-config.lua and customize
-- Auto-loaded by tiny-nvim when cwd == project root

-- === LSP ===
-- Override default TS server (vtsls recommended for monorepo)
-- vim.g.lsp_typescript_server = "vtsls"

-- Add on-demand LSP servers (loaded alongside default LSP for JS/TS)
-- vim.g.lsp_on_demands = { "tailwindcss" }

-- === Extra plugins ===
-- Keys must match files under lua/plugins/extra/ exactly
-- (e.g. "copilot-nvim" not "copilot")
-- vim.g.enable_extra_plugins = {
--   "copilot-nvim",
--   "blink-copilot",
-- }

-- === Per-project LSP overrides ===
-- Example: vtsls settings
-- vim.lsp.config("vtsls", {
--   settings = {
--     vtsls = {
--       autoUseWorkspaceTsdk = true,
--       enableMoveToFileCodeAction = true,
--     },
--   },
-- })

-- === Per-project Tailwind root markers ===
-- vim.lsp.config("tailwindcss", {
--   root_markers = {
--     "tailwind.config.js",
--     "tailwind.config.ts",
--     "package.json",
--   },
-- })