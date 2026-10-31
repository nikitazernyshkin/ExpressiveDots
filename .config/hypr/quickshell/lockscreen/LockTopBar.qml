import "../core"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Lock-screen top bar: informational only until the session is unlocked.
Item {
    id: bar
    implicitHeight: 38
    height: implicitHeight

    signal quickSettingsRequested()
    signal notificationsRequested()
    signal trayRequested()

    property int wifiSignal: -1
    property int btOn: -1
    property int batteryLevel: -1
    property bool charging: false
    property string batteryStatus: "Unknown"
    property string kbLayout: "US"

    readonly property color colorPrimary: Colors.primary
    readonly property color colorSurface: Colors.surface
    readonly property color colorSurfaceVariant: Colors.surfaceVariant
    readonly property color colorBgText: Colors.backgroundText
    readonly property color colorError: Colors.error
    readonly property color colorOutline: Colors.outline
    readonly property color colorBackground: Colors.background
    readonly property color surfaceLow: Qt.rgba(colorSurface.r, colorSurface.g, colorSurface.b, 0.82)
    readonly property color surfaceContainer: Qt.rgba(colorSurfaceVariant.r, colorSurfaceVariant.g, colorSurfaceVariant.b, 0.84)
    readonly property color surfaceHigh: Qt.rgba(colorSurfaceVariant.r, colorSurfaceVariant.g, colorSurfaceVariant.b, 0.96)
    readonly property color surfaceHover: Qt.rgba(colorPrimary.r, colorPrimary.g, colorPrimary.b, 0.16)

    Process {
        id: wifiProbe
        running: true
        command: ["sh", "-c", "sig=$(nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | awk -F: '$1==\"*\" {print $2; exit}'); echo ${sig:--1}"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text.trim(), 10); bar.wifiSignal = isNaN(v) ? -1 : v } }
    }
    Process {
        id: btProbe
        running: true
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: bar.btOn = parseInt(text.trim(), 10) || 0 }
    }
    Process {
        id: batteryProbe
        running: true
        // Find a real power-supply entry of type Battery instead of blindly taking BAT*.
        // Emit a fresh value on every poll; if no battery is available, show unknown rather than 100%.
        command: ["sh", "-c", "for b in /sys/class/power_supply/*; do [ -r \"$b/capacity\" ] || continue; t=$(cat \"$b/type\" 2>/dev/null); case \"$t:$b\" in Battery:*|*:*/BAT*) c=$(cat \"$b/capacity\" 2>/dev/null); s=$(cat \"$b/status\" 2>/dev/null); case \"$c\" in ''|*[!0-9]*) continue;; esac; [ \"$c\" -le 100 ] || c=100; echo \"$c ${s:-Unknown}\"; exit 0;; esac; done; echo '-1 Unknown'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                const value = parseInt(parts[0], 10)
                bar.batteryLevel = (!isNaN(value) && value >= 0 && value <= 100) ? value : -1
                bar.batteryStatus = parts.length > 1 ? parts.slice(1).join(" ") : "Unknown"
                bar.charging = bar.batteryStatus === "Charging"
            }
        }
    }
    Process {
        id: kbInit
        running: true
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | grep -o '\"active_keymap\":\"[^\"]*\"' | head -1 | cut -d'\"' -f4 | awk '{print toupper(substr($0, length($0)-1))}'"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) bar.kbLayout = text.trim() }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const lay = event.data.split(",").pop().trim().toLowerCase()
                bar.kbLayout = (lay.includes("ru") || lay.includes("russian")) ? "RU" : "US"
            }
        }
    }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: wifiProbe.running = true }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: btProbe.running = true }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: batteryProbe.running = true }

    // LEFT: time island.
    Rectangle {
        id: clockCapsule
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        height: 30
        width: clockText.implicitWidth + 24
        radius: height / 2
        color: clockHover.containsMouse ? bar.surfaceHover : bar.surfaceLow
        border.width: 1
        border.color: Qt.rgba(bar.colorOutline.r, bar.colorOutline.g, bar.colorOutline.b, 0.16)
        Behavior on color { ColorAnimation { duration: 160 } }
        Text {
            id: clockText
            anchors.centerIn: parent
            text: Qt.formatDateTime(new Date(), "HH:mm")
            color: clockHover.containsMouse ? bar.colorPrimary : bar.colorBgText
            font.pixelSize: 12
            font.bold: true
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Timer { interval: 1000; running: true; repeat: true; onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm") }
        MouseArea { id: clockHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bar.notificationsRequested() }
    }

    // CENTER: meaningful lock-screen status instead of desktop workspaces.
    Rectangle {
        id: lockStatusCapsule
        anchors.centerIn: parent
        height: 30
        width: lockStatusRow.implicitWidth + 26
        radius: height / 2
        color: bar.surfaceLow
        border.width: 1
        border.color: Qt.rgba(bar.colorOutline.r, bar.colorOutline.g, bar.colorOutline.b, 0.16)
        Row {
            id: lockStatusRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: "\ue897"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 16
                color: bar.colorPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text { text: "ДОБРО ПОЖАЛОВАТЬ"; color: bar.colorBgText; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.7 }
                Text { text: Qt.formatDateTime(new Date(), "dddd, d MMMM"); color: bar.colorOutline; font.pixelSize: 9 }
            }
        }
    }

    // RIGHT: tray icons, layout and status indicators.
    Row {
        id: rightSection
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 5

        Rectangle {
            id: systemTrayCapsule
            visible: sysTrayRow.width > 0
            height: 30
            width: sysTrayRow.width + 16
            radius: height / 2
            color: bar.surfaceLow
            border.width: 1
            border.color: Qt.rgba(bar.colorOutline.r, bar.colorOutline.g, bar.colorOutline.b, 0.16)
            Row {
                id: sysTrayRow
                anchors.centerIn: parent
                spacing: 7
                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        required property var modelData
                        width: 18; height: 18
                        IconImage { anchors.centerIn: parent; implicitSize: 16; source: modelData.icon ?? "" }
                    }
                }
            }
        }

        Rectangle {
            id: keyboardCapsule
            height: 30
            width: kbText.implicitWidth + 18
            radius: height / 2
            color: bar.surfaceLow
            border.width: 1
            border.color: Qt.rgba(bar.colorOutline.r, bar.colorOutline.g, bar.colorOutline.b, 0.16)
            Text { id: kbText; anchors.centerIn: parent; text: bar.kbLayout; color: bar.colorPrimary; font.pixelSize: 10; font.bold: true }
        }

        Rectangle {
            id: systemCapsule
            height: 30
            width: systemRow.implicitWidth + 20
            radius: height / 2
            color: systemHover.containsMouse ? bar.surfaceHover : bar.surfaceLow
            border.width: 1
            border.color: Qt.rgba(bar.colorOutline.r, bar.colorOutline.g, bar.colorOutline.b, 0.16)
            Behavior on color { ColorAnimation { duration: 160 } }
            Row {
                id: systemRow
                anchors.centerIn: parent
                spacing: 7
                Text { anchors.verticalCenter: parent.verticalCenter; text: bar.wifiSignal < 0 ? "\ue648" : bar.wifiSignal < 30 ? "\uf0b0" : bar.wifiSignal < 55 ? "\ue1d9" : bar.wifiSignal < 75 ? "\ue1da" : "\uf1eb"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; color: bar.wifiSignal >= 0 ? bar.colorBgText : bar.colorOutline }
                Text { anchors.verticalCenter: parent.verticalCenter; text: bar.btOn === 1 ? "\ue1a7" : "\ue1a8"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; color: bar.btOn === 1 ? bar.colorPrimary : bar.colorOutline }
                Item {
                    id: androidBattery
                    width: 22
                    height: 12
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        id: batteryContainer
                        anchors.fill: parent
                        color: Qt.rgba(bar.colorBackground.r, bar.colorBackground.g, bar.colorBackground.b, 0.4)
                        border.color: bar.batteryLevel >= 0 && bar.batteryLevel <= 20 ? bar.colorError : bar.charging ? bar.colorPrimary : bar.colorBgText
                        border.width: 1.5
                        radius: 4
                        clip: true

                        Rectangle {
                            id: batteryFill
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            anchors.margins: 1.5
                            width: bar.batteryLevel < 0 ? 0 : Math.max(0, (parent.width - 3) * Math.max(0, Math.min(100, bar.batteryLevel)) / 100)
                            radius: 2.5
                            color: batteryContainer.border.color
                            Behavior on width {
                                NumberAnimation { duration: 300; easing.type: Easing.OutQuart }
                            }

                            Text {
                                anchors.centerIn: parent
                                font.pixelSize: 9
                                font.bold: true
                                text: bar.charging ? "" : bar.batteryLevel >= 0 ? bar.batteryLevel : ""
                                color: bar.colorBackground
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            font.pixelSize: 9
                            font.bold: true
                            text: bar.charging ? "⚡" : bar.batteryLevel >= 0 ? bar.batteryLevel : ""
                            color: batteryContainer.border.color
                            z: -1
                        }
                    }

                    Rectangle {
                        anchors {
                            left: batteryContainer.right
                            leftMargin: 1
                            verticalCenter: batteryContainer.verticalCenter
                        }
                        width: 1.5
                        height: 5
                        radius: 1
                        color: batteryContainer.border.color
                    }
                }
            }
            MouseArea { id: systemHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bar.quickSettingsRequested() }
        }
    }
}
