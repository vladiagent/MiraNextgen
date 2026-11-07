import QtQuick
import Quickshell
import ".."
import "../services"

Pill {
    id: root
    required property var barWindow
    property bool expanded: false
    property real maximumWidth: Theme.mediaWidth + 8
    readonly property bool present: MediaService.available
    implicitWidth: Math.max(0, Math.min(maximumWidth, Theme.mediaWidth + (hovered || expanded ? 8 : 0)))
    opacity: present ? 1 : 0
    visible: opacity > 0.001
    highlighted: expanded
    pressed: hit.pressed
    onPresentChanged: if (!present)
        expanded = false

    MouseArea {
        id: hit
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expanded = !root.expanded
    }
    Item {
        id: trackContent
        anchors.centerIn: parent
        width: Math.max(0, Math.min(root.width - 16, playButton.width + 2 + trackLabel.implicitWidth + 12))
        height: parent.height
        visible: width >= 44
        IconButton {
            id: playButton
            anchors.verticalCenter: parent.verticalCenter
            icon: MediaService.playing ? "pause" : "play"
            iconSize: 14
            enabled: MediaService.player?.canTogglePlaying ?? false
            tooltip: MediaService.playing ? "Pause" : "Play"
            onClicked: MediaService.toggle()
        }
        BarText {
            id: trackLabel
            x: playButton.width + 2
            width: Math.max(0, parent.width - x - 12)
            height: parent.height
            text: MediaService.displayTitle
            color: Theme.text
            opacity: MediaService.playing ? 1 : 0.65
            Behavior on opacity {
                NumberAnimation { duration: Theme.normal }
            }
        }
    }
    MediaPanel {
        barWindow: root.barWindow
        opened: root.expanded
        onCloseRequested: root.expanded = false
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Media: " + MediaService.displayTitle
    Accessible.onPressAction: root.expanded = !root.expanded
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.normal
        }
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.normal
            easing.type: Easing.OutCubic
        }
    }
}
