import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../core" as ColorsImport

Item {
    id: root
    property bool btEnabled: false
    property var pairedDevices: []
    property var discoveredDevices: []
    property bool showNewDevicesMenu: false
    property bool isScanning: false
    
    property string connectingMac: ""
    property var ctl: null
    readonly property var colors: ColorsImport.Colors

    // Экспортируем данные для шапки в ControlCenter
    property string headerTitle: root.showNewDevicesMenu ? "Новые устройства" : "Bluetooth"
    property bool hasHeaderToggle: !root.showNewDevicesMenu
    property bool headerToggleState: root.btEnabled

    function onHeaderToggleClicked() {
        var newState = !btEnabled
        btEnabled = newState
        btCmd.command = ["sh", "-c", "bluetoothctl power " + (newState ? "on" : "off")]
        btCmd.running = true
    }

    function onBackClicked() {
        if (root.showNewDevicesMenu) {
            root.stopDiscovery()
            root.showNewDevicesMenu = false
            root.connectingMac = ""
        } else if (root.ctl && root.ctl.view !== "main") {
            root.ctl.view = "main"
        }
    }

    readonly property color bgColor: (colors && colors.surface) ? colors.surface : "#0F2023"
    readonly property color primaryColor: (colors && colors.primary) ? colors.primary : "#82D5D1"
    readonly property color onPrimaryColor: (colors && colors.onPrimary) ? colors.onPrimary : "#003735"
    readonly property color textColor: "#E0E3E1"
    readonly property color subtextColor: "#8E938F"
    readonly property color iconBgColor: "#1E2A2D"

    function getDeviceIcon(name) {
        if (!btEnabled) return "\ue1a8"
        var lower = (name || "").toLowerCase()
        if (lower.includes("headphone") || lower.includes("tws") || lower.includes("buds") || lower.includes("airpods") || lower.includes("dots")) return "\ue310"
        if (lower.includes("audio") || lower.includes("speaker") || lower.includes("sound")) return "\ue505"
        if (lower.includes("phone") || lower.includes("galaxy") || lower.includes("iphone")) return "\ue32c"
        if (lower.includes("mouse") || lower.includes("keyboard")) return "\ue315"
        return "\ue1a7"
    }

    Process {
        id: discoveryProcess
        command: ["sh", "-c", "bluetoothctl default-agent >/dev/null; bluetoothctl scan on"]
        onRunningChanged: root.isScanning = running
    }

    function startDiscovery() {
        if (btEnabled && !discoveryProcess.running) discoveryProcess.running = true
    }

    function stopDiscovery() {
        if (discoveryProcess.running) discoveryProcess.running = false
    }

    Process {
        id: mainDataCollector
        running: true
        command: ["python3", "-c", "
import subprocess, json, re

def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL)
    except:
        return ''

power = 'Powered: yes' in run('bluetoothctl show')
if not power:
    print(json.dumps({'power': False, 'paired': [], 'discovered': []}))
    exit()

info_out = run('bluetoothctl info')
connected_macs = set(re.findall(r'Device\s+([0-9A-Fa-f:]+)', info_out))

if not connected_macs:
    conn_out = run('bluetoothctl devices Connected')
    for line in conn_out.strip().split('\\n'):
        parts = line.strip().split(' ', 2)
        if len(parts) >= 2 and parts[0] == 'Device':
            connected_macs.add(parts[1])

paired_out = run('bluetoothctl devices Paired')
paired = []
paired_macs = set()

for line in paired_out.strip().split('\\n'):
    parts = line.strip().split(' ', 2)
    if len(parts) >= 2 and parts[0] == 'Device':
        mac = parts[1]
        name = parts[2] if len(parts) > 2 else mac
        paired_macs.add(mac)
        paired.append({
            'mac': mac,
            'name': name,
            'connected': mac in connected_macs
        })

paired.sort(key=lambda x: not x['connected'])

all_out = run('bluetoothctl devices')
discovered = []
mac_regex = re.compile(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$')

for line in all_out.strip().split('\\n'):
    parts = line.strip().split(' ', 2)
    if len(parts) >= 2 and parts[0] == 'Device':
        mac = parts[1]
        name = parts[2] if len(parts) > 2 else ''
        if mac not in paired_macs and name and not mac_regex.match(name):
            discovered.append({
                'mac': mac,
                'name': name
            })

print(json.dumps({'power': True, 'paired': paired, 'discovered': discovered}))
"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim())
                    root.btEnabled = data.power

                    if (!data.power) {
                        root.pairedDevices = []
                        root.discoveredDevices = []
                        root.connectingMac = ""
                        return
                    }

                    root.pairedDevices = data.paired || []
                    root.discoveredDevices = data.discovered || []

                    if (!btCmd.running) {
                        root.connectingMac = ""
                    }
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!btCmd.running) mainDataCollector.running = true
        }
    }

    Process { 
        id: btCmd 
        onRunningChanged: {
            if (!running) {
                mainDataCollector.running = true
            }
        }
    }

    function toggleConnect(mac, isConnected) {
        root.connectingMac = mac
        var action = isConnected ? "disconnect" : "connect"
        
        var cmd = "bluetoothctl " + action + " " + mac
        if (!isConnected) {
            cmd += " && sleep 2 && python3 -c \"import subprocess; " +
                   "sinks = subprocess.check_output(['pactl', 'list', 'short', 'sinks'], text=True); " +
                   "[subprocess.run(['pactl', 'set-default-sink', l.split('\\\\t')[1]]) for l in sinks.splitlines() if '" + mac.replace(':', '_') + "' in l or 'bluez_output' in l]\""
        }

        btCmd.command = ["sh", "-c", cmd]
        btCmd.running = true
    }

    function pairNewDevice(mac, name) {
        root.connectingMac = mac
        
        var pyScript = "
import subprocess, time

p = subprocess.Popen(['bluetoothctl'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

def send_cmd(cmd):
    p.stdin.write(cmd + '\\n')
    p.stdin.flush()
    time.sleep(1)

send_cmd('power on')
send_cmd('agent on')
send_cmd('default-agent')
send_cmd('pair " + mac + "')
time.sleep(3)
send_cmd('trust " + mac + "')
time.sleep(1)
send_cmd('connect " + mac + "')
time.sleep(2)
send_cmd('exit')
p.wait()

time.sleep(1)
try:
    sinks = subprocess.check_output(['pactl', 'list', 'short', 'sinks'], text=True)
    for line in sinks.splitlines():
        if '" + mac.replace(':', '_') + "' in line or 'bluez_output' in line:
            sink_name = line.split('\\t')[1]
            subprocess.run(['pactl', 'set-default-sink', sink_name])
            inputs = subprocess.check_output(['pactl', 'list', 'short', 'sink-inputs'], text=True)
            for input_line in inputs.splitlines():
                idx = input_line.split('\\t')[0]
                subprocess.run(['pactl', 'move-sink-input', idx, sink_name])
            break
except Exception as e:
    print(e)
"
        btCmd.command = ["python3", "-c", pyScript]
        btCmd.running = true
    }

    Rectangle {
        anchors.fill: parent
        color: root.bgColor
        radius: 28

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Flickable {
                visible: !root.showNewDevicesMenu
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: savedLayout.height
                clip: true

                ColumnLayout {
                    id: savedLayout
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: btEnabled ? root.pairedDevices : []
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 52
                            radius: 16
                            color: devMouse.containsMouse ? "#1A2629" : "transparent"
                            scale: devMouse.pressed ? 0.98 : 1.0

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 14

                                Rectangle {
                                    width: 40; height: 40; radius: 20
                                    color: modelData.connected ? root.primaryColor : root.iconBgColor

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: getDeviceIcon(modelData.name)
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 20
                                        color: modelData.connected ? root.onPrimaryColor : root.textColor
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: modelData.name
                                        color: root.textColor
                                        font.pixelSize: 15
                                        font.weight: modelData.connected ? Font.Medium : Font.Normal
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: root.connectingMac === modelData.mac 
                                              ? (modelData.connected ? "Отключение..." : "Подключение...")
                                              : (modelData.connected ? "Подключено" : "Сохранено")
                                        color: modelData.connected ? root.primaryColor : root.subtextColor
                                        font.pixelSize: 12
                                    }
                                }

                                Rectangle {
                                    width: 1; height: 24
                                    color: "#2B3537"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: "\ue8b8"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 20
                                    color: root.textColor
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                id: devMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleConnect(modelData.mac, modelData.connected)
                            }
                        }
                    }

                    Rectangle {
                        visible: btEnabled
                        Layout.fillWidth: true
                        height: 48
                        radius: 16
                        color: pairMouse.containsMouse ? "#1A2629" : "transparent"
                        scale: pairMouse.pressed ? 0.98 : 1.0

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            spacing: 14

                            Text {
                                text: "\ue145"
                                font.family: "Material Symbols Outlined"
                                color: root.textColor
                                font.pixelSize: 22
                            }

                            Text {
                                text: "Подключить новое устройство"
                                color: root.textColor
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: pairMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.showNewDevicesMenu = true
                                root.startDiscovery()
                                mainDataCollector.running = true
                            }
                        }
                    }
                }
            }

            Flickable {
                visible: root.showNewDevicesMenu
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: searchLayout.height
                clip: true

                ColumnLayout {
                    id: searchLayout
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: root.discoveredDevices
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 52
                            radius: 16
                            color: newDevMouse.containsMouse ? "#1A2629" : "transparent"
                            scale: newDevMouse.pressed ? 0.98 : 1.0

                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 14

                                Rectangle {
                                    width: 40; height: 40; radius: 20
                                    color: root.iconBgColor

                                    Text {
                                        anchors.centerIn: parent
                                        text: getDeviceIcon(modelData.name)
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 20
                                        color: root.textColor
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: modelData.name
                                        color: root.textColor
                                        font.pixelSize: 15
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        visible: root.connectingMac === modelData.mac
                                        text: "Сопряжение..."
                                        color: root.primaryColor
                                        font.pixelSize: 12
                                    }
                                }

                                Text {
                                    text: "\ue145"
                                    font.family: "Material Symbols Outlined"
                                    color: root.subtextColor
                                    font.pixelSize: 20
                                }
                            }

                            MouseArea {
                                id: newDevMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pairNewDevice(modelData.mac, modelData.name)
                            }
                        }
                    }

                    Text {
                        visible: root.discoveredDevices.length === 0
                        text: root.isScanning ? "Поиск устройств..." : "Устройства не найдены"
                        color: root.subtextColor
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 20
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignRight
                width: 84
                height: 36
                radius: 18
                color: root.primaryColor
                scale: doneMouse.pressed ? 0.95 : 1.0

                Behavior on scale { NumberAnimation { duration: 100 } }

                Text {
                    anchors.centerIn: parent
                    text: "Готово"
                    color: root.onPrimaryColor
                    font.pixelSize: 14
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: doneMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.stopDiscovery()
                        if (ctl && ctl.close) ctl.close()
                    }
                }
            }
        }
    }
}
