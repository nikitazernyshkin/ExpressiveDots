hl.window_rule({
    match = { class = "^(blobdrop)$" },
    float = true
})

-- Попробуем заставить рендерер применить window-opaque правила к слою
hl.layer_rule({
    match = { namespace = "qs" },
    blur = true,
    ignore_alpha = 0.001
})

hl.layer_rule({
    match = { namespace = "quickshell" },
    blur = true,
    ignore_alpha = 0.001
})

hl.workspace_rule({
    workspace = "w[tv1]",
    gaps_out = 0,
    gaps_in = 0,
    no_border = true,
    no_rounding = false
})
