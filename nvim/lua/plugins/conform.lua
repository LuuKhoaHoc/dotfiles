local Lsp = require "utils.lsp"

---Run the first available formatter followed by more formatters
---@param bufnr integer
---@param ... string
---@return string
local function first(bufnr, ...)
  local conform = require "conform"
  for i = 1, select("#", ...) do
    local formatter = select(i, ...)
    if conform.get_formatter_info(formatter, bufnr).available then
      return formatter
    end
  end
  return select(1, ...)
end

return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    { "<leader>cn", "<cmd>ConformInfo<cr>", desc = "Conform Info" },
  },
  opts = {
    -- Define your formatters
    formatters_by_ft = {
      lua = { "stylua" },
      hurl = { "hurlfmt" },
      -- Conform will run multiple formatters sequentially
      go = { "goimports", "gofmt" },
      -- rustfmt is installed via rustup component add rustfmt
      rust = { "rustfmt" },
      -- Install Ruff globally.
      -- uv tool install ruff@latest
      python = function(bufnr)
        if require("conform").get_formatter_info("ruff_format", bufnr).available then
          return { "ruff_format" }
        else
          return { "isort", "black" }
        end
      end,
      -- Install prettier globally.
      -- npm install -g prettier@latest
      -- Install dprint globally.
      ["json"] = { "biome", "dprint", stop_after_first = true },
      ["markdown"] = { "prettierd", "prettier", "dprint", stop_after_first = true },
      ["markdown.mdx"] = { "prettierd", "prettier", "dprint", stop_after_first = true },
      ["javascript"] = function(bufnr)
        -- Ưu tiên prettier nếu có .prettierrc trong project
        local has_prettier_config = vim.fn.filereadable(".prettierrc") == 1 or 
                                   vim.fn.filereadable(".prettierrc.json") == 1 or
                                   vim.fn.filereadable("prettier.config.js") == 1
        if has_prettier_config then
          return { "prettier", "biome", "deno_fmt", stop_after_first = true }
        end
        return { "biome", "deno_fmt", "prettier", stop_after_first = true }
      end,
      ["javascriptreact"] = function(bufnr)
        local has_prettier_config = vim.fn.filereadable(".prettierrc") == 1 or 
                                   vim.fn.filereadable(".prettierrc.json") == 1 or
                                   vim.fn.filereadable("prettier.config.js") == 1
        if has_prettier_config then
          return { "rustywind", "prettier", "biome", "deno_fmt", stop_after_first = true }
        end
        return { "rustywind", first(bufnr, "biome", "deno_fmt", "prettier", "dprint") }
      end,
      ["typescript"] = function(bufnr)
        local has_prettier_config = vim.fn.filereadable(".prettierrc") == 1 or 
                                   vim.fn.filereadable(".prettierrc.json") == 1 or
                                   vim.fn.filereadable("prettier.config.js") == 1
        if has_prettier_config then
          return { "prettier", "biome", "deno_fmt", stop_after_first = true }
        end
        return { "biome", "deno_fmt", "prettier", stop_after_first = true }
      end,
      ["typescriptreact"] = function(bufnr)
        local has_prettier_config = vim.fn.filereadable(".prettierrc") == 1 or 
                                   vim.fn.filereadable(".prettierrc.json") == 1 or
                                   vim.fn.filereadable("prettier.config.js") == 1
        if has_prettier_config then
          return { "rustywind", "prettier", "biome", "deno_fmt", stop_after_first = true }
        end
        return { "rustywind", first(bufnr, "biome", "deno_fmt", "prettier", "dprint") }
      end,
      ["svelte"] = function(bufnr)
        return { "rustywind", first(bufnr, "biome", "deno_fmt", "prettierd", "prettier", "dprint") }
      end,
    },
    formatters = {
      biome = {
        condition = function()
          local path = Lsp.biome_config_path()
          -- Skip if biome.json is in nvim
          local is_nvim = path and string.match(path, "nvim")

          if path and not is_nvim then
            return true
          end

          return false
        end,
      },
      deno_fmt = {
        condition = function()
          return Lsp.deno_config_exist()
        end,
      },
      dprint = {
        condition = function()
          return Lsp.dprint_config_exist()
        end,
      },
      prettier = {
        condition = function()
          local path = Lsp.biome_config_path()
          -- Skip if biome.json is in nvim
          local is_nvim = path and string.match(path, "nvim")

          if path and not is_nvim then
            return false
          end

          return true
        end,
      },
      prettierd = {
        condition = function()
          local path = Lsp.biome_config_path()
          -- Skip if biome.json is in nvim
          local is_nvim = path and string.match(path, "nvim")

          if path and not is_nvim then
            return false
          end

          return true
        end,
      },
    },

    -- Set default options
    default_format_opts = {
      lsp_format = "fallback",
    },
    -- Set up format-on-save
    format_on_save = { lsp_format = "fallback", timeout_ms = 500 },
  },
  init = function()
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
  end,
}
