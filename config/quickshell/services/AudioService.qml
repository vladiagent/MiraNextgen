pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: !!sink?.ready && !!sink?.audio
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int percent: Math.round(volume * 100)
    property int observedSink: -1
    property real observedVolume: -1
    property bool observedMuted: false
    signal outputChanged
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }
    onSinkChanged: observe()
    onAvailableChanged: observe()
    onVolumeChanged: observe()
    onMutedChanged: observe()
    function observe(): void {
        if (!available) return;
        if (observedSink !== sink.id) {
            observedSink = sink.id; observedVolume = volume; observedMuted = muted;
            return;
        }
        if (Math.abs(volume - observedVolume) > 0.00001 || muted !== observedMuted) {
            observedVolume = volume; observedMuted = muted; outputChanged();
        }
    }
    function setVolume(value: real): void {
        if (!available) return;
        sink.audio.volume = Math.max(0, Math.min(1, value));
        if (muted && value > 0) sink.audio.muted = false;
    }
    function toggleMute(): void { if (available) sink.audio.muted = !muted; }
}
