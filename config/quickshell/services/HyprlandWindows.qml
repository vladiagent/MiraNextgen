pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root
    property bool overviewVisible: false
    property int revision: 0
    property int refreshRequests: 0
    readonly property int activeWorkspace: Hyprland.focusedWorkspace?.id ?? 1
    function refresh(): void { refreshRequests++; Hyprland.refreshToplevels(); }
    function schedule(): void { Qt.callLater(root.refresh); }
    onOverviewVisibleChanged: if (overviewVisible) refresh()
    Timer {
        // Hyprland 0.57 does not send pixel-geometry events for every resize.
        // Reconcile only while visible; normal workspace/window events stay live.
        interval: 750
        running: root.overviewVisible
        repeat: true
        onTriggered: root.refresh()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (/^(openwindow|closewindow|movewindow|activewindow|workspace|focusedmon|changefloatingmode|fullscreen|monitor|configreloaded|pin)/.test(event.name)) root.schedule();
        }
    }
    Instantiator {
        model: Hyprland.toplevels
        delegate: Connections {
            required property var modelData
            target: modelData
            function onLastIpcObjectChanged() { root.revision++; }
            function onWorkspaceChanged() { root.revision++; }
        }
        onObjectAdded: root.revision++
        onObjectRemoved: root.revision++
    }
    function windows(number: int): var {
        const dependency = revision;
        return Hyprland.toplevels.values.filter(window => window?.workspace?.id === number && window.lastIpcObject.mapped !== false && !window.lastIpcObject.hidden)
            .slice().sort((a,b) => Number(!!a.lastIpcObject.floating) - Number(!!b.lastIpcObject.floating));
    }
    function geometry(window): var {
        if (!window) return {x: 0, y: 0, w: 0, h: 0};
        const data = window.lastIpcObject;
        const monitor = window.monitor || Hyprland.focusedMonitor;
        const info = monitor?.lastIpcObject || {};
        let width = (info.width || 1920) / (info.scale || 1), height = (info.height || 1080) / (info.scale || 1);
        if ([1,3,5,7].includes(info.transform || 0)) { const swap = width; width = height; height = swap; }
        const at = data.at || [info.x || 0, info.y || 0], size = data.size || [width, height];
        return { x: Math.max(0, Math.min(1, (at[0] - (info.x || 0)) / width)),
                 y: Math.max(0, Math.min(1, (at[1] - (info.y || 0)) / height)),
                 w: Math.max(0.001, Math.min(1, size[0] / width)), h: Math.max(0.001, Math.min(1, size[1] / height)) };
    }
    function activateWorkspace(number: int): void {
        if (number < 1 || number > 5) return;
        Hyprland.dispatch("hl.dsp.focus({workspace=" + number + "})");
    }
    function focusWindow(address: string, number: int): void {
        if (!/^(?:0x)?[0-9a-f]+$/i.test(address)) return;
        activateWorkspace(number);
        Hyprland.dispatch("hl.dsp.focus({window=" + JSON.stringify("address:0x" + address.replace(/^0x/, "")) + "})");
    }
    function moveWindow(address: string, number: int): void {
        if (!/^(?:0x)?[0-9a-f]+$/i.test(address) || number < 1 || number > 5) return;
        Hyprland.dispatch("hl.dsp.window.move({window=" + JSON.stringify("address:0x" + address.replace(/^0x/, "")) + ",workspace=" + number + ",follow=false})");
        schedule();
    }
    function windowByAddress(address: string): var {
        const key = address.replace(/^0x/, "").toLowerCase();
        return Hyprland.toplevels.values.find(window => window.address.replace(/^0x/, "").toLowerCase() === key) || null;
    }
    function selector(address: string): string {
        return "address:0x" + address.replace(/^0x/, "");
    }
    function swapWindows(address: string, targetAddress: string): void {
        const source = windowByAddress(address), target = windowByAddress(targetAddress);
        if (!source || !target || source === target || source.workspace?.id !== target.workspace?.id
                || source.lastIpcObject.floating || target.lastIpcObject.floating) return;
        // Swap and restore the pointer in one compositor dispatch. The swap's
        // keyboard-oriented cursor warp must never interrupt an overview drag.
        Hyprland.dispatch("function() local p = hl.get_cursor_pos(); "
                          + "local result = hl.dispatch(hl.dsp.window.swap({window=" + JSON.stringify(selector(source.address))
                          + ",target=" + JSON.stringify(selector(target.address)) + "})); "
                          + "if p then hl.dispatch(hl.dsp.cursor.move({x=p.x,y=p.y})) end; return result end");
        schedule();
    }
    function floatingPosition(window, x: real, y: real): var {
        const info = (window.monitor || Hyprland.focusedMonitor)?.lastIpcObject || {};
        let width = (info.width || 1920) / (info.scale || 1), height = (info.height || 1080) / (info.scale || 1);
        if ([1,3,5,7].includes(info.transform || 0)) { const swap = width; width = height; height = swap; }
        const size = window.lastIpcObject.size || [width / 2, height / 2];
        const reserved = info.reserved || [0,0,0,0];
        const left = Math.max(reserved[0], Math.min(width - reserved[2] - size[0], x * width - size[0] / 2));
        const top = Math.max(reserved[1], Math.min(height - reserved[3] - size[1], y * height - size[1] / 2));
        return {x: Math.round((info.x || 0) + left), y: Math.round((info.y || 0) + top)};
    }
    function moveFloating(address: string, x: real, y: real): void {
        const source = windowByAddress(address);
        if (!source || !source.lastIpcObject.floating || !Number.isFinite(x) || !Number.isFinite(y)) return;
        const position = floatingPosition(source, Math.max(0, Math.min(1, x)), Math.max(0, Math.min(1, y)));
        Hyprland.dispatch("hl.dsp.window.move({window=" + JSON.stringify(selector(source.address))
                          + ",x=" + position.x + ",y=" + position.y + ",relative=false})");
        schedule();
    }
}
