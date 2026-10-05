//  VELVET  ·  services/Looks.qml
//  A look is everything you set up while a particular wallpaper was up.
//
//  The palette already follows the wallpaper on its own. What it cannot know
//  is that a busy photograph wants a heavier bar and less transparency, that
//  one picture wants the taskbar on the left and the windows see-through, and
//  that another wants a different lock screen. That is taste, and taste is
//  what this remembers: colours, taskbar, windows, lock screen, desktop and
//  the rest — every setting the settings menu has, in six switchable groups.
//  Change wallpaper, get your taste for that wallpaper back.
//
//  Nothing here is destructive: a look only ever writes settings it has a
//  saved value for, a group you switched off is neither saved nor restored,
//  and a wallpaper with no look saved leaves everything exactly as it is.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool ready: root.loaded

    property bool loaded: false
    property var store: ({})           // wallpaper path -> { key: value }
    property string applying: ""       // suppresses autosave while restoring
    property string lastSnap: ""       // the tracked settings as last seen / stored
    property string previous: ""       // the wallpaper that was up before this one
    property int rev: 0                // counts every settings edit, for bindings

    readonly property string path: `${Quickshell.env("HOME")}/.config/velvet/looks.json`
    readonly property string wallpaper: Config.wallpaper.current

    readonly property bool hasLook: !!root.store[root.wallpaper]
    readonly property int count: Object.keys(root.store).length

    // ------------------------------------------------------------- what a look is
    // Six groups, each a settings section. `flag` is the looks.* switch that
    // turns the group on; the colours group has none — a look is at least that.
    readonly property var groups: [
        {
            id: "style",
            name: "COLOURS & STYLE",
            sub: "PALETTE, TINT, TRANSPARENCY, ROUNDING, FONTS",
            flag: "",
            prefixes: ["appearance"]
        },
        {
            id: "bar",
            name: "TASKBAR",
            sub: "WHERE IT SITS, SIZE, OPACITY, FRAME, CLOCK, STATUS",
            flag: "looks.includeBar",
            prefixes: ["bar"]
        },
        {
            id: "windows",
            name: "WINDOWS",
            sub: "OPACITY, GAPS, ROUNDING, BORDERS, BLUR, SHADOW",
            flag: "looks.includeWindows",
            prefixes: ["hypr"]
        },
        {
            id: "lock",
            name: "LOCK SCREEN",
            sub: "ITS STYLE, CLOCK, WIDGETS, MOTION, BLUR",
            flag: "looks.includeLock",
            prefixes: ["lock"]
        },
        {
            id: "desktop",
            name: "DESKTOP & CANVAS",
            sub: "LIVING DESKTOP, WIDGET LOOK, WINDOW MAP, EDGES",
            flag: "looks.includeDesktop",
            prefixes: ["wallpaper", "map"]
        },
        {
            id: "more",
            name: "EVERYTHING ELSE",
            sub: "LAUNCHER, NOTIFICATIONS, OSD, LYRICS, SOUNDS, AUDIO VISUALS",
            flag: "looks.includeMore",
            prefixes: ["launcher", "notifs", "osd", "lyrics", "sfx", "services:audio"]
        }
    ]

    // Things that are the machine's or a session's, not a picture's: which
    // wallpaper is up, where the library is, how Hyprland is driven, the
    // lock's login plumbing, do-not-disturb.
    readonly property var never: ({
            "wallpaper.current": 1,
            "wallpaper.directory": 1,
            "wallpaper.renderer": 1,
            "wallpaper.rotateMinutes": 1,
            "wallpaper.wheel": 1,
            "wallpaper.deskMenu": 1,
            "hypr.luaDispatch": 1,
            "hypr.manage": 1,
            "hypr.manageBorders": 1,
            "hypr.format": 1,
            "hypr.layout": 1,
            "hypr.vrr": 1,
            "hypr.followMouse": 1,
            "hypr.resizeOnBorder": 1,
            "hypr.animations": 1,
            "lock.useBuiltin": 1,
            "lock.lockOnStart": 1,
            "lock.listenToLogind": 1,
            "lock.pamConfig": 1,
            "notifs.doNotDisturb": 1,
            "launcher.actionPrefix": 1
        })

    readonly property var valueKinds: ({
            "toggle": 1,
            "slider": 1,
            "choice": 1,
            "colour": 1,
            "carousel": 1
        })

    // key -> group id, for every setting the menu has that a look may hold.
    readonly property var keyGroup: {
        const out = {};
        const rows = Schema.allRows;
        for (let i = 0; i < rows.length; i++) {
            const k = rows[i].key ?? "";
            if (k === "" || out[k] !== undefined || root.never[k] || !root.valueKinds[rows[i].kind])
                continue;
            for (let g = 0; g < root.groups.length; g++) {
                const pre = root.groups[g].prefixes;
                // "section" takes the whole section, "section:start" only the
                // names that begin with start
                if (pre.some(p => {
                    const at = p.split(":");
                    return k.startsWith(at[0] + ".") && k.slice(at[0].length + 1).startsWith(at[1] ?? "");
                })) {
                    out[k] = root.groups[g].id;
                    break;
                }
            }
        }
        return out;
    }

    function groupOn(id: string): bool {
        for (let g = 0; g < root.groups.length; g++)
            if (root.groups[g].id === id)
                return root.groups[g].flag === "" || !!Config.get(root.groups[g].flag);
        return false;
    }

    function groupCount(id: string): int {
        let n = 0;
        for (const k in root.keyGroup)
            if (root.keyGroup[k] === id)
                n++;
        return n;
    }

    function toggleGroup(id: string): void {
        for (let g = 0; g < root.groups.length; g++)
            if (root.groups[g].id === id && root.groups[g].flag !== "")
                Config.toggle(root.groups[g].flag);
    }

    // The settings a look holds right now: every group that is switched on.
    readonly property var keys: {
        const on = {};
        for (let g = 0; g < root.groups.length; g++) {
            const fl = root.groups[g].flag;
            on[root.groups[g].id] = fl === "" || !!Config.get(fl);
        }
        const out = [];
        for (const k in root.keyGroup)
            if (on[root.keyGroup[k]])
                out.push(k);
        return out;
    }

    readonly property var wallpapers: Object.keys(root.store).sort()

    // ------------------------------------------------------------------ api
    function capture(): var {
        const out = {};
        const k = root.keys;
        for (let i = 0; i < k.length; i++) {
            const v = Config.get(k[i]);
            if (v !== undefined && v !== null)
                out[k[i]] = v;
        }
        return out;
    }

    // Saves the settings now against a wallpaper (the one that is up unless
    // told otherwise). Merged over what the look already held, so a group
    // that is off at the moment keeps what it had.
    function save(wp: var): void {
        if (!wp || typeof wp !== "string")
            wp = root.wallpaper;
        if (!wp)
            return;
        const next = Object.assign({}, root.store);
        const now = root.capture();
        next[wp] = Object.assign({}, next[wp] ?? {}, now);
        root.store = next;
        root.lastSnap = JSON.stringify(now);
        root.persist();
    }

    // How many settings of one group a saved look holds.
    function heldIn(wp: string, id: string): int {
        const look = root.store[wp];
        if (!look)
            return 0;
        let n = 0;
        for (const k in look)
            if (root.keyGroup[k] === id)
                n++;
        return n;
    }

    // The switched-on settings that differ from what the wallpaper's saved
    // look holds. Reads `rev`, so a binding on it follows every edit.
    function changedCount(wp: string): int {
        const look = root.store[wp];
        if (!look || root.rev < 0)
            return 0;
        const k = root.keys;
        let n = 0;
        for (let i = 0; i < k.length; i++)
            if (look[k[i]] !== undefined && JSON.stringify(Config.get(k[i])) !== JSON.stringify(look[k[i]]))
                n++;
        return n;
    }

    // Puts another wallpaper's look on this one: stored here and worn now.
    function copyFrom(src: string): bool {
        const wp = root.wallpaper;
        if (!wp || !src || src === wp || !root.store[src])
            return false;
        const next = Object.assign({}, root.store);
        next[wp] = Object.assign({}, root.store[src]);
        root.store = next;
        root.persist();
        return root.restore(wp);
    }

    function forget(wp: var): void {
        if (!wp || typeof wp !== "string")
            wp = root.wallpaper;
        if (!wp || !root.store[wp])
            return;
        const next = Object.assign({}, root.store);
        delete next[wp];
        root.store = next;
        root.persist();
        // A tweak still waiting for its save must not bring the look back.
        if (wp === root.wallpaper) {
            autosave.stop();
            root.lastSnap = JSON.stringify(root.capture());
        }
    }

    function forgetAll(): void {
        root.store = ({});
        root.persist();
        autosave.stop();
        root.lastSnap = JSON.stringify(root.capture());
    }

    function restore(wp: string): bool {
        const look = root.store[wp];
        if (!look)
            return false;

        // Only what the switched-on groups hold — a group you turned off
        // stays as it is.
        const allowed = {};
        const k = root.keys;
        for (let i = 0; i < k.length; i++)
            allowed[k[i]] = true;
        const batch = {};
        let n = 0;
        for (const key in look) {
            if (allowed[key] && JSON.stringify(Config.get(key)) !== JSON.stringify(look[key])) {
                batch[key] = look[key];
                n++;
            }
        }

        // Guard first: applying a look writes settings, and every write would
        // otherwise be seen as a change worth saving back.
        root.applying = wp;
        // One batch, one write — key by key, every second one used to
        // snap back (see Config.setMany).
        if (n > 0)
            Config.setMany(batch);
        releaseGuard.restart();
        return true;
    }

    Timer {
        id: releaseGuard
        interval: 900
        onTriggered: {
            root.applying = "";
            root.lastSnap = JSON.stringify(root.capture());
        }
    }

    function persist(): void {
        file.setText(JSON.stringify(root.store, null, 1));
    }

    // ---------------------------------------------------------- the hookup
    // The wallpaper changed. A tweak still waiting for its moment goes to the
    // wallpaper it was made on; then, if the new one has a look, it is put on.
    // If it has none, what you see now stays, and the first thing you change
    // becomes its look.
    onWallpaperChanged: {
        const was = root.previous;
        root.previous = root.wallpaper;
        if (!Config.looks.enabled || !root.loaded)
            return;
        if (autosave.running) {
            autosave.stop();
            if (was)
                root.flush(was);
        }
        const wp = root.wallpaper;
        if (!wp)
            return;
        if (root.restore(wp))
            Toast.show(`LOOK RESTORED  ·  ${wp.split("/").pop()}`, "ok", 2600);
        else
            root.lastSnap = JSON.stringify(root.capture());
    }

    // Autosave: any change to a watched setting is remembered against whatever
    // wallpaper is up, a moment after you stop moving the slider — and only
    // if a watched setting really differs from what was last seen.
    Connections {
        target: Config
        enabled: Config.looks.enabled && Config.looks.autoSave
        function onEdited(): void {
            if (root.applying === "" && root.loaded && Config.loaded)
                autosave.restart();
        }
    }

    Connections {
        target: Config
        function onEdited(): void {
            root.rev++;
        }
    }

    function flush(wp: string): void {
        if (!Config.looks.enabled || !Config.looks.autoSave || !wp)
            return;
        if (JSON.stringify(root.capture()) !== root.lastSnap)
            root.save(wp);
    }

    Timer {
        id: autosave
        interval: 1400
        onTriggered: root.flush(root.wallpaper)
    }

    // The first picture of the settings, once both files are in: later
    // changes are measured against it.
    Timer {
        running: root.loaded && Config.loaded && root.lastSnap === ""
        interval: 800
        onTriggered: {
            root.lastSnap = JSON.stringify(root.capture());
            root.previous = root.wallpaper;
        }
    }

    // ----------------------------------------------------------------- disk
    FileView {
        id: file

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.store = (parsed && typeof parsed === "object") ? parsed : ({});
            } catch (e) {
                root.store = ({});
            }
            root.loaded = true;
        }

        onLoadFailed: {
            root.store = ({});
            root.loaded = true;
        }
    }
}
