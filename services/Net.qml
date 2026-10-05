//  VELVET  ·  services/Net.qml
//  Network status — Wi-Fi list, connect, toggle. Polls, but cheaply, and
//  degrades to "unknown" rather than breaking when NetworkManager isn't
//  there. Bluetooth lives in its own service now; the old names stay here
//  as aliases so nothing that read them has to change.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ---------------------------------------------------------------- network
    property string type: "none"        // wifi | ethernet | none
    property string ssid: ""
    property int strength: 0            // 0..100
    property bool connected: false
    property bool wifiEnabled: true
    property var networks: []           // { ssid, signal, security, active }
    property bool wifiBusy: false
    property string lastWifiAsk: ""     // the ssid the last connect tried
    property string lastWifiError: ""   // what nmcli said when it failed

    readonly property string icon: {
        if (type === "ethernet")
            return "lan";
        if (type !== "wifi")
            return "signal_wifi_off";
        if (strength >= 75)
            return "network_wifi";
        if (strength >= 50)
            return "network_wifi_3_bar";
        if (strength >= 25)
            return "network_wifi_2_bar";
        if (strength > 0)
            return "network_wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    readonly property string label: connected ? (type === "ethernet" ? "Wired" : ssid) : "Offline"

    // ---------------------------------------------------------------- bluetooth
    // The Bluetooth service owns all of this now. These names stay so the
    // bar's status cluster and the quick panel never had to move.
    readonly property bool btAvailable: Bluetooth.available
    readonly property bool btPowered: Bluetooth.powered
    readonly property int btConnectedCount: Bluetooth.connectedCount
    readonly property string btDeviceName: Bluetooth.connectedName

    function toggleBluetooth(): void {
        Bluetooth.togglePower();
    }

    // ---------------------------------------------------------------- actions
    // nmcli -t escapes ':' as '\:' and '\' as '\\' — undo that for display.
    function unescapeTsv(s: string): string {
        let out = "";
        for (let i = 0; i < s.length; i++) {
            if (s[i] === "\\" && i + 1 < s.length) {
                out += s[i + 1];
                i++;
            } else {
                out += s[i];
            }
        }
        return out;
    }

    function toggleWifi(): void {
        if (!root.wifiEnabled)
            runCmd(`nmcli radio wifi on`);
        else
            runCmd(`nmcli radio wifi off`);
        Toast.show(root.wifiEnabled ? "WI-FI OFF" : "WI-FI ON", "info", 2000);
        refreshLater.restart();
        // Turning it on makes the adapter rescan by itself; a slow refresh
        // after that picks the new list up.
        refreshLater2.restart();
    }

    function refreshNetworks(): void {
        runCmd(`nmcli device wifi rescan`);
        refreshLater.restart();
    }

    function connectWifi(ssid: string, password: string): void {
        const s = `${ssid ?? ""}`.trim();
        if (s.length === 0)
            return;
        root.wifiBusy = true;
        root.lastWifiAsk = s;
        root.lastWifiError = "";
        const q = t => (t ?? "").replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\$/g, "\\$").replace(/`/g, "\\`");
        const pw = `${password ?? ""}`.length > 0 ? ` password "${q(password)}"` : "";
        wifiConnect.command = ["bash", "-c", `nmcli device wifi connect "${q(s)}"${pw} 2>&1; echo "EXIT:$?"`];
        wifiConnect.running = false;
        wifiConnect.running = true;
    }

    function disconnectWifi(): void {
        runCmd(`nmcli device disconnect "$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')"`);
        refreshLater.restart();
    }

    Process {
        id: runOnce
        command: ["true"]
    }

    function runCmd(cmd: string): void {
        runOnce.command = ["bash", "-c", cmd];
        runOnce.running = false;
        runOnce.running = true;
    }

    Process {
        id: wifiConnect

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiBusy = false;
                const out = text.trim();
                if (out.indexOf("EXIT:0") !== -1) {
                    Toast.ok(`CONNECTED TO ${root.lastWifiAsk}`);
                    root.lastWifiError = "";
                    refreshLater.restart();
                    return;
                }
                const lines = out.split("\n").filter(l => l.indexOf("EXIT:") !== 0);
                root.lastWifiError = (lines.pop() ?? "CONNECT FAILED").trim();
                if (root.lastWifiError.length > 90)
                    root.lastWifiError = root.lastWifiError.slice(0, 90) + "…";
                Toast.show(root.lastWifiError.toUpperCase(), "warn", 3800);
            }
        }
    }

    Timer {
        id: refreshLater
        interval: 900
        onTriggered: {
            poll.running = false;
            poll.running = true;
        }
    }

    Timer {
        id: refreshLater2
        interval: 2600
        onTriggered: {
            poll.running = false;
            poll.running = true;
        }
    }

    Timer {
        running: true
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            poll.running = false;
            poll.running = true;
        }
    }

    Process {
        id: poll

        command: ["bash", "-c", `
            nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | grep -m1 ':connected:' || echo 'none:disconnected:'
            echo '---'
            nmcli -t -f IN-USE,SSID,SIGNAL device wifi 2>/dev/null | grep -m1 '^\\*' || echo ''
            echo '---'
            nmcli -t -f WIFI radio 2>/dev/null || echo 'enabled'
            echo '---'
            nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null | head -40
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const blocks = text.split("---");

                // --- device status
                const dev = (blocks[0] ?? "").trim().split(":");
                if (dev[0] === "wifi" || dev[0] === "ethernet") {
                    root.type = dev[0];
                    root.connected = true;
                } else {
                    root.type = "none";
                    root.connected = false;
                    root.ssid = "";
                    root.strength = 0;
                }

                // --- wifi detail
                const wifi = (blocks[1] ?? "").trim();
                if (wifi.startsWith("*")) {
                    const parts = wifi.split(":");
                    root.ssid = parts[1] ?? "";
                    root.strength = parseInt(parts[2]) || 0;
                }

                // --- wifi radio state
                root.wifiEnabled = (blocks[2] ?? "").trim() === "enabled";

                // --- nearby networks, strongest first, one line per ssid
                const nets = [];
                const seen = {};
                const lines = (blocks[3] ?? "").split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(":");
                    if (parts.length < 2)
                        continue;
                    const name = root.unescapeTsv(parts[1] ?? "");
                    if (name.length === 0)
                        continue;
                    const sig = parseInt(parts[2]) || 0;
                    // Strongest AP wins when the same network shows twice.
                    if (seen[name] !== undefined) {
                        if (nets[seen[name]].signal < sig)
                            nets[seen[name]].signal = sig;
                        continue;
                    }
                    seen[name] = nets.length;
                    nets.push({
                        ssid: name,
                        signal: sig,
                        security: root.unescapeTsv(parts[3] ?? ""),
                        active: (parts[0] ?? "").trim() === "*"
                    });
                }
                nets.sort((a, b) => b.signal - a.signal);
                root.networks = nets;
            }
        }
    }
}
