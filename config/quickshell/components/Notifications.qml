import QtQuick
import ".."
import "../services"

Pill {
    property var barWindow: null
    implicitWidth: 56
    Row {
        anchors.centerIn: parent
        spacing: 1
        BarText {
            text: NotificationService.count > 99 ? "99+" : String(NotificationService.count)
            height: 28
            color: NotificationService.dnd ? Theme.accent : Theme.muted
            font.pixelSize: 12
        }
        IconButton {
            icon: NotificationService.dnd ? "bellOff" : "bell"
            active: NotificationService.dnd
            tooltip: NotificationService.available ? (NotificationService.dnd ? "Do Not Disturb · Notifications" : "Notifications") : "Notifications"
            onClicked: button => {
                if (button === Qt.RightButton)
                    NotificationService.toggleDnd();
                else
                    NotificationService.togglePanel(barWindow?.screen, barWindow);
            }
        }
    }
}
