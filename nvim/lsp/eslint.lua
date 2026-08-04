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
  },
  -- Check monorepo root first so ESLint picks up the correct
  -- eslint.config.* from the workspace root, not a sub-package
  root_dir = function(fname)
    local monorepo_markers = { "turbo.json", "pnpm-workspace.yaml", "nx.json", "lerna.json" }
    local root = vim.fs.root(fname, monorepo_markers)
    if root then
      -- Also check if eslint config exists at monorepo root
      local eslint_markers = {
        ".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.yaml",
        ".eslintrc.yml", ".eslintrc.json",
        "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs",
        "eslint.config.ts", "eslint.config.mts", "eslint.config.cts",
      }
      local eslint_root = vim.fs.root(fname, eslint_markers)
      if eslint_root then return eslint_root end
      return root
    end
    return vim.fs.root(fname, {
      ".eslintrc", ".eslintrc.js", ".eslintrc.cjs", ".eslintrc.yaml",
      ".eslintrc.yml", ".eslintrc.json",
      "eslint.config.js", "eslint.config.mjs", "eslint.config.cjs",
      "eslint.config.ts", "eslint.config.mts", "eslint.config.cts",
    })
  end,
  -- Refer to https://github.com/Microsoft/vscode-eslint#settings-options for documentation.
  settings = {
    validate = "on",
    packageManager = nil,
    useESLintClass = false,
    experimental = {
      useFlatConfig = false,
    },
    codeActionOnSave = {
      enable = false,
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
  },
}
