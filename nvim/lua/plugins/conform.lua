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
      -- Conform will run multiple formatters sequentially
      go = { "goimports", "gofumpt", "gofmt" },
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
      ["jsonc"] = { "biome", "dprint", stop_after_first = true },
      ["css"] = function(bufnr)
        if require("conform").get_formatter_info("eslint", bufnr).available then
          return { "eslint" }
        elseif require("conform").get_formatter_info("prettierd", bufnr).available then
          return { "prettierd" }
        else
          return { "prettier" }
        end
      end,
      ["scss"] = function(bufnr)
        if require("conform").get_formatter_info("eslint", bufnr).available then
          return { "eslint" }
        elseif require("conform").get_formatter_info("prettierd", bufnr).available then
          return { "prettierd" }
        else
          return { "prettier" }
        end
      end,
      ["sass"] = function(bufnr)
        if require("conform").get_formatter_info("eslint", bufnr).available then
          return { "eslint" }
        elseif require("conform").get_formatter_info("prettierd", bufnr).available then
          return { "prettierd" }
        else
          return { "prettier" }
        end
      end,
      ["less"] = function(bufnr)
        if require("conform").get_formatter_info("eslint", bufnr).available then
          return { "eslint" }
        elseif require("conform").get_formatter_info("prettierd", bufnr).available then
          return { "prettierd" }
        else
          return { "prettier" }
        end
      end,
      ["postcss"] = function(bufnr)
        if require("conform").get_formatter_info("eslint", bufnr).available then
          return { "eslint" }
        elseif require("conform").get_formatter_info("prettierd", bufnr).available then
          return { "prettierd" }
        else
          return { "prettier" }
        end
      end,
      ["markdown"] = { "prettierd", "prettier", "dprint", stop_after_first = true },
      ["markdown.mdx"] = { "prettierd", "prettier", "dprint", stop_after_first = true },
      ["javascript"] = { "biome", "eslint", "deno_fmt", "prettierd", "prettier", "dprint", stop_after_first = true },
      ["javascriptreact"] = function(bufnr)
        return { "rustywind", first(bufnr, "biome", "eslint", "deno_fmt", "prettierd", "prettier", "dprint") }
      end,
      ["typescript"] = { "biome", "eslint", "deno_fmt", "prettierd", "prettier", "dprint", stop_after_first = true },
      ["typescriptreact"] = function(bufnr)
        return { "rustywind", first(bufnr, "biome", "eslint", "deno_fmt", "prettierd", "prettier", "dprint") }
      end,
      ["svelte"] = function(bufnr)
        return { "rustywind", first(bufnr, "biome", "deno_fmt", "prettierd", "prettier", "dprint") }
      end,
    },
    formatters = {
      biome = {
        condition = function()
          local path = Lsp.biome_config_path()
          return path and not string.match(path, "nvim")
        end,
      },
      eslint = {
        condition = function()
          local path = Lsp.biome_config_path()
          local has_biome = path and not string.match(path, "nvim")
          return not has_biome and Lsp.eslint_config_exists()
        end,
        command = "eslint_d",
      },
      deno_fmt = {
        condition = Lsp.deno_config_exist,
      },
      dprint = {
        condition = Lsp.dprint_config_exist,
      },
      prettier = {
        condition = function()
          local path = Lsp.biome_config_path()
          local has_biome = path and not string.match(path, "nvim")
          return not has_biome and Lsp.prettier_config_exists()
        end,
      },
      prettierd = {
        condition = function()
          local path = Lsp.biome_config_path()
          local has_biome = path and not string.match(path, "nvim")
          return not has_biome and Lsp.prettier_config_exists()
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
