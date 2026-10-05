//  VELVET  ·  services/Bluetooth.qml
//  All of Bluetooth, in the shell — no blueman, no blueberry, no app.
//
//  One long-lived `bluetoothctl` process is the controller: commands go in
//  through its stdin, and because it stays alive it also answers pairing
//  agents (passkey confirmations are auto-accepted, the way an app's agent
//  would). A cheap poll keeps the device list fresh, and everything
//  degrades quietly to "no bluetooth here" when bluez or bluetoothctl are
//  missing.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ------------------------------------------------------------- live state
    property bool available: false      // bluetoothctl found AND an adapter exists
    property bool powered: false
    property bool discovering: false
    property bool scanning: false       // a scan WE asked for (drives the UI)
    property string adapterName: ""
    property var devices: []            // { mac, name, connected, paired, trusted, kind }
    property string busyMac: ""         // a device operation in flight
    property string notice: ""          // last headline, for toasts (consumed elsewhere)

    readonly property int connectedCount: root.devices.filter(d => d.connected).length

    readonly property string connectedName: {
        const list = root.devices;
        for (let i = 0; i < list.length; i++)
            if (list[i].connected)
                return list[i].name;
        return "";
    }

    readonly property bool busy: root.busyMac !== ""

    // The bar's one-glance line, same shape Net used to provide.
    readonly property string label: root.powered ? (root.connectedName !== "" ? root.connectedName : "ON") : "OFF"

    // ---------------------------------------------------------------- control
    function send(cmd: string): void {
        if (ctl.running)
            ctl.write(cmd + "\n");
    }

    function ensureCtl(): void {
        if (!root.available)
            return;
        if (!ctl.running) {
            root.restarts = 0;
            ctl.running = true;
        }
    }

    function refreshSoon(): void {
        refreshDelay.restart();
    }

    function refreshNow(): void {
        poll.running = false;
        poll.running = true;
    }

    function togglePower(): void {
        if (!root.available)
            return;
        root.ensureCtl();
        root.send(`power ${root.powered ? "off" : "on"}`);
        root.refreshSoon();
    }

    function startScan(): void {
        if (!root.available || root.scanning)
            return;
        root.ensureCtl();
        root.scanning = true;
        root.send("pairable on");
        root.send("scan on");
        scanTimer.restart();
        Sfx.select();
    }

    function stopScan(): void {
        root.send("scan off");
        root.scanning = false;
        scanTimer.stop();
    }

    function connect(mac: string): void {
        root.ensureCtl();
        root.busyMac = mac;
        root.send(`connect ${mac}`);
        opWatchdog.restart();
    }

    function disconnect(mac: string): void {
        root.ensureCtl();
        root.busyMac = mac;
        root.send(`disconnect ${mac}`);
        opWatchdog.restart();
    }

    function pair(mac: string): void {
        root.ensureCtl();
        root.busyMac = mac;
        root.send(`pair ${mac}`);
        opWatchdog.restart();
    }

    function remove(mac: string): void {
        root.ensureCtl();
        root.send(`remove ${mac}`);
        root.refreshSoon();
    }

    function trust(mac: string): void {
        root.ensureCtl();
        root.send(`trust ${mac}`);
        root.refreshSoon();
    }

    function untrust(mac: string): void {
        root.ensureCtl();
        root.send(`untrust ${mac}`);
        root.refreshSoon();
    }

    function toggleTrust(mac: string): void {
        const it = root.byMac(mac);
        if (!it)
            return;
        if (it.trusted)
            root.untrust(mac);
        else
            root.trust(mac);
    }

    function byMac(mac: string): var {
        const list = root.devices;
        for (let i = 0; i < list.length; i++)
            if (list[i].mac === mac)
                return list[i];
        return null;
    }

    // Bluez device icon classes → shell icon names.
    function iconFor(kind: string): string {
        switch (`${kind ?? ""}`.trim()) {
        case "audio-headset":
        case "audio-headphones":
        case "audio-card":
            return "headset";
        case "audio-speaker":
            return "speaker";
        case "input-keyboard":
            return "keyboard";
        case "input-mouse":
            return "mouse";
        case "phone":
            return "smartphone";
        case "computer":
        case "laptop":
            return "computer";
        case "video-display":
            return "tv";
        case "camera-video":
            return "videocam";
        case "watch":
            return "watch";
        case "input-gaming":
            return "sports_esports";
        }
        return "bluetooth";
    }

    // A stable sort so rows don't dance on every poll: connected first,
    // then paired, then the rest, name within each band.
    function orderScore(d: var): int {
        return (d.connected ? 200 : 0) + (d.paired ? 100 : 0);
    }

    // --------------------------------------------------------- agent parsing
    // The controller's output arrives in chunks; a slow 300ms walk turns
    // complete lines into answers. ANSI is stripped first — some builds
    // colour even a piped stream.
    property string tail: ""
    property int seenLen: 0

    function stripAnsi(line: string): string {
        return line.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, "");
    }

    function handleLine(raw: string): void {
        const line = root.stripAnsi(raw).trim();
        if (line === "")
            return;

        // Pairing agent prompts — the shell is the agent, and the shell
        // trusts you: confirmations pass, PIN pads default to 0000.
        if (line.indexOf("Confirm passkey") !== -1
                || line.indexOf("Authorize service") !== -1
                || line.indexOf("Accept pairing") !== -1) {
            root.send("yes");
            return;
        }
        if (line.indexOf("Enter PIN code") !== -1 || line.indexOf("Enter passkey") !== -1) {
            root.send("0000");
            return;
        }

        // Outcomes — the headlines that drive toasts and busy state.
        if (line.indexOf("Pairing successful") !== -1) {
            root.busyMac = "";
            Toast.ok("PAIRED");
            root.refreshSoon();
            return;
        }
        if (line.indexOf("Failed to pair") !== -1) {
            root.busyMac = "";
            Toast.show("PAIRING FAILED — IS THE DEVICE IN PAIRING MODE?", "warn", 3800);
            root.refreshSoon();
            return;
        }
        if (line.indexOf("Connection successful") !== -1) {
            root.busyMac = "";
            Toast.ok("CONNECTED");
            root.refreshSoon();
            return;
        }
        if (line.indexOf("Failed to connect") !== -1) {
            root.busyMac = "";
            Toast.show("CONNECT FAILED — DEVICE OFF OR OUT OF RANGE", "warn", 3200);
            root.refreshSoon();
            return;
        }
        if (line.indexOf("has been removed") !== -1) {
            Toast.show("DEVICE REMOVED", "info", 2200);
            root.refreshSoon();
            return;
        }
        if (line.indexOf("Changing power") !== -1 && line.indexOf("succeeded") !== -1)
            root.refreshSoon();
        if (line.indexOf("Connected: yes") !== -1 || line.indexOf("Connected: no") !== -1)
            root.refreshSoon();
    }

    // --------------------------------------------------------- the controller
    property int restarts: 0

    Process {
        id: ctl

        stdinEnabled: true
        command: ["bluetoothctl"]

        // waitForEnd defaults to true: text would only appear after
        // bluetoothctl EXITS, so the line walker never saw a reply or prompt.
        stdout: StdioCollector {
            waitForEnd: false
        }

        onStarted: {
            root.restarts = 0;
            root.seenLen = 0;
            root.tail = "";
            // Register the agent BEFORE anything asks for one, and make the
            // controller pairable so fresh devices can find it.
            ctl.write("agent on\ndefault-agent\npairable on\n");
        }

        onExited: (code, status) => {
            root.scanning = false;
            root.busyMac = "";
            if (!root.available)
                return;
            if (root.restarts < 8)
                restartDelay.restart();
        }
    }

    Timer {
        id: restartDelay

        interval: 1400
        onTriggered: {
            root.restarts++;
            if (!ctl.running)
                ctl.running = true;
        }
    }

    // The controller's stdout buffer would grow forever; recycling the
    // process every twenty minutes is the cheap way to bound it, and the
    // agent re-registers itself on the way back in.
    Timer {
        running: true
        interval: 1200000
        repeat: true
        onTriggered: {
            if (ctl.running)
                ctl.running = false;
        }
    }

    // Walks the controller's output for complete lines.
    Timer {
        running: true
        interval: 300
        repeat: true

        onTriggered: {
            if (!ctl.running)
                return;
            const text = ctl.stdout?.text ?? "";
            if (text.length <= root.seenLen)
                return;
            // StdioCollector's buffer cannot be cleared, so only the part we
            // have not read yet is taken. The 20-minute controller recycle
            // below is what keeps the buffer itself from growing forever.
            root.tail += text.slice(root.seenLen);
            root.seenLen = text.length;
            let nl = root.tail.indexOf("\n");
            while (nl !== -1) {
                root.handleLine(root.tail.slice(0, nl));
                root.tail = root.tail.slice(nl + 1);
                nl = root.tail.indexOf("\n");
            }
            // Safety valve: a pathological line cannot grow forever.
            if (root.tail.length > 4000)
                root.tail = root.tail.slice(-2000);
        }
    }

    // ---------------------------------------------------------------- polling
    //  The 4s full-refresh only runs while the settings menu is open — the
    //  controller's own event stream (the 300ms walk above) keeps the bar
    //  live regardless. A 20s backup covers the idle desktop so a
    //  connection change is never stale for long.
    Timer {
        running: true
        interval: 4000
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (Panels.settings) {
                poll.running = false;
                poll.running = true;
            }
        }
    }

    Timer {
        running: true
        interval: 20000
        repeat: true

        onTriggered: {
            poll.running = false;
            poll.running = true;
        }
    }

    Process {
        id: poll

        command: ["bash", "-c", `
            if ! command -v bluetoothctl >/dev/null 2>&1; then
                echo 'NONE'
                exit 0
            fi
            show=$(bluetoothctl show 2>/dev/null)
            if [ -z "$show" ]; then
                echo 'NONE'
                exit 0
            fi
            printf '%s\n' "$show" | grep -m1 'Powered:' || echo 'Powered: no'
            printf '%s\n' "$show" | grep -m1 'Discovering:' || echo 'Discovering: no'
            printf '%s\n' "$show" | grep -m1 'Alias:' | cut -d' ' -f2- || echo ''
            echo '---'
            bluetoothctl devices 2>/dev/null | head -24 | while IFS=' ' read -r _ mac name; do
                info=$(bluetoothctl info "$mac" 2>/dev/null)
                conn=$(printf '%s' "$info" | grep -m1 'Connected:' | grep -q yes && echo 1 || echo 0)
                paired=$(printf '%s' "$info" | grep -m1 'Paired:' | grep -q yes && echo 1 || echo 0)
                trusted=$(printf '%s' "$info" | grep -m1 'Trusted:' | grep -q yes && echo 1 || echo 0)
                icon=$(printf '%s' "$info" | grep -m1 'Icon:' | cut -d' ' -f2-)
                [ -z "$name" ] && name=$(printf '%s' "$info" | grep -m1 'Name:' | cut -d' ' -f2-)
                [ -z "$name" ] && name="$mac"
                printf '%s\\x1f%s\\x1f%s\\x1f%s\\x1f%s\\x1f%s\\n' "$mac" "$name" "$conn" "$paired" "$trusted" "$icon"
            done
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const text0 = text.trim();
                if (text0 === "NONE") {
                    root.available = false;
                    root.powered = false;
                    root.scanning = false;
                    if (ctl.running)
                        ctl.running = false;
                    return;
                }

                const blocks = text0.split("---");
                const head = (blocks[0] ?? "").split("\n");
                root.available = true;
                root.powered = (head[0] ?? "").indexOf("yes") !== -1;
                root.discovering = (head[1] ?? "").indexOf("yes") !== -1;
                root.adapterName = (head[2] ?? "").trim();
                if (!root.scanning && root.discovering)
                    root.scanning = true;

                const out = [];
                const lines = (blocks[1] ?? "").split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\x1f");
                    if (parts.length < 2 || parts[0].length < 8)
                        continue;
                    const kind = `${parts[5] ?? ""}`.trim();
                    out.push({
                        mac: parts[0],
                        name: parts[1],
                        connected: parts[2] === "1",
                        paired: parts[3] === "1",
                        trusted: parts[4] === "1",
                        kind: kind,
                        icon: root.iconFor(kind)
                    });
                }
                out.sort((a, b) => (root.orderScore(b) - root.orderScore(a)) || (a.name < b.name ? -1 : (a.name > b.name ? 1 : 0)));
                root.devices = out;

                // The adapter went away (or the machine slept): drop the
                // controller so it does not fight a dead bluez.
                if (!root.available && ctl.running)
                    ctl.running = false;
            }
        }
    }

    Timer {
        id: refreshDelay

        interval: 800
        onTriggered: root.refreshNow()
    }

    // A scan we asked for stops itself after eighteen seconds — long enough
    // to find a drawer full of devices, short enough to not drain the bus.
    Timer {
        id: scanTimer

        interval: 18000
        onTriggered: root.stopScan()
    }

    // An operation (connect/pair) that neither succeeded nor failed in 40s
    // is dead — release the busy lock so the UI can never stick.
    Timer {
        id: opWatchdog

        interval: 40000
        onTriggered: root.busyMac = ""
    }
}
