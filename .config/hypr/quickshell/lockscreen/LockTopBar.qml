import "../core"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Упрощённая верхняя панель для экрана блокировки
// (без лаунчера, трея и воркспейсов)
Rectangle {
    id: bar
    implicitHeight: 36
    color: Qt.rgba(28/255, 27/255, 31/255, 0.75)
    radius: 18

    property var controlCenter

    // Цвета из Colors.qml
    readonly property color colorPrimary: typeof Colors !== "undefined" ? Colors.primary : "#D0BCFF"
    readonly property color colorSurface: typeof Colors !== "undefined" ? Colors.surface : "#49454F"
    readonly property color colorBgText: typeof Colors !== "undefined" ? Colors.backgroundText : "#E6E1E5"
    readonly property color colorError: typeof Colors !== "undefined" ? Colors.error : "#F2B8B5"
    readonly property color colorOutline: typeof Colors !== "undefined" ? Colors.outline : "#938F96"

    property int wifiSignal: -1
    property int btOn: -1
    property int batteryLevel: -1
    property bool charging: false
    property string kbLayout: "US"

    Process { id: cmdRunner }
    function runCommand(commandLine: var) {
        cmdRunner.command = commandLine
        cmdRunner.running = true
    }

    // ── Проба Wi-Fi ─────────────────────────────────────────────────────
    Process {
        id: wifiProbe
        running: true
        command: ["sh", "-c", "sig=$(nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | grep '^\\*' | head -1 | cut -d: -f2); echo ${sig:-0}"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text.trim(), 10)
                bar.wifiSignal = isNaN(v) ? -1 : v
            }
        }
    }

    // ── Проба Bluetooth ─────────────────────────────────────────────────
    Process {
        id: btProbe
        running: true
        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: bar.btOn = parseInt(text.trim(), 10) || 0
        }
    }

    // ── Проба батареи ───────────────────────────────────────────────────
    Process {
        id: batteryProbe
        running: true
        command: ["sh", "-c", "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); if [ -n \"$b\" ]; then echo \"$(cat $b/capacity) $(cat $b/status)\"; else echo \"-1\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                bar.batteryLevel = parseInt(parts[0], 10)
                bar.charging = parts.length > 1 && parts[1] === "Charging"
            }
        }
    }

    // ── Раскладка клавиатуры ────────────────────────────────────────────
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                const lay = event.data.split(",").pop().trim().toLowerCase()
                bar.kbLayout = (lay.includes("ru") || lay.includes("russian")) ? "RU" : "US"
            }
        }
    }

    Process {
        id: kbInit
        running: true
        command: ["sh", "-c", "hyprctl devices -j 2>/dev/null | grep -o '\"active_keymap\":\"[^\"]*\"' | head -1 | cut -d'\"' -f4 | awk '{print toupper(substr($0, length($0)-1))}'"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) bar.kbLayout = text.trim()
        }
    }

    Timer { interval: 3000; running: true; repeat: true; onTriggered: wifiProbe.running = true }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: btProbe.running = true }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: batteryProbe.running = true }

    // ── Содержимое панели ───────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        spacing: 8

        // Слева — пусто (лаунчер убран)
        Item { Layout.fillWidth: true }

        // Справа — статусы + часы + ControlCenter
        RowLayout {
            spacing: 6

            // Раскладка
            Rectangle {
                width: 36; height: 26
                radius: 13
                color: kbHover.containsMouse 
                    ? Qt.rgba(bar.colorSurface.r, bar.colorSurface.g, bar.colorSurface.b, 0.4) 
                    : Qt.rgba(bar.colorSurface.r, bar.colorSurface.g, bar.colorSurface.b, 0.25)
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: bar.kbLayout
                    color: bar.colorPrimary
                    font.pixelSize: 11
                    font.bold: true
                }
                MouseArea {
                    id: kbHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: runCommand(["hyprctl", "switchxkblayout", "all", "next"])
                }
            }

            // Wi-Fi / BT / Батарея
            Rectangle {
                implicitWidth: trayRow.width + 16
                implicitHeight: 26
                radius: 13
                color: trayHover.containsMouse 
                    ? Qt.rgba(bar.colorSurface.r, bar.colorSurface.g, bar.colorSurface.b, 0.4) 
                    : Qt.rgba(bar.colorSurface.r, bar.colorSurface.g, bar.colorSurface.b, 0.25)
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    id: trayRow
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        color: bar.wifiSignal > 0 ? bar.colorBgText : bar.colorError
                        font.pixelSize: 13
                        text: bar.wifiSignal <= 0 ? "󰤮" :
                              bar.wifiSignal < 30 ? "󰤟" :
                              bar.wifiSignal < 55 ? "󰤢" :
                              bar.wifiSignal < 75 ? "󰤥" : "󰤨"
                    }

                    Text {
                        color: bar.btOn === 1 ? bar.colorBgText : bar.colorOutline
                        font.pixelSize: 13
                        text: bar.btOn === 1 ? "󰂯" : "󰂳"
                    }

                    Text {
                        color: bar.batteryLevel >= 0 && bar.batteryLevel <= 20 ? bar.colorError
                             : bar.charging ? "#81C784" : bar.colorBgText
                        font.pixelSize: 13
                        text: bar.charging ? "󱐋" :
                              bar.batteryLevel <= 10 ? "󰂎" :
                              bar.batteryLevel <= 35 ? "󰁼" :
                              bar.batteryLevel <= 60 ? "󰁾" :
                              bar.batteryLevel <= 90 ? "󰂀" : "󰁹"
                    }
                    
                    Text {
                        color: bar.batteryLevel >= 0 && bar.batteryLevel <= 20 ? bar.colorError : bar.colorBgText
                        font.pixelSize: 11
                        font.bold: true
                        text: bar.batteryLevel >= 0 ? bar.batteryLevel + "%" : ""
                    }
                }

                MouseArea {
    id: trayHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
}
            }

            // Часы
            Rectangle {
                width: 58; height: 26
                radius: 13
                color: clockHover.containsMouse 
                    ? Qt.rgba(bar.colorSurface.r, bar.colorSurface.g, bar.colorSurface.b, 0.4) 
                    : Qt.rgba(bar.colorSurface.r, bar.colorSurface.g, bar.colorSurface.b, 0.25)
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(), "HH:mm")
                    color: bar.colorBgText
                    font.pixelSize: 12
                    font.bold: true
                }

                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
                }
                
                MouseArea {
    id: clockHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
}
            }
        }
    }
}
