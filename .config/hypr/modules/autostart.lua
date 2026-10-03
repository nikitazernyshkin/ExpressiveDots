hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic-hyprcursor")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_PATH", "~/.local/share/icons:~/.icons:/usr/share/icons")
hl.env("QT_QPA_PLATFORMTHEME", "hyprqt6engine")
hl.env("CHROME_OZONE_PLATFORM_HINT", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Событие старта композитора и запуск приложений
hl.on("hyprland.start", function()

    local commands = {
        "hyprpm reload",
        "hyprctl setcursor Bibata-Modern-Classic 24",
        "qs -p ~/.config/hypr/quickshell/",
        "dunst",
        "hypridle",
        "matugen image --prefer saturation --source-color-index 0 ~/.config/hypr/wallpaper.png",
        "awww-daemon",
        "cliphist wipe",
        "wl-paste --type text --watch cliphist store",
        "/opt/foldersync/bin/foldersync-desktop",
        "Telegram -startintray",
        "xsettingsd",
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
        "gnome-keyring-daemon --start --components=secrets"
    }

    for _, cmd in ipairs(commands) do
        hl.exec_cmd(cmd)
    end
end)
