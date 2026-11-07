pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray as Tray
import "services"
import "components"
import "notifications"
import "clipboard"
import "emoji"
import "lock"
import "launcher"
import "osd"

ShellRoot {
    id: shell
    LockScreen { id: sessionLockController }
    NotificationHost {}
    function dismissLauncherForPicker(): void {
        if (!appLauncher.opened)
            return;
        appLauncher.cancelDrag();
        appLauncher.pendingAction = null;
        appLauncher.opened = false;
    }
    ClipboardPopup {
        id: clipboardPopup
        onOpenedChanged: if (opened) {
            emojiPopup.close();
            shell.dismissLauncherForPicker();
        }
        blocked: sessionLockController.locked || sessionLockController.preparing
    }
    EmojiPopup {
        id: emojiPopup
        onOpenedChanged: if (opened) {
            clipboardPopup.close();
            shell.dismissLauncherForPicker();
        }
        blocked: sessionLockController.locked || sessionLockController.preparing
    }
    Binding {
        target: NotificationService
        property: "blocked"
        value: sessionLockController.locked || sessionLockController.preparing
    }
    VolumeOsd {}
    Launcher {
        id: appLauncher
        onOpenedChanged: if (opened) {
            clipboardPopup.close();
            emojiPopup.close();
        }
    }
    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup(); }
    }
    Timer {
        id: reloadTimer
        interval: 50
        onTriggered: if (!sessionLockController.locked && !sessionLockController.preparing) Quickshell.reload(false)
    }
    IpcHandler {
        target: "bar"
        function status(): string {
            return JSON.stringify({
                palette: { accent: Theme.accent.toString(), text: Theme.text.toString() },
                screens: Quickshell.screens.map(s => s.name),
                workspaces: Hyprland.workspaces.values.filter(w => w.id >= 1 && w.id <= 5).map(w => ({
                            id: w.id,
                            active: w.active
                        })),
                trayItems: Tray.SystemTray.items.values.map(t => t.id),
                notifications: {
                    available: NotificationService.available,
                    count: NotificationService.count,
                    dnd: NotificationService.dnd,
                    visible: NotificationService.panelVisible
                },
                media: {
                    available: MediaService.available,
                    title: MediaService.title,
                    artist: MediaService.artist,
                    displayTitle: MediaService.displayTitle,
                    playing: MediaService.playing,
                    position: MediaService.player?.position ?? 0,
                    duration: MediaService.duration,
                    seekable: MediaService.seekable
                }
            });
        }
        function reload(): void {
            if (sessionLockController.locked || sessionLockController.preparing) return;
            reloadTimer.restart();
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: bar
            onWindowConnected: sessionLockController.registerHost(modelData.name, contentItem)
            Component.onDestruction: if (sessionLockController) sessionLockController.unregisterHost(modelData.name, contentItem)
            required property ShellScreen modelData
            screen: modelData
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: Theme.barHeight
            exclusiveZone: Theme.barHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell-floating-bar"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region {
                Region {
                    item: leftGroup
                }
                Region {
                    item: media
                    width: media.visible ? media.width : 0
                }
                Region {
                    item: rightGroup
                }
            }
            Row {
                id: leftGroup
                x: Theme.edgeMargin
                y: Theme.topMargin
                spacing: Theme.gap
                Clock {}
                Workspaces {
                    screen: bar.screen
                }
                SystemTray {
                    barWindow: bar
                }
            }
            Media {
                id: media
                barWindow: bar
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.topMargin
                maximumWidth: Math.max(0, 2 * Math.min(bar.width / 2 - leftGroup.x - leftGroup.width - Theme.gap, rightGroup.x - bar.width / 2 - Theme.gap))
            }
            Row {
                id: rightGroup
                x: bar.width - width - Theme.edgeMargin
                y: Theme.topMargin
                spacing: Theme.gap
                Notifications { barWindow: bar }
                Connectivity {
                    barWindow: bar
                }
                Power {
                    barWindow: bar
                    onActionRequested: action => sessionLockController.handleAction(action)
                }
            }
        }
    }
}
