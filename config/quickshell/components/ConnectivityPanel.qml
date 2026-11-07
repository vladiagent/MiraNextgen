import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Wayland
import ".."

PanelWindow {
    id: root
    required property var barWindow
    required property var controller
    readonly property bool isBluetooth: controller.info === "bluetooth"
    property real reveal: controller.info !== "" ? 1 : 0
    implicitWidth: 384
    implicitHeight: Math.min(screen.height - Theme.barHeight - 24, content.implicitHeight + 44)
    visible: controller.info !== "" || reveal > 0.001
    color: "transparent"
    screen: barWindow.screen
    anchors {
        top: true
        left: true
    }
    margins.left: Math.max(8, Math.min(barWindow.width - width - 8, controller.x + controller.parent.x + controller.width / 2 - width / 2))
    margins.top: Theme.barHeight + 1
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.namespace: "quickshell-floating-bar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    mask: Region {
        item: surface
        radius: Theme.radius
    }
    Behavior on reveal {
        NumberAnimation {
            duration: Theme.normal
            easing.type: Easing.OutCubic
        }
    }
    HyprlandFocusGrab {
        active: root.controller.info !== ""
        windows: [root, root.barWindow]
        onCleared: root.controller.info = ""
    }
    Rectangle {
        id: surface
        x: 6
        y: 6 - 4 * (1 - root.reveal)
        width: parent.width - 12
        height: parent.height - 12
        radius: Theme.radius
        color: Theme.panel
        border.width: 1
        border.color: Theme.border
        opacity: root.reveal
        focus: root.controller.info !== ""
        Keys.onEscapePressed: root.controller.info = ""
        Flickable {
            x: 16
            y: 16
            width: parent.width - 32
            height: parent.height - 32
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            Column {
                id: content
                width: parent.width
                spacing: 12
                Item {
                    width: parent.width
                    height: 28
                    BarText {
                        text: root.isBluetooth ? "Bluetooth" : "Wi-Fi"
                        font.pixelSize: 17
                        height: parent.height
                    }
                    IconButton {
                        anchors.right: parent.right
                        icon: "close"
                        tooltip: "Close"
                        onClicked: root.controller.info = ""
                    }
                }
                BarText {
                    width: parent.width
                    text: root.isBluetooth ? root.controller.bluetoothStatus : root.controller.wifiStatus
                    font.pixelSize: 12
                    color: Theme.muted
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                Rectangle {
                    visible: !root.isBluetooth && !!root.controller.wired
                    width: parent.width
                    height: ethernetText.implicitHeight + 22
                    radius: 12
                    color: Theme.hover
                    Icon {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        name: "ethernet"
                        color: Theme.accent
                    }
                    BarText {
                        id: ethernetText
                        x: 38
                        y: 11
                        width: parent.width - 50
                        text: "Ethernet connected · " + (root.controller.wired?.name ?? "")
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                }
                Row {
                    spacing: 8
                    MenuButton {
                        text: root.isBluetooth ? (root.controller.bluetoothEnabled ? "Turn off" : "Turn on") : (Networking.wifiEnabled ? "Turn off" : "Turn on")
                        enabled: root.isBluetooth ? !!root.controller.adapter && !root.controller.bluetoothBusy && root.controller.adapter.state !== BluetoothAdapterState.Blocked : !!root.controller.wifi && Networking.wifiHardwareEnabled
                        onClicked: {
                            if (root.isBluetooth)
                                root.controller.toggleBluetooth();
                            else
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                        }
                    }
                    MenuButton {
                        text: root.isBluetooth && root.controller.adapter?.discovering ? "Stop search" : "Search again"
                        enabled: root.isBluetooth ? root.controller.bluetoothEnabled : !!root.controller.wifi && Networking.wifiEnabled && Networking.wifiHardwareEnabled
                        onClicked: {
                            if (root.isBluetooth) {
                                if (root.controller.adapter.discovering)
                                    root.controller.stopScan();
                                else
                                    root.controller.startScan();
                            } else {
                                root.controller.wifi.scannerEnabled = false;
                                Qt.callLater(() => {
                                    if (root.controller.wifi)
                                        root.controller.wifi.scannerEnabled = true;
                                });
                            }
                        }
                    }
                }
                BarText {
                    visible: root.isBluetooth ? root.controller.bluetoothMessage !== "" : root.controller.wifiMessage !== ""
                    width: parent.width
                    text: root.isBluetooth ? root.controller.bluetoothMessage : root.controller.wifiMessage
                    font.pixelSize: 12
                    color: Theme.warm
                    wrapMode: Text.WrapAnywhere
                    elide: Text.ElideNone
                }
                Rectangle {
                    visible: root.isBluetooth && root.controller.pairingPrompt !== null
                    width: parent.width
                    height: pairingContent.implicitHeight + 24
                    radius: 14
                    color: Theme.hover
                    border.width: 1
                    border.color: Theme.border
                    Column {
                        id: pairingContent
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 10
                        readonly property var prompt: root.controller.pairingPrompt
                        readonly property bool input: prompt?.kind === "pin" || prompt?.kind === "passkey"
                        BarText {
                            width: parent.width
                            text: root.controller.pairingName
                            font.pixelSize: 14
                        }
                        BarText {
                            width: parent.width
                            text: pairingContent.input ? "Enter the PIN shown on the device." : pairingContent.prompt?.kind === "confirm" ? "Confirm that this code matches the other device:" : pairingContent.prompt?.kind === "display" ? "Type this code on the other device, then press Enter:" : "Allow pairing with this device?"
                            font.pixelSize: 12
                            color: Theme.muted
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                        }
                        BarText {
                            visible: !!pairingContent.prompt?.code
                            text: pairingContent.prompt?.code ?? ""
                            font.pixelSize: 24
                            color: Theme.accent
                            font.letterSpacing: 4
                        }
                        MenuField {
                            id: pinInput
                            visible: pairingContent.input
                            width: parent.width
                            placeholderText: pairingContent.prompt?.kind === "passkey" ? "Numeric passkey" : "PIN"
                            maximumLength: pairingContent.prompt?.kind === "passkey" ? 6 : 16
                            echoMode: TextInput.Password
                            Accessible.name: "Bluetooth pairing PIN"
                            onVisibleChanged: {
                                clear();
                                if (visible)
                                    forceActiveFocus();
                            }
                            onAccepted: if (text.length) {
                                root.controller.answerPairing(text);
                                clear();
                            }
                        }
                        Row {
                            spacing: 8
                            MenuButton {
                                text: "Cancel"
                                onClicked: root.controller.cancelPairing()
                            }
                            MenuButton {
                                visible: pairingContent.prompt?.kind !== "display"
                                primary: true
                                text: pairingContent.input ? "Pair" : "Confirm"
                                enabled: !pairingContent.input || pinInput.text.length > 0
                                onClicked: {
                                    root.controller.answerPairing(pairingContent.input ? pinInput.text : true);
                                    pinInput.clear();
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    visible: !root.isBluetooth && root.controller.passwordNetwork !== null
                    width: parent.width
                    height: passwordContent.implicitHeight + 24
                    radius: 14
                    color: Theme.hover
                    Column {
                        id: passwordContent
                        x: 12
                        y: 12
                        width: parent.width - 24
                        spacing: 10
                        BarText {
                            width: parent.width
                            text: root.controller.passwordNetwork?.name ?? ""
                            font.pixelSize: 14
                        }
                        MenuField {
                            id: wifiPassword
                            width: parent.width
                            placeholderText: "Wi-Fi password"
                            echoMode: TextInput.Password
                            maximumLength: 64
                            Accessible.name: "Wi-Fi password"
                            onAccepted: if (text.length) {
                                root.controller.submitPassword(text);
                                clear();
                            }
                        }
                        Row {
                            spacing: 8
                            MenuButton {
                                text: "Cancel"
                                onClicked: {
                                    wifiPassword.clear();
                                    root.controller.passwordNetwork = null;
                                }
                            }
                            MenuButton {
                                text: "Connect"
                                primary: true
                                enabled: wifiPassword.text.length > 0
                                onClicked: {
                                    root.controller.submitPassword(wifiPassword.text);
                                    wifiPassword.clear();
                                }
                            }
                        }
                    }
                    onVisibleChanged: {
                        wifiPassword.clear();
                        if (visible)
                            wifiPassword.forceActiveFocus();
                    }
                }
                Column {
                    visible: root.isBluetooth && root.controller.bluetoothEnabled
                    width: parent.width
                    spacing: 5
                    BarText {
                        text: "Devices"
                        font.pixelSize: 12
                        color: Theme.muted
                    }
                    Repeater {
                        model: root.controller.bluetoothDevices
                        delegate: Rectangle {
                            id: btRow
                            required property var modelData
                            width: content.width
                            height: 66
                            radius: 12
                            color: btHover.hovered ? Theme.hover : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fast
                                }
                            }
                            HoverHandler {
                                id: btHover
                            }
                            Icon {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                name: "bluetooth"
                                color: btRow.modelData.connected ? Theme.accent : Theme.muted
                            }
                            Column {
                                x: 34
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 148
                                spacing: 4
                                BarText {
                                    width: parent.width
                                    text: btRow.modelData.name || btRow.modelData.address
                                    font.pixelSize: 13
                                }
                                BarText {
                                    width: parent.width
                                    font.pixelSize: 11
                                    color: Theme.muted
                                    text: btRow.modelData.pairing ? "Pairing…" : btRow.modelData.state === BluetoothDeviceState.Connecting ? "Connecting…" : btRow.modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…" : btRow.modelData.connected ? "Connected" + (btRow.modelData.batteryAvailable ? " · " + Math.round(btRow.modelData.battery * 100) + "% battery" : "") : btRow.modelData.paired ? "Paired" : "Not paired"
                                }
                            }
                            MenuButton {
                                x: parent.width - width
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.controller.busyAddress === btRow.modelData.address ? "Working…" : btRow.modelData.connected ? "Disconnect" : btRow.modelData.paired ? "Connect" : "Pair"
                                enabled: !root.controller.bluetoothBusy && !btRow.modelData.pairing && ![BluetoothDeviceState.Connecting, BluetoothDeviceState.Disconnecting].includes(btRow.modelData.state)
                                onClicked: root.controller.useBluetoothDevice(btRow.modelData)
                            }
                        }
                    }
                    BarText {
                        visible: root.controller.bluetoothDevices.length === 0
                        width: parent.width
                        text: "No devices found yet. Put your headphones, keyboard or other device in pairing mode, then search again."
                        color: Theme.muted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                }
                Column {
                    visible: !root.isBluetooth && !!root.controller.wifi && Networking.wifiEnabled
                    width: parent.width
                    spacing: 5
                    BarText {
                        text: "Networks"
                        font.pixelSize: 12
                        color: Theme.muted
                    }
                    Repeater {
                        model: root.controller.wifiNetworks
                        delegate: Rectangle {
                            id: wifiRow
                            required property var modelData
                            width: content.width
                            height: 66
                            radius: 12
                            color: wifiHover.hovered ? Theme.hover : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.fast
                                }
                            }
                            HoverHandler {
                                id: wifiHover
                            }
                            Icon {
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                name: "wifi"
                                color: wifiRow.modelData.connected ? Theme.accent : Theme.muted
                            }
                            Column {
                                x: 34
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 148
                                spacing: 4
                                BarText {
                                    width: parent.width
                                    text: wifiRow.modelData.name
                                    font.pixelSize: 13
                                }
                                BarText {
                                    width: parent.width
                                    font.pixelSize: 11
                                    color: Theme.muted
                                    text: (wifiRow.modelData.stateChanging ? ConnectionState.toString(wifiRow.modelData.state) : wifiRow.modelData.connected ? "Connected" : wifiRow.modelData.known ? "Saved" : WifiSecurityType.toString(wifiRow.modelData.security)) + " · " + Math.round(wifiRow.modelData.signalStrength * 100) + "%"
                                }
                            }
                            MenuButton {
                                x: parent.width - width
                                anchors.verticalCenter: parent.verticalCenter
                                text: wifiRow.modelData.connected ? "Disconnect" : "Connect"
                                enabled: !wifiRow.modelData.stateChanging && root.controller.wifi.nmManaged
                                onClicked: root.controller.chooseNetwork(wifiRow.modelData)
                            }
                        }
                    }
                    BarText {
                        visible: root.controller.wifiNetworks.length === 0
                        width: parent.width
                        text: "Searching for networks. If none appear, check the radio switch and try searching again."
                        color: Theme.muted
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                }
                BarText {
                    visible: root.isBluetooth ? !root.controller.adapter || !root.controller.bluetoothEnabled : !root.controller.wifi
                    width: parent.width
                    text: root.isBluetooth ? (root.controller.adapter ? "Turn Bluetooth on to discover and connect to devices." : "Connect a Bluetooth adapter and check that bluetooth.service is running.") : "NetworkManager currently detects no Wi-Fi hardware. Ethernet works independently; plug in a supported Wi-Fi adapter to see wireless networks here."
                    color: Theme.muted
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
                MenuButton {
                    width: parent.width
                    text: root.isBluetooth ? "More Bluetooth settings" : "Advanced network settings"
                    onClicked: {
                        if (root.isBluetooth) {
                            root.controller.info = "";
                            Quickshell.execDetached(["blueman-manager"]);
                        } else
                            root.controller.openNetworkSettings();
                    }
                }
            }
        }
    }
}
