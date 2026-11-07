import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQml.Models
import "."

Rectangle {
    id: root
    objectName: "greeter"
    width: 1920
    height: 1080
    color: Theme.background
    property bool busy: false
    property bool manualUser: userModel.count === 0
    property string selectedUser: userModel.lastUser || ""
    property string selectedName: selectedUser
    property string selectedAvatar: ""
    property string message: ""
    property real appearance: 0
    property real userAppearance: 1
    property date now: new Date()
    property string powerAction: ""
    readonly property string loginUser: manualUser ? username.text.trim() : selectedUser

    function updateUser() {
        const entry = users.objectAt(userPicker.currentIndex);
        if (!entry)
            return;
        selectedUser = entry.account;
        selectedName = entry.displayName || entry.account;
        selectedAvatar = entry.avatar;
        message = "";
        password.clear();
        userTransition.restart();
        if (!manualUser)
            password.forceActiveFocus();
    }
    function submit() {
        if (busy || !loginUser || sessionPicker.currentIndex < 0)
            return;
        busy = true;
        message = "";
        sddm.login(loginUser, password.text, sessionPicker.currentIndex);
        password.clear();
    }
    function runPower() {
        const action = powerAction;
        powerAction = "";
        powerPopup.close();
        if (action === "shutdown" && sddm.canPowerOff)
            sddm.powerOff();
        else if (action === "reboot" && sddm.canReboot)
            sddm.reboot();
    }
    Component.onCompleted: {
        appearance = 1;
        Qt.callLater(updateUser);
    }
    Behavior on appearance {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    NumberAnimation {
        id: userTransition
        target: root
        property: "userAppearance"
        from: 0
        to: 1
        duration: Theme.normal
        easing.type: Easing.OutCubic
    }
    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        onTriggered: root.now = new Date()
    }
    Connections {
        target: sddm
        ignoreUnknownSignals: true
        function onLoginFailed() {
            root.busy = false;
            root.message = qsTr("Incorrect password. Try again.");
            password.clear();
            password.forceActiveFocus();
            errorMotion.restart();
        }
        function onLoginSucceeded() {
            password.clear();
        }
        function onInformationMessage(message) {
            root.message = message;
        }
    }
    Instantiator {
        id: users
        model: userModel
        delegate: QtObject {
            required property string name
            required property string realName
            required property string icon
            readonly property string account: name
            readonly property string displayName: realName
            readonly property string avatar: icon
        }
        onObjectAdded: Qt.callLater(root.updateUser)
    }
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Theme.asset("wallpaper.png")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }
    Rectangle {
        anchors.fill: parent
        color: "#16000000"
    }

    Rectangle {
        id: clockPill
        width: time.implicitWidth + 32
        height: 38
        anchors.horizontalCenter: parent.horizontalCenter
        y: 20 - 4 * (1 - root.appearance)
        radius: Theme.radius
        color: Theme.pill
        border.width: 1
        border.color: Theme.border
        opacity: root.appearance
        Label {
            id: time
            anchors.centerIn: parent
            text: Qt.formatDateTime(root.now, "HH:mm")
            font.pixelSize: 17
        }
    }
    Label {
        anchors.top: clockPill.bottom
        anchors.topMargin: 9
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(root.now, "dddd, d MMMM")
        font.pixelSize: 12
        color: Theme.muted
        opacity: root.appearance
    }
    ShaderEffectSource {
        id: cardCrop
        sourceItem: wallpaper
        sourceRect: Qt.rect(card.x, card.y, card.width, card.height)
        textureSize: Qt.size(Math.ceil(card.width / 2), Math.ceil(card.height / 2))
        visible: false
    }
    Rectangle {
        id: cardMask
        width: card.width
        height: card.height
        radius: Theme.radius
        color: "white"
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: card
        source: cardCrop
        blurEnabled: true
        blurMax: 24
        blur: 1
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: cardMask
        opacity: root.appearance
        visible: GraphicsInfo.api !== GraphicsInfo.Software
    }
    Rectangle {
        x: card.x - 1
        y: card.y + 4
        width: card.width + 2
        height: card.height + 2
        radius: Theme.radius + 1
        color: "#18000000"
        opacity: root.appearance
    }
    Rectangle {
        id: card
        width: Math.min(360, root.width - 40)
        height: form.implicitHeight + 44
        x: (root.width - width) / 2
        y: Math.max(115, (root.height - height) / 2 - 12) + 8 * (1 - root.appearance)
        radius: Theme.radius
        color: Theme.panel
        border.width: 1
        border.color: Theme.border
        opacity: root.appearance
        Column {
            id: form
            x: 22
            y: 22
            width: parent.width - 44
            spacing: 12
            Item {
                width: parent.width
                height: 62
                opacity: root.userAppearance
                Rectangle {
                    width: 60
                    height: 60
                    radius: 30
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.activeSurface
                    border.width: 1
                    border.color: Theme.alpha(Theme.accent, 0.25)
                    Label {
                        anchors.centerIn: parent
                        visible: avatar.status !== Image.Ready || root.manualUser
                        text: (root.manualUser ? "?" : root.selectedName.substring(0, 1).toUpperCase())
                        font.pixelSize: 25
                        color: Theme.accent
                    }
                    Image {
                        id: avatar
                        anchors.fill: parent
                        source: root.manualUser ? "" : root.selectedAvatar
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    Rectangle {
                        id: avatarMask
                        width: 60
                        height: 60
                        radius: 30
                        color: "white"
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: avatar
                        maskEnabled: true
                        maskSource: avatarMask
                        visible: avatar.status === Image.Ready
                    }
                }
            }
            Label {
                width: parent.width
                height: 28
                horizontalAlignment: Text.AlignHCenter
                text: root.manualUser ? qsTr("Sign in") : root.selectedName
                font.pixelSize: 22
                opacity: root.userAppearance
            }
            Selector {
                id: userPicker
                objectName: "userPicker"
                visible: userModel.count > 1 && !root.manualUser
                width: parent.width
                model: userModel
                textRole: "name"
                currentIndex: Math.max(0, userModel.lastIndex)
                displayText: root.selectedUser
                enabled: !root.busy
                onCurrentIndexChanged: Qt.callLater(root.updateUser)
                Accessible.name: qsTr("User account")
            }
            TextField {
                id: username
                objectName: "username"
                visible: root.manualUser
                width: parent.width
                height: 40
                font.family: Theme.fontFamily
                font.pixelSize: 13
                color: Theme.text
                placeholderTextColor: Theme.muted
                placeholderText: qsTr("Username")
                selectByMouse: true
                enabled: !root.busy
                leftPadding: 14
                rightPadding: 14
                background: Rectangle {
                    radius: Theme.radius
                    color: Theme.hover
                    border.width: 1
                    border.color: username.activeFocus ? Theme.accent : Theme.border
                }
                onAccepted: password.forceActiveFocus()
                Accessible.name: qsTr("Username")
            }
            Item {
                id: fieldHolder
                width: parent.width
                height: 42
                property real offset: 0
                TextField {
                    id: password
                    objectName: "password"
                    x: fieldHolder.offset
                    width: parent.width
                    height: parent.height
                    focus: !root.manualUser
                    enabled: !root.busy
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    placeholderText: qsTr("Password")
                    color: Theme.text
                    placeholderTextColor: Theme.muted
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.surface
                    font.family: Theme.fontFamily
                    font.weight: Font.Normal
                    font.pixelSize: 14
                    leftPadding: 16
                    rightPadding: 16
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhHiddenText
                    onAccepted: root.submit()
                    onTextEdited: if (root.message)
                        root.message = ""
                    Accessible.name: qsTr("Password")
                    background: Rectangle {
                        radius: Theme.radius
                        color: Theme.hover
                        border.width: 1
                        border.color: root.message ? Theme.error : password.activeFocus ? Theme.alpha(Theme.accent, 0.85) : Theme.border
                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.fast
                            }
                        }
                    }
                }
                SequentialAnimation {
                    id: errorMotion
                    NumberAnimation {
                        target: fieldHolder
                        property: "offset"
                        to: -3
                        duration: 45
                    }
                    NumberAnimation {
                        target: fieldHolder
                        property: "offset"
                        to: 3
                        duration: 70
                    }
                    NumberAnimation {
                        target: fieldHolder
                        property: "offset"
                        to: 0
                        duration: 65
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Label {
                id: feedback
                width: parent.width
                height: Math.max(16, implicitHeight)
                horizontalAlignment: Text.AlignHCenter
                text: root.message || (keyboard.capsLock ? qsTr("Caps Lock is on") : "")
                color: root.message ? Theme.error : Theme.warning
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                Accessible.role: Accessible.AlertMessage
                Accessible.name: text
            }
            Action {
                id: loginButton
                objectName: "loginButton"
                width: parent.width
                text: root.busy ? qsTr("Logging in…") : qsTr("Log In")
                accent: true
                enabled: !root.busy && !!root.loginUser && sessionPicker.currentIndex >= 0
                onClicked: root.submit()
            }
            Action {
                visible: userModel.count > 0 && (!userModel.containsAllUsers || root.manualUser)
                anchors.horizontalCenter: parent.horizontalCenter
                height: 26
                font.pixelSize: 11
                text: root.manualUser && userModel.count > 0 ? qsTr("Back to users") : qsTr("Other user")
                enabled: !root.busy
                onClicked: {
                    root.manualUser = !root.manualUser;
                    root.message = "";
                    password.clear();
                    if (root.manualUser)
                        username.forceActiveFocus();
                    else {
                        root.updateUser();
                        password.forceActiveFocus();
                    }
                }
            }
        }
    }
    Row {
        id: secondary
        x: card.x
        y: card.y + card.height + 12
        width: card.width
        spacing: 8
        opacity: root.appearance
        Selector {
            id: sessionPicker
            objectName: "sessionPicker"
            width: parent.width - (layoutPicker.visible ? layoutPicker.width + 8 : 0) - 42
            model: sessionModel
            textRole: "name"
            currentIndex: sessionModel.count > 0 ? Math.max(0, Math.min(sessionModel.lastIndex, sessionModel.count - 1)) : -1
            enabled: !root.busy && sessionModel.count > 1
            displayText: sessionModel.count === 0 ? qsTr("No sessions installed") : currentText
            Accessible.name: qsTr("Desktop session")
        }
        Selector {
            id: layoutPicker
            visible: keyboard.enabled && keyboard.layouts.length > 0
            width: 66
            model: keyboard.layouts
            textRole: "shortName"
            currentIndex: keyboard.currentLayout
            displayText: currentText.toUpperCase()
            enabled: !root.busy && keyboard.layouts.length > 1
            onActivated: keyboard.currentLayout = currentIndex
            Accessible.name: qsTr("Keyboard layout")
        }
        Action {
            id: powerButton
            objectName: "powerButton"
            implicitWidth: 34
            width: 34
            height: 34
            enabled: !root.busy && (sddm.canSuspend || sddm.canReboot || sddm.canPowerOff)
            Accessible.name: qsTr("Power options")
            contentItem: Canvas {
                onPaint: {
                    const painter = getContext("2d");
                    painter.reset();
                    painter.scale(width / 24, height / 24);
                    painter.strokeStyle = Theme.text;
                    painter.lineWidth = 1.7;
                    painter.lineCap = "round";
                    painter.beginPath();
                    painter.arc(12, 12, 8, -Math.PI / 4, 5 * Math.PI / 4);
                    painter.moveTo(12, 3);
                    painter.lineTo(12, 11);
                    painter.stroke();
                }
                Connections {
                    target: Theme
                    function onTextChanged() {
                        powerButton.contentItem.requestPaint();
                    }
                }
            }
            onClicked: {
                root.powerAction = "";
                powerPopup.open();
            }
        }
    }
    Popup {
        id: powerPopup
        objectName: "powerPopup"
        x: Math.min(root.width - width - 20, secondary.x + secondary.width - width)
        y: Math.min(root.height - height - 20, secondary.y + secondary.height + 8)
        width: 224
        padding: 12
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            radius: Theme.radius
            color: Theme.panel
            border.width: 1
            border.color: Theme.border
        }
        onClosed: root.powerAction = ""
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
        contentItem: Column {
            spacing: 6
            Label {
                visible: root.powerAction !== ""
                width: parent.width
                height: 30
                text: root.powerAction === "reboot" ? qsTr("Restart the computer?") : qsTr("Shut down the computer?")
                font.pixelSize: 13
            }
            Action {
                visible: root.powerAction === "" && sddm.canSuspend
                width: parent.width
                text: qsTr("Suspend")
                onClicked: {
                    powerPopup.close();
                    sddm.suspend();
                }
            }
            Action {
                visible: root.powerAction === "" && sddm.canReboot
                width: parent.width
                text: qsTr("Reboot")
                onClicked: root.powerAction = "reboot"
            }
            Action {
                visible: root.powerAction === "" && sddm.canPowerOff
                width: parent.width
                text: qsTr("Shut Down")
                onClicked: root.powerAction = "shutdown"
            }
            Action {
                visible: root.powerAction !== ""
                width: parent.width
                text: qsTr("Cancel")
                onClicked: root.powerAction = ""
            }
            Action {
                visible: root.powerAction !== ""
                width: parent.width
                accent: true
                text: qsTr("Confirm")
                onClicked: root.runPower()
            }
        }
    }
    Label {
        x: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        text: "vladi-dots"
        font.pixelSize: 12
        color: Theme.muted
        opacity: 0.75
    }
    Label {
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 22
        text: sddm.hostName
        font.pixelSize: 12
        color: Theme.muted
        opacity: 0.75
    }
}
