import QtQuick
import "../core" as ColorsImport

Item {
    id: root

    width: 190
    height: 190

    readonly property var colors: ColorsImport.Colors

    readonly property color bgColor:
        (colors && colors.surface)
            ? colors.surface
            : "#0F2023"

    readonly property color primaryColor:
        (colors && colors.primary)
            ? colors.primary
            : "#82D5D1"

    readonly property color onPrimaryColor:
        (colors && colors.onPrimary)
            ? colors.onPrimary
            : "#003735"

    readonly property color textColor: "#E0E3E1"
    readonly property color subtextColor: "#8E938F"

    property date currentTime: new Date()

    property real hourAngle: 0
    property real minuteAngle: 0
    property real secondAngle: 0

    function updateTime() {
        const now = new Date()

        currentTime = now

        const h = now.getHours() % 12
        const m = now.getMinutes()
        const s = now.getSeconds()
        const ms = now.getMilliseconds()

        hourAngle =
            h * 30 +
            m * 0.5 +
            s / 120

        minuteAngle =
            m * 6 +
            s * 0.1 +
            ms * 0.0001

        secondAngle =
            s * 6 +
            ms * 0.006
    }

    Timer {
        interval: 40
        running: true
        repeat: true

        onTriggered: root.updateTime()
    }

    Component.onCompleted: updateTime()


    // ============================================================
    // ORGANIC MATERIAL 3 EXPRESSIVE SHAPE
    // ============================================================

    Canvas {
        id: shape

        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")

            ctx.reset()
            ctx.beginPath()

            const cx = width / 2
            const cy = height / 2

            const points = 160

            /*
             * Большой радиус = выпуклые части.
             * Маленький радиус = глубокие мягкие впадины.
             *
             * 10 волн дают именно ту organic/scalloped форму,
             * а не обычный круг.
             */
            const outerRadius = 100
            const innerRadius = 90
            const lobes = 10

            function point(i) {
                const a = (Math.PI * 2 * i) / points

                // Плавная 10-лепестковая волна
                const wave =
                    (Math.sin(a * lobes - Math.PI / 2) + 1) / 2

                const r =
                    innerRadius +
                    (outerRadius - innerRadius) * wave

                return {
                    x: cx + Math.cos(a) * r,
                    y: cy + Math.sin(a) * r
                }
            }

            function midpoint(a, b) {
                return {
                    x: (a.x + b.x) / 2,
                    y: (a.y + b.y) / 2
                }
            }

            let p0 = point(0)
            let p1 = point(1)

            let start = midpoint(p0, p1)

            ctx.moveTo(start.x, start.y)

            for (let i = 1; i < points; ++i) {
                const current = point(i)
                const next = point(i + 1)

                const mid = midpoint(current, next)

                ctx.quadraticCurveTo(
                    current.x,
                    current.y,
                    mid.x,
                    mid.y
                )
            }

            // Замыкаем последнюю часть
            ctx.quadraticCurveTo(
                p0.x,
                p0.y,
                start.x,
                start.y
            )

            ctx.closePath()

            ctx.fillStyle = root.bgColor
            ctx.fill()
        }

        Connections {
            target: root

            function onBgColorChanged() {
                shape.requestPaint()
            }
        }
    }


    // ============================================================
    // DATE
    // ============================================================

    Text {
        id: dateText

        anchors.horizontalCenter: parent.horizontalCenter
        y: 35

        text: Qt.locale().toString(
            root.currentTime,
            "ddd d"
        )

        color: root.textColor

        font.pixelSize: 15
        font.weight: Font.Medium

        opacity: 0.9
    }


    // ============================================================
    // CLOCK HANDS
    // ============================================================

    Item {
        id: hands

        anchors.fill: parent


        // HOUR
        Rectangle {
            id: hourHand

            width: 13
            height: 53

            x: hands.width / 2 - width / 2
            y: hands.height / 2 - height

            radius: width / 2

            color: root.textColor

            transformOrigin: Item.Bottom

            rotation: root.hourAngle
        }


        // MINUTE
        Rectangle {
            id: minuteHand

            width: 10
            height: 72

            x: hands.width / 2 - width / 2
            y: hands.height / 2 - height

            radius: width / 2

            color: root.primaryColor

            transformOrigin: Item.Bottom

            rotation: root.minuteAngle
        }


        // SECOND
        Rectangle {
            id: secondHand

            width: 3
            height: 78

            x: hands.width / 2 - width / 2
            y: hands.height / 2 - height

            radius: width / 2

            color: root.primaryColor

            transformOrigin: Item.Bottom

            rotation: root.secondAngle
        }


        // CENTER
        Rectangle {
            width: 14
            height: 14

            anchors.centerIn: parent

            radius: width / 2

            color: root.onPrimaryColor
        }
    }


    // ============================================================
    // DRAG
    // ============================================================

    DragHandler {
        target: root
        acceptedButtons: Qt.LeftButton
    }
}
