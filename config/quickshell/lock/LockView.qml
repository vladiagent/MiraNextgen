pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import ".."
import "../components"

Rectangle {
    id: root
    required property var controller
    required property string screenName
    property var snapshot: null
    readonly property bool activeHere: controller.authenticationScreen === screenName
    color: "#282828"
    function attachSnapshot(): void {
        const item = controller.snapshotFor(screenName);
        if (item) {
            item.parent = background;
            item.width = Qt.binding(() => background.width);
            item.height = Qt.binding(() => background.height);
            item.visible = true;
            snapshot = item;
            frozen.scheduleUpdate();
        }
        if (activeHere) password.forceActiveFocus();
    }
    Component.onCompleted: Qt.callLater(attachSnapshot)
    Component.onDestruction: password.clear()
    onActiveHereChanged: if (activeHere) Qt.callLater(password.forceActiveFocus)
    Item { id: background; anchors.fill: parent }
    ShaderEffectSource {
        id: frozen
        sourceItem: root.snapshot
        hideSource: true
        live: false
        visible: false
        textureSize: Qt.size(Math.max(1,Math.ceil(root.width/2)),Math.max(1,Math.ceil(root.height/2)))
    }
    MultiEffect {
        anchors.fill: parent
        source: frozen
        blurEnabled: true
        blurMax: 64
        blur: 1
        autoPaddingEnabled: false
    }
    Rectangle { anchors.fill: parent; color: "#60000000" }
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.controller.activateScreen(root.screenName);
            if (!powerMenu.visible) password.forceActiveFocus();
        }
    }
    Column {
        id: content
        width: Math.min(408,root.width-48)
        anchors.centerIn: parent
        spacing: 12
        visible: root.activeHere
        Row {
            width: parent.width
            spacing: 10
            TextField {
                id: password
                objectName: "vladi-lock-password"
                width: parent.width-54
                height: 44
                enabled: !root.controller.busy
                focus: root.activeHere
                echoMode: TextInput.Password
                passwordCharacter: "●"
                placeholderText: "Password"
                color: Theme.text
                placeholderTextColor: Theme.muted
                selectionColor: Theme.accent
                selectedTextColor: "#282828"
                font.family: Theme.fontFamily
                font.weight: Font.Normal
                font.pixelSize: 14
                leftPadding: 16; rightPadding: 16
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhHiddenText
                onAccepted: root.controller.submit(password)
                onTextEdited: root.controller.message = ""
                Keys.onEscapePressed: root.controller.cancelEntry()
                Keys.onPressed: event => { if (event.key === Qt.Key_CapsLock) root.controller.capsLock = !root.controller.capsLock; }
                Accessible.name: "Password; press Enter to unlock"
                background: Rectangle {
                    radius: Theme.radius
                    color: Theme.panel
                    border.width: 1
                    border.color: root.controller.message ? Theme.warm : password.activeFocus ? Theme.accent : Theme.border
                    Behavior on border.color { ColorAnimation { duration: Theme.fast } }
                }
                transform: Translate { id: shake; x: 0 }
            }
            IconButton {
                id: power
                width: 44; height: 44
                icon: "power"
                iconSize: 18
                tooltip: "Power options"
                enabled: !root.controller.busy
                onClicked: { root.controller.cancelEntry(); powerMenu.open(); }
                Rectangle { anchors.fill: parent; z:-1; radius: Theme.radius; color: Theme.panel; border.width:1; border.color:Theme.border }
            }
        }
        BarText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 12
            text: root.controller.message || (root.controller.busy ? "Unlocking…" : root.controller.capsLock ? "Caps Lock is on" : "Press Enter to unlock")
            color: root.controller.message ? Theme.warm : Theme.muted
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }
    Popup {
        id: powerMenu
        parent: root
        popupType: Popup.Item
        x: Math.min(root.width-width-20,content.x+content.width-width)
        y: content.y+54
        width: 190
        padding: 8
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { radius: Theme.radius; color: Theme.panel; border.width:1; border.color:Theme.border }
        onClosed: if (root.activeHere) password.forceActiveFocus()
        contentItem: Column {
            spacing: 4
            Repeater {
                model: [{text:"Sleep",action:"suspend"},{text:"Shut Down",action:"shutdown"},{text:"Reboot",action:"reboot"}]
                MenuButton {
                    required property var modelData
                    width: parent.width; height: 36
                    text: modelData.text
                    enabled: !!root.controller.capabilities[modelData.action]
                    onClicked: { powerMenu.close(); root.controller.power(modelData.action); }
                }
            }
        }
    }
    BarText { anchors.centerIn:parent; visible:!root.activeHere; text:"Click to unlock"; font.pixelSize:14; color:Theme.muted }
    SequentialAnimation {
        id: failure
        NumberAnimation { target:shake;property:"x";to:-3;duration:45 }
        NumberAnimation { target:shake;property:"x";to:3;duration:70 }
        NumberAnimation { target:shake;property:"x";to:0;duration:65;easing.type:Easing.OutCubic }
    }
    Connections {
        target: root.controller
        function onClearInputs() { password.clear(); }
        function onFocusPassword() { if (root.activeHere) Qt.callLater(password.forceActiveFocus); }
        function onFailed() { if (root.activeHere) failure.restart(); }
    }
}
