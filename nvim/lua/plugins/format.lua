return {
  "MunifTanjim/prettier.nvim",
  config = function()
    require("prettier").setup({
      bin = "prettier", -- hoặc 'prettier_d'
      filetypes = {
        "javascript",
        "typescript",
        "css",
        "scss",
        "json",
        "markdown",
        "vue",
        "svelte",
        "yaml",
        "html",
      },
    })
  end,
}
