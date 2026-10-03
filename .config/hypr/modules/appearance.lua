hl.config({ 
    decoration = { 
        rounding = 24, 
        active_opacity = 0.9, 
        inactive_opacity = 0.6, 
        blur = { 
            enabled = true, 
            xray = true, 
            size = 12, 
            passes = 4, 
            new_optimizations = true, 
            ignore_opacity = true, 
            brightness = 0.85, 
            contrast = 1.1, 
            vibrancy = 0.35, 
            noise = 0.02, 
        } 
    }, 
    misc = { 
        disable_hyprland_logo = true, 
        disable_splash_rendering = true, 
        force_default_wallpaper = 0, 
    }, 
    group = { 
        -- Все цвета для групп должны объявляться в корне секции 'group'
        ["col.border_active"]          = theme.primary,
        ["col.border_inactive"]        = theme.surface_variant,
        ["col.border_locked_active"]   = theme.tertiary or theme.primary,
        ["col.border_locked_inactive"] = theme.surface,
        
        groupbar = { 
            enabled = true, 
            font_size = 8, -- Дефолтный читаемый размер шрифта (вместо 2)
            gradients = false, 
            height = 16, 
            stacked = false, 
            render_titles = false, 
            round_only_edges = true, 
            -- Свойства col внутри groupbar в официальном API нет, 
            -- все цвета берутся из корневых параметров col.border_* выше
        } 
    } 
})
