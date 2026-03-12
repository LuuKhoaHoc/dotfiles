-- Lsp for typescript
local Lsp = require "utils.lsp"
-- Source: https://github.com/yioneko/vtsls
-- Usage: npm install -g @vtsls/language-server
-- This config base on https://github.com/neovim/nvim-lspconfig/blob/master/lua/lspconfig/configs/vtsls.lua
return {
  cmd = { "vtsls", "--stdio" },
  on_attach = Lsp.on_attach,
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
  },
  -- Enhanced root markers for monorepo support
  root_markers = {
    -- TypeScript/JavaScript config files (highest priority)
    "tsconfig.json",
    "tsconfig.base.json",
    "jsconfig.json",
    -- Package managers
    "package.json",
    "pnpm-workspace.yaml",
    "pnpm-lock.yaml",
    "yarn.lock",
    "package-lock.json",
    -- Monorepo config files
    "turbo.json",
    "lerna.json",
    "nx.json",
    "rush.json",
    "workspace.json",
    "pnpm-workspace.yml",
    -- Framework configs
    "nest-cli.json",
    "next.config.js",
    "next.config.mjs",
    "next.config.cjs",
    "next.config.ts",
    "vite.config.js",
    "vite.config.ts",
    "rollup.config.js",
    "webpack.config.js",
    ".git",
  },
  settings = {
    complete_function_calls = true,
    vtsls = {
      enableMoveToFileCodeAction = true,
      autoUseWorkspaceTsdk = true,
      experimental = {
        completion = {
          enableServerSideFuzzyMatch = true,
        },
      },
      -- Monorepo support: automatically detect and use workspace tsdk
      useWorkspaceDependencies = true,
    },
    typescript = {
      updateImportsOnFileMove = { enabled = "always" },
      suggest = {
        completeFunctionCalls = true,
        includeCompletionsForModuleExports = true,
        includeCompletionsWithInsertText = true,
      },
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = false },
        variableTypes = { enabled = false },
        propertyDeclarationTypes = { enabled = false },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
      -- Monorepo workspace support - auto-detect from workspace
      tsdk = nil, -- Let vtsls auto-detect
      preferGoToSourceDefinition = true,
      -- Enable automatic type acquisition for better monorepo support
      disableAutomaticTypeAcquisition = false,
    },
    -- Workspace folder support for monorepo/MFE
    javascript = {
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = false },
        variableTypes = { enabled = false },
        propertyDeclarationTypes = { enabled = false },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
      suggest = {
        completeFunctionCalls = true,
        includeCompletionsForModuleExports = true,
      },
    },
  },
  -- Handle monorepo workspace folders
  on_init = function(client, result)
    -- Detect workspace folders for monorepo
    local workspace_dirs = {}
    local current_dir = vim.fn.getcwd()

    -- Look for package.json in apps/* and packages/* directories
    local function find_monorepo_dirs(base_dir)
      local dirs = {}
      local handle = io.popen(string.format(
        'find "%s" -maxdepth 4 -name "package.json" -type f 2>/dev/null',
        base_dir
      ))
      if handle then
        for line in handle:lines() do
          local dir = vim.fn.fnamemodify(line, ":h")
          if dir ~= base_dir and dir ~= "" then
            table.insert(dirs, dir)
          end
        end
        handle:close()
      end
      return dirs
    end

    -- Try to find monorepo root
    local git_root = vim.fn.finddir(".git", current_dir .. ";")
    if git_root ~= "" then
      local root_dir = vim.fn.fnamemodify(git_root, ":h")
      workspace_dirs = find_monorepo_dirs(root_dir)
    end

    -- Add workspace folders if found
    if #workspace_dirs > 0 then
      -- Build workspace folders params manually for Neovim 0.11+
      local workspace_folders = {}
      for _, dir in ipairs(workspace_dirs) do
        table.insert(workspace_folders, {
          uri = vim.uri_from_fname(dir),
          name = vim.fn.fnamemodify(dir, ":t"),
        })
      end

      -- Notify server about workspace folders
      if #workspace_folders > 0 then
        client.notify("workspace/didChangeWorkspaceFolders", {
          event = {
            added = workspace_folders,
            removed = {},
          },
        })
      end
    end
  end,
}
