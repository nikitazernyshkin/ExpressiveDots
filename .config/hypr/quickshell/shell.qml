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

    // Desktop widgets are instantiated once per output.
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: desktopWidgets

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

    Binds {
        id: binds
    }

    Dock {
        id: dock
    }

    Cliphist {
        id: cliphistWidget
    }

    IpcHandler {
        target: "cliphistWidget"

        function toggle(): void {
            cliphistWidget.toggle()
        }

        function open(): void {
            cliphistWidget.visible = true
        }

        function close(): void {
            cliphistWidget.visible = false
        }
    }

    Launcher {
        id: appDrawer
    }

    ControlCenter {
        id: controlCenter

        onOpenChanged: if (open)
            notifCalendar.close()
    }

    NotificationPanel {
        id: notifCalendar

        onOpenChanged: if (open)
            controlCenter.close()
    }

    TopBar {
        id: topBar
        controlCenter: controlCenter
        notificationPanel: notifCalendar
    }

    property bool isSessionLocked: false

    LockContext {
        id: lockContext

        onUnlocked: root.isSessionLocked = false
    }

    WlSessionLock {
        id: sessionLock

        locked: root.isSessionLocked

        onLockedChanged: {
            if (!locked)
                root.isSessionLocked = false
        }

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: lockContext
                controlCenter: controlCenter
            }
        }
    }

    IpcHandler {
        target: "lockscreen"

        function lock(): void {
            root.isSessionLocked = true
        }

        function unlock(): void {
            root.isSessionLocked = false
        }
    }

    IpcHandler {
        target: "controlcenter"

        function toggle(): void {
            controlCenter.toggleMain()
        }

        function open(): void {
            controlCenter.open = true
        }

        function close(): void {
            controlCenter.close()
        }
    }
}
