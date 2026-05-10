-- .nvim-config.lua — project-specific Neovim config for TypeScript monorepo
-- Auto-loaded by tiny-nvim when cwd matches this directory
-- Copy to project root, gitignore it, then customize.

-- Use vtsls for TypeScript (better monorepo + path alias support than ts_ls)
vim.g.lsp_typescript_server = "vtsls"

-- Tailwind on JS/TS files (add only if project uses Tailwind)
vim.g.lsp_on_demands = { "tailwindcss" }

-- Extra plugins (keys must match filenames under lua/plugins/extra/)
vim.g.enable_extra_plugins = {
  "copilot-nvim",  -- github/copilot.vim engine
  "blink-copilot", -- Copilot source inside blink.cmp
}

-- vtsls overrides (optional — vtsls reads tsconfig paths automatically)
vim.lsp.config("vtsls", {
  settings = {
    vtsls = {
      autoUseWorkspaceTsdk = true,
      enableMoveToFileCodeAction = true,
      experimental = {
        completion = { enableServerSideFuzzyMatch = true },
      },
    },
    typescript = {
      updateImportsOnFileMove = { enabled = "always" },
      suggest = { completeFunctionCalls = true },
      inlayHints = {
        parameterNames = { enabled = "literals" },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
    },
  },
})

-- Tailwind: broaden root_markers so LSP starts from monorepo root
-- (default markers only look for tailwind.config.* which may live in sub-apps)
vim.lsp.config("tailwindcss", {
  root_markers = {
    "tailwind.config.js",
    "tailwind.config.ts",
    "tailwind.config.cjs",
    "tailwind.config.mjs",
    "postcss.config.js",
    "postcss.config.ts",
    "package.json", -- Tailwind v4 via @tailwindcss/vite — no config file needed
  },
})
