import QtQuick
import Quickshell
import Quickshell.Io
import "../core" as ColorsImport

Item {
    id: root

    width: 230
    height: 230

    // ============================================================
    // PALETTE
    // ============================================================

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

    readonly property color textColor:
        "#E0E3E1"

    readonly property color subtextColor:
        "#8E938F"


    // ============================================================
    // LOCATION
    // ============================================================

    property real latitude: 0
    property real longitude: 0
    property bool locationReady: false

    // Последние строки GeoClue накапливаем здесь.
    property string locationBuffer: ""


    // ============================================================
    // WEATHER
    // ============================================================

    property real temperature: 0
    property int weatherCode: -1
    property bool weatherReady: false


    // ============================================================
    // GEOCLUE
    //
    // where-am-i не завершается сам.
    // Поэтому здесь SplitParser, а не StdioCollector.
    // ============================================================

    Process {
        id: locationProcess

        command: [
            "/usr/lib/geoclue-2.0/demos/where-am-i"
        ]

        running: true

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                const text = line.trim()

                if (!text)
                    return

                root.locationBuffer += text + "\n"

                const latMatch =
                    root.locationBuffer.match(
                        /Latitude:\s*([-+]?[0-9]+[,.][0-9]+)/
                    )

                const lonMatch =
                    root.locationBuffer.match(
                        /Longitude:\s*([-+]?[0-9]+[,.][0-9]+)/
                    )

                if (!latMatch || !lonMatch)
                    return

                const lat =
                    Number(
                        latMatch[1].replace(",", ".")
                    )

                const lon =
                    Number(
                        lonMatch[1].replace(",", ".")
                    )

                if (
                    !isFinite(lat) ||
                    !isFinite(lon)
                )
                    return

                // Не обновляем погоду на те же координаты
                // каждый раз, когда GeoClue присылает новую строку.
                const changed =
                    Math.abs(root.latitude - lat) > 0.0001 ||
                    Math.abs(root.longitude - lon) > 0.0001

                root.latitude = lat
                root.longitude = lon
                root.locationReady = true

                root.locationBuffer = ""

                if (changed || !root.weatherReady)
                    root.updateWeather()
            }
        }
    }


    // ============================================================
    // OPEN-METEO
    // ============================================================

    Process {
        id: weatherProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const output =
                    this.text.trim()

                if (!output)
                    return

                try {
                    const data =
                        JSON.parse(output)

                    if (!data.current)
                        return

                    const temp =
                        Number(
                            data.current.temperature_2m
                        )

                    const code =
                        Number(
                            data.current.weather_code
                        )

                    if (!isFinite(temp))
                        return

                    root.temperature = temp
                    root.weatherCode = code
                    root.weatherReady = true

                    weatherIcon.requestPaint()

                } catch (error) {
                    console.warn(
                        "Weather: invalid JSON:",
                        error
                    )
                }
            }
        }
    }


    function updateWeather() {
        if (!root.locationReady)
            return

        const url =
            "https://api.open-meteo.com/v1/forecast" +
            "?latitude=" +
            root.latitude.toFixed(5) +
            "&longitude=" +
            root.longitude.toFixed(5) +
            "&current=temperature_2m,weather_code" +
            "&temperature_unit=celsius"

        weatherProcess.exec([
            "curl",
            "--silent",
            "--show-error",
            "--fail",
            "--connect-timeout",
            "5",
            "--max-time",
            "10",
            url
        ])
    }


    // ============================================================
    // WEATHER REFRESH
    // ============================================================

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true

        onTriggered: root.updateWeather()
    }


    // ============================================================
    // ORGANIC BACKGROUND
    //
    // Специально сделан под референс:
    // широкий, наклонённый, асимметричный blob.
    // ============================================================

    Canvas {
        id: background

        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")

            ctx.reset()
            ctx.beginPath()

            ctx.moveTo(67, 29)

            ctx.bezierCurveTo(
                91, 10,
                124, 6,
                153, 14
            )

            ctx.bezierCurveTo(
                184, 22,
                207, 43,
                216, 72
            )

            ctx.bezierCurveTo(
                226, 103,
                216, 132,
                198, 158
            )

            ctx.bezierCurveTo(
                180, 185,
                157, 209,
                128, 219
            )

            ctx.bezierCurveTo(
                99, 229,
                69, 220,
                47, 202
            )

            ctx.bezierCurveTo(
                24, 183,
                16, 154,
                20, 127
            )

            ctx.bezierCurveTo(
                23, 100,
                38, 76,
                53, 59
            )

            ctx.bezierCurveTo(
                58, 52,
                62, 40,
                67, 29
            )

            ctx.closePath()

            ctx.fillStyle = root.bgColor
            ctx.fill()
        }

        Connections {
            target: root

            function onBgColorChanged() {
                background.requestPaint()
            }
        }
    }


    // ============================================================
    // TEMPERATURE
    // ============================================================

    Text {
        id: temperatureText

        x: 63
        y: 60

        text: root.weatherReady
            ? Math.round(root.temperature)
            : "—"

        color: root.textColor

        font.family: "Fira Sans"
        font.pixelSize: 76
        font.weight: Font.Normal

        renderType: Text.NativeRendering
    }


    // ============================================================
    // DEGREE
    // ============================================================

    Text {
        id: degreeText

        x:
            temperatureText.x +
            temperatureText.implicitWidth +
            4

        y: 62

        text: "°"

        color: root.textColor

        font.family: "Fira Sans"
        font.pixelSize: 39
        font.weight: Font.Normal

        renderType: Text.NativeRendering
    }


    // ============================================================
    // WEATHER ICON
    // ============================================================

    Canvas {
        id: weatherIcon

        x: 57
        y: 132

        width: 105
        height: 88

        onPaint: {
            const ctx = getContext("2d")

            ctx.reset()


            // ====================================================
            // BLUE CIRCLE
            // ====================================================

            ctx.fillStyle =
                root.primaryColor

            ctx.beginPath()

            ctx.arc(
                50,
                42,
                37,
                0,
                Math.PI * 2
            )

            ctx.fill()


            // ====================================================
            // CLOUD
            // ====================================================

            ctx.fillStyle =
                root.textColor

            ctx.beginPath()

            // left small bump
            ctx.arc(
                29,
                54,
                19,
                0,
                Math.PI * 2
            )

            // main bump
            ctx.arc(
                49,
                43,
                27,
                0,
                Math.PI * 2
            )

            // right bump
            ctx.arc(
                69,
                55,
                19,
                0,
                Math.PI * 2
            )

            // flat lower part
            ctx.rect(
                26,
                53,
                63,
                22
            )

            ctx.fill()
        }

        Connections {
            target: root

            function onPrimaryColorChanged() {
                weatherIcon.requestPaint()
            }

            function onTextColorChanged() {
                weatherIcon.requestPaint()
            }
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
