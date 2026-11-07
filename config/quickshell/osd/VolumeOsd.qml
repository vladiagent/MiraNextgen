import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../services"
import "../components"

PanelWindow {
    id: root
    property bool opened: false
    property bool motionReady: false
    property real reveal: opened && motionReady ? 1 : 0
    FrameAnimation {
        running: root.opened && !root.motionReady
        onTriggered: root.motionReady = true
    }
    property ShellScreen targetScreen: Quickshell.screens[0] ?? null
    readonly property bool interacting: hover.hovered || slider.pressed
    screen: targetScreen
    anchors.bottom: true
    margins.bottom: 52
    implicitWidth: 374
    implicitHeight: 86
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: AudioService.available && (opened || reveal > 0.001)
    WlrLayershell.namespace: "vladi-volume"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: surface; radius: Theme.radius }
    Behavior on reveal {
        NumberAnimation {
            duration: root.opened ? Motion.enter : Motion.exit
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.opened ? Motion.settle : Motion.dismiss
        }
    }
    onVisibleChanged: if (!visible) motionReady = false
    onInteractingChanged: { if (interacting) hideTimer.stop(); else if (opened) hideTimer.restart(); }
    function show(): void {
        targetScreen = Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0];
        opened = true;
        if (!interacting) hideTimer.restart();
    }
    Connections { target: AudioService; function onOutputChanged() { root.show(); } }
    Timer { id: hideTimer; interval: 1800; onTriggered: { if (!root.interacting) root.opened = false; } }
    IpcHandler {
        target: "volume"
        function display(): void { root.show(); }
        function status(): string {
            return JSON.stringify({opened: root.opened, reveal: root.reveal, available: AudioService.available,
                percent: AudioService.percent, volume: AudioService.volume, muted: AudioService.muted,
                interacting: root.interacting, sink: AudioService.sink?.description || "",
                slider: {x: slider.x + surface.x, y: slider.y + surface.y, w: slider.width, h: slider.height}});
        }
    }
    Rectangle {
        id: surface
        x: 7; y: 7 + 10 * (1 - root.reveal)
        width: 360; height: 66
        radius: Theme.radius
        color: Theme.panel
        border.width: 1; border.color: Theme.withAlpha(Theme.text, 0.14)
        opacity: root.reveal
        HoverHandler { id: hover }
        WheelHandler {
            onWheel: event => { AudioService.setVolume(AudioService.volume + (event.angleDelta.y > 0 ? 0.02 : -0.02)); event.accepted = true; }
        }
        IconButton {
            x: 13; y: 16; width: 34; height: 34
            icon: AudioService.muted || AudioService.percent === 0 ? "volumeMuted" : "volume"
            iconSize: 21
            tooltip: AudioService.muted ? "Unmute" : "Mute"
            onClicked: AudioService.toggleMute()
        }
        Slider {
            id: slider
            x: 60; y: 17; width: 230; height: 32
            from: 0; to: 1; stepSize: 0.02
            enabled: AudioService.available
            onMoved: AudioService.setVolume(value)
            Behavior on value {
                enabled: !slider.pressed
                SmoothedAnimation { duration: Motion.control; velocity: -1; maximumEasingTime: 120 }
            }
            Binding { target: slider; property: "value"; value: Math.min(1, AudioService.volume); when: !slider.pressed; restoreMode: Binding.RestoreBindingOrValue }
            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth; height: 5; radius: height / 2
                color: Theme.withAlpha(Theme.text, 0.18)
                Rectangle {
                    width: slider.visualPosition * parent.width; height: parent.height; radius: parent.radius
                    color: AudioService.muted ? Theme.muted : Theme.accent
                    Behavior on color { ColorAnimation { duration: Motion.control } }
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 16; height: 16; radius: 8
                color: Theme.accent
                border.width: 3; border.color: Theme.panel
                scale: slider.pressed ? 1.12 : slider.hovered ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: Motion.hover; easing.type: Easing.OutQuint } }
            }
            Accessible.name: "System volume"
        }
        BarText {
            x: 300; width: 44
            anchors.verticalCenter: parent.verticalCenter
            text: AudioService.percent
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 14
        }
    }
}
