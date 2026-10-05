//  VELVET  ·  tools/island_helper.qml (verification helper)
//  Grabs one frame of the primary screen into /tmp/velvet-island-probe.png
//  and quits. Run with:  qs -p tools/island_helper.qml
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    // The real monitor, by name — never by index, so a stale FALLBACK entry
    // cannot turn the grab into a hang.
    readonly property var target: {
        const ss = Quickshell.screens;
        for (let i = 0; i < ss.length; i++)
            if (ss[i].name === "HDMI-A-1")
                return ss[i];
        return ss[0];
    }

    screen: root.target
    color: "transparent"
    WlrLayershell.namespace: "velvet-island-helper"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: -1
    visible: true

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    mask: Region {}

    ScreencopyView {
        id: view

        anchors.fill: parent
        captureSource: root.target
        live: false
        paintCursor: false
    }

    Timer {
        interval: 500
        repeat: true
        running: true

        onTriggered: {
            if (!view.hasContent)
                return;
            running = false;
            view.grabToImage(result => {
                if (result) {
                    result.saveToFile("/tmp/velvet-island-probe.png");
                    console.log("ISLAND-PROBE saved");
                } else {
                    console.log("ISLAND-PROBE grab failed");
                }
                Quickshell.quit();
            });
        }
    }

    // Hard exit: never hang the terminal, whatever the grab does.
    Timer {
        interval: 9000
        running: true
        onTriggered: {
            console.log("ISLAND-PROBE timeout, quitting");
            Quickshell.quit();
        }
    }
}
