pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import ".."
import "../components"
import "../services"

Rectangle {
    id: root
    objectName: "vladi-notification-card"
    required property var entry
    property bool inHistory: false
    readonly property var notice: entry.notification
    readonly property var actions: notice.actions.filter(action => action.identifier !== "default")
    readonly property var defaultAction: notice.actions.find(action => action.identifier === "default") ?? null
    readonly property string imageSource: NotificationService.imageSource(notice.image)
    implicitHeight: content.implicitHeight + 28
    radius: Theme.radius
    color: Theme.panel
    border.width: 1
    border.color: entry.critical ? Theme.withAlpha(Theme.accent,0.65) : Theme.border
    RetainableLock { object: root.notice; locked: true }
    HoverHandler {
        id: hover
        onHoveredChanged: if (!root.inHistory) root.entry.paused = hovered
    }
    MouseArea { anchors.fill:parent; cursorShape:root.defaultAction?Qt.PointingHandCursor:Qt.ArrowCursor; onClicked:if(root.defaultAction)NotificationService.invokeAction(root.defaultAction); }
    Column {
        id: content
        x:14; y:14; width:parent.width-28
        spacing: 9
        Item {
            width: parent.width; height: 26
            Image {
                id: appIcon
                objectName: "notification-app-icon"
                width:24; height:24
                anchors.verticalCenter: parent.verticalCenter
                source: NotificationService.iconSource(root.notice.appIcon)
                sourceSize: Qt.size(48,48)
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
                asynchronous: false
            }
            Icon { width:19; height:19; anchors.verticalCenter:parent.verticalCenter; name:"bell"; color:Theme.muted; visible:!appIcon.visible }
            BarText {
                x:34; width:parent.width-122; height:parent.height
                text: root.notice.appName
                font.pixelSize: 12
                color: Theme.muted
            }
            BarText {
                anchors.right: close.left; anchors.rightMargin: 8
                height:parent.height
                text: NotificationService.timeLabel(root.entry.received)
                font.pixelSize:11; color:Theme.muted
            }
            IconButton {
                id: close
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width:26; height:26; iconSize:14
                icon:"close"; tooltip:"Dismiss notification"
                onClicked: NotificationService.dismiss(root.entry,true)
            }
        }
        BarText {
            width: parent.width
            visible: text.length>0
            text: root.notice.summary.slice(0,1024)
            font.pixelSize:14; font.weight:500
            wrapMode: Text.Wrap
            maximumLineCount:2
            elide: Text.ElideRight
        }
        BarText {
            width: parent.width
            visible: text.length>0
            objectName: "notification-body"
            text: NotificationService.plainBody(root.notice.body)
            font.pixelSize:13; color:Theme.muted
            wrapMode: Text.Wrap
            maximumLineCount:root.inHistory?5:4
            elide:Text.ElideRight
            lineHeight:1.12
        }
        Image {
            width: parent.width; height: visible?96:0
            visible: !!root.imageSource && status!==Image.Error
            source: root.imageSource
            fillMode:Image.PreserveAspectFit
            sourceSize:Qt.size(720,192)
            asynchronous:true
        }
        Flow {
            width: parent.width
            spacing:6
            visible: root.actions.length>0
            Repeater {
                model: root.actions.slice(0,4)
                MenuButton {
                    required property var modelData
                    text:modelData.text
                    implicitWidth:Math.min(168,Math.max(72,text.length*7+24))
                    onClicked:NotificationService.invokeAction(modelData)
                }
            }
            MenuButton {
                visible:root.actions.length>4
                text:"More…"
                onClicked:more.open()
                Menu {
                    id:more
                    popupType:Popup.Item
                    Repeater {
                        model:root.actions.slice(4)
                        MenuItem { required property var modelData; text:modelData.text; onTriggered:NotificationService.invokeAction(modelData); font.family:Theme.fontFamily }
                    }
                }
            }
        }
    }
    Accessible.role: Accessible.Pane
    Accessible.name: notice.summary
}
