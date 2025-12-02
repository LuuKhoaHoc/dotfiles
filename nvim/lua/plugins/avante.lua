return {
  -- Disable copilot
  -- {
  --   "github/copilot.vim",
  --   enabled = false,
  -- },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    enabled = false,
  },
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false, -- set this if you want to always pull the latest change
    opts = {
      providers = {
        gemini = {
          model = "gemini-2.5-pro",
        },
        copilot = {
          model = "gpt-4.1-2025-04-14"
        }
      },
      hints = { enabled = true },
    },
    config = function()
      require('avante').setup({
        override_prompt_dir = vim.fn.expand("~/.config/nvim/avante_prompts"),
      })
    end,
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "saghen/blink.compat",
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
    cond = function() return not vim.g.vscode end,
    init = function()
      -- Perplexity Search Command
      vim.api.nvim_create_user_command("Perplexity", function(opts)
        local query = opts.args
        if query == "" then
          -- Try to get visual selection
          local mode = vim.api.nvim_get_mode().mode
          if mode == "v" or mode == "V" then
            local start_pos = vim.fn.getpos("v")
            local end_pos = vim.fn.getpos(".")
            -- This is a simplified selection retrieval, might need more robust logic for visual block etc.
            -- For now, let's just prompt if empty or use word under cursor
            query = vim.fn.expand("<cword>")
          else
            query = vim.fn.input("Perplexity Search: ")
          end
        end

        if query ~= "" then
          local url = "https://www.perplexity.ai/search?q=" .. vim.fn.escape(query, "")
          -- Open URL (cross-platform)
          local open_cmd
          if vim.fn.has("mac") == 1 then
            open_cmd = "open"
          elseif vim.fn.has("unix") == 1 then
            open_cmd = "xdg-open"
          elseif vim.fn.has("win32") == 1 then
            open_cmd = "start"
          end

          if open_cmd then
            vim.fn.jobstart({ open_cmd, url }, { detach = true })
          else
            vim.notify("Could not determine how to open browser", vim.log.levels.ERROR)
          end
        end
      end, { nargs = "*", range = true })
    end,
  },
}
