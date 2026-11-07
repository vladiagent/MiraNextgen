import QtQuick
import ".."
import "../components"

Rectangle {
    id: root
    property string placeholderText: "Search apps, calculate, or search the web"
    property string accessibleName: "Search applications and the web"
    property alias text: input.text
    property alias input: input
    property bool horizontalNavigation: false
    signal horizontalStep(int direction)
    signal step(int direction)
    signal activate
    signal dismiss
    implicitHeight: 52
    radius: Theme.radius - 2
    color: Theme.withAlpha(Theme.background, 0.70)
    border.width: 1
    border.color: input.activeFocus ? Theme.withAlpha(Theme.accent, 0.48) : Theme.border
    Behavior on border.color { ColorAnimation { duration: Motion.control; easing.type: Easing.OutCubic } }
    Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; name: "search"; width: 20; height: 20 }
    TextInput {
        id: input
        x: 54; width: parent.width - 100
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.fontFamily
        font.weight: Theme.fontWeight
        font.pixelSize: 16
        color: Theme.text
        selectionColor: Theme.activeSurface
        selectedTextColor: Theme.text
        clip: true
        selectByMouse: true
        activeFocusOnTab: true
        inputMethodHints: Qt.ImhNoPredictiveText
        Text {
            anchors.fill: parent
            visible: !input.text.length
            text: root.placeholderText
            color: Theme.muted
            opacity: 0.7
            font: input.font
            elide: Text.ElideRight
        }
        Keys.onLeftPressed: event => {
            if (root.horizontalNavigation && event.modifiers === Qt.NoModifier)
                root.horizontalStep(-1);
            else
                event.accepted = false;
        }
        Keys.onRightPressed: event => {
            if (root.horizontalNavigation && event.modifiers === Qt.NoModifier)
                root.horizontalStep(1);
            else
                event.accepted = false;
        }
        Keys.onUpPressed: root.step(-1)
        Keys.onDownPressed: root.step(1)
        Keys.onReturnPressed: root.activate()
        Keys.onEnterPressed: root.activate()
        Keys.onEscapePressed: root.dismiss()
        Accessible.name: root.accessibleName
    }
    IconButton {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        icon: "close"
        width: 30; height: 30
        onClicked: { if (input.text.length) input.clear(); else root.dismiss(); input.forceActiveFocus(); }
        Accessible.name: input.text.length ? "Clear search" : "Close launcher"
    }
}
