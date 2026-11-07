pragma Singleton
import QtQuick
import QtQml.Models
import QtQml.XmlListModel

QtObject {
    id: root
    readonly property string fontFamily: config.stringValue("Font") || "Google Sans"
    readonly property int radius: 19
    readonly property int fast: 120
    readonly property int normal: 180
    readonly property string assetsDir: config.stringValue("AssetsDir") || "assets"
    property var palette: ({})
    function asset(file): url {
        return assetsDir.startsWith("/") ? "file://" + assetsDir + "/" + file : Qt.resolvedUrl(assetsDir + "/" + file);
    }
    function alpha(color, opacity): color {
        return Qt.rgba(color.r, color.g, color.b, opacity);
    }
    readonly property color background: palette.background || "#282828"
    readonly property color surface: palette.surface || "#282828"
    readonly property color surfaceVariant: palette.surface_variant || "#3c3836"
    readonly property color accent: palette.primary || "#95d5a8"
    readonly property color secondary: palette.secondary || "#b5ccb7"
    readonly property color tertiary: palette.tertiary || "#a3cdda"
    readonly property color text: palette.on_surface || "#ebdbb2"
    readonly property color muted: palette.on_surface_variant || "#a89984"
    readonly property color error: palette.error || "#ffb4ab"
    readonly property color warning: palette.warning || "#a3cdda"
    readonly property color panel: Qt.rgba(40 / 255, 40 / 255, 40 / 255, 0.90)
    readonly property color pill: Qt.rgba(40 / 255, 40 / 255, 40 / 255, 0.80)
    readonly property color hover: Qt.rgba(60 / 255, 56 / 255, 54 / 255, 0.62)
    readonly property color activeSurface: alpha(accent, 0.22)
    readonly property color border: alpha(text, 0.08)

    property XmlListModel colors: XmlListModel {
        id: colorData
        source: root.asset("palette.xml")
        query: "/theme/palette"
        XmlListModelRole {
            name: "background"
            elementName: "background"
        }
        XmlListModelRole {
            name: "surface"
            elementName: "surface"
        }
        XmlListModelRole {
            name: "surface_variant"
            elementName: "surface_variant"
        }
        XmlListModelRole {
            name: "primary"
            elementName: "primary"
        }
        XmlListModelRole {
            name: "secondary"
            elementName: "secondary"
        }
        XmlListModelRole {
            name: "tertiary"
            elementName: "tertiary"
        }
        XmlListModelRole {
            name: "on_surface"
            elementName: "on_surface"
        }
        XmlListModelRole {
            name: "on_surface_variant"
            elementName: "on_surface_variant"
        }
        XmlListModelRole {
            name: "error"
            elementName: "error"
        }
        XmlListModelRole {
            name: "warning"
            elementName: "warning"
        }
    }
    property Instantiator reader: Instantiator {
        model: colorData
        delegate: QtObject {
            required property string background
            required property string surface
            required property string surface_variant
            required property string primary
            required property string secondary
            required property string tertiary
            required property string on_surface
            required property string on_surface_variant
            required property string error
            required property string warning
            Component.onCompleted: root.palette = ({
                    background,
                    surface,
                    surface_variant,
                    primary,
                    secondary,
                    tertiary,
                    on_surface,
                    on_surface_variant,
                    error,
                    warning
                })
        }
    }
}
