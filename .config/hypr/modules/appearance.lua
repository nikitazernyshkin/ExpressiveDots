hl.config({
    decoration = {
        rounding = 25,
        active_opacity = 0.7,
        inactive_opacity = 0.5,
        rounding_power = 4.0,
        wobble = {
            enabled = true
        },
        glow = {
            enabled = false
        },
        blur = {
            enabled = true,
            proportional = true,
            size = 0,
            variant = "haze",
            passes = 4,
            vibrancy = 0.25,
            vibrancy_darkness = 0.1,
            new_optimizations = true,
            ignore_opacity = true,
            popups = true
        }
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
    },
    group = {
        col      = {
            border_active = theme.primary,
            border_inactive = theme.surface_variant,
            border_locked_active = theme.tertiary,
            border_locked_inactive = theme.surface
        },

        groupbar = {
            enabled = true,
            font_size = 8,
            gradients = false,
            height = 16,
            stacked = false,
            render_titles = false,
            round_only_edges = true,
        }
    }
})
