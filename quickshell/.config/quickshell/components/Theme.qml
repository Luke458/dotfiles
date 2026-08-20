import QtQuick
import Quickshell

pragma Singleton

QtObject {
    readonly property real densityScale: {
        const requested = Number(Quickshell.env("QS_UI_SCALE") || "1");
        return isFinite(requested) ? Math.max(0.75, Math.min(2.0, requested)) : 1.0;
    }
    // Font families
    readonly property string fontUi: "Noto Sans"
    readonly property string fontMono: "MesloLGS Nerd Font Mono"
    readonly property string fontIcon: "Symbols Nerd Font"

    // Typography scale
    readonly property int fontSizeCaption: 9
    readonly property int fontSizeSmall: 10
    readonly property int fontSizeBody: 11
    readonly property int fontSizeLabel: 12
    readonly property int fontSizeBar: 13
    readonly property int fontSizeTitle: 14
    readonly property int fontSizeHeading: 15
    readonly property int fontSizeHeadingLarge: 16
    readonly property int fontSizeBanner: 17
    readonly property int fontSizeDisplaySmall: 18
    readonly property int fontSizeDisplay: 19
    readonly property int fontSizeDisplayLarge: 20
    readonly property int fontSizeValueSmall: 23
    readonly property int fontSizeValueMedium: 26
    readonly property int fontSizeValueLarge: 30
    readonly property int fontSizeHero: 40
    readonly property int fontSizeClock: 84
    readonly property int menuPointSize: 9
    readonly property int menuIconPointSize: 10

    // DWM-inspired base palette (suckless dwm config.def.h)
    readonly property color transparent: "transparent"
    readonly property color bg: "#99222222"
    readonly property color bgSolid: "#222222"
    readonly property color lockScreenBg: "#1a1a1a"
    readonly property color border: "#444444" // col_gray2
    readonly property color separator: "#555555"
    readonly property color fg: "#bbbbbb" // col_gray3
    readonly property color selFg: "#eeeeee" // col_gray4
    readonly property color selBg: "#005577" // col_cyan

    // Semantic status and data colors
    readonly property color red: "#ff0000"
    readonly property color green: "#00ff00"
    readonly property color yellow: "#ffff00"
    readonly property color critical: "#cc241d"
    readonly property color positive: "#4ade80"
    readonly property color negative: "#f87171"
    readonly property color weatherClear: "#d79921"
    readonly property color weatherFog: "#928374"
    readonly property color weatherRain: "#458588"
    readonly property color weatherSnow: "#83a598"

    // Reusable interaction and surface states
    readonly property color hover: Qt.rgba(1, 1, 1, 0.10)
    readonly property color hoverSoft: Qt.rgba(1, 1, 1, 0.08)
    readonly property color hoverSubtle: Qt.rgba(1, 1, 1, 0.05)
    readonly property color surfaceSubtle: Qt.rgba(1, 1, 1, 0.04)
    readonly property color disabledSurface: Qt.rgba(1, 1, 1, 0.06)
    readonly property color fieldBg: Qt.rgba(0, 0, 0, 0.25)
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.12)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.28)
    readonly property color menuHover: Qt.rgba(1, 1, 1, 0.13)
    readonly property color menuDisabledFg: Qt.rgba(1, 1, 1, 0.53)
    readonly property color scrollIndicator: Qt.rgba(1, 1, 1, 0.40)
    readonly property color placeholderFg: withAlpha(fg, 0.45)
    readonly property color selectionSubtle: withAlpha(selBg, 0.20)
    readonly property color selectionSoft: withAlpha(selBg, 0.24)
    readonly property color selectionMedium: withAlpha(selBg, 0.32)
    readonly property color selection: withAlpha(selBg, 0.40)
    readonly property color selectionStrong: withAlpha(selBg, 0.55)
    readonly property color positiveSurface: withAlpha(positive, 0.15)
    readonly property color negativeSurface: withAlpha(negative, 0.15)

    // Shared geometry tokens. One-off component geometry stays local.
    readonly property int spacingTiny: 2
    readonly property int spacingMicro: 3
    readonly property int spacingXSmall: 4
    readonly property int spacingSmall: 5
    readonly property int spacingCompact: 6
    readonly property int spacingIntermediate: 7
    readonly property int spacingComfortable: 8
    readonly property int spacingMedium: 10
    readonly property int spacingSection: 12
    readonly property int spacingContent: 14
    readonly property int spacingLarge: 15
    readonly property int spacingPanel: 16
    readonly property int spacingXLarge: 20
    readonly property int spacingPage: 24
    readonly property int spacingWide: 25
    readonly property int spacingDisplay: 30
    readonly property int spacingHero: 40
    readonly property int popupPadding: 5
    readonly property int controlPadding: 10
    readonly property int panelPadding: 16
    readonly property int dialogPadding: 18
    readonly property int sectionPadding: 20
    readonly property int radiusNone: 0
    readonly property int radiusSmall: 2
    readonly property int radiusCompact: 3
    readonly property int radiusMedium: 4
    readonly property int radiusComfortable: 5
    readonly property int radiusPanel: 6
    readonly property int radiusHandle: 7
    readonly property int radiusLarge: 8
    readonly property int radiusAction: 12
    readonly property int radiusRound: 999

    // Shared opacity roles
    readonly property real opacityOpaque: 1.0
    readonly property real opacityBarelyVisible: 0.10
    readonly property real opacityVerySubtle: 0.15
    readonly property real opacityFaint: 0.20
    readonly property real opacityQuarter: 0.25
    readonly property real opacitySoft: 0.30
    readonly property real opacitySubtle: 0.35
    readonly property real opacityDisabled: 0.45
    readonly property real opacityMuted: 0.50
    readonly property real opacityMedium: 0.55
    readonly property real opacitySecondaryLow: 0.60
    readonly property real opacitySecondary: 0.65
    readonly property real opacitySecondaryHigh: 0.70
    readonly property real opacityStrong: 0.75
    readonly property real opacityProminent: 0.80
    readonly property real chartFillOpacity: 0.28

    function withAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha);
    }

    function space(value) {
        return Math.max(1, Math.round(Number(value) * densityScale));
    }

    function spaceReal(value) {
        return Number(value) * densityScale;
    }

    function controlFill(focused, hovered, selected) {
        if (selected || focused)
            return selBg;
        return hovered ? hover : transparent;
    }

    function controlText(focused, hovered, selected, enabled) {
        if (enabled === false)
            return menuDisabledFg;
        return selected || focused || hovered ? selFg : fg;
    }

    function controlBorder(focused, hovered, selected) {
        return selected || focused ? selBg : (hovered ? separator : border);
    }

    function lighter(color, factor) {
        return Qt.lighter(color, factor);
    }

    function cssRgb(color) {
        return "rgb(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + ")";
    }

    function cssRgba(color, alpha) {
        return "rgba(" + Math.round(color.r * 255) + "," + Math.round(color.g * 255) + "," + Math.round(color.b * 255) + "," + alpha + ")";
    }
}
