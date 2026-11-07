import QtQuick
import Quickshell
import ".."
import "../components"
import "../services"

Rectangle {
    id: root
    objectName: "launcher-window-tile"
    required property var window
    required property var controller
    required property int workspace
    property bool dropTarget: false
    readonly property var ipc: window?.lastIpcObject || ({})
    readonly property string address: window?.address || ""
    readonly property var geometry: HyprlandWindows.geometry(window)
    readonly property string icon: LauncherApps.iconFor(ipc.class || "", ipc.initialClass || "")
    property real pressX: 0
    property real pressY: 0
    property real entrance: 0
    Component.onCompleted: entrance = 1
    readonly property rect targetBounds: Qt.rect(geometry.x * parent.width, geometry.y * parent.height,
        Math.min(parent.width * (1 - geometry.x), Math.max(8, geometry.w * parent.width)),
        Math.min(parent.height * (1 - geometry.y), Math.max(8, geometry.h * parent.height)))
    property bool landing: false
    property bool animateBounds: true
    property rect landingBounds
    property rect tileBounds: landing ? landingBounds : targetBounds
    function landFrom(ghost, destination): void {
        const topLeft = ghost.mapToItem(parent, 0, 0);
        const bottomRight = ghost.mapToItem(parent, ghost.width, ghost.height);
        animateBounds = false;
        tileBounds = Qt.rect(topLeft.x, topLeft.y, bottomRight.x - topLeft.x, bottomRight.y - topLeft.y);
        landingBounds = Qt.rect(destination.x * parent.width, destination.y * parent.height,
            Math.min(parent.width * (1 - destination.x), Math.max(8, destination.w * parent.width)),
            Math.min(parent.height * (1 - destination.y), Math.max(8, destination.h * parent.height)));
        landing = true;
        ghost.handedOff = true;
        animateBounds = true;
        tileBounds = Qt.binding(() => root.landing ? root.landingBounds : root.targetBounds);
        completeLanding();
    }
    function completeLanding(): void {
        if (landing && Math.abs(tileBounds.x - landingBounds.x) < 0.001
                && Math.abs(tileBounds.y - landingBounds.y) < 0.001
                && Math.abs(tileBounds.width - landingBounds.width) < 0.001
                && Math.abs(tileBounds.height - landingBounds.height) < 0.001)
            landing = false;
    }
    onTileBoundsChanged: if (landing) Qt.callLater(completeLanding)
    Behavior on tileBounds {
        enabled: root.animateBounds && root.controller.opened && root.controller.reveal === 1
        PropertyAnimation {
            duration: Motion.layout
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.settle
        }
    }
    x: tileBounds.x
    y: tileBounds.y
    width: tileBounds.width
    height: tileBounds.height
    radius: Math.min(9, height / 4)
    color: dropTarget ? Theme.activeSurface : hit.containsMouse ? Theme.withAlpha(Theme.accent, 0.12) : Theme.withAlpha(Theme.hover, 0.76)
    border.width: dropTarget ? 2 : 1
    border.color: dropTarget ? Theme.accent : hit.containsMouse || window?.activated ? Theme.withAlpha(Theme.accent, 0.65) : Theme.withAlpha(Theme.text, 0.16)
    property real dragOpacity: address && controller.dragAddress === address ? 0.3 : 1
    Behavior on dragOpacity { NumberAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }
    opacity: landing ? 1 : dragOpacity * entrance
    z: landing ? 10 : 0
    Behavior on entrance { NumberAnimation { duration: Motion.layout; easing.type: Easing.OutQuint } }
    Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: Motion.control; easing.type: Easing.OutCubic } }
    Image {
        id: appIcon
        anchors.centerIn: parent
        width: Math.max(0, Math.min(36, parent.width - 8, parent.height - 8)); height: width
        source: LauncherApps.iconSource(root.icon)
        sourceSize: Qt.size(72, 72)
        fillMode: Image.PreserveAspectFit
    }
    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true
        onPressed: mouse => { root.pressX = mouse.x; root.pressY = mouse.y; }
        onPositionChanged: mouse => {
            if (!pressed || !root.address) return;
            const position = mapToItem(root.controller.dragLayer, mouse.x, mouse.y);
            if (!root.controller.dragAddress && Math.hypot(mouse.x - root.pressX, mouse.y - root.pressY) > 7)
                root.controller.beginDrag(root.address, root.workspace, root.icon, root.window?.title || "", position, root.width, root.height);
            else if (root.controller.dragAddress === root.address) root.controller.updateDrag(position);
        }
        onReleased: {
            if (!root.address) { root.controller.cancelDrag(); return; }
            if (root.controller.dragAddress === root.address) root.controller.finishDrag();
            else root.controller.requestFocus(root.address, root.workspace);
        }
        onCanceled: root.controller.cancelDrag()
    }
    Accessible.role: Accessible.Button
    Accessible.name: (window?.title || "Window") + ", workspace " + workspace
    Accessible.onPressAction: if (address) controller.requestFocus(address, workspace)
}
