-- Конфигурация внешнего вида и поведения
hl.config({
    general = {
        gaps_in       = 5,
        gaps_out      = 15,
        border_size   = 2,
        col = {
            active_border   = theme.primary,
            inactive_border = theme.surface_variant,
        },
        layout        = "scrolling",
        allow_tearing = false,
    },
    xwayland = {
        enabled = false
    }
})

hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0, no_border = true, no_rounding = false })
