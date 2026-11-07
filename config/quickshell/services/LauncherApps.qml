pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../launcher/Search.js" as Search

Singleton {
    id: root
    property var cache: []
    property var iconCache: ({})
    property var iconFiles: ({})
    property bool pendingIconResolve: false
    function rebuild(): void {
        cache = DesktopEntries.applications.values.filter(entry => !entry.noDisplay).map(entry => Search.metadata(entry));
        iconCache = ({});
        Qt.callLater(resolveIcons);
    }
    Component.onCompleted: rebuild()
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.rebuild(); }
    }
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.rebuild(); }
    }
    function resolveIcons(): void {
        if (iconResolver.running) { pendingIconResolve = true; return; }
        pendingIconResolve = false;
        const icons = Array.from(new Set(cache.map(app => app.icon).concat(["application-x-executable"])));
        iconResolver.exec(["python3", Quickshell.shellDir + "/scripts/resolve-launcher-icons.py", JSON.stringify(icons)]);
    }
    Process {
        id: iconResolver
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.iconFiles = JSON.parse(text); }
                catch (error) { console.warn("Launcher icon lookup:", error.message); }
            }
        }
        onExited: if (root.pendingIconResolve) Qt.callLater(root.resolveIcons)
    }
    function iconSource(icon: string): string {
        const path = iconFiles[icon] || (icon.startsWith("/") ? icon : "");
        return path ? "file://" + path.split("/").map(encodeURIComponent).join("/")
                    : Quickshell.iconPath(icon || "application-x-executable", "application-x-executable");
    }
    function iconFor(appClass: string, initialClass: string): string {
        const key = (appClass || initialClass).toLowerCase();
        if (iconCache[key] !== undefined) return iconCache[key];
        let entry = DesktopEntries.heuristicLookup(appClass) || DesktopEntries.heuristicLookup(initialClass);
        if (!entry) entry = cache.find(app => app.entry.startupClass.toLowerCase() === key)?.entry;
        const icon = entry?.icon || "application-x-executable";
        iconCache[key] = icon;
        return icon;
    }
}
