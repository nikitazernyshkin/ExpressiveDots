package.path           = package.path .. ";~/.config/hypr/?.lua"

_G.home                = "/home/nick/"
_G.terminal            = "wezterm"
_G.fileManager         = "explr"
_G.menu                = "qs -p ~/.config/hypr/quickshell/shell.qml ipc call launcher toggle"
_G.mainMod             = "SUPER"
local success, matugen = pcall(require, "modules.colors")
_G.theme               = (success and matugen and matugen.theme) or {}

hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")

hl.config({
    general = {
        gaps_in       = 5,
        gaps_out      = 15,
        border_size   = 2,
        col           = {
            active_border   = theme.primary,
            inactive_border = theme.surface_variant,
        },
        layout        = "scrolling",
        allow_tearing = false,
    },
    xwayland = {
        enabled = true
    }
})

-- Подключаем строго по одному разу!
require("plugins.hyprsplit")
require("modules.autostart")
require("modules.binds")
require("modules.plugins")
require("modules.animations")
require("modules.monitors")
require("modules.input")
require("modules.layouts")
require("modules.appearance")
require("modules.rules")
