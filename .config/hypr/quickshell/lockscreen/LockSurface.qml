import "../core"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: root
    color: Colors.background // Используем цвет фона из темы

    property var context
    property var controlCenter
    property var passwordShapes: {
        const shapes = ["●", "◆", "▲", "■", "★", "⬟", "⬡", "⬢"]
        let result = []
        for (let i = 0; i < root.context.currentText.length; i++) {
            result.push(shapes[i % shapes.length])
        }
        return result
    }
    
    property int screenState: 0

    // ─ ОБОИ ────────────────────────────────────────────────────────────
    Image {
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.config/hypr/background.png"
        fillMode: Image.PreserveAspectCrop
        z: 0
    }

    // ── ЗАТЕМНЕНИЕ ──────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Colors.background
        opacity: 0.5 // Чуть усилили для лучшей читаемости светлых элементов
        z: 1
    }

    // ─ ВЕРХНЯЯ ПАНЕЛЬ ─────────────────────────────────────────────────
    LockTopBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        z: 10
    }

    // ═══════════════════════════════════════════════════════════════════
    // ЭКРАН 1: БОЛЬШИЕ ЧАСЫ
    // ═══════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        opacity: screenState === 0 ? 1 : 0
        scale: screenState === 0 ? 1 : 0.9
        visible: opacity > 0
        z: 5
        
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 400
            Layout.preferredHeight: 160

            Text {
                id: bigClock
                anchors.centerIn: parent
                text: Qt.formatDateTime(new Date(), "HH:mm")
                font.pixelSize: 144
                font.weight: Font.Thin
                color: Colors.backgroundText
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.6)
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 4
                    shadowBlur: 16
                }
                
                Timer {
                    interval: 1000; running: true; repeat: true
                    onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm")
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(new Date(), "dddd, d MMMM")
            font.pixelSize: 24
            color: Colors.backgroundText
            opacity: 0.8
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Нажмите Enter или кликните"
            font.pixelSize: 14
            color: Colors.outline
            opacity: 0.7
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            focus: true
            
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    screenState = 1
                    Qt.callLater(() => passwordInput.forceActiveFocus())
                }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    screenState = 1
                    Qt.callLater(() => passwordInput.forceActiveFocus())
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // ЭКРАН 2: ВВОД ПАРОЛЯ (Цвета из Colors.qml)
    // ══════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24
        width: parent.width * 0.8
        Layout.maximumWidth: 500
        
        opacity: screenState === 1 ? 1 : 0
        scale: screenState === 1 ? 1 : 0.9
        visible: opacity > 0
        z: 5
        
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Неверный пароль"
            font.pixelSize: 14
            color: Colors.error // Красный/розовый из темы
            visible: root.context.showFailure
            opacity: visible ? 1 : 0
        }

        // Поле ввода
        Rectangle {
            id: passwordField
            Layout.preferredWidth: 480
            Layout.preferredHeight: 64
            radius: 32
            
            // Тёмно-зелёный фон из темы (primaryContainer)
            color: Colors.primaryContainer 
            opacity: 0.8 // Лёгкая прозрачность, чтобы слегка просвечивали обои
            
            // Рамка меняется с серой (outline) на зелёную (primary) при фокусе
            border.color: passwordInput.activeFocus ? Colors.primary : Colors.outline
            border.width: passwordInput.activeFocus ? 2 : 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 4
                shadowBlur: passwordInput.activeFocus ? 20 : 12
            }

            MouseArea {
                anchors.fill: parent
                onClicked: passwordInput.forceActiveFocus()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 8
                spacing: 8

                Flickable {
                    id: flickable
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    contentWidth: passwordRow.width
                    contentHeight: height
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    Row {
                        id: passwordRow
                        height: parent.height
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Пароль"
                            font.pixelSize: 16
                            color: Colors.outline // Серый для неактивного текста
                            opacity: 0.7
                            visible: root.context.currentText.length === 0
                        }

                        Repeater {
                            model: root.passwordShapes
                            delegate: Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData
                                font.pixelSize: 24
                                // Светло-зелёный текст, идеально виден на тёмно-зелёном фоне
                                color: Colors.primaryContainerText 
                                opacity: 1.0
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2; height: 24
                            color: Colors.primary // Ярко-зелёный курсор
                            visible: passwordInput.activeFocus
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: 500 }
                                NumberAnimation { to: 1; duration: 500 }
                            }
                        }
                    }
                }

                // Кнопка входа
                Rectangle {
                    id: submitBtn
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 24
                    color: Colors.primary // Ярко-зелёная кнопка
                    opacity: 1.0
                    scale: submitBtnHover.containsMouse ? 1.1 : (submitBtnHover.pressed ? 0.95 : 1.0)
                    
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#000000"
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 2
                        shadowBlur: 8
                    }

                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }

                    Text {
                        anchors.centerIn: parent
                        text: "→"
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        color: Colors.primaryText // Тёмно-зелёная стрелка для контраста
                    }

                    MouseArea {
                        id: submitBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.context.tryUnlock()
                    }
                }
            }

            TextInput {
                id: passwordInput
                width: 0; height: 0; opacity: 0
                focus: true
                echoMode: TextInput.Password
                enabled: !root.context.unlockInProgress
                
                onTextChanged: {
                    root.context.currentText = text
                }
                
                onAccepted: root.context.tryUnlock()
                
                Keys.onEscapePressed: {
                    screenState = 0
                    root.context.currentText = ""
                    passwordInput.text = ""
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.context.unlockInProgress ? "Проверка..." : "Enter для входа · Esc назад"
            font.pixelSize: 13
            color: Colors.backgroundText
            opacity: 0.7
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.5)
        }
    }

    Keys.onEscapePressed: {
        if (screenState === 1) {
            screenState = 0
            root.context.currentText = ""
            passwordInput.text = ""
        }
    }
    
    onScreenStateChanged: {
        if (screenState === 1) {
            root.context.currentText = ""
            passwordInput.text = ""
        }
    }
}
