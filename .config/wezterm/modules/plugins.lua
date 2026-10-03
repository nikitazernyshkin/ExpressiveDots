-- modules/plugins.lua
local wezterm = require 'wezterm'
local M = {}

function M.apply(config)
  -- Загружаем живой и популярный плагин для кастомизации таб-бара
  local bar_plugin = wezterm.plugin.require("https://github.com/adriankarlen/bar.wezterm")

  -- Применяем его к конфигу
  bar_plugin.apply_to_config(config, {
    position = "top",
    max_width = 32,
    -- Отключаем встроенные палитры плагина, чтобы он слушался наших настроек цвета
    custom_colors = true
  })
end

return M
