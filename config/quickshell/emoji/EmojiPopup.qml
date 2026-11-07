pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../components"
import "../launcher"
import "../services"

PanelWindow {
    id: root
    property bool blocked: false
    property bool opened: false
    property bool loadedOnce: false
    property bool motionReady: false
    property real reveal: opened && motionReady ? 1 : 0
    property ShellScreen targetScreen: Quickshell.screens[0] ?? null
    property string category: "Faces"
    property var entries: []
    property var entriesById: ({})
    property var recents: []
    property bool catalogError: false
    readonly property string dataDirectory: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/miraos/emoji"
    readonly property var categories: ["Recent", "Faces", "People", "Nature", "Food", "Travel", "Activities", "Objects", "Symbols", "Flags"]
    readonly property string query: search.text.trim().toLowerCase()
    readonly property var results: {
        if (query) {
            const words = query.split(/\s+/);
            const direct = [];
            const related = [];
            for (const entry of entries) {
                const name = entry.name.toLowerCase().replace(/[:,-]+/g, " ").replace(/\s+/g, " ");
                if (entry.emoji === query || name.includes(query))
                    direct.push(entry);
                else if (words.every(word => entry.keywords.includes(word)))
                    related.push(entry);
            }
            return direct.concat(related);
        }
        if (category === "Recent")
            return recents.map(id => entriesById[id]).filter(entry => entry !== undefined);
        return entries.filter(entry => entry.category === category);
    }
    readonly property var selected: results[grid.currentIndex] ?? null
    readonly property int columns: Math.max(1, Math.floor(grid.width / 54))

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: !blocked && (opened || reveal > 0.001)
    color: "transparent"
    WlrLayershell.namespace: "miraos-emoji"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    FrameAnimation {
        running: root.opened && !root.motionReady
        onTriggered: root.motionReady = true
    }
    Behavior on reveal {
        NumberAnimation {
            duration: root.opened ? Motion.enter : Motion.exit
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.opened ? Motion.settle : Motion.dismiss
        }
    }
    onVisibleChanged: if (!visible) motionReady = false
    onBlockedChanged: if (blocked) close()
    onResultsChanged: Qt.callLater(resetSelection)

    FileView {
        preload: true
        blockLoading: false
        path: root.loadedOnce ? root.dataDirectory + "/catalog.json" : ""
        onLoaded: {
            try {
                const entries = JSON.parse(text());
                const lookup = {};
                for (const entry of entries)
                    lookup[entry.id] = entry;
                root.entriesById = lookup;
                root.entries = entries;
            } catch (_) {
                root.catalogError = true;
            }
        }
        onLoadFailed: if (root.loadedOnce) root.catalogError = true
    }
    FileView {
        id: recentFile
        preload: true
        blockLoading: false
        printErrors: false
        path: root.loadedOnce ? (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/miraos-emoji-recent.json" : ""
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                if (Array.isArray(saved))
                    root.recents = saved.filter(id => typeof id === "string").slice(0, 36);
            } catch (_) {}
        }
    }

    function open(): void {
        if (blocked)
            return;
        if (!opened) {
            targetScreen = Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0];
            NotificationService.closePanel();
            search.text = "";
            category = recents.length ? "Recent" : "Faces";
            loadedOnce = true;
            opened = true;
        }
        search.input.forceActiveFocus();
        Qt.callLater(() => search.input.forceActiveFocus());
    }
    function close(): void { opened = false; }
    function resetSelection(): void {
        grid.currentIndex = results.length ? 0 : -1;
        grid.positionViewAtBeginning();
    }
    function moveSelection(delta: int): void {
        if (!results.length)
            return;
        grid.currentIndex = Math.max(0, Math.min(results.length - 1, grid.currentIndex + delta));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
    }
    function choose(entry): void {
        if (!entry || !opened)
            return;
        Quickshell.clipboardText = entry.emoji;
        recents = [entry.id].concat(recents.filter(id => id !== entry.id)).slice(0, 36);
        recentFile.setText(JSON.stringify(recents) + "\n");
        close();
    }

    IpcHandler {
        target: "emoji"
        function toggle(): void { if (root.opened) root.close(); else root.open(); }
        function close(): void { root.close(); }
        function status(): string {
            return JSON.stringify({ opened: root.opened, focused: search.input.activeFocus,
                count: root.entries.length, results: root.results.length, selected: root.selected?.name || "",
                accent: Theme.accent.toString() });
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.close() }
    Rectangle {
        id: card
        width: Math.min(560, parent.width - 32)
        height: Math.min(492, parent.height - y - 20)
        x: (parent.width - width) / 2
        y: Math.max(Theme.barHeight + 28, Math.round(parent.height * 0.14)) + 10 * (1 - root.reveal)
        radius: Theme.radius
        color: Theme.panel
        border.width: 1
        border.color: Theme.withAlpha(Theme.accent, 0.24)
        opacity: root.reveal
        clip: true
        enabled: root.opened
        MouseArea { anchors.fill: parent; onClicked: search.input.forceActiveFocus() }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                BarText { text: "Emoji"; font.pixelSize: 20; Layout.fillWidth: true }
                IconButton {
                    width: 30; height: 30
                    icon: "close"
                    tooltip: "Close emoji picker"
                    onClicked: root.close()
                }
            }
            SearchField {
                id: search
                Layout.fillWidth: true
                placeholderText: "Search emoji"
                accessibleName: "Search emoji"
                horizontalNavigation: true
                onHorizontalStep: direction => root.moveSelection(direction)
                onStep: direction => root.moveSelection(direction * root.columns)
                onActivate: root.choose(root.selected)
                onDismiss: root.close()
            }
            Flow {
                Layout.fillWidth: true
                spacing: 5
                Repeater {
                    model: root.categories
                    MenuButton {
                        required property string modelData
                        text: modelData
                        primary: !root.query && root.category === modelData
                        onClicked: {
                            search.text = "";
                            root.category = modelData;
                            search.input.forceActiveFocus();
                        }
                    }
                }
            }
            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
                GridView {
                    id: grid
                    anchors.fill: parent
                    anchors.rightMargin: 6
                    cellWidth: width / root.columns
                    cellHeight: 51
                    clip: true
                    keyNavigationEnabled: false
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.results
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: Button {
                        id: tile
                        required property int index
                        required property var modelData
                        width: grid.cellWidth - 4
                        height: grid.cellHeight - 4
                        padding: 0
                        hoverEnabled: true
                        focusPolicy: Qt.NoFocus
                        Accessible.name: modelData.name
                        onClicked: root.choose(modelData)
                        background: Rectangle {
                            radius: 12
                            color: tile.down || grid.currentIndex === tile.index ? Theme.activeSurface : tile.hovered ? Theme.hover : "transparent"
                            border.width: grid.currentIndex === tile.index ? 1 : 0
                            border.color: Theme.withAlpha(Theme.accent, 0.35)
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                        }
                        contentItem: Item {
                            Image {
                                anchors.centerIn: parent
                                width: 30; height: 30
                                source: "file://" + root.dataDirectory + "/svg/" + tile.modelData.id + ".svg"
                                sourceSize: Qt.size(60, 60)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        ToolTip.text: modelData.name
                    }
                }
                BarText {
                    anchors.centerIn: parent
                    visible: grid.count === 0
                    color: Theme.muted
                    text: root.catalogError ? "Emoji artwork unavailable" : !root.entries.length ? "Loading emoji…" :
                          root.query ? "No matching emoji" : "Your recent emoji will appear here"
                }
            }
            RowLayout {
                Layout.fillWidth: true
                BarText {
                    Layout.fillWidth: true
                    text: root.selected?.name || ""
                    color: Theme.muted
                    font.pixelSize: 12
                }
                BarText { text: "Twemoji · CC BY 4.0"; color: Theme.muted; font.pixelSize: 11 }
            }
        }
    }
}
