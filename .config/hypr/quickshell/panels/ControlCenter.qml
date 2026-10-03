import QtQuick
import QtQuick.Effects
import "../core"
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland
import Quickshell.Io
import "../components" as Components

PanelWindow {
    id: cc
    WlrLayershell.layer: WlrLayershell.Layer.Overlay
    WlrLayershell.namespace: "control-center"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { bottom: true; left: true; right: true; top: false }
    implicitHeight: Screen.height - 28
    visible: open
    color: "transparent"

    property bool open: false
    property string view: "main"

    readonly property string iconFont: "Material Symbols Outlined"

    property bool editMode: false
    property string selectedTileKey: ""

    // Android 16/17-style tile sizes: 1×1 or 2×1.
    // The panel itself remains freely resizable.
    ListModel {
        id: tileModel
        ListElement { key: "wifi"; span: 2 }
        ListElement { key: "bt"; span: 2 }
        ListElement { key: "dnd"; span: 1 }
        ListElement { key: "night"; span: 1 }
        ListElement { key: "dark"; span: 1 }
        ListElement { key: "hypridle"; span: 1 }
        ListElement { key: "battery"; span: 2 }
    }

    FileView {
        id: tileLayoutFile
        path: Quickshell.statePath("controlcenter-layout.json")
        blockLoading: true
        atomicWrites: true
        printErrors: true
    }

    function saveTileLayout(): void {
        const tiles = []
        for (let i = 0; i < tileModel.count; ++i) {
            const item = tileModel.get(i)
            tiles.push({ key: item.key, span: item.span })
        }
        tileLayoutFile.setText(JSON.stringify({ version: 2, tiles: tiles }, null, 2))
    }

    function loadTileLayout(): void {
        const raw = tileLayoutFile.text()
        if (!raw || raw.trim() === "") {
            saveTileLayout()
            return
        }

        try {
            const data = JSON.parse(raw)
            if (!data || !Array.isArray(data.tiles)) return

            const defaults = {}
            for (let i = 0; i < tileModel.count; ++i)
                defaults[tileModel.get(i).key] = tileModel.get(i).span

            const loaded = []
            const used = {}
            for (const item of data.tiles) {
                if (!item || typeof item.key !== "string" || used[item.key] || defaults[item.key] === undefined)
                    continue
                loaded.push({ key: item.key, span: Number(item.span) === 2 ? 2 : 1 })
                used[item.key] = true
            }

            for (const key in defaults) {
                if (!used[key])
                    loaded.push({ key: key, span: defaults[key] === 2 ? 2 : 1 })
            }

            tileModel.clear()
            for (const item of loaded)
                tileModel.append(item)
        } catch (e) {
            console.warn("ControlCenter: invalid tile layout, using defaults", e)
        }
    }

    function resetTileLayout(): void {
        tileModel.clear()
        tileModel.append({ key: "wifi", span: 2 })
        tileModel.append({ key: "bt", span: 2 })
        tileModel.append({ key: "dnd", span: 1 })
        tileModel.append({ key: "night", span: 1 })
        tileModel.append({ key: "dark", span: 1 })
        tileModel.append({ key: "hypridle", span: 1 })
        tileModel.append({ key: "battery", span: 2 })
        selectedTileKey = ""
        saveTileLayout()
    }

    Component.onCompleted: loadTileLayout()

    function tileIndex(key: string): int {
        for (let i = 0; i < tileModel.count; ++i)
            if (tileModel.get(i).key === key) return i
        return -1
    }

    function selectTile(key: string): void {
        selectedTileKey = key
    }

    function resizeTile(key: string): void {
        const i = tileIndex(key)
        if (i < 0) return
        const nextSpan = tileModel.get(i).span === 1 ? 2 : 1
        tileModel.setProperty(i, "span", nextSpan)
        saveTileLayout()
    }

    function resizeTileFromDrag(key: string, startSpan: int, deltaX: real): int {
        const i = tileIndex(key)
        if (i < 0) return startSpan

        // Android 16/17 supports the compact 1×1 and expanded 2×1 states.
        const threshold = 42
        let target = startSpan
        if (startSpan === 1 && deltaX >= threshold) target = 2
        else if (startSpan === 2 && deltaX <= -threshold) target = 1

        if (target !== tileModel.get(i).span) {
            tileModel.setProperty(i, "span", target)
            saveTileLayout()
        }
        return target
    }

    function moveTile(sourceKey: string, targetKey: string): void {
        const from = tileIndex(sourceKey)
        const to = tileIndex(targetKey)
        if (from < 0 || to < 0 || from === to) return
        tileModel.move(from, to, 1)
        saveTileLayout()
    }

    function moveTileByPointer(sourceKey: string, gx: real, gy: real): void {
        const from = tileIndex(sourceKey)
        if (from < 0) return

        let best = -1
        let bestDistance = Number.MAX_VALUE
        for (let i = 0; i < tileModel.count; ++i) {
            if (i === from) continue
            const item = tileGridRepeater.itemAt(i)
            if (!item || item.width <= 0 || item.height <= 0) continue
            const center = item.mapToItem(tileGrid, item.width / 2, item.height / 2)
            const dx = gx - center.x
            const dy = gy - center.y
            const distance = dx * dx + dy * dy
            if (distance < bestDistance) {
                bestDistance = distance
                best = i
            }
        }

        if (best < 0) return
        const target = tileGridRepeater.itemAt(best)
        if (!target) return

        // Only reorder after crossing the target tile's center. This prevents
        // the list from jittering while the pointer moves inside a tile.
        const center = target.mapToItem(tileGrid, target.width / 2, target.height / 2)
        const source = tileGridRepeater.itemAt(from)
        if (!source) return

        const shouldMove = (best > from)
            ? (gx > center.x || gy > center.y)
            : (gx < center.x || gy < center.y)
        if (shouldMove) moveTile(sourceKey, target.tileKey)
    }

    function tileTitle(key: string): string {
        if (key === "wifi") return "Интернет"
        if (key === "bt") return "Bluetooth"
        if (key === "dnd") return "Не беспокоить"
        if (key === "night") return "Ночной свет"
        if (key === "dark") return "Тёмная тема"
        if (key === "hypridle") return "Ожидание"
        if (key === "battery") return "Батарея"
        return "Питание"
    }
    function tileSubtitle(key: string): string {
        if (key === "wifi") return !wifiEnabled ? "Выкл" : (wifiConnected ? "Подключено" : "Не подключено")
        if (key === "bt") return !btEnabled ? "Выкл" : (btConnected ? "Подключено" : "Вкл")
        if (key === "dnd") return dndOn ? "Вкл" : "Выкл"
        if (key === "night") return nightLightOn ? "Вкл" : "Выкл"
        if (key === "dark") return darkOn ? "Вкл" : "Выкл"
        if (key === "hypridle") return hypridleOn ? "Вкл" : "Выкл"
        if (key === "battery") return batteryLevel >= 0 ? batteryLevel + "%" + (charging ? " · Зарядка" : "") : "Недоступно"
        return "Сон · Перезапуск · Выкл"
    }
    function tileIcon(key: string): string {
        if (key === "wifi") return !wifiEnabled ? "wifi_off" : "wifi"
        if (key === "bt") return btEnabled ? "bluetooth" : "bluetooth_disabled"
        if (key === "dnd") return "notifications_off"
        if (key === "night") return "nightlight"
        if (key === "dark") return "contrast"
        if (key === "hypridle") return "timer"
        if (key === "battery") return charging ? "battery_charging_full" : "battery_full"
        return "power_settings_new"
    }
    function tileActive(key: string): bool {
        if (key === "wifi") return wifiConnected
        if (key === "bt") return btConnected
        if (key === "dnd") return dndOn
        if (key === "night") return nightLightOn
        if (key === "dark") return darkOn
        if (key === "hypridle") return hypridleOn
        if (key === "battery") return powerSaverOn
        return false
    }
    function tileEnabled(key: string): bool {
        if (key === "wifi") return wifiEnabled
        if (key === "bt") return btEnabled
        if (key === "battery") return powerSaverOn
        if (key === "power") return true
        return tileActive(key)
    }
    function tileTapped(key: string): void {
        if (editMode) { selectTile(key); return }
        if (key === "wifi") toggleWifi()
        else if (key === "bt") toggleBluetooth()
        else if (key === "dnd") toggleDnd()
        else if (key === "night") toggleNightLight()
        else if (key === "dark") toggleDark()
        else if (key === "hypridle") toggleHypridle()
        else if (key === "battery") togglePowerSaver()
        else if (key === "power") view = "power"
    }
    function tileDetail(key: string): void {
        if (editMode) { selectTile(key); return }
        if (key === "wifi") view = "wifi"
        else if (key === "bt") view = "bluetooth"
        else if (key === "battery") view = "battery"
        else if (key === "power") view = "power"
    }

    property bool wifiEnabled: false
    property bool wifiConnected: false
    property int wifiSignal: -1

    property bool btEnabled: false
    property bool btConnected: false
    property int btOn: -1

    property int batteryLevel: -1
    property bool charging: false
    property bool dndOn: false
    property bool nightLightOn: false
    property bool powerSaverOn: false
    property bool darkOn: false
    property bool hypridleOn: false
    property int brightness: 50
    property real volume: 0.5

    property var audioSinks: []
    property string defaultSink: ""

    property bool mediaAvailable: false
    property bool mediaPlaying: false
    property string mediaPlayer: ""
    property string mediaTitle: ""
    property string mediaArtist: ""

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

    function show(section: string): void {
        view = section
        open = true
        Qt.callLater(() => {
            if (section === "wifi") wifiPanel.refresh()
            if (section === "bluetooth") btPanel.refresh()
            if (section === "battery") batPanel.refresh()
            if (section === "audio") audioProbe.running = true
        })
    }
    function close(): void { open = false }
    function toggle(section: string): void {
        if (open && view === section) close()
        else show(section)
    }
    function toggleMain(): void {
        if (open) close()
        else { view = "main"; open = true }
    }

    onOpenChanged: {
        if (open) {
            content.opacity = 0
            content.scale = 0.95
            content.opacity = 1
            content.scale = 1
        } else {
            content.opacity = 0
            content.scale = 0.95
            view = "main"
        }
    }

    component QSTile: Rectangle {
        id: tileRoot

        property string icon: ""
        property string fontIconFamily: "Material Symbols Outlined"
        property string title: ""
        property string subtitle: ""
        property bool active: false
        property bool enabledState: false
        property bool compact: false
        property bool hasDetail: false
        property bool editing: false
        property string editKey: ""

        signal tapped()
        signal detailTapped()

        readonly property bool hovered: compact ? compactMouse.containsMouse
                                              : (iconArea.containsMouse || textArea.containsMouse)
        readonly property bool pressed: compact ? compactMouse.pressed
                                              : (iconArea.pressed || textArea.pressed)

        radius: compact ? 18 : 22

        color: active
            ? cc.cPrimary
            : (hovered ? cc.cSurfaceContainerHigh : cc.cSurfaceContainer)

        Behavior on color {
            ColorAnimation { duration: 180 }
        }

        scale: pressed ? 0.97 : (hovered ? 1.01 : 1.0)

        Behavior on scale {
            NumberAnimation {
                duration: pressed ? 90 : 180
                easing.type: pressed ? Easing.OutCubic : Easing.OutBack
            }
        }

        Item {
            anchors.fill: parent
            visible: tileRoot.compact

            Text {
                anchors.centerIn: parent
                text: tileRoot.icon
                font.family: tileRoot.fontIconFamily
                font.pixelSize: 21
                font.weight: Font.Medium
                color: tileRoot.active ? cc.cOnPrimary : cc.cOnSurface
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            MouseArea {
                id: compactMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    tileRoot.tapped()
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            visible: !tileRoot.compact

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                Layout.alignment: Qt.AlignVCenter
                radius: 12

                color: tileRoot.enabledState && !tileRoot.active
                    ? Qt.rgba(cc.cPrimary.r, cc.cPrimary.g, cc.cPrimary.b, 1.0)
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: tileRoot.icon
                    font.family: tileRoot.fontIconFamily
                    font.pixelSize: 20
                    font.weight: Font.Medium
                    color: tileRoot.active
                        ? cc.cOnPrimary
                        : (tileRoot.enabledState ? cc.cOnPrimary : cc.cOnSurface)
                    Behavior on color { ColorAnimation { duration: 160 } }
                }

                MouseArea {
                    id: iconArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (tileRoot.editing && tileRoot.editKey !== "") cc.resizeTile(tileRoot.editKey)
                        else tileRoot.tapped()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    spacing: 1

                    Text {
                        width: parent.width
                        text: tileRoot.title
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        color: tileRoot.active ? cc.cOnPrimary : cc.cOnSurface
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    Text {
                        width: parent.width
                        text: tileRoot.subtitle
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        visible: text !== ""
                        color: tileRoot.active
                            ? Qt.rgba(cc.cOnPrimary.r, cc.cOnPrimary.g, cc.cOnPrimary.b, 0.72)
                            : cc.cOnSurfaceVariant
                    }
                }

                MouseArea {
                    id: textArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (tileRoot.editing && tileRoot.editKey !== "") {
                            cc.resizeTile(tileRoot.editKey)
                        } else if (tileRoot.hasDetail) {
                            tileRoot.detailTapped()
                        } else {
                            tileRoot.tapped()
                        }
                    }
                }
            }
        }

    }

    component M3PowerTile: Rectangle {
        id: pwrTile
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property var cmd: []
        property bool isDanger: false
        property string fontIconFamily: "Symbols Nerd Font Mono"

        Layout.fillWidth: true
        Layout.preferredHeight: 68
        radius: 20
        color: pwrMouse.containsMouse 
            ? cc.cSurfaceContainerHigh
            : cc.cSurfaceContainer

        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 14
                color: pwrTile.isDanger ? cc.cError : Qt.rgba(cc.cPrimary.r, cc.cPrimary.g, cc.cPrimary.b, 0.2)

                Text {
                    anchors.centerIn: parent
                    text: pwrTile.icon
                    font.family: pwrTile.fontIconFamily
                    font.pixelSize: 22
                    color: pwrTile.isDanger ? cc.cOnError : cc.cPrimary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: pwrTile.title
                    font.pixelSize: 14
                    font.bold: true
                    color: cc.cOnSurface
                }
                Text {
                    text: pwrTile.subtitle
                    font.pixelSize: 11
                    color: cc.cOnSurfaceVariant
                }
            }
        }

        MouseArea {
            id: pwrMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                cc.run(pwrTile.cmd)
                cc.close()
            }
        }
    }

    component QSSlider: Item {
        id: sliderRoot

        property real value: 0.5
        property string icon: ""
        property bool clickableIcon: false

        signal iconClicked()
        signal moved(real value)

        implicitHeight: 36
        clip: false

        readonly property real rawPosition: Math.max(0, Math.min(width, width * value))

        Rectangle {
            id: bgTrack
            anchors.fill: parent
            radius: height / 2 // Полное закругление краев трека
            color: cc.cSurfaceContainerHigh

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: sliderRoot.rawPosition
                radius: height / 2 // Закругляем саму заливку, чтобы левый край был круглым
                color: cc.cPrimary

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.radius
                    color: cc.cPrimary
                    visible: sliderRoot.rawPosition > parent.radius && sliderRoot.rawPosition < sliderRoot.width - parent.radius
                }
            }

            Text {
                id: sliderIcon
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: sliderRoot.icon === "brightness" ? "brightness_6"
                      : sliderRoot.icon === "volume" || sliderRoot.icon === "volume_up" ? "volume_up"
                      : sliderRoot.icon
                font.family: cc.iconFont
                font.pixelSize: 18 // Чуть уменьшена иконка под новый размер
                font.weight: Font.Medium
                color: cc.cOnSurface 
                z: 30
            }
        }

        Rectangle {
            id: dividerLine
            width: 4 
            height: parent.height + 8 
            radius: 2 // Закругленные концы разделителя
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(sliderRoot.width - width, sliderRoot.rawPosition - width / 2))
            color: cc.cPrimary 
            z: 40
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            function setFromX(px) {
                const newValue = Math.max(0, Math.min(1, px / Math.max(1, sliderRoot.width)))
                sliderRoot.value = newValue
                sliderRoot.moved(newValue)
            }

            onPressed: function(mouse) {
                if (sliderRoot.clickableIcon && mouse.x > sliderRoot.width - 40)
                    sliderRoot.iconClicked()
                else
                    setFromX(mouse.x)
            }

            onPositionChanged: function(mouse) {
                if (!pressed) return
                if (sliderRoot.clickableIcon && mouse.x > sliderRoot.width - 40) return
                setFromX(mouse.x)
            }
        }
    }

    Process {
        id: wifiProbe
        running: true
        command: ["sh", "-c",
            "sw=$(nmcli radio wifi 2>/dev/null); " +
            "sig=$(nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | grep '^\\*' | head -1 | cut -d: -f2); " +
            "echo \"SW=$sw\"; echo \"SIG=${sig:-0}\""]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const [k, v] = line.split("=")
                    if (k === "SW") cc.wifiEnabled = (v.trim() === "enabled")
                    if (k === "SIG") {
                        const s = parseInt(v.trim(), 10)
                        cc.wifiSignal = isNaN(s) ? 0 : s
                    }
                }
                cc.wifiConnected = cc.wifiEnabled && (cc.wifiSignal > 0)
            }
        }
    }

    Process {
        id: btProbe
        running: true
        command: ["sh", "-c",
            "pwr=$(bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 1 || echo 0); " +
            "dev=$(bluetoothctl devices Connected 2>/dev/null | wc -l); " +
            "echo \"PWR=$pwr\"; echo \"DEV=$dev\""]
        stdout: StdioCollector {
            onStreamFinished: {
                let pwr = false
                let devCount = 0
                for (const line of text.split("\n")) {
                    const [k, v] = line.split("=")
                    if (k === "PWR") pwr = (v.trim() === "1")
                    if (k === "DEV") devCount = parseInt(v.trim(), 10) || 0
                }
                cc.btEnabled = pwr
                cc.btConnected = pwr && (devCount > 0)
                cc.btOn = pwr ? 1 : 0
            }
        }
    }

    Process {
        id: batteryProbe
        running: true
        command: ["sh", "-c",
            "b=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1); if [ -n \"$b\" ]; then echo \"$(cat $b/capacity) $(cat $b/status)\"; else echo \"-1\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/)
                cc.batteryLevel = parseInt(parts[0], 10)
                cc.charging = parts.length > 1 && parts[1] === "Charging"
            }
        }
    }

    Process {
        id: extrasProbe
        running: true
        command: ["sh", "-c",
            "NL=0; pgrep -x wlsunset >/dev/null 2>&1 && NL=1; " +
            "PS=0; [ \"$(powerprofilesctl get 2>/dev/null)\" = \"power-saver\" ] && PS=1; " +
            "DK=0; darkman get 2>/dev/null | grep -qx dark && DK=1; " +
            "BR=$(brightnessctl -m 2>/dev/null | awk -F, '{print $4}' | tr -d '%'); [ -z \"$BR\" ] && BR=50; " +
            "VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}'); [ -z \"$VOL\" ] && VOL=0.5; " +
            "DND=0; if command -v dunstctl >/dev/null 2>&1 && pgrep -x dunst >/dev/null 2>&1; then dunstctl get-dnd 2>/dev/null | grep -qi true && DND=1; elif [ -f /tmp/qs-dnd ]; then DND=1; fi; " +
            "HDI=0; pgrep -x hypridle >/dev/null 2>&1 && HDI=1; " +
            "echo \"NL=$NL\"; echo \"PS=$PS\"; echo \"DK=$DK\"; echo \"BR=$BR\"; echo \"VOL=$VOL\"; echo \"DND=$DND\"; echo \"HDI=$HDI\""]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const [k, v] = line.split("=")
                    if (k === "NL") cc.nightLightOn = v === "1"
                    if (k === "PS") cc.powerSaverOn = v === "1"
                    if (k === "DK") cc.darkOn = v === "1"
                    if (k === "BR") cc.brightness = parseInt(v, 10) || 50
                    if (k === "VOL") cc.volume = parseFloat(v) || 0.5
                    if (k === "DND") cc.dndOn = v === "1"
                    if (k === "HDI") cc.hypridleOn = v === "1"
                }
            }
        }
    }

    Process {
        id: audioProbe
        running: true
        command: ["sh", "-c", "pactl get-default-sink; echo '---'; pactl list sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---")
                if (parts.length < 2) return

                const defSink = parts[0].trim()
                cc.defaultSink = defSink

                const rawSinks = parts[1].split(/Name:\s+/)
                const list = []

                for (let i = 1; i < rawSinks.length; i++) {
                    const block = rawSinks[i]
                    const lines = block.split("\n")
                    const name = lines[0].trim()
                    
                    let desc = name
                    const descMatch = block.match(/Description:\s+(.*)/)
                    if (descMatch && descMatch[1]) {
                        desc = descMatch[1].trim()
                    }

                    list.push({ name: name, description: desc })
                }
                cc.audioSinks = list
            }
        }
    }

    Process {
        id: mediaProbe
        running: true
        command: ["sh", "-c",
            "if ! command -v playerctl >/dev/null 2>&1; then echo 'NONE'; exit 0; fi; " +
            "p=''; for x in $(playerctl -l 2>/dev/null); do [ \"$(playerctl -p \"$x\" status 2>/dev/null)\" = Playing ] && { p=\"$x\"; break; }; done; " +
            "[ -z \"$p\" ] && p=$(playerctl -l 2>/dev/null | head -n1); " +
            "[ -z \"$p\" ] && { echo 'NONE'; exit 0; }; " +
            "st=$(playerctl -p \"$p\" status 2>/dev/null); md=$(playerctl -p \"$p\" metadata --format '{{title}}|{{artist}}' 2>/dev/null); echo \"$st|$md|$p\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim()
                if (!line || line === "NONE") {
                    cc.mediaAvailable = false
                    cc.mediaPlaying = false
                    cc.mediaPlayer = ""
                    cc.mediaTitle = "Медиа"
                    cc.mediaArtist = "Ничего не воспроизводится"
                    return
                }
                const parts = line.split("|")
                cc.mediaAvailable = true
                cc.mediaPlaying = parts[0] === "Playing"
                cc.mediaTitle = parts[1] && parts[1].length ? parts[1] : "Без названия"
                cc.mediaArtist = parts[2] && parts[2].length ? parts[2] : "Неизвестный исполнитель"
                cc.mediaPlayer = parts[3] || ""
            }
        }
    }

    function mediaCommand(action: string) {
        if (!cc.mediaAvailable || !cc.mediaPlayer.length) return
        if (action === "previous") run(["playerctl", "-p", cc.mediaPlayer, "previous"])
        else if (action === "next") run(["playerctl", "-p", cc.mediaPlayer, "next"])
        else run(["playerctl", "-p", cc.mediaPlayer, "play-pause"])
        mediaSync.restart()
    }

    Timer { id: mediaSync; interval: 180; onTriggered: mediaProbe.running = true }

    Timer { interval: 3000; running: true; repeat: true; onTriggered: wifiProbe.running = true }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: btProbe.running = true }
    Timer { interval: 10000; running: true; repeat: true; onTriggered: batteryProbe.running = true }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: extrasProbe.running = true }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: mediaProbe.running = true }

    Process { id: cmd }
    function run(c: var) { cmd.command = c; cmd.running = true }

    Process { id: liveBrightness }
    Process { id: liveVolume }

    function applyBrightnessLive(percent: int) {
        const safeBrightness = Math.max(1, Math.min(100, percent))
        if (liveBrightness.running) liveBrightness.running = false
        liveBrightness.command = ["brightnessctl", "set", safeBrightness + "%"]
        liveBrightness.running = true
    }

    function applyVolumeLive(value: real) {
        const safeVolume = Math.max(0, Math.min(1.0, value))
        if (liveVolume.running) liveVolume.running = false
        liveVolume.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(safeVolume * 100) + "%", "--limit", "1.0"]
        liveVolume.running = true
    }

    Timer { id: syncExtras; interval: 800; onTriggered: extrasProbe.running = true }

    Timer {
        id: resync
        interval: 600
        onTriggered: {
            wifiProbe.running = true
            btProbe.running = true
            batteryProbe.running = true
            extrasProbe.running = true
            audioProbe.running = true
            wifiPanel.refresh()
            btPanel.refresh()
            batPanel.refresh()
        }
    }

    function syncNow() { resync.restart() }

    function setAudioSink(sinkName: string) {
        run(["pactl", "set-default-sink", sinkName])
        cc.defaultSink = sinkName
        audioProbe.running = true
    }

    function toggleWifi() {
        const turningOn = !cc.wifiEnabled
        run(["sh", "-c", "nmcli radio wifi " + (turningOn ? "on" : "off") + " >/dev/null 2>&1"])
        cc.wifiEnabled = turningOn
        if (!turningOn) {
            cc.wifiConnected = false
            cc.wifiSignal = -1
        }
        resync.restart()
    }
    function toggleBluetooth() {
        const turningOn = !cc.btEnabled
        run(["sh", "-c", "bluetoothctl power " + (turningOn ? "on" : "off") + " >/dev/null 2>&1"])
        cc.btEnabled = turningOn
        if (!turningOn) {
            cc.btConnected = false
            cc.btOn = 0
        } else {
            cc.btOn = 1
        }
        resync.restart()
    }
    function toggleDnd() {
        dndOn = !dndOn
        run(["sh", "-c",
            "if command -v dunstctl >/dev/null 2>&1 && pgrep -x dunst >/dev/null 2>&1; then dunstctl set-dnd " + (dndOn ? "true" : "false") + " >/dev/null 2>&1; else " + (dndOn ? "touch /tmp/qs-dnd" : "rm -f /tmp/qs-dnd") + "; fi"])
        resync.restart()
    }
    function toggleNightLight() {
    nightLightOn = !nightLightOn
    // Если свет включается — запускаем wlsunset в фоне через nohup (подставьте свои координаты вместо -l 52.0 -L 47.8)
    // Если выключается — убиваем процесс wlsunset
    run(["sh", "-c", nightLightOn 
        ? "nohup wlsunset -l 52.0 -L 47.8 -t 4500 >/dev/null 2>&1 &" 
        : "pkill -x wlsunset 2>/dev/null"])
    resync.restart()
    }
    function togglePowerSaver() {
        powerSaverOn = !powerSaverOn
        run(["sh", "-c", "powerprofilesctl set " + (powerSaverOn ? "power-saver" : "balanced") + " >/dev/null 2>&1"])
        resync.restart()
    }
    function toggleDark() {
        run(["darkman", "toggle"])
        resync.restart()
    }
    function toggleHypridle() {
        hypridleOn = !hypridleOn
        run(["sh", "-c", hypridleOn ? "nohup hypridle >/dev/null 2>&1 &" : "pkill -x hypridle 2>/dev/null"])
        resync.restart()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: cc.close()
    }

    Item {
        id: frame
        anchors { top: parent.top; right: parent.right }
        anchors.margins: 8

        // Free mouse-resizable Control Center. No edit mode or keyboard modifier needed.
        property real panelWidth: 420
        property real panelHeight: Math.min(600, Screen.height - 16)
        readonly property real minPanelWidth: 320
        readonly property real maxPanelWidth: Math.max(minPanelWidth, Screen.width - 24)
        readonly property real minPanelHeight: 360
        readonly property real maxPanelHeight: Math.max(minPanelHeight, parent.height - 16)

        width: Math.min(panelWidth, Math.max(minPanelWidth, parent.width - 16))
        height: Math.min(panelHeight, Math.max(minPanelHeight, parent.height - 16))

        MouseArea { anchors.fill: parent; onClicked: {} }

        // Invisible bottom-left resize zone: no visible grip/button.
        // Hovering this corner changes the cursor; drag to resize freely.
        MouseArea {
            id: resizeGripMouse
            width: 24
            height: 24
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            z: 100
            hoverEnabled: true
            cursorShape: Qt.SizeBDiagCursor
            acceptedButtons: Qt.LeftButton

            property real startWidth: 0
            property real startHeight: 0
            property real startX: 0
            property real startY: 0

            onPressed: function(mouse) {
                startWidth = frame.panelWidth
                startHeight = frame.panelHeight
                startX = mouse.x
                startY = mouse.y
            }

            onPositionChanged: function(mouse) {
                if (!pressed) return
                // Bottom-left corner: dragging left grows width; dragging down grows height.
                const dx = mouse.x - startX
                const dy = mouse.y - startY
                frame.panelWidth = Math.max(
                    frame.minPanelWidth,
                    Math.min(frame.maxPanelWidth, startWidth - dx)
                )
                frame.panelHeight = Math.max(
                    frame.minPanelHeight,
                    Math.min(frame.maxPanelHeight, startHeight + dy)
                )
            }
        }

        Item {
            id: content
            anchors.fill: parent
            clip: true
            transformOrigin: Item.BottomRight
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: Qt.rgba(cc.cSurface.r, cc.cSurface.g, cc.cSurface.b, 0.96)
                border.color: Qt.rgba(cc.cOutline.r, cc.cOutline.g, cc.cOutline.b, 0.08)
                border.width: 1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: cc.view === "main" ? 44 : 40
                    spacing: 10

                    Item {
                        visible: cc.view !== "main"
                        Layout.preferredWidth: visible ? 36 : 0
                        Layout.preferredHeight: 36

                        Rectangle {
                            anchors.centerIn: parent
                            width: 36; height: 36; radius: 18
                            color: backHover.containsMouse ? cc.cSurfaceContainerHigh : cc.cSurfaceContainer

                            Text {
                                anchors.centerIn: parent
                                text: "\ue5cb"
                                color: cc.cOnSurface
                                font.pixelSize: 19
                                font.family: cc.iconFont
                            }
                        }

                        MouseArea {
                            id: backHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (cc.view === "bluetooth" && btPanel.onBackClicked)
                                    btPanel.onBackClicked()
                                else
                                    cc.view = "main"
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: {
                                if (cc.view !== "main") {
                                    if (cc.view === "wifi") return "Интернет"
                                    if (cc.view === "bluetooth" && btPanel.headerTitle) return btPanel.headerTitle
                                    if (cc.view === "bluetooth") return "Bluetooth"
                                    if (cc.view === "battery") return "Батарея"
                                    if (cc.view === "audio") return "Устройства звука"
                                    if (cc.view === "power") return "Питание"
                                }
                                return Qt.formatDateTime(new Date(), "H:mm")
                            }
                            color: cc.cOnSurface
                            font.pixelSize: cc.view === "main" ? 26 : 20
                            font.weight: Font.DemiBold
                        }

                        Text {
                            visible: cc.view === "main"
                            text: Qt.formatDateTime(new Date(), "ddd, d MMM")
                            color: cc.cOnSurfaceVariant
                            font.pixelSize: 10
                        }
                    }

                    Rectangle {
                        visible: cc.view === "main"
                        Layout.preferredWidth: visible ? 36 : 0
                        Layout.preferredHeight: 36
                        radius: 18
                        color: settingsMouse.containsMouse ? cc.cSurfaceContainerHigh : cc.cSurfaceContainer

                        Text {
                            anchors.centerIn: parent
                            text: "\ue8b8"
                            font.family: cc.iconFont
                            font.pixelSize: 18
                            color: cc.cOnSurface
                        }

                        MouseArea {
                            id: settingsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cc.run(["sh", "-c", "command -v gnome-control-center >/dev/null 2>&1 && gnome-control-center || true"])
                        }
                    }

                    Rectangle {
                        visible: cc.view === "main"
                        Layout.preferredWidth: visible ? 36 : 0
                        Layout.preferredHeight: 36
                        radius: 18
                        color: powerHeaderMouse.containsMouse ? cc.cSurfaceContainerHigh : cc.cSurfaceContainer

                        Text {
                            anchors.centerIn: parent
                            text: "power_settings_new"
                            font.family: cc.iconFont
                            font.pixelSize: 19
                            color: cc.cOnSurface
                        }

                        MouseArea {
                            id: powerHeaderMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cc.view = "power"
                        }
                    }

                    Item {
                        visible: cc.view === "bluetooth" && btPanel.hasHeaderToggle === true
                        Layout.preferredWidth: visible ? 52 : 0
                        Layout.preferredHeight: 32

                        Rectangle {
                            anchors.centerIn: parent
                            width: 52; height: 32; radius: 16
                            property bool active: btPanel.headerToggleState
                            color: active ? cc.cPrimary : Qt.rgba(cc.cOutline.r, cc.cOutline.g, cc.cOutline.b, 0.3)

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22; height: 22; radius: 11
                                x: parent.active ? parent.width - width - 5 : 5
                                color: parent.active ? cc.cOnPrimary : cc.cOutline
                                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (btPanel.onHeaderToggleClicked) btPanel.onHeaderToggleClicked()
                        }
                    }
                }

                ColumnLayout {
                    visible: cc.view === "main"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    QSSlider {
                        Layout.fillWidth: true
                        value: Math.max(0.1, cc.brightness / 100)
                        icon: "brightness"
                        clickableIcon: true
                        onMoved: function(v) {
                            const clampedValue = Math.max(0.01, v)
                            cc.brightness = Math.round(clampedValue * 100)
                            cc.applyBrightnessLive(cc.brightness)
                        }
                    }
                    QSSlider {
                        Layout.fillWidth: true
                        value: cc.volume
                        icon: "volume_up"
                        clickableIcon: true
                        onIconClicked: cc.view = "audio"
                        onMoved: function(v) {
                            cc.volume = v
                            cc.applyVolumeLive(v)
                        }
                    }

                    GridLayout {
                        id: tileGrid
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        columns: 4
                        columnSpacing: 6
                        rowSpacing: 6

                        Repeater {
                            id: tileGridRepeater
                            model: tileModel

                            delegate: Item {
                                id: tileDelegate
                                required property string key
                                required property int span
                                property string tileKey: key
                                property int dragResizeSpan: span

                                Layout.columnSpan: span
                                Layout.fillWidth: true
                                Layout.preferredHeight: span === 1 ? 50 : 58
                                z: cc.selectedTileKey === tileKey ? 100 : 1

                                QSTile {
                                    id: qs
                                    anchors.fill: parent
                                    compact: tileDelegate.span === 1
                                    editing: cc.editMode
                                    editKey: tileDelegate.key
                                    icon: cc.tileIcon(tileDelegate.key)
                                    title: cc.tileTitle(tileDelegate.key)
                                    subtitle: cc.tileSubtitle(tileDelegate.key)
                                    active: cc.tileActive(tileDelegate.key)
                                    enabledState: cc.tileEnabled(tileDelegate.key)
                                    hasDetail: tileDelegate.key === "wifi" || tileDelegate.key === "bt" || tileDelegate.key === "battery" || tileDelegate.key === "power"
                                    onTapped: cc.tileTapped(tileDelegate.tileKey)
                                    onDetailTapped: cc.tileDetail(tileDelegate.tileKey)

                                    border.width: cc.editMode && cc.selectedTileKey === tileDelegate.tileKey ? 2 : 0
                                    border.color: cc.cPrimary
                                }

                                // In edit mode the whole tile is the drag surface.
                                // The right edge remains reserved for resizing.
                                MouseArea {
                                    id: tileDragArea
                                    anchors.fill: parent
                                    anchors.rightMargin: 18
                                    visible: cc.editMode
                                    enabled: cc.editMode
                                    z: 25
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                    property bool moving: false

                                    onPressed: function(mouse) {
                                        cc.selectedTileKey = tileDelegate.tileKey
                                        moving = true
                                        tileDelegate.scale = 1.035
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (!pressed || !moving) return
                                        const point = tileDragArea.mapToItem(tileGrid, mouse.x, mouse.y)
                                        cc.moveTileByPointer(tileDelegate.tileKey, point.x, point.y)
                                    }

                                    onReleased: {
                                        moving = false
                                        tileDelegate.scale = 1.0
                                        cc.saveTileLayout()
                                    }

                                    onCanceled: {
                                        moving = false
                                        tileDelegate.scale = 1.0
                                    }
                                }

                                MouseArea {
                                    id: resizeEdge
                                    visible: cc.editMode && cc.selectedTileKey === tileDelegate.tileKey
                                    enabled: visible
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.right: parent.right
                                    width: 18
                                    z: 30
                                    hoverEnabled: true
                                    cursorShape: Qt.SizeHorCursor
                                    property real resizeStartX: 0
                                    property int resizeStartSpanLocal: 1

                                    onPressed: function(mouse) {
                                        resizeStartX = mouse.x
                                        resizeStartSpanLocal = tileDelegate.span
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (!pressed) return
                                        tileDelegate.dragResizeSpan = cc.resizeTileFromDrag(
                                            tileDelegate.tileKey,
                                            resizeStartSpanLocal,
                                            mouse.x - resizeStartX
                                        )
                                    }

                                    onReleased: cc.saveTileLayout()
                                }

                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 82
                        radius: 22
                        color: cc.cSurfaceContainer

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 54
                                Layout.preferredHeight: 54
                                radius: 16
                                color: cc.mediaPlaying ? cc.cPrimary : cc.cSurfaceContainerHigh

                                Text {
                                    anchors.centerIn: parent
                                    text: cc.mediaPlaying ? "music_note" : "music_off"
                                    font.family: cc.iconFont
                                    font.pixelSize: 24
                                    color: cc.mediaPlaying ? cc.cOnPrimary : cc.cPrimary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                Text {
                                    Layout.fillWidth: true
                                    text: cc.mediaTitle
                                    color: cc.cOnSurface
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: cc.mediaArtist
                                    color: cc.cOnSurfaceVariant
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter
                                    spacing: 18

                                    Text {
                                        text: "skip_previous"
                                        font.family: cc.iconFont
                                        font.pixelSize: 20
                                        color: cc.mediaAvailable ? cc.cOnSurfaceVariant : cc.cOutline
                                        MouseArea { anchors.fill: parent; enabled: cc.mediaAvailable; cursorShape: Qt.PointingHandCursor; onClicked: cc.mediaCommand("previous") }
                                    }
                                    Text {
                                        text: cc.mediaPlaying ? "pause" : "play_arrow"
                                        font.family: cc.iconFont
                                        font.pixelSize: 24
                                        color: cc.mediaAvailable ? cc.cOnSurface : cc.cOutline
                                        MouseArea { anchors.fill: parent; enabled: cc.mediaAvailable; cursorShape: Qt.PointingHandCursor; onClicked: cc.mediaCommand("toggle") }
                                    }
                                    Text {
                                        text: "skip_next"
                                        font.family: cc.iconFont
                                        font.pixelSize: 20
                                        color: cc.mediaAvailable ? cc.cOnSurfaceVariant : cc.cOutline
                                        MouseArea { anchors.fill: parent; enabled: cc.mediaAvailable; cursorShape: Qt.PointingHandCursor; onClicked: cc.mediaCommand("next") }
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        Layout.rightMargin: 44

                        Text {
                            visible: cc.editMode
                            text: cc.editMode ? "Перетаскивай плитку · правый край — размер" : ""
                            font.pixelSize: 10
                            color: cc.cOnSurfaceVariant
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: cc.editMode
                            Layout.preferredWidth: 58
                            Layout.preferredHeight: 28
                            radius: 14
                            color: resetLayoutMouse.containsMouse ? cc.cSurfaceContainerHigh : cc.cSurfaceContainer

                            Text {
                                anchors.centerIn: parent
                                text: "Сброс"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: cc.cOnSurface
                            }

                            MouseArea {
                                id: resetLayoutMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cc.resetTileLayout()
                            }
                        }

                        Rectangle {
                            width: 30
                            height: 24
                            radius: 12
                            color: cc.editMode
                                ? cc.cPrimary
                                : (editMouse.containsMouse ? cc.cSurfaceContainerHigh : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: cc.editMode ? "✓" : "edit"
                                font.family: cc.editMode ? "Sans Serif" : cc.iconFont
                                font.pixelSize: cc.editMode ? 15 : 16
                                font.weight: cc.editMode ? Font.Bold : Font.Normal
                                color: cc.editMode ? cc.cOnPrimary : cc.cOnSurfaceVariant
                            }

                            MouseArea {
                                id: editMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    cc.editMode = !cc.editMode
                                    if (!cc.editMode) {
                                        cc.selectedTileKey = ""
                                        cc.saveTileLayout()
                                    }
                                }
                            }
                        }
                    }
                }

                Components.WifiPanel {
                    id: wifiPanel;
                    ctl: cc
                    visible: cc.view === "wifi"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
                Components.BluetoothPanel {
                    id: btPanel;
                    ctl: cc
                    visible: cc.view === "bluetooth"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
                Components.BatteryPanel {
                    id: batPanel;
                    ctl: cc
                    visible: cc.view === "battery"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                ScrollView {
                    visible: cc.view === "audio"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ColumnLayout {
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: cc.audioSinks
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 60
                                radius: 18

                                readonly property bool isSelected: modelData.name === cc.defaultSink

                                color: isSelected 
                                    ? cc.cPrimary 
                                    : (itemMouse.containsMouse ? cc.cSurfaceContainerHigh : cc.cSurfaceContainer)

                                Behavior on color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: 12
                                        color: isSelected ? "transparent" : Qt.rgba(cc.cPrimary.r, cc.cPrimary.g, cc.cPrimary.b, 0.2)

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰕾"
                                            font.pixelSize: 18
                                            color: isSelected ? cc.cOnPrimary : cc.cPrimary
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.description
                                        font.pixelSize: 13
                                        font.bold: isSelected
                                        elide: Text.ElideRight
                                        color: isSelected ? cc.cOnPrimary : cc.cOnSurface
                                    }

                                    Text {
                                        visible: isSelected
                                        text: "✓"
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: cc.cOnPrimary
                                    }
                                }

                                MouseArea {
                                    id: itemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: cc.setAudioSink(modelData.name)
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: cc.view === "power"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    M3PowerTile {
                        icon: "󰐥"
                        title: "Выключить"
                        subtitle: "Завершить работу системы"
                        isDanger: true
                        cmd: ["systemctl", "poweroff"]
                    }

                    M3PowerTile {
                        icon: "󰜉"
                        title: "Перезагрузить"
                        subtitle: "Перезапустить систему"
                        cmd: ["systemctl", "reboot"]
                    }

                    M3PowerTile {
                        icon: "󰤀"
                        title: "Сон"
                        subtitle: "Приостановить работу"
                        cmd: ["systemctl", "suspend"]
                    }

                    M3PowerTile {
                        icon: "󰌾"
                        title: "Заблокировать"
                        subtitle: "Перейти к экрану входа"
                        cmd: ["sh", "-c", "command -v hyprlock >/dev/null 2>&1 && hyprlock || command -v swaylock >/dev/null 2>&1 && swaylock -f -c 000000 || loginctl lock-session"]
                    }

                    M3PowerTile {
                        icon: "󰍃"
                        title: "Выйти"
                        subtitle: "Завершить сеанс пользователя"
                        cmd: ["sh", "-c", "command -v hyprctl >/dev/null 2>&1 && hyprctl dispatch exit || command -v swaymsg >/dev/null 2>&1 && swaymsg exit || loginctl terminate-user $USER"]
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
