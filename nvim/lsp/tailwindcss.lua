-- NOTE: npm install -g @tailwindcss/language-server
return {
  cmd = { "tailwindcss-language-server", "--stdio" },
  -- filetypes copied and adjusted from tailwindcss-intellisense
  filetypes = {
    -- html
    "aspnetcorerazor",
    "astro",
    "blade",
    "clojure",
    "django-html",
    "htmldjango",
    "edge",
    "eelixir", -- vim ft
    "elixir",
    "ejs",
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
    },
  },
  -- Check monorepo root for tailwind config so LSP works across
  -- all apps in a Turborepo workspace
  root_dir = function(fname)
    local root = vim.fs.root(fname, { "turbo.json", "pnpm-workspace.yaml", "nx.json", "lerna.json" })
    if root then
      -- Check if tailwind config exists at monorepo root
      local tw_markers = {
        "tailwind.config.js", "tailwind.config.cjs", "tailwind.config.mjs", "tailwind.config.ts",
        "postcss.config.js", "postcss.config.cjs", "postcss.config.mjs", "postcss.config.ts",
      }
      local tw_root = vim.fs.root(fname, tw_markers)
      if tw_root then return tw_root end
      return root
    end
    return vim.fs.root(fname, {
      "tailwind.config.js", "tailwind.config.cjs", "tailwind.config.mjs", "tailwind.config.ts",
      "postcss.config.js", "postcss.config.cjs", "postcss.config.mjs", "postcss.config.ts",
    })
  end,
}
