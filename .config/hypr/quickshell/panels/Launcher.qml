import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "../core" as Matugen

PanelWindow {
    id: sheet
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "app-drawer"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors { top: true; left: true; right: true; bottom: true }
    visible: open
    color: "transparent"

    property bool open: false

    property real clickX: sheet.width / 2
    property real clickY: sheet.height / 2

    // ── IPC Handler (Исправлено) ─────────────────────────
    IpcHandler {
        target: "launcher"
        function toggle(): void { sheet.open = !sheet.open }
        function open(): void { sheet.open = true }
        function close(): void { sheet.open = false }
    }

    property var apps: []
    property var recentApps: []
    property var pinnedApps: []

    property var filteredApps: []
    property var filteredFiles: []
    property var filteredWeb: []

    // Объединенный массив (сначала закрепленные, затем недавние)
    readonly property var topApps: {
        let list = []
        let pinnedExecs = new Set()

        for (let i = 0; i < pinnedApps.length; i++) {
            list.push(pinnedApps[i])
            pinnedExecs.add(pinnedApps[i].exec)
        }

        for (let i = 0; i < recentApps.length; i++) {
            if (!pinnedExecs.has(recentApps[i].exec)) {
                list.push(recentApps[i])
            }
        }

        return list.slice(0, 6)
    }

    function toggle(x, y) { 
        if (x !== undefined && y !== undefined) {
            clickX = x
            clickY = y
        }
        open = !open 
    }

    // ── Размытие фона через Hyprland ────────────────────────
    Process { id: blurProc }
    function setBlur(enable) {
        blurProc.command = ["hyprctl", "keyword", "layerrule", enable ? "blur, app-drawer" : "unset, app-drawer"]
        blurProc.running = true
    }

    // ── Сохранение и загрузка ──────────────────────────
    Process {
        id: loadRecentProc
        command: ["sh", "-c", "cat ~/.cache/quickshell/recent_apps.json 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { sheet.recentApps = JSON.parse(text) } catch(e) { sheet.recentApps = [] }
            }
        }
    }

    Process {
        id: loadPinnedProc
        command: ["sh", "-c", "cat ~/.cache/quickshell/pinned_apps.json 2>/dev/null || echo '[]'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { sheet.pinnedApps = JSON.parse(text) } catch(e) { sheet.pinnedApps = [] }
            }
        }
    }

    Process { id: saveRecentProc }
    Process { id: savePinnedProc }
    Process { id: hideAppProc }

    function saveRecentHistory(list) {
        const jsonB64 = Qt.btoa(JSON.stringify(list))
        saveRecentProc.command = ["sh", "-c", "mkdir -p ~/.cache/quickshell && echo '" + jsonB64 + "' | base64 -d > ~/.cache/quickshell/recent_apps.json"]
        saveRecentProc.running = true
    }

    function savePinnedHistory(list) {
        const jsonB64 = Qt.btoa(JSON.stringify(list))
        savePinnedProc.command = ["sh", "-c", "mkdir -p ~/.cache/quickshell && echo '" + jsonB64 + "' | base64 -d > ~/.cache/quickshell/pinned_apps.json"]
        savePinnedProc.running = true
    }

    function recordAppLaunch(app) {
        if (!app || app.isWebSearch || app.isFile) return
        let list = sheet.recentApps.filter(a => a.exec !== app.exec)
        list.unshift(app)
        if (list.length > 6) list = list.slice(0, 6)
        sheet.recentApps = list
        saveRecentHistory(list)
    }

    function isPinned(app) {
        if (!app) return false
        return sheet.pinnedApps.some(a => a.exec === app.exec)
    }

    function togglePin(app) {
        if (!app || app.isWebSearch || app.isFile) return
        let list = sheet.pinnedApps.slice()
        if (isPinned(app)) {
            list = list.filter(a => a.exec !== app.exec)
        } else {
            list.push(app)
        }
        sheet.pinnedApps = list
        savePinnedHistory(list)
    }

    function hideApp(app) {
        if (!app || !app.desktopFile) return
        
        const fileName = app.desktopFile.split("/").pop()
        const script = `
            DEST="$HOME/.local/share/applications/${fileName}"
            mkdir -p "$HOME/.local/share/applications"
            if [ -f "${app.desktopFile}" ]; then
                cp "${app.desktopFile}" "$DEST"
            fi
            grep -q "^NoDisplay=" "$DEST" 2>/dev/null && sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$DEST" || echo "NoDisplay=true" >> "$DEST"
        `
        hideAppProc.command = ["sh", "-c", script]
        hideAppProc.running = true
        
        hideAppProc.onExited.connect(() => appScan.running = true)
    }

    Component.onCompleted: {
        loadRecentProc.running = true
        loadPinnedProc.running = true
    }

    // ── Затемнение заднего плана ──────────────────────────
    MouseArea {
        id: backdrop
        anchors.fill: parent
        opacity: sheet.open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.25
        }

        onClicked: sheet.open = false
    }

    // ── Сканирование приложений ──────────────────────────
    Process {
        id: appScan
        running: true
        command: ["sh", "-c",
            "resolve() { i=\"$1\"; [ -z \"$i\" ] && return; " +
            "case \"$i\" in \\~/*) i=\"$HOME${i#\\~}\";; esac; " +
            "case \"$i\" in /*) [ -f \"$i\" ] && { echo \"$i\"; return; }; esac; " +
            "[ -f \"$i\" ] && { echo \"$i\"; return; }; " +
            "p=$(find /usr/share/icons /usr/share/pixmaps \"$HOME/.local/share/icons\" -type f -iname \"$i.png\" 2>/dev/null | head -1); " +
            "[ -n \"$p\" ] && { echo \"$p\"; return; }; " +
            "p=$(find /usr/share/icons /usr/share/pixmaps \"$HOME/.local/share/icons\" -type f \\( -iname \"$i.svg\" -o -iname \"$i.xpm\" \\) 2>/dev/null | head -1); " +
            "[ -n \"$p\" ] && { echo \"$p\"; return; }; " +
            "[ -f /usr/share/pixmaps/$i ] && echo /usr/share/pixmaps/$i; }; " +
            "emit() { f=\"$1\"; " +
            "grep -qi '^NoDisplay=true' \"$f\" && return; " +
            "grep -qi '^Hidden=true' \"$f\" && return; " +
            "name=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2- | tr -d '\\r' | sed 's/^ *//;s/ *$//'); " +
            "exec=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2- | tr -d '\\r' | sed 's/ *%[a-zA-Z]//g'); " +
            "icon=$(grep -m1 '^Icon=' \"$f\" | cut -d= -f2- | tr -d '\\r' | sed 's/^ *//;s/ *$//'); " +
            "comment=$(grep -m1 '^Comment=' \"$f\" | cut -d= -f2- | tr -d '\\r' | sed 's/^ *//;s/ *$//'); " +
            "cat=$(grep -m1 '^Categories=' \"$f\" | cut -d= -f2- | tr -d '\\r' | sed 's/^ *//;s/ *$//'); " +
            "[ -z \"$icon\" ] && [ -f /usr/share/applications/${f##*/} ] && icon=$(grep -m1 '^Icon=' /usr/share/applications/${f##*/} | cut -d= -f2- | tr -d '\\r' | sed 's/^ *//;s/ *$//'); " +
            "[ -z \"$exec\" ] && return; " +
            "ipath=$(resolve \"$icon\"); " +
            "[ -n \"$name\" ] && [ -n \"$exec\" ] && printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$name\" \"$exec\" \"$ipath\" \"$comment\" \"$cat\" \"$f\"; }; " +
            "L=\"$HOME/.local/share/applications\"; " +
            "S=\"/usr/share/applications\"; " +
            "{ " +
            "  find \"$L\" -type f -name \"*.desktop\" 2>/dev/null | while read -r f; do emit \"$f\"; done; " +
            "  find \"$S\" -type f -name \"*.desktop\" 2>/dev/null | while read -r f; do b=${f##*/}; [ -e \"$L/$b\" ] || emit \"$f\"; done; " +
            "} | sort -t$'\\t' -k1,1"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of text.split("\n")) {
                    const p = line.split("\t")
                    if (p.length >= 2 && p[0]) list.push({ 
                        name: p[0], 
                        exec: p[1], 
                        icon: p[2] || "",
                        comment: p[3] || "",
                        category: p[4] || "",
                        desktopFile: p[5] || ""
                    })
                }
                sheet.apps = list
                sheet.filterApps(searchField.text)
            }
        }
    }

    // ── Поиск файлов ──────────────────────────
    Process {
        id: fileSearchProc
        stdout: StdioCollector {
            onStreamFinished: {
                const fileList = []
                for (const line of text.split("\n")) {
                    if (!line.trim()) continue
                    const parts = line.split("\t")
                    const path = parts[0]
                    const name = parts[1] || path.split("/").pop()
                    
                    fileList.push({
                        name: name,
                        exec: "xdg-open \"" + path + "\"",
                        icon: "",
                        comment: path,
                        category: "File",
                        isFile: true
                    })
                }
                sheet.filteredFiles = fileList
            }
        }
    }

    function searchFiles(q) {
        if (!q || q.length < 2) {
            sheet.filteredFiles = []
            return
        }
        fileSearchProc.command = ["sh", "-c", "find ~ -maxdepth 3 -not -path '*/.*' -iname '*" + q.replace(/'/g, "'\\''") + "*' 2>/dev/null | head -n 6 | while read -r f; do printf '%s\t%s\n' \"$f\" \"${f##*/}\"; done"]
        fileSearchProc.running = true
    }

    Process { id: appRunner }
    Process { id: clipboardProc }

    function copyCommand(app) {
        if (!app || !app.exec) return
        const b64 = Qt.btoa(app.exec)
        clipboardProc.command = ["sh", "-c",
            "printf '%s' '" + b64 + "' | base64 -d | " +
            "(command -v wl-copy >/dev/null 2>&1 && wl-copy || xclip -selection clipboard)"]
        clipboardProc.running = true
    }

    function filterApps(q) {
        if (!q) { 
            filteredApps = apps
            filteredFiles = []
            filteredWeb = []
            return 
        }
        const s = q.toLowerCase()
        
        filteredApps = apps.filter(a => 
            a.name.toLowerCase().includes(s) ||
            a.comment.toLowerCase().includes(s) ||
            a.exec.toLowerCase().includes(s) ||
            a.category.toLowerCase().includes(s)
        )

        searchFiles(q)

        filteredWeb = [{
            name: "Поиск в сети: " + q,
            exec: "xdg-open \"https://www.google.com/search?q=" + encodeURIComponent(q) + "\"",
            icon: "",
            comment: "Искать в Интернете",
            category: "Web",
            isWebSearch: true
        }]
    }

    function launch(app) {
        if (!app) return
        recordAppLaunch(app)
        appRunner.command = ["sh", "-c", app.exec + " >/dev/null 2>&1 &"]
        appRunner.running = true
        open = false
    }

    function launchFirstAvailable() {
        if (filteredApps.length > 0) launch(filteredApps[0])
        else if (filteredFiles.length > 0) launch(filteredFiles[0])
        else if (filteredWeb.length > 0) launch(filteredWeb[0])
    }

    onOpenChanged: {
        setBlur(open)
        if (open) {
            searchField.text = ""
            filterApps("")
            Qt.callLater(() => {
                searchField.forceActiveFocus()
                slideOut.stop()
                slideIn.start()
            })
        } else {
            slideIn.stop()
            slideOut.start()
        }
    }

    // ── Позиционирование и анимация выезда снизу ───────
    Item {
        id: frame
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2
        width: 680
        height: 700

        MouseArea { anchors.fill: parent }

        Item {
            id: content
            anchors.fill: parent

            ParallelAnimation {
                id: slideIn
                NumberAnimation { 
                    target: content
                    property: "y"
                    from: sheet.height
                    to: 0
                    duration: 300
                    easing.type: Easing.OutCubic 
                }
                NumberAnimation { 
                    target: content
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 200 
                }
            }

            ParallelAnimation {
                id: slideOut
                NumberAnimation { 
                    target: content
                    property: "y"
                    to: sheet.height
                    duration: 250
                    easing.type: Easing.InCubic 
                }
                NumberAnimation { 
                    target: content
                    property: "opacity"
                    to: 0
                    duration: 200 
                }
            }

            Rectangle { 
                anchors.fill: parent
                anchors.margins: -6
                radius: 34
                color: "#000000"
                opacity: 0.3
            }

            Rectangle {
                anchors.fill: parent
                radius: 32
                color: "#D916141C" 
                border.color: "#30FFFFFF"
                border.width: 1
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 12
                anchors.bottomMargin: 20
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 16

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 36
                    height: 4
                    radius: 2
                    color: Matugen.Colors.outline || "#938F99"
                }

                // Поисковая строка
                Rectangle {
                    Layout.fillWidth: true
                    height: 56
                    radius: 28
                    color: "#A02B2930"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: "G"
                            font.pixelSize: 22
                            font.weight: Font.ExtraBold
                            color: Matugen.Colors.primary || "#8AB4F8"
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            color: Matugen.Colors.onSurface || "#E6E1E5"
                            font.pixelSize: 16
                            background: Item {}
                            onTextChanged: sheet.filterApps(text)
                            Keys.onEscapePressed: sheet.open = false
                            Keys.onReturnPressed: sheet.launchFirstAvailable()
                        }

                        RowLayout {
                            spacing: 12
                            visible: searchField.text.length === 0

                            Text {
                                text: "\ue029"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 22
                                color: Matugen.Colors.onSurfaceVariant || "#C4C6D0"
                            }
                            Text {
                                text: "\ue412"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 22
                                color: Matugen.Colors.onSurfaceVariant || "#C4C6D0"
                            }
                        }

                        Text {
                            text: "\ue5cd"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 22
                            color: Matugen.Colors.onSurfaceVariant || "#C4C6D0"
                            visible: searchField.text.length > 0

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { searchField.text = ""; searchField.forceActiveFocus() }
                            }
                        }
                    }
                }

                // ─ ЕДИНАЯ ОБЛАСТЬ ПРОКРУТКИ ─
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: mainColumn.height
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: mainColumn
                        width: parent.width
                        spacing: 20

                        // ── ЗАКРЕПЛЕННЫЕ И НЕДАВНИЕ В ЕДИНОМ РЯДУ ──
                        GridView {
                            id: topGrid
                            Layout.fillWidth: true
                            implicitHeight: count > 0 ? 96 : 0
                            visible: searchField.text.length === 0 && count > 0
                            cellWidth: Math.floor(topGrid.width / 6)
                            cellHeight: 96
                            interactive: false
                            model: sheet.topApps

                            delegate: Item {
                                width: topGrid.cellWidth
                                height: topGrid.cellHeight

                                property bool isAppPinned: sheet.isPinned(modelData)

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 54; height: 54
                                        radius: 18
                                        color: topMouse.containsMouse ? "#50FFFFFF" : "#20FFFFFF"

                                        border.color: !isAppPinned ? (Matugen.Colors.primary || "#8AB4F8") : "transparent"
                                        border.width: !isAppPinned ? 5 : 0

                                        scale: topMouse.pressed ? 0.90 : (topMouse.containsMouse ? 1.05 : 1.0)
                                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                        Image {
                                            id: topIconImg
                                            anchors.centerIn: parent
                                            width: 36; height: 36
                                            fillMode: Image.PreserveAspectFit
                                            source: modelData.icon !== "" ? "file://" + modelData.icon : ""
                                            visible: modelData.icon !== "" && status === Image.Ready
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.name.charAt(0).toUpperCase()
                                            color: Matugen.Colors.onSurface || "#E6E1E5"
                                            font.pixelSize: 22
                                            font.weight: Font.Bold
                                            visible: !topIconImg.visible
                                        }
                                    }

                                    Text {
                                        width: topGrid.cellWidth - 8
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.name
                                        color: Matugen.Colors.onSurface || "#E6E1E5"
                                        font.pixelSize: 12
                                        font.weight: Font.Normal
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        maximumLineCount: 1
                                    }
                                }

                                MouseArea {
                                    id: topMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.LeftButton) {
                                            sheet.launch(modelData)
                                        } else if (mouse.button === Qt.RightButton) {
                                            contextMenu.targetApp = modelData
                                            contextMenu.popup()
                                        }
                                    }
                                }
                            }
                        }

                        // ── 1. ПРИЛОЖЕНИЯ ──
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: sheet.filteredApps.length > 0
                            spacing: 8

                            Text {
                                text: "Все приложения"
                                color: Matugen.Colors.primary || "#8AB4F8"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                visible: searchField.text.length > 0
                            }

                            GridView {
                                id: appGrid
                                Layout.fillWidth: true
                                implicitHeight: Math.ceil(count / 6) * 96
                                cellWidth: Math.floor(appGrid.width / 6)
                                cellHeight: 96
                                interactive: false
                                model: sheet.filteredApps

                                delegate: Item {
                                    width: appGrid.cellWidth
                                    height: appGrid.cellHeight

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 54; height: 54
                                            radius: 18
                                            color: appMouse.containsMouse ? "#50FFFFFF" : "#20FFFFFF"

                                            scale: appMouse.pressed ? 0.90 : (appMouse.containsMouse ? 1.05 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                            Image {
                                                id: appIconImg
                                                anchors.centerIn: parent
                                                width: 36; height: 36
                                                fillMode: Image.PreserveAspectFit
                                                source: modelData.icon !== "" ? "file://" + modelData.icon : ""
                                                visible: modelData.icon !== "" && status === Image.Ready
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.name.charAt(0).toUpperCase()
                                                color: Matugen.Colors.onSurface || "#E6E1E5"
                                                font.pixelSize: 22
                                                font.weight: Font.Bold
                                                visible: !appIconImg.visible
                                            }
                                        }

                                        Text {
                                            width: appGrid.cellWidth - 8
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.name
                                            color: Matugen.Colors.onSurface || "#E6E1E5"
                                            font.pixelSize: 12
                                            font.weight: Font.Normal
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                            maximumLineCount: 1
                                        }
                                    }

                                    MouseArea {
                                        id: appMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                sheet.launch(modelData)
                                            } else if (mouse.button === Qt.RightButton) {
                                                contextMenu.targetApp = modelData
                                                contextMenu.popup()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── 2. ФАЙЛЫ ──
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: sheet.filteredFiles.length > 0
                            spacing: 8

                            Text {
                                text: "Файлы"
                                color: Matugen.Colors.primary || "#8AB4F8"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            GridView {
                                id: fileGrid
                                Layout.fillWidth: true
                                implicitHeight: Math.ceil(count / 6) * 96
                                cellWidth: Math.floor(fileGrid.width / 6)
                                cellHeight: 96
                                interactive: false
                                model: sheet.filteredFiles

                                delegate: Item {
                                    width: fileGrid.cellWidth
                                    height: fileGrid.cellHeight

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 54; height: 54
                                            radius: 18
                                            color: fileMouse.containsMouse ? "#50FFFFFF" : "#20FFFFFF"

                                            scale: fileMouse.pressed ? 0.90 : (fileMouse.containsMouse ? 1.05 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\ue24d"
                                                font.family: "Material Symbols Outlined"
                                                color: Matugen.Colors.onSurface || "#E6E1E5"
                                                font.pixelSize: 22
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Text {
                                            width: fileGrid.cellWidth - 8
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.name
                                            color: Matugen.Colors.onSurface || "#E6E1E5"
                                            font.pixelSize: 12
                                            font.weight: Font.Normal
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                            maximumLineCount: 1
                                        }
                                    }

                                    MouseArea {
                                        id: fileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                sheet.launch(modelData)
                                            } else if (mouse.button === Qt.RightButton) {
                                                contextMenu.targetApp = modelData
                                                contextMenu.popup()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── 3. ВЕБ ──
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: sheet.filteredWeb.length > 0
                            spacing: 8

                            Text {
                                text: "Интернет"
                                color: Matugen.Colors.primary || "#8AB4F8"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                            }

                            GridView {
                                id: webGrid
                                Layout.fillWidth: true
                                implicitHeight: Math.ceil(count / 6) * 96
                                cellWidth: Math.floor(webGrid.width / 6)
                                cellHeight: 96
                                interactive: false
                                model: sheet.filteredWeb

                                delegate: Item {
                                    width: webGrid.cellWidth
                                    height: webGrid.cellHeight

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 54; height: 54
                                            radius: 18
                                            color: webMouse.containsMouse ? "#50FFFFFF" : "#20FFFFFF"

                                            scale: webMouse.pressed ? 0.90 : (webMouse.containsMouse ? 1.05 : 1.0)
                                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "\ue8b6"
                                                font.family: "Material Symbols Outlined"
                                                color: Matugen.Colors.onSurface || "#E6E1E5"
                                                font.pixelSize: 22
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Text {
                                            width: webGrid.cellWidth - 8
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.name
                                            color: Matugen.Colors.onSurface || "#E6E1E5"
                                            font.pixelSize: 12
                                            font.weight: Font.Normal
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                            maximumLineCount: 1
                                        }
                                    }

                                    MouseArea {
                                        id: webMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                sheet.launch(modelData)
                                            } else if (mouse.button === Qt.RightButton) {
                                                contextMenu.targetApp = modelData
                                                contextMenu.popup()
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Сообщение при отсутствии результатов
                        Item {
                            Layout.fillWidth: true
                            height: 150
                            visible: searchField.text.length > 0 && sheet.filteredApps.length === 0 && sheet.filteredFiles.length === 0 && sheet.filteredWeb.length === 0

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "Ничего не найдено"
                                    color: Matugen.Colors.onSurfaceVariant || "#CAC4D0"
                                    font.pixelSize: 16
                                    font.weight: Font.Medium
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── КОНТЕКСТНОЕ МЕНЮ (ПКМ) ──────────────────────────
    //
    // Палитра берётся из Material 3 / Matugen container-токенов,
    // поэтому подсветка одинаково хорошо работает в dark и light теме.
    Menu {
        id: contextMenu
        property var targetApp: null

        implicitWidth: 230
        padding: 6

        background: Rectangle {
            implicitWidth: 230
            radius: 18
            color: Matugen.Colors.surfaceContainerHigh
                   || Matugen.Colors.surfaceContainer
                   || Matugen.Colors.surface
                   || "#25232A"
            border.color: Matugen.Colors.outlineVariant
                          || Matugen.Colors.outline
                          || "#40FFFFFF"
            border.width: 1

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                radius: 1
                color: Matugen.Colors.onSurface || "#FFFFFF"
                opacity: 0.07
            }
        }

        // Небольшой заголовок: иконка + название + категория.
        MenuItem {
            id: menuHeader
            enabled: false
            implicitHeight: 52

            contentItem: RowLayout {
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 12
                    color: Matugen.Colors.secondaryContainer
                           || Matugen.Colors.primaryContainer
                           || "#303038"

                    Image {
                        id: menuHeaderIcon
                        anchors.centerIn: parent
                        width: 27
                        height: 27
                        fillMode: Image.PreserveAspectFit
                        source: contextMenu.targetApp &&
                                contextMenu.targetApp.icon !== ""
                                ? "file://" + contextMenu.targetApp.icon
                                : ""
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !menuHeaderIcon.visible
                        text: contextMenu.targetApp
                              ? contextMenu.targetApp.name.charAt(0).toUpperCase()
                              : "?"
                        color: Matugen.Colors.onSecondaryContainer
                               || Matugen.Colors.onPrimaryContainer
                               || Matugen.Colors.onSurface
                               || "#E6E1E5"
                        font.pixelSize: 17
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        Layout.fillWidth: true
                        text: contextMenu.targetApp
                              ? contextMenu.targetApp.name
                              : ""
                        color: Matugen.Colors.onSurface || "#E6E1E5"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: contextMenu.targetApp
                              ? (contextMenu.targetApp.category || "Приложение")
                              : ""
                        color: Matugen.Colors.onSurfaceVariant || "#CAC4D0"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }
        }

        MenuSeparator {
            padding: 4
            contentItem: Rectangle {
                implicitHeight: 1
                color: Matugen.Colors.outlineVariant
                       || Matugen.Colors.outline
                       || "#40FFFFFF"
                opacity: 0.65
            }
        }

        delegate: MenuItem {
            id: menuItem
            implicitHeight: 40

            contentItem: RowLayout {
                spacing: 10

                Text {
                    Layout.preferredWidth: 20
                    text: {
                        if (menuItem.text === "Открыть") return "open_in_new"
                        if (menuItem.text === "Закрепить" ||
                            menuItem.text === "Открепить") return "push_pin"
                        if (menuItem.text === "Копировать команду") return "content_copy"
                        if (menuItem.text === "Скрыть из меню") return "visibility_off"
                        return "more_horiz"
                    }
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 19
                    color: menuItem.highlighted
                           ? (Matugen.Colors.onSecondaryContainer
                              || Matugen.Colors.onPrimaryContainer
                              || Matugen.Colors.onPrimary
                              || "#FFFFFF")
                           : (Matugen.Colors.onSurfaceVariant
                              || Matugen.Colors.onSurface
                              || "#CAC4D0")
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    Layout.fillWidth: true
                    text: menuItem.text
                    font: menuItem.font
                    color: menuItem.highlighted
                           ? (Matugen.Colors.onSecondaryContainer
                              || Matugen.Colors.onPrimaryContainer
                              || Matugen.Colors.onPrimary
                              || "#FFFFFF")
                           : (Matugen.Colors.onSurface
                              || "#E6E1E5")
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            background: Rectangle {
                radius: 12
                color: menuItem.highlighted
                       ? (Matugen.Colors.secondaryContainer
                          || Matugen.Colors.primaryContainer
                          || "#45404A")
                       : "transparent"
            }
        }

        MenuItem {
            text: "Открыть"
            onTriggered: {
                if (contextMenu.targetApp)
                    sheet.launch(contextMenu.targetApp)
            }
        }

        MenuItem {
            visible: contextMenu.targetApp &&
                     !contextMenu.targetApp.isFile &&
                     !contextMenu.targetApp.isWebSearch
            text: sheet.isPinned(contextMenu.targetApp)
                  ? "Открепить"
                  : "Закрепить"

            onTriggered: {
                if (contextMenu.targetApp)
                    sheet.togglePin(contextMenu.targetApp)
            }
        }

        MenuItem {
            visible: contextMenu.targetApp &&
                     !contextMenu.targetApp.isFile &&
                     !contextMenu.targetApp.isWebSearch &&
                     !!contextMenu.targetApp.exec
            text: "Копировать команду"

            onTriggered: {
                if (contextMenu.targetApp)
                    sheet.copyCommand(contextMenu.targetApp)
            }
        }

        MenuSeparator {
            padding: 4
            contentItem: Rectangle {
                implicitHeight: 1
                color: Matugen.Colors.outlineVariant
                       || Matugen.Colors.outline
                       || "#40FFFFFF"
                opacity: 0.45
            }
        }

        MenuItem {
            visible: contextMenu.targetApp &&
                     !contextMenu.targetApp.isFile &&
                     !contextMenu.targetApp.isWebSearch
            text: "Скрыть из меню"

            onTriggered: {
                if (contextMenu.targetApp)
                    sheet.hideApp(contextMenu.targetApp)
            }
        }
    }

}
