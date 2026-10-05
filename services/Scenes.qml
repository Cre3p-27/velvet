//  VELVET  ·  services/Scenes.qml
//  A scene is the set of windows that belong on the desktop, and where.
//
//  You arrange it by dragging things onto a picture of your screen in
//  Super+Tab → DESKTOP. It is remembered against the wallpaper that was up
//  when you made it, so a wallpaper is not just a picture any more — it is a
//  desk, with the things you keep on that desk. On login the scene for the
//  current wallpaper starts itself.
//
//  Launching is deliberately belt-and-braces. Hyprland's exec window rules
//  place the window as it opens, which is the version with no flicker; then,
//  once the window actually exists, the same geometry is applied again through
//  ordinary dispatches, and once more after a beat if it did not take. That
//  third pass is not paranoia: `resize` means "exact" in one dispatch dialect
//  and could mean "by this much" in the other, and measuring is the only way
//  to be sure which one you got.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property string path: `${Quickshell.env("HOME")}/.config/velvet/scenes.json`
    readonly property string anyKey: "__default__"

    property var store: ({})
    property bool loaded: false
    property int nextId: 1

    // Which scene is in play: the one saved for this wallpaper, or the one you
    // marked as belonging everywhere.
    readonly property string key: Config.wallpaper.current || root.anyKey

    // ── editing another scene, not necessarily the live one
    //  The DESKTOP designer can open ANY saved scene, not just the one that
    //  belongs to the wallpaper currently up. `editKey` says which one is on
    //  the designer's table; empty means "follow the live one". Every editor
    //  write below goes to `editingKey`, so a scene you are only looking at
    //  never touches the desktop you are actually on.
    property string editKey: ""
    readonly property string editingKey: root.editKey || root.key
    readonly property bool editingElsewhere: root.editKey !== "" && root.editKey !== root.key
    // A wallpaper without its own scene shows the EVERYWHERE one — the same
    // rule `items` follows — so the designer edits what is actually on the
    // desk. The first change copies it into this wallpaper's own scene.
    readonly property var editing: Array.isArray(root.store[root.editingKey]) ? root.store[root.editingKey] : (root.editingOwnable ? root.fallback : [])
    readonly property bool editingHasOwn: Array.isArray(root.store[root.editingKey])
    readonly property bool editingOwnable: root.editingKey !== root.anyKey
    readonly property bool editingUsingFallback: root.editingOwnable && !root.editingHasOwn && root.fallback.length > 0
    readonly property bool editingCanFallBack: root.editingOwnable && root.editingHasOwn && root.fallback.length > 0

    readonly property int editingCount: root.editing.length
    readonly property int editingLiveCount: {
        let n = 0;
        for (let i = 0; i < root.editing.length; i++)
            if (root.isRunning(root.editing[i]))
                n++;
        return n;
    }

    readonly property string editingStatus: {
        if (!root.loaded)
            return "LOADING…";
        if (!root.editingElsewhere)
            return root.status;
        const name = root.nameOf(root.editingKey).toUpperCase();
        if (root.editingCount === 0)
            return `EDITING ${name}  ·  NOTHING SAVED ON THIS DESKTOP`;
        return `EDITING ${name}  ·  ${root.editingCount} ITEM${root.editingCount === 1 ? "" : "S"}  ·  LIVE DESKTOP UNTOUCHED`;
    }

    //  An EMPTY list saved against this wallpaper is not the same as no list
    //  at all: the first means "nothing belongs on this desktop", the second
    //  means "use the one that applies everywhere". Clearing has to be able to
    //  say the first, or the everywhere-scene comes straight back.
    readonly property var own: Array.isArray(root.store[root.key]) ? root.store[root.key] : []
    readonly property var fallback: Array.isArray(root.store[root.anyKey]) ? root.store[root.anyKey] : []
    readonly property bool hasOwn: Array.isArray(root.store[root.key])

    readonly property bool ownable: root.key !== root.anyKey
    readonly property var items: root.hasOwn ? root.own : (root.ownable ? root.fallback : [])
    readonly property bool usingFallback: root.ownable && !root.hasOwn && root.fallback.length > 0
    // Only meaningful when this wallpaper has a desk of its own to drop.
    readonly property bool canFallBack: root.ownable && root.hasOwn && root.fallback.length > 0

    readonly property int count: root.items.length
    readonly property int saved: Object.keys(root.store).length

    readonly property string status: {
        if (!root.loaded)
            return "LOADING…";
        if (root.count === 0)
            return `NOTHING ON THE DESKTOP YET  ·  ${root.saved} SCENE${root.saved === 1 ? "" : "S"} SAVED`;
        const where = root.usingFallback ? "FROM THE EVERYWHERE SCENE" : "FOR THIS WALLPAPER";
        return `${root.count} ITEM${root.count === 1 ? "" : "S"} ${where}  ·  ${root.liveCount} RUNNING`;
    }

    readonly property int liveCount: {
        let n = 0;
        for (let i = 0; i < root.items.length; i++)
            if (root.isRunning(root.items[i]))
                n++;
        return n;
    }

    // ═══════════════════════════════════════════════════════════════ editing
    function write(list: var): void {
        const before = root.editingKey === root.key ? root.items.slice() : [];
        const next = Object.assign({}, root.store);
        if (list === null || list === undefined)
            delete next[root.editingKey];
        else
            next[root.editingKey] = list;
        root.store = next;
        root.persist();
        if (before.length > 0)
            root.closeOrphans(before);
        // Visible confirmation that it is on disk — a quiet toast, debounced
        // so dragging a tile around does not spam the screen.
        root.writes = root.writes + 1;
        savedToast.restart();
    }

    property int writes: 0

    Timer {
        id: savedToast

        interval: 450
        onTriggered: {
            const name = root.editingKey === root.anyKey ? "EVERYWHERE" : root.nameOf(root.editingKey).toUpperCase();
            Toast.ok(`DESKTOP SAVED  ·  ${name}`);
        }
    }

    // Drop the scene you are editing, back to whatever applies everywhere.
    function useFallback(): void {
        root.snapshot("SAME AS EVERYWHERE");
        root.write(null);
    }

    // Modules that were on the live desk a moment ago and are not any more
    // (taken off, cleared, replaced by another desk, undone) close with it —
    // they used to keep running with nothing left that knew about them.
    // Only Velvet's own windows, matched by their exact per-entry class.
    function closeOrphans(before: var): void {
        if (root.editingElsewhere)
            return;
        const now = ({});
        for (let i = 0; i < root.items.length; i++)
            if (root.items[i])
                now[root.items[i].id] = true;
        for (let i = 0; i < before.length; i++) {
            const gone = before[i];
            if (!gone || now[gone.id] || (gone.kind !== "term" && gone.kind !== "tui"))
                continue;
            const want = root.norm(root.classFor(gone));
            for (let j = 0; j < Desk.windows.length; j++)
                if (root.norm(Desk.windows[j].cls) === want)
                    Desk.killTree(Desk.windows[j].address);
        }
    }

    // ── one step back
    //  Everything that replaces, clears or deletes a whole desk (or takes a
    //  thing off one) keeps the store as it was, so UNDO in DESKTOP can put
    //  it back. One step, the latest — enough to take back a mis-click.
    property var undoStore: null
    property string undoWhat: ""

    function snapshot(what: string): void {
        root.undoStore = JSON.parse(JSON.stringify(root.store));
        root.undoWhat = what;
        undoExpiry.restart();
    }

    function undo(): void {
        if (!root.undoStore)
            return;
        const what = root.undoWhat;
        const before = root.items.slice();
        root.store = root.undoStore;
        root.undoStore = null;
        root.undoWhat = "";
        root.persist();
        root.closeOrphans(before);
        root.writes = root.writes + 1;
        Sfx.back();
        Toast.ok(`UNDONE  ·  ${what}`);
    }

    Timer {
        id: undoExpiry

        interval: 120000
        onTriggered: {
            root.undoStore = null;
            root.undoWhat = "";
        }
    }

    // ── which saved scene is on the designer's table
    function nameOf(key: string): string {
        const p = String(key ?? "").split("/").pop();
        return p || String(key ?? "") || "UNNAMED";
    }

    function edit(key: string): void {
        root.editKey = (key === root.key) ? "" : key;
        Sfx.select();
        if (!root.editingElsewhere)
            Toast.ok("EDITING THE LIVE DESKTOP");
        else
            Toast.ok(`EDITING  ·  ${root.nameOf(root.editingKey).toUpperCase()}`);
    }

    // Every saved desktop, in one list the designer can show. Live scene
    // first, EVERYWHERE second, the rest by name.
    readonly property var savedList: {
        const out = [];
        for (const k in root.store)
            out.push({
                key: k,
                name: k === root.anyKey ? "EVERYWHERE" : root.nameOf(k),
                count: Array.isArray(root.store[k]) ? root.store[k].length : 0,
                live: k === root.key,
                editing: k === root.editingKey
            });
        out.sort((a, b) => {
            if (a.live !== b.live)
                return a.live ? -1 : 1;
            if ((a.key === root.anyKey) !== (b.key === root.anyKey))
                return a.key === root.anyKey ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
        return out;
    }

    // A saved scene that is not the live one, brought onto this wallpaper.
    function copyToCurrent(key: string): void {
        const list = Array.isArray(root.store[key]) ? root.store[key] : null;
        if (!list || key === root.key)
            return;
        root.snapshot(`REPLACED WITH ${root.nameOf(key).toUpperCase()}`);
        const before = root.items.slice();
        const next = Object.assign({}, root.store);
        next[root.key] = list.slice();
        root.store = next;
        root.persist();
        root.closeOrphans(before);
        root.editKey = "";
        Toast.ok(`DESKTOP COPIED TO  ·  ${root.nameOf(root.key).toUpperCase()}`);
    }

    // Delete a saved desktop, whichever one it is. The live scene has no row
    // to disappear into, so dropping it hands this wallpaper back to the
    // EVERYWHERE scene. EVERYWHERE itself is just another row here. Nothing
    // is permanent — every desk can be re-arranged and re-saved.
    function removeScene(key: string): void {
        if (!key || !(key in root.store))
            return;
        root.snapshot(`DELETED ${key === root.anyKey ? "EVERYWHERE" : root.nameOf(key).toUpperCase()}`);
        if (key === root.anyKey) {
            root.forgetDefault();
            return;
        }
        if (key === root.key) {
            const next = Object.assign({}, root.store);
            delete next[root.key];
            root.store = next;
            root.persist();
            root.editKey = "";
            Toast.ok(`DESKTOP DROPPED  ·  ${root.nameOf(key).toUpperCase()} NOW ON EVERYWHERE`);
            return;
        }
        const next = Object.assign({}, root.store);
        delete next[key];
        root.store = next;
        root.persist();
        if (root.editKey === key)
            root.editKey = "";
        Toast.ok(`DESKTOP DELETED  ·  ${root.nameOf(key).toUpperCase()}`);
    }

    function add(item: var): void {
        const entry = Object.assign({
            id: `i${root.nextId}`,
            kind: "app",
            x: 0.1,
            y: 0.1,
            w: 0.3,
            h: 0.35,
            ws: 0,
            float: true,
            // Every terminal module's own knobs: see-through, a tint for the
            // Velvet ones, extra arguments for the extra ones.
            opts: {
                transparent: false,
                tint: "auto",
                args: "",
                flags: []
            }
        }, item ?? ({}));
        root.nextId = root.nextId + 1;
        root.write(root.editing.concat([entry]));
        if (entry.kind === "widget")
            root.ensureWidgetLayer();
    }

    // Placing a widget is asking to see it: switch the wallpaper's widget
    // layer on if it is off, and say so — a widget that lands on a hidden
    // layer looks exactly like a widget that is broken.
    function ensureWidgetLayer(): void {
        if (Config.wallpaper.renderer !== "builtin") {
            Toast.warn("WIDGETS NEED VELVET'S OWN WALLPAPER · WALLPAPER → RENDERER → BUILT-IN");
            return;
        }
        if (Config.wallpaper.living && Config.wallpaper.livingWidgets)
            return;
        Config.set("wallpaper.living", true);
        Config.set("wallpaper.livingWidgets", true);
        Toast.ok("LIVING DESKTOP ON · YOUR WIDGETS NOW SHOW ON THE WALLPAPER");
    }

    function patchAt(i: int, fields: var): void {
        if (i < 0 || i >= root.editing.length)
            return;
        const list = root.editing.slice();
        list[i] = Object.assign({}, list[i], fields);
        root.write(list);
        if ("x" in fields || "y" in fields || "w" in fields || "h" in fields || "ws" in fields)
            root.follow(list[i]);
    }

    function removeAt(i: int): void {
        if (i < 0 || i >= root.editing.length)
            return;
        const gone = root.editing[i];
        root.snapshot(`TOOK OFF ${root.labelFor(gone).toUpperCase()}`);
        const list = root.editing.slice();
        list.splice(i, 1);
        // Its window closes with it (write → closeOrphans). An app you
        // placed (Spotify, a browser) is yours and stays open.
        root.write(list);
    }

    function clearScene(): void {
        root.snapshot("CLEARED THE DESK");
        root.write([]);
    }

    // Copy what is on screen now into the scene that every wallpaper falls
    // back to. The one button that turns "this desk" into "my desk".
    function makeDefault(): void {
        root.snapshot("EVERYWHERE REPLACED");
        const next = Object.assign({}, root.store);
        next[root.anyKey] = root.editing.slice();
        root.store = next;
        root.persist();
        Toast.ok("THIS DESKTOP NOW APPLIES TO EVERY WALLPAPER");
    }

    function forgetDefault(): void {
        const next = Object.assign({}, root.store);
        delete next[root.anyKey];
        root.store = next;
        root.persist();
    }

    // Take the windows that are open right now and make a scene out of them.
    // Far faster than placing eight things by hand, and it is the answer to
    // "I already arranged this, just remember it".
    function captureOpen(): void {
        // Captures into the scene being EDITED — the designer is showing that
        // one, so that is the one the user means.
        const m = Desk.focusedMonitor;
        if (!m) {
            Toast.warn("NO MONITOR TO MEASURE AGAINST");
            return;
        }
        const list = [];
        let n = root.nextId;
        for (let i = 0; i < Desk.windows.length; i++) {
            const w = Desk.windows[i];
            if (w.monName !== m.name)
                continue;
            const entry = root.entryForClass(w.cls);
            list.push({
                id: `i${n++}`,
                // No desktop entry means we know where it sat but not how to
                // start it. Say so in the scene rather than inventing one.
                kind: entry ? "app" : "cmd",
                app: entry ? entry.id : "",
                cmd: "",
                name: entry ? entry.name : (w.cls || w.title),
                icon: entry ? entry.icon : "",
                x: Math.max(0, Math.min(0.98, (w.x - m.x) / m.w)),
                y: Math.max(0, Math.min(0.98, (w.y - m.y) / m.h)),
                w: Math.max(0.05, Math.min(1, w.w / m.w)),
                h: Math.max(0.05, Math.min(1, w.h / m.h)),
                ws: w.ws,
                float: true
            });
        }
        if (list.length === 0) {
            Toast.warn("NOTHING OPEN ON THIS SCREEN TO CAPTURE");
            return;
        }
        root.nextId = n;
        // Wallpaper widgets are not windows — keep them, replace the rest.
        root.write(root.editing.filter(it => it && it.kind === "widget").concat(list));
        Toast.ok(`CAPTURED ${list.length} WINDOW${list.length === 1 ? "" : "S"}`);
    }

    // ══════════════════════════════════════════════════════════ what an item is
    function entryFor(id: string): var {
        if (!id)
            return null;
        const apps = DesktopEntries.applications?.values ?? [];
        for (let i = 0; i < apps.length; i++)
            if (apps[i].id === id)
                return apps[i];
        return null;
    }

    //  A window class and a .desktop id agree far less often than you would
    //  hope: org.gnome.Nautilus, nautilus, Nautilus and "Files" are all the
    //  same program. Try every spelling before giving up.
    function entryForClass(cls: string): var {
        if (!cls)
            return null;
        const want = cls.toLowerCase();
        const tail = want.split(".").pop();
        const apps = DesktopEntries.applications?.values ?? [];
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i];
            const sc = (e.startupClass ?? "").toLowerCase();
            const id = (e.id ?? "").toLowerCase().replace(/\.desktop$/, "");
            const idTail = id.split(".").pop();
            const nm = (e.name ?? "").toLowerCase();
            if (sc && (sc === want || sc.toLowerCase().split(".").pop() === tail))
                return e;
            if (id && (id === want || idTail === tail))
                return e;
            if (nm && (nm === want || nm === tail))
                return e;
        }
        return null;
    }

    // A .desktop Exec line still carries field codes (%u, %f, %U …) that mean
    // "the file the user dropped on the icon". There is no such file here, and
    // passing them through literally is how you get a browser that opens a tab
    // called "%u".
    function execOf(entry: var): string {
        if (!entry)
            return "";
        const parts = entry.command ?? [];
        const out = [];
        for (let i = 0; i < parts.length; i++) {
            const p = String(parts[i]);
            // Field codes, and the @@ / @@u placeholders a Flatpak export
            // wraps its file arguments in. Neither means anything here, and
            // passing them through is how a browser opens a tab called "%u".
            if (p.startsWith("%") || p === "@@" || p === "@@u" || p === "@@U")
                continue;
            if (/^[A-Za-z0-9_@%+=:,./-]+$/.test(p)) {
                out.push(p);
                continue;
            }
            out.push('"' + p.split('"').join('\\"') + '"');
        }
        if (out.length === 0)
            return String(entry.execString ?? "").replace(/%[a-zA-Z]/g, "").trim();
        return out.join(" ");
    }

    // The catalogue id of a module entry (velvet module or terminal program).
    function moduleOf(item: var): string {
        if (!item)
            return "";
        if (item.kind === "term")
            return item.term || "";
        if (item.kind === "tui")
            return item.tui || item.id || "";
        return "";
    }

    //  CAVA is drawn by the shell on the wallpaper (components/CavaPreview,
    //  from the same switches) instead of in a terminal window: part of the
    //  picture, on every desktop, untouched by the zoom and by SUPER+D's
    //  tiling. opts.draw: "window" brings the old kitty window back.
    function drawnOf(item: var): bool {
        return !!item && item.kind === "tui" && root.moduleOf(item) === "cava" && (item.opts?.draw ?? "") !== "window";
    }
    readonly property var drawnItems: root.items.filter(it => root.drawnOf(it))

    // a drawn module's old window (from before, or from the window mode) goes
    function dropWindowOf(item: var): void {
        const w = root.windowFor(item);
        if (w)
            Desk.killTree(w.address);
    }

    // ── live settings
    //  A running module takes new settings without a restart: its switches
    //  through a small file it watches (bin/_velvet.py, bin/velvet-cava),
    //  its window through kitty's remote control. Both are per ENTRY, so two
    //  CAVAs are two files and two sockets.
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    function livePath(item: var): string {
        return `${root.runDir}/velvet-mod-${item.id}.args`;
    }

    // An abstract socket (no file): nothing is left behind to block the next
    // start after a crash.
    function kittySock(item: var): string {
        return `@velvet-kitty-${item.id}`;
    }

    // Velvet's own programs and the ones it wraps (cava) read a live file;
    // other terminal programs only read their command line.
    function liveCapable(item: var): bool {
        if (!item || !item.id)
            return false;
        if (item.kind === "term")
            return true;
        return item.kind === "tui" && (TermApps.byId(root.moduleOf(item))?.wrap ?? "") !== "";
    }

    // The switches of a module, as the program reads them.
    function moduleArgs(item: var): string {
        const opts = item?.opts ?? ({});
        const mod = root.moduleOf(item);
        const out = [];
        if (item.kind === "term") {
            const tint = String(opts.tint ?? "auto");
            // A hex tint travels without its "#" — a shell reads that as the
            // start of a comment.
            if (tint !== "auto" && /^#?[0-9a-fA-F]{6}$|^[a-z]+$/.test(tint))
                out.push(`--tint ${tint.replace("#", "")}`);
            const shared = TermApps.argsFor(TermApps.shared, opts.o);
            if (shared)
                out.push(shared);
        }
        const own = TermApps.argsFor(TermApps.optionsOf(mod), opts.o);
        if (own)
            out.push(own);
        return out.join(" ");
    }

    function writeLive(item: var): void {
        Quickshell.execDetached(["python3", "-c", "import os,sys\np=sys.argv[1]\nopen(p+'.tmp','w').write(sys.argv[2])\nos.replace(p+'.tmp',p)", root.livePath(item), root.moduleArgs(item)]);
    }

    // How the compositor treats a module's window. CLICK-THROUGH (no_focus)
    // hands every click to whatever lies underneath — verified: a click on a
    // no_focus window focuses the window below it — so a cava strip over
    // the bottom of the screen never gets in the way. BARE drops border,
    // shadow and blur: a module that looks like part of the wallpaper, not
    // like a window (a clear background otherwise showed a frosted box).
    function applyProps(item: var, win: var): void {
        if (!item || !win || (item.kind !== "term" && item.kind !== "tui"))
            return;
        const opts = item.opts ?? ({});
        const through = opts.pointer === "through";
        const bare = opts.look === "bare";
        const set = (prop, on) => Hypr.act(`setprop address:${win.address} ${prop.replace(/_/g, "")} ${on ? 1 : 0}`, `hl.dsp.window.set_prop({ window = "address:${win.address}", prop = "${prop}", value = "${on ? 1 : 0}" })`);
        set("no_focus", through);
        // every desktop: pinned (only a floating window can be; place()
        // floats it first). Asked only when it differs, the pin toggles.
        const every = root.everyOf(item);
        if (win.floating && (win.pinned === true) !== every)
            Hypr.setPinned(win.address, every);
        // Hyprland 0.56 has no no_border; `decorate` off drops the window's
        // decoration (its border) — the other two are their own props.
        set("decorate", !bare);
        set("no_shadow", bare);
        set("no_blur", bare);
    }

    // The edge a module stands on — cava's bars grow out of it. kitty keeps
    // padding only on the FAR side (the bars run edge to edge along the
    // edge they stand on, and touch it) and puts its spare pixels (a window
    // is rarely an exact number of cells) there too, so nothing hovers a
    // little above the edge or stops short of the screen's sides.
    // "" = no edge (centred, padding all round).
    function edgeOf(item: var): string {
        if (root.moduleOf(item) !== "cava")
            return "";
        const o = item?.opts?.o ?? ({});
        return ({
                "": "bottom",
                up: "bottom",
                down: "top",
                left: "left",
                right: "right"
            })[String(o.orient ?? "")] ?? "";
    }

    function farSide(edge: string): string {
        return ({
                top: "bottom",
                bottom: "top",
                left: "right",
                right: "left"
            })[edge] ?? "";
    }

    // Text size, background and padding, pushed into the running kitty —
    // and the compositor's side of the window.
    function applyWindow(item: var): void {
        const w = item ? root.windowFor(item) : null;
        if (w)
            root.applyProps(item, w);
        if (Term.chosen !== "kitty" || !item?.id)
            return;
        const opts = item.opts ?? ({});
        const win = opts.win ?? ({});
        const size = Number(win.size ?? 0);
        const bg = opts.transparent ? 0 : Number(win.bg ?? -1);
        const pad = Number(win.pad ?? -1);
        const to = `unix:${root.kittySock(item)}`;
        Quickshell.execDetached(["kitty", "@", "--to", to, "set-font-size", String(size > 0 ? size : 0)]);
        Quickshell.execDetached(["kitty", "@", "--to", to, "set-background-opacity", String(bg >= 0 && bg < 1 ? bg : 1)]);
        const edge = root.edgeOf(item);
        const spacing = [pad >= 0 ? `padding=${pad}` : "padding=default"];
        if (edge)
            for (const side of ["top", "right", "bottom", "left"])
                if (side !== root.farSide(edge))
                    spacing.push(`padding-${side}=0`);
        Quickshell.execDetached(["kitty", "@", "--to", to, "set-spacing"].concat(spacing));
    }

    // Everything the designer can change, into the running module — no
    // restart. False when the module cannot take its switches live (a plain
    // terminal program): the caller restarts it instead.
    function applyLive(item: var): bool {
        if (!item || item.kind === "widget" || !root.isRunning(item))
            return true;
        root.applyWindow(item);
        if (!root.liveCapable(item))
            return false;
        root.writeLive(item);
        return true;
    }

    // A monitor that sleeps hands every window to Hyprland's FALLBACK
    // output and back when it wakes — modules came back shifted and cut off
    // (a 3200-px cava on a 1920 fallback, at x = -636). When the set of
    // monitors changes, every module on the live desk returns to its box.
    property string monitorSig: ""

    Connections {
        target: Desk
        function onMonitorsChanged(): void {
            const sig = Desk.monitors.map(m => `${m.name}:${m.w}x${m.h}`).join(",");
            if (sig === root.monitorSig)
                return;
            const first = root.monitorSig === "";
            root.monitorSig = sig;
            if (!first)
                replaceTimer.restart();
        }
    }

    Timer {
        id: replaceTimer

        interval: 2500
        onTriggered: {
            for (let i = 0; i < root.items.length; i++) {
                const it = root.items[i];
                if (it && (it.kind === "term" || it.kind === "tui"))
                    root.follow(it);
            }
        }
    }

    // Arranging the desk moves the real window with it.
    function follow(item: var): void {
        if (!item || item.kind === "widget" || root.editingElsewhere)
            return;
        const win = root.windowFor(item);
        if (win)
            root.place(item, win);
    }

    function commandFor(item: var): string {
        if (!item)
            return "";
        if (item.kind === "term" || item.kind === "tui") {
            const opts = item.opts ?? ({});
            const mod = root.moduleOf(item);
            let cmd;
            let hold = false;
            if (item.kind === "term") {
                const p = TermApps.pathOf(mod);
                if (!p)
                    return "";
                cmd = p;
                const args = root.moduleArgs(item);
                if (args)
                    cmd += ` ${args}`;
            } else {
                cmd = TermApps.resolvedRun(mod);
                const fl = opts.flags;
                if (fl && fl.length !== undefined)
                    for (let i = 0; i < fl.length; i++)
                        if (fl[i])
                            cmd = cmd ? `${cmd} ${fl[i]}` : fl[i];
                const own = root.moduleArgs(item);
                if (own)
                    cmd = cmd ? `${cmd} ${own}` : own;
                if (opts.args)
                    cmd = cmd ? `${cmd} ${opts.args}` : opts.args;
                if (TermApps.holdOf(mod))
                    hold = true;
            }
            if (root.liveCapable(item))
                cmd += ` --live ${root.livePath(item)}`;
            // The window itself (kitty): text size, how solid the background
            // is, and the air around the content — and a remote-control
            // socket of its own, so the designer can change all three while
            // it runs.
            const win = opts.win ?? ({});
            const size = Number(win.size ?? 0);
            const bgo = opts.transparent ? 0 : Number(win.bg ?? -1);
            const pad = Number(win.pad ?? -1);
            // kitty reads four paddings as top right bottom left.
            const edge = root.edgeOf(item);
            const sides = ["top", "right", "bottom", "left"].map(e => e === root.farSide(edge) ? Math.max(0, pad) : 0);
            const extra = [
                size > 0 ? `-o font_size=${size}` : "",
                bgo >= 0 && bgo < 1 ? `-o background_opacity=${bgo}` : "",
                pad >= 0 ? (edge ? `-o 'window_padding_width=${sides.join(" ")}'` : `-o window_padding_width=${pad}`) : (edge ? `-o window_padding_width=0` : ""),
                edge ? `-o placement_strategy=${edge}` : "",
                item.id ? `-o allow_remote_control=socket-only -o dynamic_background_opacity=yes --listen-on unix:${root.kittySock(item)}` : "",
                hold ? "--hold" : ""
            ].filter(s => s !== "").join(" ");
            return Term.wrap(root.classFor(item), root.titleFor(item), cmd, extra);
        }
        if (item.kind === "cmd")
            return item.cmd || "";
        const e = root.entryFor(item.app || "");
        if (e) {
            const line = root.execOf(e);
            // Some entries are console programs. Running one under Hyprland's
            // exec opens no window at all, which looks exactly like a scene
            // item that silently does nothing.
            if (line && e.runInTerminal === true)
                return Term.wrap(root.classFor(item), root.titleFor(item) || `velvet-${e.id}`, line);
            return line;
        }
        return item.cmd || "";
    }

    //  Does it stay put while the canvas pans and zooms? A widget lives on the
    //  wallpaper and always does. A module's own window (cava, vitals …)
    //  defaults to staying put too, so it sits where the widgets sit; a
    //  program's window moves with the canvas unless told otherwise. Each
    //  can be switched in its inspector (opts.canvas: "fixed" | "moves").
    function pinnedOf(item: var): bool {
        if (!item || item.kind === "widget")
            return true;
        const c = item.opts?.canvas ?? "";
        if (c === "fixed")
            return true;
        if (c === "moves")
            return false;
        return item.kind === "tui";
    }

    //  On every desktop? A module that stays put (cava along an edge, vitals …)
    //  belongs to the desktop like the widgets do, so by default it is pinned
    //  and follows you to every workspace. opts.every: false keeps it on one.
    function everyOf(item: var): bool {
        if (!item || (item.kind !== "term" && item.kind !== "tui") || item.float === false)
            return false;
        if (item.opts?.every === false)
            return false;
        return root.pinnedOf(item);
    }

    // Window classes of every fixed window of every desktop, one per line —
    // the canvas scripts (infinite_desktop_core, navigate_windows,
    // move_window, desktop_zoom) read this file and leave those windows be.
    readonly property string fixedKey: {
        const out = {};
        const keys = Object.keys(root.store);
        for (let k = 0; k < keys.length; k++) {
            const list = root.store[keys[k]];
            if (!Array.isArray(list))
                continue;
            for (let i = 0; i < list.length; i++) {
                const it = list[i];
                if (it && it.kind !== "widget" && !root.drawnOf(it) && root.pinnedOf(it))
                    out[root.classFor(it)] = true;
            }
        }
        return Object.keys(out).filter(c => c).sort().join("\n");
    }
    readonly property string fixedPath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/velvet-fixed`

    onFixedKeyChanged: {
        if (root.loaded)
            root.writeFixed();
    }
    onLoadedChanged: {
        if (root.loaded) {
            root.writeFixed();
            pinPass.restart();
        }
    }

    // Modules already running when the shell starts (or reloads) get their
    // desktop rule too: every fixed one is pinned to every workspace.
    Timer {
        id: pinPass

        interval: 4000
        onTriggered: {
            for (let i = 0; i < root.items.length; i++) {
                const it = root.items[i];
                if (it && root.drawnOf(it))
                    root.dropWindowOf(it);
                else if (it && (it.kind === "term" || it.kind === "tui"))
                    root.applyWindow(it);
            }
        }
    }

    function writeFixed(): void {
        Quickshell.execDetached(["python3", "-c", "import os,sys\np=sys.argv[1]\nopen(p+'.tmp','w').write(sys.argv[2])\nos.replace(p+'.tmp',p)", root.fixedPath, root.fixedKey]);
    }

    function isFixedClass(cls: string): bool {
        return !!cls && root.fixedKey.split("\n").indexOf(cls) >= 0;
    }

    //  A reverse-DNS class, because ghostty validates --class as a GTK
    //  application id and rejects anything without a dot in it.
    function classFor(item: var): string {
        if (!item)
            return "";
        // One class per ENTRY (dev.velvet.cava.i53), so two of the same
        // module are two windows the scene can tell apart.
        if (item.kind === "term" || item.kind === "tui")
            return `dev.velvet.${root.moduleOf(item) || "app"}${item.id ? "." + item.id : ""}`;
        const e = root.entryFor(item.app || "");
        const sc = e?.startupClass ?? "";
        if (sc)
            return sc;
        return (item.app || item.cmd || "").replace(/\.desktop$/, "").split(" ")[0].split("/").pop();
    }

    //  The second thing to match on. konsole, xfce4-terminal and xterm cannot
    //  be told what to call their window's class — but every one of the eight
    //  can be told its TITLE, so a terminal program always gets one, and
    //  matching accepts either. This is the difference between recognising
    //  your own clock on the next login and opening a second one.
    function titleFor(item: var): string {
        if (!item || (item.kind !== "term" && item.kind !== "tui"))
            return "";
        return `velvet-${root.moduleOf(item) || "app"}${item.id ? "-" + item.id : ""}`;
    }

    function norm(text: string): string {
        return String(text ?? "").toLowerCase().replace(/[_\s]+/g, "-");
    }

    function tail(text: string): string {
        const bits = root.norm(text).split(".");
        return bits[bits.length - 1];
    }

    function matches(item: var, win: var): bool {
        if (!item || !win)
            return false;

        // Velvet's modules: exact, per entry. A window started before
        // entries had classes of their own (dev.velvet.cava) still counts,
        // but only while it is the one entry of that module on the desk.
        if (item.kind === "term" || item.kind === "tui") {
            const cls = root.norm(win.cls);
            if (cls === root.norm(root.classFor(item)))
                return true;
            const mod = root.moduleOf(item);
            if (cls === root.norm(`dev.velvet.${mod}`)) {
                // Handed to the FIRST entry of that module, so it is never
                // orphaned and never claimed twice.
                const list = root.editing.some(it => it && it.id === item.id) ? root.editing : root.items;
                const first = list.find(it => it && root.moduleOf(it) === mod && (it.kind === "term" || it.kind === "tui"));
                return !first || first.id === item.id;
            }
            const t = root.norm(win.title);
            return t === root.norm(root.titleFor(item));
        }

        const wantTitle = root.titleFor(item);
        if (wantTitle && root.norm(win.title).indexOf(wantTitle) !== -1)
            return true;

        const a = root.norm(root.classFor(item));
        const b = root.norm(win.cls);
        if (!a || !b)
            return false;
        if (a === b)
            return true;

        // org.gnome.Nautilus against nautilus, and gnome-terminal against
        // org.gnome.Terminal. Compared on the last dot-segment, and long
        // enough that two short names cannot collide by accident.
        const ta = root.tail(a);
        const tb = root.tail(b);
        if (ta === tb)
            return true;
        if (ta.length >= 5 && tb.length >= 5 && (ta.endsWith(tb) || tb.endsWith(ta)))
            return true;
        return false;
    }

    function windowFor(item: var): var {
        for (let i = 0; i < Desk.windows.length; i++)
            if (root.matches(item, Desk.windows[i]))
                return Desk.windows[i];
        return null;
    }

    function isRunning(item: var): bool {
        // A wallpaper widget has no window: it is "running" whenever it is on
        // the desk, so a scene of widgets counts as complete.
        if (item && (item.kind === "widget" || root.drawnOf(item)))
            return true;
        return root.windowFor(item) !== null;
    }

    // The other half of the wallpaper switch: an item of the NEW scene whose
    // window survived the close pass (wrong workspace, or a kill that did
    // not take) still has to land where THIS wallpaper's layout says. Moving
    // it beats leaving it parked where the old desk put it.
    function rehomeExisting(): void {
        for (let i = 0; i < root.items.length; i++) {
            const it = root.items[i];
            if (it.float === false)
                continue;
            const win = root.windowFor(it);
            if (!win)
                continue;
            if (win.ws !== 1 && !root.everyOf(it))
                Desk.sendToWorkspace(win.address, 1);
            const g = root.pixelsFor(it);
            if (!g)
                continue;
            if (!win.floating)
                Desk.setFloating(win.address);
            Hypr.resizeExact(win.address, g.w, g.h);
            Desk.placeAt(win.address, g.x, g.y);
            if (root.everyOf(it) && win.pinned !== true)
                Hypr.setPinned(win.address, true);
        }
    }

    function iconFor(item: var): string {
        if (!item)
            return "";
        if (item.kind === "term")
            return "";
        if (item.icon)
            return item.icon;
        return root.entryFor(item.app || "")?.icon ?? "";
    }

    function labelFor(item: var): string {
        if (!item)
            return "";
        if (item.kind === "widget")
            return LockModules.find(item.widget ?? "")?.name ?? "WIDGET";
        if (item.name)
            return item.name;
        if (item.kind === "term")
            return TermApps.nameOf(item.term ?? "");
        return root.entryFor(item.app || "")?.name ?? (item.cmd || "");
    }

    // The live scene's widgets — the wallpaper's widget layer renders
    // exactly these, and the binding follows the scene on every wallpaper
    // switch.
    function liveWidgets(): var {
        return root.items.filter(it => it && it.kind === "widget");
    }

    // ══════════════════════════════════════════════════════════════ launching
    //  Fractions of a screen, not pixels: a scene made on the laptop still
    //  makes sense on the 4K.
    function pixelsFor(item: var): var {
        const m = Desk.focusedMonitor;
        if (!m || !item)
            return null;
        return {
            x: Math.round(m.x + (item.x ?? 0) * m.w),
            y: Math.round(m.y + (item.y ?? 0) * m.h),
            w: Math.max(160, Math.round((item.w ?? 0.3) * m.w)),
            h: Math.max(100, Math.round((item.h ?? 0.3) * m.h))
        };
    }

    property var pending: []
    readonly property bool working: root.pending.length > 0 || root.queue.length > 0

    // Every address a pending entry has already claimed. Two programs starting
    // a beat apart are both still LOOKING at the same moment, and without this
    // the slower one's entry grabs the faster one's window — placing one at
    // the wrong geometry and leaving the other unplaced for good.
    function claimed(): var {
        const out = ({});
        for (let i = 0; i < root.pending.length; i++)
            if (root.pending[i].addr)
                out[root.pending[i].addr] = true;
        return out;
    }

    function launchItem(item: var, force: bool): void {
        // Widgets live in the wallpaper layer, not in windows of their own —
        // there is nothing to run; the layer follows the scene by binding.
        if (item.kind === "widget")
            return;
        if (root.drawnOf(item)) {
            root.dropWindowOf(item);
            return;
        }
        const cmd = root.commandFor(item);
        if (!cmd) {
            Toast.warn(`${root.labelFor(item).toUpperCase()}: NOTHING TO RUN`);
            return;
        }
        if (!force && root.isRunning(item))
            return;

        const g = root.pixelsFor(item);
        const rules = [];
        if (item.float !== false)
            rules.push("float");
        if (g && item.float !== false) {
            rules.push(`size ${g.w} ${g.h}`);
            rules.push(`move ${g.x} ${g.y}`);
        }
        if (root.restrictWs) {
            if (Hypr.activeWsId !== 1)
                rules.push("workspace 1 silent");
        } else if ((item.ws ?? 0) > 0 && item.ws !== Hypr.activeWsId) {
            rules.push(`workspace ${item.ws} silent`);
        }

        // What is on screen the instant before we ask, so the window that
        // turns up afterwards can be told apart from the ones already there.
        // Anything another entry has already claimed counts as already there.
        const seen = root.claimed();
        for (let i = 0; i < Desk.windows.length; i++)
            seen[Desk.windows[i].address] = true;

        root.pending = root.pending.concat([
            {
                item: item,
                seen: seen,
                t: Date.now(),
                phase: "find",
                addr: "",
                polls: Desk.polls
            }
        ]);

        Hypr.execWith(rules, cmd);
        Desk.refresh();
    }

    // Close a running module and start it again — how a change to its
    // switches reaches the screen. The close is the same SIGTERM of the
    // process tree the scene switch uses; the start waits a beat for it.
    //  Two steps a beat apart (close, then start), and never while the
    //  last start of the same item is still looking for its window — a
    //  quick run of clicks restarts it once, never into two copies.
    function relaunch(item: var): void {
        if (!item || item.kind === "widget")
            return;
        relaunchTimer.item = item;
        relaunchTimer.closed = false;
        relaunchTimer.restart();
    }

    Timer {
        id: relaunchTimer

        property var item: null
        property bool closed: false

        interval: 450
        onTriggered: {
            const it = relaunchTimer.item;
            if (!it)
                return;
            if (root.pending.some(p => p.item && p.item.id === it.id)) {
                relaunchTimer.restart();
                return;
            }
            const win = root.windowFor(it);
            if (win && !relaunchTimer.closed) {
                relaunchTimer.closed = true;
                Desk.killTree(win.address);
                relaunchTimer.restart();
                return;
            }
            relaunchTimer.item = null;
            root.launchItem(it, true);
        }
    }

    // One at a time, a beat apart, so "the window that just appeared" never
    // means two different windows at once.
    property var queue: []
    property bool queueForce: false
    property bool quiet: false

    function launchAll(force: bool, quiet: bool): void {
        root.quiet = quiet === true;
        if (root.working) {
            if (!root.quiet)
                Toast.show("STILL OPENING THE LAST LOT", "info", 2200);
            return;
        }
        if (root.items.length === 0) {
            if (!root.quiet)
                Toast.show("NOTHING IS ARRANGED ON THIS DESKTOP YET", "info", 2600);
            return;
        }
        // Decide from FRESH window data, never from a poll that could be five
        // seconds old. Asking twice in a row used to open everything twice,
        // because the first lot had not appeared in the window list yet.
        root.queueForce = force;
        Desk.watch();
        settle.list = root.items;
        settle.restart();
    }

    // Open a scene that is not the live one — the saved-desktop list's OPEN.
    function launchKey(key: string, force: bool, quiet: bool): void {
        const list = Array.isArray(root.store[key]) ? root.store[key] : [];
        root.quiet = quiet === true;
        if (root.working) {
            if (!root.quiet)
                Toast.show("STILL OPENING THE LAST LOT", "info", 2200);
            return;
        }
        if (list.length === 0) {
            if (!root.quiet)
                Toast.show("NOTHING IS ARRANGED ON THAT DESKTOP", "info", 2600);
            return;
        }
        root.queueForce = force;
        Desk.watch();
        settle.list = list;
        settle.restart();
    }

    // OPEN WHAT IS MISSING in the designer: whatever scene is being edited,
    // live or not.
    function launchEditing(force: bool): void {
        if (root.editingElsewhere)
            root.launchKey(root.editingKey, force, false);
        else
            root.launchAll(force, false);
    }

    // ─────────────────────────────────────── scenes that follow the wallpaper
    //  A scene belongs to the wallpaper it was saved for. On login the scene
    //  of the current wallpaper comes up; when the wallpaper changes, the
    //  desktops the OLD scene touched are cleared COMPLETELY — every window
    //  on them closes, scene window or not — and then the new scene comes up.
    //  Both run silently: a toast two seconds after boot says nothing useful.
    //
    //  The wallpaper is followed through a Binding, not a Connections on
    //  Config.wallpaper: a config reload swaps the whole adapter — and with
    //  it the wallpaper object a Connections would be listening to, which is
    //  how the old hook went deaf. A Binding follows the VALUE, whatever
    //  object holds it.
    property string activeKey: ""
    property string prevKey: ""
    property string watchedWallpaper: ""
    // While a wallpaper-triggered scene comes up, everything is forced onto
    // workspace 1 — the user asked for that desktop alone to be rebuilt.
    property bool restrictWs: false

    Binding {
        target: root
        property: "watchedWallpaper"
        value: Config.wallpaper.current
        when: Config.loaded
    }

    onWatchedWallpaperChanged: {
        const nextKey = root.watchedWallpaper;
        if (nextKey === "" || nextKey === root.activeKey)
            return;
        const isBoot = root.activeKey === "";
        // Remember what the previous scene opened, then take the new key
        // immediately so a reload cascade cannot run this twice.
        root.prevKey = root.activeKey;
        root.activeKey = nextKey;
        // The designer only ever arranges the wallpaper that is up — a
        // wallpaper change always puts the live desk back on its table.
        root.editKey = "";
        // Boot belongs to the autostart timer below. Running this path too
        // opened the first item twice and pinned everything to workspace 1.
        if (isBoot)
            return;
        const enabled = isBoot ? Config.scene.autostart : Config.scene.onWallpaperChange;
        if (!enabled)
            return;      // off means off: nothing closes, nothing opens
        // Close on FRESH window data — a stale poll misses windows and
        // leaves doubles behind. The new scene opens on workspace 1 only,
        // and any window that survived the close pass gets re-homed onto
        // this wallpaper's layout afterwards.
        root.restrictWs = true;
        root.rehome = true;
        Desk.watch();
        closeOld.restart();
        sceneChange.restart();
    }

    // True while a wallpaper-triggered scene is coming up: windows of the
    // new scene that survived the close pass get moved onto the new
    // layout's spot instead of keeping wherever the old desk left them.
    property bool rehome: false

    Timer {
        id: closeOld

        interval: 350
        onTriggered: {
            Desk.refresh();
            root.closeDesktopFor(root.prevKey);
        }
    }

    // The close pass needs ~2 s of its own (SIGTERM, a beat, KILL). The new
    // scene must not start while old windows are still dying, or "already
    // open" matches a corpse and that item never actually opens.
    Timer {
        id: sceneChange

        interval: 3200
        onTriggered: {
            Desk.refresh();
            root.launchAll(false, true);
        }
    }

    // When the wallpaper changes, ONLY workspace 1 is rebuilt: every window
    // on it closes — scene window or not — and the new scene opens there.
    // Windows that belonged to the OLD scene are also cleared wherever else
    // they sit, so nothing of the previous desk survives. Everything is
    // ended through its process tree (SIGTERM first), never through a
    // polite close request: a terminal with a running child answers a close
    // request with a "python3 is still running, really quit?" dialog, and a
    // desk that is being cleared deliberately must not stop to ask.
    function closeDesktopFor(key: string): void {
        if (!key)
            return;
        const list = root.sceneFor(key);
        const wins = Desk.windows;
        for (let i = 0; i < wins.length; i++) {
            const w = wins[i];
            if (w.ws === 1) {
                Desk.killTree(w.address);
                continue;
            }
            for (let j = 0; j < list.length; j++) {
                if (root.matches(list[j], w)) {
                    Desk.killTree(w.address);
                    break;
                }
            }
        }
    }

    // What a saved key means in practice: its own list, or the one that
    // applies everywhere when it has none of its own. The close pass must
    // use this too — the old desk's windows existed even when the old
    // wallpaper only borrowed the EVERYWHERE scene, and an empty own-scene
    // must not turn "close the old desk" into "close nothing".
    function sceneFor(key: string): var {
        const own = Array.isArray(root.store[key]) ? root.store[key] : [];
        return own.length > 0 ? own : root.fallback;
    }

    Timer {
        id: settle

        property var list: []

        interval: 700
        onTriggered: root.assembleFrom(settle.list)
    }

    function assembleFrom(items: var): void {
        if (root.rehome) {
            root.rehome = false;
            root.rehomeExisting();
        }
        const list = [];
        let mute = 0;
        for (let i = 0; i < items.length; i++) {
            const it = items[i];
            // Widgets live on the wallpaper — nothing to start, nothing to warn.
            if (it && it.kind === "widget")
                continue;
            if (!root.commandFor(it)) {
                mute++;               // no command: say so once, not per item
                continue;
            }
            if (root.queueForce || !root.isRunning(it))
                list.push(it);
        }

        if (mute > 0)
            if (!root.quiet)
                Toast.warn(`${mute} ITEM${mute === 1 ? " HAS" : "S HAVE"} NO COMMAND TO RUN`);

        if (list.length === 0) {
            if (mute === 0 && !root.quiet)
                Toast.show("EVERYTHING ON THIS DESKTOP IS ALREADY OPEN", "info", 2600);
            root.quiet = false;
            root.restrictWs = false;
            return;
        }

        root.queue = list;
        if (!root.quiet)
            Toast.ok(`OPENING ${list.length} ITEM${list.length === 1 ? "" : "S"}`);
        root.quiet = false;
        starter.restart();
    }

    Timer {
        id: starter

        interval: 900
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (root.queue.length === 0) {
                starter.stop();
                root.restrictWs = false;
                return;
            }
            const next = root.queue[0];
            root.queue = root.queue.slice(1);
            root.launchItem(next, root.queueForce);
        }
    }

    // ─────────────────────────────────────────────────────────── placing them
    Timer {
        interval: 420
        repeat: true
        running: root.pending.length > 0

        onTriggered: root.chase()
    }

    function chase(): void {
        // Ask for fresh windows ourselves rather than making Desk watch us:
        // two singletons that each read the other are a construction order
        // waiting to go wrong.
        Desk.refresh();

        const now = Date.now();
        const taken = root.claimed();
        const keep = [];

        let looking = 0;
        for (let i = 0; i < root.pending.length; i++)
            if (root.pending[i].phase === "find")
                looking++;

        for (let i = 0; i < root.pending.length; i++) {
            const p = root.pending[i];

            if (now - p.t > 16000)
                continue;            // it never came. Let it go.

            if (p.phase === "find") {
                if (now - p.t < 700) {
                    keep.push(p);
                    continue;
                }
                const hit = root.freshWindow(p, taken, looking === 1);
                if (!hit) {
                    keep.push(p);
                    continue;
                }
                taken[hit.address] = true;
                root.place(p.item, hit);
                keep.push({
                    item: p.item,
                    seen: p.seen,
                    t: now,
                    phase: "verify",
                    addr: hit.address,
                    polls: Desk.polls
                });
                continue;
            }

            // verify: did the geometry actually land? Only worth asking once a
            // poll has happened SINCE the placement — measuring against older
            // numbers and then nudging by the difference is how a window ends
            // up twice the size it was asked for.
            if (now - p.t < 800 || Desk.polls <= p.polls) {
                keep.push(p);
                continue;
            }
            root.correct(p.item, p.addr);
        }

        root.pending = keep;
    }

    //  `alone` is true when this is the only entry still looking. Only then is
    //  "the first window that was not there before" a safe guess; with two in
    //  flight it is a coin toss, and a wrong guess moves somebody else's
    //  window to somebody else's place.
    function freshWindow(p: var, taken: var, alone: bool): var {
        let loose = null;
        for (let i = 0; i < Desk.windows.length; i++) {
            const w = Desk.windows[i];
            if (p.seen[w.address] || taken[w.address])
                continue;
            if (root.matches(p.item, w))
                return w;
            if (!loose)
                loose = w;
        }
        return alone ? loose : null;
    }

    function place(item: var, win: var): void {
        root.applyProps(item, win);
        const g = root.pixelsFor(item);
        // Under a Lua config the launch carried no rules, so the workspace is
        // settled here, after the window exists.
        const every = root.everyOf(item);
        const wantWs = root.restrictWs ? 1 : (item.ws ?? 0);
        if (!every && wantWs > 0 && win.ws !== wantWs)
            Desk.sendToWorkspace(win.address, wantWs);
        if (item.float === false || !g)
            return;
        if (!win.floating)
            Desk.setFloating(win.address);
        Hypr.resizeExact(win.address, g.w, g.h);
        Desk.placeAt(win.address, g.x, g.y);
        if (every && win.pinned !== true)
            Hypr.setPinned(win.address, true);
    }

    // The measured second opinion. `resize` is one dispatch name with two
    // possible meanings across dialects; this reads back what actually
    // happened and nudges the difference away rather than trusting either.
    function correct(item: var, address: string): void {
        const g = root.pixelsFor(item);
        const w = Desk.byAddress(address);
        if (!g || !w || item.float === false)
            return;

        const dw = g.w - w.w;
        const dh = g.h - w.h;
        if (Math.abs(dw) > 8 || Math.abs(dh) > 8)
            Hypr.resizeBy(address, dw, dh);

        if (Math.abs(g.x - w.x) > 4 || Math.abs(g.y - w.y) > 4)
            Desk.placeAt(address, g.x, g.y);
    }


    // ════════════════════════════════════════════════════════════════ autostart
    //  On login, once: bring up whatever belongs with the wallpaper that is
    //  already on. Anything already running is left alone, so restarting the
    //  shell does not give you four clocks.
    property bool booted: false

    Timer {
        interval: 2600
        running: !root.booted && root.loaded && Config.loaded
        onTriggered: {
            root.booted = true;
            if (!Config.scene.autostart || root.items.length === 0)
                return;
            Desk.refresh();
            bootRun.restart();
        }
    }

    Timer {
        id: bootRun

        interval: 900
        onTriggered: {
            root.queueForce = false;
            root.assembleFrom(root.items);
        }
    }

    // ═════════════════════════════════════════════════════════════════════ disk
    function persist(): void {
        file.setText(JSON.stringify(root.store, null, 1));
    }

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
            root.rebase();
            root.loaded = true;
        }

        onLoadFailed: {
            root.store = ({});
            root.loaded = true;
        }
    }

    // Ids are only used to tell one row from another, but a fresh counter
    // after a restart would hand a new item the id of an old one.
    function rebase(): void {
        let top = 0;
        try {
            for (const k in root.store) {
                const list = root.store[k];
                if (!Array.isArray(list))
                    continue;
                for (let i = 0; i < list.length; i++) {
                    const row = list[i];
                    if (!row)
                        continue;
                    const n = parseInt(String(row.id ?? "").replace(/^i/, ""), 10);
                    if (n > top)
                        top = n;
                }
            }
        } catch (e) {
            // A hand-edited scenes.json must never be able to stop the shell
            // finishing its load — which is exactly what an uncaught throw in
            // onLoaded would do, leaving `loaded` false and the login
            // autostart waiting for a flag that never arrives.
            top = 0;
        }

        // Terminal programs (kind "tui") used to keep their catalogue id in
        // `id` — the entry's OWN id — so two CAVAs on one desk were the same
        // entry: one opened, the other counted as running, a restart hit
        // both. They move to `tui`, and every entry gets an id of its own.
        let migrated = false;
        try {
            for (const k in root.store) {
                const list = root.store[k];
                if (!Array.isArray(list))
                    continue;
                const seen = ({});
                for (let i = 0; i < list.length; i++) {
                    const row = list[i];
                    if (!row)
                        continue;
                    if (row.kind === "tui" && !row.tui) {
                        row.tui = row.id;
                        row.id = `i${++top}`;
                        migrated = true;
                    } else if (!row.id || seen[row.id]) {
                        row.id = `i${++top}`;
                        migrated = true;
                    }
                    seen[row.id] = true;
                }
            }
        } catch (e) {
            migrated = false;
        }
        root.nextId = top + 1;
        if (migrated) {
            root.store = Object.assign({}, root.store);
            root.persist();
        }
    }

    // ══════════════════════════════════════════════════════════════════════ ipc
    //   qs -c velvet ipc call scene start
    IpcHandler {
        target: "scene"

        function start(): void {
            root.launchAll(false);
        }
        function restart(): void {
            root.launchAll(true);
        }
        function capture(): void {
            root.captureOpen();
        }
        function list(): string {
            const out = [];
            for (let i = 0; i < root.items.length; i++)
                out.push(root.labelFor(root.items[i]));
            return out.join(", ") || "empty";
        }
    }

    GlobalShortcut {
        name: "scene"
        description: "Open whatever belongs on this desktop and is not already running"
        onPressed: root.launchAll(false)
    }
}
