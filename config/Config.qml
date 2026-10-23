//  VELVET  ·  config/Config.qml
//  The single source of truth. JSON on disk, live QML properties in memory.
//  Every widget binds to this; every settings row writes to this. No restarts.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.config/velvet`
    readonly property string path: `${dir}/config.json`

    // Sub-object shortcuts so call sites stay short: Config.bar.thickness
    readonly property var appearance: adapter.appearance
    readonly property var bar: adapter.bar
    readonly property var hypr: adapter.hypr
    readonly property var services: adapter.services
    readonly property var map: adapter.map
    readonly property var scene: adapter.scene
    readonly property var lyrics: adapter.lyrics
    readonly property var looks: adapter.looks
    readonly property var launcher: adapter.launcher
    readonly property var notifs: adapter.notifs
    readonly property var osd: adapter.osd
    readonly property var wallpaper: adapter.wallpaper
    readonly property var lock: adapter.lock
    readonly property var login: adapter.login
    readonly property var sfx: adapter.sfx
    readonly property var home: adapter.home
    readonly property var velly: adapter.velly
    readonly property var night: adapter.night
    readonly property var books: adapter.books
    readonly property var pad: adapter.pad
    readonly property var display: adapter.display

    // DISPLAY → RESOLUTION's choices, filled by services/Monitors.qml from
    // the screen itself (Schema reads them here: no service in config/).
    property var monitorModes: [
        {
            value: "auto",
            label: "AUTO"
        }
    ]

    property bool loaded: false

    // Any setting changed — however it happened (a slider, a preset, a look,
    // a hand edit). Looks watches this to remember what you tweak.
    signal edited

    // ---------------------------------------------------------------- generic access
    // The settings menu is data driven: it addresses everything by dotted key
    // ("bar.clock.format24h"), so it never needs to know what a setting *is*.
    function get(key: string): var {
        const parts = key.split(".");
        let obj = adapter;
        for (let i = 0; i < parts.length; i++) {
            if (obj === null || obj === undefined)
                return undefined;
            obj = obj[parts[i]];
        }
        return obj;
    }

    // Settings with a fixed set of words. A config.json, a saved look or an
    // IPC call may carry a word that is no longer one of them (a value that
    // was renamed); it is read as the first word, the default, so nothing
    // ever falls through to a face or a style that does not exist.
    readonly property var words: ({
            "lock.look": ["fluid", "soft", "velvet", "vibe"],
            "lock.passwordShapes": ["pop", "settle", "circles"],
            // looks that were taken out of the shell fall back to the house
            "appearance.skin": ["persona", "console", "arcade", "hud", "ledger", "glass", "tome", "poster", "clean", "win"],
            "appearance.typeStyle": ["persona", "soft", "mono", "serif", "block", "arcade", "tech", "clean", "win"],
            "appearance.backdrop": ["persona", "plain", "grid", "dots", "checker", "ruled", "vignette", "aurora"],
            "appearance.vibe": ["", "arcade", "cyber", "terminal", "paper", "glass", "rpg", "brutal", "clean", "minimal", "flat", "neu", "clay", "windows", "ink", "chrome"],
            "sfx.pack": ["velvet", "arcade", "cyber", "terminal", "paper", "glass", "rpg", "brutal", "clean", "windows"],
            "services.btQuality": ["best", "stable", "safest"],
            "velly.speakWhen": ["spoken", "always"],
            "books.lang": ["de", "en"],
            "velly.voiceThinking": ["fast", "balanced"],
            "velly.textThinking": ["thorough", "balanced"],
            "wallpaper.liveStyle": ["auto", "dust", "leaves", "petals", "snow", "rain", "fireflies", "stars", "fog", "glow", "sheen", "rays"],
            "wallpaper.liveWind": ["auto", "left", "right", "none"],
            "wallpaper.liveColour": ["picture", "gold", "white", "red", "orange", "pink", "purple", "blue", "turquoise", "green", "silver"]
        })

    function current(key: string, value: var): var {
        const list = root.words[key];
        return list && list.indexOf(value) < 0 ? list[0] : value;
    }

    // Rewrites any such word found in the file — once, after loading.
    function migrate(): void {
        const batch = {};
        for (const key in root.words) {
            const v = root.get(key);
            const now = root.current(key, v);
            if (now !== v)
                batch[key] = now;
        }
        if (Object.keys(batch).length > 0)
            root.setMany(batch);
    }

    function set(key: string, value: var): void {
        value = root.current(key, value);
        const parts = key.split(".");
        let obj = adapter;
        for (let i = 0; i < parts.length - 1; i++) {
            if (obj === null || obj === undefined)
                return;
            obj = obj[parts[i]];
        }
        if (obj !== null && obj !== undefined)
            obj[parts[parts.length - 1]] = value;
    }

    function toggle(key: string): void {
        root.set(key, !root.get(key));
    }

    // Many settings at once ({ "bar.position": "top", … }) — ONE write at
    // the end. Writing after every key let the file machinery hand older
    // values back in the middle of the burst (measured: every second key of
    // a look snapped back); a batch never writes half a change.
    property bool batching: false

    function setMany(map: var): void {
        root.batching = true;
        try {
            for (const key in map)
                root.set(key, map[key]);
        } finally {
            root.batching = false;
        }
        root.save();
    }

    // A write is always a beat later (see writeSoon below), so a save right
    // after a burst of sets writes them all at once.
    function save(): void {
        writeSoon.restart();
    }

    // Our own writes come back as "the file changed". Reloading that echo
    // is at best useless and at worst harmful: a setting changed between
    // the write and its echo (a slider still moving) would be handed back
    // its older value. So a change that arrives right after our own write
    // is taken for its echo; an edit from outside (a hand-edited
    // config.json) is still read, as before.
    property real lastWrite: 0

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false

        onFileChanged: {
            if (Date.now() - root.lastWrite < 1500)
                return;
            reload();
        }
        // Written a beat later, not on every key: two settings changed in
        // one go (a style arrow sets the face AND the shape) used to lose
        // the second — the write in between handed the old value back.
        onAdapterUpdated: {
            root.edited();
            if (!root.batching)
                writeSoon.restart();
        }
        onLoaded: {
            root.loaded = true;
            root.migrate();
        }
        onLoadFailed: err => {
            // First run: materialise the defaults below onto disk.
            if (err === FileViewError.FileNotFound)
                seed.restart();
            else
                // A config.json that no longer parses (hand-edited, truncated
                // by a crash) must not take the whole shell down with it: the
                // defaults are already in memory, so run on those. The file
                // is rewritten the next time anything is changed.
                root.loaded = true;
        }

        ConfigData {
            id: adapter
        }
    }

    Timer {
        id: writeSoon

        interval: 40
        onTriggered: {
            root.lastWrite = Date.now();
            file.writeAdapter();
        }
    }

    Process {
        id: mkdir
        running: true
        command: ["mkdir", "-p", root.dir]
    }

    // The defaults: every setting as the shell ships it, never loaded.
    ConfigData {
        id: factory
    }

    function defaultOf(key: string): var {
        const parts = key.split(".");
        let obj = factory;
        for (let i = 0; i < parts.length; i++) {
            if (obj === null || obj === undefined)
                return undefined;
            obj = obj[parts[i]];
        }
        return obj;
    }

    // First run: give mkdir a moment to land, then materialise the defaults.
    Timer {
        id: seed
        interval: 350
        onTriggered: {
            file.writeAdapter();
            root.loaded = true;
        }
    }
}
