local map = vim.keymap.set

local function in_git_repo()
  return vim.fn.isdirectory ".git" == 1
end

local function close_buffer()
  local ok, bufremove = pcall(require, "mini.bufremove")
  if ok then
    bufremove.delete(0, false)
    return
  end

  vim.cmd "bdelete"
end

_G.mini_git_cli = function(command, fallback)
  if not in_git_repo() then
    vim.notify(fallback or "Not a git repository", vim.log.levels.WARN)
    return
  end

  require("mini.pick").builtin.cli { command = command }
end

-- Better up/down
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })
map({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })

-- Go to different windows
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window", remap = true })
map("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window", remap = true })
map("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window", remap = true })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window", remap = true })

-- Resize window using <ctrl> arrow keys
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Move Lines
map("n", "<A-j>", "<cmd>execute 'move .+' . v:count1<cr>==", { desc = "Move Down" })
map("n", "<A-k>", "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = "Move Up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move Down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move Up" })
map("v", "<A-j>", ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = "Move Down" })
map("v", "<A-k>", ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = "Move Up" })

-- Goto
map("n", "gl", "$", { desc = "Go to end of line" })
map("n", "gh", "^", { desc = "Go to start of line" })

-- buffers
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "<S-q>", close_buffer, { desc = "Delete Buffer" })
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })

-- Clear search with <esc>
map({ "i", "n" }, "<esc>", function()
  vim.cmd "noh"
  if vim.api.nvim_get_mode().mode == "n" then
    local ok, mc = pcall(require, "multicursor-nvim")
    if ok then
      if not mc.cursorsEnabled() then
        mc.enableCursors()
      elseif mc.hasCursors() then
        mc.clearCursors()
      end
    end
  end
  return "<esc>"
end, { desc = "Escape and Clear hlsearch", expr = true })

-- Clear search, diff update and redraw
-- taken from runtime/lua/_editor.lua
map(
  "n",
  "<leader>ur",
  "<Cmd>nohlsearch<Bar>diffupdate<Bar>normal! <C-L><CR>",
  { desc = "Redraw / Clear hlsearch / Diff Update" }
)

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
map("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "Next Search Result" })
map("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
map("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
map("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "Prev Search Result" })
map("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev Search Result" })
map("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev Search Result" })

-- Add undo break-points
map("i", ",", ",<c-g>u")
map("i", ".", ".<c-g>u")
map("i", ";", ";<c-g>u")

-- save file
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

-- save file using leader
map("n", "<leader>fs", "<cmd>w<cr>", { desc = "Save File" })

--keywordprg
map("n", "<leader>K", "<cmd>norm! K<cr>", { desc = "Keywordprg" })

-- better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- commenting
map("n", "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Below" })
map("n", "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Above" })

-- lazy
map("n", "<leader>zz", "<cmd>Lazy<cr>", { desc = "Lazy" })

-- new file
map("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New File" })

-- location list
map("n", "<leader>xl", function()
  local success, err = pcall(vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 and vim.cmd.lclose or vim.cmd.lopen)
  if not success and err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end, { desc = "Location List" })
-- quickfix list
map("n", "<leader>xq", function()
  local success, err = pcall(vim.fn.getqflist({ winid = 0 }).winid ~= 0 and vim.cmd.cclose or vim.cmd.copen)
  if not success and err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end, { desc = "Quickfix List" })

map("n", "[q", vim.cmd.cprev, { desc = "Previous Quickfix" })
map("n", "]q", vim.cmd.cnext, { desc = "Next Quickfix" })

-- diagnostic
local diagnostic_goto = function(next, severity)
  severity = severity and vim.diagnostic.severity[severity] or nil
  return function()
    vim.diagnostic.jump { count = next and 1 or -1, float = true, severity = severity }
  end
end
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
map("n", "]d", diagnostic_goto(true), { desc = "Next Diagnostic" })
map("n", "[d", diagnostic_goto(false), { desc = "Prev Diagnostic" })
map("n", "]e", diagnostic_goto(true, "ERROR"), { desc = "Next Error" })
map("n", "[e", diagnostic_goto(false, "ERROR"), { desc = "Prev Error" })
map("n", "]w", diagnostic_goto(true, "WARN"), { desc = "Next Warning" })
map("n", "[w", diagnostic_goto(false, "WARN"), { desc = "Prev Warning" })

-- quit
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

-- highlights under cursor
map("n", "<leader>ui", vim.show_pos, { desc = "Inspect Pos" })
map("n", "<leader>uI", "<cmd>InspectTree<cr>", { desc = "Inspect Tree" })

