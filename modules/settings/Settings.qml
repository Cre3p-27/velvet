//  VELVET  ·  modules/settings/Settings.qml
//  Super+Tab. The whole point of the shell: HOME is the title screen you
//  land on (name, face, launch tiles), SETTINGS is every knob in one
//  place, and both are driven entirely from the keyboard or entirely from
//  the mouse, either works.
//
//  Since v8.40 it is a real WINDOW, not an overlay: move it, resize it, tile
//  it, leave it open next to what you are doing — nothing else closes it,
//  only its own close button, Escape on HOME or Super+Tab. It remembers its
//  size (home.winW / winH).
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import Quickshell
import Quickshell.Wayland
import QtQuick
import Qt5Compat.GraphicalEffects as GE

FloatingWindow {
    id: root

    // ------------------------------------------------------------------ state
    //
    //  Plain Super+Tab lands on HOME — the title screen. Picking SETTINGS
    //  shows the categories, lined up down the right edge. Choosing one —
    //  click, → or Enter — glides the rail to the left and unfolds that
    //  category's settings on the right. Escape walks the same road
    //  backwards: out of the pages, out of the category, back to the bare
    //  categories, back to HOME, then out of the window.
    property bool rendered: false
    property bool entered: false

    property int column: 1                 // 0 = category rail, 1 = settings
    property int tabIndex: Panels.settingsTab
    property int itemIndex: 0
    property bool searching: false
    // True on the front page (categories only), false once a category is
    // open and the settings list is out.
    property bool home: true
    // When the window last opened. The rail opens a tab on hover — but a
    // window appearing under a resting pointer is not a hover, and it used
    // to throw a deep link (right-click a desktop widget → DESKTOP) onto
    // whichever tab happened to land under the pointer.
    property real openedAt: 0

    // The four rooms at the top of the window. HOME is the title screen
    // Super+Tab lands on — your name, your face, the launch tiles.
    // SETTINGS is the classic menu; WORKFLOW is the task list; QUICK
    // SETTINGS is the everything-switch view. A deep link can name any
    // room; plain Super+Tab always comes home.
    property int zone: 0
    // The room flip: while a room change is in flight the old room dims and
    // a portrait card turns across the screen carrying the target's name.
    property bool flipping: false
    property int flipTarget: -1
    readonly property var zones: [
        {
            name: "HOME",
            icon: "home",
            sub: "YOUR DESKTOP'S TITLE SCREEN"
        },
        {
            name: "SETTINGS",
            icon: "tune",
            sub: "EVERY KNOB IN THE SHELL"
        },
        {
            name: "WORKFLOW",
            icon: "checklist",
            sub: "TASKS · FOCUS · MAP"
        },
        {
            name: "QUICK SETTINGS",
            icon: "bolt",
            sub: "BLUETOOTH · WI-FI · POWER"
        }
    ]

    function setZone(i: int): void {
        const next = Math.max(0, Math.min(root.zones.length - 1, i));
        if (next === root.zone && !flipAnim.running)
            return;
        if (!root.rendered) {
            // Cold open — deep links arrive before the window is up; no
            // flip, the window's own entrance is the show.
            root.zone = next;
            listFocus.restart();
            Sfx.cursor();
            return;
        }
        if (flipAnim.running) {
            // Retarget: before the card has turned the room, it lands on the
            // latest ask; after, a fresh turn starts for it.
            if (root.flipping) {
                root.flipTarget = next;
                return;
            }
            flipAnim.stop();
            flipCard.spin = 0;
            flipCard.opacity = 0;
            if (next === root.zone)
                return;
        }
        root.flipTarget = next;
        root.flipping = true;
        Sfx.open();
        flipAnim.restart();
    }

    // The sub-tab you are in. A page (MODULES → TASKBAR, LOCK SCREEN →
    // CLOCK & SOUND …) is not unfolded in place any more: it OPENS, as a
    // sub-tab of its own, and the list shows only what is inside it. Each
    // step remembers the row the cursor stood on, so BACK lands right there.
    property var trail: []          // [{ name, back }]
    readonly property var trailNames: root.trail.map(t => t.name)

    readonly property var tab: Schema.tabs[Math.max(0, Math.min(Schema.tabs.length - 1, tabIndex))]

    // Another category starts at its top level.
    onTabIndexChanged: root.trail = []

    // The pages of the trail, resolved against the schema (a stale name —
    // a page renamed under you — simply stops the walk there).
    readonly property var pageStack: {
        const out = [];
        let items = root.tab?.items ?? [];
        for (let i = 0; i < root.trailNames.length; i++) {
            const hit = items.find(it => it.kind === "page" && it.name === root.trailNames[i]);
            if (!hit)
                break;
            out.push(hit);
            items = hit.items ?? [];
        }
        return out;
    }
    readonly property var page: root.pageStack.length > 0 ? root.pageStack[root.pageStack.length - 1] : null
    readonly property var levelItems: root.page ? (root.page.items ?? []) : (root.tab?.items ?? [])
    readonly property var levelTrail: [root.tab?.name ?? ""].concat(root.trailNames.slice(0, root.pageStack.length))
    // Which way the last step went, for the slide: 1 in, -1 back out.
    property int pageDir: 1

    // The row whose fold is open — a slider showing its slider, a choice
    // laying out its options. One at a time, by its path, so it survives
    // the list rebuilding; a new level closes it.
    property string openPath: ""
    readonly property int openIndex: root.openPath === "" ? -1 : root.rows.findIndex(r => r.path === root.openPath)
    onLevelTrailChanged: root.openPath = ""

    // A dangerous action (RESTART, SHUT DOWN, FORGET EVERY LOOK …) asks
    // once more: the first click arms it for a few seconds, the second runs
    // it. A stray click can no longer shut the machine down.
    property string armedPath: ""
    readonly property int armedIndex: root.armedPath === "" ? -1 : root.rows.findIndex(r => r.path === root.armedPath)
    onRowsChanged: root.armedPath = ""

    Timer {
        id: disarm

        interval: 3500
        onTriggered: root.armedPath = ""
    }

    // Where the cursor lands inside a page: its first row you can use —
    // not the explanation at its top.
    function firstUsable(): int {
        const i = root.rows.findIndex(r => (r.item.kind ?? "info") !== "info");
        return Math.max(0, i);
    }

    function toggleFold(): void {
        const r = root.currentRow;
        if (!r)
            return;
        root.openPath = root.openPath === r.path ? "" : r.path;
        Sfx.select();
    }

    function openFold(): void {
        if (root.currentRow)
            root.openPath = root.currentRow.path;
    }

    // One step back, whatever "back" means here: a fold closes, an editor
    // or a page steps out, a category goes back to the front page. The
    // Escape key, Backspace and the mouse's back button all walk it.
    function stepBack(): bool {
        if (root.openPath !== "") {
            root.openPath = "";
            Sfx.back();
            return true;
        }
        if (root.leavePage())
            return true;
        if (!root.home) {
            root.goHome();
            return true;
        }
        return false;
    }

    // Some tabs are an editor rather than a list. When one is up, the settings
    // list and everything that drives it stands down.
    // A tab can be a whole editor (`pane` on the tab), and so can a page
    // inside a tab — ARRANGE MODULES is one such page inside MODULES →
    // TASKBAR. An open page with a pane wins over the tab's own.
    readonly property var openPaneRow: root.page && root.page.pane ? {
        item: root.page,
        path: root.levelTrail.join(" › ")
    } : null
    readonly property string pane: root.home ? "" : ((root.openPaneRow?.item?.pane ?? "") || (root.tab?.pane ?? ""))
    readonly property bool isPane: root.pane !== ""

    function pathOf(trail: var, name: string): string {
        return trail.concat([name]).join(" › ");
    }

    // Into a page: it becomes the sub-tab, the list shows what is inside.
    function enterPage(item: var): void {
        if (!item || item.kind !== "page")
            return;
        root.pageDir = 1;
        root.trail = root.trail.concat([{
                name: item.name,
                back: root.itemIndex
            }]);
        root.itemIndex = root.firstUsable();
        root.column = 1;
        Sfx.select();
    }

    // One step back out — onto the row of the page you came from.
    function leavePage(): bool {
        if (root.trail.length === 0)
            return false;
        const last = root.trail[root.trail.length - 1];
        root.pageDir = -1;
        root.trail = root.trail.slice(0, -1);
        root.itemIndex = last.back;
        Sfx.back();
        return true;
    }

    // Straight up to a level of the breadcrumb (0 = the category itself).
    function leaveTo(level: int): void {
        if (level >= root.trail.length)
            return;
        const back = root.trail[Math.max(0, level)].back;
        root.pageDir = -1;
        root.trail = root.trail.slice(0, Math.max(0, level));
        root.itemIndex = back;
        root.column = 1;
        Sfx.back();
    }

    // The visible list: the rows of the level you are on — the category, or
    // the page you opened. Pages inside it are rows you can open in turn.
    readonly property var rows: {
        const out = [];
        const items = root.levelItems;
        const trail = root.levelTrail;
        for (let i = 0; i < items.length; i++) {
            const it = items[i];
            if (!Schema.shown(it))
                continue;
            out.push({
                item: it,
                depth: 0,
                path: root.pathOf(trail, it.name ?? ""),
                open: false,
                count: it.kind === "page" ? root.countOf(it.items ?? []) : 0
            });
        }
        return out;
    }

    function countOf(items: var): int {
        let n = 0;
        for (let i = 0; i < items.length; i++) {
            if (!Schema.shown(items[i]))
                continue;
            if (items[i].kind === "page")
                n += root.countOf(items[i].items ?? []);
            else if (items[i].kind !== "info")
                n++;
        }
        return n;
    }

    // Finds a page by its visible name, anywhere in the schema — needed now
    // that a page (ARRANGE MODULES) answers for what used to be a whole tab.
    function findPage(items: var, trail: var, name: string): var {
        for (let i = 0; i < items.length; i++) {
            const it = items[i];
            if (it.kind !== "page")
                continue;
            if (it.name === name)
                return { item: it, trail: trail };
            const deep = root.findPage(it.items ?? [], trail.concat([it.name]), name);
            if (deep)
                return deep;
        }
        return null;
    }

    readonly property var currentRow: root.rows[Math.max(0, Math.min(root.rows.length - 1, root.itemIndex))] ?? null
    readonly property var current: root.currentRow?.item ?? null

    readonly property bool inCarousel: current?.kind === "carousel" && carouselOpen
    property bool carouselOpen: false
    property bool helpOpen: false
    property bool facePickerOpen: false
    // The face photo gets a cache-busting stamp each time the picker
    // applies one, so the title screen's avatar swaps instantly.
    property int faceStamp: 0
    readonly property bool overlayOpen: carouselOpen || helpOpen || facePickerOpen

    // A window has the bar outside it: nothing to keep clear inside.
    readonly property real insetL: 0
    readonly property real insetR: 0
    readonly property real insetT: 0
    readonly property real insetB: 0
    readonly property real fieldW: width - insetL - insetR
    readonly property real fieldH: height - insetT - insetB

    // The whole menu is one grid: a header band, then two columns to the
    // bottom. Every pane below reads these rather than inventing its own
    // percentages, which is what used to leave a third of the screen empty.
    //
    // Every skin has its own grid: the terminal keeps a slim status line and
    // a text tree, the arcade a banner over a row of level tiles, the
    // newspaper a masthead over a column. `sg` holds the numbers.
    readonly property string skin: Appearance.skin
    readonly property bool skinned: Appearance.skinned
    readonly property var skinGrid: ({
            console: { head: 44, rail: "left", railW: 230, railH: 0, foot: 36, pad: 24, gap: 20, max: 0 },
            arcade: { head: 74, rail: "top", railW: 0, railH: 86, foot: 40, pad: 36, gap: 0, max: 1180 },
            hud: { head: 66, rail: "left", railW: 240, railH: 0, foot: 40, pad: 30, gap: 26, max: 0 },
            ledger: { head: 132, rail: "top", railW: 0, railH: 44, foot: 38, pad: 44, gap: 0, max: 1100 },
            glass: { head: 84, rail: "left", railW: 300, railH: 0, foot: 40, pad: 30, gap: 24, max: 0 },
            tome: { head: 80, rail: "left", railW: 290, railH: 0, foot: 40, pad: 36, gap: 0, max: 0 },
            poster: { head: 84, rail: "left", railW: 300, railH: 0, foot: 40, pad: 28, gap: 22, max: 0 },
            clean: root.cleanGrids[Appearance.flavour] ?? root.cleanGrids.clean,
            win: root.winGrids[Appearance.winVer] ?? root.winGrids["11"]
        })
    // The WINDOWS look is a window in the middle of the screen; each edition
    // has its own title bar, tabs and status line, so its own numbers.
    readonly property var winGrids: ({
            "95": { head: 58, rail: "left", railW: 214, railH: 0, foot: 30, pad: 12, gap: 6, max: 0, modal: true, winW: 1480, winH: 940, edge: 44 },
            "xp": { head: 78, rail: "left", railW: 236, railH: 0, foot: 32, pad: 12, gap: 8, max: 0, modal: true, winW: 1480, winH: 940, edge: 44 },
            "7": { head: 100, rail: "left", railW: 232, railH: 0, foot: 36, pad: 16, gap: 0, max: 0, modal: true, winW: 1480, winH: 940, edge: 44 },
            "10": { head: 80, rail: "left", railW: 280, railH: 0, foot: 30, pad: 0, gap: 24, max: 0, modal: true, winW: 1480, winH: 940, edge: 44 },
            "11": { head: 52, rail: "left", railW: 288, railH: 0, foot: 36, pad: 14, gap: 6, max: 0, modal: true, winW: 1480, winH: 940, edge: 44 }
        })
    // The five quiet looks share one skin but not one shape: CLEAN is a
    // window, MINIMAL a whole open page with no window at all, FLAT a
    // full-height app, NEUMORPH and CLAY smaller soft slabs.
    readonly property var cleanGrids: ({
            clean: { head: 60, rail: "left", railW: 224, railH: 0, foot: 40, pad: 16, gap: 24, max: 820, modal: true, winW: 1480, winH: 940, edge: 56 },
            minimal: { head: 84, rail: "left", railW: 210, railH: 0, foot: 40, pad: 48, gap: 64, max: 760, modal: true, winW: 99999, winH: 99999, edge: 0 },
            flat: { head: 64, rail: "left", railW: 268, railH: 0, foot: 40, pad: 12, gap: 32, max: 860, modal: true, winW: 1600, winH: 99999, edge: 0 },
            neu: { head: 72, rail: "left", railW: 240, railH: 0, foot: 44, pad: 26, gap: 30, max: 780, modal: true, winW: 1360, winH: 880, edge: 72 },
            clay: { head: 74, rail: "left", railW: 250, railH: 0, foot: 44, pad: 28, gap: 30, max: 800, modal: true, winW: 1300, winH: 900, edge: 64 }
        })
    readonly property var sg: root.skinGrid[root.skin] ?? null

    readonly property real pad: root.sg ? root.sg.pad : Math.round(46 * Appearance.densityScale)
    readonly property real headH: root.sg ? root.sg.head : Math.round(112 * Appearance.densityScale)
    readonly property real footH: root.sg ? root.sg.foot : 0
    readonly property bool railTop: root.sg ? root.sg.rail === "top" : false
    readonly property real railStripH: root.sg ? root.sg.railH : 0
    // The modal looks (CLEAN, WINDOWS) are a window in the middle of the
    // screen, not the whole field; every other skin fills the field. All the
    // geometry below is relative to this frame.
    readonly property bool modal: root.sg ? root.sg.modal === true : false
    // The modal looks drew a window in the middle of the screen; in a real
    // window their sheet simply is the window.
    readonly property real frameW: root.fieldW
    readonly property real frameH: root.fieldH
    readonly property real frameX: root.insetL + (root.fieldW - root.frameW) / 2
    readonly property real frameY: root.insetT + (root.fieldH - root.frameH) / 2

    readonly property real railW: root.sg ? root.sg.railW : Math.max(260, Math.min(400, root.fieldW * 0.2))
    // On the front page the rail is wider and lives on the RIGHT edge; once
    // a category is open it takes its classic spot on the left. One property
    // per question, so the tween writes itself. (The other skins keep the
    // rail where it is.)
    readonly property real railWHome: root.sg ? root.railW : Math.max(320, Math.min(580, root.fieldW * 0.3))
    // The front page is one composition: the hero's left edge sits insetL +
    // pad from the left, so the rail mirrors it — the same distance from the
    // right edge. Reading the two columns against their edges is what makes
    // the page feel symmetric.
    readonly property real railGapHome: root.insetL + root.pad
    readonly property real railX: root.sg ? root.frameX + root.pad : (root.home
        ? root.insetL + root.fieldW - root.railWHome - root.railGapHome
        : root.insetL + root.pad)
    // Room for the front page's big word, left of the right-aligned rail.
    readonly property real heroW: Math.max(200, root.fieldW - root.railWHome - root.railGapHome - root.pad)
    // The rooms (home, workflow, quick) start right under the header; the
    // settings list also clears a top rail strip.
    readonly property real roomY: root.frameY + root.headH + (root.sg ? (root.modal ? 0 : 8) : root.pad * 0.4)
    readonly property real roomH: root.frameH - root.headH - (root.sg ? (root.modal ? 0 : 8) + root.footH : root.pad * 1.6)
    readonly property real bodyY: root.roomY + (root.railTop ? root.railStripH + 10 : 0)
    readonly property real bodyH: root.roomH - (root.railTop ? root.railStripH + 10 : 0)
    readonly property real listW: {
        if (!root.sg)
            return root.fieldW - root.pad * 3 - root.railW;
        if (root.railTop)
            return Math.min(root.sg.max, root.frameW - root.pad * 2);
        const room = root.frameW - root.pad * 2 - root.railW - root.sg.gap;
        return root.sg.max > 0 ? Math.min(root.sg.max, room) : room;
    }
    readonly property real listX: {
        if (!root.sg)
            return root.insetL + root.pad + root.railW + root.pad;
        if (root.railTop)
            return root.frameX + (root.frameW - root.listW) / 2;
        const room = root.frameW - root.pad * 2 - root.railW - root.sg.gap;
        return root.frameX + root.pad + root.railW + root.sg.gap + (room - root.listW) / 2;
    }
    // LOCK SCREEN wears a live picture of the lock beside its list: the
    // real face, drawn at this screen's size and scaled into the panel, so
    // every pick shows exactly as the lock will. The FLUID and SOFT faces only —
    // the original velvet look has no preview mode.
    readonly property bool lockPreview: root.zone === 1 && !root.home && !root.isPane && !root.overlayOpen && !root.searching && (Schema.tabs[root.tabIndex]?.name ?? "") === "LOCK SCREEN" && ["fluid", "soft", "vibe"].indexOf(Config.lock.look) >= 0
    // The picture gets two fifths: the list beside it has to stay readable.
    readonly property real previewW: Math.round(Math.min(root.listW * 0.4, 900))

    readonly property string breadcrumb: root.zone === 0 ? "HOME" : root.zone === 1 ? (root.home ? "SETTINGS" : (root.currentRow ? root.currentRow.path : (root.tab?.name ?? ""))) : root.zones[root.zone].name

    // The keys the footer teaches, for whichever room or editor is up.
    readonly property var hintList: root.zone === 0 ? [
                {
                    k: "↑ ↓",
                    v: "MOVE"
                },
                {
                    k: "ENTER",
                    v: "FIRE"
                },
                {
                    k: "1–6",
                    v: "FIRE DIRECT"
                },
                {
                    k: "E",
                    v: "RENAME YOU"
                },
                {
                    k: "A",
                    v: "NEW PHOTO"
                },
                {
                    k: "C",
                    v: "ACCENT"
                },
                {
                    k: "CTRL+TAB",
                    v: "NEXT ROOM"
                },
                {
                    k: "ESC",
                    v: "CLOSE"
                }
            ] : root.zone === 2 ? [
                {
                    k: "↑ ↓",
                    v: "MOVE"
                },
                {
                    k: "ENTER",
                    v: "TOGGLE"
                },
                {
                    k: "N",
                    v: "NEW TASK"
                },
                {
                    k: "DEL",
                    v: "REMOVE"
                },
                {
                    k: "P",
                    v: "PIN"
                },
                {
                    k: "F",
                    v: "FOCUS TIMER"
                },
                {
                    k: "CTRL+TAB",
                    v: "NEXT ROOM"
                },
                {
                    k: "ESC",
                    v: "BACK TO HOME"
                }
            ] : root.zone === 3 ? [
                {
                    k: "← →",
                    v: "SWITCH PANEL"
                },
                {
                    k: "↑ ↓",
                    v: "MOVE"
                },
                {
                    k: "ENTER",
                    v: "SELECT"
                },
                {
                    k: "CTRL+TAB",
                    v: "NEXT ROOM"
                },
                {
                    k: "ESC",
                    v: "BACK TO HOME"
                }
            ] : root.home ? [
                {
                    k: "↑ ↓",
                    v: "CHOOSE A CATEGORY"
                },
                {
                    k: "→",
                    v: "OPEN"
                },
                {
                    k: "TAB",
                    v: "NEXT"
                },
                {
                    k: "/",
                    v: "SEARCH"
                },
                {
                    k: "F1",
                    v: "ALL KEYS"
                },
                {
                    k: "ESC",
                    v: "CLOSE"
                }
            ] : root.pane === "softlock" ? [
                {
                    k: "DRAG",
                    v: "MOVE ANYTHING"
                },
                {
                    k: "CLICK",
                    v: "PICK IT"
                },
                {
                    k: "← → ↑ ↓",
                    v: "NUDGE · SHIFT MORE"
                },
                {
                    k: "ALT",
                    v: "NO SNAPPING"
                },
                {
                    k: "ESC",
                    v: "CLOSE"
                }
            ] : root.pane === "wallpaper" ? [
                {
                    k: "CLICK",
                    v: "SWITCH · SAVE · USE"
                },
                {
                    k: "SCROLL",
                    v: "MORE WALLPAPERS"
                },
                {
                    k: "ESC",
                    v: "CLOSE"
                }
            ] : root.pane === "credits" ? [
                {
                    k: "SCROLL",
                    v: "MORE"
                },
                {
                    k: "TAB",
                    v: "NEXT"
                },
                {
                    k: "ESC",
                    v: "CLOSE"
                }
            ] : root.pane === "looks" ? [
                {
                    k: "← →",
                    v: "PICK A LOOK"
                },
                {
                    k: "ENTER",
                    v: "PUT IT ON"
                },
                {
                    k: "BACKSPACE",
                    v: "BACK TO YOURS"
                },
                {
                    k: "ESC",
                    v: "CLOSE"
                }
            ] : root.isPane ? [
                {
                    k: "DRAG",
                    v: "REORDER"
                },
                {
                    k: "CLICK",
                    v: "ITS SETTINGS"
                },
                {
                    k: "SHIFT ← →",
                    v: "MOVE"
                },
                {
                    k: "DEL",
                    v: "REMOVE"
                },
                {
                    k: "ESC",
                    v: "CLOSE"
                }
            ] : root.carouselOpen ? [
                {
                    k: "← →",
                    v: "BROWSE"
                },
                {
                    k: "ENTER",
                    v: "APPLY"
                },
                {
                    k: "F",
                    v: "FAVOURITE"
                },
                {
                    k: "ESC",
                    v: "BACK"
                }
            ] : [
                {
                    k: "↑ ↓",
                    v: "MOVE"
                },
                {
                    k: "← →",
                    v: "ADJUST · OPEN A PAGE"
                },
                {
                    k: "ENTER",
                    v: "OPEN · UNFOLD"
                },
                {
                    k: "TAB",
                    v: "NEXT TAB"
                },
                {
                    k: "/",
                    v: "SEARCH"
                },
                {
                    k: "F1",
                    v: "ALL KEYS"
                },
                {
                    k: "ESC",
                    v: "BACK"
                }
            ]

    // ------------------------------------------------------------- navigation
    function openTab(i: int): void {
        const next = Math.max(0, Math.min(Schema.tabs.length - 1, i));
        if (next === root.tabIndex)
            return;
        root.tabIndex = next;
        Panels.settingsTab = root.tabIndex;
        root.itemIndex = 0;
        Sfx.cursor();
    }

    function refocus(): void {
        listFocus.restart();
    }

    // The front page → inside. The category is picked, the rail glides to
    // the left and the category's settings unfold on the right where they
    // always lived.
    function enterTab(i: int): void {
        const next = Math.max(0, Math.min(Schema.tabs.length - 1, i));
        if (root.home) {
            if (next !== root.tabIndex) {
                root.tabIndex = next;
                Panels.settingsTab = next;
                root.itemIndex = 0;
            }
            root.home = false;
            Sfx.open();
        } else if (next === root.tabIndex) {
            // The category you are already in: back to its top level.
            if (root.trail.length > 0)
                root.leaveTo(0);
            else
                Sfx.select();
        } else {
            root.openTab(next);
        }
        root.column = 1;
        root.refocus();
    }

    // Inside → the front page. Every open page closes, the list slides away
    // and the rail glides back to the right edge, alone again.
    function goHome(): void {
        if (root.home)
            return;
        root.trail = [];
        root.home = true;
        root.column = 0;
        Sfx.back();
        root.refocus();
    }

    // Backspace / Escape: close the page the cursor is inside, and put the
    // cursor on that page's own row so the next Escape closes its parent.
    // The header's BACK: one level up.
    function collapseAll(): void {
        root.leavePage();
    }

    // Backspace / Escape / ←: out of the sub-tab you are in.
    function collapseHere(): bool {
        return root.leavePage();
    }

    function moveItem(delta: int): void {
        const n = root.rows.length;
        if (n === 0)
            return;
        // Walking on closes an open fold and disarms a dangerous action.
        root.openPath = "";
        root.armedPath = "";
        // Single steps wrap; paging clamps, so PgDn at the bottom stays put
        // instead of flinging you back to the top.
        if (Math.abs(delta) === 1)
            root.itemIndex = (root.itemIndex + delta + n) % n;
        else
            root.itemIndex = Math.max(0, Math.min(n - 1, root.itemIndex + delta));
        Sfx.cursor();
    }

    function activate(): void {
        const it = root.current;
        if (!it)
            return;

        switch (it.kind) {
        case "page":
            root.enterPage(it);
            break;
        case "toggle":
            Bridge.set(it, !Bridge.get(it));
            Sfx.toggle();
            break;
        case "action":
            if (it.danger && root.armedPath !== (root.currentRow?.path ?? "")) {
                root.armedPath = root.currentRow?.path ?? "";
                disarm.restart();
                Sfx.toggle();
                break;
            }
            root.armedPath = "";
            Bridge.act(it);
            Sfx.select();
            // A window stays open: what an action opens (launcher, wheel,
            // island) appears over it, and you close the window yourself.
            break;
        case "carousel":
            root.carouselOpen = true;
            Sfx.open();
            break;
        case "slider":
        case "choice":
            // Click or Enter: the fold opens (the slider, every option);
            // again: it closes.
            root.toggleFold();
            break;
        case "colour":
            // Enter takes the accent off the wallpaper and hands it to you;
            // ← → then move the hue, and the strip in the row is clickable.
            Config.set("appearance.accentSource", "manual");
            Toast.show("ACCENT IS YOURS NOW  ·  ← → MOVE THE HUE", "info", 3000);
            Sfx.select();
            break;
        }
    }

    function adjust(direction: int, times: int): void {
        const it = root.current;
        if (!it)
            return;

        if (it.kind === "slider") {
            // The keys move it and show it.
            root.openFold();
            Bridge.nudge(it, direction, times);
            Sfx.cursor();
        } else if (it.kind === "choice") {
            Bridge.cycleChoice(it, direction);
            Sfx.select();
        } else if (it.kind === "toggle") {
            const want = direction > 0;
            if (Bridge.get(it) !== want) {
                Bridge.set(it, want);
                Sfx.toggle();
            }
        } else if (it.kind === "page" && direction > 0) {
            // → opens the page; ← (below) steps back out of this one.
            root.enterPage(it);
        } else if (it.kind === "colour") {
            Bridge.shiftHue(it, direction, times);
            Sfx.cursor();
        } else if (direction > 0 && it.kind === "carousel") {
            root.carouselOpen = true;
            Sfx.open();
        } else if (direction < 0) {
            if (!root.collapseHere())
                root.column = 0;
        }
    }

    // Jump straight to a setting found through search.
    function navigateTo(entry: var): void {
        root.home = false;
        root.tabIndex = entry.tabIndex;
        Panels.settingsTab = entry.tabIndex;

        // Open the sub-tab the setting lives in, so the row is actually in
        // the list — and the breadcrumb says where it lives. BACK then walks
        // out through each page to its row.
        const steps = [];
        for (let i = 1; i < entry.trail.length; i++)
            steps.push({
                name: entry.trail[i],
                back: 0
            });
        // Each step's BACK should land on that page's own row.
        let items = root.tab?.items ?? [];
        for (let i = 0; i < steps.length; i++) {
            const at = items.findIndex(it => it.kind === "page" && it.name === steps[i].name);
            steps[i].back = Math.max(0, at);
            items = at >= 0 ? (items[at].items ?? []) : [];
        }
        root.pageDir = 1;
        root.trail = steps;

        const want = [Schema.tabs[entry.tabIndex].name].concat(entry.trail.slice(1)).concat([entry.item.name]).join(" › ");
        const idx = root.rows.findIndex(r => r.path === want);
        root.itemIndex = idx >= 0 ? idx : 0;
        root.column = 1;
        root.searching = false;
        Sfx.select();
        // A page found by name opens — "arrange by hand" lands in the editor.
        if (entry.item.kind === "page" && idx >= 0)
            root.enterPage(entry.item);
    }

    // ------------------------------------------------------------------ shell
    title: "Velvet Settings"
    visible: rendered
    color: Colours.paper
    implicitWidth: Config.home.winW > 0 ? Config.home.winW : Math.round((Hypr.focusedScreen?.width ?? 1920) * 0.72)
    implicitHeight: Config.home.winH > 0 ? Config.home.winH : Math.round((Hypr.focusedScreen?.height ?? 1080) * 0.8)
    minimumSize: Qt.size(980, 640)

    // the size you gave it comes back next time
    onWidthChanged: sizeSave.restart()
    onHeightChanged: sizeSave.restart()

    Timer {
        id: sizeSave

        interval: 800
        onTriggered: {
            if (!root.visible || root.width < 600 || root.height < 400)
                return;
            if (Math.abs(root.width - Config.home.winW) > 2 || Math.abs(root.height - Config.home.winH) > 2)
                Config.setMany({
                    "home.winW": Math.round(root.width),
                    "home.winH": Math.round(root.height)
                });
        }
    }

    // HOME → OPEN AS: fullscreen (the default), maximised or a free window.
    // Hyprland is asked once the window exists, and again when you change it.
    readonly property int modeWanted: ({
            fullscreen: 2,
            maximized: 1,
            window: 0
        })[Config.home.winMode] ?? 2
    property int modeTries: 0

    function applyMode(): void {
        const a = Hypr.addressOfTitle("Velvet Settings");
        if (!a) {
            if (root.modeTries++ < 20)
                modeTimer.restart();
            return;
        }
        Hypr.setFullscreenState(a, root.modeWanted);
    }
    onModeWantedChanged: if (root.visible)
        root.applyMode()
    onRenderedChanged: if (root.rendered) {
        root.modeTries = 0;
        modeTimer.restart();
    }

    Timer {
        id: modeTimer

        interval: 60
        onTriggered: root.applyMode()
    }

    // Closed by the compositor (its close key, the window's own button):
    // the flag follows, so Super+Tab opens it again rather than "closing" it.
    onVisibleChanged: {
        if (!root.visible && Panels.settings && root.rendered) {
            root.entered = false;
            root.rendered = false;
            Panels.settings = false;
        }
    }

    // Opens or closes as Panels.settings says — and also when this window is created BY
    // that flag: panels are loaded on demand (shell.qml, Parked), so the flag is
    // often already true by the time the window exists.
    function present(): void {
        if (Panels.settings) {
            // A close may have left the exit timer pending — a quick
            // reopen (deep link from inside the menu) must not let it
            // slam the window shut 300ms later.
            exitTimer.stop();
            root.openedAt = Date.now();
            root.rendered = true;
            root.searching = false;
            root.carouselOpen = false;
            root.helpOpen = false;
            // Every plain Super+Tab lands on HOME — the title screen.
            // A deep link (a named tab, a launcher hit, a named room)
            // goes where it was asked to go.
            root.trail = [];
            root.home = true;
            root.column = 0;
            // The WORKFLOW room's session counters start from this open.
            workStats.doneBase = Tasks.doneCount;
            // Which room to land on: HOME by default; a deep link may
            // name SETTINGS, WORKFLOW or QUICK SETTINGS.
            let target = 0;
            if (Panels.pendingZone === "SETTINGS")
                target = 1;
            else if (Panels.pendingZone === "WORKFLOW")
                target = 2;
            else if (Panels.pendingZone === "QUICK" || Panels.pendingZone === "QUICK SETTINGS")
                target = 3;
            Panels.pendingZone = "";
            if (root.rendered && root.zone !== target) {
                // Already open (or mid-reopen) — the room flip is the
                // show, not the window entrance.
                enterTimer.restart();
                root.setZone(target);
            } else {
                root.zone = target;
                enterTimer.restart();
                Sfx.open();
            }

            // A deep link may also ask for the face picker up front —
            // the CHOOSE YOUR PHOTO row in HOME lands here.
            if (Panels.pendingFacePicker) {
                Panels.pendingFacePicker = false;
                root.facePickerOpen = true;
            }

            // Arrived here from something that names a whole tab — or,
            // since the bar moved under MODULES, a page inside one.
            if (Panels.pendingTab) {
                // A named tab/pane always lives in the SETTINGS room,
                // whatever room the window was showing before.
                if (root.flipping) {
                    root.flipTarget = -1;
                    root.flipping = false;
                }
                root.zone = 1;
                let hit = false;
                for (let i = 0; i < Schema.tabs.length; i++) {
                    if (Schema.tabs[i].name === Panels.pendingTab) {
                        root.tabIndex = i;
                        Panels.settingsTab = i;
                        hit = true;
                        break;
                    }
                }
                if (!hit) {
                    for (let i = 0; i < Schema.tabs.length; i++) {
                        const found = root.findPage(Schema.tabs[i].items ?? [], [Schema.tabs[i].name], Panels.pendingTab);
                        if (found) {
                            root.tabIndex = i;
                            Panels.settingsTab = i;
                            // Open the named page itself as the sub-tab,
                            // every page above it on the way.
                            const names = found.trail.slice(1).concat([found.item.name]);
                            const steps = [];
                            let items = Schema.tabs[i].items ?? [];
                            for (let k = 0; k < names.length; k++) {
                                const at = items.findIndex(it => it.kind === "page" && it.name === names[k]);
                                steps.push({
                                    name: names[k],
                                    back: Math.max(0, at)
                                });
                                items = at >= 0 ? (items[at].items ?? []) : [];
                            }
                            root.pageDir = 1;
                            root.trail = steps;
                            root.itemIndex = 0;
                            break;
                        }
                    }
                }
                Panels.pendingTab = "";
                root.home = false;
                root.column = 1;
            }

            // Arrived here from the launcher — go straight to the row,
            // which also lives in the SETTINGS room.
            if (Panels.pendingSetting) {
                if (root.flipping) {
                    root.flipTarget = -1;
                    root.flipping = false;
                }
                root.zone = 1;
                jump.entry = Panels.pendingSetting;
                Panels.pendingSetting = null;
                jump.restart();
            }
        } else {
            // a window just goes (the compositor animates it)
            root.entered = false;
            root.rendered = false;
            Sfx.close();
        }
    }

    Connections {
        target: Panels

        function onSettingsChanged(): void {
            root.present();
        }

        // a deep link while the window is already open
        function onSettingsAsked(): void {
            root.present();
        }
    }

    // (a PanelWindow has no Component.onCompleted — a one-shot timer does the same)
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (Panels.settings)
                root.present();
        }
    }

    Timer {
        id: enterTimer
        interval: 1
        onTriggered: {
            root.entered = true;
            // Whichever screen is up takes the keyboard. The home screen is
            // inside a Loader, and a Loader only reports `onLoaded` once — so
            // handing focus over there has to happen on every open, not just
            // the first, or the arrow keys stop working the second time.
            if (root.zone === 1)
                keys.forceActiveFocus();
            else
                listFocus.restart();
        }
    }

    Timer {
        id: jump

        property var entry: null

        interval: 30
        onTriggered: {
            if (jump.entry)
                root.navigateTo(jump.entry);
        }
    }

    Timer {
        id: exitTimer
        interval: Appearance.anim.normal + 40
        onTriggered: root.rendered = false
    }

    // ------------------------------------------------------- the work stats
    //  The WORKFLOW room's session numbers live here, not in the pane, so
    //  they survive switching rooms — the zone Loader destroys the pane, but
    //  the Deep Work countdown must keep ticking. Fresh every time the shell
    //  process wakes; closing the menu does not reset it.
    QtObject {
        id: workStats

        property int focusTotal: 25 * 60
        property int focusLeft: 25 * 60
        property bool focusRunning: false
        property int focusSeconds: 0
        property int doneBase: Tasks.doneCount
    }

    Timer {
        id: focusKeeper

        interval: 1000
        repeat: true
        running: workStats.focusRunning
        onTriggered: {
            workStats.focusLeft--;
            workStats.focusSeconds++;
            if (workStats.focusLeft <= 0) {
                workStats.focusLeft = 0;
                workStats.focusRunning = false;
                Sfx.open();
                Toast.show("DEEP WORK DONE  ·  STAND UP, STRETCH, GO AGAIN", "ok", 5000);
            }
        }
    }

    // ================================================================ visuals
    Item {
        id: stage

        anchors.fill: parent
        opacity: root.entered ? 1 : 0
        scale: root.entered ? 1 : 1.045

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutExpo
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.entrance
                easing.type: Easing.OutExpo
            }
        }

        // ------------------------------------------------------------ ground
        Rectangle {
            anchors.fill: parent
            color: root.skin === "glass" ? Colours.alpha(Colours.paper, 0.86) : Colours.paper
        }

        // The mouse's own BACK and FORWARD buttons: back walks the same
        // one-step-back road as Escape (without ever closing the menu),
        // forward opens the row under the cursor. Everything above lets
        // these buttons fall through to here.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.BackButton | Qt.ForwardButton
            onClicked: mouse => {
                if (root.searching || root.overlayOpen)
                    return;
                if (mouse.button === Qt.BackButton) {
                    if (root.zone === 1)
                        root.stepBack();
                    else if (root.zone !== 0)
                        root.setZone(0);
                } else if (root.zone === 1 && !root.home && !root.isPane && root.current?.kind === "page") {
                    root.enterPage(root.current);
                }
            }
        }

        Image {
            anchors.fill: parent
            source: Config.wallpaper.current ? "file://" + Config.wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            // HOME leans into the wallpaper; the settings rooms stay quiet
            // so lists stay readable.
            visible: !root.modal
            opacity: root.skin === "glass" ? 0.16 : (root.zone === 0 ? 0.2 : 0.13)
            asynchronous: true
            cache: true

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.slow
                }
            }
        }

        Backdrop {
            anchors.fill: parent
            visible: Config.appearance.backdrop !== "persona" && !root.modal
        }

        Scanlines {
            anchors.fill: parent
            z: 40
        }

        SpeedLines {
            anchors.fill: parent
            visible: Config.appearance.backdrop === "persona"
            color: Colours.accent
            strength: 0.075
            originX: 0.1
            originY: 0.62
            count: 18

            NumberAnimation on spin {
                running: root.entered
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 240000
            }
        }

        Halftone {
            anchors.fill: parent
            strength: 0.05
            angle: -14
        }

        // Two hard accent bands raking across the whole screen.
        Slash {
            visible: Config.appearance.backdrop === "persona"
            width: parent.width * 1.4
            height: 5
            x: -parent.width * 0.2
            y: parent.height * 0.135
            shear: 0
            rotation: -4
            color: Colours.accent
            opacity: 0.55
        }

        Slash {
            visible: Config.appearance.backdrop === "persona"
            width: parent.width * 1.4
            height: 2
            x: -parent.width * 0.2
            y: parent.height * 0.885
            shear: 0
            rotation: -4
            color: Colours.accent
            opacity: 0.35
        }

        // Ghost type — the current tab, enormous, behind everything. It
        // steps back on the front page; the big word lives there instead.
        P5Text {
            visible: !root.skinned
            anchors.right: parent.right
            anchors.rightMargin: -parent.width * 0.02
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -parent.height * 0.06
            display: true
            text: root.zone === 0 ? "VELVET" : root.zone === 1 ? (root.tab?.name ?? "") : root.zones[root.zone].name
            color: Colours.ink
            opacity: root.zone === 1 ? (root.home ? 0 : 0.035) : 0.035
            font.pixelSize: Math.min(parent.height * 0.42, 420)
            tracking: -8
            rotation: -4
            horizontalAlignment: Text.AlignRight

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }
        }

        // The layer behind the lists: a skin's pages, panes and spine.
        Loader {
            id: skinBack

            anchors.fill: parent
            active: root.skinned && root.rendered && ["glass", "tome", "clean", "win"].indexOf(root.skin) >= 0
            sourceComponent: ({
                    glass: skinGlassBack,
                    tome: skinTomeBack,
                    clean: skinCleanBack,
                    win: skinWinBack
                })[root.skin] ?? null
        }

        Component {
            id: skinGlassBack

            SkinGlass {
                host: root
                back: true
            }
        }

        Component {
            id: skinTomeBack

            SkinTome {
                host: root
                back: true
            }
        }

        Component {
            id: skinCleanBack

            SkinClean {
                host: root
                back: true
            }
        }

        Component {
            id: skinWinBack

            SkinWin {
                host: root
                back: true
            }
        }

        // ----------------------------------------------------- front page
        // The landing state's other half: the big word on the left, holding
        // the fort while the categories line up on the right.
        Column {
            id: hero

            visible: !root.skinned
            // Explicit geometry instead of anchors: a verticalCenter anchor
            // resolved against the zero-height window at birth (the window
            // is born hidden) and never re-resolved on show, pinning the
            // hero to y=0. Plain numbers, same source of truth as the
            // rail's centring, cannot freeze.
            x: root.insetL + root.pad
            width: root.heroW
            y: root.bodyY + root.bodyH / 2 - hero.height / 2
            opacity: !root.flipping && root.home && root.zone === 1 && root.entered ? 1 : 0
            scale: root.home && root.zone === 1 ? 1 : 0.965
            spacing: 10

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }

            Row {
                spacing: 12

                Slash {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52
                    height: 26
                    shear: Appearance.skew
                    color: Colours.accent
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: "THE CONTROL ROOM"
                    color: Colours.accentInk
                    font.pixelSize: Appearance.font.size.small
                    tracking: 4
                }
            }

            P5Text {
                display: true
                text: "SETTINGS"
                color: Colours.ink
                font.pixelSize: Math.max(84, Math.min(190, root.heroW * 0.14))
                tracking: -4
                lineHeight: 0.92
            }

            P5Text {
                display: true
                text: "EVERY KNOB IN THE SHELL, ONE PLACE"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.normal
                tracking: 3
            }

            P5Text {
                text: "PICK A CATEGORY  ·  OR JUST TYPE TO SEARCH"
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.small
                tracking: 2
            }
        }

        // ------------------------------------------------------------ header
        Column {
            id: title

            visible: !root.skinned
            x: root.insetL + root.pad
            y: root.insetT + Math.round(root.pad * 0.5)
            spacing: -4

            transform: Translate {
                x: root.entered ? 0 : -160

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.entrance
                        easing.type: Easing.OutExpo
                    }
                }
            }

            Row {
                spacing: 12

                VelvetMark {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    reveal: root.entered ? 1 : 0

                    Behavior on reveal {
                        NumberAnimation {
                            duration: Appearance.anim.entrance
                            easing.type: Easing.OutExpo
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Panels.closeSettings()
                    }
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: "VELVET"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.hero * 0.62
                    tracking: -1
                }
            }

            P5Text {
                x: 20
                width: Math.max(200, root.fieldW - root.pad * 2 - 700)
                text: root.zone === 0
                    ? `${root.breadcrumb.toUpperCase()}   ·   ↑ ↓ TILE   ·   E RENAME   ·   A NEW PHOTO   ·   C ACCENT   ·   F1 KEYS`
                    : `${root.breadcrumb.toUpperCase()}   ·   TYPE TO SEARCH EVERY SETTING   ·   F1 FOR EVERY KEY`
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.small
                tracking: 3
                elide: Text.ElideRight
            }
        }

        Timer {
            id: listFocus
            interval: 16
            onTriggered: {
                if (root.zone !== 1) {
                    zoneLoader.item?.forceActiveFocus();
                    return;
                }
                if (root.isPane)
                    paneLoader.item?.forceActiveFocus();
                else
                    keys.forceActiveFocus();
            }
        }

        // ---------------------------------------------------------- the rooms
        // The four top tabs. Clicking one switches the whole window; HOME is
        // the title screen, SETTINGS is the menu, the other two unfold their
        // own rooms.
        Row {
            id: zoneTabs

            visible: !root.skinned
            anchors.right: parent.right
            anchors.rightMargin: root.insetR + root.pad
            anchors.verticalCenter: title.verticalCenter
            spacing: 10

            transform: Translate {
                x: root.entered ? 0 : 200

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.entrance
                        easing.type: Easing.OutExpo
                    }
                }
            }

            Repeater {
                model: root.zones

                Item {
                    id: ztab

                    required property var modelData
                    required property int index

                    readonly property bool sel: ztab.index === (root.flipTarget >= 0 ? root.flipTarget : root.zone)

                    width: zrow.implicitWidth + 46
                    height: 46
                    scale: ztab.sel ? 1.05 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.6
                        }
                    }

                    Slash {
                        anchors.fill: parent
                        shear: Appearance.skew
                        color: ztab.sel ? Colours.alpha(Colours.ink, 0.12) : (ztabArea.containsMouse ? Colours.alpha(Colours.ink, 0.14) : Colours.alpha(Colours.ink, 0.07))
                        borderColor: ztab.sel ? Colours.alpha(Colours.ink, 0.28) : Colours.alpha(Colours.ink, 0.2)
                        borderWidth: 1

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    Row {
                        id: zrow

                        anchors.centerIn: parent
                        spacing: 8

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: ztab.modelData.icon
                            color: Colours.accent
                            font.pixelSize: Appearance.font.size.normal
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            display: true
                            text: ztab.modelData.name
                            color: ztab.sel ? Colours.accent : Colours.ink
                            font.pixelSize: Appearance.font.size.small
                            tracking: 1.4
                        }
                    }

                    // The little accent notch under the selected room.
                    Slash {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height + 3
                        width: 20
                        height: 3
                        shear: Appearance.skew
                        color: Colours.accent
                        visible: ztab.sel
                    }

                    MouseArea {
                        id: ztabArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setZone(ztab.index)
                    }
                }
            }
        }

        // ------------------------------------------------------------- pane
        Loader {
            id: paneLoader

            visible: root.zone === 1 && root.isPane && !root.overlayOpen && !root.searching
            active: root.rendered && root.isPane && root.zone === 1
            opacity: root.flipping ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }
            x: root.listX
            y: root.bodyY
            width: root.listW
            height: root.bodyH

            sourceComponent: ({
                    layout: layoutPane,
                    desktop: desktopPane,
                    lock: lockPane,
                    looks: looksPane,
                    wallpaper: wallpaperPane,
                    softlock: softLockPane,
                    credits: creditsPane
                })[root.pane] ?? null

            onLoaded: listFocus.restart()
        }

        Component {
            id: layoutPane

            LayoutTab {
                // Unhandled keys bubble back to the settings' key brain, so
                // Escape still closes the pane ("ESC → CLOSE") and typing
                // still starts a search while an editor is up.
                Keys.forwardTo: [keys]
            }
        }

        Component {
            id: desktopPane

            DesktopTab {
                Keys.forwardTo: [keys]
            }
        }

        Component {
            id: lockPane

            LockTab {
                Keys.forwardTo: [keys]
            }
        }

        Component {
            id: looksPane

            LooksPane {
                Keys.forwardTo: [keys]
            }
        }

        Component {
            id: creditsPane

            CreditsPane {
                Keys.forwardTo: [keys]
            }
        }

        Component {
            id: wallpaperPane

            WallpaperPane {
                Keys.forwardTo: [keys]
            }
        }

        Component {
            id: softLockPane

            SoftLockTab {
                screenW: root.width
                screenH: root.height
                Keys.forwardTo: [keys]
            }
        }

        // -------------------------------------------------------------- rooms
        // WORKFLOW and QUICK SETTINGS — full-width rooms under the header.
        Loader {
            id: zoneLoader

            visible: root.zone !== 1 && !root.overlayOpen
            active: root.rendered && root.zone !== 1
            opacity: root.flipping ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }
            x: root.frameX + root.pad
            y: root.roomY
            width: root.frameW - root.pad * 2
            height: root.roomH

            sourceComponent: root.zone === 0 ? homePane : (root.zone === 2 ? workflowPane : quickPane)

            onLoaded: listFocus.restart()
        }

        Component {
            id: homePane

            HomePane {
                // ESC and F1 bubble back to the settings' key brain — ESC
                // from HOME closes the whole window.
                Keys.forwardTo: [keys]
                faceRev: root.faceStamp
                onOpenFacePicker: root.facePickerOpen = true
            }
        }

        Component {
            id: workflowPane

            WorkflowPane {
                // Unhandled keys (Escape above all) bubble back to the
                // settings' key brain.
                Keys.forwardTo: [keys]
                stats: workStats
            }
        }

        Component {
            id: quickPane

            QuickPane {
                Keys.forwardTo: [keys]
            }
        }

        // ---------------------------------------------------------- tab rail
        TabRail {
            id: rail

            visible: root.zone === 1 && !root.skinned
            enabled: root.zone === 1
            opacity: root.flipping ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }

            x: root.railX
            y: root.bodyY
            width: root.home ? root.railWHome : root.railW
            height: root.bodyH

            currentIndex: root.tabIndex
            focused: root.column === 0
            hero: root.home
            // Inside a sub-tab the category says where you are.
            trailText: root.home ? "" : root.trailNames.slice(0, root.pageStack.length).join(" › ")

            onPicked: i => root.enterTab(i)
            // Hover never opens a category: it only lights the row up (in
            // the rail itself). Passing over the rail on the way to the list
            // used to swap the whole list out from under the pointer.

            // The rail is the one piece that moves twice: right edge on the
            // front page, left edge inside a category — and the glide
            // between the two is the whole show.
            Behavior on x {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutExpo
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutExpo
                }
            }

            transform: Translate {
                x: root.entered ? 0 : (root.home ? 360 : -360)

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.entrance
                        easing.type: Easing.OutExpo
                    }
                }
            }
        }

        // -------------------------------------------------------------- list
        SettingsList {
            id: listPane

            visible: root.zone === 1 && !root.overlayOpen && !root.isPane
            // On the front page the list stands down entirely — invisible,
            // inert, parked off to the right until a category calls for it.
            enabled: !root.home
            opacity: root.home || root.flipping ? 0 : 1
            x: root.listX
            y: root.bodyY
            width: root.lockPreview ? root.listW - root.previewW - root.pad : root.listW
            height: root.bodyH

            rows: root.rows
            currentIndex: root.itemIndex
            focused: root.column === 1
            breadcrumb: root.breadcrumb
            nested: root.trail.length > 0
            crumbs: root.home ? [] : root.levelTrail
            pageItem: root.page
            pageDir: root.pageDir
            onCrumb: level => root.leaveTo(level)

            openIndex: root.openIndex
            armedIndex: root.armedIndex

            onPicked: i => {
                // A click on another row closes the fold that was open.
                if (i !== root.itemIndex && root.openIndex !== i)
                    root.openPath = "";
                root.itemIndex = i;
                root.column = 1;
                root.activate();
            }
            onTouched: i => {
                if (i !== root.itemIndex) {
                    root.openPath = root.openIndex === i ? root.openPath : "";
                    root.itemIndex = i;
                }
                root.column = 1;
            }
            onBack: root.collapseAll()

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }

            transform: Translate {
                x: root.entered ? (root.home ? 420 : 0) : 420

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutExpo
                    }
                }
            }
        }

        // ------------------------------------------------------ lock preview
        Item {
            id: lockPreviewPane

            x: root.listX + root.listW - root.previewW
            y: root.bodyY
            width: root.previewW
            height: root.bodyH
            visible: root.lockPreview
            opacity: root.lockPreview && !root.flipping ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }

            Column {
                width: parent.width
                spacing: 14

                Row {
                    width: parent.width
                    spacing: 10

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "visibility"
                        color: Colours.accent
                        font.pixelSize: 20
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: "LIVE PREVIEW"
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.large
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "THE REAL LOCK, EVERY PICK AT ONCE"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1
                    }
                }

                // The frame: the lock at this screen's own size, scaled in.
                Item {
                    id: previewFrame

                    width: parent.width
                    height: Math.round(parent.width * root.height / Math.max(1, root.width))

                    Item {
                        id: previewClip

                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: GE.OpacityMask {
                            maskSource: Rectangle {
                                width: previewClip.width
                                height: previewClip.height
                                radius: Appearance.r(22)
                            }
                        }

                        Loader {
                            id: previewLoader

                            // Only while the tab is up: the face is a whole
                            // lock screen, and nobody watches it otherwise.
                            active: root.lockPreview

                            sourceComponent: ({
                                    soft: softPreview,
                                    vibe: Locker.resolve("vibe") === "vibe" ? vibePreview : softPreview
                                })[Config.lock.look] ?? fluidPreview
                        }

                        Component {
                            id: fluidPreview

                            FluidFace {
                                preview: true
                                width: root.width
                                height: root.height
                                scale: previewFrame.width / Math.max(1, root.width)
                                transformOrigin: Item.TopLeft
                            }
                        }

                        Component {
                            id: vibePreview

                            VibeFace {
                                preview: true
                                width: root.width
                                height: root.height
                                scale: previewFrame.width / Math.max(1, root.width)
                                transformOrigin: Item.TopLeft
                            }
                        }

                        Component {
                            id: softPreview

                            SoftFace {
                                preview: true
                                width: root.width
                                height: root.height
                                scale: previewFrame.width / Math.max(1, root.width)
                                transformOrigin: Item.TopLeft
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.r(22)
                        color: "transparent"
                        border.width: 1
                        border.color: Colours.alpha(Colours.ink, 0.14)
                        antialiasing: true
                    }
                }

                Row {
                    spacing: 10

                    Plate {
                        id: replay

                        width: replayRow.implicitWidth + 32
                        height: 38
                        radius: Appearance.r(19)
                        color: replayHover.hovered ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, 0.08)
                        border.width: 1
                        border.color: Colours.alpha(Colours.ink, 0.12)
                        antialiasing: true

                        Row {
                            id: replayRow

                            anchors.centerIn: parent
                            spacing: 8

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "replay"
                                color: replayHover.hovered ? Colours.on(Colours.accent) : Colours.ink
                                font.pixelSize: 17
                            }

                            P5Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "PLAY THE ENTRANCE"
                                color: replayHover.hovered ? Colours.on(Colours.accent) : Colours.ink
                                font.pixelSize: Appearance.font.size.small
                                tracking: 1
                            }
                        }

                        HoverHandler {
                            id: replayHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                Sfx.select();
                                if (previewLoader.item)
                                    previewLoader.item.restartEntrance();
                            }
                        }
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TEST LOCK (IN THE LIST) LOCKS FOR REAL · 20 S"
                        color: Colours.alpha(Colours.inkDim, 0.8)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1
                    }
                }
            }
        }

        // ---------------------------------------------------------- carousel
        Loader {
            id: carousel

            active: root.carouselOpen
            anchors.fill: parent
            z: 20

            sourceComponent: Carousel {
                onClosed: {
                    root.carouselOpen = false;
                    Sfx.back();
                    root.refocus();
                }
            }
        }

        // -------------------------------------------------------- face picker
        //  Choosing your profile photo: a coverflow over your own pictures.
        Loader {
            id: facePicker

            active: root.facePickerOpen
            anchors.fill: parent
            z: 22

            sourceComponent: FacePicker {
                onClosed: {
                    root.facePickerOpen = false;
                    Sfx.back();
                    root.refocus();
                }
                onFaceApplied: root.faceStamp++
            }
        }

        // ------------------------------------------------------- key help
        Loader {
            id: keyHelp

            active: root.helpOpen
            anchors.fill: parent
            z: 40

            sourceComponent: KeyHelp {
                onClosed: {
                    root.helpOpen = false;
                    root.refocus();
                }
            }
        }

        // ------------------------------------------------------------ search
        Loader {
            id: search

            active: root.searching
            anchors.fill: parent
            z: 30

            sourceComponent: SearchOverlay {
                seed: searchSeed.value

                onDismissed: {
                    root.searching = false;
                    root.refocus();
                }
                onChosen: entry => root.navigateTo(entry)
            }
        }

        // ------------------------------------------------------------- hints
        Row {
            id: hints

            visible: !root.skinned
            // Inside a category it sits under the list, clear of the rail;
            // everywhere else in the middle.
            x: root.zone === 1 && !root.home ? root.listX + Math.max(0, (root.listW - hints.width) / 2) : (parent.width - hints.width) / 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.insetB + root.fieldH * 0.035
            spacing: 26
            opacity: root.entered ? 0.75 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.slow
                }
            }

            Repeater {
                model: root.hintList

                Row {
                    id: hint

                    required property var modelData

                    spacing: 7

                    Slash {
                        anchors.verticalCenter: parent.verticalCenter
                        width: keyLabel.implicitWidth + 18
                        height: 24
                        shear: Appearance.skew
                        color: Colours.alpha(Colours.ink, 0.12)
                        borderColor: Colours.alpha(Colours.ink, 0.3)
                        borderWidth: 1

                        P5Text {
                            id: keyLabel

                            anchors.centerIn: parent
                            display: true
                            text: hint.modelData.k
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.tiny
                        }
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: hint.modelData.v
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.6
                    }
                }
            }
        }

        // ------------------------------------------------------------- skin
        //  Every vibe but the house look dresses the window in a layout of its
        //  own — header, category rail, front page and key hints (the rows are
        //  SkinRow). They read this window's state and call its functions;
        //  nothing about what the settings DO lives in them.
        Loader {
            id: skinLoader

            anchors.fill: parent
            z: 6
            active: root.skinned && root.rendered
            sourceComponent: ({
                    console: skinConsole,
                    arcade: skinArcade,
                    hud: skinHud,
                    ledger: skinLedger,
                    glass: skinGlass,
                    tome: skinTome,
                    poster: skinPoster,
                    clean: skinClean,
                    win: skinWin
                })[root.skin] ?? null
        }

        Component {
            id: skinConsole

            SkinConsole {
                host: root
            }
        }

        Component {
            id: skinArcade

            SkinArcade {
                host: root
            }
        }

        Component {
            id: skinHud

            SkinHud {
                host: root
            }
        }

        Component {
            id: skinLedger

            SkinLedger {
                host: root
            }
        }

        Component {
            id: skinGlass

            SkinGlass {
                host: root
            }
        }

        Component {
            id: skinTome

            SkinTome {
                host: root
            }
        }

        Component {
            id: skinPoster

            SkinPoster {
                host: root
            }
        }

        Component {
            id: skinClean

            SkinClean {
                host: root
            }
        }

        Component {
            id: skinWin

            SkinWin {
                host: root
            }
        }

        // ------------------------------------------------------ the room flip
        //  Switching rooms flips a portrait card across the screen. The old
        //  room dims, the card swings in from edge-on carrying the target
        //  room's name, turns through, and the new room unfolds behind it as
        //  the card lifts away. HOME is portrait, the rooms are landscape —
        //  the card is the hinge between the two.
        Item {
            id: flipCard

            anchors.fill: parent
            z: 35
            visible: flipCard.opacity > 0
            opacity: 0

            property real spin: 0

            transform: Rotation {
                origin.x: flipCard.width / 2
                origin.y: flipCard.height / 2
                angle: flipCard.spin
            }

            Item {
                anchors.centerIn: parent
                width: 560
                height: 760
                scale: Math.min(1, (flipCard.height - 80) / 820)

                Slash {
                    anchors.fill: parent
                    shear: Appearance.skew * 1.5
                    color: Colours.alpha(Colours.ink, 0.08)
                    borderColor: Colours.alpha(Colours.accent, 0.5)
                    borderWidth: 1
                }

                Slash {
                    anchors.fill: parent
                    anchors.margins: 14
                    shear: Appearance.skew * 1.5
                    color: "transparent"
                    borderColor: Colours.alpha(Colours.accent, 0.16)
                    borderWidth: 1
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 16

                    VelvetMark {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64
                        height: 64
                        reveal: 1
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        display: true
                        text: "VELVET"
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.large
                        tracking: 3
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        display: true
                        text: root.zones[Math.max(0, Math.min(root.zones.length - 1, root.flipTarget >= 0 ? root.flipTarget : root.zone))].name
                        color: Colours.accent
                        font.pixelSize: 64
                        tracking: -1
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.zones[Math.max(0, Math.min(root.zones.length - 1, root.flipTarget >= 0 ? root.flipTarget : root.zone))].sub
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 3
                    }
                }

                // The middle dash breathes like a loading tick.
                Slash {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 52
                    width: 22
                    height: 3
                    shear: Appearance.skew
                    color: Colours.accent

                    SequentialAnimation on opacity {
                        running: flipCard.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.25
                            duration: 500
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1
                            duration: 500
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }
        }

        // One turn, not two: the card swings in edge-on, the room changes
        // behind it, and it swings on out — about half a second instead of
        // the old in-out-in-out that took well over one.
        SequentialAnimation {
            id: flipAnim

            ParallelAnimation {
                NumberAnimation {
                    target: flipCard
                    property: "spin"
                    from: -90
                    to: 0
                    duration: 190
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: flipCard
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
            ScriptAction {
                script: {
                    if (root.flipTarget >= 0) {
                        root.zone = root.flipTarget;
                        root.flipTarget = -1;
                        root.flipping = false;
                        listFocus.restart();
                    }
                }
            }
            PauseAnimation {
                duration: 60
            }
            ParallelAnimation {
                NumberAnimation {
                    target: flipCard
                    property: "spin"
                    from: 0
                    to: 90
                    duration: 210
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: flipCard
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 210
                    easing.type: Easing.InQuad
                }
            }
            ScriptAction {
                script: {
                    flipCard.spin = 0;
                }
            }
        }
    }

    // ============================================================== keyboard
    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            // The carousel, the search overlay and the home screen each own
            // the keyboard while they are up.
            if (root.searching || root.overlayOpen)
                return;
            // A pane tab or a room owns its own keyboard; only Escape, the
            // tab keys and F1 are still ours. Rooms do not start a search —
            // search is for settings.
            if ((root.isPane || root.zone !== 1) && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Tab && event.key !== Qt.Key_F1 && !(event.modifiers & Qt.ControlModifier))
                return;

            const coarse = (event.modifiers & Qt.ControlModifier) !== 0;

            // F1 shows every key, from any room.
            if (event.key === Qt.Key_F1 || event.key === Qt.Key_Question) {
                root.helpOpen = true;
                Sfx.open();
                event.accepted = true;
                return;
            }

            // Ctrl+Tab cycles the rooms; Ctrl+Shift+Tab walks the other way.
            if (coarse && event.key === Qt.Key_Tab) {
                root.setZone((root.zone + 1) % root.zones.length);
                event.accepted = true;
                return;
            }
            if (coarse && event.key === Qt.Key_Backtab) {
                root.setZone((root.zone + root.zones.length - 1) % root.zones.length);
                event.accepted = true;
                return;
            }

            // The rooms own everything else; only Escape still reaches them,
            // in the switch below.
            if (root.zone !== 1)
                return;

            // Ctrl+1…9 jumps straight to a category. Plain digits are left
            // alone so they can still start a search.
            if (coarse && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                root.enterTab(event.key - Qt.Key_1);
                event.accepted = true;
                return;
            }

            switch (event.key) {
            case Qt.Key_PageUp:
                if (root.column === 1)
                    root.moveItem(-5);
                event.accepted = true;
                return;

            case Qt.Key_PageDown:
                if (root.column === 1)
                    root.moveItem(5);
                event.accepted = true;
                return;

            case Qt.Key_Escape:
                // HOME closes straight away — it is the title screen, not a
                // room you walk back out of. The other rooms first step back
                // to HOME, then the classic one-step-back chain runs for the
                // SETTINGS room itself.
                if (root.zone === 0) {
                    Panels.closeSettings();
                    event.accepted = true;
                    return;
                }
                if (root.zone !== 1) {
                    root.setZone(0);
                    event.accepted = true;
                    return;
                }
                // One step back at a time: a fold closes, a page or an editor
                // steps out, the category goes back to the front page — and
                // from there the menu closes.
                if (!root.stepBack())
                    Panels.closeSettings();
                event.accepted = true;
                return;

            case Qt.Key_Up:
                if (root.railTop && root.column === 1 && root.itemIndex <= 0 && !root.home) {
                    // a strip of categories lies above the list: Up climbs onto it
                    root.column = 0;
                    Sfx.cursor();
                } else if (root.column === 0 && !root.railTop)
                    root.openTab(root.tabIndex - 1 < 0 ? Schema.tabs.length - 1 : root.tabIndex - 1);
                else if (root.column === 1)
                    root.moveItem(-1);
                event.accepted = true;
                return;

            case Qt.Key_Down:
                if (root.railTop && root.column === 0) {
                    if (root.home)
                        root.enterTab(root.tabIndex);
                    else {
                        root.column = 1;
                        Sfx.select();
                    }
                } else if (root.column === 0)
                    root.openTab((root.tabIndex + 1) % Schema.tabs.length);
                else
                    root.moveItem(1);
                event.accepted = true;
                return;

            case Qt.Key_Left:
                if (root.railTop && root.column === 0)
                    root.openTab(root.tabIndex - 1 < 0 ? Schema.tabs.length - 1 : root.tabIndex - 1);
                else if (root.column === 1)
                    root.adjust(-1, coarse ? 10 : 1);
                event.accepted = true;
                return;

            case Qt.Key_Right:
                if (root.railTop && root.column === 0) {
                    root.openTab((root.tabIndex + 1) % Schema.tabs.length);
                } else if (root.home) {
                    root.enterTab(root.tabIndex);
                } else if (root.column === 0) {
                    root.column = 1;
                    Sfx.select();
                } else {
                    root.adjust(1, coarse ? 10 : 1);
                }
                event.accepted = true;
                return;

            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (root.home) {
                    root.enterTab(root.tabIndex);
                } else if (root.column === 0) {
                    root.column = 1;
                    Sfx.select();
                } else {
                    root.activate();
                }
                event.accepted = true;
                return;

            case Qt.Key_Space:
                if (root.column === 1 && root.current?.kind === "toggle") {
                    Bridge.set(root.current, !Bridge.get(root.current));
                    Sfx.toggle();
                }
                event.accepted = true;
                return;

            case Qt.Key_Backspace:
                root.stepBack();
                event.accepted = true;
                return;

            case Qt.Key_Tab:
                root.openTab((root.tabIndex + 1) % Schema.tabs.length);
                event.accepted = true;
                return;

            case Qt.Key_Backtab:
                root.openTab(root.tabIndex - 1 < 0 ? Schema.tabs.length - 1 : root.tabIndex - 1);
                event.accepted = true;
                return;

            case Qt.Key_Home:
                root.itemIndex = 0;
                event.accepted = true;
                return;

            case Qt.Key_End:
                root.itemIndex = Math.max(0, root.rows.length - 1);
                event.accepted = true;
                return;
            }

            // Any printable key jumps into search — the fastest path to a
            // setting you can name but can't find.
            if (event.text && event.text.length === 1 && event.text >= " ") {
                root.searching = true;
                searchSeed.value = event.text === "/" ? "" : event.text;
                event.accepted = true;
            }
        }
    }

    QtObject {
        id: searchSeed
        property string value: ""
    }

    // A stray click on empty space must never close the menu. The menu only
    // closes on purpose: Escape, or one of the close buttons. This used to
    // be a full-screen kill-MouseArea that shut everything on any click
    // outside the list body — labels, gaps and section headers let the
    // click fall through and slammed the whole menu shut. Gone.

}
