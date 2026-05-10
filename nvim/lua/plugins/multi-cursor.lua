return {
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    config = function()
      local mc = require "multicursor-nvim"
      mc.setup()

      local map = vim.keymap.set

      -- Find next match (VSCode style but with Ctrl+Alt+d as requested)
      map({ "n", "v" }, "<C-M-d>", function()
        mc.matchAddCursor(1)
      end, { desc = "Add cursor to next match" })
    end,
  },
}
