local M = {}

M.theme = {
    primary           = "0xff{{colors.primary.default.hex_stripped}}",
    on_primary        = "0xff{{colors.on_primary.default.hex_stripped}}",
    primary_container = "0xff{{colors.primary_container.default.hex_stripped}}",
    secondary         = "0xff{{colors.secondary.default.hex_stripped}}",
    tertiary          = "0xff{{colors.tertiary.default.hex_stripped}}",
    surface           = "0xff{{colors.surface.default.hex_stripped}}",
    surface_variant   = "0xff{{colors.surface_variant.default.hex_stripped}}",
    background        = "0xff{{colors.background.default.hex_stripped}}",
    outline           = "0xff{{colors.outline.default.hex_stripped}}",
    shadow            = "0x40000000",
}

return M
