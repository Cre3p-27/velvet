//  VELVET  ·  services/Display.qml
//  Night light + idle inhibition. Both are just long-lived child processes,
//  which means "off" is genuinely off — nothing lingers.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string sunsetBackend: ""   // hyprsunset | wlsunset | gammastep

    readonly property bool nightLightOn: Config.services.nightLight
    readonly property bool idleInhibited: Config.services.idleInhibit || Focus.keepsAwake

    // ------------------------------------------------------------- night light
    Process {
        id: sunset

        // `bouncing` restarts the daemon without an imperative write, which
        // would destroy this binding (night light could then never turn off).
        running: root.nightLightOn && root.sunsetBackend !== "" && !root.bouncing
        command: {
            const k = Config.services.nightLightTemp;
            if (root.sunsetBackend === "hyprsunset")
                return ["hyprsunset", "-t", `${k}`];
            if (root.sunsetBackend === "wlsunset")
                return ["wlsunset", "-T", `${k + 1}`, "-t", `${k}`];
            if (root.sunsetBackend === "gammastep")
                return ["gammastep", "-O", `${k}`];
            return ["true"];
        }
    }

    property bool bouncing: false

    Timer {
        id: unbounce
        interval: 150
        onTriggered: root.bouncing = false
    }

    // Restart the daemon when the temperature slider settles.
    Timer {
        id: retemp
        interval: 220
        onTriggered: {
            if (root.nightLightOn && root.sunsetBackend !== "") {
                root.bouncing = true;
                unbounce.restart();
            }
        }
    }

    Connections {
        target: Config.services
        function onNightLightTempChanged(): void {
            retemp.restart();
        }
    }

    // ------------------------------------------------------------- idle inhibit
    Process {
        id: inhibitor

        running: root.idleInhibited
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=Velvet", "--why=User requested", "--mode=block", "sleep", "infinity"]
    }

    // ------------------------------------------------------------- detection
    Process {
        id: detect

        running: true
        command: ["bash", "-c", "for b in hyprsunset wlsunset gammastep; do command -v $b >/dev/null 2>&1 && { echo $b; break; }; done"]

        stdout: StdioCollector {
            onStreamFinished: root.sunsetBackend = text.trim()
        }
    }
}
