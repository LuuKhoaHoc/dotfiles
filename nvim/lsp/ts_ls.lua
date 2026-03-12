local Lsp = require "utils.lsp"
-- NOTE: npm install -g typescript typescript-language-server
return {
  on_attach = Lsp.on_attach,
  init_options = { hostInfo = "neovim" },
  cmd = { "typescript-language-server", "--stdio" },
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
    typescript = {
      -- Inlay Hints preferences
      inlayHints = {
        -- You can set this to 'all' or 'literals' to enable more hints
        includeInlayParameterNameHints = "literals", -- 'none' | 'literals' | 'all'
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = false,
        includeInlayVariableTypeHints = false,
        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
        includeInlayPropertyDeclarationTypeHints = false,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
      -- Code Lens preferences
      implementationsCodeLens = {
        enabled = true,
      },
      referencesCodeLens = {
        enabled = true,
        showOnAllFunctions = true,
      },
      format = {
        indentSize = vim.o.shiftwidth,
        convertTabsToSpaces = vim.o.expandtab,
        tabSize = vim.o.tabstop,
      },
      -- Monorepo support
      suggest = {
        includeCompletionsForModuleExports = true,
        includeCompletionsWithInsertText = true,
      },
      updateImportsOnFileMove = { enabled = "always" },
    },
    javascript = {
      -- Inlay Hints preferences
      inlayHints = {
        -- You can set this to 'all' or 'literals' to enable more hints
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayParameterNameHints = "all", -- 'none' | 'literals' | 'all'
        includeInlayVariableTypeHints = true,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHintsWhenTypeMatchesName = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
      -- Code Lens preferences
      implementationsCodeLens = {
        enabled = true,
      },
      referencesCodeLens = {
        enabled = true,
        showOnAllFunctions = true,
      },
      format = {
        indentSize = vim.o.shiftwidth,
        convertTabsToSpaces = vim.o.expandtab,
        tabSize = vim.o.tabstop,
      },
      -- Monorepo support
      suggest = {
        includeCompletionsForModuleExports = true,
        includeCompletionsWithInsertText = true,
      },
    },
    completions = {
      completeFunctionCalls = true,
    },
  },
}
