//  VELVET  ·  services/SysInfo.qml
//  CPU / memory / temperature, straight from /proc and /sys. No shelling out.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real cpuPercent: 0
    property real memoryPercent: 0
    property real swapPercent: 0
    property real memoryUsedGb: 0
    property real memoryTotalGb: 0
    property real temperature: 0
    property real uptimeSeconds: 0
    property string osPrettyName: ""
    // Who is looking at the screen, and which machine it is. The HOME
    // page's profile card reads these.
    readonly property string user: Quickshell.env("USER") ?? ""
    property string hostname: ""
    property real storagePercent: 0
    property real storageUsedGb: 0
    property real storageTotalGb: 0

    // Rolling history for the graph module. 60 samples at 2 s is two minutes.
    property var cpuHistory: []
    property var memHistory: []
    readonly property int historyLength: 60

    readonly property string uptimeText: {
        const s = root.uptimeSeconds;
        if (s <= 0)
            return "";
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0)
            return `${d}d ${h}h`;
        if (h > 0)
            return `${h}h ${m}m`;
        return `${m}m`;
    }

    function push(list: var, value: real): var {
        const next = list.slice();
        next.push(value);
        while (next.length > root.historyLength)
            next.shift();
        return next;
    }

    property real _lastIdle: 0   // jiffies overflow int32 after ~2 weeks up
    property real _lastTotal: 0

    // How often the bar refreshes these. Cheap enough at 2s.
    property int interval: 2000

    Timer {
        running: true
        interval: root.interval
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            statFile.reload();
            memFile.reload();
            thermalFile.reload();
            uptimeFile.reload();
            osFile.reload();
            if (root.hostname === "")
                hostFile.reload();
            root.cpuHistory = root.push(root.cpuHistory, root.cpuPercent);
            root.memHistory = root.push(root.memHistory, root.memoryPercent);
        }
    }

    // Disk usage — the one number that needs a process rather than a file.
    // Refreshed rarely; the lock's resource cells read it.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            storageProbe.running = false;
            storageProbe.running = true;
        }
    }

    Process {
        id: storageProbe

        command: ["bash", "-c", "df -kP / | tail -1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length < 5)
                    return;
                const total = parseInt(parts[1]);
                const used = parseInt(parts[2]);
                if (total > 0) {
                    root.storageTotalGb = total / 1048576;
                    root.storageUsedGb = used / 1048576;
                    root.storagePercent = (used / total) * 100;
                }
            }
        }
    }

    FileView {
        id: statFile

        path: "/proc/stat"
        printErrors: false

        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("cpu "));
            if (!line)
                return;
            const parts = line.split(/\s+/).slice(1).map(Number);
            if (parts.length < 5)
                return;

            const idle = parts[3] + (parts[4] ?? 0);
            let total = 0;
            for (let i = 0; i < parts.length; i++)
                total += parts[i];

            const dIdle = idle - root._lastIdle;
            const dTotal = total - root._lastTotal;
            root._lastIdle = idle;
            root._lastTotal = total;

            if (dTotal > 0)
                root.cpuPercent = Math.max(0, Math.min(100, (1 - dIdle / dTotal) * 100));
        }
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"
        printErrors: false

        onLoaded: {
            const data = text();
            const read = key => {
                const m = data.match(new RegExp(key + ":\\s+(\\d+)"));
                return m ? parseInt(m[1]) : 0;
            };

            const total = read("MemTotal");
            const available = read("MemAvailable");
            const swapTotal = read("SwapTotal");
            const swapFree = read("SwapFree");

            if (total > 0) {
                root.memoryTotalGb = total / 1048576;
                root.memoryUsedGb = (total - available) / 1048576;
                root.memoryPercent = ((total - available) / total) * 100;
            }
            if (swapTotal > 0)
                root.swapPercent = ((swapTotal - swapFree) / swapTotal) * 100;
        }
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        printErrors: false

        onLoaded: {
            const v = parseFloat(text().split(" ")[0]);
            if (!isNaN(v))
                root.uptimeSeconds = v;
        }
    }

    FileView {
        id: osFile

        path: "/etc/os-release"
        printErrors: false

        onLoaded: {
            const m = text().match(/^PRETTY_NAME="?([^"\n]+)"?/m);
            if (m)
                root.osPrettyName = m[1];
        }
    }

    // The machine's name — read once, it never changes while the shell runs.
    FileView {
        id: hostFile

        path: "/etc/hostname"
        printErrors: false

        onLoaded: {
            const h = text().trim();
            if (h !== "")
                root.hostname = h;
        }
    }

    FileView {
        id: thermalFile

        path: "/sys/class/thermal/thermal_zone0/temp"
        printErrors: false

        onLoaded: {
            const v = parseInt(text());
            if (!isNaN(v))
                root.temperature = v > 1000 ? v / 1000 : v;
        }
    }
}
