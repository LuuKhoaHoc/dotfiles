# Neovim Performance Guide

## Hiện tượng lag trong Neovim

Khi dùng Neovim với nhiều LSP servers, bạn có thể gặp phải:
- **Memory leak**: LSP servers tích lũy memory không giải phóng
- **LSP exhaustion**: Quá nhiều LSP chạy cùng lúc
- **Slowdown**: Neovim phản hồi chậm sau thời gian dài sử dụng

## Các lệnh hữu ích đã được thêm

### Kiểm tra & Debug
```vim
:Memory          " Hiển thị bộ nhớ đang dùng
:LspStatus       " Hiển thị LSP nào đang chạy
:GC              " Chạy garbage collection thủ công
```

### Quản lý LSP
```vim
:LspStopAll      " Dừng tất cả LSP (khi bị lag nặng)
:LspRestartAll   " Restart tất cả LSP
```

### Toggle features (đã có sẵn từ Snacks)
```vim
<leader>ud       " Toggle diagnostics
<leader>uT       " Toggle Treesitter
<leader>uh       " Toggle inlay hints
<leader>ug       " Toggle indent guides
```

## Các optimizations đã áp dụng

### 1. Automatic Garbage Collection
- Chạy GC mỗi 1000ms
- Giảm memory accumulation

### 2. LSP Auto-cleanup
- Tự động stop LSP khi đóng buffer cuối cùng của filetype
- Không stop các LSP quan trọng (lua_ls, json)
- Delay 5 giây trước khi stop để tránh stop/start liên tục

### 3. Reduced Diagnostics
- Disable virtual_text (chỉ dùng signs)
- Giới hạn max_line_length = 500
- Chỉ hiển thị diagnostics khi cần

### 4. Disabled Unused Features
- Ruby provider
- Perl provider  
- Node provider
- netrw (dùng snacks explorer thay thế)

## Tips để tránh lag

### 1. Đóng buffer không dùng
```vim
:bd              " Đóng buffer hiện tại
:bufdo bd        " Đóng tất cả buffers (cẩn thận!)
```

### 2. Dùng `:LspStopAll` khi cần
Khi thấy Neovim chậm, chạy:
```vim
:LspStopAll
```
Sau đó mở lại file cần edit, LSP sẽ tự động start lại.

### 3. Giới hạn filetypes dùng LSP nặng
Với các file chỉ xem không edit, có thể disable LSP:
```vim
" Trong config của bạn
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "largefile", "log" },
  callback = function()
    vim.lsp.stop_client(vim.lsp.get_clients({ bufnr = 0 }))
  end,
})
```

### 4. Dùng `:Memory` để monitor
```vim
:Memory  " Kiểm tra memory usage
```
Nếu > 500MB, nên chạy `:GC` hoặc restart Neovim.

### 5. Tránh mở quá nhiều files cùng lúc
- Dùng `:buffers` để xem buffers đang mở
- Đóng buffers không cần thiết

## So với VS Code

| Aspect | Neovim | VS Code |
|--------|--------|---------|
| Startup | ~50ms | ~2000ms |
| Memory (idle) | ~50MB | ~500MB |
| Memory (with LSP) | ~200-500MB | ~1-2GB |
| Customization | Cao | Trung bình |
| Performance degradation | Có (cần quản lý) | Ít hơn (nhưng nặng hơn) |

**Kết luận**: Neovim vẫn nhẹ hơn VS Code nhiều, nhưng cần quản lý LSP đúng cách.

## Troubleshooting

### Lag sau 30 phút coding
```vim
:GC
:LspStopAll
```
Sau đó mở lại file cần edit.

### Memory > 1GB
Restart Neovim. Dùng session để restore:
```vim
:SessionSave     " Trước khi thoát
:SessionLoad     " Khi vào lại
```

### LSP không hoạt động sau khi restart
```vim
:LspRestart      " Restart LSP cho buffer hiện tại
:LspRestartAll   " Restart tất cả LSP
```

## Recommended workflow

1. **Morning**: Start Neovim, load session
2. **During day**: Close unused buffers, run `:GC` occasionally
3. **When laggy**: `:LspStopAll` + reopen file
4. **End day**: Save session, exit Neovim

This keeps Neovim running smoothly all day!
