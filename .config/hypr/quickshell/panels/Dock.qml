import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "../core" as Matugen

PanelWindow {
    id: dock

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dock"
    exclusiveZone: 18
    WlrLayershell.keyboardFocus: contextMenu.opened
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    anchors {
        bottom: true
        left: false
        right: false
        top: false
    }

    // Extra transparent headroom keeps app labels/tooltips fully inside the layer.
    implicitHeight: 118
    implicitWidth: Math.max(220, dockContent.implicitWidth + 42)
    color: "transparent"

    property bool isHovered: triggerArea.containsMouse || dockHoverHandler.hovered || contextMenu.opened
    property var recentApps: []
    property var pinnedApps: []

    // Expressive dock tuning.
    readonly property real collapsedWidth: 156
    readonly property real iconSize: 42
    readonly property real expandedIconSize: 46
    readonly property real dockRadius: 23

    readonly property var displayApps: {
        let list = []
        let pinnedExecs = new Set()

        for (let i = 0; i < pinnedApps.length; i++) {
            list.push(pinnedApps[i])
            pinnedExecs.add(pinnedApps[i].exec)
        }

        for (let i = 0; i < recentApps.length; i++) {
            if (!pinnedExecs.has(recentApps[i].exec))
                list.push(recentApps[i])
        }

        return list.slice(0, 8)
    }

    readonly property var androidDecel: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var androidAccel: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property var androidStandard: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 360
            easing.type: Easing.BezierSpline
            easing.bezierCurve: dock.androidDecel
        }
    }

    Process { id: blurProc }
    Process { id: savePinnedProc }
    Process { id: appRunner }
    Process { id: clipboardProc }

    Component.onCompleted: {
        blurProc.command = ["hyprctl", "keyword", "layerrule", "blur, dock"]
        blurProc.running = true
        loadRecentProc.running = true
        loadPinnedProc.running = true
    }

    Process {
        id: loadRecentProc
        command: ["sh", "-c", "cat ~/.cache/quickshell/recent_apps.json 2>/dev/null || echo '[]'"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    dock.recentApps = JSON.parse(text)
                } catch (e) {
                    dock.recentApps = []
                }
            }
        }
    }

    Process {
        id: loadPinnedProc
        command: ["sh", "-c", "cat ~/.cache/quickshell/pinned_apps.json 2>/dev/null || echo '[]'"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    dock.pinnedApps = JSON.parse(text)
                } catch (e) {
                    dock.pinnedApps = []
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true

        onTriggered: {
            loadRecentProc.running = true
            loadPinnedProc.running = true
        }
    }

    function savePinnedHistory(list) {
        const jsonB64 = Qt.btoa(JSON.stringify(list))
        savePinnedProc.command = [
            "sh", "-c",
            "mkdir -p ~/.cache/quickshell && echo '" +
            jsonB64 +
            "' | base64 -d > ~/.cache/quickshell/pinned_apps.json"
        ]
        savePinnedProc.running = true
    }

    function isPinned(app) {
        if (!app)
            return false

        return dock.pinnedApps.some(a => a.exec === app.exec)
    }

    function togglePin(app) {
        if (!app)
            return

        let list = dock.pinnedApps.slice()

        if (isPinned(app))
            list = list.filter(a => a.exec !== app.exec)
        else
            list.push(app)

        dock.pinnedApps = list
        savePinnedHistory(list)
    }

    function launch(app) {
        if (!app || !app.exec)
            return

        appRunner.command = [
            "sh", "-c",
            app.exec + " >/dev/null 2>&1 &"
        ]
        appRunner.running = true
    }

    function copyCommand(app) {
        if (!app || !app.exec)
            return

        const b64 = Qt.btoa(app.exec)
        clipboardProc.command = [
            "sh", "-c",
            "printf '%s' '" + b64 + "' | base64 -d | " +
            "(command -v wl-copy >/dev/null 2>&1 && wl-copy || xclip -selection clipboard)"
        ]
        clipboardProc.running = true
    }

    // Approximate "Mac/Pixel expressive" magnification.
    function iconScaleFor(item) {
        if (!dock.isHovered || (!triggerArea.containsMouse && !dockHoverHandler.hovered))
            return 1.0

        const center = item.mapToItem(dockContent, item.width / 2, 0).x
        const distance = Math.abs(dockHoverMouse.mouseX - center)

        if (distance < 28)
            return 1.14
        if (distance < 68)
            return 1.08
        if (distance < 110)
            return 1.035

        return 1.0
    }

    // Only the thin handle at the very bottom opens the dock.
    MouseArea {
        id: triggerArea
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 11
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        Rectangle {
            id: dockSurface
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 11

            width: dock.isHovered
                ? Math.max(210, dockContent.implicitWidth + 42)
                : 132

            height: dock.isHovered ? 58 : 5
            radius: dock.isHovered ? dock.dockRadius : 3

            color: dock.isHovered
                ? Qt.rgba(
                    (Matugen.Colors.surfaceContainerHigh || "#302E36").r,
                    (Matugen.Colors.surfaceContainerHigh || "#302E36").g,
                    (Matugen.Colors.surfaceContainerHigh || "#302E36").b,
                    0.94
                  )
                : "transparent"

            border.width: dock.isHovered ? 1 : 0
            border.color: Qt.rgba(
                (Matugen.Colors.outline || "#938F99").r,
                (Matugen.Colors.outline || "#938F99").g,
                (Matugen.Colors.outline || "#938F99").b,
                0.12
            )

            Behavior on width {
                NumberAnimation {
                    duration: 360
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: dock.androidDecel
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: dock.androidDecel
                }
            }

            Behavior on color {
                ColorAnimation { duration: 220 }
            }

            // Soft expressive "handle" when collapsed.
            Rectangle {
                anchors.centerIn: parent
                width: 104
                height: 4
                radius: 3
                color: Matugen.Colors.onSurface || "#E6E1E5"
                opacity: dock.isHovered ? 0 : 0.68

                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }
            }

            HoverHandler {
                id: dockHoverHandler
            }

            MouseArea {
                id: dockHoverMouse
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                z: -1
            }

            RowLayout {
                id: dockContent

                anchors.centerIn: parent
                spacing: 7

                opacity: dock.isHovered ? 1 : 0
                scale: dock.isHovered ? 1 : 0.78
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 210
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: dock.androidDecel
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 330
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: dock.androidDecel
                    }
                }

                Repeater {
                    model: dock.displayApps

                    delegate: Item {
                        id: appItem

                        width: dock.expandedIconSize
                        height: dock.expandedIconSize

                        property bool isAppPinned: dock.isPinned(modelData)
                        property bool hovered: recMouse.containsMouse
                        property bool runningApp: !isAppPinned

                        scale: dock.iconScaleFor(appItem)

                        Behavior on scale {
                            NumberAnimation {
                                duration: 240
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.15
                            }
                        }

                        // Tiny vertical lift makes the magnification feel more physical.
                        y: hovered ? -3 : 0

                        Behavior on y {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutBack
                            }
                        }

                        Rectangle {
                            id: appBg
                            anchors.centerIn: parent
                            width: dock.iconSize
                            height: dock.iconSize
                            radius: 19

                            color: recMouse.containsMouse
                                ? Qt.rgba(
                                    (Matugen.Colors.primary || "#D0BCFF").r,
                                    (Matugen.Colors.primary || "#D0BCFF").g,
                                    (Matugen.Colors.primary || "#D0BCFF").b,
                                    0.20
                                  )
                                : Qt.rgba(1, 1, 1, 0.055)

                            border.width: isAppPinned ? 0 : 1
                            border.color: isAppPinned
                                ? "transparent"
                                : Qt.rgba(
                                    (Matugen.Colors.outline || "#938F99").r,
                                    (Matugen.Colors.outline || "#938F99").g,
                                    (Matugen.Colors.outline || "#938F99").b,
                                    0.35
                                  )

                            scale: recMouse.pressed ? 0.88 : 1.0

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: recMouse.pressed ? 90 : 230
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Image {
                                id: recIcon
                                anchors.centerIn: parent
                                width: 31
                                height: 31
                                fillMode: Image.PreserveAspectFit
                                source: modelData.icon !== ""
                                    ? "file://" + modelData.icon
                                    : ""
                                visible: modelData.icon !== "" &&
                                         status === Image.Ready
                                smooth: true
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name
                                    ? modelData.name.charAt(0).toUpperCase()
                                    : "?"
                                color: Matugen.Colors.onSurface || "#E6E1E5"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                visible: !recIcon.visible
                            }

                            // Running/recent indicator.
                            Rectangle {
                                visible: !isAppPinned
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -3

                                width: recMouse.containsMouse ? 14 : 6
                                height: 3
                                radius: 2
                                color: Matugen.Colors.primary || "#D0BCFF"

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        // Tooltip / expressive label.
                        Rectangle {
                            id: appTooltip
                            anchors.bottom: appBg.top
                            anchors.bottomMargin: 8

                            // Keep the label inside the PanelWindow. Without this,
                            // the first icon can push half of a wide tooltip outside
                            // the layer window and the beginning of the text gets cut.
                            x: {
                                const p = appItem.mapToItem(dockContent, 0, 0)
                                const desired = appItem.width / 2 - width / 2
                                const minX = 8 - p.x
                                const maxX = dockContent.width - width - 8 - p.x
                                return Math.max(minX, Math.min(desired, maxX))
                            }

                            width: Math.min(260, Math.max(90, appNameText.implicitWidth + 28))
                            height: 30
                            radius: 15

                            color: Matugen.Colors.surfaceContainerHighest
                                || Matugen.Colors.surfaceContainerHigh
                                || "#38363E"

                            opacity: hovered ? 1 : 0
                            scale: hovered ? 1 : 0.86
                            visible: opacity > 0

                            Behavior on opacity {
                                NumberAnimation { duration: 140 }
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 190
                                    easing.type: Easing.OutBack
                                }
                            }

                            Text {
                                id: appNameText
                                anchors.centerIn: parent
                                width: parent.width - 24
                                text: modelData.name || modelData.exec || "Приложение"
                                color: Matugen.Colors.onSurface || "#E6E1E5"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: recMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    dock.launch(modelData)
                                } else if (mouse.button === Qt.RightButton) {
                                    contextMenu.targetApp = modelData
                                    contextMenu.popup()
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: dock.displayApps.length > 0 ? 1 : 0
                    Layout.preferredHeight: 30
                    radius: 1
                    color: Matugen.Colors.outline || "#938F99"
                    opacity: 0.24
                    visible: dock.displayApps.length > 0
                }

                // Launcher.
                Item {
                    width: dock.expandedIconSize
                    height: dock.expandedIconSize

                    Process {
                        id: toggleLauncherProc
                        command: ["qs", "-p", "/home/nick/.config/hypr/quickshell/shell.qml", "ipc", "call", "launcher", "toggle"]
                    }

                    Rectangle {
                        id: launcherBg
                        anchors.centerIn: parent
                        width: dock.iconSize
                        height: dock.iconSize
                        radius: 20

                        color: launcherMouse.containsMouse
                            ? Matugen.Colors.primary || "#D0BCFF"
                            : Matugen.Colors.surfaceContainer || "#2B2930"

                        scale: launcherMouse.pressed
                            ? 0.88
                            : (launcherMouse.containsMouse ? 1.06 : 1.0)

                        Behavior on scale {
                            NumberAnimation {
                                duration: launcherMouse.pressed ? 90 : 240
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.1
                            }
                        }

                        Behavior on color {
                            ColorAnimation { duration: 170 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "apps"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 24
                            font.weight: Font.Medium

                            color: launcherMouse.containsMouse
                                ? Matugen.Colors.onPrimary || "#381E72"
                                : Matugen.Colors.onSurface || "#E6E1E5"

                            rotation: launcherMouse.containsMouse ? 45 : 0

                            Behavior on rotation {
                                NumberAnimation {
                                    duration: 280
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.0
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: launcherMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: toggleLauncherProc.running = true
                    }

                    Rectangle {
                        id: launcherTooltip
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 8

                        width: 76
                        height: 30
                        radius: 15

                        color: Matugen.Colors.surfaceContainerHighest
                            || Matugen.Colors.surfaceContainerHigh
                            || "#38363E"

                        opacity: launcherMouse.containsMouse ? 1 : 0
                        scale: launcherMouse.containsMouse ? 1 : 0.86
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation { duration: 140 }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 190
                                easing.type: Easing.OutBack
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Приложения"
                            color: Matugen.Colors.onSurface || "#E6E1E5"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    // Context menu — Material 3 Expressive.
    Menu {
        id: contextMenu
        property var targetApp: null

        implicitWidth: 236
        padding: 7

        background: Rectangle {
            implicitWidth: 236
            radius: 20
            color: Matugen.Colors.surfaceContainerHigh
                || Matugen.Colors.surfaceContainer
                || Matugen.Colors.surface
                || "#25232A"
            border.color: Matugen.Colors.outlineVariant
                || Matugen.Colors.outline
                || "#40FFFFFF"
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                radius: 1
                color: Matugen.Colors.onSurface || "#FFFFFF"
                opacity: 0.07
            }
        }

        // App header.
        MenuItem {
            enabled: false
            implicitHeight: 52

            contentItem: RowLayout {
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 12
                    color: Matugen.Colors.secondaryContainer
                        || Matugen.Colors.primaryContainer
                        || "#303038"

                    Image {
                        id: menuIcon
                        anchors.centerIn: parent
                        width: 27
                        height: 27
                        fillMode: Image.PreserveAspectFit
                        source: contextMenu.targetApp && contextMenu.targetApp.icon
                            ? "file://" + contextMenu.targetApp.icon : ""
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !menuIcon.visible
                        text: contextMenu.targetApp && contextMenu.targetApp.name
                            ? contextMenu.targetApp.name.charAt(0).toUpperCase() : "?"
                        color: Matugen.Colors.onSecondaryContainer
                            || Matugen.Colors.onPrimaryContainer
                            || Matugen.Colors.onSurface
                            || "#E6E1E5"
                        font.pixelSize: 17
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: contextMenu.targetApp && contextMenu.targetApp.name
                            ? contextMenu.targetApp.name : "Приложение"
                        color: Matugen.Colors.onSurface || "#E6E1E5"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: contextMenu.targetApp && contextMenu.targetApp.exec
                            ? contextMenu.targetApp.exec : "Док"
                        color: Matugen.Colors.onSurfaceVariant || "#CAC4D0"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }

        MenuSeparator {
            padding: 4
            contentItem: Rectangle {
                implicitHeight: 1
                color: Matugen.Colors.outlineVariant
                    || Matugen.Colors.outline
                    || "#40FFFFFF"
                opacity: 0.55
            }
        }

        delegate: MenuItem {
            id: menuItem
            implicitHeight: 40

            contentItem: RowLayout {
                spacing: 10

                Text {
                    Layout.preferredWidth: 20
                    text: {
                        if (menuItem.text === "Открыть") return "open_in_new"
                        if (menuItem.text === "Закрепить" || menuItem.text === "Открепить") return "push_pin"
                        if (menuItem.text === "Копировать команду") return "content_copy"
                        return "more_horiz"
                    }
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 19
                    horizontalAlignment: Text.AlignHCenter
                    color: menuItem.highlighted
                        ? (Matugen.Colors.onSecondaryContainer
                           || Matugen.Colors.onPrimaryContainer
                           || Matugen.Colors.onPrimary
                           || "#FFFFFF")
                        : (Matugen.Colors.onSurfaceVariant
                           || Matugen.Colors.onSurface
                           || "#CAC4D0")
                }

                Text {
                    Layout.fillWidth: true
                    text: menuItem.text
                    font: menuItem.font
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    color: menuItem.highlighted
                        ? (Matugen.Colors.onSecondaryContainer
                           || Matugen.Colors.onPrimaryContainer
                           || Matugen.Colors.onPrimary
                           || "#FFFFFF")
                        : (Matugen.Colors.onSurface || "#E6E1E5")
                }
            }

            background: Rectangle {
                radius: 12
                color: menuItem.highlighted
                    ? (Matugen.Colors.secondaryContainer
                       || Matugen.Colors.primaryContainer
                       || "#45404A")
                    : "transparent"
            }
        }

        MenuItem {
            text: "Открыть"
            onTriggered: {
                if (contextMenu.targetApp) dock.launch(contextMenu.targetApp)
                contextMenu.close()
            }
        }

        MenuItem {
            text: contextMenu.targetApp && dock.isPinned(contextMenu.targetApp)
                ? "Открепить" : "Закрепить"
            onTriggered: {
                if (contextMenu.targetApp) dock.togglePin(contextMenu.targetApp)
                contextMenu.close()
            }
        }

        MenuItem {
            visible: contextMenu.targetApp && !!contextMenu.targetApp.exec
            text: "Копировать команду"
            onTriggered: {
                if (contextMenu.targetApp) dock.copyCommand(contextMenu.targetApp)
                contextMenu.close()
            }
        }
    }

}
