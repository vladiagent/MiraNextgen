pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam
import ".."

Scope {
    id: root
    reloadableId: "vladi-lock-controller"
    property bool preparing: false
    property var screenHosts: ({})
    property var snapshots: []
    readonly property bool locked: state.requested
    readonly property bool secure: sessionLock.secure
    property bool busy: false
    property string message: ""
    property var pendingField: null
    property var surfaces: []
    property var identity: ({account: Quickshell.env("USER"), name: Quickshell.env("USER"), avatar: "", host: ""})
    property string keyboardLayout: "US"
    property bool capsLock: false
    property var capabilities: ({})
    readonly property string authenticationScreen: Quickshell.screens.some(s => s.name === state.authenticationScreen)
        ? state.authenticationScreen : (Quickshell.screens[0]?.name || "")
    signal clearInputs()
    signal failed()
    signal focusPassword()

    PersistentProperties {
        id: state
        reloadableId: "vladi-lock-state"
        property bool requested: false
        property string authenticationScreen: ""
        property bool previousWatchFiles: true
    }
    WlSessionLock {
        id: sessionLock
        reloadableId: "vladi-secure-session-lock"
        locked: state.requested
        onSecureStateChanged: root.send({command: "locked", secure: secure})
        WlSessionLockSurface {
            id: surface
            color: "#282828"
            Component.onCompleted: root.surfaces = root.surfaces.concat([surface])
            Component.onDestruction: root.surfaces = root.surfaces.filter(item => item !== surface)
            Loader {
                objectName: "vladi-lock-visual"
                anchors.fill: parent
                sourceComponent: LockView {
                    controller: root
                    screenName: surface.screen?.name || ""
                }
            }
        }
    }
    function registerHost(name, item): void { screenHosts[name] = item; }
    function unregisterHost(name, item): void {
        if (screenHosts[name] === item) delete screenHosts[name];
        snapshots = snapshots.filter(shot => shot && shot.monitorName !== name);
    }
    function snapshotFor(name): var { return snapshots.find(item => item && item.monitorName === name && item.hasContent) || null; }
    function clearSnapshots(): void {
        const old = snapshots; snapshots = [];
        for (const item of old) { item.captureSource = null; item.parent = null; item.destroy(); }
    }
    Component {
        id: capture
        ScreencopyView {
            id: shot
            Component.onDestruction: if (root) root.snapshots = root.snapshots.filter(item => item !== shot)
            required property string monitorName
            property bool unavailable: false
            live: false
            paintCursor: false
            visible: false
            onHasContentChanged: if (hasContent) root.tryLock()
            onStopped: { unavailable = true; root.tryLock(); }
        }
    }
    Timer {
        id: captureDeadline
        interval: 350
        onTriggered: root.acquireLock()
    }
    function engage(): void {
        if (state.requested || preparing) { focusPassword(); return; }
        state.previousWatchFiles = Quickshell.watchFiles;
        Quickshell.watchFiles = false;
        state.authenticationScreen = Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || "";
        message = ""; clearInputs(); clearSnapshots(); preparing = true;
        for (const screen of Quickshell.screens) {
            const host = screenHosts[screen.name];
            if (host) {
                const item = capture.createObject(host, {monitorName:screen.name, captureSource:screen});
                if (item) snapshots = snapshots.concat([item]);
            }
        }
        captureDeadline.start();
        tryLock();
        keyboard.exec(["hyprctl", "-j", "devices"]);
    }
    function tryLock(): void {
        if (preparing && snapshots.every(item => item.hasContent || item.unavailable)) acquireLock();
    }
    function acquireLock(): void {
        if (!preparing) return;
        captureDeadline.stop(); preparing = false; state.requested = true;
        Qt.callLater(() => {
            if (!sessionLock.locked) {
                state.requested = false;
                clearSnapshots(); Quickshell.watchFiles = state.previousWatchFiles;
                message = "The compositor could not acquire the session lock.";
            }
        });
    }
    function activateScreen(name: string): void {
        if (name === authenticationScreen) return;
        clearInputs(); state.authenticationScreen = name; focusPassword();
    }
    function submit(field): void {
        if (!secure || busy || !field || !field.text) return;
        message = ""; busy = true;
        if (auth.active && auth.responseRequired) {
            if (auth.responseVisible) { field.clear(); auth.abort(); busy = false; message = "Unsupported authentication prompt."; return; }
            auth.respond(field.text); field.clear();
        } else {
            pendingField = field;
            if (!auth.start()) { pendingField = null; busy = false; field.clear(); message = "Authentication is unavailable. Try again."; }
        }
    }
    function cancelEntry(): void {
        auth.abort(); pendingField = null; busy = false; clearInputs(); message = ""; focusPassword();
    }
    PamContext {
        id: auth
        config: "system-auth"
        configDirectory: "/etc/pam.d"
        // An unset user authenticates the process's real Unix UID, not an env var.
        onPamMessage: {
            if (!responseRequired) return;
            if (responseVisible) {
                root.pendingField = null; root.busy = false; root.clearInputs(); abort();
                root.message = "Unsupported authentication prompt."; return;
            }
            if (root.pendingField) {
                respond(root.pendingField.text); root.pendingField.clear(); root.pendingField = null;
            } else { root.busy = false; root.focusPassword(); }
        }
        onCompleted: result => {
            root.pendingField = null; root.busy = false; root.clearInputs();
            if (result === PamResult.Success && sessionLock.secure && state.requested) {
                state.requested = false;
                root.clearSnapshots();
                Quickshell.watchFiles = state.previousWatchFiles;
                root.message = "";
                root.send({command: "locked", secure: false});
            } else {
                root.message = result === PamResult.Error ? "Authentication is unavailable. Try again." : "Incorrect password. Try again.";
                root.failed(); root.focusPassword();
            }
        }
    }
    function send(message): void { if (bridge.running) bridge.write(JSON.stringify(message) + "\n"); }
    function handleAction(action: string): void {
        if (action === "lock") engage();
        else if (action === "logout") Hyprland.dispatch("hl.dsp.exit()");
        else power(action);
    }
    function power(action: string): void { if (["suspend", "reboot", "shutdown"].includes(action)) send({command: "power", action: action}); }
    Process {
        id: bridge
        command: ["python", "-B", Qt.resolvedUrl("../scripts/lock-session-bridge.py").toString().replace(/^file:\/\//, "")].concat(Quickshell.env("VLADI_LOCK_ISOLATED_TEST") === "1" ? ["--no-session-controls"] : [])
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    if (event.event === "identity") root.identity = event;
                    else if (event.event === "lock") root.engage();
                    else if (event.event === "capabilities") root.capabilities = event.actions;
                    else if (event.event === "ready") root.send({command: "locked", secure: sessionLock.secure});
                    else if (event.event === "error") root.message = event.message;
                } catch (_) { console.warn("Invalid lock-session service message"); }
            }
        }
        onExited: { if (state.requested) root.message = "Session controls unavailable. Password unlocking remains available."; }
    }
    Process {
        id: keyboard
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devices = JSON.parse(text).keyboards || [];
                    const current = devices.find(k => k.main) || devices[0];
                    root.keyboardLayout = (current?.layout?.split(",")[current?.active_layout_index || 0] || "us").toUpperCase();
                    root.capsLock = !!current?.capsLock;
                } catch (_) {}
            }
        }
    }
    IpcHandler {
        target: "lock"
        function engage(): void { root.engage(); }
        function suspend(): void { root.power("suspend"); }
        function status(): string { return JSON.stringify({locked: root.locked, secure: root.secure, requested: state.requested, screens: Quickshell.screens.map(s => s.name), authenticationScreen: root.authenticationScreen, capabilities: root.capabilities, preparing: root.preparing, captureHosts: Object.keys(root.screenHosts), surfaces: root.surfaces.map(s => ({screen:s.screen?.name || "",width:s.width,height:s.height}))}); }
    }
}