-- Terminal Mappings
map("t", "<esc><esc>", "<c-\\><c-n>", { desc = "Enter Normal Mode" })
map("t", "<C-h>", "<cmd>wincmd h<cr>", { desc = "Go to Left Window" })
map("t", "<C-j>", "<cmd>wincmd j<cr>", { desc = "Go to Lower Window" })
map("t", "<C-k>", "<cmd>wincmd k<cr>", { desc = "Go to Upper Window" })
map("t", "<C-l>", "<cmd>wincmd l<cr>", { desc = "Go to Right Window" })
map("t", "<C-/>", "<cmd>close<cr>", { desc = "Hide Terminal" })
map("t", "<c-_>", "<cmd>close<cr>", { desc = "which_key_ignore" })

-- windows
map("n", "<leader>ww", "<C-W>p", { desc = "Other Window", remap = true })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete Window", remap = true })
map("n", "<leader>w-", "<C-W>s", { desc = "Split Window Below", remap = true })
map("n", "<leader>w|", "<C-W>v", { desc = "Split Window Right", remap = true })
map("n", "<leader>-", "<C-W>s", { desc = "Split Window Below", remap = true })
map("n", "<leader>|", "<C-W>v", { desc = "Split Window Right", remap = true })

-- tabs
map("n", "<leader><tab>l", "<cmd>tablast<cr>", { desc = "Last Tab" })
map("n", "<leader><tab>o", "<cmd>tabonly<cr>", { desc = "Close Other Tabs" })
map("n", "<leader><tab>f", "<cmd>tabfirst<cr>", { desc = "First Tab" })
map("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New Tab" })
map("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close Tab" })
map("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })

vim.api.nvim_create_user_command("FormatDisable", function(args)
  if args.bang then
    -- FormatDisable! will disable formatting just for this buffer
    vim.b.disable_autoformat = true
  else
    vim.g.disable_autoformat = true
  end
end, {
  desc = "Disable autoformat-on-save",
  bang = true,
})
vim.api.nvim_create_user_command("FormatEnable", function()
  vim.b.disable_autoformat = false
  vim.g.disable_autoformat = false
end, {
  desc = "Re-enable autoformat-on-save",
})

-- Define a global variable to enable/disable autoformat
local auto_format = true
map("n", "<leader>uf", function()
  auto_format = not auto_format
  if auto_format then
    vim.cmd "FormatEnable"
  else
    vim.cmd "FormatDisable"
  end
end, { desc = "Toggle Autoformat" })

-- ------------------------------------------------------------------------- }}}
-- {{{ Folding commands.

-- Author: Karl Yngve Lervåg
--    See: https://github.com/lervag/dotnvim

-- Close all fold except the current one.
map("n", "zv", "zMzvzz", {
  desc = "Close all folds except the current one",
})

-- Close current fold when open. Always open next fold.
map("n", "zj", "zcjzOzz", {
  desc = "Close current fold when open. Always open next fold.",
})

-- Close current fold when open. Always open previous fold.
map("n", "zk", "zckzOzz", {
  desc = "Close current fold when open. Always open previous fold.",
})

-- Refer [FAQ - Neovide](https://neovide.dev/faq.html#how-can-i-use-cmd-ccmd-v-to-copy-and-paste)
if vim.g.neovide then
  vim.keymap.set("n", "<D-s>", ":w<CR>") -- Save
  vim.keymap.set("v", "<D-c>", '"+y') -- Copy
  vim.keymap.set({ "n", "v" }, "<D-v>", '"+P') -- Paste normal and visual mode
  vim.keymap.set({ "i", "c" }, "<D-v>", "<C-R>+") -- Paste insert and command mode
  vim.keymap.set("t", "<D-v>", [[<C-\><C-N>"+P]]) -- Paste terminal mode  vim.keymap.set("n", "<D-s>", ":w<CR>") -- Save
end

-- Silent keymap option
local opts = { silent = true }

-- Better paste
-- remap "p" in visual mode to delete the highlighted text without overwriting your yanked/copied text, and then paste the content from the unnamed register.
map("v", "p", '"_dP', opts)

-- Copy whole file content to clipboard with C-c
map("n", "<C-c>", ":%y+<CR>", opts)

-- Select all text in buffer with Alt-a
map("n", "<A-a>", "ggVG", { noremap = true, silent = true, desc = "Select all" })

-- Smart expand/shrink selection (VS Code-like)
local selection_stack = {}

local function get_visual_range()
  local vpos = vim.fn.getpos "v"
  local cpos = vim.fn.getpos "."
  local s_row, s_col = vpos[2] - 1, vpos[3] - 1
  local e_row, e_col = cpos[2] - 1, cpos[3] - 1

  if s_row > e_row or (s_row == e_row and s_col > e_col) then
    s_row, e_row = e_row, s_row
    s_col, e_col = e_col, s_col
  end
  -- Treesitter is 0-indexed, and end is exclusive. 
  -- Visual selection end in Vim is inclusive, so we'll handle that in the selection logic.
  return s_row, s_col, e_row, e_col
end

local function ts_select(is_expand)
  local bufnr = vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then return end

  if not selection_stack[bufnr] then selection_stack[bufnr] = {} end
  local stack = selection_stack[bufnr]

  local mode = vim.fn.mode()
  if not is_expand then
    if #stack <= 1 then 
      -- If nothing to shrink, just exit visual mode
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
      return 
    end
    table.remove(stack)
    local r = stack[#stack]
    vim.api.nvim_win_set_cursor(0, { r[1] + 1, r[2] })
    vim.cmd "normal! o"
    vim.api.nvim_win_set_cursor(0, { r[3] + 1, math.max(0, r[4] - 1) })
    return
  end

  local s_row, s_col, e_row, e_col
  if mode:match("[vV\22]") then
    s_row, s_col, e_row, e_col = get_visual_range()
    -- We need to account for inclusive end in visual mode for Treesitter
    e_col = e_col + 1
  else
    local pos = vim.api.nvim_win_get_cursor(0)
    s_row, s_col, e_row, e_col = pos[1] - 1, pos[2], pos[1] - 1, pos[2] + 1
    selection_stack[bufnr] = {} -- Reset stack on fresh start
    stack = selection_stack[bufnr]
  end

  local root = parser:parse()[1]:root()
  -- Find the smallest named node that contains the range
  local node = root:named_descendant_for_range(s_row, s_col, e_row, e_col)
  if not node then return end

  local ns, nsc, ne, nec = node:range()
  
  -- If the node we found is exactly what we already have selected, go up
  while ns == s_row and nsc == s_col and ne == e_row and nec == e_col do
    local parent = node:parent()
    if not parent then break end
    node = parent
    ns, nsc, ne, nec = node:range()
  end

  if node then
    table.insert(stack, { ns, nsc, ne, nec })
    if not mode:match("[vV\22]") then vim.cmd "normal! v" end
    
    -- In Neovim visual mode, one end is 'anchor' and other is 'cursor'
    -- We set anchor first, then 'o' to move cursor to other end
    vim.api.nvim_win_set_cursor(0, { ns + 1, nsc })
    vim.cmd "normal! o"
    -- nec is exclusive, so we go to nec - 1
    vim.api.nvim_win_set_cursor(0, { ne + 1, math.max(0, nec - 1) })
  end
end

-- Clear stack when leaving visual mode
vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = "[vV\22]:n",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    selection_stack[bufnr] = nil
  end,
})

map("n", "<C-space>", function() ts_select(true) end, { desc = "Expand Selection" })
map("x", "<C-space>", function() ts_select(true) end, { desc = "Expand Selection" })
map("x", "<BS>", function() ts_select(false) end, { desc = "Shrink Selection" })

-- If you prefer Space instead of Alt:
-- map("v", "<Space>", ts_select_parent, { desc = "Expand Selection (Space)" })
-- map("v", "<S-Space>", ts_select_child, { desc = "Shrink Selection (Shift+Space)" })

-- Visual --
-- Stay in indent mode
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)

-- Easier access to beginning and end of lines
map("n", "<A-h>", "^", {
  desc = "Go to start of line",
  silent = true,
})
map("n", "<A-l>", "$", {
  desc = "Go to end of line",
  silent = true,
})

-- Move live up or down
-- moving
map("n", "<A-Down>", ":m .+1<CR>", opts)
map("n", "<A-Up>", ":m .-2<CR>", opts)
map("i", "<A-Down>", "<Esc>:m .+1<CR>==gi", opts)
map("i", "<A-Up>", "<Esc>:m .-2<CR>==gi", opts)
map("v", "<A-Down>", ":m '>+1<CR>gv=gv", opts)
map("v", "<A-Up>", ":m '<-2<CR>gv=gv", opts)

-- Fix Spell checking
map("n", "z0", "1z=", {
  desc = "Fix world under cursor",
})

-- Toggle wrap
map("n", "<leader>tw", "<cmd>set wrap!<CR>", {
  desc = "Toggle Wrap",
  silent = true,
})

-- Toggle spell
map("n", "<leader>ts", "<cmd>set spell!<CR>", {
  desc = "Toggle Spell",
  silent = true,
})

map(
  "n",
  "<leader>us",
  "<cmd>lua require('utils.cspell').add_word_to_c_spell_dictionary()<CR>",
  { noremap = true, silent = true, desc = "Add unknown to cspell dictionary" }
)
