pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup(); }
    }
    id: app
    property var entries: []
    property bool browsing: false
    property string folder: ""
    property string downloads: ""
    property string parentFolder: ""
    property string message: ""
    property bool failed: false
    property string query: ""
    property var selected: null
    property string current: ""
    property string pendingAction: ""
    property bool applySucceeded: false
    property int workerExitCode: -1
    readonly property string home: Quickshell.env("HOME")
    readonly property var filtered: entries.filter(item => item.name.toLowerCase().includes(query.toLowerCase()))
    function run(action, argument) {
        if (worker.running) return;
        pendingAction = action;
        applySucceeded = false;
        workerExitCode = -1;
        failed = false;
        message = "";
        const args = ["/usr/bin/python", "-B", home + "/.config/quickshell-wallpapers/backend.py", action];
        if (argument !== undefined) args.push(argument);
        worker.command = args;
        worker.running = true;
    }
    function activate(item) {
        if (item.directory) {
            query = "";
            search.text = "";
            run("browse", item.path);
        } else {
            selected = item;
            if (!browsing) run("apply", item.path);
        }
    }
    function syncSelection() {
        const item = filtered[grid.currentIndex];
        selected = item && !item.directory ? item : null;
    }
    function confirmCurrent() {
        if (worker.running) return;
        const item = filtered[grid.currentIndex];
        if (!item) return;
        if (browsing && !item.directory) run("add", item.path);
        else activate(item);
    }
    Timer {
        id: focusTimer
        interval: 20
        onTriggered: {
            if (worker.running) { restart(); return; }
            const currentIndex = app.filtered.findIndex(item => item.path === app.current);
            grid.currentIndex = currentIndex >= 0 ? currentIndex : (app.filtered.length ? 0 : -1);
            app.syncSelection();
            grid.forceActiveFocus();
        }
    }
    Timer {
        interval: 20
        repeat: true
        running: app.applySucceeded
        onTriggered: {
            if (!worker.running && app.workerExitCode === 0) Qt.quit();
        }
    }
    Component.onCompleted: run("list")
    IpcHandler {
        target: "picker"
        function close(): void { if (!worker.running) Qt.quit(); }
        function browse(directory: string): void { app.run("browse", directory); }
        function refresh(): void { app.run("list"); }
        function status(): string { return JSON.stringify({count: app.entries.length, browsing: app.browsing, folder: app.folder, index: grid.currentIndex, gridFocused: grid.activeFocus, selected: app.selected?.path || "", error: app.failed, message: app.message}); }
    }
    Process {
        id: worker
        onExited: (exitCode, exitStatus) => { app.workerExitCode = exitCode; }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    if (!data.ok) { app.failed = true; app.message = data.error; focusTimer.restart(); return; }
                    if (app.pendingAction === "apply") { app.applySucceeded = true; return; }
                    app.entries = data.items;
                    app.browsing = data.browsing;
                    app.folder = data.folder;
                    app.downloads = data.downloads;
                    app.parentFolder = data.parent;
                    app.current = data.current;
                    app.selected = null;
                    app.query = "";
                    search.text = "";
                    app.message = data.message || "";
                    focusTimer.restart();
                } catch (e) { app.failed = true; app.message = "Could not load wallpapers: " + e; }
            }
        }
        stderr: StdioCollector {}
    }
    component Action: Rectangle {
        id: control
        property string label: ""
        property bool primary: false
        signal clicked
        activeFocusOnTab: true
        Keys.onReturnPressed: if (enabled) clicked()
        Keys.onEnterPressed: if (enabled) clicked()
        Keys.onSpacePressed: if (enabled) clicked()
        implicitWidth: textLabel.implicitWidth + 28
        implicitHeight: 38
        radius: 12
        color: primary ? Theme.accent : (area.containsMouse ? Theme.hover : "transparent")
        border.width: primary ? 0 : 1
        border.color: activeFocus ? Theme.accent : Theme.border
        opacity: enabled ? 1 : 0.4
        Text {
            id: textLabel
            anchors.centerIn: parent
            text: control.label
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: control.primary ? "#1c241e" : Theme.text
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: control.clicked() }
    }
    PanelWindow {
        id: window
        visible: true
        implicitWidth: Math.min(1000, screen.width - 64)
        implicitHeight: Math.min(700, screen.height - 100)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "miraos-wallpaper-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        mask: Region { item: surface; radius: 24 }
        Rectangle {
            id: surface
            anchors.fill: parent
            radius: 24
            color: Theme.panel
            border.width: 1
            border.color: Theme.border
            focus: true
            Component.onCompleted: forceActiveFocus()
            Keys.onEscapePressed: {
                if (worker.running) return;
                if (app.browsing) app.run("list"); else Qt.quit();
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 26
                spacing: 16
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true
                        Text { text: app.browsing ? "Add a wallpaper" : "Wallpapers"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 28; font.weight: Font.Medium }
                        Text { visible: app.browsing; text: "Choose an image to copy into your collection"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 13 }
                    }
                    Action { label: app.browsing ? "Back to collection" : "+ Add wallpaper"; enabled: !worker.running; onClicked: app.run(app.browsing ? "list" : "browse", app.downloads || app.home) }
                    Action { label: "Close"; enabled: !worker.running; onClicked: Qt.quit() }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: app.browsing
                    Action { label: "↑ Up"; enabled: !worker.running && app.folder !== app.parentFolder; onClicked: app.run("browse", app.parentFolder) }
                    Action { label: "Home"; enabled: !worker.running; onClicked: app.run("browse", app.home) }
                    Action { label: "Pictures"; enabled: !worker.running; onClicked: app.run("browse", app.home + "/Pictures") }
                    Action { label: "Downloads"; visible: app.downloads !== ""; enabled: !worker.running; onClicked: app.run("browse", app.downloads) }
                    Text { text: app.folder; Layout.fillWidth: true; elide: Text.ElideMiddle; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 12 }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 12
                    color: Theme.hover
                    TextField {
                        id: search
                        anchors.fill: parent
                        placeholderText: app.browsing ? "Filter files and folders…" : "Find a wallpaper…"
                        color: Theme.text
                        placeholderTextColor: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        leftPadding: 14
                        background: Item {}
                        onTextChanged: { app.query = text; grid.currentIndex = app.filtered.length ? 0 : -1; app.syncSelection(); }
                        Keys.onReturnPressed: app.confirmCurrent()
                        Keys.onEnterPressed: app.confirmCurrent()
                        Keys.onDownPressed: { grid.forceActiveFocus(); grid.currentIndex = 0; }
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    GridView {
                        id: grid
                        anchors.fill: parent
                        clip: true
                        cellWidth: width / Math.max(2, Math.floor(width / 220))
                        cellHeight: 185
                        model: app.filtered
                        keyNavigationEnabled: true
                        onCurrentIndexChanged: app.syncSelection()
                        enabled: !worker.running
                        ScrollBar.vertical: ScrollBar {}
                        Keys.onReturnPressed: app.confirmCurrent()
                        Keys.onEnterPressed: app.confirmCurrent()
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                                search.forceActiveFocus(); search.selectAll(); event.accepted = true;
                            }
                        }
                        delegate: Item {
                            id: tile
                            required property var modelData
                            required property int index
                            width: grid.cellWidth
                            height: grid.cellHeight
                            readonly property bool chosen: app.selected?.path === modelData.path
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 5
                                radius: 15
                                color: tile.chosen ? Theme.activeSurface : (hit.containsMouse ? Theme.hover : "transparent")
                                border.width: tile.chosen || (grid.activeFocus && grid.currentIndex === tile.index) ? 2 : 1
                                border.color: tile.chosen || (grid.activeFocus && grid.currentIndex === tile.index) ? Theme.accent : Theme.border
                                ClippingRectangle {
                                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 7 }
                                    height: 122
                                    radius: 10
                                    color: Theme.hover
                                    Image { anchors.fill: parent; source: tile.modelData.preview; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 420 }
                                    Text { visible: tile.modelData.directory; anchors.centerIn: parent; text: "▣"; color: Theme.accent; font.pixelSize: 38 }
                                    Rectangle {
                                        visible: tile.modelData.path === app.current && !app.browsing
                                        anchors { top: parent.top; right: parent.right; margins: 7 }
                                        width: 65; height: 24; radius: 8; color: Theme.accent
                                        Text { anchors.centerIn: parent; text: "Current"; color: "#1c241e"; font.family: Theme.fontFamily; font.pixelSize: 11 }
                                    }
                                }
                                Text { anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 12 } text: tile.modelData.name; elide: Text.ElideRight; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13 }
                                MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { grid.currentIndex = tile.index; app.activate(tile.modelData); } }
                            }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: app.filtered.length === 0 && !worker.running; text: app.query ? "No matches" : "No images here — add a wallpaper to get started"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 15 }
                    Rectangle { anchors.fill: parent; visible: worker.running; color: "#99282828"; radius: 12; Text { anchors.centerIn: parent; text: "Working…"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 16 } }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Text { Layout.fillWidth: true; text: app.message || (app.selected ? app.selected.name : (app.browsing ? "PNG, JPG and WebP · originals stay where they are" : app.entries.length + " wallpapers · arrows to move · Enter to apply")); color: app.failed ? "#ffb4ab" : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: 12; elide: Text.ElideRight }
                    Action { label: app.browsing ? "Add to collection" : "Apply wallpaper"; primary: true; enabled: !!app.selected && !worker.running; onClicked: app.run(app.browsing ? "add" : "apply", app.selected.path) }
                }
            }
        }
    }
}
