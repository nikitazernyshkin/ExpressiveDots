//@ pragma UseQApplication

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"

PanelWindow {
    id: root

    property bool open: false
    property string search: ""
    property bool loading: false
    property var binds: []

    visible: open

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "binds"
    WlrLayershell.keyboardFocus: open
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: -1
    color: "transparent"

    // Material 3 palette — same source/fallbacks as ControlCenter.qml
    readonly property color cPrimary:
        Colors.primary !== undefined ? Colors.primary : "#D0BCFF"
    readonly property color cOnPrimary:
        Colors.onPrimary !== undefined ? Colors.onPrimary : "#381E72"
    readonly property color cSurface:
        Colors.surface !== undefined ? Colors.surface : "#1C1B1F"
    readonly property color cBackground:
        Colors.background !== undefined ? Colors.background : cSurface
    readonly property color cOnSurface:
        Colors.surfaceText !== undefined ? Colors.surfaceText : "#E6E1E5"
    readonly property color cOnSurfaceVariant:
        Colors.onSurfaceVariant !== undefined ? Colors.onSurfaceVariant : "#CAC4D0"
    readonly property color cSurfaceContainer:
        Colors.surfaceContainer !== undefined
            ? Colors.surfaceContainer
            : (Colors.surfaceVariant !== undefined
                ? Colors.surfaceVariant
                : "#2B292F")
    readonly property color cSurfaceContainerHigh:
        Colors.surfaceContainerHigh !== undefined
            ? Colors.surfaceContainerHigh
            : "#36343B"
    readonly property color cOutline:
        Colors.outline !== undefined ? Colors.outline : "#938F99"
    readonly property color cError:
        Colors.error !== undefined ? Colors.error : "#F2B8B5"
    readonly property color cBgText:
        Colors.backgroundText !== undefined ? Colors.backgroundText : cOnSurface

    function toggle() {
        open = !open
        if (open) {
            search = ""
            refresh()
        }
    }

    function show() {
        open = true
        search = ""
        refresh()
    }

    function close() {
        open = false
    }

    function refresh() {
        loading = true
        bindProcess.running = true
    }

    function modifierName(mask) {
        var result = []

        // Hyprland modifier bit masks.
        if ((mask & 64) !== 0) result.push("Super")
        if ((mask & 4) !== 0) result.push("Ctrl")
        if ((mask & 1) !== 0) result.push("Shift")
        if ((mask & 8) !== 0) result.push("Alt")

        return result
    }

    function prettyKey(key) {
        if (!key)
            return ""

        var k = String(key)

        var names = {
            "SPACE": "Space",
            "RETURN": "Enter",
            "ENTER": "Enter",
            "ESC": "Esc",
            "ESCAPE": "Esc",
            "TAB": "Tab",
            "BACKSPACE": "Backspace",
            "DELETE": "Delete",
            "INSERT": "Insert",
            "HOME": "Home",
            "END": "End",
            "PAGEUP": "Page Up",
            "PAGEDOWN": "Page Down",
            "LEFT": "Left",
            "RIGHT": "Right",
            "UP": "Up",
            "DOWN": "Down",
            "PRINT": "Print",
            "CAPSLOCK": "Caps Lock",
            "NUMLOCK": "Num Lock",
            "SCROLLLOCK": "Scroll Lock",
            "PLUS": "+",
            "MINUS": "−",
            "COMMA": ",",
            "PERIOD": ".",
            "SLASH": "/",
            "BACKSLASH": "\\",
            "SEMICOLON": ";",
            "APOSTROPHE": "'",
            "GRAVE": "`",
            "LEFTBRACKET": "[",
            "RIGHTBRACKET": "]"
        }

        if (names[k] !== undefined)
            return names[k]

        if (k.indexOf("mouse:") === 0)
            return k

        if (k.length === 1)
            return k.toUpperCase()

        return k
            .replace(/_/g, " ")
            .replace(/\b\w/g, function(ch) { return ch.toUpperCase() })
    }

    function shortcut(bind) {
        var parts = modifierName(Number(bind.modmask))
        var key = prettyKey(bind.key)

        if (key)
            parts.push(key)

        return parts.join(" + ")
    }

    function actionText(bind) {
        if (bind.description && String(bind.description).trim() !== "")
            return String(bind.description)

        return "Без описания"
    }

    function isWorkspaceBind(bind) {
        var description = bind.description ? String(bind.description).toLowerCase() : ""
        return description.indexOf("рабочий стол") !== -1
    }

    function matches(bind) {
        if (!search || search.trim() === "")
            return true

        var q = search.trim().toLowerCase()

        var values = [
            shortcut(bind),
            actionText(bind),
            bind.key || "",
            bind.description || ""
        ]

        for (var i = 0; i < values.length; ++i) {
            if (String(values[i]).toLowerCase().indexOf(q) !== -1)
                return true
        }

        return false
    }

    function rebuildModel() {
        bindModel.clear()

        var normalBinds = []
        var workspaceBinds = []

        for (var i = 0; i < binds.length; ++i) {
            var b = binds[i]

            // Mouse binds are intentionally hidden: this is a keyboard
            // shortcut sheet in the style of the Niri shortcut overlay.
            if (b.mouse || String(b.key || "").indexOf("mouse:") === 0)
                continue

            if (!matches(b))
                continue

            if (isWorkspaceBind(b))
                workspaceBinds.push(b)
            else
                normalBinds.push(b)
        }

        // Workspace shortcuts are kept at the end of the list,
        // independently of the order in which Hyprland registered them.
        var ordered = normalBinds.concat(workspaceBinds)

        for (var j = 0; j < ordered.length; ++j) {
            var item = ordered[j]

            bindModel.append({
                shortcut: shortcut(item),
                action: actionText(item),
                key: prettyKey(item.key)
            })
        }
    }

    Process {
        id: bindProcess

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            id: bindOutput

            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    root.binds = Array.isArray(parsed) ? parsed : []
                } catch (e) {
                    root.binds = []
                }

                root.loading = false
                root.rebuildModel()
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.loading = false
                root.binds = []
                root.rebuildModel()
            }
        }
    }

    ListModel {
        id: bindModel
    }

    onSearchChanged: rebuildModel()

    IpcHandler {
        target: "binds"

        function toggle() {
            root.toggle()
        }

        function open() {
            root.show()
        }

        function close() {
            root.close()
        }

        function refresh() {
            root.refresh()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.open
        onActivated: root.close()
    }

    Rectangle {
        id: scrim

        anchors.fill: parent
        color: "#000000"
        opacity: root.open ? 0.48 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: panel

        anchors.centerIn: parent

        width: Math.min(parent.width - 32, 760)
        height: Math.min(parent.height - 32, 720)

        radius: 28
        color: cSurface
        border.width: 1
        border.color: Qt.alpha(cOutline, 0.34)

        opacity: root.open ? 1.0 : 0.0
        scale: root.open ? 1.0 : 0.96

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
            }
        }

        // Very subtle inner highlight, closer to Material surfaces than
        // a generic glass/blurred panel.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha("#FFFFFF", 0.025)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: "Сочетания клавиш"
                        color: cOnSurface
                        font.family: "Fira Sans"
                        font.pixelSize: 23
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: loading
                            ? "Обновление…"
                            : bindModel.count + " сочетаний"
                        color: cOnSurfaceVariant
                        font.family: "Fira Sans"
                        font.pixelSize: 13
                        renderType: Text.NativeRendering
                    }
                }
            }

            // Search field
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 24

                color: searchField.activeFocus
                    ? Qt.alpha(cPrimary, 0.10)
                    : cSurfaceContainer

                border.width: searchField.activeFocus ? 1 : 0
                border.color: Qt.alpha(cPrimary, 0.65)

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: "⌕"
                        color: cOnSurfaceVariant
                        font.pixelSize: 21
                        font.weight: Font.Medium
                    }

                    TextField {
                        id: searchField

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        text: root.search
                        onTextChanged: root.search = text

                        placeholderText: "Поиск сочетаний"
                        placeholderTextColor: Qt.alpha(cOnSurfaceVariant, 0.72)

                        color: cOnSurface
                        selectionColor: cPrimary
                        selectedTextColor: cOnPrimary

                        font.family: "Fira Sans"
                        font.pixelSize: 14

                        background: Item {}
                    }

                    Text {
                        visible: root.search.length > 0
                        text: "Esc"
                        color: cOnSurfaceVariant
                        font.family: "Fira Sans"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold

                        Rectangle {
                            z: -1
                            anchors.centerIn: parent
                            width: parent.width + 12
                            height: parent.height + 7
                            radius: height / 2
                            color: cSurfaceContainerHigh
                        }
                    }
                }
            }

            // Shortcut list
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true

                radius: 22
                color: Qt.alpha(cSurfaceContainer, 0.72)
                border.width: 1
                border.color: Qt.alpha(cOutline, 0.16)

                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 6

                    ScrollBar.vertical.policy: ScrollBar.AsNeeded
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    GridView {
                        id: bindList

                        anchors.fill: parent
                        anchors.margins: 2

                        model: bindModel
                        cellWidth: width / 2
                        cellHeight: 62
                        clip: true

                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: row

                            width: bindList.cellWidth - 4
                            height: bindList.cellHeight - 4

                            radius: 14
                            color: rowMouse.containsMouse
                                ? cSurfaceContainerHigh
                                : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 90 }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                // Key chip — Niri-like, but Material 3.
                                Rectangle {
                                    id: keyChip

                                    Layout.preferredWidth: Math.max(
                                        68,
                                        keyText.implicitWidth + 20
                                    )
                                    Layout.preferredHeight: 28
                                    Layout.maximumWidth: 145

                                    radius: 10

                                    color: rowMouse.containsMouse
                                        ? Qt.alpha(cPrimary, 0.16)
                                        : Qt.alpha(cOnSurface, 0.055)

                                    border.width: 1
                                    border.color: rowMouse.containsMouse
                                        ? Qt.alpha(cPrimary, 0.34)
                                        : Qt.alpha(cOutline, 0.20)

                                    Text {
                                        id: keyText

                                        anchors.centerIn: parent
                                        width: parent.width - 14

                                        text: model.shortcut
                                        color: rowMouse.containsMouse
                                            ? cPrimary
                                            : cOnSurface

                                        font.family: "Fira Sans"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold

                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight

                                        renderType: Text.NativeRendering
                                    }
                                }

                                Text {
                                    id: actionTextItem

                                    Layout.fillWidth: true

                                    text: model.action
                                    color: cOnSurface
                                    opacity: rowMouse.containsMouse ? 1.0 : 0.90

                                    font.family: "Fira Sans"
                                    font.pixelSize: 12
                                    font.weight: Font.Normal

                                    maximumLineCount: 2
                                    wrapMode: Text.WordWrap
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter

                                    renderType: Text.NativeRendering
                                }

                            }

                            MouseArea {
                                id: rowMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    Text {
                        anchors.centerIn: parent

                        visible: !loading && bindModel.count === 0
                        text: root.search.length > 0
                            ? "Ничего не найдено"
                            : "Сочетания не найдены"

                        color: cOnSurfaceVariant
                        font.family: "Fira Sans"
                        font.pixelSize: 14
                    }
                }

                // Loading indicator
                Rectangle {
                    anchors.centerIn: parent
                    width: 42
                    height: 42
                    radius: 21

                    visible: loading
                    color: cSurfaceContainerHigh

                    Text {
                        anchors.centerIn: parent
                        text: "…"
                        color: cPrimary
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                    }
                }
            }

            // Footer — deliberately subtle like Niri's help overlay.
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 30
                    height: 24
                    radius: 8
                    color: cSurfaceContainerHigh

                    Text {
                        anchors.centerIn: parent
                        text: "Esc"
                        color: cOnSurfaceVariant
                        font.family: "Fira Sans"
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    text: "закрыть"
                    color: cOnSurfaceVariant
                    font.family: "Fira Sans"
                    font.pixelSize: 11
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: "Hyprland · binds -j"
                    color: cOnSurfaceVariant
                    opacity: 0.55
                    font.family: "Fira Sans"
                    font.pixelSize: 10
                }
            }
        }
    }

    // Clicking outside the card closes the overlay.
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: root.open
        onClicked: root.close()
    }
}
