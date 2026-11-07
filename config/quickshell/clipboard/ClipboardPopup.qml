pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import ".."
import "../components"
import "../services"
import "../launcher"

PanelWindow {
    id:root
    objectName:"vladi-clipboard-popup"
    property bool blocked:false
    property bool opened:false
    property bool motionReady:false
    property real reveal:opened&&motionReady?1:0
    property bool confirmingClear:false
    property ShellScreen targetScreen:Quickshell.screens[0]??null
    readonly property string query:search.text.trim().toLocaleLowerCase()
    readonly property var matches:ClipboardService.entries.filter(entry=>!query || entry.preview.toLocaleLowerCase().includes(query))
    readonly property var results:matches.slice(0,80)
    screen:targetScreen
    anchors {top:true;bottom:true;left:true;right:true}
    readonly property real topOffset:Math.max(Theme.barHeight+28,Math.round((screen?.height||1080)*0.14))
    readonly property real cardWidth:Math.min(562,(screen?.width||1920)-32)-12
    readonly property real cardHeight:Math.min((screen?.height||1080)-topOffset-24,Math.max(274,174+Math.min(results.length,7)*66))-12
    implicitWidth:screen?.width||1920
    implicitHeight:screen?.height||1080
    color:"transparent"
    exclusionMode:ExclusionMode.Ignore
    visible:!blocked&&(opened||reveal>0.001)
    WlrLayershell.namespace:"vladi-clipboard"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:root.opened?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.None
    FrameAnimation {running:root.opened&&!root.motionReady;onTriggered:root.motionReady=true}
    Behavior on reveal {NumberAnimation {duration:root.opened?Motion.enter:Motion.exit;easing.type:Easing.OutQuint}}
    function open(): void {
        if(blocked) return;
        if(opened) {search.input.forceActiveFocus();return;}
        targetScreen=Quickshell.screens.find(screen=>screen.name===Hyprland.focusedMonitor?.name)||Quickshell.screens[0];
        NotificationService.closePanel();search.text="";confirmingClear=false;list.currentIndex=0;
        ClipboardService.open();opened=true;Qt.callLater(()=>search.input.forceActiveFocus());
    }
    function close(): void {opened=false;confirmingClear=false;ClipboardService.send({command:"close"});}
    function setQuery(text: string): void {open();search.text=text;}
    function toggle(): void {if(opened)close();else open();}
    function activate(): void {const entry=results[list.currentIndex];if(entry)ClipboardService.copy(entry.id);}
    onBlockedChanged:if(blocked) {close();ClipboardService.close();}
    onVisibleChanged:if(!visible) {motionReady=false;search.text="";ClipboardService.close();}
    onQueryChanged:Qt.callLater(()=>{list.currentIndex=0;list.positionViewAtBeginning();})
    Connections {target:ClipboardService;function onCopied(){root.close();}}
    IpcHandler {
        target:"clipboard"
        function toggle(): void {root.toggle();}
        function open(): void {root.open();}
        function close(): void {root.close();}
        function search(text:string): void {root.setQuery(text);}
        function status():string {
            return JSON.stringify({opened:root.opened,focused:search.input.activeFocus,total:ClipboardService.entries.length,
                shown:root.results.length,selected:list.currentIndex,loading:ClipboardService.loading,available:ClipboardService.available,
                confirmingClear:root.confirmingClear,accent:Theme.accent.toString()});
        }
    }
    MouseArea {anchors.fill:parent;onClicked:root.close()}
    Rectangle {
        id:surface
        objectName:"clipboard-surface"
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.topOffset + 6 + 10 * (1 - root.reveal)
        width:root.cardWidth;height:root.cardHeight
        Behavior on height {SmoothedAnimation {duration:Motion.resize;velocity:-1;maximumEasingTime:120}}
        radius:Theme.radius;color:Theme.panel;border.width:1;border.color:Theme.withAlpha(Theme.accent,0.24)
        opacity:root.reveal
        focus:root.opened
        MouseArea {anchors.fill:parent;onClicked:search.input.forceActiveFocus()}
        Keys.onEscapePressed: {if(root.confirmingClear)root.confirmingClear=false;else root.close();}
        BarText {x:20;y:17;text:"Clipboard";font.pixelSize:20}
        BarText {anchors.right:clear.left;anchors.rightMargin:12;y:20;text:root.matches.length+" items";font.pixelSize:12;color:Theme.muted;visible:ClipboardService.entries.length>0}
        MenuButton {id:clear;anchors.right:parent.right;anchors.rightMargin:14;y:12;height:32;text:"Clear History";enabled:ClipboardService.entries.length>0;onClicked:{root.confirmingClear=true;confirmButton.forceActiveFocus();}}
        SearchField {
            id:search
            x:14;y:58;width:parent.width-28
            placeholderText:"Search clipboard history"
            accessibleName:"Search clipboard history"
            onStep:direction=> {if(root.results.length) list.currentIndex=(list.currentIndex+direction+root.results.length)%root.results.length;}
            onActivate:root.activate()
            onDismiss:root.close()
        }
        ListView {
            id:list
            objectName:"clipboard-results"
            x:14;y:122;width:parent.width-28;height:parent.height-y-36
            spacing:4;clip:true
            boundsBehavior:Flickable.StopAtBounds
            model:ScriptModel {values:root.results;objectProp:"id"}
            keyNavigationEnabled:false
            onCurrentIndexChanged:positionViewAtIndex(currentIndex,ListView.Contain)
            delegate:Item {
                id:row
                objectName:"clipboard-entry"
                required property var modelData
                required property int index
                width:list.width;height:62
                Component.onCompleted:if(modelData.image)ClipboardService.thumbnail(modelData.id)
                Rectangle {
                    anchors.fill:parent;radius:13
                    color:list.currentIndex===row.index?Theme.withAlpha(Theme.accent,0.14):hover.hovered?Theme.hover:"transparent"
                    border.width:1;border.color:list.currentIndex===row.index?Theme.withAlpha(Theme.accent,0.2):"transparent"
                    Behavior on color {ColorAnimation {duration:Motion.hover}}
                }
                MouseArea {anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{list.currentIndex=row.index;root.activate();}}
                HoverHandler {id:hover}
                Icon {x:12;anchors.verticalCenter:parent.verticalCenter;name:row.modelData.image?"image":"copy";width:20;height:20;color:Theme.muted;visible:!thumbnail.visible}
                Image {
                    id:thumbnail
                    x:8;anchors.verticalCenter:parent.verticalCenter;width:30;height:40
                    source:ClipboardService.thumbnails[row.modelData.id]||""
                    fillMode:Image.PreserveAspectFit
                    visible:row.modelData.image&&status===Image.Ready
                }
                BarText {
                    x:46;width:parent.width-90;anchors.verticalCenter:parent.verticalCenter
                    text:row.modelData.preview
                    font.pixelSize:13
                    wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight
                }
                IconButton {
                    anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter
                    icon:"trash";iconSize:16;tooltip:"Delete entry"
                    onClicked:ClipboardService.remove(row.modelData.id)
                }
            }
            ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
        }
        Column {
            anchors.centerIn:list;spacing:10
            visible:root.results.length===0
            BarText {anchors.horizontalCenter:parent.horizontalCenter;text:ClipboardService.loading?"Loading…":ClipboardService.message?"Clipboard unavailable":root.query?"No matching entries":"Your clipboard history is empty";font.pixelSize:14}
            BarText {anchors.horizontalCenter:parent.horizontalCenter;text:ClipboardService.message||(!root.query&&!ClipboardService.loading?"Copy something to see it here":"");color:Theme.muted;font.pixelSize:12}
        }
        BarText {
            x:20;anchors.bottom:parent.bottom;anchors.bottomMargin:12
            width:parent.width-40
            text:ClipboardService.message || (root.matches.length>80?"Showing 80 matches · Type to narrow your search":"↑ ↓ Navigate    Enter Copy    Esc Close")
            color:Theme.muted;font.pixelSize:11
        }
        Rectangle {
            anchors.fill:parent;radius:parent.radius;color:Theme.panel
            visible:root.confirmingClear
            MouseArea {anchors.fill:parent}
            Column {
                anchors.centerIn:parent;width:parent.width-48;spacing:16
                BarText {width:parent.width;text:"Clear clipboard history?";font.pixelSize:19;horizontalAlignment:Text.AlignHCenter}
                BarText {width:parent.width;text:"This removes all saved entries. Your current clipboard stays available.";wrapMode:Text.Wrap;horizontalAlignment:Text.AlignHCenter;color:Theme.muted;font.pixelSize:13}
                Row {
                    anchors.horizontalCenter:parent.horizontalCenter;spacing:10
                    MenuButton {text:"Cancel";onClicked:{root.confirmingClear=false;search.input.forceActiveFocus();}}
                    MenuButton {id:confirmButton;text:"Clear History";primary:true;onClicked:{ClipboardService.clear();root.confirmingClear=false;search.input.forceActiveFocus();}}
                }
            }
        }
    }
}
