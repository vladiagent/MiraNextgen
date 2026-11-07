import QtQuick
import QtQuick.Controls
import "."

Button {
    id: root
    property bool accent: false
    implicitHeight: 36
    implicitWidth: Math.max(72, caption.implicitWidth + 28)
    padding: 10
    scale: down ? 0.98 : 1
    opacity: enabled ? 1 : 0.4
    font.family: Theme.fontFamily
    font.weight: Font.Normal
    font.pixelSize: 13
    contentItem: Label {
        id: caption
        text: root.text
        font: root.font
        horizontalAlignment: Text.AlignHCenter
    }
    background: Rectangle {
        radius: height / 2
        color: root.down ? Theme.activeSurface : root.hovered || root.visualFocus ? Theme.hover : root.accent ? Theme.activeSurface : "transparent"
        border.width: 1
        border.color: root.visualFocus ? Theme.accent : Theme.border
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.fast
            easing.type: Easing.OutCubic
        }
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
