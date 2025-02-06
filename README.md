# 🛠 Dotfiles của tôi

Bộ cấu hình cá nhân cho môi trường phát triển (Neovim, terminal, tools...).  
*"Một developer hạnh phúc cần một config chuẩn chỉnh!"* ✨

![Neovim Preview](https://i.imgur.com/your-image-link.png) *(Optional: Ảnh chụp màn hình Neovim của bạn)*

## 📦 Cài đặt nhanh

**Yêu cầu**: Git, GNU Stow (cho quản lý symlink), Neovim ≥ 0.9

```bash
git clone https://github.com/username/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Dùng stow để tạo symlink (ví dụ cho nvim và zsh)
stow nvim       # Cấu hình Neovim sẽ ở ~/.config/nvim
stow zsh        # Cấu hình Zsh sẽ ở ~/.zshrc



``` Cấu trúc thư mục
.dotfiles/
├── nvim/               # Cấu hình Neovim (Lua)
│   ├── init.lua
│   └── lua/           # Custom modules
├── zsh/
│   ├── .zshrc         # Main config
│   └── functions/     # Custom functions
├── tmux/
│   └── .tmux.conf     # Tmux config
├── git/
│   └── .gitconfig     # Git aliases & settings
└── wezterm/           # (Optional) WezTerm config
