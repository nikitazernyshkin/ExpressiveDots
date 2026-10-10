//@ pragma UseQApplication

import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

import "./core"
import "./widgets"
import "./panels"
import "./lockscreen"

ShellRoot {
    id: root

    // ========================================================
    // 1. ВИДЖЕТЫ РАБОЧЕГО СТОЛА (ЧАСЫ) НА ВСЕХ МОНИТОРАХ
    // ========================================================
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusiveZone: 0
            focusable: false
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Bottom

            Clock {
                id: clock
                x: 80
                y: 100
            }
        }
    }

    // ========================================================
    // 2. ВЕРХНЯЯ ПАНЕЛЬ (TOPBAR) НА ВСЕХ МОНИТОРАХ ОДНОВРЕМЕННО
    // ========================================================
    Variants {
        model: Quickshell.screens

        // Вызываем TopBar напрямую как окно. Никаких PanelWindow-оберток и anchors.fill!
        TopBar {
            required property var modelData
            screen: modelData // Передаем экран в окно TopBar

            notificationPanel: notifCalendar
        }
    }

    // ========================================================
    // 3. ДОК-ПАНЕЛЬ (DOCK) НА ВСЕХ МОНИТОРАХ ОДНОВРЕМЕННО
    // ========================================================
    Variants {
        model: Quickshell.screens

        // Вызываем Dock напрямую как окно.
        Dock {
            required property var modelData
            screen: modelData // Передаем экран в окно Dock
        }
    }

    // ========================================================
    // СИНГЛТОНЫ И СЕРВИСНАЯ ЛОГИКА (Следование за курсором)
    // ========================================================
    // These are singleton overlays. Let PanelWindow choose its default screen;
    // assigning Quickshell.screens.active here is unsupported in this setup.
    Binds {
        id: binds
        onOpenChanged: {
            if (open) {
                appDrawer.close()
                controlCenter.close()
                notifCalendar.close()
            }
        }
    }
    Cliphist { id: cliphistWidget }

    Launcher {
        id: appDrawer
        onOpenChanged: {
            if (open) {
                controlCenter.close()
                notifCalendar.close()
                binds.close()
            }
        }
    }

    ControlCenter {
        id: controlCenter
        onOpenChanged: {
            if (open) {
                appDrawer.close()
                notifCalendar.close()
                binds.close()
            }
        }
    }

    NotificationPanel {
        id: notifCalendar
        onOpenChanged: {
            if (open) {
                appDrawer.close()
                controlCenter.close()
                binds.close()
            }
        }
    }

    // ========================================================
    // ЭКРАН БЛОКИРОВКИ
    // ========================================================
    property bool isSessionLocked: false

    LockContext {
        id: lockContext
        onUnlocked: root.isSessionLocked = false
    }

    WlSessionLock {
        id: sessionLock
        locked: root.isSessionLocked
        onLockedChanged: if (!locked) root.isSessionLocked = false

        surface: Component {
            WlSessionLockSurface {
                LockSurface {
                    anchors.fill: parent
                    context: lockContext
                        }
            }
        }
    }
}
