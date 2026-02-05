return {
  {
    "amitds1997/remote-nvim.nvim",
    version = "*", -- Pin to GitHub releases
    dependencies = {
      "nvim-lua/plenary.nvim", -- For standard functions
      "MunifTanjim/nui.nvim", -- To build the plugin UI
      "nvim-telescope/telescope.nvim", -- For picking b/w different remote methods
    },
    cmd = {
      "RemoteStart",
      "RemoteStop",
      "RemoteInfo",
      "RemoteCleanup",
      "RemoteConfigDel",
      "RemoteLog",
    },
    keys = {
      { "<leader>rs", "<cmd>RemoteStart<cr>", desc = "Remote Start" },
      { "<leader>ri", "<cmd>RemoteInfo<cr>", desc = "Remote Info" },
      { "<leader>rq", "<cmd>RemoteStop<cr>", desc = "Remote Stop" },
      { "<leader>rc", "<cmd>RemoteCleanup<cr>", desc = "Remote Cleanup" },
    },
    opts = {
      -- Configuration for SSH connections
      ssh_config = {
        ssh_binary = "ssh",
        scp_binary = "scp",
        ssh_config_file_paths = { "$HOME/.ssh/config" },
      },
      -- Remote configuration
      remote = {
        app_name = "nvim",
        copy_dirs = {
          config = {
            base = vim.fn.stdpath("config"),
            dirs = "*",
            compression = {
              enabled = false,
            },
          },
          data = {
            base = vim.fn.stdpath("data"),
            dirs = {},
            compression = {
              enabled = true,
            },
          },
          cache = {
            base = vim.fn.stdpath("cache"),
            dirs = {},
            compression = {
              enabled = true,
            },
          },
          state = {
            base = vim.fn.stdpath("state"),
            dirs = {},
            compression = {
              enabled = true,
            },
          },
        },
      },
      -- Plugin log related configuration
      log = {
        level = "info",
      },
    },
  },
}
