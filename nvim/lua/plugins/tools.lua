return {
  -- Thêm bất kỳ công cụ nào bạn muốn cài đặt dưới đây
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "stylua",
        "shellcheck",
        "shfmt",
        "flake8",
      },
    },
  },
  {
    "luckasRanarison/tailwind-tools.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim", -- tùy chọn
      "neovim/nvim-lspconfig", -- tùy chọn
    },
    config = function()
      require("tailwind-tools").setup()
    end,
  },
}
