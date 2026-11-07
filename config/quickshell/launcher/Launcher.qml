import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "../components"
import "../services"
import "Calculator.js" as Calculator
import "Search.js" as Search

PanelWindow {
    id: root
    property bool opened: false
    property bool motionReady: false
    property real reveal: opened && motionReady ? 1 : 0
    FrameAnimation {
        running: root.opened && !root.motionReady
        onTriggered: root.motionReady = true
    }
    property var results: []
    property ShellScreen targetScreen: Quickshell.screens[0] ?? null
    property string dragAddress: ""
    property string lastAction: ""
    property var pendingAction: null
    property alias dragLayer: dragCanvas
    readonly property string query: queryField.text
    screen: targetScreen
    visible: opened || reveal > 0.001
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.namespace: "vladi-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Behavior on reveal {
        NumberAnimation {
            duration: root.opened ? Motion.enter : Motion.exit
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.opened ? Motion.settle : Motion.dismiss
        }
    }
    onVisibleChanged: {
        if (!visible) {
            motionReady = false;
            reset();
            if (pendingAction) Qt.callLater(runPendingAction);
        }
    }
    onOpenedChanged: {
        HyprlandWindows.overviewVisible = opened;
        if (opened) Qt.callLater(() => queryField.input.forceActiveFocus());
    }
    function reset(): void { queryField.text = ""; list.currentIndex = 0; cancelDrag(); }
    function open(): void {
        if (opened) { queryField.input.forceActiveFocus(); return; }
        targetScreen = Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0];
        pendingAction = null; reset(); opened = true;
    }
    function close(): void {
        if (opened && !pendingAction) pendingAction = {kind: "workspace", number: HyprlandWindows.activeWorkspace};
        cancelDrag(); opened = false;
    }
    function toggle(): void { if (opened) close(); else open(); }
    // Unmap the keyboard layer before focusing a client/workspace. Otherwise
    // Hyprland restores the pre-overlay focus when the layer later disappears.
    function requestWorkspace(number: int): void { pendingAction = {kind: "workspace", number: number}; close(); }
    function requestFocus(address: string, number: int): void { pendingAction = {kind: "window", address: address, number: number}; close(); }
    function runPendingAction(): void {
        const action = pendingAction; pendingAction = null;
        if (!action || opened) return;
        if (action.kind === "workspace") HyprlandWindows.activateWorkspace(action.number);
        else if (action.kind === "window") HyprlandWindows.focusWindow(action.address, action.number);
        else if (action.kind === "app") DesktopEntries.byId(action.id)?.execute();
        else if (action.kind === "web") Qt.openUrlExternally(action.value);
    }
    function setQuery(text: string): void { open(); queryField.text = text; }
    function updateResults(): void {
        const query = queryField.text.trim();
        let matches = Search.applications(LauncherApps.cache, query, 5);
        const calc = Calculator.calculate(query);
        if (calc?.ok) matches.unshift({kind: "calculator", id: "calculator", title: calc.value,
                                      subtitle: query + "  ·  Enter to copy result", icon: "", value: calc.value});
        else if (calc) matches.unshift({kind: "calculator-error", id: "calculator-error", title: calc.error,
                                       subtitle: "Keep typing to complete the calculation", icon: "", value: ""});
        if (query) matches.push({kind: "web", id: "web", title: "Search Google for “" + query + "”",
                                subtitle: "Open in your default browser", icon: "", value: "https://www.google.com/search?q=" + encodeURIComponent(query)});
        results = matches; list.currentIndex = 0;
    }
    function activate(index: int): void {
        const result = results[index];
        if (!result) return;
        if (result.kind === "app") { if (!DesktopEntries.byId(result.id)) { updateResults(); return; } pendingAction = result; }
        else if (result.kind === "web") pendingAction = result;
        else if (result.kind === "calculator") Quickshell.clipboardText = result.value;
        else return;
        close();
    }
    function beginDrag(address, workspace, icon, title, position, width, height): void {
        ghost.windowAddress = address; ghost.sourceWorkspace = workspace; ghost.iconName = icon;
        ghost.width = Math.min(200, Math.max(60, width)); ghost.height = Math.min(130, Math.max(48, height));
        ghost.handedOff = false; updateDrag(position); dragAddress = address;
    }
    function updateDrag(position): void { ghost.x = position.x - ghost.width / 2; ghost.y = position.y - ghost.height / 2; }
    function finishDrag(): void { ghost.Drag.drop(); dragAddress = ""; queryField.input.forceActiveFocus(); }
    function cancelDrag(): void { if (dragAddress) ghost.Drag.cancel(); dragAddress = ""; }
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function search(text: string): void { root.setQuery(text); }
        function status(): string {
            return JSON.stringify({opened: root.opened, lastAction: root.lastAction, reveal: root.reveal, surfaceHeight: searchSurface.height, query: root.query, focused: queryField.input.activeFocus,
                selected: list.currentIndex, accent: Theme.accent.toString(), apps: LauncherApps.cache.length,
                results: root.results.map(result => ({id: result.id, kind: result.kind, title: result.title, subtitle: result.subtitle, value: result.value,
                                                    icon: result.icon, iconResolved: result.icon ? Quickshell.hasThemeIcon(result.icon) : true})),
                activeWorkspace: HyprlandWindows.activeWorkspace, geometryRefreshes: HyprlandWindows.refreshRequests, renderedCards: overview.renderedCards(),
                workspaces: [1,2,3,4,5].map(number => ({id: number, windows: HyprlandWindows.windows(number).map(window => ({
                    address: window.address, title: window.title, icon: LauncherApps.iconFor(window.lastIpcObject.class || "", window.lastIpcObject.initialClass || ""),
                    geometry: HyprlandWindows.geometry(window)}))})),
                layout: {search: {x: queryField.mapToItem(root.contentItem, 0, 0).x, y: queryField.mapToItem(root.contentItem, 0, 0).y, w: queryField.width, h: queryField.height},
                         overview: {x: overview.mapToItem(root.contentItem, 0, 0).x, y: overview.mapToItem(root.contentItem, 0, 0).y, w: overview.width, h: overview.height}}});
        }
    }
    Connections {
        target: LauncherApps
        function onCacheChanged() { root.updateResults(); }
    }
    MouseArea { anchors.fill: parent; onClicked: { root.lastAction = "outside"; root.close(); } }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0,0,0,0.16 * root.reveal) }
    Item {
        id: stack
        x: 0; y: Math.max(Theme.barHeight + 26, root.height * 0.115) + 14 * (1 - root.reveal)
        width: parent.width; height: searchSurface.height + 24 + overview.height
        opacity: root.reveal
        Rectangle {
            anchors.fill: searchSurface; anchors.margins: -10
            radius: Theme.radius + 11; color: Qt.rgba(0,0,0,0.045)
        }
        Rectangle {
            anchors.fill: searchSurface; anchors.margins: -5
            radius: Theme.radius + 6; color: Qt.rgba(0,0,0,0.07)
        }
        Rectangle {
            id: searchSurface
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(680, parent.width - 48)
            height: 80 + (root.results.length ? 12 + Math.min(6, root.results.length) * 62 : 0)
            radius: Theme.radius + 2
            color: Theme.panel
            border.width: 1
            border.color: Theme.withAlpha(Theme.accent, 0.24)
            clip: true
            Behavior on height { SmoothedAnimation { duration: Motion.resize; velocity: -1; maximumEasingTime: 160 } }
            MouseArea { anchors.fill: parent; onClicked: queryField.input.forceActiveFocus() }
            SearchField {
                id: queryField
                x: 14; y: 14; width: parent.width - 28
                onTextChanged: root.updateResults()
                onStep: direction => { if (root.results.length) list.currentIndex = (list.currentIndex + direction + root.results.length) % root.results.length; }
                onActivate: root.activate(list.currentIndex)
                onDismiss: { if (root.dragAddress) root.cancelDrag(); else root.close(); }
            }
            Results {
                id: list
                x: 14; y: 76; width: parent.width - 28; height: parent.height - y - 14
                results: root.results
                opacity: root.results.length ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.control; easing.type: Easing.OutCubic } }
                onChosen: index => root.activate(index)
            }
        }
        WorkspaceOverview {
            id: overview
            anchors.horizontalCenter: parent.horizontalCenter
            y: searchSurface.height + 24
            width: Math.min(1510, parent.width - 80)
            controller: root
        }
    }
    Item {
        id: dragCanvas
        anchors.fill: parent
        Rectangle {
            id: ghost
            property bool handedOff: false
            property string windowAddress: ""
            property int sourceWorkspace: 0
            property string iconName: ""
            visible: !handedOff && (!!root.dragAddress || opacity > 0.001)
            z: 100
            radius: 12
            color: Theme.panel
            border.width: 2; border.color: Theme.accent
            opacity: root.dragAddress ? 0.94 : 0
            scale: root.dragAddress ? 1.025 : 0.98
            Behavior on opacity { NumberAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: Motion.control; easing.type: Easing.OutQuint } }
            Drag.active: !!root.dragAddress
            Drag.source: ghost
            Drag.keys: ["vladi-hypr-window"]
            Drag.hotSpot: Qt.point(width / 2, height / 2)
            Drag.proposedAction: Qt.MoveAction
            Image {
                anchors.centerIn: parent
                width: Math.min(40, parent.height - 12); height: width
                source: ghost.iconName ? LauncherApps.iconSource(ghost.iconName) : ""
                sourceSize: Qt.size(80,80)
                fillMode: Image.PreserveAspectFit
            }
        }
    }
}
