import "../core"
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../widgets"
import Quickshell
import Quickshell.Wayland

Rectangle {
    id: root
    color: Colors.background

    property var context
    property var controlCenter
    property int screenState: 0
    focus: true

    readonly property color textColor: Colors.backgroundText
    readonly property color mutedColor: Colors.outline
    readonly property color glass: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.88)
    readonly property color glassHigh: Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.94)

    Image {
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.config/hypr/background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        z: 0
    }

    // A soft, even veil keeps the wallpaper visible without compromising readability.
    Rectangle {
        anchors.fill: parent
        color: "#071011"
        opacity: 0.48
        z: 1
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#30000000" }
            GradientStop { position: 0.48; color: "#08000000" }
            GradientStop { position: 1.0; color: "#50000000" }
        }
        z: 1
    }

    LockTopBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        z: 10
    }

    // Reuse the exact desktop clock widget on the lock screen.
    // Its own date and analog hands stay in sync through widgets/Clock.qml.
    Column {
        id: clockScreen
        anchors.centerIn: parent
        spacing: 18
        opacity: root.screenState === 0 ? 1 : 0
        scale: root.screenState === 0 ? 1 : 0.94
        visible: opacity > 0.01
        z: 5
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: hintRow.implicitWidth + 32
            height: 44
            radius: 22
            color: Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.60)
            border.width: 1
            border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.16)
            Row {
                id: hintRow
                anchors.centerIn: parent
                spacing: 9
                Text { text: "\ue897"; font.family: "Material Symbols Rounded"; font.pixelSize: 17; color: Colors.primary; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Нажмите или Enter, чтобы разблокировать"; font.pixelSize: 12; color: root.textColor; opacity: 0.88; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: parent.color = Qt.rgba(Colors.surfaceContainerHigh.r, Colors.surfaceContainerHigh.g, Colors.surfaceContainerHigh.b, 0.82)
                onExited: parent.color = Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.60)
                onClicked: root.openPassword()
            }
        }
    }

    // Password view: centered Material 3 Expressive card with a clear focus state.
    Column {
        id: passwordScreen
        anchors.centerIn: parent
        width: Math.min(parent.width - 36, 430)
        spacing: 18
        opacity: root.screenState === 1 ? 1 : 0
        scale: root.screenState === 1 ? 1 : 0.94
        visible: opacity > 0.01
        z: 6
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        Rectangle {
            id: avatarBadge
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76
            height: 76
            radius: 28
            color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.17)
            border.width: 1
            border.color: Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.34)
            Text {
                anchors.centerIn: parent
                text: "\ue7fd"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 38
                color: Colors.primary
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Добро пожаловать"
            color: root.textColor
            font.pixelSize: 28
            font.weight: Font.Medium
            font.letterSpacing: -0.5
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.context.unlockInProgress ? "Проверяем пароль…" : "Введите пароль, чтобы продолжить"
            color: root.mutedColor
            font.pixelSize: 13
        }

        Rectangle {
            id: passwordCard
            width: parent.width
            height: 76
            radius: 28
            color: passwordInput.activeFocus ? Qt.rgba(Colors.primaryContainer.r, Colors.primaryContainer.g, Colors.primaryContainer.b, 0.86) : root.glassHigh
            border.width: passwordInput.activeFocus ? 2 : 1
            border.color: root.context.showFailure ? Colors.error : passwordInput.activeFocus ? Colors.primary : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.30)
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }
            Behavior on border.width { NumberAnimation { duration: 120 } }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 10
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\ue897"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 23
                    color: passwordInput.activeFocus ? Colors.primary : Colors.outline
                }

                Item {
                    id: passwordTextArea
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 22 - 12 - 54 - 10
                    height: 42
                    clip: true
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.context.currentText.length === 0
                        text: "Пароль"
                        font.pixelSize: 15
                        color: Colors.outline
                        opacity: 0.9
                    }
                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7
                        Repeater {
                            model: root.context.currentText.length
                            delegate: Rectangle {
                                required property int index
                                width: 9; height: 9; radius: 4.5
                                color: Colors.primaryContainerText
                                opacity: 0.98
                                scale: 1
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                            }
                        }
                        Rectangle {
                            width: 2; height: 22; radius: 1
                            color: Colors.primary
                            visible: passwordInput.activeFocus && !root.context.unlockInProgress
                            SequentialAnimation on opacity {
                                running: passwordInput.activeFocus
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.15; duration: 480 }
                                NumberAnimation { to: 1; duration: 480 }
                            }
                        }
                    }
                }

                Rectangle {
                    id: submitBtn
                    anchors.verticalCenter: parent.verticalCenter
                    width: 54; height: 54; radius: 20
                    color: root.context.unlockInProgress ? Colors.surfaceVariant : Colors.primary
                    opacity: root.context.currentText.length > 0 && !root.context.unlockInProgress ? 1 : 0.68
                    scale: submitHover.pressed ? 0.94 : submitHover.containsMouse ? 1.04 : 1
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Text {
                        anchors.centerIn: parent
                        text: root.context.unlockInProgress ? "\ue863" : "\ue5c8"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 26
                        color: root.context.unlockInProgress ? Colors.surfaceVariantText : Colors.primaryText
                    }
                    MouseArea {
                        id: submitHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.context.currentText.length > 0 && !root.context.unlockInProgress
                        onClicked: root.context.tryUnlock()
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: passwordInput.forceActiveFocus()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.context.showFailure ? "Неверный пароль. Попробуйте ещё раз." : ""
            visible: root.context.showFailure
            color: Colors.error
            font.pixelSize: 13
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.context.unlockInProgress ? "Подождите" : "Enter — подтвердить     ·     Esc — назад"
            color: root.mutedColor
            font.pixelSize: 12
        }

        TextInput {
            id: passwordInput
            width: 1
            height: 1
            opacity: 0.01
            color: "transparent"
            selectionColor: Colors.primary
            focus: root.screenState === 1
            echoMode: TextInput.Password
            enabled: root.screenState === 1 && !root.context.unlockInProgress
            onTextChanged: {
                if (root.context.currentText !== text)
                    root.context.currentText = text
            }
            onAccepted: root.context.tryUnlock()
            Keys.onEscapePressed: root.closePassword()
        }

        // PAM clears the context text after a failed attempt. Keep the hidden
        // keyboard input in sync too, otherwise the next attempt appends to the
        // old password even though the dots have disappeared.
        Connections {
            target: root.context
            function onCurrentTextChanged() {
                if (passwordInput.text !== root.context.currentText)
                    passwordInput.text = root.context.currentText
            }
            function onUnlockInProgressChanged() {
                if (!root.context.unlockInProgress && root.screenState === 1)
                    Qt.callLater(() => passwordInput.forceActiveFocus())
            }
        }
    }

    function openPassword() {
        screenState = 1
        Qt.callLater(() => passwordInput.forceActiveFocus())
    }
    function closePassword() {
        screenState = 0
        root.context.currentText = ""
        passwordInput.text = ""
        Qt.callLater(() => root.forceActiveFocus())
    }

    Keys.onEscapePressed: {
        if (screenState === 1)
            closePassword()
    }
    Component.onCompleted: Qt.callLater(() => root.forceActiveFocus())
    onScreenStateChanged: {
        if (screenState === 1) {
            root.context.currentText = ""
            passwordInput.text = ""
            Qt.callLater(() => passwordInput.forceActiveFocus())
        } else {
            Qt.callLater(() => root.forceActiveFocus())
        }
    }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && screenState === 1) {
            closePassword()
            event.accepted = true
        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && screenState === 0) {
            openPassword()
            event.accepted = true
        }
    }
}
