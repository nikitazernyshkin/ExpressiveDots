import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"

PanelWindow {
    id: runPanel
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "run"
    exclusiveZone: -1
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { left: true; bottom: true }
    implicitWidth: Math.min(560, (Screen.width || 800) - 32)
    implicitHeight: runPanel.statusText.length > 0 ? 86 : 72
    margins { left: 12; bottom: 32 }
    visible: open
    color: "transparent"

    property bool open: false
    property string pendingCommand: ""
    property string statusText: ""
    readonly property color cSurface: typeof Colors !== "undefined" && Colors.surfaceContainerHigh ? Colors.surfaceContainerHigh : "#252b2b"
    readonly property color cSurfaceLow: typeof Colors !== "undefined" && Colors.surfaceContainer ? Colors.surfaceContainer : "#1a2121"
    readonly property color cText: typeof Colors !== "undefined" && Colors.surfaceText ? Colors.surfaceText : "#dde4e3"
    readonly property color cMuted: typeof Colors !== "undefined" && Colors.surfaceVariantText ? Colors.surfaceVariantText : "#bec8c8"
    readonly property color cPrimary: typeof Colors !== "undefined" && Colors.primary ? Colors.primary : "#a8c7fa"
    readonly property color cOnPrimary: typeof Colors !== "undefined" && Colors.onPrimary ? Colors.onPrimary : "#102f50"
    readonly property color cOutline: typeof Colors !== "undefined" && Colors.outlineVariant ? Colors.outlineVariant : "#45474d"

    IpcHandler {
        target: "run"
        function toggle(): void { runPanel.toggle() }
        function open(): void { runPanel.show() }
        function close(): void { runPanel.close() }
    }

    Process {
        id: commandCheck
        command: []
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                commandProcess.command = ["bash", "-lc", runPanel.pendingCommand]
                commandProcess.running = true
                runPanel.close()
            } else {
                runPanel.statusText = "Команда не найдена"
                commandField.forceActiveFocus()
                commandField.selectAll()
            }
        }
    }
    Process {
        id: commandProcess
        command: []
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                runPanel.statusText = "Ошибка запуска (" + exitCode + ")"
                runPanel.open = true
                Qt.callLater(() => commandField.forceActiveFocus())
            }
        }
    }

    function show(): void {
        open = true
        statusText = ""
        Qt.callLater(() => commandField.forceActiveFocus())
    }
    function close(): void { open = false }
    function toggle(): void { if (open) close(); else show() }
    function execute(): void {
        const command = commandField.text.trim()
        if (!command || commandCheck.running || commandProcess.running) return
        const executable = command.match(/^\s*(?:env\s+)?([^\s;&|]+)/)
        if (!executable) return
        pendingCommand = command
        statusText = ""
        // Validate the command name without evaluating the full command first.
        commandCheck.command = ["bash", "-lc", "command -v -- \"$1\" >/dev/null 2>&1 || test -x \"$1\"", "_", executable[1].replace(/^['"]|['"]$/g, "")]
        commandCheck.running = true
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 26
        color: runPanel.cSurface
        border.width: 1
        border.color: Qt.rgba(runPanel.cOutline.r, runPanel.cOutline.g, runPanel.cOutline.b, 0.8)
        opacity: runPanel.open ? 1 : 0
        scale: runPanel.open ? 1 : 0.94
        y: runPanel.open ? 0 : 10
        Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 10
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 21
                color: runPanel.cSurfaceLow
                border.width: commandField.activeFocus ? 2 : 1
                border.color: commandField.activeFocus ? runPanel.cPrimary : runPanel.cOutline
                Behavior on border.color { ColorAnimation { duration: 140 } }
                TextField {
                    id: commandField
                    anchors.fill: parent
                    anchors.leftMargin: 17
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: "Команда или путь к приложению"
                    placeholderTextColor: runPanel.cMuted
                    color: runPanel.cText
                    font.pixelSize: 14
                    selectByMouse: true
                    selectionColor: runPanel.cPrimary
                    selectedTextColor: runPanel.cOnPrimary
                    background: null
                    onAccepted: runPanel.execute()
                    Keys.onEscapePressed: event => { runPanel.close(); event.accepted = true }
                }
            }
            Rectangle {
                Layout.preferredWidth: 48
                Layout.fillHeight: true
                radius: 20
                color: executeMouse.pressed ? Qt.darker(runPanel.cPrimary, 1.12) : runPanel.cPrimary
                scale: executeMouse.pressed ? 0.94 : 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack } }
                Text {
                    anchors.centerIn: parent
                    text: "play_arrow"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 25
                    color: runPanel.cOnPrimary
                }
                MouseArea {
                    id: executeMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: runPanel.execute()
                }
            }
        }
        Text {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 22
            anchors.bottomMargin: 1
            text: runPanel.statusText
            visible: runPanel.statusText.length > 0
            color: runPanel.statusText.indexOf("не найдена") >= 0 ? (Colors.error || "#f2b8b5") : runPanel.cMuted
            font.pixelSize: 11
        }
    }
    onOpenChanged: if (open) Qt.callLater(() => commandField.forceActiveFocus())
}
