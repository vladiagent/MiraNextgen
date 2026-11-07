import QtQuick
import QtQuick.Controls
import "."

ComboBox {
    id: root
    implicitHeight: 34
    leftPadding: 13
    rightPadding: 29
    font.family: Theme.fontFamily
    font.weight: Font.Normal
    font.pixelSize: 12
    contentItem: Label {
        text: root.displayText
        font: root.font
        color: root.enabled ? Theme.text : Theme.muted
    }
    indicator: Label {
        x: root.width - 22
        height: root.height
        text: "⌄"
        font.pixelSize: 15
        color: Theme.muted
    }
    background: Rectangle {
        radius: height / 2
        color: root.hovered || root.visualFocus ? Theme.hover : Theme.pill
        border.width: 1
        border.color: root.visualFocus ? Theme.accent : Theme.border
        Behavior on color {
            ColorAnimation {
                duration: Theme.fast
            }
        }
    }
    delegate: ItemDelegate {
        required property int index
        required property var model
        width: root.width
        height: 36
        highlighted: root.highlightedIndex === index
        contentItem: Label {
            text: model[root.textRole] || ""
            font.pixelSize: 12
        }
        background: Rectangle {
            radius: 12
            color: parent.highlighted ? Theme.activeSurface : "transparent"
        }
    }
    popup: Popup {
        y: root.height + 6
        width: Math.max(root.width, 190)
        padding: 6
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 228)
        background: Rectangle {
            radius: Theme.radius
            color: Theme.panel
            border.width: 1
            border.color: Theme.border
        }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollIndicator.vertical: ScrollIndicator {}
        }
        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.normal
                easing.type: Easing.OutCubic
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Theme.fast
            }
        }
    }
}
