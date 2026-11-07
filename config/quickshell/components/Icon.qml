import QtQuick
import ".."

Item {
    id: root
    property string name: "music"
    property color color: Theme.text
    readonly property var paths: ({
            volume: '<path d="M4 9h4l5-4v14l-5-4H4Z"/><path d="M16 8a6 6 0 0 1 0 8M19 5a10 10 0 0 1 0 14"/>',
            volumeMuted: '<path d="M4 9h4l5-4v14l-5-4H4Z"/><path d="m17 9 5 6m0-6-5 6"/>',
            search: '<circle cx="10" cy="10" r="6.5"/><path d="m15 15 5 5"/>',
            enter: '<path d="M20 5v9H4m5-5-5 5 5 5"/>',
            globe: '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/>',
            calculator: '<rect x="5" y="2" width="14" height="20" rx="3"/><path d="M8 6h8M8 11h1m6 0h1m-8 4h1m6 0h1m-8 4h1m6 0h1"/>',
            trash: '<path d="M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7M14 10v7"/>',
            image: '<rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="8" cy="8" r="1.5"/><path d="m3 17 5-5 4 4 3-3 6 6"/>',
            copy: '<rect x="8" y="8" width="12" height="13" rx="2"/><path d="M16 8V3H3v13h5"/>',
            app: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
            clock: '<circle cx="12" cy="12" r="8"/><path d="M12 7v5l3 2"/>',
            bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-2 7-2 9h16c0-2-2-2-2-9M10 21h4M12 2v1"/>',
            bellOff: '<path d="M18 8a6 6 0 0 0-9-5M6 6v2c0 7-2 7-2 9h13M10 21h4M3 3l18 18"/>',
            wifi: '<path d="M2 8a16 16 0 0 1 20 0M5 12a11 11 0 0 1 14 0M8.5 16a5.5 5.5 0 0 1 7 0"/><circle cx="12" cy="20" r=".8"/>',
            wifiOff: '<path d="M2 8a16 16 0 0 1 2-1.4M9 4.5A16 16 0 0 1 22 8M5 12a11 11 0 0 1 3-1.7M14 10a11 11 0 0 1 5 2M8.5 16a5.5 5.5 0 0 1 7 0M3 3l18 18"/><circle cx="12" cy="20" r=".8"/>',
            bluetooth: '<path d="m7 7 10 10-5 4V3l5 4L7 17"/>',
            ethernet: '<rect x="3" y="4" width="18" height="12" rx="2"/><path d="M8 20h8M12 16v4M7 8h2M11 8h2M15 8h2M7 12h10"/>',
            sleep: '<path d="M20.5 13a8.5 8.5 0 0 1-9.5-9.5A8.5 8.5 0 1 0 20.5 13Z"/>',
            lock: '<rect x="5" y="10" width="14" height="11" rx="2.5"/><path d="M8 10V7a4 4 0 0 1 8 0v3M12 14v3"/>',
            logout: '<path d="M10 4H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h5M9 12h12m-5-5 5 5-5 5"/>',
            reboot: '<path d="M20 7v5h-5M20 12a8 8 0 1 0-2 5"/>',
            power: '<path d="M12 2v9M6 5a9 9 0 1 0 12 0"/>',
            play: '<path d="m9 5 11 7-11 7Z" fill="currentColor" stroke="none"/>',
            pause: '<path d="M8 5v14M16 5v14" stroke-width="3.5"/>',
            previous: '<path d="M5 5v14M18 5 7 12l11 7Z"/>',
            next: '<path d="M19 5v14M6 5l11 7-11 7Z"/>',
            close: '<path d="m6 6 12 12M6 18 18 6"/>',
            music: '<path d="M9 18V5l12-2v13M9 9l12-2"/><ellipse cx="6" cy="18" rx="3" ry="3"/><ellipse cx="18" cy="16" rx="3" ry="3"/>',
            chevron: '<path d="m7 10 5 5 5-5"/>'
        })
    implicitWidth: 16
    implicitHeight: 16
    Image {
        anchors.fill: parent
        sourceSize.width: Math.ceil(width * 2)
        sourceSize.height: Math.ceil(height * 2)
        source: "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" color="' + root.color + '" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">' + (root.paths[root.name] || root.paths.music) + '</svg>')
        smooth: true
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.fast
        }
    }
}
