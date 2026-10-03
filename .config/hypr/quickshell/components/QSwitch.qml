import QtQuick
import "../core"

Item {
    id: root
    property bool checked: false
    signal toggled(bool on)
    implicitWidth: 52
    implicitHeight: 32

    // Трек (фон переключателя)
    Rectangle {
        anchors.centerIn: parent
        width: 52; height: 32; radius: 16
        color: root.checked ? Colors.primary : "transparent"
        border.color: root.checked ? Colors.primary : Colors.outline
        border.width: 2
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    // Ручка (knob)
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? 24 : 6
        width: root.checked ? 24 : 16
        height: root.checked ? 24 : 16
        radius: width / 2   // ← исправил: теперь всегда круг (было жёстко 16)
        color: root.checked ? Colors.primaryText : Colors.outline
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 150 } }
        Behavior on height { NumberAnimation { duration: 150 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
