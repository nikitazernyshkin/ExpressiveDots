-- Context menu and per-window settings for WezTerm.
-- WezTerm does not expose a native arbitrary right-click menu API, so this uses
-- its built-in InputSelector overlay. It works without plugins.
local wezterm = require 'wezterm'
local act = wezterm.action
local M = {}

local function get_overrides(window)
  return window:get_config_overrides() or {}
end

local function set_override(window, key, value)
  local overrides = get_overrides(window)
  overrides[key] = value
  window:set_config_overrides(overrides)
end

local function show_settings(window, pane)
  local choices = {
    { label = 'Увеличить шрифт  (+)', id = 'font_up' },
    { label = 'Уменьшить шрифт  (-)', id = 'font_down' },
    { label = 'Сбросить размер шрифта', id = 'font_reset' },
    { label = 'Переключить прозрачность окна', id = 'opacity' },
    { label = 'Показать / скрыть панель вкладок', id = 'tabbar' },
    { label = 'Перезагрузить конфигурацию', id = 'reload' },
    { label = 'Назад', id = 'back' },
  }

  window:perform_action(act.InputSelector {
    title = '⚙ Настройки WezTerm',
    fuzzy = false,
    choices = choices,
    action = wezterm.action_callback(function(inner_window, inner_pane, id)
      if not id or id == 'back' then
        return
      elseif id == 'font_up' then
        inner_window:perform_action(act.IncreaseFontSize, inner_pane)
      elseif id == 'font_down' then
        inner_window:perform_action(act.DecreaseFontSize, inner_pane)
      elseif id == 'font_reset' then
        local overrides = get_overrides(inner_window)
        overrides.font_size = nil
        inner_window:set_config_overrides(overrides)
      elseif id == 'opacity' then
        local overrides = get_overrides(inner_window)
        if overrides.window_background_opacity == nil then
          overrides.window_background_opacity = 0.88
        else
          overrides.window_background_opacity = nil
        end
        inner_window:set_config_overrides(overrides)
      elseif id == 'tabbar' then
        local overrides = get_overrides(inner_window)
        local currently_enabled = overrides.enable_tab_bar
        if currently_enabled == nil then currently_enabled = true end
        overrides.enable_tab_bar = not currently_enabled
        inner_window:set_config_overrides(overrides)
      elseif id == 'reload' then
        inner_window:perform_action(act.ReloadConfiguration, inner_pane)
      end
    end),
  }, pane)
end

local function show_context_menu(window, pane)
  window:perform_action(act.InputSelector {
    title = 'Терминал',
    fuzzy = false,
    choices = {
      { label = 'Копировать выделенное   Ctrl+Shift+C', id = 'copy' },
      { label = 'Вставить из буфера   Ctrl+Shift+V', id = 'paste' },
      { label = 'Очистить прокрутку', id = 'clear' },
      { label = 'Настройки  ⚙', id = 'settings' },
      { label = 'Перезагрузить конфигурацию', id = 'reload' },
    },
    action = wezterm.action_callback(function(inner_window, inner_pane, id)
      if id == 'copy' then
        inner_window:perform_action(act.CopyTo 'ClipboardAndPrimarySelection', inner_pane)
      elseif id == 'paste' then
        inner_window:perform_action(act.PasteFrom 'Clipboard', inner_pane)
      elseif id == 'clear' then
        inner_window:perform_action(act.ClearScrollback 'ScrollbackOnly', inner_pane)
      elseif id == 'settings' then
        show_settings(inner_window, inner_pane)
      elseif id == 'reload' then
        inner_window:perform_action(act.ReloadConfiguration, inner_pane)
      end
    end),
  }, pane)
end

function M.apply(config)
  -- Add, rather than replace, existing key bindings.
  config.keys = config.keys or {}
  table.insert(config.keys, {
    key = ',', mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      show_settings(window, pane)
    end),
  })

  config.mouse_bindings = config.mouse_bindings or {}
  table.insert(config.mouse_bindings, {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = wezterm.action_callback(function(window, pane)
      show_context_menu(window, pane)
    end),
  })
end

return M
