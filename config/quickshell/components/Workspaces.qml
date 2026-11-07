pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."

Pill {
    id: root
    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 0
    implicitWidth: 5 * Theme.workspaceCell + 20

    Rectangle {
        x: 10 + (Math.max(1, Math.min(5, root.activeId)) - 1) * Theme.workspaceCell
        y: 8
        width: Theme.workspaceCell
        height: 20
        radius: 11
        color: Theme.accent
        opacity: root.activeId >= 1 && root.activeId <= 5 ? 1 : 0
        Behavior on x {
            NumberAnimation {
                duration: Theme.glide
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.fast
            }
        }
    }
    Row {
        x: 10
        height: parent.height
        Repeater {
            model: 5
            delegate: Item {
                id: cell
                required property int index
                readonly property int number: index + 1
                readonly property HyprlandWorkspace workspace: Hyprland.workspaces.values.find(w => w.id === number) ?? null
                readonly property bool occupied: (workspace?.toplevels.values.length ?? 0) > 0
                width: Theme.workspaceCell
                height: Theme.pillHeight
                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 24
                    radius: 12
                    color: hit.containsMouse && root.activeId !== cell.number ? Theme.hover : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }
                }
                BarText {
                    anchors.centerIn: parent
                    text: cell.number
                    color: root.activeId === cell.number ? "#202922" : cell.workspace?.urgent ? Theme.warm : cell.occupied ? Theme.text : Theme.muted
                    opacity: root.activeId === cell.number || cell.occupied || hit.containsMouse ? 1 : 0.65
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.normal
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.fast
                        }
                    }
                }
                MouseArea {
                    id: hit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activate(cell.number)
                }
                Accessible.role: Accessible.Button
                Accessible.name: "Workspace " + number
                Accessible.onPressAction: root.activate(number)
            }
        }
    }
    function activate(number: int): void {
        const workspace = Hyprland.workspaces.values.find(w => w.id === number);
        if (workspace)
            workspace.activate();
    }
}
