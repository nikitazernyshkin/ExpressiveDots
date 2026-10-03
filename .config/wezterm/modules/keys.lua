local wezterm = require 'wezterm'
local M = {}

function M.apply(config)
  config.keys = {
    { key = 't', mods = 'CTRL', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
    { key = 'w', mods = 'CTRL', action = wezterm.action.CloseCurrentTab { confirm = false } },
    { key = 'p', mods = 'CTRL|SHIFT', action = wezterm.action.EmitEvent 'toggle-tab-pin' },
    { key = 'Tab', mods = 'CTRL', action = wezterm.action.ActivateTabRelative(1) },
    { key = 'Tab', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateTabRelative(-1) },
    { key = '1', mods = 'CTRL', action = wezterm.action.ActivateTab(0) },
    { key = '2', mods = 'CTRL', action = wezterm.action.ActivateTab(1) },
    { key = '3', mods = 'CTRL', action = wezterm.action.ActivateTab(2) },
    { key = '4', mods = 'CTRL', action = wezterm.action.ActivateTab(3) },
    { key = '5', mods = 'CTRL', action = wezterm.action.ActivateTab(4) },
    { key = '6', mods = 'CTRL', action = wezterm.action.ActivateTab(5) },
    { key = '7', mods = 'CTRL', action = wezterm.action.ActivateTab(6) },
    { key = '8', mods = 'CTRL', action = wezterm.action.ActivateTab(7) },
    { key = '9', mods = 'CTRL', action = wezterm.action.ActivateTab(-1) },
    { key = 'PageUp', mods = 'CTRL|SHIFT', action = wezterm.action.MoveTabRelative(-1) },
    { key = 'PageDown', mods = 'CTRL|SHIFT', action = wezterm.action.MoveTabRelative(1) },
    { key = 'LeftArrow', mods = 'ALT|SHIFT', action = wezterm.action.MoveTabRelative(-1) },
    { key = 'RightArrow', mods = 'ALT|SHIFT', action = wezterm.action.MoveTabRelative(1) },
    { key = 'c', mods = 'CTRL|SHIFT', action = wezterm.action.CopyTo 'ClipboardAndPrimarySelection' },
    { key = 'v', mods = 'CTRL|SHIFT', action = wezterm.action.PasteFrom 'Clipboard' },
    { key = 'V', mods = 'ALT', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = 'H', mods = 'ALT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'W', mods = 'ALT', action = wezterm.action.CloseCurrentPane { confirm = true } },
    { key = 'F', mods = 'ALT', action = wezterm.action.TogglePaneZoomState },
    { key = 'LeftArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Left' },
    { key = 'RightArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Right' },
    { key = 'UpArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Up' },
    { key = 'DownArrow', mods = 'ALT', action = wezterm.action.ActivatePaneDirection 'Down' },
  }
end

return M
