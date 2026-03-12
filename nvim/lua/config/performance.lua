-- Performance optimizations for Neovim
local M = {}

-- Garbage collection settings
M.gc_interval = 1000 -- Run GC every 1000ms
M.gc_pause = 1.3     -- Pause multiplier
M.gc_step_mul = 200  -- Step multiplier

function M.setup()
  -- Configure garbage collection
  vim.opt.updatetime = 200 -- Trigger CursorHold more frequently

  -- Setup automatic garbage collection
  local gc_timer = vim.uv.new_timer()
  if gc_timer then
    gc_timer:start(
      M.gc_interval,
      M.gc_interval,
      vim.schedule_wrap(function()
        collectgarbage "step"
      end)
    )
  end

  -- Disable unused providers
  vim.g.loaded_ruby_provider = 0
  vim.g.loaded_perl_provider = 0
  vim.g.loaded_node_provider = 0
  -- Keep python3 provider if needed for some plugins

  -- Disable netrw for faster startup
  vim.g.loaded_netrw = 1
  vim.g.loaded_netrwPlugin = 1

  -- Reduce LSP memory usage
  vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
    vim.lsp.diagnostic.on_publish_diagnostics,
    {
      underline = true,
      virtual_text = false, -- Disable virtual text by default
      signs = true,
      update_in_insert = false,
    }
  )

  -- Configure LSP clients to be more memory efficient
  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then
        return
      end

      -- Disable features you don't need to save memory
      -- Uncomment if you don't need these features:
      -- client.server_capabilities.semanticTokensProvider = nil
      -- client.server_capabilities.documentFormattingProvider = nil
      -- client.server_capabilities.documentRangeFormattingProvider = nil
      -- client.server_capabilities.colorProvider = nil
    end,
  })

  -- Auto-close LSP when last buffer of a filetype is closed
  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local clients = vim.lsp.get_clients { bufnr = bufnr }

      if #clients > 0 then
        local ft = vim.bo.filetype
        local buf_count = 0
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.bo[buf].filetype == ft and vim.api.nvim_buf_is_loaded(buf) then
            buf_count = buf_count + 1
          end
        end

        -- If this is the last buffer of this type, stop LSP after delay
        if buf_count == 1 then
          vim.defer_fn(function()
            -- Check again if still the last buffer
            local current_count = 0
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if vim.bo[buf].filetype == ft and vim.api.nvim_buf_is_loaded(buf) then
                current_count = current_count + 1
              end
            end

            if current_count == 1 then
              for _, client in ipairs(clients) do
                -- Don't stop essential LSPs
                if not vim.tbl_contains({ "lua_ls", "json" }, client.name) then
                  vim.lsp.stop_client(client.id)
                  break
                end
              end
            end
          end, 5000) -- Wait 5 seconds before stopping
        end
      end
    end,
  })

  -- Limit diagnostic count to prevent slowdowns
  vim.diagnostic.config {
    underline = true,
    update_in_insert = false,
    virtual_text = {
      spacing = 4,
      source = "if_many",
      prefix = "●",
    },
    severity_sort = true,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = " ",
        [vim.diagnostic.severity.WARN] = " ",
        [vim.diagnostic.severity.HINT] = " ",
        [vim.diagnostic.severity.INFO] = " ",
      },
    },
  }

  -- Performance commands
  vim.api.nvim_create_user_command("LspStopAll", function()
    local clients = vim.lsp.get_clients()
    for _, client in ipairs(clients) do
      vim.lsp.stop_client(client.id)
    end
    vim.notify("Stopped all LSP clients", vim.log.levels.INFO)
  end, { desc = "Stop all LSP clients" })

  vim.api.nvim_create_user_command("LspRestartAll", function()
    local clients = vim.lsp.get_clients()
    local filetypes = {}
    for _, client in ipairs(clients) do
      vim.lsp.stop_client(client.id)
    end
    -- Re-enable LSP for current buffer
    vim.defer_fn(function()
      vim.cmd("LspRestart")
      vim.notify("Restarted LSP clients", vim.log.levels.INFO)
    end, 500)
  end, { desc = "Restart all LSP clients" })

  vim.api.nvim_create_user_command("GC", function()
    collectgarbage "collect"
    vim.notify("Garbage collection completed", vim.log.levels.INFO)
  end, { desc = "Run garbage collection" })

  -- Show memory usage
  vim.api.nvim_create_user_command("Memory", function()
    local stats = collectgarbage "count"
    vim.notify(string.format("Memory usage: %.2f KB", stats), vim.log.levels.INFO)
  end, { desc = "Show memory usage" })

  -- Show LSP status
  vim.api.nvim_create_user_command("LspStatus", function()
    local clients = vim.lsp.get_clients()
    if #clients == 0 then
      vim.notify("No active LSP clients", vim.log.levels.INFO)
      return
    end

    local lines = { "Active LSP clients:" }
    for _, client in ipairs(clients) do
      local buffers = vim.lsp.get_buffers_by_client_id(client.id)
      table.insert(lines, string.format("  - %s (%d buffers)", client.name, #buffers))
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, { desc = "Show LSP status" })
end

return M
