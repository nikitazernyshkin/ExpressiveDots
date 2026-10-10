# ExpressiveDots

A personal Linux desktop rice inspired by Android's expressive design language.

**Expressive surfaces. Dynamic colors. Tiny details.**

`ExpressiveDots` is a custom desktop environment setup built around Hyprland and Quickshell, bringing together a cohesive interface inspired by Material 3 Expressive and modern Android UI.

## Preview



https://github.com/user-attachments/assets/ec09c69b-4eae-4e5d-9bb1-feb3992332b3



## Features

* **Material-inspired UI** — rounded surfaces, expressive shapes, and consistent spacing.
* **Dynamic theming** — coordinated colors across the shell and desktop.
* **Custom shell** — panels, dock, launcher, notifications, and control center built with Quickshell.
* **Widgets** — desktop widgets designed to fit the overall aesthetic.
* **Dark and light themes** — a unified look across supported components.
* **Hyprland integration** — workspace controls, shortcuts, and desktop interactions.

## Built with

* [Hyprland](https://hypr.land/) — Wayland compositor
* [Quickshell](https://quickshell.org/) — desktop shell and widgets
* [Qt Quick / QML](https://doc.qt.io/qt-6/qtquick-index.html) — UI implementation
* [Matugen](https://github.com/InioX/matugen) — color generation
* [darkman](https://gitlab.com/WhyNotHugo/darkman) — dark/light theme switching

## Installation

> This configuration is a personal rice, not a universal desktop environment installer. Some paths, commands, and dependencies may need to be adjusted for your system.

### Requirements

* Linux with a working Wayland session
* Hyprland
* Quickshell
* Hyprqt6engine
* Hyprpm (optional)
* Darkman
* Hyprpicker
* Hyprland-qt-support
* TTF Material Symbols Variable (git version)
* Hypridle
* Wlsunset

### Setup

1. Install the required dependencies.

2. Back up your existing configuration.

3. Clone this repository:

    ```bash
    git clone https://github.com/nikitazernyshkin/ExpressiveDots.git .expressiveDots
    cd .expressiveDots

    # Replace user with your username (/home/username)
    find . -type f -exec sed -i 's/nick/user/g' {} +
    for dir in \$(pwd)/.config/*; do
        ln -sfn "dir" "HOME/.config/(basename "dir")"
    done

    ln -sfn (pwd)/.local/share/darkman "HOME/.local/share/darkman"
    ```
 
4. Install plugins:
   
    ```bash
    hyprpm update
    hyprpm add https://github.com/gfhdhytghd/HyprCapture
    hyprpm enable HyprCapture
    hyprpm add https://github.com/yayuuu/hyprland-scroll-overview
    hyprpm enable scrolloverview
    hyprpm add https://github.com/devcexx/hyprvibr
    hyprpm enable hyprvibr
    hyprpm add https://github.com/VirtCode/hypr-dynamic-cursors
    hyprpm enable dynamic-cursors
    hyprpm enable borders-plus-plus
    hyprpm add https://github.com/micha4w/Hypr-DarkWindow
    hyprpm enable Hypr-DarkWindow
    hyprpm add https://github.com/savonovv/hypr-kinetic-scroll
    hyprpm enable hypr-kinetic-scroll
    ```

   Or open your config (~/.config/hypr/hyprland.lua) and comment this line:
    ```lua
    -- require("modules.plugins")
    ```

5. Review the configuration files and adjust paths, commands, and system-specific settings.

6. Relogin in your new system!

## Update

Clone repository and relaunch hyprland:

```bash
    git clone https://github.com/nikitazernyshkin/ExpressiveDots.git .expressiveDots
```


## Customization

The interface is designed around a shared color palette and reusable QML components. You can customize the colors, widgets, panels, and interactions to suit your own setup.

Some features may require additional system services or command-line utilities.

## Status

Work in progress. Features, visuals, and configuration may change as the project evolves.

## Credits

Inspired by Material 3 Expressive and modern Android interface design.

Built for personal use and shared for anyone who wants to explore, adapt, or take inspiration from it.

## License

MIT Licence (XD)
