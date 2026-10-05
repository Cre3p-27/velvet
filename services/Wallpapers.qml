//  VELVET  ·  services/Wallpapers.qml
//  Finds wallpapers, sets them through whichever backend is installed, and
//  keeps a favourites list. Changing the wallpaper re-tints the entire shell.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var list: []
    property var favourites: []
    property bool scanning: false
    property string backend: ""     // swww | hyprpaper | swaybg
    // The coverflow rescans every time it opens — a full disk walk on the
    // hot path. Remember the last walk and skip a fresh one for 20s.
    property real lastScan: 0

    readonly property string favPath: `${Quickshell.env("HOME")}/.config/velvet/favourites.json`

    readonly property var shown: showFavouritesOnly ? list.filter(p => favourites.indexOf(p) !== -1) : list
    property bool showFavouritesOnly: false

    function basename(path: string): string {
        const f = path.split("/").pop();
        return f.replace(/\.[^.]+$/, "");
    }

    function isFavourite(path: string): bool {
        return favourites.indexOf(path) !== -1;
    }

    function toggleFavourite(path: string): void {
        const next = favourites.slice();
        const i = next.indexOf(path);
        if (i === -1)
            next.push(path);
        else
            next.splice(i, 1);
        root.favourites = next;
        favFile.setText(JSON.stringify(next, null, 2));
    }

    function apply(path: string): void {
        if (!path)
            return;
        Config.wallpaper.current = path;

        // The built-in renderer is bound straight to that path — there is
        // nothing else to do, and nothing that can fail after a reboot.
        if (Config.wallpaper.renderer === "builtin")
            return;

        const transition = Config.wallpaper.transition;
        let cmd;
        if (root.backend === "swww")
            cmd = ["swww", "img", path, "--transition-type", transition ? "grow" : "none", "--transition-fps", "60", "--transition-duration", transition ? "0.9" : "0", "--transition-pos", "0.9,0.9"];
        else if (root.backend === "hyprpaper")
            cmd = ["bash", "-c", `hyprctl hyprpaper preload "${path}" && hyprctl hyprpaper wallpaper ",${path}" && hyprctl hyprpaper unload unused`];
        else if (root.backend === "swaybg")
            cmd = ["bash", "-c", `pkill -x swaybg; swaybg -i "${path}" -m fill &`];
        else
            return;

        setter.command = cmd;
        setter.running = false;
        setter.running = true;
    }

    function scan(force: bool): void {
        if (root.scanning || (Date.now() - root.lastScan < 20000 && !force))
            return;
        root.lastScan = Date.now();
        root.scanning = true;
        scanner.running = false;
        scanner.running = true;
    }

    function next(): void {
        const l = root.shown;
        if (l.length === 0)
            return;
        const i = l.indexOf(Config.wallpaper.current);
        apply(l[(i + 1) % l.length]);
    }

    function random(): void {
        const l = root.shown;
        if (l.length > 0)
            apply(l[Math.floor(Math.random() * l.length)]);
    }

    Process {
        id: setter
        command: ["true"]
    }

    Process {
        id: scanner

        command: ["bash", "-c", `find "${Config.wallpaper.directory}" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \\) 2>/dev/null | sort`]

        stdout: StdioCollector {
            onStreamFinished: {
                root.list = text.trim().split("\n").filter(l => l.length > 0);
                root.scanning = false;
                // Adopt the first wallpaper if none has been chosen yet, so the
                // palette has something to work with on a fresh install.
                if (!Config.wallpaper.current && root.list.length > 0)
                    Config.wallpaper.current = root.list[0];
            }
        }
    }

    Process {
        id: detect

        running: true
        // swww needs its daemon up before `swww img` will do anything, which is
        // the usual reason an external wallpaper is missing after a reboot.
        command: ["bash", "-c", `
            for b in swww hyprpaper swaybg; do command -v $b >/dev/null 2>&1 && { echo $b; break; }; done
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                root.backend = text.trim();
                if (root.backend === "swww" && Config.wallpaper.renderer !== "builtin")
                    swwwDaemon.running = true;
            }
        }
    }

    Process {
        id: swwwDaemon
        command: ["bash", "-c", "pgrep -x swww-daemon >/dev/null || swww-daemon &"]
    }

    FileView {
        id: favFile

        path: root.favPath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (Array.isArray(parsed))
                    root.favourites = parsed;
            } catch (e) {
                root.favourites = [];
            }
        }
        onLoadFailed: root.favourites = []
    }

    Timer {
        running: true
        interval: 1
        onTriggered: root.scan()
    }

    Connections {
        target: Config.wallpaper
        function onDirectoryChanged(): void {
            root.scan(true);
        }
    }

    // The one job the old external carousel did that the shell still
    // couldn't: move to the next wallpaper every N minutes, inside the shell,
    // so the palette always matches the picture on screen.
    Timer {
        running: Config.wallpaper.rotateMinutes > 0 && Config.wallpaper.current !== ""
        interval: Math.max(1, Config.wallpaper.rotateMinutes) * 60000
        repeat: true
        onTriggered: root.next()
    }
}
