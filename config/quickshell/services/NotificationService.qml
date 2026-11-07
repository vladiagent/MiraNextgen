pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../notifications"

Singleton {
    id: root
    readonly property bool available: true
    property alias dnd: state.dnd
    property bool blocked: false
    property bool panelVisible: false
    property var panelWindow: null
    property var pendingAction: null
    property ShellScreen panelScreen: Quickshell.screens[0] ?? null
    property var entries: []
    readonly property var history: entries.filter(entry => !entry.notification.transient)
    readonly property int count: history.length
    readonly property var groupedHistory: {
        const groups = new Map();
        for (const entry of history) {
            if (!groups.has(entry.group)) groups.set(entry.group,[]);
            groups.get(entry.group).push(entry);
        }
        return Array.from(groups.values()).reduce((all,group)=>all.concat(group),[]);
    }
    readonly property date now: clock.date
    PersistentProperties {
        id: state
        reloadableId: "vladi-notifications-state"
        property bool dnd: false
        property var received: ({})
    }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Component { id: entryComponent; NotificationEntry {} }
    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true
        onNotification: notification => {
            notification.tracked = true;
            const monitor = Hyprland.focusedMonitor?.name || Quickshell.screens[0]?.name || "";
            const received = state.received[notification.id] || Date.now();
            state.received[notification.id] = received;
            const entry = entryComponent.createObject(root,{notification:notification,owner:root,monitorName:monitor,received:received});
            if (!entry) { notification.dismiss(); return; }
            root.entries = [entry].concat(root.entries);
            entry.popup = !notification.lastGeneration && !root.blocked && !root.panelVisible && (!root.dnd || entry.critical);
            if (notification.transient && !entry.popup) root.dismiss(entry,false);
            while (root.entries.length>100) root.dismiss(root.entries[root.entries.length-1],false);
        }
    }
    function popupsFor(name: string, limit: int): var {
        if (blocked) return [];
        return entries.filter(entry => entry.popup &&
            (Quickshell.screens.some(screen => screen.name===entry.monitorName) ? entry.monitorName : Quickshell.screens[0]?.name)===name).slice(0,limit);
    }
    function dismiss(entry, user: bool): void {
        if (!entries.includes(entry)) return;
        entries = entries.filter(item => item !== entry);
        delete state.received[entry.noticeId];
        entry.popup = false;
        if (entry.notification.tracked) {
            if (user) entry.notification.dismiss(); else entry.notification.expire();
        }
        entry.destroy(380);
    }
    function invokeAction(action): void {
        if (panelVisible) { pendingAction = action; closePanel(); }
        else if (action) action.invoke();
    }
    function finishAction(): void { const action = pendingAction; pendingAction = null; if (action) action.invoke(); }
    function clearAll(): void { for (const entry of entries.slice()) dismiss(entry,true); }
    function toggleDnd(): void { state.dnd = !state.dnd; }
    function closePanel(): void { panelVisible = false; }
    function togglePanel(screen, window): void {
        if (blocked) return;
        if (panelVisible) closePanel();
        else {
            panelScreen = screen || Quickshell.screens.find(item => item.name===Hyprland.focusedMonitor?.name) || Quickshell.screens[0];
            panelWindow = window || null;
            panelVisible = true;
        }
    }
    function iconSource(icon: string): string {
        if (!icon) return "";
        if (icon.startsWith("/")) return "file://" + icon.split("/").map(encodeURIComponent).join("/");
        if (/^(file|image|data):/.test(icon)) return icon;
        return LauncherApps.iconSource(icon);
    }
    function imageSource(source: string): string { return /^(file|image|data):/.test(source) || source.startsWith("/") ? iconSource(source) : ""; }
    function plainBody(body: string): string {
        return body.slice(0,6000).replace(/<br\s*\/?\s*>/gi,"\n").replace(/<\/?[a-zA-Z][^>]*>/g,"")
            .replace(/&lt;/g,"<").replace(/&gt;/g,">").replace(/&quot;/g,'"').replace(/&apos;/g,"'").replace(/&amp;/g,"&");
    }
    function timeLabel(time: double): string {
        const age = Math.max(0,now.getTime()-time);
        if (age<60000) return "Now";
        if (age<3600000) return Math.floor(age/60000)+"m";
        return Qt.formatDateTime(new Date(time),age<86400000?"HH:mm":"ddd HH:mm");
    }
    onDndChanged: if (dnd) for (const entry of entries.slice()) if (!entry.critical) entry.hidePopup();
    onBlockedChanged: if (blocked) { closePanel(); for (const entry of entries.slice()) entry.hidePopup(); }
    onPanelVisibleChanged: if (panelVisible) for (const entry of entries.slice()) entry.hidePopup();
    IpcHandler {
        target: "notifications"
        function toggle(): void { root.togglePanel(null); }
        function open(): void { if (!root.panelVisible) root.togglePanel(null); }
        function close(): void { root.closePanel(); }
        function dnd(enabled: bool): void { root.dnd = enabled; }
        function status(): string {
            return JSON.stringify({count:root.count,dnd:root.dnd,visible:root.panelVisible,blocked:root.blocked,
                screen:root.panelScreen?.name || "",popups:root.entries.filter(entry=>entry.popup).length,
                monitors:Quickshell.screens.map(screen=>({name:screen.name,popups:root.popupsFor(screen.name,3).length}))});
        }
    }
}
