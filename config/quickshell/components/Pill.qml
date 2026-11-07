import QtQuick
import ".."

Rectangle {
    id: root
    property bool highlighted: false
    property bool pressed: false
    readonly property bool hovered: hoverHandler.hovered
    implicitHeight: Theme.pillHeight
    radius: Theme.radius
    color: highlighted || hovered ? Theme.hover : Theme.background
    border.width: 1
    border.color: hovered ? Qt.rgba(0.96, 0.90, 0.78, 0.15) : Theme.border
    scale: pressed ? 0.98 : 1
    HoverHandler {
        id: hoverHandler
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.normal
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Theme.normal
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.fast
            easing.type: Easing.OutCubic
        }
    }
}
