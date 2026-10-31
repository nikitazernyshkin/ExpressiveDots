import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../core"

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "cliphist"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    visible: open
    property bool open: false
    property var clipboardItems: []
    readonly property color cSurface: typeof Colors !== "undefined" && Colors.surfaceContainerHigh ? Colors.surfaceContainerHigh : "#252b2b"
    readonly property color cSurfaceLow: typeof Colors !== "undefined" && Colors.surfaceContainer ? Colors.surfaceContainer : "#1a2121"
    readonly property color cText: typeof Colors !== "undefined" && Colors.surfaceText ? Colors.surfaceText : "#e3e3e3"
    readonly property color cMuted: typeof Colors !== "undefined" && Colors.outline ? Colors.outline : "#aeb4c0"
    readonly property color cPrimary: typeof Colors !== "undefined" && Colors.primary ? Colors.primary : "#a8c7fa"
    readonly property color cOutline: typeof Colors !== "undefined" && Colors.outlineVariant ? Colors.outlineVariant : "#45474d"
    property var selectedItem: null

    IpcHandler {
        target: "cliphist"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.close() }
    }
    function show() { open = true; loadClipboard(); Qt.callLater(() => searchInput.forceActiveFocus()) }
    function close() { open = false; itemMenu.close() }
    function toggle() { if (open) close(); else show() }
    function loadClipboard() {
        clipboardItems = []
        if (!cliphistListProcess.running) cliphistListProcess.running = true
    }
    function filteredItems() {
        const q = searchInput.text.trim().toLowerCase()
        return q ? clipboardItems.filter(item => item.text.toLowerCase().includes(q)) : clipboardItems
    }
    function selectItem(item, terminalPaste) {
        if (!item) return
        // Decode to the clipboard and send one keyboard shortcut; never simulate
        // typing each character, which is extremely slow for long snippets.
        close()
        pasteProcess.command = ["bash", "-lc", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy || exit $?; sleep 0.18; if [ \"$2\" = terminal ]; then wtype -M ctrl -M shift -k v -m shift -m ctrl; else wtype -M ctrl -k v -m ctrl; fi", "_", String(item.raw), terminalPaste ? "terminal" : "normal"]
        pasteProcess.running = true
    }
    function copyItem(item) {
        if (!item) return
        copyProcess.command = ["bash", "-lc", "printf '%s\n' \"$1\" | cliphist decode | wl-copy", "_", String(item.raw)]
        copyProcess.running = true
        close()
    }

    MouseArea { anchors.fill: parent; onClicked: root.close() }
    Shortcut { sequence: "Escape"; onActivated: root.close() }

    Process {
        id: cliphistListProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector { id: cliphistOutput }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.clipboardItems = []
                return
            }
            const lines = cliphistOutput.text.split("\n")
            const parsed = []
            for (const raw of lines) {
                if (!raw.trim()) continue
                const tab = raw.indexOf("\t")
                if (tab < 1) continue
                parsed.push({ id: raw.slice(0, tab), text: raw.slice(tab + 1), raw: raw })
            }
            root.clipboardItems = parsed
        }
    }
    Process { id: pasteProcess; command: [] }
    Process { id: copyProcess; command: [] }
    Process {
        id: wipeProcess
        command: ["cliphist", "wipe"]
        onExited: { root.clipboardItems = []; listView.model = [] }
    }

    Rectangle {
        id: panel
        width: Math.min(470, Screen.width - 32)
        height: Math.min(610, Screen.height - 48)
        anchors.centerIn: parent
        radius: 32
        color: root.cSurface
        border.width: 1
        border.color: root.cOutline
        scale: root.open ? 1 : 0.94
        opacity: root.open ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.04 } }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        MouseArea { anchors.fill: parent; onClicked: {} }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 16
                    color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.18)
                    Text { anchors.centerIn: parent; text: "history"; font.family: "Material Symbols Rounded"; font.pixelSize: 23; color: root.cPrimary }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text { text: "Буфер обмена"; color: root.cText; font.pixelSize: 20; font.weight: Font.DemiBold }
                    Text { text: root.clipboardItems.length + " элементов"; color: root.cMuted; font.pixelSize: 12 }
                }
                ToolButton {
                    text: "delete_sweep"
                    font.family: "Material Symbols Rounded"; font.pixelSize: 22
                    width: 42; height: 42
                    background: Rectangle {
                        radius: 21
                        color: parent.down ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.30) : (parent.hovered ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.16) : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                    onClicked: wipeDialog.open()
                    ToolTip.visible: hovered; ToolTip.text: "Очистить историю"
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 24
                color: root.cSurfaceLow
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? root.cPrimary : root.cOutline
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 12; spacing: 9
                    Text { text: "search"; font.family: "Material Symbols Rounded"; font.pixelSize: 21; color: root.cMuted }
                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: "Поиск"
                        placeholderTextColor: root.cMuted
                        color: root.cText; font.pixelSize: 14
                        background: null
                        Keys.onEscapePressed: event => { root.close(); event.accepted = true }
                    }
                }
            }
            ListView {
                id: listView
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 7
                model: root.filteredItems()
                delegate: Item {
                    required property var modelData
                    width: ListView.view.width
                    height: Math.min(76, Math.max(58, itemText.implicitHeight + 24))
                    Rectangle {
                        anchors.fill: parent; radius: 19
                        color: itemMouse.containsMouse ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.25) : root.cSurfaceLow
                        border.width: itemMouse.containsMouse ? 1 : 0
                        border.color: root.cPrimary
                        scale: itemMouse.containsMouse ? 1.012 : 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack; easing.overshoot: 1.03 } }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 15; anchors.rightMargin: 12; spacing: 10
                            Text {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 2
                                text: "content_paste_go"
                                font.family: "Material Symbols Rounded"; font.pixelSize: 19; color: root.cMuted
                            }
                            Text {
                                id: itemText
                                Layout.fillWidth: true
                                text: modelData.text.replace(/\n/g, " ↵ ")
                                color: root.cText; font.pixelSize: 13
                                elide: Text.ElideRight; maximumLineCount: 3; wrapMode: Text.Wrap
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent; hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                root.selectedItem = modelData
                                if (mouse.button === Qt.RightButton) {
                                    const p = itemMouse.mapToItem(panel, mouse.x, mouse.y)
                                    itemMenu.x = Math.max(8, Math.min(panel.width - itemMenu.width - 8, p.x))
                                    itemMenu.y = Math.max(8, Math.min(panel.height - itemMenu.height - 8, p.y))
                                    itemMenu.open()
                                } else root.selectItem(modelData, false)
                            }
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "Нажатие — вставить · ПКМ — действия"
                color: root.cMuted; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    Popup {
        id: itemMenu
        parent: panel
        width: 224
        height: 164
        padding: 6
        modal: false
        focus: true
        background: Rectangle {
            radius: 22
            color: root.cSurface
            border.width: 1
            border.color: root.cOutline
        }
        contentItem: Column {
            spacing: 2
            Repeater {
                model: [
                    { label: "Вставить", icon: "keyboard", action: 0 },
                    { label: "Вставить в терминал", icon: "terminal", action: 1 },
                    { label: "Скопировать", icon: "content_copy", action: 2 }
                ]
                delegate: Item {
                    required property var modelData
                    width: itemMenu.width - 12
                    height: 48
                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: menuMouse.containsMouse ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.16) : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 12
                        Text { text: modelData.icon; font.family: "Material Symbols Rounded"; font.pixelSize: 20; color: root.cText }
                        Text { text: modelData.label; font.pixelSize: 13; color: root.cText; Layout.fillWidth: true }
                    }
                    MouseArea {
                        id: menuMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.action === 0) root.selectItem(root.selectedItem, false)
                            else if (modelData.action === 1) root.selectItem(root.selectedItem, true)
                            else root.copyItem(root.selectedItem)
                            itemMenu.close()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: wipeDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        focus: true
        title: "Очистить историю?"
        standardButtons: Dialog.NoButton
        width: 320
        background: Rectangle {
            radius: 28
            color: root.cSurface
            border.color: root.cOutline
            border.width: 1
        }
        contentItem: ColumnLayout {
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: "Все записи буфера обмена будут удалены. Это действие нельзя отменить."
                color: root.cText
                wrapMode: Text.Wrap
                font.pixelSize: 14
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Отмена"
                    onClicked: wipeDialog.close()
                }
                Button {
                    text: "Очистить"
                    highlighted: true
                    onClicked: { wipeDialog.close(); wipeProcess.running = true }
                }
            }
        }
    }
}
