import QtQuick
import QtQuick.Controls
import ".."

Button {
    id: root
    property bool primary: false
    implicitHeight: 32
    implicitWidth: Math.max(64, label.implicitWidth + 24)
    padding: 10
    opacity: enabled ? 1 : 0.4
    scale: down ? 0.97 : 1
    font.family: Theme.fontFamily
    font.weight: Theme.fontWeight
    font.pixelSize: 12
    contentItem: BarText {
        id: label
        text: root.text
        horizontalAlignment: Text.AlignHCenter
        font: root.font
        color: root.primary ? "#282828" : Theme.text
    }
    background: Rectangle {
        radius: 12
        color: root.primary ? (root.hovered ? Qt.lighter(Theme.accent, 1.12) : Theme.accent) : (root.hovered || root.visualFocus ? Theme.hover : Theme.activeSurface)
        border.width: root.visualFocus ? 1 : 0
        border.color: Theme.accent
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.fast
        }
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
