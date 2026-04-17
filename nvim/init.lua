-- Load core editor options and performance tuning before any plugin setup.
require "config.options"
require "config.performance"

-- Load per-project settings from .nvim-config.lua if present.
-- This file is intentionally untracked so project-specific overrides stay local.
local project_setting = vim.fn.getcwd() .. "/.nvim-config.lua"
-- Check if the file exists and load it
if vim.loop.fs_stat(project_setting) then
  -- Read the file and run it with pcall to catch any errors
  local ok, err = pcall(dofile, project_setting)
  if not ok then
    vim.notify("Error loading project setting: " .. err, vim.log.levels.ERROR)
  end
end

-- Apply any configured performance optimizations early.
require("config.performance").setup()

-- Load editor behavior customizations, keybindings, and plugin configuration.
require "config.autocmds"
require "config.lazy"
require "config.keymaps"
require "config.project"

-- Only load the theme if not in VSCode
if vim.g.vscode then
  -- Trigger vscode keymap
  local pattern = "NvimIdeKeymaps"
  vim.api.nvim_exec_autocmds("User", { pattern = pattern, modeline = false })
else
  -- Load the colorscheme for normal Neovim sessions.
  require("kanagawa").load "wave"

  local ts_server = vim.g.lsp_typescript_server or "vtsls"   -- "ts_ls" or "vtsls" for TypeScript

  -- Configure built-in LSP servers for the current session.
  local lsp_servers = {
    ts_server,
    "lua_ls",          -- Lua
    "json",            -- JSON
    "pyright",         -- Python
    "gopls",           -- Go
    "tailwindcss",     -- Tailwind CSS
    "cssmodules",      -- CSS Language Server
    "eslint",          -- ESLint
  }

  -- Only add the Biome LSP when the current project explicitly uses Biome.
  local Lsp = require "utils.lsp"
  if Lsp.biome_config_exists() then
    table.insert(lsp_servers, "biome")  -- Biome = Eslint + Prettier
  end

  vim.lsp.enable(lsp_servers)

  -- Load Lsp on-demand, e.g: eslint is disable by default
  -- e.g: We could enable eslint by set vim.g.lsp_on_demands = {"eslint"}
  if vim.g.lsp_on_demands then
    vim.lsp.enable(vim.g.lsp_on_demands)
  end
end
