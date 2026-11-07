pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
PanelWindow {
    id: root
    required property var barWindow
    required property var controller
    property real reveal: controller.opened ? 1 : 0
    property string pendingAction: ""
    signal actionRequested(string action)
    screen: barWindow.screen
    implicitWidth: 208
    implicitHeight: 233
    anchors { top: true; right: true }
    margins.top: Theme.topMargin + Theme.pillHeight
    margins.right: Math.max(4,Theme.edgeMargin-6)
    visible: controller.opened || reveal>0.001
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-floating-bar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region { item:surface; radius:Theme.radius }
    Behavior on reveal { NumberAnimation { duration:Theme.normal;easing.type:Easing.OutCubic } }
    onVisibleChanged: if (!visible && pendingAction) { const action=pendingAction;pendingAction="";actionRequested(action); }
    Connections { target:root.controller;function onOpenedChanged() { if(root.controller.opened) root.pendingAction=""; } }
    HyprlandFocusGrab { active:root.controller.opened;windows:[root,root.barWindow];onCleared:root.controller.opened=false }
    Rectangle {
        id: surface
        x:6; y:6-4*(1-root.reveal)
        width:parent.width-12;height:parent.height-12
        radius:Theme.radius;color:Theme.panel
        border.width:1;border.color:Theme.border
        opacity:root.reveal
        focus:root.controller.opened
        Keys.onEscapePressed:root.controller.opened=false
        Column {
            x:8;y:8;width:parent.width-16;spacing:2
            Repeater {
                model:[{text:"Sleep",action:"suspend",icon:"sleep"},{text:"Lock",action:"lock",icon:"lock"},{text:"Log Out",action:"logout",icon:"logout"},{text:"Shut Down",action:"shutdown",icon:"power"},{text:"Reboot",action:"reboot",icon:"reboot"}]
                Button {
                    id: item
                    required property var modelData
                    width:parent.width;height:39
                    onClicked:{root.pendingAction=modelData.action;root.controller.opened=false}
                    padding: 0
                    text: modelData.text
                    Accessible.name: text
                    contentItem: Item {
                        Icon {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18; height: 18
                            name: item.modelData.icon
                            color: Theme.text
                            scale: item.down ? 0.9 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
                        }
                        BarText {
                            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 42; rightMargin: 12 }
                            text: item.text
                            font.pixelSize: 13
                        }
                    }
                    background:Rectangle {
                        radius:12
                        color:item.down?Theme.activeSurface:item.hovered||item.visualFocus?Theme.hover:"transparent"
                        Behavior on color { ColorAnimation { duration:Theme.fast } }
                    }
                    HoverHandler { cursorShape:Qt.PointingHandCursor }
                }
            }
        }
    }
}
