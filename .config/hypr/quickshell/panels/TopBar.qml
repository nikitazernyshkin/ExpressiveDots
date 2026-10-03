import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../core"

PanelWindow {
    id: panel

    // Dependencies supplied by shell.qml.
    property var controlCenter
    property var notificationPanel

    Process {
        id: commandProcess
    }

    function runCommand(commandLine: var) {
        commandProcess.command = commandLine
        commandProcess.running = true
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "top-panel"

    anchors {
        top: true
        bottom: false
        left: true
        right: true
    }
    /*
     * ─────────────────────────────
     * DP
     * ─────────────────────────────
     *
     * QML/Wayland already works in
     * logical pixels.
     *
     * So this behaves similarly to
     * Compose dp and respects system
     * display scaling.
     */
    function dp(value) {
        return value
    }

    /*
     * OLD PANEL SIZE
     *
     * Original panel:
     * 34px
     *
     * Now:
     * 34dp
     */

    implicitHeight: dp(34)
    focusable: typeof workspaceArea !== "undefined" && workspaceArea.editingWorkspaceId >= 0
    color: "#01ffffff" 


    /*
     * ─────────────────────────────
     * STATUS
     * ─────────────────────────────
     */
    property string home: "/home/nick/"
    property int wifiSignal: -1
    property int btOn: -1
    property int batteryLevel: -1
    property bool charging: false
    property string kbLayout: "US"

    /*
     * ─────────────────────────────
     * COLORS
     * ─────────────────────────────
     */
    readonly property color colorPrimary: typeof Colors !== "undefined" ? Colors.primary : "#D0BCFF"
    readonly property color colorSurface: typeof Colors !== "undefined" ? Colors.surface : "#49454F"
    readonly property color colorSurfaceVariant: typeof Colors !== "undefined" ? Colors.surfaceVariant : "#454654"
    readonly property color colorBgText: typeof Colors !== "undefined" ? Colors.backgroundText : "#E6E1E5"
    readonly property color colorError: typeof Colors !== "undefined" ? Colors.error : "#F2B8B5"
    readonly property color colorOutline: typeof Colors !== "undefined" ? Colors.outline : "#938F96"
    readonly property color colorBackground: typeof Colors !== "undefined" ? Colors.background : "#111318"

    /*
     * ─────────────────────────────
     * TONAL SURFACES
     * ─────────────────────────────
     */
    readonly property color surfaceLow: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.82)
    readonly property color surfaceContainer: Qt.rgba(colorSurfaceVariant.r, colorSurfaceVariant.g, colorSurfaceVariant.b, 0.84)
    readonly property color surfaceHigh: Qt.rgba(colorSurfaceVariant.r, colorSurfaceVariant.g, colorSurfaceVariant.b, 0.96)
    readonly property color surfaceHover: Qt.rgba(colorPrimary.r, colorPrimary.g, colorPrimary.b, 0.16)

    /*
     * TRAY MENU COLORS
     *
     * Change these only if you want to theme the tray context menu.
     * The rest of the panel design is untouched.
     */
    readonly property color trayMenuBackground: "#202124"
    readonly property color trayMenuText: "#E8EAED"
    readonly property color trayMenuDisabled: "#6F7278"
    readonly property color trayMenuHover: "#303134"
    readonly property color trayMenuAccent: "#A8C7FA"
    readonly property color trayMenuSeparator: "#3C4043"
    readonly property color trayMenuBorder: "#45474D"

    /*
     * ═════════════════════════════
     * WIFI
     * ═════════════════════════════
     */
    Process {
        id: wifiProbe

        running: true
        command: [
            "sh",
            "-c",
            "sig=$(nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | grep '^\\*' | head -1 | cut -d: -f2); echo ${sig:-0}"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim(), 10)
                panel.wifiSignal = isNaN(v) ? -1 : v
            }
        }
    }

    /*
     * ═════════════════════════════
     * BLUETOOTH
     * ═════════════════════════════
     */
    Process {
        id: btProbe

        running: true
        command: [
            "sh",
            "-c",
            "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0"
        ]

        stdout: StdioCollector {
            onStreamFinished: panel.btOn = parseInt(text.trim(), 10) || 0
        }
    }

    /*
     * ═════════════════════════════
     * BATTERY
     * ═════════════════════════════
     */
    Process {
        id: batteryProbe

        running: true
        command: [
            "sh",
            "-c",
            "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); if [ -n \"$b\" ]; then echo \"$(cat $b/capacity) $(cat $b/status)\"; else echo \"-1\"; fi"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                panel.batteryLevel = parseInt(parts[0], 10)
                panel.charging = parts.length > 1 && parts[1] === "Charging"
            }
        }
    }

    /*
     * ═════════════════════════════
     * KEYBOARD
     * ═════════════════════════════
     */
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const lay = event.data.split(",").pop().trim().toLowerCase()
                panel.kbLayout = (lay.includes("ru") || lay.includes("russian")) ? "RU" : "US"
            }
        }
    }

    Process {
        id: kbInit

        running: true
        command: [
            "sh",
            "-c",
            "hyprctl devices -j 2>/dev/null | grep -o '\"active_keymap\":\"[^\"]*\"' | head -1 | cut -d'\"' -f4 | awk '{print toupper(substr($0, length($0)-1))}'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    panel.kbLayout = text.trim()
            }
        }
    }

    /*
     * ═════════════════════════════
     * TIMERS
     * ═════════════════════════════
     */
    Timer {
        interval: 3000
        running: true
        repeat: true

        onTriggered: wifiProbe.running = true
    }

    Timer {
        interval: 5000
        running: true
        repeat: true

        onTriggered: btProbe.running = true
    }

    Timer {
        interval: 10000
        running: true
        repeat: true

        onTriggered: batteryProbe.running = true
    }
    /*
     * ═════════════════════════════
     *
     * LEFT
     * CLOCK CAPSULE
     *
     * ═════════════════════════════
     */
    Rectangle {
        id: clockCapsule

        anchors {
            left: parent.left
            leftMargin: panel.dp(4)
            verticalCenter: parent.verticalCenter
        }

        height: panel.dp(26)
        width: clockText.implicitWidth + panel.dp(20)
        radius: height / 2
        color: clockHover.containsMouse ? panel.surfaceHover : panel.surfaceLow

        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        scale: clockHover.pressed ? 0.96 : clockHover.containsMouse ? 1.02 : 1.0

        Text {
            id: clockText

            anchors.centerIn: parent
            text: Qt.formatDateTime(new Date(), "HH:mm")
            color: clockHover.containsMouse ? panel.colorPrimary : panel.colorBgText
            font.pixelSize: panel.dp(11)
            font.bold: true

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true

            onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
        }

        MouseArea {
            id: clockHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: notificationPanel.toggle()
        }
    }

    /*
     * ═════════════════════════════
     *
     * CENTER
     * BROWSER-LIKE WORKSPACE TABS
     *
     * The workspace model is intentionally read from Hyprland's
     * public JSON IPC (`hyprctl workspaces -j`) instead of depending
     * on Quickshell's Hyprland ObjectModel. This makes the widget
     * independent of the QML backend and fits the Lua configuration
     * model used by Hyprland 0.55+.
     *
     * LMB -> focus
     * RMB -> focus + rename
     * Enter -> save
     * Esc -> cancel
     * + -> first free numeric workspace
     * ═════════════════════════════
     */
    Item {
        id: workspaceArea

        anchors {
            left: clockCapsule.right
            right: rightSection.left
            verticalCenter: parent.verticalCenter
        }

        anchors.leftMargin: panel.dp(10)
        anchors.rightMargin: panel.dp(10)

        height: panel.dp(30)
        clip: true

        property int editingWorkspaceId: -1
        property int activeWorkspaceId: -1
        property string activeWorkspaceNameFromIpc: ""
        property var workspaceItems: []

        readonly property real gap: panel.dp(3)
        readonly property real plusWidth: panel.dp(24)
        readonly property real preferredInactiveWidth: panel.dp(29)
        readonly property real minimumInactiveWidth: panel.dp(21)
        readonly property real minimumActiveWidth: panel.dp(76)
        readonly property real maximumActiveWidth: panel.dp(150)

        readonly property int workspaceCount:
            Math.max(0, workspaceItems.length - 1)

        readonly property real availableWidth:
            Math.max(panel.dp(90), width - panel.dp(2))

        function visibleName(item) {
            if (!item)
                return ""

            const name = String(item.name || "").trim()
            return name.length > 0 ? name : String(item.id)
        }

        function hasCustomName(item) {
            if (!item)
                return false

            const name = String(item.name || "").trim()
            return name.length > 0 && name !== String(item.id)
        }

        readonly property string activeName: {
            if (activeWorkspaceNameFromIpc.length > 0)
                return activeWorkspaceNameFromIpc

            for (let i = 0; i < workspaceItems.length; ++i) {
                const item = workspaceItems[i]
                if (item && item.kind === "workspace" && item.id === activeWorkspaceId)
                    return visibleName(item)
            }

            return activeWorkspaceId > 0 ? String(activeWorkspaceId) : ""
        }

        Text {
            id: activeWorkspaceMeasure
            visible: false
            text: workspaceArea.activeName
            font.family: "Fira Sans"
            font.pixelSize: panel.dp(10)
            font.bold: true
        }

        readonly property real activeNaturalWidth: Math.min(
            maximumActiveWidth,
            Math.max(
                minimumActiveWidth,
                activeWorkspaceMeasure.implicitWidth
                    + panel.dp(
                        workspaceArea.activeWorkspaceNameFromIpc.length > 0
                        && workspaceArea.activeWorkspaceNameFromIpc !== String(workspaceArea.activeWorkspaceId)
                            ? 39
                            : 24
                    )
            )
        )

        readonly property int inactiveCount:
            Math.max(0, workspaceCount - 1)

        readonly property real totalGapWidth:
            workspaceCount * gap

        readonly property real effectiveInactiveWidth: {
            if (inactiveCount <= 0)
                return 0

            const preferredTotal =
                activeNaturalWidth
                + inactiveCount * preferredInactiveWidth
                + plusWidth
                + totalGapWidth

            if (preferredTotal <= availableWidth)
                return preferredInactiveWidth

            const remaining = Math.max(
                panel.dp(0),
                availableWidth
                - activeNaturalWidth
                - plusWidth
                - totalGapWidth
            )

            return Math.max(
                minimumInactiveWidth,
                Math.min(preferredInactiveWidth, remaining / inactiveCount)
            )
        }

        readonly property real effectiveActiveWidth: {
            if (workspaceCount <= 0)
                return 0

            const preferredTotal =
                activeNaturalWidth
                + inactiveCount * preferredInactiveWidth
                + plusWidth
                + totalGapWidth

            if (preferredTotal <= availableWidth)
                return activeNaturalWidth

            const availableForActive = Math.max(
                minimumActiveWidth,
                availableWidth
                - inactiveCount * effectiveInactiveWidth
                - plusWidth
                - totalGapWidth
            )

            return Math.max(
                minimumActiveWidth,
                Math.min(activeNaturalWidth, availableForActive)
            )
        }

        readonly property real tabsWidth: {
            if (workspaceCount <= 0)
                return plusWidth

            return effectiveActiveWidth
                + inactiveCount * effectiveInactiveWidth
                + plusWidth
                + totalGapWidth
        }

        function focusWorkspace(id) {
            runCommand([
                "/usr/bin/hyprctl",
                "dispatch",
                "hl.dsp.focus({ workspace = " + String(id) + " })"
            ])
        }

        function nextFreeWorkspaceId() {
            let candidate = 1

            while (true) {
                let used = false

                for (let i = 0; i < workspaceItems.length; ++i) {
                    const item = workspaceItems[i]
                    if (item && item.kind === "workspace" && item.id === candidate) {
                        used = true
                        break
                    }
                }

                if (!used)
                    return candidate

                ++candidate
            }
        }

        function createWorkspace() {
            focusWorkspace(nextFreeWorkspaceId())
            refreshWorkspaceData()
        }

        function escapeLuaString(value) {
            return String(value)
                .replace(/\\/g, "\\\\")
                .replace(/"/g, '\\"')
                .replace(/\r/g, "")
                .replace(/\n/g, " ")
        }

        function beginRename(id) {
            let exists = false

            for (let i = 0; i < workspaceItems.length; ++i) {
                const item = workspaceItems[i]
                if (item && item.kind === "workspace" && item.id === id) {
                    exists = true
                    break
                }
            }

            if (!exists)
                return

            focusWorkspace(id)
            editingWorkspaceId = id
        }

        function saveRename(id, value) {
            let name = String(value || "")
                .replace(/\s+/g, " ")
                .trim()

            if (name.length === 0)
                name = String(id)

            runCommand([
                "/usr/bin/hyprctl",
                "dispatch",
                "hl.dsp.workspace.rename({ workspace = "
                + String(id)
                + ", name = \""
                + escapeLuaString(name)
                + "\" })"
            ])

            editingWorkspaceId = -1
            refreshWorkspaceData()
        }

        function cancelRename() {
            editingWorkspaceId = -1
        }

        function refreshWorkspaceData() {
            if (!workspaceQuery.running)
                workspaceQuery.running = true

            if (!activeQuery.running)
                activeQuery.running = true
        }

        function rebuildWorkspaceItems(workspaces) {
            const list = []

            for (let i = 0; i < workspaces.length; ++i) {
                const ws = workspaces[i]
                if (!ws || typeof ws.id !== "number" || ws.id < 1)
                    continue

                list.push({
                    kind: "workspace",
                    id: ws.id,
                    name: String(ws.name || "").trim()
                })
            }

            /* Fallback to Quickshell's native model if hyprctl returned nothing. */
            if (list.length === 0 && Hyprland.workspaces) {
                const nativeList = Array.from(Hyprland.workspaces)

                for (let i = 0; i < nativeList.length; ++i) {
                    const ws = nativeList[i]
                    if (!ws || ws.id < 1)
                        continue

                    list.push({
                        kind: "workspace",
                        id: ws.id,
                        name: String(ws.name || "").trim()
                    })
                }
            }

            list.sort(function(a, b) {
                return a.id - b.id
            })

            /* Never leave the bar with only '+', even during IPC startup. */
            if (list.length === 0 && activeWorkspaceId > 0) {
                list.push({
                    kind: "workspace",
                    id: activeWorkspaceId,
                    name: activeWorkspaceNameFromIpc || String(activeWorkspaceId)
                })
            }

            if (activeWorkspaceId > 0) {
                let found = false

                for (let i = 0; i < list.length; ++i) {
                    if (list[i].id === activeWorkspaceId) {
                        found = true
                        break
                    }
                }

                if (!found) {
                    list.push({
                        kind: "workspace",
                        id: activeWorkspaceId,
                        name: activeWorkspaceNameFromIpc || String(activeWorkspaceId)
                    })
                    list.sort(function(a, b) {
                        return a.id - b.id
                    })
                }
            }

            let nextId = 1
            while (true) {
                let occupied = false

                for (let i = 0; i < list.length; ++i) {
                    if (list[i].id === nextId) {
                        occupied = true
                        break
                    }
                }

                if (!occupied)
                    break

                ++nextId
            }

            list.push({
                kind: "new",
                id: nextId,
                name: ""
            })

            workspaceItems = list
        }

        function applyWorkspaceJson(jsonText) {
            try {
                const parsed = JSON.parse(String(jsonText || "[]"))
                if (Array.isArray(parsed))
                    rebuildWorkspaceItems(parsed)
            } catch (error) {
                console.warn("workspace query failed:", error)
                rebuildWorkspaceItems([])
            }
        }

        function applyActiveJson(jsonText) {
            try {
                const parsed = JSON.parse(String(jsonText || "{}"))
                if (parsed && typeof parsed.id === "number") {
                    activeWorkspaceId = parsed.id
                    activeWorkspaceNameFromIpc = String(parsed.name || "").trim()
                }
            } catch (error) {
                if (Hyprland.focusedWorkspace) {
                    activeWorkspaceId = Hyprland.focusedWorkspace.id
                    activeWorkspaceNameFromIpc = String(Hyprland.focusedWorkspace.name || "").trim()
                }
            }
        }

        Process {
            id: workspaceQuery

            command: ["/usr/bin/hyprctl", "workspaces", "-j"]

            stdout: StdioCollector {
                onStreamFinished: workspaceArea.applyWorkspaceJson(this.text)
            }
        }

        Process {
            id: activeQuery

            command: ["/usr/bin/hyprctl", "activeworkspace", "-j"]

            stdout: StdioCollector {
                onStreamFinished: workspaceArea.applyActiveJson(this.text)
            }
        }

        Timer {
            interval: 300
            repeat: true
            running: true
            triggeredOnStart: true

            onTriggered: workspaceArea.refreshWorkspaceData()
        }

        Component.onCompleted: {
            if (Hyprland.focusedWorkspace) {
                activeWorkspaceId = Hyprland.focusedWorkspace.id
                activeWorkspaceNameFromIpc = String(Hyprland.focusedWorkspace.name || "").trim()
            }
            refreshWorkspaceData()
        }

        Row {
            id: workspaceTabRow

            width: workspaceArea.tabsWidth
            height: parent.height
            anchors.centerIn: parent
            spacing: workspaceArea.gap

            Repeater {
                model: workspaceArea.workspaceItems

                delegate: Item {
                    id: workspaceTab

                    readonly property bool isNewTab:
                        modelData && modelData.kind === "new"

                    readonly property bool isActive:
                        !isNewTab && modelData.id === workspaceArea.activeWorkspaceId

                    readonly property bool isEditing:
                        !isNewTab
                        && modelData.id === workspaceArea.editingWorkspaceId

                    width: isNewTab
                        ? workspaceArea.plusWidth
                        : isActive
                            ? workspaceArea.effectiveActiveWidth
                            : workspaceArea.effectiveInactiveWidth

                    height: parent.height

                    Behavior on width {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        id: capsule

                        anchors.centerIn: parent
                        width: parent.width
                        height: isActive ? panel.dp(27) : panel.dp(25)
                        radius: height / 2

                        color: {
                            if (isActive)
                                return panel.surfaceHigh
                            if (tabMouse.containsMouse)
                                return panel.surfaceContainer
                            return panel.surfaceLow
                        }

                        border.width: isActive ? panel.dp(0.5) : 0
                        border.color: isActive
                            ? Qt.rgba(
                                panel.colorOutline.r,
                                panel.colorOutline.g,
                                panel.colorOutline.b,
                                0.24
                            )
                            : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: 140
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        visible: !isActive && !isNewTab
                        anchors.centerIn: capsule
                        text: String(modelData.id)
                        color: tabMouse.containsMouse
                            ? panel.colorBgText
                            : panel.colorOutline

                        font.family: "Fira Sans"
                        font.pixelSize: panel.dp(9)
                        font.bold: true
                    }

                    Row {
                        visible: isActive && !isEditing

                        anchors {
                            left: capsule.left
                            right: capsule.right
                            verticalCenter: capsule.verticalCenter
                            leftMargin: panel.dp(9)
                            rightMargin: panel.dp(9)
                        }

                        spacing: panel.dp(6)

                        Text {
                            width: panel.dp(12)
                            text: String(modelData.id)
                            color: panel.colorPrimary

                            font.family: "Fira Sans"
                            font.pixelSize: panel.dp(9)
                            font.bold: true

                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            visible: workspaceArea.hasCustomName(modelData)
                            width: visible ? Math.max(0, parent.width - panel.dp(18)) : 0
                            text: String(modelData.name || "").trim()
                            color: panel.colorBgText

                            font.family: "Fira Sans"
                            font.pixelSize: panel.dp(10)
                            font.bold: true

                            elide: Text.ElideRight
                            maximumLineCount: 1
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    TextInput {
                        id: renameInput

                        visible: isEditing
                        z: 10

                        anchors {
                            left: capsule.left
                            right: capsule.right
                            verticalCenter: capsule.verticalCenter
                            leftMargin: panel.dp(9)
                            rightMargin: panel.dp(9)
                        }

                        text: workspaceArea.hasCustomName(modelData)
                            ? String(modelData.name || "").trim()
                            : ""
                        color: panel.colorBgText

                        font.family: "Fira Sans"
                        font.pixelSize: panel.dp(10)
                        font.bold: true

                        horizontalAlignment: TextInput.AlignHCenter
                        selectByMouse: true
                        maximumLength: 32
                        clip: true

                        Rectangle {
                            z: -1
                            anchors.fill: parent
                            anchors.margins: -panel.dp(3)
                            color: Qt.rgba(
                                panel.colorBackground.r,
                                panel.colorBackground.g,
                                panel.colorBackground.b,
                                0.20
                            )
                            border.width: panel.dp(0.5)
                            border.color: panel.colorPrimary
                            radius: panel.dp(6)
                        }

                        onVisibleChanged: {
                            if (visible) {
                                Qt.callLater(function() {
                                    forceActiveFocus()
                                    selectAll()
                                })
                            }
                        }

                        onAccepted: workspaceArea.saveRename(modelData.id, text)

                        Keys.onEscapePressed: function(event) {
                            workspaceArea.cancelRename()
                            event.accepted = true
                        }
                    }

                    MouseArea {
                        id: tabMouse

                        anchors.fill: parent
                        z: 5
                        enabled: !isEditing
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: function(mouse) {
                            if (isNewTab) {
                                workspaceArea.createWorkspace()
                                return
                            }

                            if (mouse.button === Qt.RightButton) {
                                workspaceArea.beginRename(modelData.id)
                            } else {
                                workspaceArea.focusWorkspace(modelData.id)
                            }
                        }
                    }

                    Text {
                        visible: isNewTab
                        anchors.centerIn: capsule
                        text: "+"
                        color: tabMouse.containsMouse
                            ? panel.colorPrimary
                            : panel.colorOutline

                        font.family: "Fira Sans"
                        font.pixelSize: panel.dp(14)
                        font.bold: true
                    }
                }
            }
        }
    }

    /*
     * ═════════════════════════════
     *
     * RIGHT SECTION
     *
     * ═════════════════════════════
     */
    Row {
        id: rightSection

        anchors {
            right: parent.right
            rightMargin: panel.dp(4)
            verticalCenter: parent.verticalCenter
        }

        spacing: panel.dp(4)

        /*
         * ─────────────────────────
         * SYSTEM TRAY CAPSULE
         * ─────────────────────────
         */
        /*
         * SYSTEM TRAY
         *
         * Use Quickshell's native StatusNotifierItem support here.
         * The tray item itself owns activation, scrolling and its DBus menu.
         * QsMenuAnchor is the supported way to display that menu.
         */
        Rectangle {
            id: systemTrayCapsule

            visible: sysTrayRow.width > 0
            height: panel.dp(26)
            width: sysTrayRow.width + panel.dp(12)
            radius: height / 2
            color: panel.surfaceLow

            Row {
                id: sysTrayRow

                anchors.centerIn: parent
                spacing: panel.dp(6)

                Repeater {
                    model: SystemTray.items

                    delegate: Item {
                        id: trayItem

                        required property var modelData

                        width: panel.dp(18)
                        height: panel.dp(18)

                        IconImage {
                            id: trayIcon

                            anchors.centerIn: parent
                            implicitSize: panel.dp(16)
                            source: modelData.icon
                        }

                        QsMenuAnchor {
                            id: trayMenuAnchor

                            menu: modelData.menu
                            anchor.item: trayItem
                        }

                        MouseArea {
                            id: trayMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons:
                                Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    if (modelData.hasMenu)
                                        trayMenuAnchor.open()
                                } else if (mouse.button === Qt.LeftButton) {
                                    if (modelData.onlyMenu && modelData.hasMenu)
                                        trayMenuAnchor.open()
                                    else
                                        modelData.activate()
                                } else if (mouse.button === Qt.MiddleButton) {
                                    modelData.secondaryActivate()
                                }
                            }

                            onWheel: (wheel) => {
                                const delta = wheel.angleDelta.y !== 0
                                    ? wheel.angleDelta.y
                                    : wheel.angleDelta.x

                                if (delta !== 0) {
                                    modelData.scroll(
                                        delta,
                                        wheel.angleDelta.x !== 0
                                    )
                                }

                                wheel.accepted = true
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            id: keyboardCapsule

            height: panel.dp(26)
            width: kbText.implicitWidth + panel.dp(14)
            radius: height / 2
            color: kbHover.containsMouse ? panel.surfaceHover : panel.surfaceLow

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            scale: kbHover.pressed ? 0.96 : kbHover.containsMouse ? 1.02 : 1.0

            Text {
                id: kbText

                anchors.centerIn: parent
                text: panel.kbLayout
                color: kbHover.containsMouse ? panel.colorBgText : panel.colorPrimary
                font.pixelSize: panel.dp(10)
                font.bold: true
            }

            MouseArea {
                id: kbHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    runCommand([
                        "hyprctl",
                        "switchxkblayout",
                        "all",
                        "next"
                    ])
                }
            }
        }

        /*
         * ─────────────────────────
         *
         * SYSTEM STATUS CAPSULE
         *
         * WIFI
         * BLUETOOTH
         * BATTERY
         *
         * ─────────────────────────
         */
        Rectangle {
            id: systemCapsule

            height: panel.dp(26)
            width: systemRow.width + panel.dp(14)
            radius: height / 2
            color: systemHover.containsMouse ? panel.surfaceHover : panel.surfaceLow
            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            scale: systemHover.pressed ? 0.97 : systemHover.containsMouse ? 1.015 : 1.0

            Row {
                id: systemRow

                anchors.centerIn: parent
                spacing: panel.dp(7)

                /*
                 * WIFI
                 */
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.wifiSignal <= 0 ? "\ue648" : panel.wifiSignal < 30 ? "\uf0b0" : panel.wifiSignal < 55 ? "\ue1d9" : panel.wifiSignal < 75 ? "\ue1da" : "\uf1eb"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: panel.dp(16)
                    font.weight: Font.Normal
                    color: panel.wifiSignal > 0 ? panel.colorBgText : panel.colorError
                }

                /*
                 * BLUETOOTH
                 */
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.btOn === 1 ? "\ue1a7" : "\ue1a8"
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: panel.dp(16)
                    font.weight: Font.Normal
                    color: panel.btOn === 1 ? panel.colorPrimary : panel.colorOutline
                }

                /*
                 * BATTERY
                 */
                Item {
                    id: androidBattery

                    width: panel.dp(22)
                    height: panel.dp(12)
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: batteryContainer

                        anchors.fill: parent
                        color: Qt.rgba(panel.colorBackground.r, panel.colorBackground.g, panel.colorBackground.b, 0.4)
                        border.color: panel.batteryLevel <= 20 ? panel.colorError : panel.charging ? panel.colorPrimary : panel.colorBgText
                        border.width: panel.dp(1.5)
                        radius: panel.dp(4)
                        clip: true

                        Rectangle {
                            id: batteryFill

                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            anchors.margins: panel.dp(1.5)
                            width: Math.max(0, (parent.width - panel.dp(3)) * (panel.batteryLevel / 100))
                            radius: panel.dp(2.5)
                            color: panel.batteryLevel <= 20 ? panel.colorError : panel.charging ? panel.colorPrimary : panel.colorBgText

                            Behavior on width {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutQuart
                                }
                            }

                            Text {
                                x: (batteryContainer.width / 2) - (width / 2) - panel.dp(1.5)
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: panel.dp(9)
                                font.bold: true
                                text: panel.charging ? "" : panel.batteryLevel >= 0 ? panel.batteryLevel : ""
                                color: panel.colorBackground
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            font.pixelSize: panel.dp(9)
                            font.bold: true
                            text: panel.charging ? "⚡" : panel.batteryLevel >= 0 ? panel.batteryLevel : ""
                            color: batteryContainer.border.color
                            z: -1
                        }
                    }

                    Rectangle {
                        anchors {
                            left: batteryContainer.right
                            leftMargin: panel.dp(1)
                            verticalCenter: batteryContainer.verticalCenter
                        }
                        width: panel.dp(1.5)
                        height: panel.dp(5)
                        radius: panel.dp(1)
                        color: batteryContainer.border.color
                    }
                }
            }

            MouseArea {
                id: systemHover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: controlCenter.toggleMain()
            }
        }
    }
}
