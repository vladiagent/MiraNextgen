import QtQuick
import QtQuick.Controls
import ".."

Item {
    id: root
    property string icon: "music"
    property string tooltip: ""
    property bool active: false
    property bool warning: false
    property bool filled: false
    property int iconSize: 16
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    signal clicked(int button)
    implicitWidth: 30
    implicitHeight: 28
    opacity: enabled ? 1 : 0.35
    Accessible.role: Accessible.Button
    Accessible.name: tooltip
    Accessible.onPressAction: clicked(Qt.LeftButton)
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.filled ? Theme.accent : root.active ? Theme.activeSurface : mouse.containsMouse ? Theme.hover : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.normal
            }
        }
    }
    Icon {
        anchors.centerIn: parent
        width: root.iconSize
        height: root.iconSize
        name: root.icon
        color: root.filled ? "#202922" : root.warning && mouse.containsMouse ? Theme.warm : root.active ? Theme.accent : Theme.text
        scale: mouse.pressed ? 0.88 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Theme.fast
                easing.type: Easing.OutCubic
            }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => root.clicked(event.button)
    }
    ToolTip.visible: mouse.containsMouse && tooltip !== ""
    ToolTip.delay: 650
    ToolTip.text: tooltip
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.fast
        }
    }
}
