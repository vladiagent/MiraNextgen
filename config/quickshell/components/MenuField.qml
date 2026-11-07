import QtQuick
import QtQuick.Controls
import ".."

TextField {
    id: root
    implicitHeight: 36
    font.family: Theme.fontFamily
    font.weight: Theme.fontWeight
    font.pixelSize: 13
    color: Theme.text
    placeholderTextColor: Theme.muted
    selectionColor: Theme.accent
    selectedTextColor: "#282828"
    leftPadding: 12
    rightPadding: 12
    background: Rectangle {
        radius: 10
        color: Theme.hover
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : Theme.border
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
    }
}
