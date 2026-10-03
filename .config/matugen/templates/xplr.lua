-- Корректный шаблон xplr согласно официальной спецификации
local xplr = xplr

local function rgb(r, g, b)
  return { Rgb = { r, g, b } }
end

-- Цвета из Material You палитры Matugen
local primary_fg = rgb({{colors.primary.default.red}}, {{colors.primary.default.green}}, {{colors.primary.default.blue}})
local on_surface_fg = rgb({{colors.on_surface.default.red}}, {{colors.on_surface.default.green}}, {{colors.on_surface.default.blue}})
local on_primary_fg = rgb({{colors.on_primary.default.red}}, {{colors.on_primary.default.green}}, {{colors.on_primary.default.blue}})

-- 1. Дефолтный стиль текста в таблице проводника
xplr.config.general.table.row.style = {
  fg = on_surface_fg
}

-- 2. Правильное поле для строки под курсором (Focus Selection UI)
xplr.config.general.focus_selection_ui = {
  style = {
    bg = primary_fg,
    fg = on_primary_fg
  }
}
