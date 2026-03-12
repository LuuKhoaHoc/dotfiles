-- NOTE: npm install -g @tailwindcss/language-server
return {
  cmd = { "tailwindcss-language-server", "--stdio" },
  -- filetypes copied and adjusted from tailwindcss-intellisense
  filetypes = {
    -- html
    "aspnetcorerazor",
    "astro",
    "astro-markdown",
    "blade",
    "clojure",
    "django-html",
    "htmldjango",
    "edge",
    "eelixir", -- vim ft
    "elixir",
    "ejs",
    "erb",
    "eruby", -- vim ft
    "gohtml",
    "gohtmltmpl",
    "haml",
    "handlebars",
    "hbs",
    "html",
    "htmlangular",
    "html-eex",
    "heex",
    "jade",
    "leaf",
    "liquid",
    "markdown",
    "mdx",
    "mustache",
    "njk",
    "nunjucks",
    "php",
    "razor",
    "slim",
    "twig",
    -- css
    "css",
    "less",
    "postcss",
    "sass",
    "scss",
    "stylus",
    "sugarss",
    -- js
    "javascript",
    "javascriptreact",
    "reason",
    "rescript",
    "typescript",
    "typescriptreact",
    -- mixed
    "vue",
    "svelte",
    "templ",
  },
  settings = {
    tailwindCSS = {
      validate = true,
      lint = {
        cssConflict = "warning",
        invalidApply = "error",
        invalidScreen = "error",
        invalidVariant = "error",
        invalidConfigPath = "error",
        invalidTailwindDirective = "error",
        recommendedVariantOrder = "warning",
      },
      classAttributes = {
        "class",
        "className",
        "class:list",
        "classList",
        "ngClass",
      },
      includeLanguages = {
        eelixir = "html-eex",
        eruby = "erb",
        templ = "html",
        htmlangular = "html",
      },
      -- Monorepo support: search for tailwind config in workspace
      experimental = {
        classRegex = {},
      },
      -- Emmet completions
      emmetCompletions = true,
      -- Enable suggestions for custom class attributes
      suggestions = true,
      -- IntelliSense options
      intellisense = {
        classNameMetadata = true,
      },
    },
  },
  -- Enhanced root markers for monorepo support
  root_markers = {
    -- Tailwind config files (priority order)
    "tailwind.config.js",
    "tailwind.config.cjs",
    "tailwind.config.mjs",
    "tailwind.config.ts",
    "tailwind.config.json",
    -- PostCSS config
    "postcss.config.js",
    "postcss.config.cjs",
    "postcss.config.mjs",
    "postcss.config.ts",
    -- Package files for monorepo detection
    "package.json",
    "pnpm-workspace.yaml",
    "yarn.lock",
    "package-lock.json",
    -- Monorepo configs
    "turbo.json",
    "lerna.json",
    "nx.json",
    ".git",
  },
  on_attach = function(client, bufnr)
    require("utils.lsp").on_attach(client, bufnr)
    local ok, colors = pcall(require, "tailwindcss-colors")
    if ok then
      colors.buf_attach(bufnr)
    end
  end
}
