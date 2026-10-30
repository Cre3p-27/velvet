//  VELVET  ·  services/Net.qml
//  Network status — Wi-Fi list, connect, toggle. Polls, but cheaply, and
//  degrades to "unknown" rather than breaking when NetworkManager isn't
//  there. Bluetooth lives in its own service now; the old names stay here
//  as aliases so nothing that read them has to change.
pragma Singleton

import qs.config
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
    // The network a connect is on its way to. Everything reads as joined the
    // moment you click (the list, the label, the bar): NetworkManager confirms
    // in the background and only a refusal turns it back. No spinners.
    property string joining: ""
    // A search for networks is under way (RESCAN, Wi-Fi switched on, a list
    // opened after a while): the lists show placeholder rows meanwhile.
    property bool scanning: false
    property double lastScan: 0

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

    // ---------------------------------------------------------------- LAN
    // The first wired port: its state, whether a cable is in (the carrier),
    // the speed it agreed on (Mb/s, -1 unknown), the address it got and the
    // profile it runs. NetworkManager's states: 100 connected, 40–90 on its
    // way, 30 disconnected, 20 unavailable (no cable), 10 unmanaged.
    property string ethDevice: ""
    property int ethState: 0
    property bool ethCable: false
    property int ethSpeed: -1
    property string ethIp: ""
    property string ethConnection: ""
    readonly property bool ethConnected: root.ethState === 100
    readonly property bool ethConnecting: root.ethState >= 40 && root.ethState < 100
    readonly property bool hasLan: root.ethDevice !== ""
    // the lever's side (WLAN | LAN): on the cable while it carries the
    // connection, or while a switch to it is on its way
    readonly property bool onLan: root.lanSwitch !== "" ? root.lanSwitch === "lan" : root.ethConnected
    property string lanSwitch: ""       // "lan" | "wifi" while the lever's switch runs
    property string wifiDevice: ""
    // the shell's own wired profile (LAN → ADDRESS): yours, so its address can
    // change without an administrator password
    readonly property string ownProfile: "Velvet LAN"
    property bool ownProfileExists: false

    readonly property string lanLine: {
        if (!root.hasLan)
            return "NO NETWORK PORT FOUND";
        if (!root.ethCable)
            return "NO CABLE IN";
        if (root.ethConnecting)
            return "CONNECTING…";
        if (!root.ethConnected)
            return root.ethSpeed > 0 ? `CABLE IN · ${root.speedText} · NOT CONNECTED` : "CABLE IN · NOT CONNECTED";
        return `CONNECTED · ${root.speedText}${root.ethIp !== "" ? " · " + root.ethIp.split("/")[0] : ""}`;
    }
    readonly property string speedText: root.ethSpeed >= 1000 ? `${root.ethSpeed / 1000} GBIT/S` : (root.ethSpeed > 0 ? `${root.ethSpeed} MBIT/S` : "SPEED UNKNOWN")

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

    // ---------------------------------------------------------------- the lever
    //  WLAN ⇄ LAN. To the cable: connect it, and only once it is up let the
    //  Wi-Fi go (its radio stays on, so the way back is quick). Back to
    //  WLAN: the Wi-Fi joins a network it knows, and only then the cable is
    //  let go — a switch never leaves you offline. Returns false when the
    //  cable side cannot be had (no cable): the lever springs back.
    function useLan(on: bool): bool {
        if (on && (!root.hasLan || !root.ethCable)) {
            Toast.show(root.hasLan ? `NO CABLE IN ${root.ethDevice.toUpperCase()} — PLUG ONE IN AND FLIP AGAIN` : "THIS PC HAS NO NETWORK PORT", "warn", 3600);
            return false;
        }
        if (on === root.onLan && root.lanSwitch === "")
            return true;
        root.lanSwitch = on ? "lan" : "wifi";
        const q = t => `'${`${t ?? ""}`.replace(/'/g, "'\\''")}'`;
        const eth = q(root.ethDevice);
        const own = q(root.ownProfile);
        const script = on ? `
            wifi=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')
            if nmcli -t -f NAME connection show | grep -qxF ${own}; then out=$(nmcli connection up ${own} ifname ${eth} 2>&1); else out=$(nmcli device connect ${eth} 2>&1); fi
            if [ $? -ne 0 ]; then echo "ERR:$(echo "$out" | tail -1)"; exit 0; fi
            [ -n "$wifi" ] && nmcli device disconnect "$wifi" >/dev/null 2>&1
            echo "OK:lan"
        ` : `
            wifi=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')
            [ -n "$wifi" ] || { echo "ERR:NO WI-FI CARD"; exit 0; }
            nmcli radio wifi on >/dev/null 2>&1
            out=$(nmcli device connect "$wifi" 2>&1)
            if [ $? -ne 0 ]; then echo "ERR:NOWIFI:$(echo "$out" | tail -1)"; exit 0; fi
            nmcli device disconnect ${eth} >/dev/null 2>&1
            echo "OK:wifi"
        `;
        lever.command = ["bash", "-c", script];
        lever.running = false;
        lever.running = true;
        return true;
    }

    function connectLan(): void {
        root.useLan(true);
    }

    function disconnectLan(): void {
        if (!root.hasLan)
            return;
        root.ethState = 30;
        runCmd(`nmcli device disconnect '${root.ethDevice}'`);
        refreshLater.restart();
    }

    Process {
        id: lever

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim().split("\n").pop() ?? "";
                const toLan = root.lanSwitch === "lan";
                root.lanSwitch = "";
                if (out.startsWith("OK:")) {
                    Toast.ok(toLan ? `ON THE CABLE · ${root.speedText}` : `ON WI-FI${root.ssid !== "" ? " · " + root.ssid : ""}`);
                } else if (out.startsWith("ERR:NOWIFI")) {
                    Toast.show("NO WI-FI YOU HAVE USED BEFORE IS IN RANGE — PICK ONE BELOW; THE CABLE STAYS ON", "warn", 4400);
                } else {
                    Toast.show(`${toLan ? "THE CABLE" : "WI-FI"} DID NOT CONNECT: ${out.replace(/^ERR:/, "").toUpperCase().slice(0, 80)}`, "warn", 4400);
                }
                poll.running = false;
                poll.running = true;
                refreshLater2.restart();
            }
        }
    }

    // ---------------------------------------------------------------- LAN → ADDRESS
    //  A fixed address (or back to automatic) on the shell's own wired
    //  profile, made the first time and yours (connection.permissions), so
    //  NetworkManager lets you change it without an administrator password.
    //  It takes over from the system's profile on this port.
    function applyLan(): void {
        if (!root.hasLan) {
            Toast.show("THIS PC HAS NO NETWORK PORT", "warn", 3000);
            return;
        }
        const manual = Config.lan.method === "manual";
        const addr = `${Config.lan.address ?? ""}`.trim();
        const gw = `${Config.lan.gateway ?? ""}`.trim();
        const dns = `${Config.lan.dns ?? ""}`.trim().replace(/[,;]+/g, " ").replace(/\s+/g, " ");
        if (manual && !/^\d{1,3}(\.\d{1,3}){3}(\/\d{1,2})?$/.test(addr)) {
            Toast.show("ADDRESS FIRST — LIKE 192.168.178.50/24", "warn", 3600);
            return;
        }
        const withPrefix = addr.indexOf("/") >= 0 ? addr : `${addr}/24`;
        const q = t => `'${`${t ?? ""}`.replace(/'/g, "'\\''")}'`;
        const own = q(root.ownProfile);
        const eth = q(root.ethDevice);
        const ip = manual ? `ipv4.method manual ipv4.addresses ${q(withPrefix)} ipv4.gateway ${q(gw)}` : `ipv4.method auto ipv4.addresses '' ipv4.gateway ''`;
        const script = `
            if ! nmcli -t -f NAME connection show | grep -qxF ${own}; then
              out=$(nmcli connection add type ethernet ifname ${eth} con-name ${own} connection.permissions "user:$USER" connection.autoconnect ${Config.lan.autoconnect ? "yes" : "no"} connection.autoconnect-priority 10 2>&1) || { echo "ERR:$(echo "$out" | tail -1)"; exit 0; }
            fi
            out=$(nmcli connection modify ${own} connection.autoconnect ${Config.lan.autoconnect ? "yes" : "no"} ${ip} ipv4.dns ${q(dns)} ipv4.ignore-auto-dns ${dns !== "" ? "yes" : "no"} 2>&1) || { echo "ERR:$(echo "$out" | tail -1)"; exit 0; }
            if [ "$(cat /sys/class/net/${root.ethDevice}/carrier 2>/dev/null)" = "1" ]; then
              out=$(nmcli connection up ${own} ifname ${eth} 2>&1) || { echo "ERR:$(echo "$out" | tail -1)"; exit 0; }
            fi
            echo OK
        `;
        lanApply.command = ["bash", "-c", script];
        lanApply.running = false;
        lanApply.running = true;
        Toast.show("SETTING UP THE CABLE…", "info", 2000);
    }

    // Back to the system's own profile (automatic, as it came): the shell's
    // profile is switched off, not deleted.
    function lanBackToSystem(): void {
        const own = `'${root.ownProfile}'`;
        lanApply.command = ["bash", "-c", `nmcli connection modify ${own} connection.autoconnect no >/dev/null 2>&1; nmcli connection down ${own} >/dev/null 2>&1; nmcli device connect '${root.ethDevice}' >/dev/null 2>&1; echo OK`];
        lanApply.running = false;
        lanApply.running = true;
    }

    Process {
        id: lanApply

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim().split("\n").pop() ?? "";
                if (out === "OK")
                    Toast.ok(root.ethCable ? "THE CABLE IS SET UP" : "SAVED — IT CONNECTS WHEN A CABLE GOES IN");
                else
                    Toast.show(`THE CABLE COULD NOT BE SET UP: ${out.replace(/^ERR:/, "").toUpperCase().slice(0, 90)}`, "warn", 5200);
                poll.running = false;
                poll.running = true;
            }
        }
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
        // the switch moves when you flip it, not when nmcli answers
        const wasOn = root.wifiEnabled;
        root.wifiEnabled = !wasOn;
        if (wasOn) {
            root.connected = root.type === "ethernet";
            root.type = root.connected ? "ethernet" : "none";
            root.networks = [];
        }
        if (!wasOn)
            runCmd(`nmcli radio wifi on`);
        else
            runCmd(`nmcli radio wifi off`);
        Toast.show(wasOn ? "WI-FI OFF" : "WI-FI ON", "info", 2000);
        refreshLater.restart();
        // Turning it on makes the adapter rescan by itself; slower refreshes
        // after that pick the new list up.
        refreshLater2.restart();
        if (!wasOn) {
            root.scanning = true;
            root.lastScan = Date.now();
            scanDone.restart();
        } else {
            root.scanning = false;
        }
    }

    // A real scan: results come in over a few seconds, so the list is read
    // three times (the old single read after 0.9 s mostly got the old list).
    function refreshNetworks(): void {
        if (!root.wifiEnabled)
            return;
        root.scanning = true;
        root.lastScan = Date.now();
        runCmd(`nmcli device wifi rescan`);
        refreshLater.interval = 1200;
        refreshLater.restart();
        refreshLater2.restart();
        scanDone.restart();
    }

    // A list was opened: search again if the last search is older than 30 s.
    function scanIfStale(): void {
        if (root.wifiEnabled && !root.scanning && Date.now() - root.lastScan > 30000)
            root.refreshNetworks();
    }

    function connectWifi(ssid: string, password: string): void {
        const s = `${ssid ?? ""}`.trim();
        if (s.length === 0)
            return;
        root.wifiBusy = true;
        root.lastWifiAsk = s;
        root.lastWifiError = "";
        root.joining = s;
        root.markActive(s);
        const q = t => (t ?? "").replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\$/g, "\\$").replace(/`/g, "\\`");
        const pw = `${password ?? ""}`.length > 0 ? ` password "${q(password)}"` : "";
        wifiConnect.command = ["bash", "-c", `nmcli device wifi connect "${q(s)}"${pw} 2>&1; echo "EXIT:$?"`];
        wifiConnect.running = false;
        wifiConnect.running = true;
    }

    // the list, the label and the icon as if `ssid` were joined already
    function markActive(ssid: string): void {
        const nets = [];
        let sig = 0;
        for (let i = 0; i < root.networks.length; i++) {
            const n = root.networks[i];
            if (n.ssid === ssid)
                sig = n.signal;
            nets.push({
                ssid: n.ssid,
                signal: n.signal,
                security: n.security,
                active: ssid !== "" && n.ssid === ssid
            });
        }
        // joined first, then strongest — where the eye already is
        nets.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
        root.networks = nets;
        if (ssid !== "") {
            root.type = "wifi";
            root.ssid = ssid;
            root.strength = sig || root.strength || 60;
            root.connected = true;
        }
    }

    function disconnectWifi(): void {
        if (root.type === "wifi") {
            root.connected = false;
            root.type = "none";
            root.ssid = "";
            root.strength = 0;
            root.markActive("");
        }
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
                root.joining = "";
                const out = text.trim();
                if (out.indexOf("EXIT:0") !== -1) {
                    Toast.ok(`CONNECTED TO ${root.lastWifiAsk}`);
                    root.lastWifiError = "";
                    poll.running = false;
                    poll.running = true;
                    return;
                }
                // refused: back to what is really there, right away
                poll.running = false;
                poll.running = true;
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
        interval: 3200
        onTriggered: {
            poll.running = false;
            poll.running = true;
        }
    }

    Timer {
        id: scanDone
        interval: 6000
        onTriggered: {
            poll.running = false;
            poll.running = true;
            root.scanning = false;
        }
    }

    Timer {
        running: true
        // a fullscreen game hides the bar: four nmcli calls every 20 s, not 5
        interval: Hypr.allCovered ? 20000 : 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            poll.running = false;
            poll.running = true;
        }
    }

    // Every 5 s: the device, the joined network's signal, the radio and the
    // list — ALL with --rescan no. A plain `nmcli device wifi` makes the card
    // scan whenever its list is older than 30 s (nmcli(1)): the Wi-Fi went off
    // the air for a scan every half minute, for a signal bar.
    Process {
        id: poll

        command: ["bash", "-c", `
            nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | grep -m1 ':connected:' || echo 'none:disconnected:'
            echo '---'
            nmcli -t -f IN-USE,SSID,SIGNAL device wifi list --rescan no 2>/dev/null | grep -m1 '^\\*' || echo ''
            echo '---'
            nmcli -t -f WIFI radio 2>/dev/null || echo 'enabled'
            echo '---'
            nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY,FREQ device wifi list --rescan no 2>/dev/null | head -40
            echo '---'
            d=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="ethernet"{print $1; exit}')
            if [ -n "$d" ]; then
              echo "dev=$d"
              echo "carrier=$(cat /sys/class/net/$d/carrier 2>/dev/null || echo 0)"
              echo "speed=$(cat /sys/class/net/$d/speed 2>/dev/null || echo -1)"
              nmcli -t -f GENERAL.STATE,GENERAL.CONNECTION,IP4.ADDRESS device show "$d" 2>/dev/null | head -3
            fi
            echo "wifidev=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')"
            nmcli -t -f NAME connection show 2>/dev/null | grep -qxF 'Velvet LAN' && echo "own=1"
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const blocks = text.split("---");
                // a connect on its way: what nmcli says now is the old state
                if (root.joining !== "")
                    return;

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
                    const mhz = parseInt(parts[4]) || 0;
                    const band = mhz >= 5925 ? "6" : (mhz >= 4900 ? "5" : (mhz > 0 ? "2.4" : ""));
                    // Strongest AP wins when the same network shows twice;
                    // a dual-band network lists both bands.
                    if (seen[name] !== undefined) {
                        const n = nets[seen[name]];
                        if (n.signal < sig)
                            n.signal = sig;
                        if (band !== "" && n.bands.indexOf(band) < 0)
                            n.bands = n.bands.concat([band]).sort((a, b) => parseFloat(a) - parseFloat(b));
                        if ((parts[0] ?? "").trim() === "*")
                            n.active = true;
                        continue;
                    }
                    seen[name] = nets.length;
                    nets.push({
                        ssid: name,
                        signal: sig,
                        security: root.unescapeTsv(parts[3] ?? ""),
                        bands: band !== "" ? [band] : [],
                        active: (parts[0] ?? "").trim() === "*"
                    });
                }
                nets.sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                root.networks = nets;

                // --- the wired port
                let edev = "", car = false, spd = -1, st = 0, con = "", ip = "", wdev = "", own = false;
                const wl = (blocks[4] ?? "").split("\n");
                for (let i = 0; i < wl.length; i++) {
                    const l = wl[i].trim();
                    if (l.startsWith("dev="))
                        edev = l.slice(4);
                    else if (l.startsWith("carrier="))
                        car = l.slice(8) === "1";
                    else if (l.startsWith("speed="))
                        spd = parseInt(l.slice(6));
                    else if (l.startsWith("GENERAL.STATE:"))
                        st = parseInt(l.slice(14)) || 0;
                    else if (l.startsWith("GENERAL.CONNECTION:"))
                        con = l.slice(19);
                    else if (l.startsWith("IP4.ADDRESS"))
                        ip = l.split(":").slice(1).join(":");
                    else if (l.startsWith("wifidev="))
                        wdev = l.slice(8);
                    else if (l === "own=1")
                        own = true;
                }
                root.ethDevice = edev;
                root.ethCable = car;
                root.ethSpeed = isNaN(spd) ? -1 : spd;
                if (root.lanSwitch === "")
                    root.ethState = st;
                root.ethConnection = con;
                root.ethIp = ip;
                root.wifiDevice = wdev;
                root.ownProfileExists = own;
            }
        }
    }
}
