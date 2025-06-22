# 🎨 Rofi Theme System for DWM

Hệ thống quản lý theme rofi hoàn chỉnh cho DWM với clipboard manager và nhiều tùy chọn theme.

## 📦 Các File Đã Tạo

```
📁 chadwm/
├── 🎨 dracula-rofi.rasi          # Theme Dracula tùy chỉnh cho rofi
├── 🔧 rofi-theme-manager.sh      # Script quản lý theme
├── 🚀 setup-rofi-themes.sh       # Script cài đặt tự động
├── 📋 clipboard-manager.sh       # Script clipboard manager (nếu có)
├── ⚙️ config.def.h               # Config DWM đã cập nhật
├── 📖 ROFI_THEMES_SETUP.md       # Hướng dẫn chi tiết
└── 📖 DWM_KEYBINDINGS_GUIDE.md   # Hướng dẫn keybindings
```

## 🚀 Cài Đặt Nhanh

```bash
# 1. Chạy script cài đặt tự động
chmod +x setup-rofi-themes.sh
./setup-rofi-themes.sh

# 2. Cài đặt DWM
sudo make install

# 3. Restart DWM
# Nhấn Super + Shift + R
```

## 🎯 Tính Năng

### ✨ Theme System

- **Custom Dracula Theme** - Phù hợp hoàn toàn với DWM Dracula
- **34 System Themes** - Từ `/usr/share/rofi/themes/`
- **Auto Theme Detection** - Tự động tạo theme phù hợp với DWM theme
- **Theme Manager** - Script quản lý theme thông minh

### ⌨️ Keybindings Mới

- `Super + D` - Application launcher với theme
- `Super + V` - Clipboard manager với theme matching

### 🛠️ Theme Manager Features

- Liệt kê tất cả theme có sẵn
- Test theme không ảnh hưởng config
- Thay đổi theme và auto-rebuild DWM
- Tạo theme mới dựa trên DWM theme
- Backup tự động trước khi thay đổi

## 📱 Cách Sử Dụng

### Xem Danh Sách Theme

```bash
./rofi-theme-manager.sh list
```

### Test Theme (Không Thay Đổi Config)

```bash
./rofi-theme-manager.sh test Arc-Dark
./rofi-theme-manager.sh test blue
./rofi-theme-manager.sh test android_notification
```

### Thay Đổi Theme

```bash
# Áp dụng theme và rebuild DWM
./rofi-theme-manager.sh set Arc-Dark
./rofi-theme-manager.sh set DarkBlue

# Reset về mặc định
./rofi-theme-manager.sh reset
```

### Tạo Theme Mới

```bash
# Tạo theme dựa trên DWM theme hiện tại
./rofi-theme-manager.sh create my-theme

# File my-theme.rasi sẽ được tạo để chỉnh sửa
```

## 🎨 Theme Recommendations

### 🌙 Dark Themes (Phù Hợp Theme Dark)

```bash
./rofi-theme-manager.sh set Arc-Dark        # Modern dark
./rofi-theme-manager.sh set DarkBlue        # Deep blue
./rofi-theme-manager.sh set c64             # Retro style
```

### 🌈 Colorful Themes

```bash
./rofi-theme-manager.sh set blue            # Bright blue
./rofi-theme-manager.sh set arthur          # Gradient
```

### 📱 Modern Themes

```bash
./rofi-theme-manager.sh set android_notification  # Android style
./rofi-theme-manager.sh set dmenu               # Minimalist
```

## 🎛️ Tùy Chỉnh Theme

### Chỉnh Sửa Theme Có Sẵn

```bash
# Copy theme để chỉnh sửa
cp /usr/share/rofi/themes/Arc-Dark.rasi my-custom.rasi

# Chỉnh sửa file
vim my-custom.rasi

# Áp dụng
./rofi-theme-manager.sh set my-custom
```

### Tạo Theme Từ Đầu

```bash
# Tạo base theme
./rofi-theme-manager.sh create awesome-theme

# Chỉnh sửa màu sắc trong awesome-theme.rasi
# Tìm section colors và thay đổi:
#   bg0: #your-bg-color;
#   fg0: #your-text-color;
#   blue: #your-accent-color;
```

## 🔧 Config Details

### DWM Config Changes

```c
// Application launcher với theme
{ MODKEY, XK_d, spawn, SHCMD("rofi -show drun -theme ./dracula-rofi.rasi") },

// Clipboard manager với theme
{ MODKEY, XK_v, spawn, SHCMD("rofi -modi \"clipboard:greenclip print\" -show clipboard -theme ./dracula-rofi.rasi") },
```

### Theme Variables (dracula-rofi.rasi)

```css
* {
  bg0: #21222c; /* Background chính */
  bg1: #282a36; /* Background thứ 2 */
  fg0: #f8f8f2; /* Text color */
  blue: #bd93f9; /* Accent color */
  /* ... thêm nhiều màu khác */
}
```

## 🚨 Troubleshooting

### Theme Không Load

```bash
# Kiểm tra file theme
ls -la *.rasi

# Test manual
rofi -show drun -theme ./dracula-rofi.rasi
```

### Build Lỗi

```bash
# Restore config backup
cp config.def.h.backup config.def.h
make clean && make
```

### Font Issues

```bash
# Cài font JetBrains Mono
sudo pacman -S ttf-jetbrains-mono nerd-fonts-jetbrains-mono  # Arch
sudo apt install fonts-jetbrains-mono                       # Ubuntu
```

## 📚 Documentation Files

- **[ROFI_THEMES_SETUP.md](ROFI_THEMES_SETUP.md)** - Hướng dẫn chi tiết theme system
- **[DWM_KEYBINDINGS_GUIDE.md](DWM_KEYBINDINGS_GUIDE.md)** - Hướng dẫn keybindings DWM

## 🔄 Workflow Example

```bash
# 1. Xem theme có sẵn
./rofi-theme-manager.sh list

# 2. Test một vài theme
./rofi-theme-manager.sh test Arc-Dark
./rofi-theme-manager.sh test blue

# 3. Chọn theme ưng ý
./rofi-theme-manager.sh set Arc-Dark

# 4. Install và restart DWM
sudo make install
# Super + Shift + R

# 5. Tạo theme riêng nếu muốn
./rofi-theme-manager.sh create my-perfect-theme
vim my-perfect-theme.rasi  # Chỉnh sửa
./rofi-theme-manager.sh set my-perfect-theme
```

## 🎊 Features Summary

### ✅ Đã Hoàn Thành

- ✅ Custom Dracula theme phù hợp DWM
- ✅ Theme manager script đầy đủ tính năng
- ✅ Auto-backup và recovery
- ✅ Keybinding integration
- ✅ Clipboard manager support
- ✅ Documentation đầy đủ

### 🚀 Có Thể Mở Rộng

- 🔄 Auto theme switching theo thời gian
- 🎨 Theme generator từ wallpaper
- 🔗 Integration với other applications
- 📱 Mobile-style themes

---

**Enjoy your beautiful rofi themes! 🎨✨**

_Nếu có vấn đề gì, check troubleshooting section hoặc restore backup config._
