pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

PanelWindow {
    id: root
    required property ShellScreen targetScreen
    property bool keepingVisible: false
    property real lastHeight: 1
    Timer { id: retire; interval: Motion.exit; onTriggered: root.keepingVisible=false }
    onEntriesChanged: { if(entries.length) { keepingVisible=true;retire.stop(); } else retire.restart(); }
    readonly property int limit: Math.max(1,Math.min(3,Math.floor(((targetScreen?.height||1080)-80)/300)))
    readonly property var entries: NotificationService.popupsFor((targetScreen?.name||""),limit)
    screen: targetScreen
    anchors { top:true; right:true }
    margins.top:Theme.topMargin+Theme.pillHeight
    margins.right:Math.max(4,Theme.edgeMargin-6)
    implicitWidth:Math.min(408,(targetScreen?.width||1920)-16)
    implicitHeight:Math.min((targetScreen?.height||1080)-Theme.barHeight-20,Math.max(1,entries.length?list.contentHeight+12:lastHeight))
    color:"transparent"
    visible:!!targetScreen && !NotificationService.blocked && keepingVisible
    exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"quickshell-floating-bar"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
    mask:Region { item:list }
    ListView {
        id:list
        x:6; y:6; width:parent.width-12; height:parent.height-12
        onContentHeightChanged: if(root.entries.length) root.lastHeight=contentHeight+12
        spacing:10
        clip:true
        interactive:contentHeight>height
        boundsBehavior:Flickable.StopAtBounds
        model:ScriptModel { values:root.entries;objectProp:"noticeId" }
        delegate:NotificationCard {
            required property var modelData
            width:list.width
            entry:modelData
            Component.onCompleted:entry.showing=true
            Component.onDestruction:if(entry) { entry.showing=false;entry.paused=false; }
        }
        add:Transition {
            ParallelAnimation {
                NumberAnimation { property:"opacity";from:0;to:1;duration:Motion.enter;easing.type:Easing.OutCubic }
                NumberAnimation { property:"x";from:18;to:0;duration:Motion.enter;easing.type:Easing.OutQuint }
            }
        }
        remove:Transition { NumberAnimation { property:"opacity";to:0;duration:Motion.exit;easing.type:Easing.InCubic } }
        displaced:Transition { NumberAnimation { property:"y";duration:Motion.layout;easing.type:Easing.OutQuint } }
    }
}
