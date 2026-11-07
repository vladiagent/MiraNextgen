import QtQuick
import Quickshell
import ".."
Pill {
    id: root
    required property var barWindow
    signal actionRequested(string action)
    property bool opened: false
    implicitWidth: Theme.pillHeight
    highlighted: opened
    IconButton {
        anchors.centerIn: parent
        width: 30; height: 30
        icon: "power"
        warning: true
        tooltip: "Power menu"
        onClicked: root.opened = !root.opened
    }
    PowerPanel { barWindow: root.barWindow; controller: root; onActionRequested: action => root.actionRequested(action) }
}
