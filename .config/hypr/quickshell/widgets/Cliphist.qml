import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"

PanelWindow {
    id: root
    
    // Растягиваем невидимое окно на весь экран
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    visible: false 

    // Закрытие по клику вне меню
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    // Закрытие по Escape
    Shortcut {
        sequence: "Escape"
        onActivated: root.visible = false
    }

    function toggle() {
        root.visible = !root.visible;
        if (root.visible) {
            loadClipboard();
            searchInput.forceActiveFocus();
        }
    }

    property var clipboardItems: []

    function loadClipboard() {
        clipboardItems = [];
        cliphistListProcess.running = true;
    }

    Process {
        id: cliphistListProcess
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() !== "") {
                    let parts = data.split("\t");
                    if (parts.length >= 2) {
                        clipboardItems.push({
                            id: parts[0],
                            text: parts.slice(1).join("\t")
                        });
                    }
                }
            }
        }
        onExited: {
            listView.model = clipboardItems;
        }
    }

    Process {
        id: cliphistActionProcess
        command: []
    }

    Process {
        id: cliphistWipeProcess
        command: ["cliphist", "wipe"]
        onExited: {
            clipboardItems = [];
            listView.model = [];
        }
    }

    // Само окно буфера обмена (размещаем по центру)
    Rectangle {
        width: 440
        height: 560
        anchors.centerIn: parent
        color: Colors.surfaceContainerLow
        radius: 28
        border.color: Colors.outlineVariant
        border.width: 1

        // Блокируем клики, чтобы они не уходили на закрытие окна (в нижний MouseArea)
        MouseArea {
            anchors.fill: parent
            onClicked: {} // пустое действие, клик "поглощается"
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            // Шапка
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        text: "Буфер обмена"
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        color: Colors.surfaceText
                    }
                    Label {
                        text: clipboardItems.length + " элементов сохранено"
                        font.pixelSize: 13
                        color: Colors.outline
                    }
                }

                // Корзина (Очистить всё)
                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: clearMouse.containsMouse ? Colors.errorContainer : Colors.surfaceContainerHighest
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "🗑"
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: cliphistWipeProcess.running = true
                    }
                }
            }

            // Поиск
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: Colors.surfaceContainerHighest
                radius: 24
                border.color: searchInput.activeFocus ? Colors.primary : "transparent"
                border.width: 1.5
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 10

                    Text { 
                        text: "🔍" 
                        font.pixelSize: 14 
                        color: Colors.outline 
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.pixelSize: 14
                        color: Colors.surfaceText
                        selectionColor: Colors.primary
                        selectedTextColor: Colors.primaryText
                        verticalAlignment: TextInput.AlignVCenter
                        
                        Text {
                            text: "Поиск в истории..."
                            color: Colors.outline
                            font.pixelSize: 14
                            visible: searchInput.text.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: {
                            if (text.trim() === "") {
                                listView.model = clipboardItems;
                            } else {
                                listView.model = clipboardItems.filter(item => 
                                    item.text.toLowerCase().includes(searchInput.text.toLowerCase())
                                );
                            }
                        }
                    }
                }
            }

            // Список
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 8

                delegate: Item {
                    width: listView.width
                    height: 60
                    required property var modelData
                    required property int index

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: itemMouse.containsMouse ? Colors.surfaceContainerHigh : Colors.surfaceContainer
                        border.color: itemMouse.containsMouse ? Colors.primaryContainer : "transparent"
                        border.width: 1
                        
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 10
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2
                                
                                Label { 
                                    text: "ID: " + modelData.id
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: Colors.primary 
                                }
                                
                                Label { 
                                    text: modelData.text
                                    font.pixelSize: 14
                                    color: Colors.surfaceText
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    maximumLineCount: 1 
                                }
                            }

                            // Кнопка удаления одного элемента
                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 16
                                color: deleteMouse.containsMouse ? Colors.errorContainer : "transparent"
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: deleteMouse.containsMouse ? Colors.errorContainerText : Colors.outline
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    id: deleteMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        // ИСправлено: используем \s вместо \t для надежного поиска по ID
                                        cliphistActionProcess.command = ["bash", "-c", "cliphist list | grep -E '^" + modelData.id + "\\s' | cliphist delete"];
                                        cliphistActionProcess.running = true;
                                        
                                        clipboardItems = clipboardItems.filter(i => i.id !== modelData.id);
                                        listView.model = clipboardItems;
                                    }
                                }
                            }
                        }

                        // Копирование элемента И автоматическая вставка
                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: (mouse) => {
                                // По умолчанию эмулируем Ctrl+V
                                let pasteCommand = "wtype -M ctrl -k v -m ctrl";
                                
                                // Если при клике был зажат Shift, эмулируем Ctrl+Shift+V (для терминала)
                                if (mouse.modifiers & Qt.ShiftModifier) {
                                    pasteCommand = "wtype -M ctrl -M shift -k v -m shift -m ctrl";
                                }

                                cliphistActionProcess.command = [
                                    "bash", 
                                    "-c", 
                                    "cliphist list | grep -E '^" + modelData.id + "\\s' | cliphist decode | wl-copy && sleep 0.1 && " + pasteCommand
                                ];
                                cliphistActionProcess.running = true;
                                root.visible = false; 
                            }
                        }
                    }
                }
            }
        }
    }
}
