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
    // THE LOOK (LOOKS: Velvet, Windows 11, your own …) owns its memory. Every
    // look has a book of its own — its setup per wallpaper, and the setup it
    // was last left in — so nothing you set while wearing one look is ever
    // saved onto, or restored into, another. `store` is the book of the look
    // you wear (wallpaper path -> { key: value }), so everything that reads
    // it per wallpaper still does; `books` holds the others.
    property var store: ({})           // wallpaper path -> { key: value }, this look's
    property var books: ({})           // look id -> { wallpaper path -> { key: value } }
    property var lasts: ({})           // look id -> the setup that look was last left in
    property var legacy: null          // a pre-look looks.json, until it has an owner
    property string bookLook: ""       // whose book `store` is
    property bool switchingLook: false // Presets is putting another look on
    readonly property string look: Presets.loaded ? (Presets.applied || "velvet") : ""
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
            // live wallpapers are the machine's: what Velly makes, and whether it plays
            "wallpaper.liveOn": 1,
            "wallpaper.liveAuto": 1,
            "wallpaper.liveStyle": 1,
            "wallpaper.liveStrength": 1,
            "wallpaper.liveIntensity": 1,
            "wallpaper.liveAmount": 1,
            "wallpaper.liveSpeed": 1,
            "wallpaper.liveSeconds": 1,
            "wallpaper.liveFps": 1,
            "wallpaper.livePauseBehind": 1,
            "wallpaper.liveGif": 1,
            "wallpaper.liveGifPictures": 1,
            "wallpaper.liveGifWidth": 1,
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

    // Settings that are not a row of the menu but are arranged by hand —
    // the taskbar's modules, the lock designer's places and styles, the
    // greeting — belong to the look just the same.
    readonly property var arranged: ({
            "bar.layout": "bar",
            "lock.greeting": "lock",
            "lock.softPlace": "lock",
            "lock.softStyle": "lock"
        })
    // key -> group id, for every setting the menu has that a look may hold.
    readonly property var keyGroup: {
        const out = Object.assign({}, root.arranged);
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
        return root.restoreFrom(look);
    }

    function restoreFrom(look: var): bool {
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
        root.applying = "restore";
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
        if (root.bookLook === "")
            return;
        const books = Object.assign({}, root.books);
        books[root.bookLook] = root.store;
        root.books = books;
        file.setText(JSON.stringify({
            "__byLook__": books,
            "__last__": root.lasts,
            "__v__": 2
        }, null, 1));
    }

    // Both files are in: the books get their owner. A looks.json from before
    // looks had books of their own belongs to the look you wear now (it was
    // made with whatever was on — the file was backed up next to it).
    function adopt(): void {
        if (root.bookLook !== "" || !root.loaded || root.look === "")
            return;
        root.bookLook = root.look;
        if (root.legacy !== null) {
            const books = Object.assign({}, root.books);
            books[root.look] = root.legacy;
            root.books = books;
            root.legacy = null;
        }
        root.store = root.books[root.look] ?? ({});
        root.persist();
    }

    onLookChanged: {
        if (root.bookLook === "") {
            root.adopt();
            return;
        }
        if (root.look === "" || root.look === root.bookLook)
            return;
        root.enterLook(root.look);
    }

    // Presets calls this BEFORE it writes another look: what is still waiting
    // to be saved goes to the look you are leaving (the settings are still
    // its own at this moment), the look's whole setup is kept as the one it
    // was left in, and nothing the new look writes is taken for your edit.
    // A look that was deleted: its books go too (never the one worn).
    function forgetLook(id: string): void {
        if (!id || id === root.bookLook)
            return;
        const books = Object.assign({}, root.books);
        const lasts = Object.assign({}, root.lasts);
        delete books[id];
        delete lasts[id];
        root.books = books;
        root.lasts = lasts;
        root.persist();
    }

    // A look made from the one you wear (SAVE AS A LOOK) starts with a copy
    // of its memory and of the setup as it is right now.
    function seedLook(id: string): void {
        if (!id || root.bookLook === "" || id === root.bookLook)
            return;
        const books = Object.assign({}, root.books);
        books[id] = JSON.parse(JSON.stringify(root.store));
        const lasts = Object.assign({}, root.lasts);
        lasts[id] = root.capture();
        root.books = books;
        root.lasts = lasts;
        root.persist();
    }

    function lookLeaving(): void {
        if (root.bookLook === "")
            return;
        root.switchingLook = true;
        root.applying = "look";
        if (autosave.running) {
            autosave.stop();
            root.flush(root.wallpaper);
        }
        const lasts = Object.assign({}, root.lasts);
        lasts[root.bookLook] = root.capture();
        root.lasts = lasts;
        root.persist();
        // a Presets call that never gets as far as changing the look must
        // not leave the guard up
        lookGuard.restart();
    }

    // The look changed (Presets set `applied`): its own book comes out, and
    // its setup for this wallpaper — or, for a wallpaper it has none for, the
    // setup it was left in — goes on over the look's design.
    function enterLook(id: string): void {
        const books = Object.assign({}, root.books);
        books[root.bookLook] = root.store;
        root.books = books;
        root.bookLook = id;
        root.store = books[id] ?? ({});
        root.switchingLook = false;
        lookGuard.stop();
        const wp = root.wallpaper;
        if (wp && root.store[wp]) {
            root.restore(wp);
        } else if (root.lasts[id]) {
            root.restoreFrom(root.lasts[id]);
        } else {
            // a look never worn before: its design over the shell's own
            // defaults — never what the look you just left had set
            root.restoreFrom(root.freshFor(id));
        }
        root.persist();
    }

    // What a look starts from the first time: every remembered setting as
    // the shell ships it, except what the look's own design (and your
    // tuning of it) sets — Presets has just written those.
    function freshFor(id: string): var {
        const look = Presets.find(id);
        const own = look ? Presets.plan(look) : ({});
        const tune = Presets.tunes[id] ?? ({});
        const out = {};
        const k = root.keys;
        for (let i = 0; i < k.length; i++) {
            if (own[k[i]] !== undefined || tune[k[i]] !== undefined)
                continue;
            const v = Config.defaultOf(k[i]);
            if (v !== undefined && v !== null && typeof v !== "function")
                out[k[i]] = JSON.parse(JSON.stringify(v));
        }
        return out;
    }

    Timer {
        id: lookGuard

        interval: 4000
        onTriggered: {
            root.switchingLook = false;
            root.applying = "";
            root.lastSnap = JSON.stringify(root.capture());
        }
    }

    // ---------------------------------------------------------- the hookup
    // The wallpaper changed. A tweak still waiting for its moment goes to the
    // wallpaper it was made on; then, if the new one has a look, it is put on.
    // If it has none, what you see now stays, and the first thing you change
    // becomes its look.
    onWallpaperChanged: {
        const was = root.previous;
        root.previous = root.wallpaper;
        if (!Config.looks.enabled || !root.loaded || root.switchingLook || root.bookLook === "")
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
            let parsed = null;
            try {
                parsed = JSON.parse(text());
            } catch (e) {
                parsed = null;
            }
            if (parsed && typeof parsed === "object" && parsed["__byLook__"]) {
                root.books = parsed["__byLook__"];
                root.lasts = parsed["__last__"] ?? ({});
                root.legacy = null;
            } else {
                root.books = ({});
                root.lasts = ({});
                root.legacy = (parsed && typeof parsed === "object") ? parsed : ({});
            }
            root.loaded = true;
            root.adopt();
        }

        onLoadFailed: {
            root.books = ({});
            root.lasts = ({});
            root.legacy = ({});
            root.loaded = true;
            root.adopt();
        }
    }
}
