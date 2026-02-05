return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>m", group = "markdown", icon = "" },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    opts = { ensure_installed = { "markdown", "markdown_inline" } },
  },
  -- Markdown preview
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      latex = { enabled = false },
    },
    ft = { "markdown" },
    keys = {
      {
        "<leader>tm",
        "<cmd>RenderMarkdown toggle<cr>",
        desc = "Toggle Markdown preview",
      },
    },
  },
  {
    "previm/previm",
    config = function()
      -- define global for open markdown preview -- use xdg-open if want to use default browser
      vim.g.previm_open_cmd = "google-chrome-stable"
    end,
    ft = { "markdown" },
    keys = {
      {
        "<leader>m",
        "<cmd>PrevimOpen<cr>",
        desc = "Markdown preview on browser",
      },
    },
  },
}
