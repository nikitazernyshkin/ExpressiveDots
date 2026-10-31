local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- --- Системные настройки для Hyprland/Wayland ---
config.front_end = "OpenGL"
config.enable_wayland = true
config.window_decorations = "NONE"
config.max_fps = 30

-- --- Настройки интерфейса ---
config.enable_tab_bar = true
config.scrollback_lines = 5000
config.default_cursor_style = 'BlinkingBar'
config.animation_fps = 60
config.cursor_blink_ease_in = 'EaseIn'
config.cursor_blink_ease_out = 'EaseOut'
config.cursor_blink_rate = 500

config.font = wezterm.font 'RobotoMono Nerd Font'
config.font_size = 12
config.check_for_updates = false

-- --- Цветовая схема ---
config.colors = require 'modules.colors'

-- --- Подключение ваших локальных модулей ---
require('modules.keys').apply(config)
require('modules.mouse').apply(config)
require('modules.appearance').apply(config)
--require('modules.plugins').apply(config)

return config
