pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray as Tray
import ".."

Pill {
    id: root
    required property var barWindow
    readonly property int itemCount: Tray.SystemTray.items.values.length
    implicitWidth: itemCount > 0 ? trayRow.implicitWidth + 16 : 0
    opacity: itemCount > 0 ? 1 : 0
    visible: opacity > 0.001
    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: Tray.SystemTray.items
            delegate: Item {
                id: trayItem
                required property Tray.SystemTrayItem modelData
                property bool quitRequested: false
                readonly property var quitEntries: quitRequested ? (quitMenu.children?.values ?? []) : []
                onQuitEntriesChanged: if (quitRequested && quitEntries.length)
                    Qt.callLater(finishQuit)

                function normalizedLabel(text: string): string {
                    return text.replace(/[&_]/g, "").replace(/[.…]+$/, "").trim().toLowerCase();
                }
                function finishQuit(): void {
                    if (!quitRequested)
                        return;
                    const appNames = [modelData.title, modelData.tooltipTitle, modelData.id].map(normalizedLabel);
                    const action = quitEntries.find(entry => {
                        if (entry.isSeparator || !entry.enabled || entry.hasChildren || entry.buttonType !== QsMenuButtonType.None)
                            return false;
                        const label = normalizedLabel(entry.text);
                        return label === "quit" || label === "exit" || appNames.some(name =>
                            name && (label === "quit " + name || label === "exit " + name));
                    });
                    quitTimeout.stop();
                    if (action) {
                        action.triggered();
                        quitRequested = false;
                    } else {
                        openMenu();
                    }
                }
                function openMenu(): void {
                    quitTimeout.stop();
                    quitRequested = false;
                    if (modelData.hasMenu)
                        menu.open();
                }
                QsMenuOpener {
                    id: quitMenu
                    menu: trayItem.quitRequested ? trayItem.modelData.menu : null
                }
                Timer {
                    id: quitTimeout
                    interval: 1200
                    onTriggered: trayItem.finishQuit()
                }
                width: 25
                height: 28
                Rectangle {
                    anchors.fill: parent
                    radius: 13
                    color: hit.containsMouse ? Theme.hover : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.fast
                        }
                    }
                }
                Image {
                    anchors.centerIn: parent
                    width: 17
                    height: 17
                    sourceSize: Qt.size(34, 34)
                    source: trayItem.modelData.icon
                    smooth: true
                    scale: hit.pressed ? 0.9 : 1
                    Behavior on scale {
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
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: event => {
                        if (event.button === Qt.MiddleButton)
                            trayItem.modelData.secondaryActivate();
                        else if (event.button === Qt.RightButton) {
                            if (event.modifiers & Qt.ShiftModifier)
                                trayItem.openMenu();
                            else if (trayItem.modelData.hasMenu && !trayItem.quitRequested) {
                                quitTimeout.restart();
                                trayItem.quitRequested = true;
                            }
                        } else if (trayItem.modelData.onlyMenu)
                            trayItem.openMenu();
                        else
                            trayItem.modelData.activate();
                    }
                    onWheel: event => trayItem.modelData.scroll(event.angleDelta.y || event.angleDelta.x, event.angleDelta.y === 0)
                }
                QsMenuAnchor {
                    id: menu
                    menu: trayItem.modelData.menu
                    anchor.item: trayItem
                    anchor.edges: Edges.Bottom
                    anchor.gravity: Edges.Bottom
                }
                ToolTip.visible: hit.containsMouse
                ToolTip.delay: 650
                ToolTip.text: modelData.tooltipTitle || modelData.title || modelData.id
            }
        }
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Theme.normal
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.normal
        }
    }
}
