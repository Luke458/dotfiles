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

    // A replacement map preserves bindings and resets removed overrides.
    property string themeFileUsed: ""
    readonly property int overrideCount: Object.keys(_overrides).length
    property var _overrides: ({})
    readonly property var _stringTokens: "fontUi fontMono fontIcon".split(" ")
    readonly property var _intTokens: "fontSizeCaption fontSizeSmall fontSizeBody fontSizeLabel fontSizeBar fontSizeTitle fontSizeHeading fontSizeHeadingLarge fontSizeBanner fontSizeDisplaySmall fontSizeDisplay fontSizeDisplayLarge fontSizeValueSmall fontSizeValueMedium fontSizeValueLarge fontSizeHero fontSizeClock menuPointSize menuIconPointSize spacingTiny spacingMicro spacingXSmall spacingSmall spacingCompact spacingIntermediate spacingComfortable spacingMedium spacingSection spacingContent spacingLarge spacingPanel spacingXLarge spacingPage spacingWide spacingDisplay spacingHero popupPadding controlPadding panelPadding dialogPadding sectionPadding radiusNone radiusSmall radiusCompact radiusMedium radiusComfortable radiusPanel radiusHandle radiusLarge radiusAction radiusRound".split(" ")
    readonly property var _realTokens: "opacityOpaque opacityBarelyVisible opacityVerySubtle opacityFaint opacityQuarter opacitySoft opacitySubtle opacityDisabled opacityMuted opacityMedium opacitySecondaryLow opacitySecondary opacitySecondaryHigh opacityStrong opacityProminent chartFillOpacity".split(" ")
    readonly property var _colorTokens: "bg bgSolid lockScreenBg border separator fg selFg selBg red green yellow critical positive negative weatherClear weatherFog weatherRain weatherSnow hover hoverSoft hoverSubtle surfaceSubtle disabledSurface fieldBg shadow scrim menuHover menuDisabledFg scrollIndicator".split(" ")

    function token(name, fallback) {
        return Object.prototype.hasOwnProperty.call(_overrides, name) ? _overrides[name] : fallback;
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
        const next = {};
        for (const key of Object.keys(parsed)) {
            const value = parsed[key];
            let valid = false;
            if (_colorTokens.includes(key)) {
                try {
                    valid = typeof value === "string" && Qt.color(value).valid;
                } catch (error) {
                    valid = false;
                }
            } else if (_stringTokens.includes(key))
                valid = typeof value === "string" && value.trim().length > 0;
            else if (_intTokens.includes(key))
                valid = Number.isInteger(value) && value >= (key.startsWith("fontSize") || key.endsWith("PointSize") ? 1 : 0);
            else if (_realTokens.includes(key))
                valid = typeof value === "number" && isFinite(value) && value >= 0 && value <= 1;
            if (valid)
                next[key] = value;
            else
                console.warn("Theme: ignored invalid or non-overridable token: " + key);
        }
        _overrides = next;
    }

    // Font families
    readonly property string fontUi: token("fontUi", "Noto Sans")
    readonly property string fontMono: token("fontMono", "MesloLGS Nerd Font Mono")
    readonly property string fontIcon: token("fontIcon", "Symbols Nerd Font")

    // Typography scale
    readonly property int fontSizeCaption: token("fontSizeCaption", 9)
    readonly property int fontSizeSmall: token("fontSizeSmall", 10)
    readonly property int fontSizeBody: token("fontSizeBody", 11)
    readonly property int fontSizeLabel: token("fontSizeLabel", 12)
    readonly property int fontSizeBar: token("fontSizeBar", 13)
    readonly property int fontSizeTitle: token("fontSizeTitle", 14)
    readonly property int fontSizeHeading: token("fontSizeHeading", 15)
    readonly property int fontSizeHeadingLarge: token("fontSizeHeadingLarge", 16)
    readonly property int fontSizeBanner: token("fontSizeBanner", 17)
    readonly property int fontSizeDisplaySmall: token("fontSizeDisplaySmall", 18)
    readonly property int fontSizeDisplay: token("fontSizeDisplay", 19)
    readonly property int fontSizeDisplayLarge: token("fontSizeDisplayLarge", 20)
    readonly property int fontSizeValueSmall: token("fontSizeValueSmall", 23)
    readonly property int fontSizeValueMedium: token("fontSizeValueMedium", 26)
    readonly property int fontSizeValueLarge: token("fontSizeValueLarge", 30)
    readonly property int fontSizeHero: token("fontSizeHero", 40)
    readonly property int fontSizeClock: token("fontSizeClock", 84)
    readonly property int menuPointSize: token("menuPointSize", 9)
    readonly property int menuIconPointSize: token("menuIconPointSize", 10)

    // DWM-inspired base palette (suckless dwm config.def.h)
    readonly property color transparent: "transparent"
    readonly property color bg: token("bg", bgSolid)
    readonly property color bgSolid: token("bgSolid", "#222222")
    readonly property color lockScreenBg: token("lockScreenBg", "#1a1a1a")
    readonly property color border: token("border", "#444444") // col_gray2
    readonly property color separator: token("separator", "#555555")
    readonly property color fg: token("fg", "#bbbbbb") // col_gray3
    readonly property color selFg: token("selFg", "#eeeeee") // col_gray4
    readonly property color selBg: token("selBg", "#005577") // col_cyan

    // Semantic status and data colors
    readonly property color red: token("red", "#ff0000")
    readonly property color green: token("green", "#00ff00")
    readonly property color yellow: token("yellow", "#ffff00")
    readonly property color critical: token("critical", "#cc241d")
    readonly property color positive: token("positive", "#4ade80")
    readonly property color negative: token("negative", "#f87171")
    readonly property color weatherClear: token("weatherClear", "#d79921")
    readonly property color weatherFog: token("weatherFog", "#928374")
    readonly property color weatherRain: token("weatherRain", "#458588")
    readonly property color weatherSnow: token("weatherSnow", "#83a598")

    // Reusable interaction and surface states
    readonly property color hover: token("hover", withAlpha(fg, .10))
    readonly property color hoverSoft: token("hoverSoft", withAlpha(fg, .08))
    readonly property color hoverSubtle: token("hoverSubtle", withAlpha(fg, .05))
    readonly property color surfaceSubtle: token("surfaceSubtle", withAlpha(fg, .04))
    readonly property color disabledSurface: token("disabledSurface", withAlpha(fg, .06))
    readonly property color fieldBg: token("fieldBg", withAlpha(fg, 0.06))
    readonly property color shadow: token("shadow", Qt.rgba(0, 0, 0, 0.12))
    readonly property color scrim: token("scrim", Qt.rgba(0, 0, 0, 0.28))
    readonly property color menuHover: token("menuHover", withAlpha(fg, .13))
    readonly property color menuDisabledFg: token("menuDisabledFg", withAlpha(fg, 0.53))
    readonly property color scrollIndicator: token("scrollIndicator", withAlpha(fg, .40))
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
    readonly property int spacingTiny: token("spacingTiny", 2)
    readonly property int spacingMicro: token("spacingMicro", 3)
    readonly property int spacingXSmall: token("spacingXSmall", 4)
    readonly property int spacingSmall: token("spacingSmall", 5)
    readonly property int spacingCompact: token("spacingCompact", 6)
    readonly property int spacingIntermediate: token("spacingIntermediate", 7)
    readonly property int spacingComfortable: token("spacingComfortable", 8)
    readonly property int spacingMedium: token("spacingMedium", 10)
    readonly property int spacingSection: token("spacingSection", 12)
    readonly property int spacingContent: token("spacingContent", 14)
    readonly property int spacingLarge: token("spacingLarge", 15)
    readonly property int spacingPanel: token("spacingPanel", 16)
    readonly property int spacingXLarge: token("spacingXLarge", 20)
    readonly property int spacingPage: token("spacingPage", 24)
    readonly property int spacingWide: token("spacingWide", 25)
    readonly property int spacingDisplay: token("spacingDisplay", 30)
    readonly property int spacingHero: token("spacingHero", 40)
    readonly property int popupPadding: token("popupPadding", 5)
    readonly property int controlPadding: token("controlPadding", 10)
    readonly property int panelPadding: token("panelPadding", 16)
    readonly property int dialogPadding: token("dialogPadding", 18)
    readonly property int sectionPadding: token("sectionPadding", 20)
    readonly property int radiusNone: token("radiusNone", 0)
    readonly property int radiusSmall: token("radiusSmall", 0)
    readonly property int radiusCompact: token("radiusCompact", 0)
    readonly property int radiusMedium: token("radiusMedium", 0)
    readonly property int radiusComfortable: token("radiusComfortable", 0)
    readonly property int radiusPanel: token("radiusPanel", 0)
    readonly property int radiusHandle: token("radiusHandle", 0)
    readonly property int radiusLarge: token("radiusLarge", 0)
    readonly property int radiusAction: token("radiusAction", 12)
    readonly property int radiusRound: token("radiusRound", 999)

    // Shared opacity roles
    readonly property real opacityOpaque: token("opacityOpaque", 1.0)
    readonly property real opacityBarelyVisible: token("opacityBarelyVisible", 0.10)
    readonly property real opacityVerySubtle: token("opacityVerySubtle", 0.15)
    readonly property real opacityFaint: token("opacityFaint", 0.20)
    readonly property real opacityQuarter: token("opacityQuarter", 0.25)
    readonly property real opacitySoft: token("opacitySoft", 0.30)
    readonly property real opacitySubtle: token("opacitySubtle", 0.35)
    readonly property real opacityDisabled: token("opacityDisabled", 0.45)
    readonly property real opacityMuted: token("opacityMuted", 0.50)
    readonly property real opacityMedium: token("opacityMedium", 0.55)
    readonly property real opacitySecondaryLow: token("opacitySecondaryLow", 0.60)
    readonly property real opacitySecondary: token("opacitySecondary", 0.65)
    readonly property real opacitySecondaryHigh: token("opacitySecondaryHigh", 0.70)
    readonly property real opacityStrong: token("opacityStrong", 0.75)
    readonly property real opacityProminent: token("opacityProminent", 0.80)
    readonly property real chartFillOpacity: token("chartFillOpacity", 0.28)

    property FileView themeFile: FileView {
        path: Quickshell.env("QS_THEME_FILE") || Quickshell.shellPath("theme.json")
        watchChanges: true
        printErrors: false
        onLoaded: {
            theme.themeFileUsed = path;
            theme.applyThemeOverrides(text());
        }
        onFileChanged: reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                theme.applyThemeOverrides("{}");
        }
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
