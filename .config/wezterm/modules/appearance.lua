-- Chrome-inspired tabs for WezTerm.
-- Pin/unpin the active tab with Ctrl+Shift+P. Tabs start unpinned.
local wezterm = require 'wezterm'
local M = {}
local pinned_tabs = {}

local function process_icon(process_name)
  process_name = (process_name or ''):gsub('^.*/', ''):lower()
  local icons = {
    bash = '', zsh = '', fish = '󰈺', sh = '',
    nvim = '', vim = '', nano = '󰏫', git = '',
    tmux = '', htop = '', btop = '', cargo = '',
    python = '', wezterm = '',
  }
  return icons[process_name] or ''
end

function M.apply(config)
  local palette = require 'modules.colors'
  local bg = palette.background or '#0e1514'
  local active_bg = (palette.brights and palette.brights[1]) or '#3f4948'
  local hover_bg = '#26302f'
  local fg = palette.foreground or '#dde4e3'
  local muted = (palette.brights and palette.brights[8]) or '#bec8c8'
  local accent = palette.cursor_bg or '#80d4d5'
  local close_fg = (palette.ansi and palette.ansi[2]) or '#ffb4ab'
  local plus_fg = (palette.ansi and palette.ansi[3]) or '#bbcbb2'

  config.enable_tab_bar = true
  config.hide_tab_bar_if_only_one_tab = false
  config.use_fancy_tab_bar = true -- native layout handles tab sizing better than fixed-cell custom tabs
  config.show_new_tab_button_in_tab_bar = true
  config.show_tabs_in_tab_bar = true
  config.show_tab_index_in_tab_bar = false
  config.animation_fps = 60 -- improves supported easing effects; WezTerm has no Chrome-style tab-slide animation API
  config.window_close_confirmation = 'NeverPrompt'
  config.switch_to_last_active_tab_when_closing_tab = true

  -- The real native close button is currently available in WezTerm nightly only.
  -- pcall keeps stable builds from failing on an unknown config field.
  pcall(function()
    config.show_close_tab_button_in_tabs = true
  end)

  wezterm.on('toggle-tab-pin', function(window, pane)
    local tab = pane:tab()
    if not tab then return end
    local id = tab:tab_id()
    pinned_tabs[id] = not pinned_tabs[id]
    pane:set_user_var('WEZTERM_TAB_PIN_REFRESH', pinned_tabs[id] and '1' or '0')
    window:toast_notification('WezTerm', pinned_tabs[id] and 'Вкладка закреплена' or 'Вкладка откреплена', nil, 1400)
  end)

  wezterm.on('format-tab-title', function(tab, tabs, panes, conf, hover, max_width)
    local pane = tab.active_pane or {}
    local icon = process_icon(pane.foreground_process_name)
    local title = tab.tab_title
    if not title or title == '' then title = pane.title or 'Новая вкладка' end
    if title == '' then title = 'Новая вкладка' end

    local pinned = pinned_tabs[tab.tab_id] == true
    local is_active = tab.is_active
    local tab_bg, tab_fg = bg, muted
    if is_active then
      tab_bg, tab_fg = active_bg, fg
    elseif hover then
      tab_bg, tab_fg = hover_bg, fg
    end

    -- Pinned tabs are compact, icon-only. No tabs are pinned by default.
    if pinned then
      return {
        { Background = { Color = tab_bg } },
        { Foreground = { Color = is_active and accent or tab_fg } },
        { Text = '  ' .. icon .. '  ' },
      }
    end

    -- Fancy mode sizes tabs from their content. Avoid a fake × glyph: it was only
    -- decoration and did not receive mouse clicks. The native close button is used
    -- where the installed WezTerm build supports it; Ctrl+W always remains available.
    local available = math.max(8, (max_width or 30) - 4)
    title = wezterm.truncate_right(title, available)
    return {
      { Background = { Color = tab_bg } },
      { Foreground = { Color = is_active and accent or tab_fg } },
      { Text = '  ' .. icon .. ' ' },
      { Foreground = { Color = tab_fg } },
      { Text = title .. '  ' },
    }
  end)

  config.colors = config.colors or {}
  config.colors.tab_bar = {
    background = bg,
    inactive_tab = { bg_color = bg, fg_color = muted },
    inactive_tab_hover = { bg_color = hover_bg, fg_color = fg },
    active_tab = { bg_color = active_bg, fg_color = fg },
    new_tab = { bg_color = bg, fg_color = plus_fg },
    new_tab_hover = { bg_color = active_bg, fg_color = plus_fg },
    inactive_tab_edge = bg,
  }

  -- Keep the + visually quiet; use a rounded accent only while hovered.
  config.tab_bar_style = {
    new_tab = wezterm.format {
      { Background = { Color = bg } },
      { Foreground = { Color = plus_fg } },
      { Text = '   +   ' },
    },
    new_tab_hover = wezterm.format {
      { Background = { Color = bg } },
      { Foreground = { Color = active_bg } },
      { Text = '' },
      { Background = { Color = active_bg } },
      { Foreground = { Color = plus_fg } },
      { Text = ' + ' },
      { Background = { Color = bg } },
      { Foreground = { Color = active_bg } },
      { Text = '' },
    },
  }
end

return M
