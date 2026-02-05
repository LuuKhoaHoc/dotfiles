local Lsp = require "utils.lsp"

local home = vim.fn.expand "~"
local odoo_ls_path = home .. "/.local/share/nvim/odoo/odoo_ls_server"
local server_path = vim.fn.executable(odoo_ls_path) == 1 and odoo_ls_path or "odoo-lsp"

return {
  cmd = { server_path },
  on_attach = Lsp.on_attach,
  filetypes = { "javascript", "xml", "python" },
  root_markers = { ".odoo_lsp", ".odoo_lsp.json", ".odoo_modules", "odoo.conf", "odools.toml" },
  settings = {
    odoo = {
      autoRefresh = true,
      autoRefreshDelay = 3000,
      diagMissingImportLevel = "hint",
    },
  },
}
