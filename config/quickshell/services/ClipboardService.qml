pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool available: false
    property bool opened: false
    property bool loading: false
    property bool busy: false
    property var entries: []
    property var thumbnails: ({})
    property var requestedThumbnails: ({})
    property string message: ""
    signal copied()
    function send(message): void { if (backend.running) backend.write(JSON.stringify(message) + "\n"); }
    function open(): void { opened = true; loading = true; message = ""; send({command:"open"}); }
    function close(): void {
        opened = false; entries = []; thumbnails = ({}); requestedThumbnails = ({});
        loading = false; busy = false; send({command:"close"});
    }
    function copy(id: string): void { if (busy) return; busy = true; message = ""; send({command:"copy",id:id}); }
    function remove(id: string): void { send({command:"delete",id:id}); }
    function clear(): void { send({command:"clear"}); }
    function thumbnail(id: string): void {
        if (requestedThumbnails[id] || !opened) return;
        requestedThumbnails[id] = true; send({command:"thumbnail",id:id});
    }
    Process {
        id: backend
        command: ["python", "-B", Qt.resolvedUrl("../scripts/clipboard-history.py").toString().replace(/^file:\/\//, "")]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    if (event.event === "ready") { root.available = event.available; if (root.opened) root.open(); }
                    else if (event.event === "entries" && root.opened) { root.entries = event.entries; root.loading = false; root.busy = false; }
                    else if (event.event === "copied") { root.busy = false; root.copied(); }
                    else if (event.event === "thumbnail" && root.opened) root.thumbnails = Object.assign({},root.thumbnails,{[event.id]:event.source});
                    else if (event.event === "unavailable") root.available = false;
                    else if (event.event === "error") { root.message = event.message; root.loading = false; root.busy = false; }
                } catch (_) {}
            }
        }
        onExited: { root.available = false; root.loading = false; root.busy = false; root.message = "Clipboard history is unavailable."; }
    }
}
