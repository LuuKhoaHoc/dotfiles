local wezterm = require("wezterm")
local config = wezterm.config_builder()
local brightness = 0.03

-- Xử lý đường dẫn đa nền tảng
local function get_home()
    return os.getenv("USERPROFILE") or os.getenv("HOME") or "C:\\Users\\khoahoc"
end

-- image setting
local home = get_home()
local background_folder = home .. "./dotfiles/wezterm/bg" -- Thư mục chứa ảnh từ GitHub
local function pick_random_background(folder)
    -- Sử dụng wezterm.glob thay vì ls để liệt kê file trên Windows
    local files = wezterm.glob(folder .. "\\*.{jpg,png,gif}")
    if #files > 0 then
        return files[math.random(#files)]
    else
        return nil
    end
end

config.window_background_image_hsb = {
    brightness = brightness,
    hue = 1.0,
    saturation = 0.8,
}

-- default background
local bg_image = home .. "./dotfiles/wezterm/bg.gif" -- Đường dẫn mặc định
if not wezterm.glob(bg_image) then
    bg_image = pick_random_background(background_folder) -- Nếu không tìm thấy, chọn ngẫu nhiên từ wezterm_bg
end

config.window_background_image = bg_image
-- end image setting

-- window setting
config.window_background_opacity = 0.90
config.win32_system_backdrop = "Acrylic" -- Tương đương macos_window_background_blur trên Windows
config.window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
}

config.color_scheme = "Tokyo Night"
config.font = wezterm.font("FiraCode Nerd Font Mono", {weight="DemiBold", stretch="Normal", style="Normal"})
config.font_size = 10

config.window_decorations = "RESIZE"
config.enable_tab_bar = true

config.window_frame = {
    border_left_width = "0.28cell",
    border_right_width = "0.28cell",
    border_bottom_height = "0.15cell",
    border_top_height = "0.15cell",
    border_left_color = "pink",
    border_right_color = "pink",
    border_bottom_color = "pink",
    border_top_color = "pink",
}

-- Đặt PowerShell 7 làm shell mặc định
config.default_prog = { "pwsh.exe", "-NoLogo" }

-- keys
config.keys = {
    {
        key = "b",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window)
            local new_bg = pick_random_background(background_folder)
            if new_bg then
                bg_image = new_bg
                window:set_config_overrides({
                    window_background_image = bg_image,
                })
                wezterm.log_info("New bg: " .. bg_image)
            else
                wezterm.log_error("Could not find bg image in " .. background_folder)
            end
        end),
    },
    {
        key = "L",
        mods = "CTRL|SHIFT",
        action = wezterm.action.OpenLinkAtMouseCursor,
    },
    {
        key = ">",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window)
            brightness = math.min(brightness + 0.01, 1.0)
            window:set_config_overrides({
                window_background_image_hsb = {
                    brightness = brightness,
                    hue = 1.0,
                    saturation = 0.8,
                },
                window_background_image = bg_image,
            })
        end),
    },
    {
        key = "<",
        mods = "CTRL|SHIFT",
        action = wezterm.action_callback(function(window)
            brightness = math.max(brightness - 0.01, 0.01)
            window:set_config_overrides({
                window_background_image_hsb = {
                    brightness = brightness,
                    hue = 1.0,
                    saturation = 0.8,
                },
                window_background_image = bg_image,
            })
        end),
    },
}

-- others
config.default_cursor_style = "BlinkingUnderline"
config.cursor_thickness = 2
config.max_fps = 120
config.enable_kitty_graphics = true -- Bật Kitty graphics protocol cho snacks.nvim

return config
