pragma Singleton
import QtQuick

QtObject {
    readonly property int press: 160
    readonly property int hover: 200
    readonly property int control: 280
    readonly property int selection: 300
    readonly property int resize: 360
    readonly property int layout: 420
    readonly property int enter: 440
    readonly property int exit: 320
    readonly property var settle: [0.20, 0.00, 0.15, 1.00, 1.00, 1.00]
    readonly property var dismiss: [0.40, 0.00, 0.20, 1.00, 1.00, 1.00]
}
