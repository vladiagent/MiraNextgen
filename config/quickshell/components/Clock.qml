import QtQuick
import Quickshell
import ".."

Pill {
    implicitWidth: 92
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Row {
        anchors.centerIn: parent
        spacing: 7
        Icon {
            name: "clock"
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.muted
            width: 15
            height: 15
        }
        BarText {
            text: Qt.formatTime(clock.date, "HH:mm")
            height: 22
        }
    }
    Accessible.role: Accessible.StaticText
    Accessible.name: Qt.formatTime(clock.date, "HH:mm")
}
