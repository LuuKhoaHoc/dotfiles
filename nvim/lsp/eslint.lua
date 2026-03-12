-- NOTE: You need to install the eslint language server to use this config.
-- npm i -g vscode-langservers-extracted

return {
  cmd = { "vscode-eslint-language-server", "--stdio" },
  filetypes = {
    "javascript",
    "javascriptreact",
    "javascript.jsx",
    "typescript",
    "typescriptreact",
    "typescript.tsx",
    "vue",
    "svelte",
    "astro",
    "json",
    "jsonc",
    "css",
    "scss",
    "sass",
    "less",
    "postcss",
  },
  -- Enhanced root markers for monorepo support
  root_markers = {
    -- ESLint config files (new flat config first)
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.cjs",
    "eslint.config.ts",
    "eslint.config.mts",
    "eslint.config.cts",
    -- Legacy ESLint config files
    ".eslintrc",
    ".eslintrc.js",
    ".eslintrc.cjs",
    ".eslintrc.yaml",
    ".eslintrc.yml",
    ".eslintrc.json",
    -- Package and monorepo configs
    "package.json",
    "pnpm-workspace.yaml",
    "yarn.lock",
    "package-lock.json",
    "pnpm-lock.yaml",
    -- Monorepo configs
    "turbo.json",
    "lerna.json",
    "nx.json",
    ".git",
  },
  -- Refer to https://github.com/Microsoft/vscode-eslint#settings-options for documentation.
  settings = {
    validate = "on",
    packageManager = nil,
    useESLintClass = false,
    experimental = {
      useFlatConfig = false,
    },
    codeActionOnSave = {
      enable = true, -- Enable auto-fix on save
      mode = "all",
    },
    format = true,
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    run = "onType",
    problems = {
      shortenToSingleLine = false,
    },
    -- nodePath configures the directory in which the eslint server should start its node_modules resolution.
    -- This path is relative to the workspace folder (root dir) of the server instance.
    -- For monorepo support, we leave this empty to allow workspace resolution
    nodePath = "",
    -- use the workspace folder location or the file location (if no workspace folder is open) as the working directory
    workingDirectory = { mode = "location" },
    codeAction = {
      disableRuleComment = {
        enable = true,
        location = "separateLine",
      },
      showDocumentation = {
        enable = true,
      },
    },
    -- Monorepo support: use workspace dependencies
    useWorkspaceDependencies = true,
  },
}
