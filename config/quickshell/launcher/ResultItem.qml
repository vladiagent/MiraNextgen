import QtQuick
import Quickshell
import ".."
import "../components"
import "../services"

Item {
    id: root
    required property var result
    property bool selected: false
    signal activate
    signal hovered
    height: 60
    scale: hit.pressed ? 0.992 : 1
    Behavior on scale { NumberAnimation { duration: Motion.press; easing.type: Easing.OutCubic } }
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: root.selected ? "transparent" : hit.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }
    }
    Item {
        x: 16; width: 34; height: 34
        anchors.verticalCenter: parent.verticalCenter
        Image {
            id: image
            anchors.fill: parent
            visible: root.result.kind === "app" && status === Image.Ready
            source: root.result.kind === "app" ? LauncherApps.iconSource(root.result.icon) : ""
            sourceSize: Qt.size(68, 68)
            fillMode: Image.PreserveAspectFit
        }
        Icon {
            anchors.centerIn: parent
            width: 26; height: 26
            visible: root.result.kind !== "app" || image.status !== Image.Ready
            name: root.result.kind === "calculator" ? "calculator" : root.result.kind === "web" ? "globe" : "app"
            color: root.result.kind === "calculator" ? Theme.accent : Theme.muted
        }
    }
    Column {
        x: 68; width: parent.width - 112; spacing: 3
        anchors.verticalCenter: parent.verticalCenter
        BarText { width: parent.width; text: root.result.title; font.pixelSize: 15 }
        BarText { width: parent.width; text: root.result.subtitle; font.pixelSize: 12; color: Theme.muted }
    }
    Icon {
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        name: root.result.kind === "calculator" ? "copy" : "enter"
        opacity: root.selected ? 0.85 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.activate()
    }
    Accessible.role: Accessible.Button
    Accessible.name: result.title + ". " + result.subtitle
    Accessible.onPressAction: activate()
}
