import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../core"

Item {
    id: root
    property string currentNetwork: ""
    property int currentSignal: 0
    property bool wifiEnabled: true
    property var networks: []
    property var saved: []
    property string askSsid: ""
    property var ctl: null

    function refresh() { wifiScan.running = true }

    // Безопасное получение цветов через ctl (или дефолтные Material 3)
    readonly property color cPrimary: ctl && typeof Colors !== "undefined" && Colors.primary ? Colors.primary : "#D0BCFF"
    readonly property color cOnPrimary: ctl && typeof Colors !== "undefined" && Colors.onPrimary ? Colors.onPrimary : "#381E72"
    readonly property color cSurface: ctl && typeof Colors !== "undefined" && Colors.surface ? Colors.surface : "#1C1B1F"
    readonly property color cOnSurface: ctl && typeof Colors !== "undefined" && Colors.onSurface ? Colors.onSurface : "#E6E1E5"
    readonly property color cOnSurfaceVariant: ctl && typeof Colors !== "undefined" && Colors.onSurfaceVariant ? Colors.onSurfaceVariant : "#CAC4D0"
    readonly property color cSurfaceContainer: ctl && typeof Colors !== "undefined" && Colors.surfaceContainer ? Colors.surfaceContainer : Qt.rgba(1, 1, 1, 0.08)

    function getSignalIcon(sig) {
        if (!wifiEnabled || sig <= 0) return "\ue648"
        if (sig < 30) return "\uf0b0"
        if (sig < 55) return "\ue1d9"
        if (sig < 75) return "\ue1da"
        return "\ue63e"
    }

    function isNetworkSaved(ssid) {
        for (var i = 0; i < saved.length; i++) {
            if (saved[i] === ssid) return true
        }
        return false
    }

    Connections {
        target: ctl
        function onWifiSignalChanged() {
            if (ctl && ctl.wifiSignal >= 0) wifiEnabled = ctl.wifiSignal > 0
        }
    }

    Process {
        id: wifiScan
        running: true
        command: ["sh", "-c",
            "nmcli -t -f IN-USE,SSID,SIGNAL dev wifi 2>/dev/null | head -20; " +
            "echo '---'; " +
            "nmcli -t -f WIFI g 2>/dev/null; " +
            "echo '==='; " +
            "nmcli -g NAME con show 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split('\n')
                var sep1 = lines.indexOf('---')
                var sep2 = lines.indexOf('===')
                var wifiLines = sep1 >= 0 ? lines.slice(0, sep1) : []
                var stateLine = sep1 >= 0 ? (lines[sep1 + 1] || "") : ""

                wifiEnabled = stateLine.trim() === "enabled"

                var newSaved = []
                if (sep2 >= 0) {
                    for (var i = sep2 + 1; i < lines.length; i++) {
                        var s = lines[i].trim()
                        if (s !== "") newSaved.push(s)
                    }
                }
                saved = newSaved

                var activeSsid = ""
                var activeSig = 0
                var nets = []

                for (var j = 0; j < wifiLines.length; j++) {
                    var p = wifiLines[j].split(':')
                    if (p.length >= 3) {
                        var inUse = p[0] === '*'
                        var ssid = p[1]
                        var sig = parseInt(p[2], 10) || 0
                        if (inUse && ssid) {
                            activeSsid = ssid
                            activeSig = sig
                        } else if (ssid && ssid !== activeSsid) {
                            nets.push({ ssid: ssid, signal: sig })
                        }
                    }
                }
                root.currentNetwork = activeSsid
                root.currentSignal = activeSig
                networks = nets
            }
        }
    }

    Timer { 
        interval: 5000; 
        running: true; 
        repeat: true; 
        onTriggered: wifiScan.running = true 
    }

    Process { id: wifiCmd }
    Timer { id: rescanLater; interval: 2000; onTriggered: wifiScan.running = true }

    function connectSaved(ssid) {
        wifiCmd.command = ["sh", "-c", "nmcli dev wifi connect \"$1\" >/dev/null 2>&1 &", "x", ssid]
        wifiCmd.running = true
        rescanLater.restart()
    }

    function connectWithPass(ssid, pass) {
        wifiCmd.command = ["sh", "-c", "nmcli dev wifi connect \"$1\" password \"$2\" >/dev/null 2>&1 &", "x", ssid, pass]
        wifiCmd.running = true
        askSsid = ""
        rescanLater.restart()
    }

    function forgetNetwork(ssid) {
        wifiCmd.command = ["sh", "-c", "nmcli connection delete \"$1\" >/dev/null 2>&1", "x", ssid]
        wifiCmd.running = true
        rescanLater.restart()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Wi-Fi Toggle Row (в стиле шапки блютуза)
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4

            Text {
                text: "Включение сети"
                color: root.cOnSurface
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
            }

            Item {
                implicitWidth: 52
                implicitHeight: 32

                Rectangle {
                    anchors.centerIn: parent
                    width: 52; height: 32; radius: 16
                    color: wifiEnabled ? root.cPrimary : "#2B3537"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22; height: 22; radius: 11
                        x: wifiEnabled ? parent.width - width - 5 : 5
                        color: wifiEnabled ? root.cOnPrimary : "#8E938F"
                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var newState = !wifiEnabled
                        if (ctl) {
                            ctl.wifiSignal = newState ? 60 : -1
                            ctl.syncNow()
                        }
                        wifiEnabled = newState
                        wifiCmd.command = ["sh", "-c", "nmcli radio wifi " + (newState ? "on" : "off") + " >/dev/null 2>&1"]
                        wifiCmd.running = true
                    }
                }
            }
        }

        // List Area
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: scrollContent.height
            clip: true

            ColumnLayout {
                id: scrollContent
                width: parent.width
                spacing: 8

                // Password Input Block
                Rectangle {
                    visible: askSsid !== ""
                    Layout.fillWidth: true
                    height: 130
                    radius: 20
                    color: root.cSurfaceContainer
                    border.color: root.cPrimary
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: askSsid; color: root.cOnSurface; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text {
                                text: "✕"
                                color: root.cOnSurfaceVariant
                                font.pixelSize: 16
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: askSsid = ""
                                }
                            }
                        }

                        TextField {
                            id: passField
                            Layout.fillWidth: true
                            height: 38
                            placeholderText: "Пароль"
                            placeholderTextColor: root.cOnSurfaceVariant
                            echoMode: TextInput.Password
                            color: root.cOnSurface
                            background: Rectangle {
                                radius: 12
                                color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.05)
                                border.color: passField.activeFocus ? root.cPrimary : Qt.rgba(root.cOnSurfaceVariant.r, root.cOnSurfaceVariant.g, root.cOnSurfaceVariant.b, 0.3)
                            }
                            onAccepted: root.connectWithPass(askSsid, text)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                width: 110; height: 32; radius: 16
                                color: root.cPrimary
                                Text { anchors.centerIn: parent; text: "Подключить"; color: root.cOnPrimary; font.bold: true; font.pixelSize: 12 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.connectWithPass(askSsid, passField.text) }
                            }
                        }
                    }
                }

                // Connected Network
                Rectangle {
                    visible: wifiEnabled && root.currentNetwork !== ""
                    Layout.fillWidth: true
                    height: 56
                    radius: 20
                    color: root.cPrimary

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16

                        Text {
                            text: getSignalIcon(root.currentSignal)
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            color: root.cOnPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: root.currentNetwork
                                color: root.cOnPrimary
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "Подключено"
                                color: Qt.rgba(root.cOnPrimary.r, root.cOnPrimary.g, root.cOnPrimary.b, 0.75)
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            text: "\ue88d"
                            font.family: "Material Symbols Outlined"
                            color: root.cOnPrimary
                            font.pixelSize: 18
                        }
                    }
                }

                // Other Networks List
                Repeater {
                    model: wifiEnabled ? networks : []
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 56
                        radius: 20
                        color: netHover.containsMouse ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.12) : root.cSurfaceContainer
                        Behavior on color { ColorAnimation { duration: 150 } }

                        property bool isSaved: isNetworkSaved(modelData.ssid)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 16

                            Text {
                                text: getSignalIcon(modelData.signal)
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 22
                                color: root.cOnSurface
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.ssid
                                    color: root.cOnSurface
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: isSaved
                                    text: "Сохранено"
                                    color: root.cOnSurfaceVariant
                                    font.pixelSize: 11
                                }
                            }

                            Text {
                                text: "\ue88d"
                                font.family: "Material Symbols Outlined"
                                color: root.cOnSurfaceVariant
                                font.pixelSize: 18
                            }
                        }

                        MouseArea {
                            id: netHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (isSaved) {
                                    root.connectSaved(modelData.ssid)
                                } else {
                                    askSsid = modelData.ssid
                                    passField.text = ""
                                    passField.forceActiveFocus()
                                }
                            }
                            onPressAndHold: {
                                if (isSaved) root.forgetNetwork(modelData.ssid)
                            }
                        }
                    }
                }

                // See All Button
                Rectangle {
                    visible: wifiEnabled
                    Layout.fillWidth: true
                    height: 48
                    radius: 20
                    color: seeAllHover.containsMouse ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.12) : root.cSurfaceContainer
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 16
                        Text { 
                            text: "\ue5c8"
                            font.family: "Material Symbols Outlined"
                            color: root.cPrimary
                            font.pixelSize: 20 
                        }
                        Text { text: "Настройки сети..."; color: root.cOnSurface; font.pixelSize: 14; font.bold: true; Layout.fillWidth: true }
                    }

                    MouseArea {
                        id: seeAllHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var cmd = ["sh", "-c", "command -v nm-connection-editor >/dev/null 2>&1 && nm-connection-editor & || command -v gnome-control-center >/dev/null 2>&1 && gnome-control-center wifi &"]
                            if (ctl) ctl.run(cmd)
                        }
                    }
                }
            }
        }
    }
}
