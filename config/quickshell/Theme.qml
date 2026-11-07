pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: theme
    property var palette: ({})
    property FileView paletteFile: FileView {
        path: Quickshell.shellDir + "/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { theme.palette = JSON.parse(text()); }
            catch (error) { console.warn("Invalid wallpaper palette:", error); }
        }
    }
    function withAlpha(value: color, opacity: real): color {
        return Qt.rgba(value.r, value.g, value.b, opacity);
    }
    readonly property string fontFamily: "Google Sans"
    readonly property int fontWeight: Font.Normal
    readonly property int fontSize: 13
    readonly property color background: Qt.rgba(40 / 255, 40 / 255, 40 / 255, 0.80)
    readonly property color hover: Qt.rgba(60 / 255, 56 / 255, 54 / 255, 0.62)
    readonly property color panel: Qt.rgba(40 / 255, 40 / 255, 40 / 255, 0.94)
    readonly property color accent: (palette.primary || "#e9c16c")
    readonly property color warm: (palette.tertiary || "#b0cfa9")
    readonly property color text: (palette.on_surface || "#ebe1d4")
    readonly property color muted: (palette.on_surface_variant || "#d0c5b4")
    readonly property color border: withAlpha((palette.on_surface || "#ebe1d4"), 0.08)
    readonly property color activeSurface: withAlpha((palette.primary || "#e9c16c"), 0.22)
    readonly property int pillHeight: 36
    readonly property int radius: 19
    readonly property int topMargin: 5
    readonly property int edgeMargin: 10
    readonly property int gap: 8
    readonly property int barHeight: pillHeight + topMargin + 5
    readonly property int fast: 120
    readonly property int normal: 180
    readonly property int glide: 200
    readonly property int workspaceCell: 30
    readonly property int mediaWidth: 220
    readonly property int mediaPanelWidth: 384
    readonly property int mediaPanelHeight: 260
}
