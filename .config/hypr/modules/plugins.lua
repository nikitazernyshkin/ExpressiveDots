hl.config({
    plugin = {
        hyprcapture = {},
        scrolloverview = {
            gesture_distance = 300,
            scale = 0.5,
            workspace_gap = 100,
            layout = "horizontal",
            wallpaper = 2,
            blur = false,
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
        },
        darkwindow = {
            load_shaders = "all"
        }
    }
})

hl.plugin.darkwindow.load_shader("transparent_bg", {
    from = "chromakey",
    args = "bkg=[0.08 0.09 0.11] similarity=0.18 targetOpacity=0.0",
    introduces_transparency = false,
    fade_in_speed = 2,
    fade_out_speed = 2
})
