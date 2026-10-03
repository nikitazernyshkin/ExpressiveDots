pragma Singleton

import QtQuick

QtObject {
    id: root

    signal reloaded()

    function reload() {
        reloaded()
    }

    // ============================================================
    // BACKGROUND
    // ============================================================

    property color background: "#0e1514"
    property color backgroundText: "#dde4e3"


    // ============================================================
    // SURFACES
    // ============================================================

    property color surface: "#0e1514"
    property color surfaceText: "#dde4e3"

    property color surfaceVariant: "#3f4948"
    property color surfaceVariantText: "#bec8c8"


    // ============================================================
    // SURFACE CONTAINERS
    //
    // Используются для создания глубины без классических теней.
    // Это особенно важно для Material 3 / Expressive.
    // ============================================================

    property color surfaceContainerLowest:
        "#090f0f"

    property color surfaceContainerLow:
        "#161d1d"

    property color surfaceContainer:
        "#1a2121"

    property color surfaceContainerHigh:
        "#252b2b"

    property color surfaceContainerHighest:
        "#2f3636"


    // ============================================================
    // OUTLINE
    // ============================================================

    property color outline:
        "#899392"

    property color outlineVariant:
        "#3f4948"


    // ============================================================
    // PRIMARY
    //
    // Основной акцент:
    // активный workspace
    // часы
    // активные кнопки
    // ============================================================

    property color primary:
        "#80d4d5"

    property color primaryText:
        "#003737"

    property color primaryContainer:
        "#004f50"

    property color primaryContainerText:
        "#9cf1f2"


    // ============================================================
    // SECONDARY
    //
    // Вторичные интерактивные элементы.
    // ============================================================

    property color secondary:
        "#b0cccc"

    property color secondaryText:
        "#1b3435"

    property color secondaryContainer:
        "#324b4b"

    property color secondaryContainerText:
        "#cce8e8"


    // ============================================================
    // TERTIARY
    //
    // Дополнительные акценты:
    // Bluetooth
    // специальные состояния
    // ============================================================

    property color tertiary:
        "#b3c8e9"

    property color tertiaryText:
        "#1d314b"

    property color tertiaryContainer:
        "#344863"

    property color tertiaryContainerText:
        "#d4e3ff"


    // ============================================================
    // ERROR
    // ============================================================

    property color error:
        "#ffb4ab"

    property color errorText:
        "#690005"

    property color errorContainer:
        "#93000a"

    property color errorContainerText:
        "#ffdad6"


    // ============================================================
    // LEGACY / COMPATIBILITY
    //
    // Оставляем для существующих компонентов.
    // ============================================================

    property QtObject backgroundObj: QtObject {
        property real r: 14
        property real g: 21
        property real b: 20
    }
}
