local Path = require "utils.path"

local M = {}

-- Provide LSP-only keymaps so the rest of the config can stay plugin-agnostic.
function M.get_default_keymaps()
  return {
    { keys = "<leader>ca", func = vim.lsp.buf.code_action, desc = "Code Actions" },
    { keys = "<leader>.",  func = vim.lsp.buf.code_action, desc = "Code Actions" },
    { keys = "<leader>cA", func = M.action.source,         desc = "Source Actions" },
    { keys = "<leader>co", func = M.organizeImports,       desc = "Organize Imports" },
    { keys = "<leader>cu", func = M.removeUnusedImports,   desc = "Remove Unused Imports" },
    { keys = "<leader>cU", func = M.fixUnusedCode,         desc = "Fix Unused Code" },
    { keys = "<leader>cM", func = M.addMissingImports,     desc = "Add Missing Imports" },
    { keys = "<leader>cr", func = vim.lsp.buf.rename,      desc = "Code Rename" },
    { keys = "<leader>cf", func = vim.lsp.buf.format,      desc = "Code Format" },
    { keys = "<leader>k",  func = vim.lsp.buf.hover,       desc = "Documentation",        has = "hoverProvider" },
    { keys = "K",          func = vim.lsp.buf.hover,       desc = "Documentation",        has = "hoverProvider" },
    { keys = "gd",         func = vim.lsp.buf.definition,  desc = "Goto Definition",      has = "definitionProvider" },
    -- NOTE: Use snack UI for below keymaps
    -- { keys = "gD", func = vim.lsp.buf.declaration, desc = "Goto Declaration", has = "declarationProvider" },
    -- { keys = "gr", func = vim.lsp.buf.references, desc = "Goto References", has = "referencesProvider", nowait = true },
    -- { keys = "gi", func = vim.lsp.buf.implementation, desc = "Goto Implementation", has = "implementationProvider" },
    -- { keys = "gy", func = vim.lsp.buf.type_definition, desc = "Goto Type Definition", has = "typeDefinitionProvider" },
  }
end

M.on_attach = function(client, buffer)
  local keymaps = M.get_default_keymaps()
  for _, keymap in ipairs(keymaps) do
    if not keymap.has or client.server_capabilities[keymap.has] then
      vim.keymap.set(keymap.mode or "n", keymap.keys, keymap.func, {
        buffer = buffer,
        desc = "LSP: " .. keymap.desc,
        nowait = keymap.nowait,
      })
    end
  end
end

M.action = setmetatable({}, {
  __index = function(_, action)
    return function()
      vim.lsp.buf.code_action {
        apply = true,
        context = {
          only = { action },
          diagnostics = {},
        },
      }
    end
  end,
})

M.organizeImports = function()
  -- Use source actions to keep import cleanup aligned with the active server.
  vim.lsp.buf.code_action({
    context = { only = { "source.organizeImports" } },
    apply = true
  })
end

M.removeUnusedImports = function()
  -- Remove imports through the server so the result matches language-specific rules.
  vim.lsp.buf.code_action({
    context = { only = { "source.removeUnusedImports" } },
    apply = true
  })
end

M.fixUnusedCode = function()
  -- Let the server fix broader dead-code issues when it knows how.
  vim.lsp.buf.code_action({
    context = { only = { "source.fixAll" } },
    apply = true
  })
end

M.addMissingImports = function()
  -- Ask the server to infer and add unresolved imports.
  vim.lsp.buf.code_action({
    context = { only = { "source.addMissingImports" } },
    apply = true
  })
end



-- Conform and lint helpers share config-path discovery logic.
--- Get the path of the config file in the current directory or the root of the git repo
---@param filename string
---@return string | nil
local function get_config_path(filename)
  local current_dir = vim.fn.getcwd()
  local config_file = current_dir .. "/" .. filename
  if vim.fn.filereadable(config_file) == 1 then
    return current_dir
  end

  -- Fall back to the repo root so nested packages still inherit shared config.
  local git_root = Path.get_git_root()
  if Path.is_git_repo() and git_root ~= current_dir then
    config_file = git_root .. "/" .. filename
    if vim.fn.filereadable(config_file) == 1 then
      return git_root
    end
  end

  return nil
end

M.biome_config_path = function()
  return get_config_path "biome.json"
end

M.biome_config_exists = function()
  local has_config = get_config_path "biome.json"
  return has_config ~= nil
end

M.dprint_config_path = function()
  return get_config_path "dprint.json"
end

M.dprint_config_exist = function()
  local has_config = get_config_path "dprint.json"
  return has_config ~= nil
end

M.deno_config_exist = function()
  local has_config = get_config_path "deno.json" or get_config_path "deno.jsonc"
  return has_config ~= nil
end

M.spectral_config_path = function()
  return get_config_path ".spectral.yaml"
end

M.eslint_config_exists = function()
  local current_dir = vim.fn.getcwd()
  local config_files = {
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.yaml",
    ".eslintrc.yml",
    ".eslintrc.json",
    ".eslintrc",
    "eslint.config.js",
  }

  for _, file in ipairs(config_files) do
    local config_file = current_dir .. "/" .. file
    if vim.fn.filereadable(config_file) == 1 then
      return true
    end
  end

  -- Fall back to the repo root so workspaces can share a single ESLint config.
  local git_root = Path.get_git_root()
  if Path.is_git_repo() and git_root ~= current_dir then
    for _, file in ipairs(config_files) do
      local config_file = git_root .. "/" .. file
      if vim.fn.filereadable(config_file) == 1 then
        return true
      end
    end
  end

  return false
end

M.prettier_config_exists = function()
  local current_dir = vim.fn.getcwd()
  local config_files = {
    ".prettierrc",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.yaml",
    ".prettierrc.yml",
    ".prettierrc.json",
    ".prettierrc.json5",
    ".prettierrc.toml",
    "prettier.config.js",
    "prettier.config.cjs",
    ".prettierrc.mjs",
    "prettier.config.mjs",
  }

  for _, file in ipairs(config_files) do
    local config_file = current_dir .. "/" .. file
    if vim.fn.filereadable(config_file) == 1 then
      return true
    end
  end

  -- Fall back to the repo root so nested packages can share a formatter config.
  local git_root = Path.get_git_root()
  if Path.is_git_repo() and git_root ~= current_dir then
    for _, file in ipairs(config_files) do
      local config_file = git_root .. "/" .. file
      if vim.fn.filereadable(config_file) == 1 then
        return true
      end
    end
  end

  return false
end

return M
