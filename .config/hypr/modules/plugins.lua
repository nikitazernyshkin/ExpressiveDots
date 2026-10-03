hl.config({
    plugin = {
        hyprcapture = {},
        scrolloverview = {
            gesture_distance = 300, -- how far is the "max" for the gesture
            scale = 0.5, -- preferred overview scale
            workspace_gap = 100,
            layout = "horizontal", -- vertical, horizontal, or auto (per-monitor orientation)
            wallpaper = 2, -- 0: global only, 1: per-workspace only, 2: both
            blur = false, -- blur only the main overview wallpaper

            shadow = {
                enabled = false,
            },
        },
        dynamic_cursors = {
            enabled = true,
            mode = "tilt",
            threshold = 1,
            shake = { enabled = false },
            hyprcursor = { enabled = true, nearest = true }
        },
        borders_plus_plus = {
            add_borders = 1,
            natural_rounding = true,
            col = {
                border_1 = theme.surface
            },
            border_size_1 = 1
        }
    }
})
