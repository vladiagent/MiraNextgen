pragma ComponentBehavior: Bound
import QtQuick
import ".."

Row {
    id: root
    function renderedCards(): var {
        return children.filter(child => child.objectName === "launcher-workspace-card").map(child => ({id: child.number, tiles: child.renderedTiles()}));
    }
    required property var controller
    spacing: 16
    height: Math.max(128, Math.min(190, ((width - 64) / 5) * 0.68))
    Repeater {
        model: 5
        delegate: WorkspaceCard {
            required property int index
            number: index + 1
            controller: root.controller
            width: (root.width - 4 * root.spacing) / 5
            height: root.height
        }
    }
}
