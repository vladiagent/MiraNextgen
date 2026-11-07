import QtQuick
import Quickshell

Scope {
    id: root
    required property var notification
    required property var owner
    required property string monitorName
    property double received: Date.now()
    property bool popup: false
    property bool showing: false
    property bool paused: false
    property real remaining: notification.expireTimeout > 0 ? notification.expireTimeout : 6000
    property double started: 0
    readonly property bool critical: notification.urgency === 2
    readonly property bool persistentPopup: critical || notification.expireTimeout === 0
    readonly property string appName: notification.appName
    readonly property string group: notification.desktopEntry || notification.appName || String(notification.id)
    readonly property int noticeId: notification.id
    RetainableLock { object: root.notification; locked: true }
    Timer { id: expiry; onTriggered: root.hidePopup() }
    function pauseClock(): void {
        if (expiry.running) remaining = Math.max(1,remaining-(Date.now()-started));
        expiry.stop();
    }
    function arm(): void {
        pauseClock();
        if (popup && showing && !paused && !persistentPopup && !owner.blocked) {
            expiry.interval = Math.max(1,remaining); started = Date.now(); expiry.start();
        }
    }
    function hidePopup(): void {
        pauseClock(); popup = false;
        if (notification.transient) owner.dismiss(root, false);
    }
    function updated(): void {
        remaining = notification.expireTimeout > 0 ? notification.expireTimeout : 6000;
        popup = !owner.blocked && !owner.panelVisible && (!owner.dnd || critical);
        arm();
    }
    onPopupChanged: arm()
    onShowingChanged: arm()
    onPausedChanged: arm()
    onPersistentPopupChanged: arm()
    Connections {
        target: root.notification
        function onClosed() { root.owner.dismiss(root, false); }
        function onSummaryChanged() { root.updated(); }
        function onBodyChanged() { root.updated(); }
        function onUrgencyChanged() { root.updated(); }
        function onExpireTimeoutChanged() { root.updated(); }
    }
}
