return {
  -- Thêm pyright vào lspconfig
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        pyright = {},
      },
    },
  },
  -- Thêm tsserver và thiết lập với typescript.nvim thay vì lspconfig
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      {
        "jose-elias-alvarez/typescript.nvim",
        config = function()
          require("typescript").setup({
            server = {
              on_attach = function(client, bufnr)
                -- Thiết lập phím tắt cho TypeScript
                vim.keymap.set(
                  "n",
                  "<leader>co",
                  ":TypescriptOrganizeImports<CR>",
                  { buffer = bufnr, desc = "Organize Imports" }
                )
                vim.keymap.set("n", "<leader>cR", ":TypescriptRenameFile<CR>", { buffer = bufnr, desc = "Rename File" })
              end,
            },
          })
        end,
      },
    },
    config = function()
      local lspconfig = require("lspconfig")

      -- Cấu hình cho cssls
      lspconfig.cssls.setup({
        settings = {
          css = { validate = true },
          scss = { validate = true },
          less = { validate = true },
        },
      })
    end,
  },
  -- Thêm jsonls và schemastore packages, và thiết lập treesitter cho json, json5 và jsonc
  { import = "lazyvim.plugins.extras.lang.json" },
}
