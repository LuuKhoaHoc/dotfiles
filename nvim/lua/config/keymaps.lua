-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Mở terminal tích hợp
map("n", "<leader>t", ":ToggleTerm<CR>", opts)

-- Tìm kiếm tệp với Telescope
map("n", "<leader>ff", ":Telescope find_files<CR>", opts)
map("n", "<leader>fg", ":Telescope live_grep<CR>", opts)

-- Chọn tất cả
map("n", "<C-a>", "ggVG", opts)

-- Đóng buffer
map("n", "Q", ":bd<CR>", opts)
