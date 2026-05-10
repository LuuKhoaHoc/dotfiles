#!/bin/bash
# Script kiểm tra tính tương thích của hệ thống dual-shell

echo "=== Kiểm tra tính tương thích hệ thống dual-shell ==="
echo ""

# Kiểm tra các package cần thiết
echo "1. Kiểm tra các package cần thiết:"
echo "================================"

# Kiểm tra Hyprland
if command -v hyprctl &> /dev/null; then
    echo "✅ Hyprland: $(hyprctl version | head -n 1)"
else
    echo "❌ Hyprland: Chưa cài đặt"
fi

# Kiểm tra Waybar
if command -v waybar &> /dev/null; then
    echo "✅ Waybar: $(waybar --version 2>&1 | head -n 1)"
else
    echo "❌ Waybar: Chưa cài đặt"
fi

# Kiểm tra Quickshell
if command -v quickshell &> /dev/null; then
    echo "✅ Quickshell: Đã cài đặt"
else
    echo "❌ Quickshell: Chưa cài đặt"
fi

# Kiểm tra Kitty
if command -v kitty &> /dev/null; then
    echo "✅ Kitty: $(kitty --version 2>&1 | head -n 1)"
else
    echo "❌ Kitty: Chưa cài đặt"
fi

# Kiểm tra Foot
if command -v foot &> /dev/null; then
    echo "✅ Foot: $(foot --version 2>&1 | head -n 1)"
else
    echo "❌ Foot: Chưa cài đặt"
fi

# Kiểm tra Zsh
if command -v zsh &> /dev/null; then
    echo "✅ Zsh: $(zsh --version 2>&1)"
else
    echo "❌ Zsh: Chưa cài đặt"
fi

# Kiểm tra Fish
if command -v fish &> /dev/null; then
    echo "✅ Fish: $(fish --version 2>&1)"
else
    echo "❌ Fish: Chưa cài đặt"
fi

# Kiểm tra Starship
if command -v starship &> /dev/null; then
    echo "✅ Starship: $(starship --version 2>&1 | head -n 1)"
else
    echo "❌ Starship: Chưa cài đặt"
fi

echo ""
echo "2. Kiểm tra cấu hình:"
echo "====================="

# Kiểm tra file cấu hình
CONFIG_FILES=(
    "$HOME/.config/hypr/hyprland.conf"
    "$HOME/.config/waybar/config"
    "$HOME/.config/kitty/kitty.conf"
    "$HOME/.config/foot/foot.ini"
    "$HOME/.config/fish/config.fish"
    "$HOME/.config/starship.toml"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $(basename $file): Tồn tại"
    else
        echo "❌ $(basename $file): Không tìm thấy"
    fi
done

echo ""
echo "3. Kiểm tra script chuyển đổi:"
echo "=============================="

# Kiểm tra script chuyển đổi
SCRIPTS=(
    "$HOME/Dev-Work/dotfiles/scripts/switch_to_caelestia.sh"
    "$HOME/Dev-Work/dotfiles/scripts/switch_back_waybar.sh"
    "$HOME/Dev-Work/dotfiles/hypr/scripts/switch-shell.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "✅ $(basename $script): Tồn tại"
        if [ -x "$script" ]; then
            echo "   └── Có quyền thực thi"
        else
            echo "   └── Không có quyền thực thi"
        fi
    else
        echo "❌ $(basename $script): Không tìm thấy"
    fi
done

echo ""
echo "4. Kiểm tra biến môi trường:"
echo "============================"

# Kiểm tra biến môi trường hiện tại
echo "HYPRLAND_SHELL: ${HYPRLAND_SHELL:-Chưa thiết lập}"
echo "TERMINAL: ${TERMINAL:-Chưa thiết lập}"
echo "SHELL hiện tại: $SHELL"

echo ""
echo "5. Kiểm tra animation config:"
echo "=============================="

# Kiểm tra animation config từ caelestia
if [ -f "$HOME/Dev-Work/dotfiles/hypr/animations/Caelestia.conf" ]; then
    echo "✅ Caelestia animation: Đã tạo"
else
    echo "❌ Caelestia animation: Chưa tạo"
fi

echo ""
echo "=== Kết thúc kiểm tra ==="