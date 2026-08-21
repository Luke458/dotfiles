import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

QtObject {
    id: theme

    readonly property real densityScale: {
        const requested = Number(Quickshell.env("QS_UI_SCALE") || "1");
        return isFinite(requested) ? Math.max(0.75, Math.min(2.0, requested)) : 1.0;
    }

    // --- Theme override system -------------------------------------------------
    // Tokens below are defaults. A JSON file (env QS_THEME_FILE, otherwise
    // theme.json next to shell.qml) may override any non-derived token by name;
    // string values that look like colors are parsed as colors, other strings
    // assign verbatim (fonts), numbers assign directly. Derived tokens
    // (selection*, placeholderFg, *Surface) stay bound to their base token so a
    // single selBg/fg change recolors the whole set. The file is watched and
    // hot-applied.
    property string themeFileUsed: ""
    property int overrideCount: 0

    function _looksLikeColor(value) {
        const v = String(value).trim().toLowerCase();
        return v.startsWith("#") || v.startsWith("rgb") || v.startsWith("hsl");
    }

    function applyThemeOverrides(text) {
        let parsed;
        try {
            parsed = JSON.parse(String(text || "{}"));
        } catch (error) {
            console.warn("Theme: ignoring invalid theme file: " + error);
            return;
        }
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
            console.warn("Theme: theme file must be a JSON object");
            return;
        }

        let applied = 0;
        const unknown = [];
        for (const key in parsed) {
            if (!parsed.hasOwnProperty(key))
                continue;
            const value = parsed[key];
            if (value === null || typeof value === "object")
                continue;
            if (!(key in theme) || typeof theme[key] === "function") {
                unknown.push(key);
                continue;
            }
            try {
                if (typeof value === "number") {
                    theme[key] = value;
                    applied++;
                } else if (_looksLikeColor(value)) {
                    theme[key] = Qt.color(String(value));
                    applied++;
                } else {
                    theme[key] = String(value);
                    applied++;
                }
            } catch (error) {
                console.warn("Theme: could not apply '" + key + "': " + error);
            }
        }
        if (unknown.length > 0)
            console.warn("Theme: ignored unknown tokens: " + unknown.join(", "));
        overrideCount = applied;
    }

    // Font families
    property string fontUi: "Noto Sans"
    property string fontMono: "MesloLGS Nerd Font Mono"
    property string fontIcon: "Symbols Nerd Font"

    // Typography scale
    property int fontSizeCaption: 9
    property int fontSizeSmall: 10
    property int fontSizeBody: 11
    property int fontSizeLabel: 12
    property int fontSizeBar: 13
    property int fontSizeTitle: 14
    property int fontSizeHeading: 15
    property int fontSizeHeadingLarge: 16
    property int fontSizeBanner: 17
    property int fontSizeDisplaySmall: 18
    property int fontSizeDisplay: 19
    property int fontSizeDisplayLarge: 20
    property int fontSizeValueSmall: 23
    property int fontSizeValueMedium: 26
    property int fontSizeValueLarge: 30
    property int fontSizeHero: 40
    property int fontSizeClock: 84
    property int menuPointSize: 9
    property int menuIconPointSize: 10

    // DWM-inspired base palette (suckless dwm config.def.h)
    readonly property color transparent: "transparent"
    property color bg: "#99222222"
    property color bgSolid: "#222222"
    property color lockScreenBg: "#1a1a1a"
    property color border: "#444444" // col_gray2
    property color separator: "#555555"
    property color fg: "#bbbbbb" // col_gray3
    property color selFg: "#eeeeee" // col_gray4
    property color selBg: "#005577" // col_cyan

    // Semantic status and data colors
    property color red: "#ff0000"
    property color green: "#00ff00"
    property color yellow: "#ffff00"
    property color critical: "#cc241d"
    property color positive: "#4ade80"
    property color negative: "#f87171"
    property color weatherClear: "#d79921"
    property color weatherFog: "#928374"
    property color weatherRain: "#458588"
    property color weatherSnow: "#83a598"

    // Reusable interaction and surface states
    property color hover: Qt.rgba(1, 1, 1, 0.10)
    property color hoverSoft: Qt.rgba(1, 1, 1, 0.08)
    property color hoverSubtle: Qt.rgba(1, 1, 1, 0.05)
    property color surfaceSubtle: Qt.rgba(1, 1, 1, 0.04)
    property color disabledSurface: Qt.rgba(1, 1, 1, 0.06)
    property color fieldBg: Qt.rgba(0, 0, 0, 0.25)
    property color shadow: Qt.rgba(0, 0, 0, 0.12)
    property color scrim: Qt.rgba(0, 0, 0, 0.28)
    property color menuHover: Qt.rgba(1, 1, 1, 0.13)
    property color menuDisabledFg: Qt.rgba(1, 1, 1, 0.53)
    property color scrollIndicator: Qt.rgba(1, 1, 1, 0.40)
    // Derived from base tokens; they follow fg/selBg overrides automatically.
    readonly property color placeholderFg: withAlpha(fg, 0.45)
    readonly property color selectionSubtle: withAlpha(selBg, 0.20)
    readonly property color selectionSoft: withAlpha(selBg, 0.24)
    readonly property color selectionMedium: withAlpha(selBg, 0.32)
    readonly property color selection: withAlpha(selBg, 0.40)
    readonly property color selectionStrong: withAlpha(selBg, 0.55)
    readonly property color positiveSurface: withAlpha(positive, 0.15)
    readonly property color negativeSurface: withAlpha(negative, 0.15)

    // Shared geometry tokens. One-off component geometry stays local.
    property int spacingTiny: 2
    property int spacingMicro: 3
    property int spacingXSmall: 4
    property int spacingSmall: 5
    property int spacingCompact: 6
    property int spacingIntermediate: 7
    property int spacingComfortable: 8
    property int spacingMedium: 10
    property int spacingSection: 12
    property int spacingContent: 14
    property int spacingLarge: 15
    property int spacingPanel: 16
    property int spacingXLarge: 20
    property int spacingPage: 24
    property int spacingWide: 25
    property int spacingDisplay: 30
    property int spacingHero: 40
    property int popupPadding: 5
    property int controlPadding: 10
    property int panelPadding: 16
    property int dialogPadding: 18
    property int sectionPadding: 20
    property int radiusNone: 0
    property int radiusSmall: 2
    property int radiusCompact: 3
    property int radiusMedium: 4
    property int radiusComfortable: 5
    property int radiusPanel: 6
    property int radiusHandle: 7
    property int radiusLarge: 8
    property int radiusAction: 12
    property int radiusRound: 999

    // Shared opacity roles
    property real opacityOpaque: 1.0
    property real opacityBarelyVisible: 0.10
    property real opacityVerySubtle: 0.15
    property real opacityFaint: 0.20
    property real opacityQuarter: 0.25
    property real opacitySoft: 0.30
    property real opacitySubtle: 0.35
    property real opacityDisabled: 0.45
    property real opacityMuted: 0.50
    property real opacityMedium: 0.55
    property real opacitySecondaryLow: 0.60
    property real opacitySecondary: 0.65
    property real opacitySecondaryHigh: 0.70
    property real opacityStrong: 0.75
    property real opacityProminent: 0.80
    property real chartFillOpacity: 0.28

    property FileView themeFile: FileView {
        path: Quickshell.env("QS_THEME_FILE") || Quickshell.shellPath("theme.json")
        watchChanges: true
        printErrors: false
        onLoaded: {
            theme.themeFileUsed = path;
            theme.applyThemeOverrides(text());
        }
        onFileChanged: reload()
    }

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
