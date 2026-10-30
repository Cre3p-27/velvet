//  VELVET  ·  services/Avatar.qml
//  Your picture (~/.face), once, for the whole shell. Every module that wears
//  it — the lock's faces and cards, HOME's profile card, the desktop widgets —
//  reads `Avatar.url`, so a new photo shows everywhere at the same moment.
//
//  Why a copy: an image the shell has shown stays in Qt's image cache under
//  its file name, so a new ~/.face behind the same name kept showing the old
//  photo on every module that did not reload it by hand (a query-string cache
//  buster breaks file:// loads). Each picture is written to a fresh file in
//  the runtime folder instead — a new name is a new picture, everywhere.
//
//  HOME → YOUR PICTURE → MATCH THE WALLPAPER dresses the copy in the
//  wallpaper's colours (bin/velvet-face): TINT lays them over the photo,
//  DUOTONE paints it in them, POSTER cuts it into four flat tones. It follows
//  every wallpaper (and every palette) change on its own.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string facePath: `${Quickshell.env("HOME") ?? ""}/.face`
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string tool: `${Qt.resolvedUrl("../bin/velvet-face")}`.replace(/^file:\/\//, "")

    // what the modules read: is there a picture, and where it is
    property bool exists: false
    property string url: ""

    readonly property string style: ["tint", "duotone", "poster"].indexOf(Config.home.faceStyle) >= 0 ? Config.home.faceStyle : "photo"
    // the colours it is dressed in: the wallpaper's own (the accent follows it)
    readonly property string dark: `${Colours.tone}`
    readonly property string accent: `${Colours.accent}`
    readonly property string light: `${Colours.mix(Colours.accent, "#ffffff", 0.82)}`
    readonly property string recipe: `${root.style}|${root.dark}|${root.accent}|${root.light}`

    property int serial: 0
    readonly property string stamp: Date.now().toString(36)
    property string madeFor: ""

    FileView {
        id: probe

        path: root.facePath
        printErrors: false
        watchChanges: true
        blockLoading: false

        onFileChanged: probe.reload()
        onLoaded: {
            root.exists = true;
            root.madeFor = "";
            soon.restart();
        }
        onLoadFailed: {
            root.exists = false;
            root.url = "";
        }
    }

    onRecipeChanged: soon.restart()

    // a file that is not there yet cannot be watched: look again now and then
    Timer {
        running: !root.exists
        interval: 5000
        repeat: true
        onTriggered: probe.reload()
    }

    // one render per burst of changes (a wallpaper switch moves every colour)
    Timer {
        id: soon

        interval: 250
        onTriggered: root.render()
    }

    // a hand-off from the face picker, which copied a new picture home
    function refresh(): void {
        probe.reload();
    }

    function render(): void {
        if (!root.exists)
            return;
        const key = `${root.recipe}|${root.serial}`;
        if (root.madeFor === key && root.url !== "")
            return;
        root.serial++;
        // a name no earlier picture had — not even one from before a reload
        const dst = `${root.runDir}/velvet-face-${root.stamp}-${root.serial}.png`;
        maker.dst = dst;
        maker.key = `${root.recipe}|${root.serial}`;
        maker.command = ["bash", "-c", `rm -f "$1"/velvet-face-*.png.part; python3 "$2" "$3" "$4" "$5" "$6" "$7" "$8" >/dev/null 2>&1 || cp -f -- "$3" "$4"; [ -s "$4" ] && echo done`, "velvet-face", root.runDir, root.tool, root.facePath, dst, root.style, root.dark, root.accent, root.light];
        maker.running = false;
        maker.running = true;
    }

    Process {
        id: maker

        property string dst: ""
        property string key: ""

        stdout: StdioCollector {
            onStreamFinished: {
                // cut short by the next render, or nothing written: keep what shows
                if (text.indexOf("done") < 0)
                    return;
                const old = root.url;
                root.url = `file://${maker.dst}`;
                root.madeFor = maker.key;
                // the picture before this one is no longer shown anywhere
                if (old !== "" && old !== root.url)
                    cleanup.command = ["rm", "-f", "--", old.replace(/^file:\/\//, "")];
                cleanup.running = false;
                cleanup.running = old !== "" && old !== root.url;
            }
        }
    }

    Process {
        id: cleanup

        command: ["true"]
    }

    // At start: a picture from an earlier run of the shell is never reused
    // (it may be the wrong one) — clear them away.
    Process {
        running: true
        command: ["bash", "-c", `rm -f "$1"/velvet-face-*.png`, "velvet-face", root.runDir]
    }
}
