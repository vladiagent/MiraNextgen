pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import ".."

Singleton {
    id: root
    readonly property MprisPlayer player: {
        const players = Mpris.players.values;
        const direct = players.filter(p => !p.dbusName.includes("playerctld"));
        const list = direct.length ? direct : players;
        const preferred = String(Quickshell.env("QUICKSHELL_MEDIA_PLAYER") || "");
        return (preferred ? list.find(p => p.dbusName === preferred || p.identity === preferred) : null) || list.find(p => p.isPlaying) || list.find(p => p.trackTitle) || list[0] || null;
    }
    readonly property bool available: player !== null
    readonly property string title: player?.trackTitle || player?.identity || "Nothing playing"
    readonly property string artist: player?.trackArtist || "Unknown artist"
    readonly property string displayTitle: artist + " - " + title
    readonly property string art: player?.trackArtUrl || ""
    readonly property bool playing: player?.isPlaying ?? false
    readonly property real duration: player?.lengthSupported ? Math.max(0, player.length) : 0
    readonly property bool seekable: !!player && player.canControl && player.canSeek && player.positionSupported && duration > 0

    function toggle(): void {
        if (player?.canTogglePlaying)
            player.togglePlaying();
    }
    function previous(): void {
        if (player?.canControl && player.canGoPrevious)
            player.previous();
    }
    function next(): void {
        if (player?.canControl && player.canGoNext)
            player.next();
    }
    function seek(seconds: real): void {
        if (seekable)
            player.position = Math.max(0, Math.min(duration, seconds));
    }
    function formatTime(seconds: real): string {
        const s = Math.max(0, Math.floor(Number.isFinite(seconds) ? seconds : 0));
        const h = Math.floor(s / 3600);
        const m = Math.floor(s / 60) % 60;
        return (h ? h + ":" + String(m).padStart(2, "0") : String(m)) + ":" + String(s % 60).padStart(2, "0");
    }
}
