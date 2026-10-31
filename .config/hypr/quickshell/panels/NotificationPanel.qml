import QtQuick
import "../core"
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: notifRoot

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notification-center"
    exclusiveZone: -1
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { bottom: true; left: true; right: true; top: false }
    implicitHeight: Math.max(1, (notifRoot.screen ? notifRoot.screen.height : Screen.height) - 45)
    visible: open
    color: "transparent"

    property bool open: false
    property var notificationsList: []
    property var dismissedList: []
    property var expandedIds: ({})
    property int unreadCount: notificationsList.length

    readonly property color cPrimary: typeof Colors !== "undefined" && Colors.primary ? Colors.primary : "#D0BCFF"
    readonly property color cOnPrimary: typeof Colors !== "undefined" && Colors.onPrimary ? Colors.onPrimary : "#381E72"
    readonly property color cSurface: typeof Colors !== "undefined" && Colors.surface ? Colors.surface : "#1C1B1F"
    readonly property color cBackground: typeof Colors !== "undefined" && Colors.background ? Colors.background : cSurface
    readonly property color cOnSurface: typeof Colors !== "undefined" && Colors.surfaceText ? Colors.surfaceText : "#E6E1E5"
    readonly property color cOnSurfaceVariant: typeof Colors !== "undefined" && Colors.onSurfaceVariant ? Colors.onSurfaceVariant : "#CAC4D0"
    readonly property color cSurfaceContainer: typeof Colors !== "undefined" && Colors.surfaceContainer
        ? Colors.surfaceContainer
        : (typeof Colors !== "undefined" && Colors.surfaceVariant ? Colors.surfaceVariant : "#2B292F")
    readonly property color cSurfaceContainerHigh: typeof Colors !== "undefined" && Colors.surfaceContainerHigh
        ? Colors.surfaceContainerHigh
        : "#36343B"
    readonly property color cOutline: typeof Colors !== "undefined" && Colors.outline ? Colors.outline : "#938F99"
    readonly property color cError: typeof Colors !== "undefined" && Colors.error ? Colors.error : "#F2B8B5"
    readonly property color cOnError: typeof Colors !== "undefined" && Colors.onError ? Colors.onError : "#601410"
    readonly property color cBgText: typeof Colors !== "undefined" && Colors.backgroundText ? Colors.backgroundText : cOnSurface
    readonly property string iconFont: "Material Symbols Outlined"

    function unwrap(value, fallback) {
        if (value === undefined || value === null) return fallback
        if (typeof value === "object" && value.data !== undefined) return value.data
        return value
    }

    function field(notif, name, fallback) {
        if (!notif || notif[name] === undefined || notif[name] === null) return fallback
        return unwrap(notif[name], fallback)
    }

    function notificationId(notif) {
        return String(field(notif, "id", -1))
    }

    function appName(notif) {
        let value = field(notif, "appname", "System")
        if (!value || String(value).trim() === "") return "System"
        return String(value)
    }

    function summary(notif) { return String(field(notif, "summary", "Без заголовка")) }
    function body(notif) { return String(field(notif, "body", "")) }

    function urgency(notif) {
        let value = field(notif, "urgency", "normal")
        if (typeof value === "number") {
            if (value >= 2) return "critical"
            if (value === 1) return "normal"
            return "low"
        }
        return String(value).toLowerCase()
    }

    function isCritical(notif) { return urgency(notif) === "critical" }
    function iconPath(notif) { return String(field(notif, "icon_path", "")) }

    function fallbackIcon(notif) {
        const app = appName(notif).toLowerCase()
        if (app.indexOf("firefox") >= 0) return "language"
        if (app.indexOf("telegram") >= 0) return "send"
        if (app.indexOf("discord") >= 0) return "forum"
        if (app.indexOf("spotify") >= 0) return "music_note"
        if (app.indexOf("steam") >= 0) return "sports_esports"
        if (app.indexOf("bluetooth") >= 0) return "bluetooth"
        if (app.indexOf("network") >= 0 || app.indexOf("nm") >= 0) return "wifi"
        if (app.indexOf("battery") >= 0 || app.indexOf("power") >= 0) return "battery_alert"
        if (isCritical(notif)) return "error"
        return "notifications"
    }

    function timeText(notif) {
        let raw = field(notif, "timestamp", "")
        if (!raw) raw = field(notif, "time", "")
        if (!raw) return ""
        let d = new Date(raw)
        if (isNaN(d.getTime()) && /^\d+$/.test(String(raw))) {
            let n = Number(raw)
            if (n > 100000000000) d = new Date(n)
            else if (n > 1000000000) d = new Date(n * 1000)
        }
        if (isNaN(d.getTime())) return ""
        return Qt.formatTime(d, "HH:mm")
    }

    function progressValue(notif) {
        let p = Number(field(notif, "progress", -1))
        if (isNaN(p) || p < 0) return -1
        if (p > 1) p /= 100
        return Math.max(0, Math.min(1, p))
    }

    function actionsFor(notif) {
        let a = notif ? unwrap(notif.actions, null) : null
        if (!a) return []
        if (Array.isArray(a)) return a
        if (typeof a === "string") {
            try {
                const parsed = JSON.parse(a)
                if (Array.isArray(parsed)) return parsed
            } catch (e) {}
        }
        return []
    }

    function actionLabel(action) {
        if (action === undefined || action === null) return "Открыть"
        if (typeof action === "string") return action
        if (action.label !== undefined) return String(unwrap(action.label, "Открыть"))
        if (action.name !== undefined) return String(unwrap(action.name, "Открыть"))
        if (action.id !== undefined) return String(unwrap(action.id, "Открыть"))
        return "Открыть"
    }

    function triggerAction(notif, actionId) {
        const id = field(notif, "id", null)
        if (id === null) return
        actionProcess.command = actionId
            ? ["dunstctl", "action", id.toString(), actionId.toString()]
            : ["dunstctl", "action", id.toString()]
        actionProcess.running = true
    }

    function deleteSingleNotification(notif, remember) {
        const id = field(notif, "id", null)
        if (remember !== false && notif)
            dismissedList = [notif].concat(dismissedList).slice(0, 6)
        if (id !== null) {
            removeProcess.command = ["dunstctl", "history-rm", id.toString()]
            removeProcess.running = true
        }
    }

    function clearAll() {
        if (notificationsList.length)
            dismissedList = notificationsList.slice(0, 6).concat(dismissedList).slice(0, 6)
        clearAllProcess.running = true
    }

    function toggleExpanded(notif) {
        const id = notificationId(notif)
        const next = {}
        for (let k in expandedIds) next[k] = expandedIds[k]
        next[id] = !next[id]
        expandedIds = next
    }

    function isExpanded(notif) { return !!expandedIds[notificationId(notif)] }

    function show(): void {
        open = true
        fetchDunstHistory()
    }

    function close(): void {
        open = false
        contextMenu.close()
    }

    function toggle(): void {
        if (open) close()
        else show()
    }

    // Keep the same public IPC surface as Launcher, Control Center and Binds.
    IpcHandler {
        target: "notifications"
        function toggle(): void { notifRoot.toggle() }
        function open(): void { notifRoot.show() }
        function close(): void { notifRoot.close() }
        function refresh(): void { notifRoot.fetchDunstHistory() }
    }

    function fetchDunstHistory() { dunstProcess.running = true }

    Process {
        id: dunstProcess
        command: ["dunstctl", "history"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text || text.trim() === "") {
                    notifRoot.notificationsList = []
                    return
                }
                try {
                    const parsed = JSON.parse(text)
                    if (parsed && parsed.data && parsed.data.length > 0) {
                        let list = parsed.data[0]
                        if (!Array.isArray(list)) list = []
                        notifRoot.notificationsList = list
                    } else {
                        notifRoot.notificationsList = []
                    }
                } catch (e) {
                    notifRoot.notificationsList = []
                }
            }
        }
    }

    Process { id: removeProcess; stdout: StdioCollector { onStreamFinished: fetchDunstHistory() } }
    Process { id: actionProcess; stdout: StdioCollector { onStreamFinished: fetchDunstHistory() } }
    Process { id: clearAllProcess; command: ["dunstctl", "history-clear"]; stdout: StdioCollector { onStreamFinished: fetchDunstHistory() } }

    Timer {
        interval: 4000
        running: notifRoot.open
        repeat: true
        onTriggered: notifRoot.fetchDunstHistory()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: notifRoot.close()
    }

    Menu {
        id: contextMenu
        property var targetNotif: null

        background: Rectangle {
            implicitWidth: 190
            color: notifRoot.cSurfaceContainerHigh
            radius: 18
            border.color: Qt.rgba(notifRoot.cOutline.r, notifRoot.cOutline.g, notifRoot.cOutline.b, 0.16)
        }

        MenuItem {
            text: "Открыть"
            contentItem: Text {
                text: parent.text
                color: notifRoot.cOnSurface
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            onTriggered: if (contextMenu.targetNotif) notifRoot.triggerAction(contextMenu.targetNotif)
        }

        MenuItem {
            text: "Удалить"
            contentItem: Text {
                text: parent.text
                color: notifRoot.cError
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            onTriggered: if (contextMenu.targetNotif) notifRoot.deleteSingleNotification(contextMenu.targetNotif)
        }
    }

    Item {
        id: frame
        anchors { top: parent.top; left: parent.left }
        anchors.leftMargin: 15

        // Fixed, responsive dimensions; users cannot resize this panel.
        width: Math.min(430, Math.max(320, Screen.width - 30))
        height: Math.min(690, Math.max(380, Screen.height - 60))
        opacity: notifRoot.open ? 1 : 0
        scale: notifRoot.open ? 1 : 0.965
        y: notifRoot.open ? 0 : 18

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.04 } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Rectangle {
            anchors.fill: parent
            radius: 32
            color: Qt.rgba(notifRoot.cSurface.r, notifRoot.cSurface.g, notifRoot.cSurface.b, 0.98)
            border.color: Qt.rgba(notifRoot.cOutline.r, notifRoot.cOutline.g, notifRoot.cOutline.b, 0.14)
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "Уведомления"
                        color: notifRoot.cOnSurface
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }

                    Text {
                        text: notifRoot.notificationsList.length > 0
                            ? notifRoot.notificationsList.length + (notifRoot.notificationsList.length === 1 ? " новое уведомление" : " уведомлений")
                            : "Всё чисто"
                        color: notifRoot.cOnSurfaceVariant
                        font.pixelSize: 12
                    }
                }

                Rectangle {
                    Layout.preferredWidth: clearText.implicitWidth + 26
                    Layout.preferredHeight: 38
                    radius: 19
                    color: clearMouse.containsMouse
                        ? Qt.rgba(notifRoot.cPrimary.r, notifRoot.cPrimary.g, notifRoot.cPrimary.b, 0.28)
                        : Qt.rgba(notifRoot.cPrimary.r, notifRoot.cPrimary.g, notifRoot.cPrimary.b, 0.14)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "Очистить"
                        color: notifRoot.cPrimary
                        font.pixelSize: 12
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notifRoot.clearAll()
                    }
                }
            }


            ListView {
                id: notificationListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 9
                boundsBehavior: Flickable.StopAtBounds
                model: notifRoot.notificationsList

                delegate: Item {
                    id: notificationDelegate
                    required property var modelData
                    width: ListView.view.width
                    property bool expanded: notifRoot.isExpanded(modelData)
                    property real swipeX: 0
                    property var actionList: notifRoot.actionsFor(modelData)
                    property real progress: notifRoot.progressValue(modelData)

                    height: Math.max(
                        82,
                        expanded
                            ? 82 + Math.min(210, notifBody.implicitHeight + actionRow.implicitHeight + (progress >= 0 ? 34 : 0) + 30)
                            : 82
                    )

                    Behavior on height {
                        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        id: card
                        x: notificationDelegate.swipeX
                        width: parent.width
                        height: parent.height
                        radius: notifRoot.isCritical(modelData) ? 26 : 24
                        color: notifRoot.isCritical(modelData)
                            ? Qt.rgba(notifRoot.cError.r, notifRoot.cError.g, notifRoot.cError.b, 0.13)
                            : (cardMouse.containsMouse ? notifRoot.cSurfaceContainerHigh : notifRoot.cSurfaceContainer)
                        border.width: notifRoot.isCritical(modelData) ? 1 : 0
                        border.color: Qt.rgba(notifRoot.cError.r, notifRoot.cError.g, notifRoot.cError.b, 0.45)

                        Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 13
                            spacing: 11

                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                Layout.alignment: Qt.AlignTop
                                radius: 16
                                color: notifRoot.isCritical(modelData)
                                    ? Qt.rgba(notifRoot.cError.r, notifRoot.cError.g, notifRoot.cError.b, 0.25)
                                    : Qt.rgba(notifRoot.cPrimary.r, notifRoot.cPrimary.g, notifRoot.cPrimary.b, 0.16)

                                Image {
                                    id: notificationIconImage
                                    anchors.fill: parent
                                    anchors.margins: 9
                                    visible: notifRoot.iconPath(modelData).length > 0
                                    source: visible ? "file://" + notifRoot.iconPath(modelData) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !notificationIconImage.visible
                                    text: notifRoot.fallbackIcon(modelData)
                                    font.family: notifRoot.iconFont
                                    font.pixelSize: 23
                                    color: notifRoot.isCritical(modelData) ? notifRoot.cError : notifRoot.cPrimary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Text {
                                        text: notifRoot.appName(modelData)
                                        color: notifRoot.cOnSurfaceVariant
                                        font.pixelSize: 10
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: notifRoot.timeText(modelData)
                                        color: notifRoot.cOutline
                                        font.pixelSize: 10
                                    }
                                }

                                Text {
                                    text: notifRoot.summary(modelData)
                                    color: notifRoot.cOnSurface
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    id: notifBody
                                    Layout.fillWidth: true
                                    text: notifRoot.body(modelData)
                                    color: notifRoot.cOnSurfaceVariant
                                    font.pixelSize: 12
                                    maximumLineCount: notificationDelegate.expanded ? 8 : 2
                                    wrapMode: Text.WordWrap
                                    elide: notificationDelegate.expanded ? Text.ElideNone : Text.ElideRight
                                }

                                Rectangle {
                                    visible: notificationDelegate.progress >= 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 7
                                    radius: 3.5
                                    color: Qt.rgba(notifRoot.cOnSurface.r, notifRoot.cOnSurface.g, notifRoot.cOnSurface.b, 0.10)

                                    Rectangle {
                                        width: parent.width * notificationDelegate.progress
                                        height: parent.height
                                        radius: 3.5
                                        color: notifRoot.cPrimary
                                    }
                                }

                                RowLayout {
                                    id: actionRow
                                    Layout.fillWidth: true
                                    visible: notificationDelegate.expanded && notificationDelegate.actionList.length > 0
                                    spacing: 6

                                    Repeater {
                                        model: notificationDelegate.actionList

                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.preferredWidth: Math.min(145, actionLabelText.implicitWidth + 22)
                                            Layout.preferredHeight: 30
                                            radius: 15
                                            color: actionMouse.containsMouse
                                                ? Qt.rgba(notifRoot.cPrimary.r, notifRoot.cPrimary.g, notifRoot.cPrimary.b, 0.25)
                                                : Qt.rgba(notifRoot.cPrimary.r, notifRoot.cPrimary.g, notifRoot.cPrimary.b, 0.13)

                                            Text {
                                                id: actionLabelText
                                                anchors.centerIn: parent
                                                text: notifRoot.actionLabel(modelData)
                                                color: notifRoot.cPrimary
                                                font.pixelSize: 10
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                id: actionMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: notifRoot.triggerAction(
                                                    notificationDelegate.modelData,
                                                    (modelData && modelData.id !== undefined)
                                                        ? notifRoot.unwrap(modelData.id, "")
                                                        : ""
                                                )
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignTop
                                text: notificationDelegate.expanded ? "expand_less" : "expand_more"
                                font.family: notifRoot.iconFont
                                font.pixelSize: 19
                                color: notifRoot.cOnSurfaceVariant
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    contextMenu.targetNotif = modelData
                                    const globalPos = cardMouse.mapToItem(null, mouse.x, mouse.y)
                                    contextMenu.popup(globalPos.x, globalPos.y)
                                } else {
                                    notifRoot.toggleExpanded(modelData)
                                }
                            }
                        }
                    }
                }
            }


        }

        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 22
            anchors.bottomMargin: 14
            width: 72
            height: 4
            radius: 2
            color: notifRoot.cPrimary
            opacity: 0.55
        }
    }

    Text {
        visible: open && notificationsList.length === 0
        anchors.left: frame.left
        anchors.top: frame.top
        anchors.leftMargin: 30
        anchors.topMargin: 150
        width: frame.width - 60
        horizontalAlignment: Text.AlignHCenter
        text: "notifications_off"
        font.family: notifRoot.iconFont
        font.pixelSize: 52
        color: notifRoot.cOutline
        opacity: 0.45
    }

    Text {
        visible: open && notificationsList.length === 0
        anchors.left: frame.left
        anchors.top: frame.top
        anchors.leftMargin: 30
        anchors.topMargin: 210
        width: frame.width - 60
        horizontalAlignment: Text.AlignHCenter
        text: "Всё чисто"
        color: notifRoot.cOnSurface
        font.pixelSize: 18
        font.weight: Font.DemiBold
    }

    Text {
        visible: open && notificationsList.length === 0
        anchors.left: frame.left
        anchors.top: frame.top
        anchors.leftMargin: 30
        anchors.topMargin: 240
        width: frame.width - 60
        horizontalAlignment: Text.AlignHCenter
        text: "Новых уведомлений нет"
        color: notifRoot.cOnSurfaceVariant
        font.pixelSize: 12
    }
}
