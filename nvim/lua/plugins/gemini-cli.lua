-- Gemini CLI integration for Neovim
-- Requires: pip install gemini-cli (or npm install -g @anthropics/gemini-cli)
--
-- Usage:
--   • Toggle Gemini: <leader>Gg
--   • Ask Gemini: <leader>Ga
--   • Add current file: <leader>Gf

local mapping_key_prefix = "<leader>G"

return {
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { mapping_key_prefix, group = "Gemini CLI", mode = { "n", "v" } },
      },
    },
  },
  {
    "marcinjahn/gemini-cli.nvim",
    dependencies = {
      "folke/snacks.nvim", -- Required dependency
    },
    cmd = "Gemini",
    keys = {
      { mapping_key_prefix .. "g", "<cmd>Gemini toggle<cr>", desc = "Toggle Gemini CLI" },
      { mapping_key_prefix .. "a", "<cmd>Gemini ask<cr>", desc = "Ask Gemini", mode = { "n", "v" } },
      { mapping_key_prefix .. "f", "<cmd>Gemini add_file<cr>", desc = "Add current file" },
      { mapping_key_prefix .. "d", "<cmd>Gemini command diagnostics<cr>", desc = "Send diagnostics" },
      { mapping_key_prefix .. "h", "<cmd>Gemini health<cr>", desc = "Check health" },
    },
    config = true,
  },
}
