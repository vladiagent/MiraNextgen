import QtQuick
import ".."

Text {
    color: Theme.text
    font.family: Theme.fontFamily
    font.weight: Theme.fontWeight
    font.pixelSize: Theme.fontSize
    textFormat: Text.PlainText
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    renderType: Text.QtRendering
}
