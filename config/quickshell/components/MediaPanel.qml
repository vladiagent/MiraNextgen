import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Wayland
import ".."
import "../services"

PanelWindow {
    id: root
    required property var barWindow
    property bool opened: false
    property real reveal: opened ? 1 : 0
    readonly property var player: MediaService.player
    readonly property real position: player?.positionSupported ? Math.max(0, player.position) : 0
    readonly property real panelHeight: Math.max(Theme.mediaPanelHeight, panelContent.implicitHeight + 36)
    signal closeRequested
    implicitWidth: Theme.mediaPanelWidth + 12
    implicitHeight: panelHeight + 12
    color: "transparent"
    screen: barWindow.screen
    anchors {
        top: true
    }
    margins.top: Theme.barHeight + 1
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.namespace: "quickshell-floating-bar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    visible: opened || reveal > 0.001
    mask: Region {
        x: surface.x
        y: surface.y
        width: surface.width
        height: surface.height
        radius: Theme.radius
    }

    Behavior on reveal {
        NumberAnimation {
            duration: Theme.normal
            easing.type: Easing.OutCubic
        }
    }
    HyprlandFocusGrab {
        active: root.opened && root.visible
        windows: [root, root.barWindow]
        onCleared: root.closeRequested()
    }
    FrameAnimation {
        running: root.opened && MediaService.playing && (root.player?.positionSupported ?? false)
        onTriggered: root.player.positionChanged()
    }
    Rectangle {
        id: surface
        anchors.horizontalCenter: parent.horizontalCenter
        y: 6 - 5 * (1 - root.reveal)
        width: Theme.mediaPanelWidth - 24 * (1 - root.reveal)
        height: 36 + (root.panelHeight - 36) * root.reveal
        radius: Theme.radius
        color: Theme.panel
        border.width: 1
        border.color: Theme.border
        opacity: root.reveal
        clip: true
        focus: root.opened
        Keys.onEscapePressed: root.closeRequested()
        onVisibleChanged: if (visible && root.opened)
            forceActiveFocus()

        IconButton {
            anchors.top: parent.top
            anchors.topMargin: 9
            anchors.right: parent.right
            anchors.rightMargin: 12
            width: 28
            height: 28
            icon: "close"
            iconSize: 14
            tooltip: "Close media panel"
            onClicked: root.closeRequested()
        }
        Column {
            id: panelContent
            x: 18
            y: 18
            width: Theme.mediaPanelWidth - 36
            spacing: 12
            opacity: root.reveal
            ClippingRectangle {
                id: cover
                anchors.horizontalCenter: parent.horizontalCenter
                width: 100
                height: 100
                radius: 12
                color: Theme.hover
                Icon {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    color: Theme.muted
                    opacity: art.status === Image.Ready ? 0 : 0.65
                }
                Image {
                    id: art
                    anchors.fill: parent
                    source: MediaService.art
                    sourceSize: Qt.size(200, 200)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.normal }
                    }
                }
            }
            Column {
                width: parent.width
                spacing: 5
                BarText {
                    width: parent.width
                    text: MediaService.title
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 15
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
                BarText {
                    width: parent.width
                    text: MediaService.artist
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.muted
                    font.pixelSize: 12
                }
                BarText {
                    width: parent.width
                    text: root.player?.identity || ""
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.muted
                    opacity: 0.65
                    font.pixelSize: 11
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    icon: "previous"
                    iconSize: 20
                    tooltip: "Previous track"
                    enabled: (root.player?.canControl && root.player.canGoPrevious) ?? false
                    onClicked: MediaService.previous()
                }
                IconButton {
                    width: 42
                    height: 42
                    filled: true
                    icon: MediaService.playing ? "pause" : "play"
                    iconSize: 21
                    tooltip: MediaService.playing ? "Pause" : "Play"
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: MediaService.toggle()
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    icon: "next"
                    iconSize: 20
                    tooltip: "Next track"
                    enabled: (root.player?.canControl && root.player.canGoNext) ?? false
                    onClicked: MediaService.next()
                }
            }
            Slider {
                id: seek
                x: 0
                width: parent.width
                height: 24
                from: 0
                to: Math.max(1, MediaService.duration)
                enabled: MediaService.seekable
                hoverEnabled: true
                live: true
                property real dragValue: 0
                property var dragPlayer: null
                property int dragTrack: -1
                Accessible.name: "Playback position"
                onPressedChanged: {
                    if (pressed) {
                        dragPlayer = root.player;
                        dragTrack = root.player?.uniqueId ?? -1;
                        dragValue = value;
                    } else if (dragPlayer === root.player && dragTrack === root.player?.uniqueId) {
                        MediaService.seek(dragValue);
                    }
                }
                onMoved: {
                    dragValue = value;
                    if (!pressed)
                        MediaService.seek(value);
                }
                Binding {
                    target: seek
                    property: "value"
                    value: Math.min(MediaService.duration, root.position)
                    when: !seek.pressed
                    restoreMode: Binding.RestoreNone
                }
                background: Rectangle {
                    x: seek.leftPadding
                    y: seek.topPadding + seek.availableHeight / 2 - height / 2
                    width: seek.availableWidth
                    height: seek.hovered || seek.pressed ? 5 : 4
                    radius: 3
                    color: Qt.rgba(0.96, 0.90, 0.78, 0.13)
                    Rectangle {
                        width: seek.visualPosition * parent.width
                        height: parent.height
                        radius: parent.radius
                        color: seek.enabled ? Theme.accent : Theme.muted
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.fast
                        }
                    }
                }
                handle: Rectangle {
                    x: seek.leftPadding + seek.visualPosition * (seek.availableWidth - width)
                    y: seek.topPadding + seek.availableHeight / 2 - height / 2
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.text
                    opacity: seek.enabled && (seek.hovered || seek.pressed || seek.activeFocus) ? 1 : 0
                    scale: seek.pressed ? 1.15 : 1
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.fast
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.fast
                        }
                    }
                }
            }
            Item {
                width: parent.width
                height: 16
                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player?.positionSupported ? MediaService.formatTime(seek.pressed ? seek.dragValue : root.position) : "--:--"
                    color: Theme.muted
                    font.pixelSize: 11
                }
                BarText {
                    anchors.centerIn: parent
                    text: !MediaService.duration ? "Live / duration unavailable" : !MediaService.seekable ? "Seeking unavailable" : ""
                    color: Theme.muted
                    font.pixelSize: 11
                    opacity: 0.65
                }
                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: MediaService.duration ? MediaService.formatTime(MediaService.duration) : "--:--"
                    color: Theme.muted
                    font.pixelSize: 11
                }
            }
        }
    }
}
