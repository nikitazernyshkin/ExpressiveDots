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

    property color background: "{{colors.background.default.hex}}"
    property color backgroundText: "{{colors.on_background.default.hex}}"


    // ============================================================
    // SURFACES
    // ============================================================

    property color surface: "{{colors.surface.default.hex}}"
    property color surfaceText: "{{colors.on_surface.default.hex}}"

    property color surfaceVariant: "{{colors.surface_variant.default.hex}}"
    property color surfaceVariantText: "{{colors.on_surface_variant.default.hex}}"


    // ============================================================
    // SURFACE CONTAINERS
    //
    // Используются для создания глубины без классических теней.
    // Это особенно важно для Material 3 / Expressive.
    // ============================================================

    property color surfaceContainerLowest:
        "{{colors.surface_container_lowest.default.hex}}"

    property color surfaceContainerLow:
        "{{colors.surface_container_low.default.hex}}"

    property color surfaceContainer:
        "{{colors.surface_container.default.hex}}"

    property color surfaceContainerHigh:
        "{{colors.surface_container_high.default.hex}}"

    property color surfaceContainerHighest:
        "{{colors.surface_container_highest.default.hex}}"


    // ============================================================
    // OUTLINE
    // ============================================================

    property color outline:
        "{{colors.outline.default.hex}}"

    property color outlineVariant:
        "{{colors.outline_variant.default.hex}}"


    // ============================================================
    // PRIMARY
    //
    // Основной акцент:
    // активный workspace
    // часы
    // активные кнопки
    // ============================================================

    property color primary:
        "{{colors.primary.default.hex}}"

    property color primaryText:
        "{{colors.on_primary.default.hex}}"

    property color primaryContainer:
        "{{colors.primary_container.default.hex}}"

    property color primaryContainerText:
        "{{colors.on_primary_container.default.hex}}"


    // ============================================================
    // SECONDARY
    //
    // Вторичные интерактивные элементы.
    // ============================================================

    property color secondary:
        "{{colors.secondary.default.hex}}"

    property color secondaryText:
        "{{colors.on_secondary.default.hex}}"

    property color secondaryContainer:
        "{{colors.secondary_container.default.hex}}"

    property color secondaryContainerText:
        "{{colors.on_secondary_container.default.hex}}"


    // ============================================================
    // TERTIARY
    //
    // Дополнительные акценты:
    // Bluetooth
    // специальные состояния
    // ============================================================

    property color tertiary:
        "{{colors.tertiary.default.hex}}"

    property color tertiaryText:
        "{{colors.on_tertiary.default.hex}}"

    property color tertiaryContainer:
        "{{colors.tertiary_container.default.hex}}"

    property color tertiaryContainerText:
        "{{colors.on_tertiary_container.default.hex}}"


    // ============================================================
    // ERROR
    // ============================================================

    property color error:
        "{{colors.error.default.hex}}"

    property color errorText:
        "{{colors.on_error.default.hex}}"

    property color errorContainer:
        "{{colors.error_container.default.hex}}"

    property color errorContainerText:
        "{{colors.on_error_container.default.hex}}"


    // ============================================================
    // LEGACY / COMPATIBILITY
    //
    // Оставляем для существующих компонентов.
    // ============================================================

    property QtObject backgroundObj: QtObject {
        property real r: {{colors.background.default.red}}
        property real g: {{colors.background.default.green}}
        property real b: {{colors.background.default.blue}}
    }
}
