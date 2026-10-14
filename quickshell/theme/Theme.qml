pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Material You palette from scripts/material.py (colors.json, colours under
// "colors"); hot-swaps when the file changes. Also accepts a flat
// {name: "#hex"} file or an Ignis user_options.json.
Singleton {
    id: root

    property var palette: ({})

    readonly property color background: palette.background ?? "#1a1112"
    readonly property color surface: palette.surface ?? "#1a1112"
    readonly property color surfaceContainer: palette.surfaceContainer ?? "#271d1e"
    readonly property color surfaceContainerLow: palette.surfaceContainerLow ?? "#22191a"
    readonly property color surfaceContainerHigh: palette.surfaceContainerHigh ?? "#322828"
    readonly property color surfaceContainerHighest: palette.surfaceContainerHighest ?? "#3d3233"
    readonly property color secondaryContainer: palette.secondaryContainer ?? "#5d3f42"
    // "on*" Material names are exposed as fg*: QML reads onX as a signal handler.
    readonly property color fgSurface: palette.onSurface ?? "#f0dedf"
    readonly property color fgSurfaceVariant: palette.onSurfaceVariant ?? "#d7c1c2"
    readonly property color primary: palette.primary ?? "#ffb2bb"
    readonly property color fgPrimary: palette.onPrimary ?? "#561d28"
    readonly property color primaryContainer: palette.primaryContainer ?? "#72333e"
    readonly property color fgPrimaryContainer: palette.onPrimaryContainer ?? "#ffd9dc"
    readonly property color tertiary: palette.tertiary ?? "#e8bf8f"
    readonly property color fgTertiary: palette.onTertiary ?? "#442b06"
    readonly property color error: palette.error ?? "#ffb4ab"
    readonly property color outline: palette.outline ?? "#9f8c8d"

    readonly property string fontFamily: "JetBrains Mono"
    readonly property int fontSize: 15      // ~1rem in the old GTK styles
    readonly property int radius: 15

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Equivalent of the SCSS hover() mixin.
    function hover(c: color): color {
        return Config.appearance.darkMode ? Qt.lighter(c, 1.15) : Qt.darker(c, 1.08);
    }

    FileView {
        path: Config.expand(Config.appearance.colorsFile)
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const obj = JSON.parse(text());
                root.palette = obj.colors ?? obj.material?.colors ?? obj;
            } catch (e) {
                console.warn("Theme: cannot parse", path, e);
            }
        }
    }
}
