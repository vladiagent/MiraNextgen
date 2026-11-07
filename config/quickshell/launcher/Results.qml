pragma ComponentBehavior: Bound
import QtQuick
import ".."

ListView {
    id: root
    property var results: []
    signal chosen(int index)
    model: results
    clip: true
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: Motion.selection
    highlightMoveVelocity: -1
    highlightResizeDuration: 0
    highlightResizeVelocity: -1
    highlightFollowsCurrentItem: true
    keyNavigationEnabled: false
    highlight: Rectangle {
        width: root.width
        height: 60
        radius: 14
        color: Theme.withAlpha(Theme.accent, 0.16)
        border.width: 1
        border.color: Theme.withAlpha(Theme.accent, 0.16)
    }
    delegate: ResultItem {
        required property var modelData
        required property int index
        width: root.width
        result: modelData
        selected: root.currentIndex === index
        onHovered: root.currentIndex = index
        onActivate: root.chosen(index)
    }
    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
}
