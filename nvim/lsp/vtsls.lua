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
    "typescript",
    "typescriptreact",
  },
  -- Prefer monorepo root (turbo.json, pnpm-workspace.yaml) to prevent LSP
  -- from starting multiple instances per workspace
  root_dir = function(fname)
    local root = vim.fs.root(fname, { "turbo.json", "pnpm-workspace.yaml", "nx.json", "lerna.json" })
    if root then return root end
    return vim.fs.root(fname, { "tsconfig.json", "jsconfig.json", "package.json", ".git" })
  end,
  -- Reuse a single vtsls instance across buffers in the same monorepo
  -- Prevents spawning 10+ vtsls processes for each workspace package
  reuse_client = true,
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
    },
    typescript = {
      updateImportsOnFileMove = { enabled = "always" },
      suggest = {
        completeFunctionCalls = true,
      },
      inlayHints = {
        parameterNames = { enabled = "literals" },
        parameterTypes = { enabled = false },
        variableTypes = { enabled = false },
        propertyDeclarationTypes = { enabled = false },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
    },
  },
}
