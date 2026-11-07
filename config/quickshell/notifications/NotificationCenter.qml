pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../services"

PanelWindow {
    id:root
    property bool motionReady:false
    property real reveal:NotificationService.panelVisible && motionReady?1:0
    screen:NotificationService.panelScreen
    anchors {top:true;right:true}
    margins.top:Theme.topMargin+Theme.pillHeight
    margins.right:Math.max(4,Theme.edgeMargin-6)
    implicitWidth:Math.min(432,(screen?.width || 1920)-16)
    implicitHeight:Math.min(720,(screen?.height || 1080)-Theme.barHeight-24)
    exclusionMode:ExclusionMode.Ignore
    visible:!NotificationService.blocked && (NotificationService.panelVisible || reveal>0.001)
    color:"transparent"
    WlrLayershell.namespace:"quickshell-floating-bar"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:NotificationService.panelVisible?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.None
    mask:Region {item:surface;radius:Theme.radius}
    FrameAnimation { running:NotificationService.panelVisible&&!root.motionReady;onTriggered:root.motionReady=true }
    Behavior on reveal { NumberAnimation { duration:NotificationService.panelVisible?Motion.enter:Motion.exit;easing.type:Easing.OutQuint } }
    onVisibleChanged:if(!visible) { motionReady=false;NotificationService.finishAction(); }
    HyprlandFocusGrab { active:NotificationService.panelVisible;windows:NotificationService.panelWindow?[root,NotificationService.panelWindow]:[root];onCleared:NotificationService.closePanel() }
    Rectangle {
        id:surface
        x:6; y:6+8*(1-root.reveal)
        width:parent.width-12;height:parent.height-12
        radius:Theme.radius;color:Theme.panel;border.width:1;border.color:Theme.border
        opacity:root.reveal
        focus:NotificationService.panelVisible
        Keys.onEscapePressed:NotificationService.closePanel()
        BarText {x:20;y:20;text:"Notifications";font.pixelSize:22;font.weight:400}
        IconButton {anchors.right:parent.right;anchors.rightMargin:14;y:17;icon:"close";tooltip:"Close notifications";onClicked:NotificationService.closePanel()}
        Rectangle {
            x:14;y:64;width:parent.width-28;height:54
            radius:14;color:Theme.withAlpha(Theme.text,0.045)
            Icon {x:14;anchors.verticalCenter:parent.verticalCenter;name:"sleep";width:19;height:19;color:NotificationService.dnd?Theme.accent:Theme.muted}
            BarText {x:45;height:parent.height;text:"Do Not Disturb";font.pixelSize:13}
            Switch {
                id:dnd
                width:44;height:40;padding:0
                anchors.right:parent.right;anchors.rightMargin:10;anchors.verticalCenter:parent.verticalCenter
                checked:NotificationService.dnd
                onToggled:NotificationService.dnd=checked
                indicator:Rectangle {
                    implicitWidth:38;implicitHeight:22;radius:11
                    x:(dnd.width-width)/2;y:(dnd.height-height)/2
                    color:dnd.checked?Theme.accent:Theme.withAlpha(Theme.text,0.18)
                    Rectangle {x:dnd.checked?19:3;y:3;width:16;height:16;radius:8;color:dnd.checked?"#282828":Theme.text;Behavior on x {NumberAnimation {duration:Motion.control;easing.type:Easing.OutCubic}}}
                    Behavior on color {ColorAnimation {duration:Motion.control}}
                }
                Accessible.name:"Do Not Disturb"
            }
        }
        BarText {x:20;y:135;text:NotificationService.count?"Recent · "+NotificationService.count:"Recent";color:Theme.muted;font.pixelSize:12}
        MenuButton {anchors.right:parent.right;anchors.rightMargin:14;y:126;height:30;text:"Clear All";enabled:NotificationService.count>0;onClicked:NotificationService.clearAll()}
        ListView {
            id:list
            x:12;y:168;width:parent.width-24;height:parent.height-y-12
            clip:true;spacing:10
            boundsBehavior:Flickable.StopAtBounds
            model:ScriptModel {values:NotificationService.panelVisible?NotificationService.groupedHistory:[];objectProp:"noticeId"}
            delegate:Column {
                id:groupedCard
                required property var modelData
                required property int index
                readonly property bool groupStart:index===0 || NotificationService.groupedHistory[index-1]?.group!==modelData.group
                width:list.width;spacing:8
                BarText {
                    width:parent.width-12;x:6
                    visible:groupedCard.groupStart && text.length>0
                    text:groupedCard.modelData.appName
                    color:Theme.muted;font.pixelSize:11
                }
                NotificationCard {width:parent.width;entry:groupedCard.modelData;inHistory:true}
            }
            remove:Transition {NumberAnimation {property:"opacity";to:0;duration:Motion.exit}}
            displaced:Transition {NumberAnimation {property:"y";duration:Motion.layout;easing.type:Easing.OutQuint}}
            ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
        }
        Column {
            anchors.centerIn:list
            spacing:15
            visible:NotificationService.count===0
            Icon {anchors.horizontalCenter:parent.horizontalCenter;name:"bell";width:34;height:34;color:Theme.muted;opacity:0.55}
            BarText {text:"You're all caught up";font.pixelSize:15;anchors.horizontalCenter:parent.horizontalCenter}
            BarText {text:"New notifications will appear here";color:Theme.muted;font.pixelSize:12;anchors.horizontalCenter:parent.horizontalCenter}
        }
    }
}
