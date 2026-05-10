#!/bin/bash
# Script để switch lại về Waybar/AGS với terminal kitty + zsh
# Sử dụng biến môi trường HYPRLAND_SHELL

echo "=== Switching back to Waybar/AGS (kitty + zsh) ==="

# Bước 1: Thiết lập biến môi trường HYPRLAND_SHELL
export HYPRLAND_SHELL=waybar

# Bước 2: Tắt Quickshell
echo "Stopping Quickshell..."
killall quickshell 2>/dev/null

# Bước 3: Thay đổi terminal mặc định về kitty
echo "Setting default terminal to kitty..."
export TERMINAL=kitty

# Cập nhật trong fish config
FISH_CONFIG="$HOME/.config/fish/config.fish"
if [ -f "$FISH_CONFIG" ]; then
    # Xóa dòng set -gx TERMINAL cũ nếu có
    sed -i '/set -gx TERMINAL/d' "$FISH_CONFIG"
    echo 'set -gx TERMINAL kitty' >> "$FISH_CONFIG"
fi

# Cập nhật trong zshrc
ZSH_CONFIG="$HOME/.zshrc"
if [ -f "$ZSH_CONFIG" ]; then
    sed -i '/export TERMINAL=/d' "$ZSH_CONFIG"
    echo 'export TERMINAL=kitty' >> "$ZSH_CONFIG"
fi

# Bước 4: Thay đổi shell mặc định về zsh
echo "Setting default shell to zsh..."
# Kiểm tra xem zsh đã là shell mặc định chưa
if [ "$SHELL" != "/usr/bin/zsh" ]; then
    echo "Changing default shell to zsh..."
    chsh -s /usr/bin/zsh
fi

# Bước 5: Start lại Waybar và AGS
echo "Starting Waybar and AGS..."
waybar &
# ags & # AGS v3 incompatible with old config

echo ""
echo "✅ Done! Waybar/AGS is now running with kitty + zsh."