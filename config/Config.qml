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
    readonly property var sfx: adapter.sfx
    readonly property var home: adapter.home
    readonly property var velly: adapter.velly
    readonly property var pad: adapter.pad

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
            "appearance.vibe": ["", "arcade", "cyber", "terminal", "paper", "glass", "rpg", "brutal", "clean", "minimal", "flat", "neu", "clay", "windows"],
            "sfx.pack": ["velvet", "arcade", "cyber", "terminal", "paper", "glass", "rpg", "brutal", "clean", "windows"]
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

        JsonAdapter {
            id: adapter

            // ============================================================ APPEARANCE
            property JsonObject appearance: JsonObject {
                // "wallpaper" derives the accent from the current wallpaper,
                // "manual" uses accentColour verbatim.
                property string accentSource: "wallpaper"
                property string accentColour: "#e4002b"
                property real transparency: 0.82   // 0..1 surface alpha
                property real roundingScale: 1.0   // global radius multiplier
                property real spacingScale: 1.0
                property real fontScale: 1.0
                property real animationScale: 1.0  // <1 = faster
                property bool halftone: true       // P5 dot texture in overlays
                // How loud the wallpaper is allowed to be. 1.0 is what the
                // image gave us; lower drifts toward neutral.
                property real accentSaturation: 0.88
                // Raises the whole dark end. Pure black photographs well and
                // reads badly at 2am.
                property real surfaceLift: 0.035
                // How much of the accent hue bleeds into the greys.
                property real surfaceTint: 0.22
                // Measure text against its background and push it until it
                // passes WCAG AA. Turn off only if you want the raw palette.
                property bool contrastGuard: true
                // How much room each settings row gets.
                property string density: "comfortable"   // compact | comfortable | spacious
                property real skew: 4.0            // the signature tilt, in degrees
                property bool sharpCorners: false  // true = full Persona angularity
                // persona (heavy, italic) | soft (round, upright) | mono (terminal)
                // | serif (editorial) | block (chunky arcade/poster sans) | tech
                // (wide, light, HUD).
                property string typeStyle: "persona"
                // The soft looks' pill colour (soft lock, soft widgets, the
                // bar's TONE): "accent" = the accent's own deep tone,
                // "surface" = the shell's grey, "black". Strength and
                // lightness tune the accent tone.
                property string softTone: "accent"
                property real softToneStrength: 1.0
                property real softToneLight: 0.13
                property string fontDisplay: "auto"
                property string fontBody: "auto"
                property string fontMono: "auto"

                // ── THE VIBE — what every card, chip and panel is made of.
                // The house look is slash/persona; the rest of these dials turn
                // the same shell into a pixel arcade, a sci-fi HUD, a terminal,
                // a paper zine, frosted glass, a fantasy tome or a brutalist
                // poster (SETTINGS → LOOKS → VIBES).
                //
                // Card shape: slash (tilted) | round | pill | square | notch
                // (cut corners) | bracket (corner marks) | pixel (stair steps).
                property string shape: "slash"
                // An outline drawn over every card, in px (0 = none).
                property real outline: 0
                // Its colour: auto (follows the look) | ink | accent | black.
                property string edge: "auto"
                // What a card casts: none | soft | hard (offset block) | glow.
                property string shadow: "none"
                property int shadowSize: 0
                // The ground the palette is built on: dark | light.
                property string ground: "dark"
                // Letters: upper (as written) | lower (everything lowercase).
                property string caps: "upper"
                // How things move: punchy | smooth | bouncy | crisp.
                property string motion: "punchy"
                // CRT lines laid over the big surfaces, 0..1.
                property real scanlines: 0
                // The hue the greys of every panel are made of: "auto" takes the
                // accent's, a colour (#1b2a6b) gives navy panels under a yellow accent.
                property string groundColour: "auto"
                // The SETTINGS skin — how the settings window is built, not just
                // dressed: persona (big cards on a rail) | console (a text
                // terminal) | arcade (a game's level select) | hud (a sci-fi
                // panel) | ledger (a newspaper) | glass (floating panes) |
                // tome (a book) | poster (loud stacked blocks) | clean (a calm
                // column) | win (a window of the chosen WINDOWS version).
                property string skin: "persona"
                // The pattern under settings, launcher and home: persona (rays
                // and print dots) | plain | grid | dots | checker | ruled | vignette.
                property string backdrop: "persona"
                // Which vibe was last put on (for the LOOKS page).
                property string vibe: ""
                // Which Windows the WINDOWS look wears: 95 | xp | 7 | 10 | 11.
                property string winVersion: "11"

                // ── THIS LOOK (VISUALS → THIS LOOK) — the tuning every look
                // shares. 1.0 is the look as designed; each look remembers its
                // own values (appearance.tunes), so putting a look back on
                // brings your tuning back with it.
                // How deep the relief is: every shadow's reach, the raise of
                // neumorphic and clay plates, the lift of a glass pane.
                property real depth: 1.0
                // How glossy: the sheen of glass, the shine of clay, the
                // highlight edge of a bevel.
                property real gloss: 1.0
                // How loud the pattern behind the panels is (speed lines, dots,
                // grid, the aurora).
                property real patternStrength: 1.0
                // GLASS: how white the panes are, the smoke under them that keeps
                // light type readable, how bright their edge is, and the aurora.
                property real glassFrost: 1.0
                property real glassSmoke: 0.24
                property real glassRim: 0.55
                property real auroraStrength: 1.0
                property string auroraPalette: "violet"   // violet | ocean | sunset | forest | mono
                // NEUMORPH: where the light comes from; CLAY: the colour of the
                // clay (accent | peach | mint | sky | lilac).
                property string neuLight: "top-left"      // top-left | top-right | bottom-left | bottom-right
                property string clayTint: "accent"
                // CLEAN · MINIMAL · FLAT: how a row sits (lines | cards | plain)
                // and whether the sidebar has a tint of its own.
                property string cleanRows: "lines"
                property string cleanSide: "tinted"       // tinted | plain
                // The looks' colours: "wallpaper" = each look takes its accent and
                // the hue of its ground from the wallpaper (and follows it when
                // the wallpaper changes); "own" = the colours it was designed in.
                property string lookColours: "wallpaper"
                // SHELL PARTS: how the launcher, the notifications, the volume
                // pop-up and the power menu are built — "auto" = the look's way,
                // or any look's: velvet | prompt | arcade | hud | index |
                // spotlight | grimoire | poster | raycast | start.
                property string launcherStyle: "auto"
                property string notifStyle: "auto"
                property string osdStyle: "auto"
                property string sessionStyle: "auto"
                // What each look remembers: { vibe: { "appearance.shape": …} }.
                property var tunes: ({})
            }

            // ============================================================ BAR
            property JsonObject bar: JsonObject {
                // Master switch — MODULES → TASKBAR. Off removes the bar
                // and its popouts from every screen.
                property bool enabled: true
                property string position: "left"   // left | right | top | bottom
                property int thickness: 46
                property int margin: 8
                property int rounding: 18
                property int spacing: 10
                property int padding: 8
                property real opacity: 0.82
                property bool blur: true
                property bool persistent: true
                property bool showOnHover: true
                // How wide the invisible strip along the edge is that wakes a
                // hidden bar. Input only — it is not drawn.
                property int revealEdge: 8
                // How much of a hidden bar stays VISIBLE. 0 means gone.
                property int peek: 0
                property int hoverDelay: 120
                property int hideDelay: 450
                property int fontSize: 12
                property int iconSize: 18
                // The strip's look: "velvet" (halftone, accent hairline and
                // wedge), "clean" (a plain strip), "floating" (a pill that
                // hugs its modules, centred on the edge).
                property string style: "velvet"
                // A thin frame round the whole screen in the bar's colour,
                // with the desktop's corners rounded inside it.
                property bool frame: false
                property int frameWidth: 6
                property int frameRounding: 22
                // The bar becomes part of the frame: one surface, no seam,
                // the desktop's corners rounded right where the bar ends.
                property bool frameConnect: true
                // The frame's colour: "bar" (the bar's own), "tone" (the
                // accent's deep tone), "black", "accent".
                property string frameColour: "bar"
                property real frameOpacity: 0.96
                // A hairline of accent round the desktop, and a soft shadow
                // the frame casts inwards — the desktop sits IN something.
                property bool frameOutline: false
                property bool frameShadow: true
                // The bar's own colour: "surface" (the shell's), "tone"
                // (the accent's deep tone), "black".
                property string colour: "surface"

                // The bar, in order, start edge → end edge. "spacer" pushes
                // everything after it away; use as many as you like. Edited by
                // dragging in TASKBAR → ARRANGE MODULES.
                property var layout: ["logo", "workspaces", "spacer", "activeWindow", "spacer", "tray", "clock", "statusIcons", "power"]

                property JsonObject workspaces: JsonObject {
                    // "slash" (the accent wedge slides), "pills" (the active
                    // one stretches into a pill with its number), "dots",
                    // "numbers".
                    property string style: "slash"
                    property int shown: 5
                    property bool showWindows: true
                    property bool activeIndicator: true
                    property bool labelOccupied: false
                }

                property JsonObject clock: JsonObject {
                    property bool showDate: true
                    property bool format24h: true
                    property bool showSeconds: false
                }

                property JsonObject status: JsonObject {
                    property bool network: true
                    property bool bluetooth: true
                    property bool volume: true
                    property bool battery: true
                    property bool cpu: true
                    property bool memory: true
                    property bool temperature: false
                }

                property JsonObject tray: JsonObject {
                    property bool background: true
                }

                property JsonObject scroll: JsonObject {
                    property bool workspaces: true
                    property bool volume: true
                    property bool brightness: true
                }
            }

            // ============================================================ HYPRLAND
            // Written live via hyprctl and persisted to ~/.config/hypr/velvet.conf
            property JsonObject hypr: JsonObject {
                property bool manage: true         // master switch for the writer
                // "auto" picks .lua or .conf by which config file you have.
                property string format: "auto"     // auto | lua | conf
                // Dispatchers differ between the two config languages.
                property string luaDispatch: "auto"  // auto | lua | classic
                property bool manageBorders: false  // tint window borders with the accent (README: off by default)
                property int gapsIn: 5
                property int gapsOut: 12
                property int borderSize: 2
                property int rounding: 12
                property real roundingPower: 2.0
                property real activeOpacity: 1.0
                property real inactiveOpacity: 0.92
                property bool dimInactive: false
                property real dimStrength: 0.3
                property bool blur: true
                property int blurSize: 6
                property int blurPasses: 3
                property real blurNoise: 0.02
                property bool blurXray: false
                property bool shadow: true
                property int shadowRange: 18
                property real shadowRenderPower: 3.0
                property bool vrr: true
                property bool resizeOnBorder: true
                property string layout: "dwindle"
                property bool animations: true
                // On unlock the open windows rise from 0 up to their
                // configured opacity while the lock lets go — the desktop
                // fades in instead of popping.
                property bool unlockFade: true
                property bool followMouse: true
            }

            // ============================================================ SERVICES
            property JsonObject services: JsonObject {
                property real volumeStep: 0.05
                property real brightnessStep: 0.05
                property real volumeOverdrive: 1.0   // max volume (1.0 = 100%)
                property bool nightLight: false
                property int nightLightTemp: 4000
                property bool idleInhibit: false
                // One switch for "leave me alone". What it actually does is
                // yours to choose below; the point is that one keypress does
                // all of it and one keypress puts it all back.
                property bool focusMode: false
                property bool focusSilences: true
                property bool focusKeepsAwake: true
                property bool focusHidesBar: false
                property bool focusMutesShell: true
                // Spotlight: focus mode dims every window you are not looking
                // at (through the same live Hyprland path the DESIGN page
                // uses) and shades the desktop behind it. Both are put back
                // the moment focus goes off — focus never rewrites your
                // own dim_inactive settings, it only borrows them.
                property bool focusDims: true
                property real focusDimStrength: 0.55   // 0.3..0.8, stronger than the default dim
                property bool focusShades: true
                // Checking a task off answers with a toast and a flourish
                // (WORKFLOW → QUEST COMPLETE).
                property bool questToasts: true
                // Tombstone: the combo meter was removed in v7.9.1 on request.
                // The switch stays, false, only so the parked files
                // services/Combo.qml and modules/osd/Combo.qml — which nothing
                // instantiates any more — stay valid and inert if ever revived.
                property bool comboMeter: false
                // ── AUDIO-REACTIVE DESKTOP ─────────────────────────────────
                // cava drives the shell: a live waveform under the island's
                // transport, the bar's media entry pulsing on the beat, and
                // a hairline wave on the wallpaper. One master switch here;
                // the three surfaces are separate so an all-day music
                // desktop does not mean a moving wallpaper. Silent without
                // cava — no fake motion.
                property bool audioReactive: true
                property bool audioIsland: true
                property bool audioBar: true
                property bool audioWave: true
                // The wallpaper wave's look: "hairline" (the quiet row in the
                // middle), or a WAVE / BARS / LINE along a screen edge.
                property string audioWaveStyle: "hairline"
                property string audioWaveEdge: "bottom"
                property real audioWaveReach: 0.12
                property string audioWaveDensity: "normal"   // fine · normal · wide (BARS)
                property bool weather: true
                // Empty means "wherever wttr.in thinks you are".
                property string weatherLocation: ""
                property bool weatherMetric: true
                property int weatherInterval: 20   // minutes
                property string screenshotCommand: "grim -g \"$(slurp)\" - | wl-copy"
            }

            // ================================================================= MAP
            // The mini desktop that drops from the top edge.
            property JsonObject map: JsonObject {
                property bool enabled: true
                property bool hoverEdge: true       // open by touching the top edge
                property int edgeWidth: 420         // how wide that hot zone is
                property int edgeHeight: 4
                property int openDelay: 130
                property int closeDelay: 420
                // The Dynamic Island: hovering the edge raises the black pill
                // first — swipe for modules, pull down to open. Off gives you
                // the map directly on hover, the old way.
                property bool island: true
                // How wide the resting pill is — MODULES → DYNAMIC ISLAND.
                property int islandWidth: 316
                // The island's face — MODULES → DYNAMIC ISLAND: how solid
                // the capsule is, which ground it sits on, and whether the
                // accent glows along its ring.
                property real islandOpacity: 1.0      // 0.35..1
                property string islandTheme: "dark"   // dark | glass | wallpaper
                property bool islandAccent: true
                // Where the pill stands: BELOW a bar on the top edge (it used
                // to land on top of it), or OVER it. Plus a free nudge.
                property string islandPlace: "below"   // below | over
                property int islandGap: 0               // extra px from the top
                property int islandShift: 0             // px sideways
                // The TASKS module in the island's swipe cycle, between the
                // map and the weather — configure it in WORKFLOW.
                property bool islandTasks: true
                // How wide the plate is, as a share of the screen. There is no
                // height dial on purpose: the plate is cut to your monitor's
                // shape, which is what makes one workspace fill it exactly.
                property real plateWidth: 0.34
                // How many desktops the map keeps room for. Zooming out has to
                // show you somewhere to put a window, not a dead end.
                property int desktops: 6
                property bool showTitles: true
                property bool showWorkspaceLabels: true
                // The photograph of the desktop. Off gives you icon cards,
                // which cost nothing.
                property bool previews: true
                property bool clickFocuses: true
                // Dragging a tiled window plainly means "put it there", and
                // Hyprland can only do that once the window floats.
                property bool dragFloats: true
            }

            // =============================================================== SCENE
            // The windows that belong on the desktop, and where. Arranged by
            // hand in SUPER+TAB -> DESKTOP and remembered per wallpaper.
            property JsonObject scene: JsonObject {
                // Bring the scene up on login, if its wallpaper is the one on.
                property bool autostart: true
                // …and again whenever you switch to that wallpaper: the old
                // scene's desktops close completely and the new scene comes
                // up. The wallpaper IS the desk — that is the point of the
                // DESKTOP tab.
                property bool onWallpaperChange: true
                // Which emulator the little terminal programs open in.
                property string terminal: "auto"
                // How windows sit on each desktop: { "3": "tiling", "5": "floating" };
                // a desktop not listed is normal (services/WorkspaceModes.qml).
                property var workspaceModes: ({})
            }

            // ============================================================== LYRICS
            property JsonObject lyrics: JsonObject {
                property bool enabled: false
                property bool desktop: true         // draw it on the desktop
                property string position: "bottom"  // bottom | top | centre
                property real size: 1.0
                // "word" shows one word at a time, huge, the way the inspo
                // does it; "line" shows the whole line and fills it in as it
                // is sung.
                property string mode: "word"
                property bool blocky: true          // pixel-slab type, like the inspo
                property bool tile: true            // draw it as a panel, not loose on the desktop
                property real width: 0.46           // share of the screen, tile mode
                property bool shadow: true          // the extruded drop behind the type
                property bool showProgress: true
                property bool romanise: false
                property int offsetMs: 0            // nudge the timing
            }

            // =============================================================== LOOKS
            // A "look" is the appearance settings that belong with a wallpaper.
            // Switch wallpaper, get its look back.
            property JsonObject looks: JsonObject {
                property bool enabled: true
                property bool autoSave: true        // remember tweaks against the current wallpaper
                property bool includeBar: true
                property bool includeWindows: true
                property bool includeLock: true
                property bool includeDesktop: true
                property bool includeMore: true
            }

            // ============================================================ PAD
            // Which player slot the game controller takes (QUICK SETTINGS →
            // CONTROLLER). 1 changes nothing; 2 makes bin/velvet-pad hold
            // slot 1 so the pad you plug in is player 2 — Bluetooth or cable.
            property JsonObject pad: JsonObject {
                property int player: 1
            }

            // ============================================================ LAUNCHER
            property JsonObject launcher: JsonObject {
                // Master switch — MODULES → PILL LAUNCHER.
                property bool enabled: true
                property int maxShown: 8
                property bool fuzzy: true
                property bool showIcons: true
                property bool useCalculator: true
                // Find shell settings from the launcher, not only apps.
                property bool searchSettings: true
                property string actionPrefix: ">"
                property real width: 720
            }

            // ============================================================ NOTIFS
            property JsonObject notifs: JsonObject {
                property bool enabled: true
                property bool expanded: false
                property int timeout: 5000
                property int maxPopups: 5
                property bool doNotDisturb: false
                property string position: "top-right"
                property real width: 400
            }

            // ============================================================ OSD
            property JsonObject osd: JsonObject {
                property bool enabled: true
                property int timeout: 1600
                property string position: "bottom"
            }

            // ============================================================ WALLPAPER
            property JsonObject wallpaper: JsonObject {
                property string directory: `${Quickshell.env("HOME")}/Pictures/Wallpapers`
                property string current: ""
                property bool transition: true
                // "builtin" paints the wallpaper itself on a background layer —
                // no swww, no hyprpaper, and it always comes back after a reboot.
                property string renderer: "builtin"   // builtin | external
                property string fillMode: "fill"      // fill | fit | stretch
                property int fadeDuration: 900
                property bool kenBurns: true          // slow drift while idle
                property bool vignette: true          // soft gradient across the image
                property int rotateMinutes: 0         // auto-advance · 0 = off
                // The Super+W coverflow — MODULES → WALLPAPER CHANGER.
                property bool wheel: true
                // Right-click on a free spot of the desktop opens the quick
                // desktop menu (widgets, wallpaper, look, desktops, canvas).
                property bool deskMenu: true
                // ── THE LIVING DESKTOP ─────────────────────────────────────
                // Widgets and living light layered onto the wallpaper itself,
                // so a wallpaper is a place rather than a picture. Master
                // switch here; every knob lives in WALLPAPER → LIVING DESKTOP.
                property bool living: true            // the whole living layer
                property bool livingWidgets: true     // scene widgets ride the wallpaper
                property string livingChips: "shapes" // shapes | soft | glass | ink | raw — per widget overridable
                // The SHAPES look: DEEP tones for a dark desktop, PASTEL for
                // the soft light one. MOTION = morphs, rolling digits, fills.
                property string shapeTone: "deep"     // deep | pastel
                property bool shapeMotion: true
                // Point at a SHAPES or SOFT widget and its shape morphs (its
                // HOVER SHAPE, or a partner of its own).
                property bool shapeHoverMorph: true
                property real livingScale: 1.0        // global widget size · 0.5..2
                property real livingOpacity: 0.72     // chip opacity · 0.3..1
                property bool livingEntrance: true    // widgets glide in when the wallpaper loads
                property bool livingRipples: true     // accent wave where a new window lands
                property bool livingTimeTint: true    // the picture warms at sunset, cools at night
                property bool livingAurora: false     // a slow drift of accent light
            }

            // ============================================================ LOCK
            property JsonObject lock: JsonObject {
                // On by default. This is only safe because Locker refuses to
                // lock unless PAM has proven itself, and falls back to your own
                // locker otherwise — it can no longer strand you.
                property bool useBuiltin: true
                property bool listenToLogind: true
                // Lock as soon as the shell starts. Paired with SDDM
                // auto-login this turns the lock into the login screen:
                // a reboot lands on the lock and the password lets you in.
                property bool lockOnStart: false
                // Which /etc/pam.d service to authenticate against. "auto"
                // picks the first of velvet, hyprlock, swaylock, system-auth,
                // login that exists. Guessing wrong here is the usual reason a
                // lock screen never accepts a correct password.
                property string pamConfig: "auto"
                property real backgroundDim: 0.55
                property bool showMedia: true
                property string greeting: ""
                // The lock's face. "fluid" is the welcoming card with its
                // side columns; "soft" the round one; "velvet" is the
                // original hard-edged look; "vibe" draws the lock of the vibe you
                // wear (a terminal login, a game's title screen, a newspaper,
                // the logon screen of Windows 95 … 11, a painted wall). The
                // core — PAM, shake, tally marks — is identical either way.
                property string look: "fluid"
                // How the lock enters — the card's entrance choreography,
                // chosen in the LOCK SCREEN tab. "morph" is the card's
                // own square-spin-grow; "zoom", "drop" and "fade" are
                // the quiet alternatives, each with a matching exit.
                property string animation: "morph"
                // The lock's own motion dial, on top of the global one.
                // Honoured by zoom, drop and fade; the morph keeps its own
                // timing.
                property real animationScale: 1.0
                // The glyph the wallpaper sits in behind the card; "off" is
                // the old plain blurred wallpaper.
                property string backgroundShape: "burst"
                // How far the glyph reaches — share of the smaller screen edge.
                property real shapeSize: 0.9
                // Wheel over the lock background swaps the glyph.
                property bool shapeCycle: true
                // The cards around the tile modules; off is bare.
                property bool tileCards: true
                // The password's face — "pop": the shapes pop in on an
                // expressive overshoot and cool to ink; "settle": a deck
                // that settles each shape into a circle; "circles" skips
                // the glyphs.
                property string passwordShapes: "pop"
                // The eye in the password island that lets you peek at
                // what you typed.
                property bool passwordPeek: true
                // The state line: caps/num lock warnings
                // and the keyboard layout under the islands.
                property bool stateHints: true
                // Full-bleed cover art behind the media card.
                property bool mediaArtwork: true
                // The hourly strip and the high/low line on the weather
                // card, when wttr.in delivers them.
                property bool weatherForecast: true
                property bool weatherHighLow: true
                // How many entries (or groups) the notification dock shows.
                property int notifsCount: 4
                // The dock: one row per app with a click-to-unfold
                // preview; off is a flat list.
                property bool notifsGrouped: true
                // Privacy: keep notification content behind the lock.
                property bool hideNotifs: false
                // Wear your ~/.face photo in the avatar glyph.
                property bool avatarFace: true
                // A third resource cell — disk usage.
                property bool resourcesDisk: true
                // The clock: how big (× her 224px), and its face — "" the
                // light headline, "display" the heavy house type, "mono",
                // "dots", a drawn 5 × 7 dot matrix, or "analog", hands on a
                // round dial.
                property real clockScale: 1.0
                // How big the card's inside is drawn: "auto" grows with a
                // taller screen, or a factor ("1.15").
                property string scale: "auto"
                property string clockFace: ""
                // The shape the clock sits in: "none", or cookie / sun /
                // flower / clover / circle / pentagon — hours over minutes,
                // with the hands sweeping over them.
                property string clockShape: "none"
                // How soft the wallpaper behind the lock is (0 = sharp).
                property real blur: 1.0
                // With a background shape: what lies around it — the plain
                // paper, or the whole wallpaper, blurred and dimmed.
                property string shapeSurround: "paper"
                // The music along a screen edge while locked.
                property bool visualizer: false
                property string visualizerEdge: "bottom"
                property string visualizerStyle: "wave"
                property real visualizerReach: 0.16
                // The line the song is singing, under the date.
                property bool lyrics: true
                // Seconds without input before the lock steps back to the
                // clock, the lyric and the visualizer ("0" = never).
                property string ambientAfter: "30"
                // The clock's typeface ("" = by CLOCK FACE) and how big the
                // digits sit inside a clock shape (1 = the house size).
                property string clockFont: ""
                property real clockFontScale: 1.0
                // The digits' colours: "twotone" (hours in the accent,
                // minutes in ink), "accent", "ink".
                property string clockColours: "twotone"
                // How close the visualizer's bars stand: fine · normal · wide.
                property string visualizerDensity: "normal"
                // ── the SOFT lock (LOCK STYLE → SOFT) ─────────────────────
                // Where the clock sits against the password: stacked
                // (VERTICAL), side by side (HORIZONTAL), or the GREETING
                // stage — a column of shapes, a big hello in a cloud.
                property string layout: "vertical"
                // The pencil beside the password: customise the lock right
                // on the lock (clock style, size, font, blur, visualizer).
                property bool softEdit: true
                // The small pills around the password: LOG OUT · RESTART ·
                // SHUT DOWN, the bell with the weather, what is playing.
                property bool softPower: true
                property bool softStatus: true
                property bool softMedia: true
                // ── the soft lock, arranged by hand ─────────────────────────
                // CUSTOM layout: where each element sits, as fractions of the
                // screen ({ clock: { x: 0.5, y: 0.3 } …}), and every
                // element's own look in any layout: { id: { shape, scale,
                // show, corners, form } }.
                property var softPlace: ({})
                property var softStyle: ({})
                // How the elements arrive: rise · fade · zoom · drop · pop ·
                // spin · slide, and the beat between one element and the next.
                property string softAnimation: "rise"
                property real softStagger: 0.08
                // Elements glide to their new place when the layout changes;
                // the shapes turn slowly while locked; the digits roll.
                property bool softGlide: true
                property bool softShapeSpin: false
                property string softDigitMotion: "roll"   // none · roll · fade
                // Point at a shape on the soft lock and it morphs into its hover shape.
                property bool softHoverMorph: true
                // How solid the soft lock's modules are (1 = solid); each
                // module's own fill and highlight live in softStyle[id].fill/.hi.
                property real softOpacity: 1.0

                // ── the lock of the VIBES (LOCK SCREEN → VIBE FACES) — what every
                // face (terminal, game, HUD, newspaper, glass, book, poster,
                // quiet, Windows) takes from you, whatever it looks like.
                // The clock's hours: follow the bar | 24h | 12h; with seconds.
                property string vClock: "auto"
                property bool vSeconds: false
                // The date under it: long | short | numeric | off.
                property string vDate: "long"
                // How big the clock is (1 = the face's own size).
                property real vScale: 1.0
                // What typing looks like: dots | stars | bar | count | none.
                property string vMask: "dots"
                // The line the face says to you ("" = the face's own words).
                property string vHello: ""
                // The name and picture of the user; the battery · network line;
                // the song that is playing; the weather.
                property bool vUser: true
                property bool vInfo: true
                property bool vMedia: false
                property bool vWeather: false
                // How blurred and how dark the wallpaper behind the face is
                // ("auto" = the face's own, else a number from 0 to 1).
                property string vBlur: "auto"
                property string vDim: "auto"
                // How the face arrives: fade | rise | zoom | none.
                property string vEntrance: "fade"
                // The small hints (caps lock, the keys that work).
                property bool vHints: true
                // The atmosphere over the face: none | stars | embers | rain |
                // snow | scanlines | grain | vignette, and how strong it is.
                property string vFx: "none"
                property real vFxStrength: 1.0
                // The edges glow in the accent with the music.
                property bool vGlow: false
                // The music along an edge of the look's lock.
                property bool vViz: false
                property string vVizEdge: "bottom"
                property string vVizStyle: "wave"
                property real vVizReach: 0.09
                // The clock's colour (auto = the look's own | accent | alt |
                // ink | white | black) and typeface ("" = the look's own).
                property string vClockColour: "auto"
                property string vClockFont: ""
            }

            // ============================================================ SFX
            property JsonObject sfx: JsonObject {
                property bool enabled: true
                property real volume: 0.55
                property string player: "auto"  // auto | pw-play | paplay | aplay
                // The sound set: velvet (the house clicks) or one made for a
                // vibe — arcade · cyber · terminal · paper · glass · rpg · brutal.
                property string pack: "velvet"
            }

            // ============================================================ HOME
            // The Super+Tab title screen: your name, your face, your HUD.
            property JsonObject home: JsonObject {
                // The player name on the HOME page. Empty shows the login.
                property string displayName: ""
                // Wear the ~/.face photo in the profile card; off is the
                // glyph badge with your initial.
                property bool avatarFace: true
                // How Super+Tab opens: fullscreen | maximized (the bar stays) | window.
                property string winMode: "fullscreen"
                // A welcome page with the first steps opens with the shell.
                property bool welcome: true
                // The settings window's size (0 = a share of the screen).
                property int winW: 0
                property int winH: 0
            }

            // ============================================================ VELLY
            // The assistant the Dynamic Island keeps asleep until you hold
            // the pill. Everything here is a dial on that session: what she
            // may do, what she may hear, and what she leaves behind.
            // The secret itself (the API key) never lives here — it lives in
            // ~/.config/velvet/ai.json with 0600, written by her own setup.
            property JsonObject velly: JsonObject {
                // Master switch — MODULES → VELLY. Off removes her module from
                // the island and the long press does nothing.
                property bool enabled: true
                // How long you hold the pill before she wakes, in ms.
                property int longPress: 620
                // Speak her answers out loud (bin/velvet-voice).
                property bool voice: true
                // Which engine: auto picks piper, then espeak-ng, then a cloud
                // voice when there is a key, and stays quiet when there is none.
                property string voiceEngine: "auto"  // auto | natural | piper | espeak | cloud | none
                property string voiceName: ""        // engine's own voice, empty = default
                property string naturalVoice: "Sophie" // the natural (Orpheus) speaker
                property bool fillers: true          // "Hm, Moment …" while she thinks
                property bool wakeWord: false        // "Hey Velly" without holding the island
                property real voiceSpeed: 1.0        // 0.6 slow … 1.5 fast, 1.0 is the voice's own pace
                property real voiceVolume: 0.9
                // Listen while she is awake (bin/velvet-ears). The microphone
                // runs only inside a session — asleep means the process is gone.
                property bool ears: true
                property bool autoListen: true       // open the mic the moment she wakes
                property real earsSensitivity: 1.0   // 0.4..3 — how loud you have to be
                // Her memory: what she remembers across sessions.
                property bool learn: true
                // The one greeting she says when she wakes, spoken only.
                property bool greet: true
                // Ask before the destructive tools (lock, logout, reboot,
                // shutdown, restarting the shell).
                property bool confirmDanger: true
                // Which brain: auto means the local engine room first (free,
                // no key, nothing leaves the machine), then a local ollama,
                // then a stored key. The model and the key are set in her own
                // SETUP — this is the override.
                property string provider: "auto"     // auto | local | openai | deepseek | anthropic | ollama
                property string model: ""            // empty = the provider's default
                property real temperature: 0.6
                property int maxTokens: 320          // how long an answer may get
                // Run the CHOSEN size even when it is far from fitting the free
                // VRAM right now (a game holding the card): most of it then
                // lives in RAM and it answers slowly. A model that is only a
                // little short always keeps its size — llama.cpp moves just a
                // few expert layers. Off: the biggest size that fits serves.
                property bool forceTier: false
                // Minutes the model stays loaded after a session — the next
                // question is instant instead of a 12 GB load. 0 unloads at
                // once. A fullscreen game always takes the card back at once.
                property int keepWarm: 5
                // Music drops while she listens and talks, so the microphone
                // hears you, not the song (whisper turned lyrics into
                // questions — measured), and comes back when she sleeps.
                property bool duckMedia: true
            }
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
