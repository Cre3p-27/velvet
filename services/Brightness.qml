//  VELVET  ·  services/Brightness.qml
//  brightnessctl for internal panels, ddcutil as the fallback for desktop monitors.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property real brightness: 0.5
    property bool available: false
    property string device: ""
    property string backend: ""     // "brightnessctl" | "ddcutil" | ""
    property int _max: 100

    signal changedByUser

    function setBrightness(value: real): void {
        // No backend: nothing would change, so the OSD must not pretend.
        if (!root.available)
            return;
        const v = Math.max(0.01, Math.min(1, value));
        root.brightness = v;
        applyDebounce.restart();
        root.changedByUser();
    }

    function increment(): void {
        setBrightness(brightness + Config.services.brightnessStep);
    }

    function decrement(): void {
        setBrightness(brightness - Config.services.brightnessStep);
    }

    Timer {
        id: applyDebounce
        interval: 24
        onTriggered: {
            if (root.backend === "brightnessctl")
                applyProc.command = ["brightnessctl", "-d", root.device, "-q", "s", `${Math.round(root.brightness * 100)}%`];
            else if (root.backend === "ddcutil")
                applyProc.command = ["ddcutil", "setvcp", "10", `${Math.round(root.brightness * 100)}`, "--noverify"];
            else
                return;
            applyProc.running = false;
            applyProc.running = true;
        }
    }

    Process {
        id: applyProc
        command: ["true"]
    }

    // ------------------------------------------------------------- detection
    Process {
        id: detectProc

        running: true
        command: ["bash", "-c", "brightnessctl -m -l 2>/dev/null | grep -m1 ',backlight,' || true"]

        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                if (line) {
                    const parts = line.split(",");
                    root.device = parts[0];
                    root._max = parseInt(parts[4]) || 100;
                    root.brightness = (parseInt(parts[2]) || 50) / root._max;
                    root.backend = "brightnessctl";
                    root.available = true;
                } else {
                    ddcDetect.running = true;
                }
            }
        }
    }

    Process {
        id: ddcDetect

        command: ["bash", "-c", "command -v ddcutil >/dev/null && ddcutil detect --brief 2>/dev/null | grep -qm1 Display && echo yes || true"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "yes") {
                    root.backend = "ddcutil";
                    root.available = true;
                }
            }
        }
    }
}
