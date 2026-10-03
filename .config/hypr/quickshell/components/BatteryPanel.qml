import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../core"

Item {
    id: root
    property int level: -1
    property bool charging: false
    property string status: ""
    property bool powerSaver: false
    property var ctl: null

    property int energyFull: 0
    property int energyFullDesign: 0
    property int powerNow: 0
    property int voltageNow: 0
    property int cycleCount: 0
    property string technology: ""
    property string manufacturer: ""
    property string modelName: ""

    function refresh() { batScan.running = true }

    component MaterialSwitch: Item {
        id: swRoot
        property bool checked: false
        signal toggled(bool on)
        implicitWidth: 52
        implicitHeight: 32

        Rectangle {
            id: track
            anchors.centerIn: parent
            width: 52; height: 32; radius: 16
            color: swRoot.checked ? Colors.primary : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.24)
            Behavior on color { ColorAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Rectangle {
                id: knob
                anchors.verticalCenter: parent.verticalCenter
                width: swRoot.checked ? 24 : 16
                height: swRoot.checked ? 24 : 16
                radius: width / 2
                x: swRoot.checked ? parent.width - width - 4 : 4
                color: swRoot.checked ? Colors.primaryText : Colors.outline
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                swRoot.checked = !swRoot.checked
                swRoot.toggled(swRoot.checked)
            }
        }
    }

    function getStatusText() {
        if (charging) return "Заряжается"
        if (level >= 95) return "Полностью заряжена"
        if (status === "Discharging") return "Разряжается"
        if (status === "Not charging") return "Не заряжается"
        return status || "—"
    }

    function getBatteryColor() {
        if (level <= 20) return Colors.error
        if (level <= 50) return "#FFD54F"
        return "#81C784"
    }

    function getHealthText() {
        if (energyFullDesign <= 0) return "Неизвестно"
        var health = (energyFull / energyFullDesign) * 100
        if (health >= 90) return "Отличное"
        if (health >= 75) return "Хорошее"
        if (health >= 60) return "Среднее"
        return "Плохое"
    }

    function getHealthValue() {
        if (energyFullDesign <= 0) return 0
        return Math.round((energyFull / energyFullDesign) * 100)
    }

    function getTimeRemaining() {
        if (level < 0) return "—"
        if (charging) {
            if (energyFull <= 0 || powerNow <= 0) return "Расчёт..."
            var remaining = energyFull - (energyFull * level / 100)
            var hours = remaining / powerNow
            var mins = Math.round((hours % 1) * 60)
            return Math.floor(hours) + "ч " + mins + "м до полной"
        } else {
            if (powerNow <= 0) return "Расчёт..."
            var remaining2 = energyFull * level / 100
            var hours2 = remaining2 / powerNow
            var mins2 = Math.round((hours2 % 1) * 60)
            return Math.floor(hours2) + "ч " + mins2 + "м осталось"
        }
    }

    function getPowerWatts() {
        if (powerNow <= 0) return "0 Вт"
        return (powerNow / 1000000).toFixed(1) + " Вт"
    }

    function getVoltageVolts() {
        if (voltageNow <= 0) return "—"
        return (voltageNow / 1000000).toFixed(2) + " В"
    }

    Process {
        id: batScan
        running: true
        command: ["sh", "-c",
            "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); " +
            "if [ -n \"$b\" ]; then " +
            "echo \"$(cat $b/capacity)\"; " +
            "echo \"$(cat $b/status)\"; " +
            "[ -f $b/energy_full ] && echo \"$(cat $b/energy_full_design) $(cat $b/energy_full)\" || echo \"0 0\"; " +
            "[ -f $b/power_now ] && echo \"$(cat $b/power_now)\" || echo \"0\"; " +
            "[ -f $b/voltage_now ] && echo \"$(cat $b/voltage_now)\" || echo \"0\"; " +
            "[ -f $b/cycle_count ] && echo \"$(cat $b/cycle_count)\" || echo \"0\"; " +
            "[ -f $b/technology ] && cat $b/technology || echo \"\"; " +
            "[ -f $b/manufacturer ] && cat $b/manufacturer || echo \"\"; " +
            "[ -f $b/model_name ] && cat $b/model_name || echo \"\"; " +
            "else echo '-1'; echo 'Unknown'; echo '0 0'; echo '0'; echo '0'; echo '0'; echo ''; echo ''; echo ''; fi; " +
            "[ \"$(powerprofilesctl get 2>/dev/null)\" = \"power-saver\" ] && echo PS=1 || echo PS=0"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.split('\n')
                level = parseInt(lines[0], 10)
                status = (lines[1] || '').trim()
                charging = status === "Charging"
                var energyParts = (lines[2] || '').split(/\s+/)
                energyFullDesign = parseInt(energyParts[0], 10) || 0
                energyFull = parseInt(energyParts[1], 10) || 0
                powerNow = parseInt(lines[3], 10) || 0
                voltageNow = parseInt(lines[4], 10) || 0
                cycleCount = parseInt(lines[5], 10) || 0
                technology = (lines[6] || '').trim()
                manufacturer = (lines[7] || '').trim()
                modelName = (lines[8] || '').trim()
                powerSaver = (lines[9] || '').trim() === "PS=1"
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: batScan.running = true }
    Process { id: psCmd }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // Main Hero Card
        Rectangle {
            Layout.fillWidth: true
            height: 180
            radius: 20
            color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.75)
            border.width: 1
            border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.12)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Item {
                    Layout.preferredWidth: 130
                    Layout.preferredHeight: 130

                    Canvas {
                        id: ring
                        anchors.centerIn: parent
                        width: 130; height: 130

                        onPaint: {
                            var ctx = getContext('2d')
                            ctx.clearRect(0, 0, width, height)
                            ctx.lineWidth = 12
                            ctx.lineCap = "round"

                            ctx.strokeStyle = Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.15)
                            ctx.beginPath()
                            ctx.arc(width/2, height/2, 52, 0, Math.PI * 2)
                            ctx.stroke()

                            if (root.level >= 0) {
                                ctx.strokeStyle = getBatteryColor()
                                ctx.beginPath()
                                ctx.arc(width/2, height/2, 52, -Math.PI/2, -Math.PI/2 + Math.PI * 2 * root.level / 100)
                                ctx.stroke()
                            }
                        }

                        Connections { target: root; function onLevelChanged() { ring.requestPaint() } }
                        Connections { target: root; function onChargingChanged() { ring.requestPaint() } }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.level >= 0 ? root.level + "%" : "—"
                            color: Colors.backgroundText
                            font.pixelSize: 28
                            font.bold: true
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.charging ? "⚡" : ""
                            color: "#81C784"
                            font.pixelSize: 14
                        }
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: getStatusText()
                        color: Colors.backgroundText
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Text {
                        text: root.level >= 0 ? getTimeRemaining() : ""
                        color: Colors.primary
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Item { width: 1; height: 4 }

                    Text {
                        visible: root.level >= 0
                        text: "Состояние: " + getHealthText() + " (" + getHealthValue() + "%)"
                        color: Colors.outline
                        font.pixelSize: 12
                    }
                }
            }
        }

        // Scrollable Area
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: scrollContent.height + 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            ColumnLayout {
                id: scrollContent
                width: parent.width
                spacing: 12

                // Power Saver Tile
                Rectangle {
                    Layout.fillWidth: true
                    height: 76
                    radius: 20
                    color: powerSaver ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.15) : Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.75)
                    border.width: 1
                    border.color: powerSaver ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.4) : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.12)
                    Behavior on color { ColorAnimation { duration: 200 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 16

                        Rectangle {
                            width: 40; height: 40; radius: 20
                            color: powerSaver ? Colors.primary : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1)
                            Text {
                                anchors.centerIn: parent
                                text: "󰌪"
                                font.pixelSize: 20
                                color: powerSaver ? Colors.primaryText : Colors.backgroundText
                            }
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Энергосбережение"
                                color: Colors.backgroundText
                                font.pixelSize: 15
                                font.bold: true
                            }
                            Text {
                                text: powerSaver ? "Включено" : "Выключено"
                                color: powerSaver ? Colors.primary : Colors.outline
                                font.pixelSize: 12
                            }
                        }

                        MaterialSwitch {
                            checked: powerSaver
                            onToggled: function(on) {
                                if (ctl) {
                                    ctl.powerSaverOn = on
                                    ctl.syncNow()
                                }
                                powerSaver = on
                                psCmd.command = ["sh", "-c", "powerprofilesctl set " + (on ? "power-saver" : "balanced") + " >/dev/null 2>&1"]
                                psCmd.running = true
                            }
                        }
                    }
                }

                // Details Section Header
                Text {
                    visible: root.level >= 0
                    text: "ПОДРОБНО"
                    color: Colors.outline
                    font.pixelSize: 11
                    font.bold: true
                    Layout.leftMargin: 4
                    Layout.topMargin: 4
                }

                // Details Card
                Rectangle {
                    visible: root.level >= 0
                    Layout.fillWidth: true
                    height: 220
                    radius: 20
                    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.12)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        // Reusable row component layout helper omitted for inline brevity, maintaining explicit clean rows
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "󰂀"; color: Colors.primary; font.pixelSize: 16 }
                            Text { Layout.fillWidth: true; text: "Состояние"; color: Colors.backgroundText; font.pixelSize: 13 }
                            Text { text: getHealthText(); color: Colors.outline; font.pixelSize: 13; font.weight: Font.Medium }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "󱊣"; color: Colors.primary; font.pixelSize: 16 }
                            Text { Layout.fillWidth: true; text: "Профиль питания"; color: Colors.backgroundText; font.pixelSize: 13 }
                            Text { text: powerSaver ? "Экономия" : "Сбалансированный"; color: Colors.outline; font.pixelSize: 13; font.weight: Font.Medium }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "󱐋"; color: Colors.primary; font.pixelSize: 16 }
                            Text { Layout.fillWidth: true; text: "Потребление"; color: Colors.backgroundText; font.pixelSize: 13 }
                            Text { text: getPowerWatts(); color: Colors.outline; font.pixelSize: 13; font.weight: Font.Medium }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "󰚦"; color: Colors.primary; font.pixelSize: 16 }
                            Text { Layout.fillWidth: true; text: "Напряжение"; color: Colors.backgroundText; font.pixelSize: 13 }
                            Text { text: getVoltageVolts(); color: Colors.outline; font.pixelSize: 13; font.weight: Font.Medium }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "󰆍"; color: Colors.primary; font.pixelSize: 16 }
                            Text { Layout.fillWidth: true; text: "Циклов зарядки"; color: Colors.backgroundText; font.pixelSize: 13 }
                            Text { text: cycleCount > 0 ? cycleCount.toString() : "—"; color: Colors.outline; font.pixelSize: 13; font.weight: Font.Medium }
                        }
                    }
                }

                // Specification Section Header
                Text {
                    visible: root.level >= 0 && (technology !== "" || manufacturer !== "" || modelName !== "")
                    text: "СПЕЦИФИКАЦИЯ"
                    color: Colors.outline
                    font.pixelSize: 11
                    font.bold: true
                    Layout.leftMargin: 4
                    Layout.topMargin: 4
                }

                // Specification Card
                Rectangle {
                    visible: root.level >= 0 && (technology !== "" || manufacturer !== "" || modelName !== "")
                    Layout.fillWidth: true
                    height: 120
                    radius: 20
                    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.75)
                    border.width: 1
                    border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.12)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: "Технология"; color: Colors.outline; font.pixelSize: 13 }
                            Text { text: technology || "—"; color: Colors.backgroundText; font.pixelSize: 13; font.weight: Font.Medium }
                        }
                        RowLayout {
                            visible: manufacturer !== ""
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: "Производитель"; color: Colors.outline; font.pixelSize: 13 }
                            Text { text: manufacturer; color: Colors.backgroundText; font.pixelSize: 13; font.weight: Font.Medium }
                        }
                        RowLayout {
                            visible: modelName !== ""
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: "Модель"; color: Colors.outline; font.pixelSize: 13 }
                            Text { text: modelName; color: Colors.backgroundText; font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight }
                        }
                    }
                }

                // Empty State
                Item {
                    visible: root.level < 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 120

                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "󰂄"
                            color: Colors.outline
                            font.pixelSize: 32
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "Батарея не обнаружена"
                            color: Colors.outline
                            font.pixelSize: 13
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }

                // Settings Button Card
                Rectangle {
                    Layout.fillWidth: true
                    height: 52
                    radius: 16
                    color: settingsHover.containsMouse ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.08) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        Text { text: "󰒓"; color: Colors.backgroundText; font.pixelSize: 16 }
                        Text { Layout.fillWidth: true; text: "Настройки питания"; color: Colors.backgroundText; font.pixelSize: 14; font.weight: Font.Medium }
                        Text { text: "›"; color: Colors.outline; font.pixelSize: 16 }
                    }

                    MouseArea {
                        id: settingsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var cmd = ["sh", "-c", "command -v gnome-power-statistics >/dev/null 2>&1 && gnome-power-statistics & || command -v gnome-control-center >/dev/null 2>&1 && gnome-control-center power & || command -v kcmshell6 >/dev/null 2>&1 && kcmshell6 kcm_power & || command -v xfce4-power-manager-settings >/dev/null 2>&1 && xfce4-power-manager-settings &"]
                            if (ctl) ctl.run(cmd)
                        }
                    }
                }
            }
        }
    }
}
