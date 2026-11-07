pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQml.Models
import ".."
import "../components"
import "../services"

Rectangle {
    id: root
    objectName: "launcher-workspace-card"
    function renderedTiles(): var {
        return canvas.children.filter(child => child.objectName === "launcher-window-tile").map(child => ({
            address: child.window?.address, landing: child.landing, opacity: child.opacity, entrance: child.entrance,
            x: child.x, y: child.y, w: child.width, h: child.height, icon: child.icon}));
    }
    required property int number
    required property var controller
    readonly property var windows: HyprlandWindows.windows(number)
    readonly property bool active: HyprlandWindows.activeWorkspace === number
    readonly property bool occupied: windows.length > 0
    property real selection: active || drop.containsDrag ? 1 : 0
    Behavior on selection { NumberAnimation { duration: Motion.control; easing.type: Easing.OutCubic } }
    HoverHandler { id: hover }
    function handOffDrag(ghost, destination): void {
        const tile = canvas.children.find(child => child.objectName === "launcher-window-tile" && child.address === ghost.windowAddress);
        if (tile) tile.landFrom(ghost, destination);
    }
    property string dropTargetAddress: ""
    property var floatingDrop: null
    function updateDrop(event): void {
        dropTargetAddress = ""; floatingDrop = null;
        const source = HyprlandWindows.windowByAddress(event.source?.windowAddress || "");
        if (!source || source.workspace?.id !== number) return;
        const x = (event.x - canvas.x) / canvas.width, y = (event.y - canvas.y) / canvas.height;
        if (source.lastIpcObject.floating) {
            const position = HyprlandWindows.floatingPosition(source, x, y);
            const monitor = source.monitor?.lastIpcObject || {};
            const geometry = HyprlandWindows.geometry(source);
            let mw = (monitor.width || 1920) / (monitor.scale || 1), mh = (monitor.height || 1080) / (monitor.scale || 1);
            if ([1,3,5,7].includes(monitor.transform || 0)) { const swap = mw; mw = mh; mh = swap; }
            floatingDrop = {x: (position.x - (monitor.x || 0)) / mw, y: (position.y - (monitor.y || 0)) / mh,
                            w: geometry.w, h: geometry.h, pointerX: x, pointerY: y};
            return;
        }
        const own = HyprlandWindows.geometry(source);
        if (x >= own.x && x <= own.x + own.w && y >= own.y && y <= own.y + own.h) return;
        let nearest = null, distance = Infinity;
        for (const target of windows) {
            if (target.address === source.address || target.lastIpcObject.floating) continue;
            const geometry = HyprlandWindows.geometry(target);
            const dx = Math.max(geometry.x - x, 0, x - geometry.x - geometry.w);
            const dy = Math.max(geometry.y - y, 0, y - geometry.y - geometry.h);
            const score = dx * dx + dy * dy;
            if (score < distance) { nearest = target; distance = score; }
        }
        dropTargetAddress = nearest?.address || "";
    }
    property var previousTiles: ({})
    onWindowsChanged: {
        let snapshots = {};
        for (const window of windows) snapshots[window.address] = {
            geometry: HyprlandWindows.geometry(window),
            icon: LauncherApps.iconFor(window.lastIpcObject.class || "", window.lastIpcObject.initialClass || "")
        };
        for (const address in previousTiles) {
            if (!snapshots[address] && canvas && controller.opened)
                departure.createObject(canvas, {tileGeometry: previousTiles[address].geometry, iconName: previousTiles[address].icon});
        }
        previousTiles = snapshots;
    }
    radius: Theme.radius
    color: drop.containsDrag ? Theme.withAlpha(Theme.accent, 0.10) : Theme.withAlpha(Theme.panel, hover.hovered ? 0.95 : 0.90)
    border.width: 1
    border.color: Theme.withAlpha(Theme.text, hover.hovered ? 0.22 : 0.12)
    Behavior on border.color { ColorAnimation { duration: Motion.control; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }
    Rectangle {
        anchors.fill: parent; anchors.margins: -2
        z: -1; radius: Theme.radius + 2
        color: "transparent"
        border.width: 2
        border.color: Theme.withAlpha(Theme.accent, 0.06)
        opacity: root.selection
    }
    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: "transparent"
        border.width: 2
        border.color: Theme.withAlpha(Theme.accent, 0.85)
        opacity: root.selection
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.controller.lastAction = "workspace:" + root.number; root.controller.requestWorkspace(root.number); }
    }
    BarText {
        x: 15; y: 11
        text: root.number
        opacity: root.occupied ? 1 : 0
        color: root.active ? Theme.accent : Theme.text
        font.pixelSize: 13
        Behavior on opacity { NumberAnimation { duration: Motion.control } }
        Behavior on color { ColorAnimation { duration: Motion.control } }
    }
    BarText {
        anchors.centerIn: parent
        text: root.number
        opacity: root.occupied ? 0 : root.active ? 0.72 : 0.42
        font.pixelSize: 40
        color: root.active ? Theme.accent : Theme.muted
        Behavior on opacity { NumberAnimation { duration: Motion.control } }
        Behavior on color { ColorAnimation { duration: Motion.control } }
    }
    BarText {
        anchors.right: parent.right; anchors.rightMargin: 15; y: 11
        text: root.floatingDrop ? "Move" : root.dropTargetAddress ? "Swap" : ""
        color: Theme.accent; font.pixelSize: 11
    }
    Item {
        id: canvas
        x: 12; y: 35; width: parent.width - 24; height: parent.height - 47
        clip: true
        Repeater {
            model: ScriptModel { values: root.windows }
            delegate: WindowTile {
                required property var modelData
                window: modelData
                workspace: root.number
                controller: root.controller
                dropTarget: root.dropTargetAddress !== "" && root.dropTargetAddress === (window?.address || "")
            }
        }
        Rectangle {
            visible: !!root.floatingDrop
            x: (root.floatingDrop?.x ?? 0) * parent.width
            y: (root.floatingDrop?.y ?? 0) * parent.height
            width: (root.floatingDrop?.w ?? 0) * parent.width
            height: (root.floatingDrop?.h ?? 0) * parent.height
            radius: 9
            color: Theme.withAlpha(Theme.accent, 0.08)
            border.width: 2; border.color: Theme.accent
        }
    }
    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["vladi-hypr-window"]
        onEntered: event => root.updateDrop(event)
        onPositionChanged: event => root.updateDrop(event)
        onExited: { root.dropTargetAddress = ""; root.floatingDrop = null; }
        onDropped: event => {
            root.updateDrop(event);
            if (event.source.windowAddress && event.source.sourceWorkspace !== root.number) {
                HyprlandWindows.moveWindow(event.source.windowAddress, root.number);
                event.acceptProposedAction();
            } else if (root.floatingDrop) {
                root.handOffDrag(event.source, root.floatingDrop);
                HyprlandWindows.moveFloating(event.source.windowAddress, root.floatingDrop.pointerX, root.floatingDrop.pointerY);
                event.acceptProposedAction();
            } else if (root.dropTargetAddress) {
                const target = HyprlandWindows.windowByAddress(root.dropTargetAddress);
                if (target) root.handOffDrag(event.source, HyprlandWindows.geometry(target));
                HyprlandWindows.swapWindows(event.source.windowAddress, root.dropTargetAddress);
                event.acceptProposedAction();
            }
            root.dropTargetAddress = ""; root.floatingDrop = null;
        }
    }
    Component {
        id: departure
        Rectangle {
            id: fading
            required property var tileGeometry
            required property string iconName
            x: tileGeometry.x * parent.width; y: tileGeometry.y * parent.height
            width: Math.max(4, Math.min(parent.width - x, tileGeometry.w * parent.width))
            height: Math.max(4, Math.min(parent.height - y, tileGeometry.h * parent.height))
            radius: Math.min(9, height / 4)
            color: Theme.withAlpha(Theme.hover, 0.76)
            border.width: 1; border.color: Theme.withAlpha(Theme.text, 0.16)
            Image {
                anchors.centerIn: parent
                width: Math.max(0, Math.min(36, parent.width - 8, parent.height - 8)); height: width
                source: LauncherApps.iconSource(fading.iconName)
                sourceSize: Qt.size(72,72); fillMode: Image.PreserveAspectFit
            }
            NumberAnimation on scale { from: 1; to: 0.985; duration: Motion.control; easing.type: Easing.OutCubic; running: true }
            NumberAnimation on opacity { from: 1; to: 0; duration: Motion.control; easing.type: Easing.OutCubic; running: true; onStopped: fading.destroy() }
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: "Workspace " + number + (occupied ? ", " + windows.length + " windows" : ", empty")
}
