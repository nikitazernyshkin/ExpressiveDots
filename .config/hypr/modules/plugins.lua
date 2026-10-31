hl.config({
    plugin = {
        hyprcapture = {},
        --[[        scrolloverview = {
            gesture_distance = 300,
            scale = 0.5,
            workspace_gap = 100,
            layout = "vertical",
            wallpaper = 2,
            blur = false,
            shadow = {
                enabled = false,
            },
        },
]]
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
            border_size_1 = 2
        },
    }
})
