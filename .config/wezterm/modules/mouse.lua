-- Mouse bindings that preserve normal terminal text selection.
local wezterm = require 'wezterm'
local act = wezterm.action
local M = {}

function M.apply(config)
  config.mouse_bindings = {
    -- Middle-click closes the active tab, matching common browser behavior.
    {
      event = { Down = { streak = 1, button = 'Middle' } },
      mods = 'NONE',
      action = act.CloseCurrentTab { confirm = false },
    },
    -- Normal terminal text selection. Do not bind left-drag to MoveTabRelative:
    -- that steals the drag gesture from selection and does not drag a tab.
    {
      event = { Drag = { streak = 1, button = 'Left' } },
      mods = 'NONE',
      action = act.ExtendSelectionToMouseCursor 'Cell',
    },
    {
      event = { Down = { streak = 2, button = 'Left' } },
      mods = 'NONE',
      action = act.SelectTextAtMouseCursor 'Word',
    },
    {
      event = { Down = { streak = 3, button = 'Left' } },
      mods = 'NONE',
      action = act.SelectTextAtMouseCursor 'Line',
    },
    {
      event = { Down = { streak = 1, button = { WheelUp = 1 } } },
      mods = 'NONE',
      action = act.ScrollByLine(-3),
    },
    {
      event = { Down = { streak = 1, button = { WheelDown = 1 } } },
      mods = 'NONE',
      action = act.ScrollByLine(3),
    },
  }
end

return M
