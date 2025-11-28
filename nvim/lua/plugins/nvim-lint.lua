local Lsp = require "utils.lsp"

--- Check if eslint_d should be disabled (when biome.json exists)
---@return boolean
local function should_disable_eslint()
  local path = Lsp.biome_config_path()
  local is_nvim = path and string.match(path, "nvim")
  return path and not is_nvim
end

return {
  "mfussenegger/nvim-lint",
  event = "VeryLazy",
  opts = {
    linters_by_ft = {
      -- cspell: npm install -g cspell@latest
      -- codespell: ux tool install codespell
      ["*"] = { "cspell", "codespell" },
      -- oxlint: npm install -g oxlint@latest
      -- Note: eslint_d will be conditionally disabled when biome.json exists
      javascript = { "oxlint", "eslint_d" },
      typescript = { "oxlint", "eslint_d" },
      javascriptreact = { "oxlint", "eslint_d" },
      typescriptreact = { "oxlint", "eslint_d" },
      json = { "eslint_d" },
      jsonc = { "eslint_d" },
      css = { "eslint_d" },
      scss = { "eslint_d" },
      sass = { "eslint_d" },
      less = { "eslint_d" },
      postcss = { "eslint_d" },
    },
    linters = {
      eslint_d = {
        args = {
          "--no-warn-ignored", -- Ignore warnings, support Eslint 9
          "--format",
          "json",
          "--stdin",
          "--stdin-filename",
          function()
            return vim.api.nvim_buf_get_name(0)
          end,
        },
      },
    },
  },
  config = function(_, opts)
    local lint = require "lint"
    lint.linters_by_ft = opts.linters_by_ft

    -- Ignore issue with missing eslint config file
    lint.linters.eslint_d = require("lint.util").wrap(lint.linters.eslint_d, function(diagnostic)
      if diagnostic.message:find "Error: Could not find config file" then
        return nil
      end
      return diagnostic
    end)

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      callback = function()
        local names = lint._resolve_linter_by_ft(vim.bo.filetype)

        -- Create a copy of the names table to avoid modifying the original.
        names = vim.list_extend({}, names)

        -- Add fallback linters.
        if #names == 0 then
          vim.list_extend(names, lint.linters_by_ft["_"] or {})
        end

        -- Add global linters.
        vim.list_extend(names, lint.linters_by_ft["*"] or {})

        -- Filter out eslint_d when biome.json exists
        if should_disable_eslint() then
          names = vim.tbl_filter(function(name)
            return name ~= "eslint_d"
          end, names)
        end

        -- Run linters.
        if #names > 0 then
          -- Check the if the linter is available, otherwise it will throw an error.
          for _, name in ipairs(names) do
            local cmd = vim.fn.executable(name)
            if cmd == 0 then
              vim.notify("Linter " .. name .. " is not available", vim.log.levels.INFO)
              return
            else
              -- Run the linter
              lint.try_lint(name)
            end
          end
        end
      end,
    })
  end,
}
