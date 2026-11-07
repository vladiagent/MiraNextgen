import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import ".."
import "../services"

Pill {
    id: root
    required property var barWindow
    property string info: ""
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var network: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool wifiConnected: wifi?.connected ?? false
    readonly property bool bluetoothEnabled: adapter?.enabled ?? false
    readonly property bool networkAvailable: Networking.backend !== NetworkBackendType.None
    readonly property var wifiNetworks: (wifi?.networks.values ?? []).filter(n => n.name !== "").slice().sort((a, b) => Number(b.connected) - Number(a.connected) || Number(b.known) - Number(a.known) || b.signalStrength - a.signalStrength)
    readonly property var bluetoothDevices: (adapter?.devices.values ?? []).slice().sort((a, b) => Number(b.connected) - Number(a.connected) || Number(b.paired) - Number(a.paired) || a.name.localeCompare(b.name))
    readonly property string wifiStatus: !networkAvailable ? "NetworkManager is unavailable" : !wifi ? "No Wi-Fi adapter detected" : !Networking.wifiHardwareEnabled ? "Wi-Fi blocked by hardware switch" : !Networking.wifiEnabled ? "Wi-Fi is off" : !wifi.nmManaged ? "Wi-Fi is unmanaged" : network ? "Connected to " + network.name : "Wi-Fi is on · Not connected"
    readonly property string bluetoothStatus: !adapter ? "No Bluetooth adapter detected" : adapter.state === BluetoothAdapterState.Blocked ? "Bluetooth blocked by hardware switch" : bluetoothEnabled ? (adapter.discovering ? "Searching for nearby devices…" : "Bluetooth is on · " + adapter.name) : "Bluetooth is off"
    property var targetNetwork: null
    property var passwordNetwork: null
    property string wifiMessage: ""
    property string bluetoothMessage: ""
    property var pairingPrompt: null
    property string pairingName: ""
    property string busyAddress: ""
    readonly property bool bluetoothBusy: bluetoothAction.running || pairing.running
    property var scanAdapter: null
    implicitWidth: 110
    highlighted: info !== ""

    onInfoChanged: {
        if (info === "bluetooth")
            Qt.callLater(startScan);
        else {
            stopScan();
            if (pairing.running)
                cancelPairing();
        }
        passwordNetwork = null;
    }
    onBluetoothEnabledChanged: {
        if (bluetoothEnabled && info === "bluetooth")
            Qt.callLater(startScan);
        else if (!bluetoothEnabled)
            stopScan();
    }
    Component.onDestruction: stopScan()

    function startScan(): void {
        if (!adapter?.enabled || info !== "bluetooth")
            return;
        scanAdapter = adapter;
        scanAdapter.discovering = true;
        scanTimer.restart();
    }
    function stopScan(): void {
        scanTimer.stop();
        if (scanAdapter)
            scanAdapter.discovering = false;
        scanAdapter = null;
    }
    function toggleBluetooth(): void {
        if (!adapter || bluetoothBusy)
            return;
        bluetoothMessage = "";
        bluetoothAction.exec(["bluetoothctl", "--timeout", "20", "power", bluetoothEnabled ? "off" : "on"]);
    }
    function useBluetoothDevice(device): void {
        if (bluetoothBusy)
            return;
        bluetoothMessage = "";
        busyAddress = device.address;
        if (device.paired || device.connected) {
            bluetoothAction.exec(["bluetoothctl", "--timeout", "25", device.connected ? "disconnect" : "connect", device.address]);
        } else {
            pairingName = device.name || device.address;
            pairingPrompt = null;
            pairing.exec(["python", "-B", Quickshell.shellDir + "/scripts/bluetooth-pair.py", device.dbusPath]);
        }
    }
    function answerPairing(value): void {
        if (pairing.running && pairingPrompt)
            pairing.write(JSON.stringify({
                action: "respond",
                id: pairingPrompt.id,
                value: value
            }) + "\n");
    }
    function cancelPairing(): void {
        if (pairing.running)
            pairing.write(JSON.stringify({
                action: "cancel"
            }) + "\n");
    }
    function usesPsk(n): bool {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(n.security);
    }
    function chooseNetwork(n): void {
        if (n.stateChanging)
            return;
        wifiMessage = "";
        passwordNetwork = null;
        targetNetwork = n;
        if (n.connected)
            n.disconnect();
        else if (n.known || n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe)
            n.connect();
        else if (usesPsk(n))
            passwordNetwork = n;
        else
            openNetworkSettings();
    }
    function submitPassword(password): void {
        if (!passwordNetwork || password.length === 0)
            return;
        targetNetwork = passwordNetwork;
        passwordNetwork = null;
        wifiMessage = "";
        targetNetwork.connectWithPsk(password);
    }
    function openNetworkSettings(): void {
        info = "";
        Quickshell.execDetached(["kitty", "--class", "quickshell-network", "nmtui"]);
    }

    Timer {
        id: scanTimer
        interval: 30000
        onTriggered: root.stopScan()
    }
    Binding {
        target: root.wifi
        property: "scannerEnabled"
        value: root.info === "wifi" && Networking.wifiEnabled
        when: root.wifi !== null
    }
    Connections {
        target: root.targetNetwork
        function onConnectionFailed(reason) {
            root.wifiMessage = "Connection failed: " + ConnectionFailReason.toString(reason);
            if (reason === ConnectionFailReason.NoSecrets && root.targetNetwork && root.usesPsk(root.targetNetwork)) {
                root.wifiMessage = "A password is required. Check it and try again.";
                root.passwordNetwork = root.targetNetwork;
            }
        }
    }
    Process {
        id: bluetoothAction
        stdout: StdioCollector {
            id: actionOutput
        }
        stderr: StdioCollector {
            id: actionError
        }
        onExited: (code, status) => {
            root.bluetoothMessage = code === 0 ? "" : (actionError.text.trim() || actionOutput.text.trim() || "Bluetooth operation failed");
            root.busyAddress = "";
        }
    }
    Process {
        id: pairing
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const event = JSON.parse(line);
                    if (["pin", "passkey", "confirm", "authorize", "display"].includes(event.kind)) {
                        root.pairingPrompt = event;
                        root.bluetoothMessage = "";
                    } else if (event.kind === "clear")
                        root.pairingPrompt = null;
                    else {
                        root.bluetoothMessage = event.message || "";
                        if (["done", "error"].includes(event.kind))
                            root.pairingPrompt = null;
                    }
                } catch (error) {
                    root.bluetoothMessage = "Could not read pairing response";
                }
            }
        }
        stderr: StdioCollector {
            id: pairingError
        }
        onExited: (code, status) => {
            root.pairingPrompt = null;
            root.busyAddress = "";
            if (code !== 0 && !root.bluetoothMessage)
                root.bluetoothMessage = pairingError.text.trim() || "Pairing failed. Try again or open Bluetooth settings.";
        }
    }
    IpcHandler {
        target: "connectivity-" + root.barWindow.screen.name
        function open(menu: string): void {
            if (["wifi", "bluetooth", ""].includes(menu))
                root.info = menu;
        }
        function status(): string {
            return JSON.stringify({
                menu: root.info,
                wifi: root.wifiStatus,
                ethernet: !!root.wired,
                bluetooth: root.bluetoothStatus,
                scanning: root.adapter?.discovering ?? false,
                devices: root.bluetoothDevices.map(d => ({
                            name: d.name,
                            paired: d.paired,
                            connected: d.connected
                        })),
                networks: root.wifiNetworks.map(n => ({
                            name: n.name,
                            connected: n.connected,
                            known: n.known
                        }))
            });
        }
    }
    Row {
        anchors.centerIn: parent
        spacing: 2
        IconButton {
            icon: root.wifiConnected ? "wifi" : root.wired ? "ethernet" : "wifiOff"
            active: root.wifiConnected || !!root.wired
            tooltip: root.wifiStatus + (root.wired ? " · Ethernet connected" : "")
            onClicked: root.info = root.info === "wifi" ? "" : "wifi"
        }
        IconButton {
            icon: "bluetooth"
            active: root.bluetoothEnabled
            tooltip: root.bluetoothStatus + " · Click for devices"
            onClicked: root.info = root.info === "bluetooth" ? "" : "bluetooth"
        }
        IconButton {
            icon: "sleep"
            active: NotificationService.dnd
            tooltip: "Do Not Disturb " + (NotificationService.dnd ? "on" : "off")
            onClicked: NotificationService.toggleDnd()
        }
    }
    ConnectivityPanel {
        barWindow: root.barWindow
        controller: root
    }
}
