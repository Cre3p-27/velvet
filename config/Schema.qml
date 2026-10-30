//  VELVET  ·  config/Schema.qml
//  Every setting in the shell, described as data. The Persona menu renders
//  this and nothing else — adding a setting here makes it appear, searchable
//  and keyboard-navigable, with no UI work at all.
//
//  kinds:  slider · toggle · choice · action · page · carousel · colour · info
//  fmt:    int · percent · float1 · float2 · raw
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property var fontChoices: {
        const wanted = ["Archivo Black", "Anton", "Bebas Neue", "Oswald", "Inter Display", "Inter", "IBM Plex Sans", "Roboto", "Roboto Condensed", "Noto Sans", "Cantarell", "JetBrains Mono", "Iosevka", "Fira Code", "DejaVu Sans"];
        const have = Qt.fontFamilies();
        const out = [
            {
                value: "auto",
                label: "AUTO"
            }
        ];
        for (let i = 0; i < wanted.length; i++)
            if (have.indexOf(wanted[i]) !== -1)
                out.push({
                    value: wanted[i],
                    label: wanted[i].toUpperCase()
                });
        return out;
    }

    // The vibe faces' clock: "" keeps the look's own face.
    readonly property var lockClockFonts: [
        {
            value: "",
            label: "THE LOOK'S OWN"
        }
    ].concat(root.fontChoices.filter(f => f.value !== "auto")).concat(root.clockFontChoices.filter(f => f.value !== "" && root.fontChoices.every(g => g.value !== f.value)))

    // The lock clock's typefaces: "" follows CLOCK FACE; then whichever of
    // the round inspo families are installed.
    readonly property var clockFontChoices: {
        const wanted = ["Google Sans", "Google Sans Flex", "DM Sans", "Plus Jakarta Sans", "Outfit", "Poppins", "Inter", "Adwaita Sans", "Open Sans", "Cantarell", "Noto Sans", "DejaVu Sans"];
        const have = Qt.fontFamilies();
        const out = [
            {
                value: "",
                label: "BY CLOCK FACE"
            }
        ];
        for (let i = 0; i < wanted.length; i++)
            if (have.indexOf(wanted[i]) !== -1)
                out.push({
                    value: wanted[i],
                    label: wanted[i].toUpperCase()
                });
        return out;
    }

    // ================================================================== TABS
    readonly property var tabs: [
        {
            // Whole-shell presets from the inspo videos — one click puts a
            // look on, the band on top takes you back to your own setup.
            name: "LOOKS",
            sub: "VELVET THE ORIGINAL · 13 VIBES · SAKURA · SOFT LOCK · EMBER",
            icon: "auto_awesome",
            pane: "looks",
            items: []
        },
        {
            name: "VISUALS",
            sub: "COLOUR · SHAPE · MOTION",
            icon: "palette",
            items: root.visuals
        },
        {
            // Every piece of the shell in one place — switch a module on
            // or off here, and open its own page of knobs underneath.
            // The bar lives here too: MODULES → TASKBAR is the whole old
            // TASKBAR tab, one bar, one home.
            name: "MODULES",
            sub: "TASKBAR · ISLAND · LAUNCHER · WALLPAPER …",
            icon: "widgets",
            items: root.modulesHub
        },
        {
            // The other editor tab. Drag programs onto a picture of your
            // screen; they open where you put them, every time.
            name: "DESKTOP",
            sub: "WHAT SITS ON YOUR WALLPAPER, AND WHERE",
            icon: "space_dashboard",
            pane: "desktop",
            items: []
        },
        {
            // Everything that can be different per wallpaper, in one place:
            // what is saved, what it holds, and every wallpaper that has a look.
            name: "PER WALLPAPER",
            sub: "EACH WALLPAPER KEEPS ITS OWN TASKBAR, WINDOWS, LOCK AND DESKTOP",
            icon: "wallpaper",
            pane: "wallpaper",
            items: []
        },
        {
            // The lock's own tab: the rows are the lock's knobs, and the
            // ARRANGE MODULES page opens the editor — drag the modules around
            // a picture of the lock, exactly like the desktop one.
            name: "LOCK SCREEN",
            sub: "WHAT THE LOCK SHOWS, AND WHERE",
            icon: "lock",
            items: root.lockScreen
        },
        {
            name: "WINDOWS",
            sub: "HYPRLAND GAPS · BLUR · SHADOWS",
            icon: "monitor",
            items: root.windows
        },
        {
            name: "AUDIO",
            sub: "OUTPUT · INPUT · DEVICES",
            icon: "volume_up",
            items: root.audio
        },
        {
            name: "DISPLAY",
            sub: "RESOLUTION · SCALE · BRIGHTNESS · NIGHT LIGHT",
            icon: "light_mode",
            items: root.display
        },
        {
            name: "WALLPAPER",
            sub: "PICK ONE, RECOLOUR EVERYTHING",
            icon: "image",
            items: root.wallpaper
        },
        {
            name: "SHELL",
            sub: "LAUNCHER · NOTIFICATIONS · SOUND",
            icon: "apps",
            items: root.shell
        },
        {
            name: "POWER",
            sub: "LOCK · SLEEP · RESTART · EXIT",
            icon: "power_settings_new",
            items: root.power
        },
        {
            name: "HOME",
            sub: "THE TITLE SCREEN",
            icon: "home",
            items: root.homePage
        },
        {
            // Who this is for and what it stands on.
            name: "CREDITS",
            sub: "SUG & SANE (SnS) · 27 · WHAT IT STANDS ON",
            icon: "favorite",
            pane: "credits",
            items: []
        }
    ]

    // ================================================================ MODULES
    // The hub: every module of the shell, its master switch, and a page of
    // its own knobs. Some of these rows also live in the module's classic
    // tab — same keys, same truth, just a second front door.
    readonly property var modulesHub: [
        {
            kind: "info",
            name: "THE MODULES",
            help: "Every piece of the shell has its own page here. Open one to find its master switch at the top and all of its settings underneath.",
            sub: "EVERY PIECE OF THE SHELL  ·  SWITCH IT, TUNE IT, OPEN IT"
        },
        {
            kind: "page",
            name: "TASKBAR",
            help: "Everything about the bar: whether it exists, where it docks, how it looks, the screen frame, how it hides, and which modules sit on it (ARRANGE MODULES at the bottom).",
            sub: "THE BAR AND EVERYTHING ON IT",
            icon: "tune",
            // Everything the bar ever had — the whole old TASKBAR tab,
            // folded into this one page: the master switch first, then
            // every knob, then the editor.
            items: [
                {
                    kind: "toggle",
                    key: "bar.enabled",
                    name: "TASKBAR",
                    help: "The whole bar, on every monitor, together with its popouts. Off removes it completely and frees the space it reserved at the screen edge.",
                    sub: "THE WHOLE BAR, ON EVERY SCREEN"
                },
                {
                    kind: "toggle",
                    key: "bar.blur",
                    name: "BLUR",
                    help: "Frosts whatever is behind the bar (Hyprland layer blur). You only see it where the bar is see-through, so pair it with a BACKGROUND OPACITY below 100%.",
                    sub: "FROST THE BAR OVER WHAT IS BEHIND IT"
                }
            ].concat(root.taskbar).concat([
                {
                    kind: "page",
                    name: "ARRANGE MODULES",
                    help: "The bar editor: a picture of your screen with the bar on it. Drag modules to reorder them, drag them off the strip to remove them, and drag new ones in from the tray below. Click a module to see its own settings beside it.",
                    sub: "DRAG THE BAR BY HAND",
                    icon: "dashboard",
                    pane: "layout",
                    items: []
                }
            ])
        },
        {
            kind: "page",
            name: "DOCK",
            aka: "SECOND TASKBAR · ZWEITE TASKLEISTE · SHORTCUTS · VERKNÜPFUNGEN · FAVOURITES",
            help: "A second taskbar of your own shortcuts on an edge of its own: apps, terminal commands, folders, web links and the shell's own doors (settings, the scratchpad, the launcher …). + adds one (type to find an app, or switch to COMMAND, FOLDER, WEB LINK, SHELL), drag along the dock to reorder, drag one off to remove it. A click opens it — an app that is already open comes forward (click again: its next window); a middle click opens a new one.",
            sub: "YOUR OWN SHORTCUTS  ·  APPS, COMMANDS, FOLDERS, LINKS",
            icon: "dock_to_bottom",
            items: [
                {
                    kind: "toggle",
                    key: "dock.enabled",
                    name: "DOCK",
                    aka: "SECOND TASKBAR · ZWEITE TASKLEISTE",
                    help: "The second taskbar, on every screen. The first time it comes up it holds the apps you pinned in the launcher (or the ones you open most).",
                    sub: "THE SECOND TASKBAR, ON EVERY SCREEN"
                },
                {
                    kind: "choice",
                    key: "dock.position",
                    name: "EDGE",
                    help: "Which edge of the screen it lives on — the bottom like a dock, or any other.",
                    sub: "BOTTOM · TOP · LEFT · RIGHT",
                    when: { key: "dock.enabled", is: true },
                    options: [
                        { value: "bottom", label: "BOTTOM" },
                        { value: "top", label: "TOP" },
                        { value: "left", label: "LEFT" },
                        { value: "right", label: "RIGHT" }
                    ]
                },
                {
                    kind: "slider",
                    key: "dock.size",
                    name: "ICON SIZE",
                    help: "How big its icons are, in pixels.",
                    sub: "HOW BIG THE ICONS ARE",
                    when: { key: "dock.enabled", is: true },
                    min: 28, max: 80, step: 2, fmt: "int", unit: "px"
                },
                {
                    kind: "choice",
                    key: "dock.style",
                    name: "STYLE",
                    help: "AUTO follows the look you wear: pop-it BUBBLES on FIDGET, GLASS on the glass looks, a SOLID pill on the rest. Or pick one.",
                    sub: "AUTO · SOLID · GLASS · BUBBLES",
                    when: { key: "dock.enabled", is: true },
                    options: [
                        { value: "auto", label: "AUTO" },
                        { value: "solid", label: "SOLID" },
                        { value: "glass", label: "GLASS" },
                        { value: "bubble", label: "BUBBLES" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "dock.magnify",
                    name: "MAGNIFY",
                    aka: "VERGRÖSSERN · ZOOM",
                    help: "The icon under the pointer grows out of the dock, its neighbours a little, like a wave following your hand.",
                    sub: "THE ICON UNDER THE POINTER GROWS",
                    when: { key: "dock.enabled", is: true }
                },
                {
                    kind: "toggle",
                    key: "dock.labels",
                    name: "NAMES",
                    help: "The name of what you point at, just beside it.",
                    sub: "THE NAME OF WHAT YOU POINT AT",
                    when: { key: "dock.enabled", is: true }
                },
                {
                    kind: "toggle",
                    key: "dock.running",
                    name: "OPEN APPS TOO",
                    help: "Apps that are open but not on the dock show after a thin line, so the dock doubles as a task list. A dot under an icon says it is open (one per window, up to three).",
                    sub: "OPEN APPS AFTER A LINE  ·  DOTS FOR OPEN WINDOWS",
                    when: { key: "dock.enabled", is: true }
                },
                {
                    kind: "toggle",
                    key: "dock.autoHide",
                    name: "HIDE UNTIL NEEDED",
                    aka: "AUTO HIDE · AUSBLENDEN",
                    help: "Away until the pointer touches its edge; then it springs out. Off: it keeps its place and windows stay clear of it.",
                    sub: "SPRINGS OUT WHEN YOU TOUCH ITS EDGE",
                    when: { key: "dock.enabled", is: true }
                }
            ]
        },
        {
            kind: "page",
            name: "STAGE",
            aka: "STAGE MANAGER · BÜHNE · FENSTER VERWALTEN · WINDOW MANAGEMENT · CARDS",
            help: "A desktop can be a STAGE (SUPER+TAB → DESKTOP → STAGE): one window stands in the middle, every other window of that desktop waits at the edge as a card that leans back into the screen — a live picture of itself with the app's badge. Point at a card: it straightens up and goes live. Click: that window steps on stage, the one there becomes a card. A new window takes the stage; close the one on stage and the last one before it comes back. CTRL+SUPER+arrows walk the cards. Turning the desktop back to NORMAL, TILING or FLOATING brings every card back out.",
            sub: "ONE WINDOW IN THE MIDDLE  ·  THE OTHERS AS CARDS AT THE EDGE",
            icon: "view_sidebar",
            items: [
                {
                    kind: "slider",
                    key: "stage.size",
                    name: "ON STAGE",
                    help: "How big the window on stage is: a share of the screen that the bar and the cards leave, in the middle of it.",
                    sub: "HOW BIG THE WINDOW IN THE MIDDLE IS",
                    min: 40, max: 94, step: 2, fmt: "int", unit: "%"
                },
                {
                    kind: "choice",
                    key: "stage.side",
                    name: "THE CARDS",
                    help: "Which edge the cards wait at.",
                    sub: "LEFT · RIGHT",
                    options: [
                        { value: "left", label: "LEFT" },
                        { value: "right", label: "RIGHT" }
                    ]
                },
                {
                    kind: "slider",
                    key: "stage.card",
                    name: "CARD SIZE",
                    help: "How wide a card is, in pixels.",
                    sub: "HOW WIDE A CARD IS",
                    min: 110, max: 260, step: 2, fmt: "int", unit: "px"
                },
                {
                    kind: "slider",
                    key: "stage.cards",
                    name: "HOW MANY",
                    help: "How many cards show at once — the rest wait as +N, and come forward as you bring cards on stage.",
                    sub: "CARDS AT ONCE",
                    min: 2, max: 10, step: 1, fmt: "int"
                },
                {
                    kind: "toggle",
                    key: "stage.tilt",
                    name: "LEAN BACK",
                    aka: "TILT · 3D · NEIGEN",
                    help: "The cards lean back into the screen, the far side smaller; the one you point at straightens up. Off: flat cards.",
                    sub: "CARDS LEAN BACK INTO THE SCREEN"
                }
            ]
        },
        {
            kind: "page",
            name: "DYNAMIC ISLAND",
            help: "The island that rises when you touch its screen edge: a pill on the top edge, a rail of icons on the left or right edge. It holds the modules (music, map, tasks, weather, system, Velly): swipe, scrub or scroll to flip between them, click or pull one out to open it, hold it to wake Velly. Docked, it grows out of the screen frame or the taskbar.",
            sub: "TOP PILL OR SIDE RAIL  ·  DOCKED IN THE FRAME",
            icon: "view_agenda",
            items: [
                {
                    kind: "toggle",
                    key: "map.island",
                    name: "DYNAMIC ISLAND",
                    help: "Turns the island on. Off means touching its edge opens the mini desktop straight away, the old way, and the island's modules are gone.",
                    sub: "THE ISLAND ITSELF  ·  ITS MODULES  ·  ITS GESTURES"
                },
                {
                    kind: "page",
                    name: "MODULES IN THE ISLAND",
                    help: "Which modules the island holds: switch off the ones you never use and the swipe gets shorter. The desktop map always stays — it is where the island starts. Velly has her own switch under MODULES → VELLY.",
                    sub: "MUSIC · TASKS · WEATHER · SYSTEM — THE MAP ALWAYS STAYS",
                    icon: "view_carousel",
                    items: [
                        {
                            kind: "toggle",
                            key: "map.islandMusic",
                            name: "NOW PLAYING",
                            help: "The music module: the song, its cover, play/pause and the progress. It is the first one in the swipe, left of the map.",
                            sub: "THE SONG, ITS COVER, THE BUTTONS"
                        },
                        {
                            kind: "toggle",
                            key: "map.islandTasks",
                            name: "TASKS MODULE",
                            help: "Adds the task checklist to the island's swipe cycle, between the map and the weather. The tasks themselves are managed in WORKFLOW.",
                            sub: "A CHECKLIST BETWEEN MAP AND WEATHER"
                        },
                        {
                            kind: "toggle",
                            key: "map.islandWeather",
                            name: "WEATHER",
                            help: "Now, today's high and low, the humidity and the next hours (SHELL → WEATHER sets the place).",
                            sub: "NOW · HIGH AND LOW · THE NEXT HOURS"
                        },
                        {
                            kind: "toggle",
                            key: "map.islandSystem",
                            name: "SYSTEM",
                            help: "CPU, memory, temperature, storage and uptime at a glance.",
                            sub: "CPU · MEMORY · TEMPERATURE · STORAGE"
                        },
                        {
                            kind: "toggle",
                            key: "map.islandScratch",
                            name: "SCRATCHPAD",
                            help: "An endless sheet to keep things on — write, draw, sticky notes, arrows, pasted pictures — on pages of its own, kept for good. SUPER+O opens it from anywhere. Its size, paper and pen are under MODULES → SCRATCHPAD.",
                            sub: "WRITE · DRAW · NOTES · SUPER+O"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "map.hoverEdge",
                    name: "OPEN ON HOVER",
                    help: "Touching the top edge of the screen raises the pill. Off: the island only opens from the keyboard shortcut or the bar.",
                    sub: "TOUCH THE TOP EDGE AND THE PILL RISES"
                },
                {
                    kind: "toggle",
                    key: "map.islandSwipeNatural",
                    name: "SWIPE LIKE A PHONE",
                    help: "On: the pill's face sticks to your hand — drag it left and the next module slides in from the right, like turning a page on a phone. Off: drag towards the module you want, like moving a cursor along the tabs. Either way a soft tick tells you when letting go will change the module, and a quick flick does it from a short way.",
                    when: { key: "map.islandSide", is: "centre" },
                    sub: "THE PILL'S FACE FOLLOWS YOUR HAND"
                },
                {
                    kind: "slider",
                    key: "map.islandWidth",
                    name: "PILL WIDTH",
                    help: "How wide the resting pill on the top edge is, in pixels. It widens by itself when a module needs the room. (On a side edge the island is a rail of icons.)",
                    when: { key: "map.islandSide", is: "centre" },
                    sub: "HOW WIDE THE RESTING PILL IS",
                    min: 220, max: 560, step: 4, fmt: "int", unit: "px"
                },
                {
                    kind: "slider",
                    key: "map.islandOpacity",
                    name: "ISLAND OPACITY",
                    help: "How solid the capsule is. 100% is fully opaque; lower lets the desktop show through.",
                    sub: "HOW SOLID THE CAPSULE IS",
                    min: 0.35, max: 1, step: 0.01, fmt: "percent"
                },
                {
                    kind: "choice",
                    key: "map.islandTheme",
                    name: "ISLAND THEME",
                    aka: "ISLAND COLOUR",
                    help: "The island's colour. AUTO follows the look and the frame: the frame's colour where the island grows out of a connected frame, frosted glass on the glass look, the accent's deep tone on the soft-depth looks, ink elsewhere. INK BLACK is the classic solid black. GLASS is a dark frost over the blurred desktop. WALLPAPER wears the picture's own colours. FRAME takes the screen frame's colour (and the bar's, when they are connected): docked, the island, frame and bar are one surface. TONE is the accent's deep shade.",
                    sub: "AUTO FOLLOWS THE LOOK · INK BLACK · GLASS · WALLPAPER · FRAME · TONE",
                    options: [
                        {
                            value: "auto",
                            label: "AUTO"
                        },
                        {
                            value: "dark",
                            label: "INK BLACK"
                        },
                        {
                            value: "glass",
                            label: "GLASS"
                        },
                        {
                            value: "wallpaper",
                            label: "WALLPAPER"
                        },
                        {
                            value: "frame",
                            label: "FRAME"
                        },
                        {
                            value: "tone",
                            label: "TONE"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "map.islandFrame",
                    name: "PART OF THE FRAME",
                    aka: "ISLAND IN THE FRAME",
                    help: "With the SCREEN FRAME on, the island becomes part of it: always docked, in exactly the frame's colour and opacity (ISLAND THEME and ISLAND OPACITY step aside), the frame's outline and shadow carried round it — and at rest the frame swells softly where the island lives, so you can see where it is. It grows out of that swell when you reach for it. Off: the island is a part of its own (DOCK TO THE EDGE still attaches it).",
                    sub: "THE FRAME SWELLS WHERE IT LIVES  ·  ITS COLOUR, OUTLINE AND SHADOW"
                },
                {
                    kind: "toggle",
                    key: "map.islandDepth",
                    name: "DEPTH",
                    aka: "TIEFE · GLASS · RIM",
                    help: "The island is deep where it meets the frame and turns to glass towards its free edge: the wallpaper's colour comes into it there, and a rim of light runs along that edge — like a slab of glass hanging out of the frame.",
                    sub: "DEEP AT THE FRAME  ·  GLASS AND A RIM OF LIGHT AT THE EDGE"
                },
                {
                    kind: "toggle",
                    key: "map.islandBlurIn",
                    name: "INTO FOCUS",
                    aka: "UNSCHÄRFE · BLUR",
                    help: "What opens in the island comes up out of a blur, as if through frosted glass — and so does the next module when you switch.",
                    sub: "MODULES COME UP OUT OF A BLUR"
                },
                {
                    kind: "toggle",
                    key: "map.islandSparkles",
                    name: "SPARKS",
                    aka: "FUNKEN · PARTICLES",
                    help: "A few sparks fly off the island's corners when it lands open, and fade.",
                    sub: "A FEW SPARKS WHEN IT LANDS OPEN"
                },
                {
                    kind: "toggle",
                    key: "map.islandDock",
                    name: "DOCK TO THE EDGE",
                    help: "The island grows out of its edge instead of floating near it: flush with the screen frame or the taskbar there, square where it meets them and flared into them with soft inner curves. With SCREEN FRAME on and the theme FRAME, island, frame and bar read as one surface, and the frame's OUTLINE runs round the island. Off: a free pill a little way off the edge.",
                    sub: "FLUSH WITH THE FRAME OR TASKBAR  ·  FLARED INTO IT"
                },
                {
                    kind: "info",
                    name: "THE SCREEN FRAME",
                    sub: "THE FRAME THE ISLAND GROWS OUT OF",
                    help: "The same switches as TASKBAR → SCREEN FRAME, here because the island docks into the frame."
                },
                {
                    kind: "action",
                    fn: "islandJoinFrame",
                    name: "ISLAND + FRAME AS ONE",
                    help: "One click for the integrated look: the screen frame on and connected to the bar, the island part of the frame.",
                    sub: "FRAME ON · BAR CONNECTED · ISLAND PART OF THE FRAME"
                },
                {
                    kind: "toggle",
                    key: "bar.frame",
                    name: "SCREEN FRAME",
                    help: "A frame (a border round the whole screen, not round each window) in the bar's colour, with the desktop's corners rounded inside it. A docked island grows out of its inner edge.",
                    sub: "A FRAME ROUND THE SCREEN"
                },
                {
                    kind: "slider",
                    key: "bar.frameWidth",
                    name: "FRAME WIDTH",
                    help: "How thick the frame is on the edges the bar does not hold, in pixels. A docked island on such an edge sits right on its inner line.",
                    sub: "HOW THICK THE FRAME IS",
                    when: { key: "bar.frame", is: true },
                    min: 0, max: 24, step: 1, fmt: "int", unit: "px"
                },
                {
                    kind: "slider",
                    key: "bar.frameRounding",
                    name: "FRAME ROUNDING",
                    help: "How round the desktop's corners are inside the frame. The docked island's flared curves grow with it.",
                    sub: "THE DESKTOP'S CORNERS  ·  THE ISLAND'S CURVES",
                    when: { key: "bar.frame", is: true },
                    min: 0, max: 48, step: 1, fmt: "int", unit: "px"
                },
                {
                    kind: "choice",
                    key: "bar.frameColour",
                    name: "FRAME COLOUR",
                    help: "The frame's colour — and the island's, when its theme is FRAME: BAR follows the bar's colour, TONE is the accent's deep shade, BLACK, or ACCENT.",
                    sub: "BAR · TONE · BLACK · ACCENT",
                    when: { key: "bar.frame", is: true },
                    options: [
                        { value: "bar", label: "BAR" },
                        { value: "tone", label: "TONE" },
                        { value: "black", label: "BLACK" },
                        { value: "accent", label: "ACCENT" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "notifs.inFrame",
                    name: "NOTIFICATIONS IN THE FRAME",
                    aka: "BENACHRICHTIGUNGEN IM RAHMEN · NOTIFICATIONS IN THE FRAME · RAHMEN",
                    help: "The popups come out of the SCREEN FRAME itself: a tab of the frame's own colour grows from the corner (or the middle of the edge) you chose under POSITION, its sides flowing into the frame in soft curves, and the cards sit in it in the frame's ink — frame, bar, island and notifications as one surface. The centre (SUPER+N) comes out of the frame too, as a drawer (THE CENTRE TOO). Needs TASKBAR → SCREEN FRAME.",
                    sub: "A TAB OF THE FRAME THAT THE CARDS SIT IN",
                    when: { key: "bar.frame", is: true }
                },
                {
                    kind: "toggle",
                    key: "bar.frameConnect",
                    name: "BAR JOINS THE FRAME",
                    help: "Bar and frame become one surface (no seam), also for a bar that hides: it grows out of the frame. With the island docked and themed FRAME (or AUTO), all three are one.",
                    sub: "BAR AND FRAME, ONE SURFACE",
                    when: { key: "bar.frame", is: true }
                },
                {
                    kind: "toggle",
                    key: "bar.frameOutline",
                    name: "FRAME OUTLINE",
                    help: "A thin accent line along the frame's inner edge. A docked island carries it round itself, as if the frame's edge bent round the island.",
                    sub: "AN ACCENT HAIRLINE  ·  IT BENDS ROUND THE ISLAND",
                    when: { key: "bar.frame", is: true }
                },
                {
                    kind: "info",
                    name: "PLACE AND REACH",
                    sub: "EDGE · HEIGHT · DISTANCE · HOT ZONE",
                    help: "Where the island sits and how much of its edge listens."
                },
                {
                    kind: "choice",
                    key: "map.islandPlace",
                    name: "WITH A BAR ON TOP",
                    when: { key: "map.islandSide", is: "centre" },
                    help: "Where the pill stands when your taskbar is on the top edge. BELOW THE BAR keeps the two apart; OVER THE BAR lets the pill cover it, as before.",
                    sub: "THE PILL AND A TOP TASKBAR  ·  BELOW KEEPS THEM APART",
                    options: [
                        {
                            value: "below",
                            label: "BELOW THE BAR"
                        },
                        {
                            value: "over",
                            label: "OVER THE BAR"
                        }
                    ]
                },
                {
                    kind: "slider",
                    key: "map.islandGap",
                    name: "DISTANCE FROM THE EDGE",
                    help: "Extra room between the island and its edge (or a taskbar on that edge), in pixels. Only when it is not docked.",
                    when: { key: "map.islandDock", is: false },
                    sub: "EXTRA ROOM BETWEEN THE PILL AND ITS EDGE",
                    min: 0, max: 200, step: 2, fmt: "int", unit: "px"
                },
                {
                    kind: "choice",
                    key: "map.islandSide",
                    name: "POSITION",
                    help: "Which screen edge the island lives on. TOP: a pill drops from the middle of the top edge. LEFT EDGE / RIGHT EDGE: a rail of the modules' icons slides out of that side at ISLAND HEIGHT, like a vertical taskbar — point at it and every module's live line unfolds beside its icon; click an icon (or pull it out) and that module opens beside the rail; scrub along the rail or scroll to flip between them. Touching that edge raises it, the desktop map slides in from the same edge, and a taskbar there is stepped round (docked, the rail grows out of it).",
                    sub: "TOP PILL, OR A RAIL ON THE LEFT OR RIGHT EDGE",
                    options: [
                        { value: "centre", label: "TOP" },
                        { value: "left", label: "LEFT EDGE" },
                        { value: "right", label: "RIGHT EDGE" }
                    ]
                },
                {
                    kind: "slider",
                    key: "map.islandEdgeY",
                    name: "ISLAND HEIGHT",
                    help: "On the left or right edge: how far down the island sits. 50 % is the middle of the screen. The hot zone moves with it.",
                    sub: "WHERE ON THE SIDE EDGE IT SITS",
                    when: { key: "map.islandSide", in: ["left", "right"] },
                    min: 0.1, max: 0.9, step: 0.05, fmt: "percent"
                },
                {
                    kind: "slider",
                    key: "map.islandShift",
                    name: "SHIFT SIDEWAYS",
                    help: "Fine-tunes where the pill sits along its edge, in pixels: left or right on the top edge, up or down on a side edge. Handy when the bar has something just there.",
                    sub: "A NUDGE ALONG ITS EDGE",
                    min: -800, max: 800, step: 10, fmt: "int", unit: "px"
                },
                {
                    kind: "toggle",
                    key: "map.islandAccent",
                    name: "ACCENT RING",
                    help: "A thin ring round the capsule in the accent colour. Off keeps the pill plain.",
                    sub: "THE CAPSULE'S RING FOLLOWS THE ACCENT COLOUR"
                },
                {
                    kind: "slider",
                    key: "map.edgeWidth",
                    name: "HOT ZONE LENGTH",
                    help: "How much of the island's edge reacts to the pointer, in pixels (at least 80), centred on the island. Shorten it if you reach that edge by accident, e.g. to hit a window's title or scrollbar.",
                    sub: "HOW MUCH OF ITS EDGE LISTENS",
                    min: 120, max: 1400, step: 20, fmt: "int", unit: "px"
                },
                {
                    kind: "slider",
                    key: "map.edgeHeight",
                    name: "HOT ZONE HEIGHT",
                    help: "How thick the invisible strip at the island's edge is, in pixels. On the top edge anything below 10 px counts as 10; on a side edge 3 to 12 px, so scrollbars there stay usable.",
                    sub: "HOW THICK THE LISTENING STRIP IS",
                    min: 1, max: 40, step: 1, fmt: "int", unit: "px"
                },
                {
                    kind: "slider",
                    key: "map.openDelay",
                    name: "OPEN DELAY",
                    help: "How long the pointer has to rest on the top edge before anything opens, in milliseconds. Raise it if it opens when you just pass by.",
                    sub: "HOW LONG YOU HAVE TO MEAN IT",
                    min: 0, max: 600, step: 10, fmt: "int", unit: "ms"
                },
                {
                    kind: "slider",
                    key: "map.closeDelay",
                    name: "CLOSE DELAY",
                    help: "How long the island or map waits after the pointer leaves before it closes, in milliseconds — room to come back without it snapping shut.",
                    sub: "GRACE PERIOD AFTER THE POINTER LEAVES",
                    min: 0, max: 1500, step: 20, fmt: "int", unit: "ms"
                }
            ]
        },
        {
            // The assistant. Two halves on purpose: the switches that decide
            // what she may do, and the five actions that decide what she is —
            // setup, test, wake, and the two ways to deal with her memory.
            kind: "page",
            name: "VELLY",
            aka: "ASSISTENT · ASSISTENTIN · KI",
            help: "Velly, the assistant in the island. A long press on the pill wakes her; here you set what she thinks with, how she speaks, whether she listens and what she remembers. She speaks German.",
            sub: "THE ASSISTANT IN THE ISLAND · A LONG PRESS WAKES HER",
            icon: "auto_awesome",
            items: [
                {
                    kind: "toggle",
                    key: "velly.enabled",
                    name: "VELLY",
                    help: "Turns Velly on or off as a module of the island. Off: a long press on the pill does nothing, and nothing of her runs in the background.",
                    sub: "HER MODULE IN THE SWIPE CYCLE · WITHOUT HER A LONG PRESS DOES NOTHING"
                },
                {
                    kind: "action",
                    fn: "vellySetup",
                    name: "SETUP",
                    help: "Opens Velly's setup: download or pick a local brain, choose a voice, and — only for cloud providers — store an API key. The key lives in ~/.config/velvet/ai.json (readable by you only, 0600).",
                    sub: "LOAD A LOCAL BRAIN, PICK A VOICE · A KEY ONLY FOR CLOUDS (AI.JSON, 0600)"
                },
                {
                    kind: "action",
                    fn: "vellyWake",
                    name: "WAKE HER NOW",
                    aka: "JETZT WECKEN",
                    help: "Opens the island and a session with Velly, just like the long press.",
                    sub: "OPENS THE ISLAND AND A SESSION — LIKE THE LONG PRESS"
                },
                {
                    kind: "choice",
                    key: "velly.face",
                    name: "FACE",
                    aka: "GESICHT · DOT MATRIX · PUNKTE · ORB",
                    help: "How Velly looks in the island. DOTS: a round dot-matrix display with a face — she blinks, looks at your pointer, goes wide-eyed while she listens, looks up while she thinks (a comet of dots runs round the rim), talks with a mouth of dot bars, squints happily when an answer has landed, and a halo of dot rays rides the voice. ORB: the breathing rings and radial bars.",
                    sub: "DOTS · ORB",
                    options: [
                        { value: "dots", label: "DOTS" },
                        { value: "orb", label: "ORB" }
                    ]
                },
                {
                    kind: "choice",
                    key: "velly.faceDots",
                    name: "DOTS",
                    aka: "PUNKTE · GRAIN · RASTER",
                    help: "How fine her display is: CHUNKY (17 dots across), CLASSIC (21) or FINE (25).",
                    sub: "CHUNKY · CLASSIC · FINE",
                    when: { key: "velly.face", is: "dots" },
                    options: [
                        { value: 17, label: "CHUNKY" },
                        { value: 21, label: "CLASSIC" },
                        { value: 25, label: "FINE" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "velly.faceHalo",
                    name: "HALO",
                    aka: "STRAHLEN · RAYS",
                    help: "The ring of dot rays round her display: it breathes in a slow wave, rides your voice while she listens and hers while she speaks.",
                    sub: "DOT RAYS THAT RIDE THE VOICE",
                    when: { key: "velly.face", is: "dots" }
                },
                {
                    kind: "choice",
                    key: "velly.speakWhen",
                    name: "SHE SPEAKS",
                    aka: "SPRICHT NUR WENN · NUR MIT MIKROFON · VOICE ONLY WHEN SPOKEN TO · ANTWORT VORLESEN",
                    help: "When Velly answers out loud. WHEN SPOKEN TO: only what you said to her (the microphone, „Hey Velly“) gets a spoken answer — what you type is answered in the island, silently, and so is a reminder you typed. ALWAYS: every answer is spoken, typed or not.",
                    sub: "WHEN SPOKEN TO: A SPOKEN QUESTION GETS A SPOKEN ANSWER, A TYPED ONE A WRITTEN ONE",
                    options: [
                        { value: "spoken", label: "WHEN SPOKEN TO" },
                        { value: "always", label: "ALWAYS" }
                    ]
                },
                {
                    kind: "choice",
                    key: "velly.voiceThinking",
                    name: "WHEN YOU SPEAK",
                    aka: "SPRECHEN · GESCHWINDIGKEIT · SPEED FIRST · SCHNELL",
                    help: "How Velly thinks when you talk to her. SPEED FIRST: the quickest thinking that does the job and a few spoken sentences — the answer comes in a moment (only an outright „denk genau nach“ gets more). BALANCED: a little more thought for questions and explanations, about half a second slower.",
                    sub: "SPEED FIRST: THE ANSWER IN A MOMENT · BALANCED: MORE THOUGHT FOR QUESTIONS",
                    options: [
                        { value: "fast", label: "SPEED FIRST" },
                        { value: "balanced", label: "BALANCED" }
                    ]
                },
                {
                    kind: "choice",
                    key: "velly.textThinking",
                    name: "WHEN YOU TYPE",
                    aka: "SCHREIBEN · GRÜNDLICH · PERFEKT · THOROUGH · QUALITY",
                    help: "How Velly works when you type to her. UNTIL IT IS RIGHT: she thinks as deeply as she can, takes every step a task needs (up to 16 tool steps), checks each result and tries another way when one fails — and before the answer goes out she reads it once more like an editor and improves it (CHECKING in the island). Slower, and the answer is written: paragraphs and lists. BALANCED: quicker, no second look.",
                    sub: "UNTIL IT IS RIGHT: DEEP THINKING, EVERY STEP, A SECOND LOOK BEFORE IT GOES OUT",
                    options: [
                        { value: "thorough", label: "UNTIL IT IS RIGHT" },
                        { value: "balanced", label: "BALANCED" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "velly.confirmDanger",
                    name: "ASK FIRST",
                    aka: "NACHFRAGEN · CONFIRM",
                    help: "Before locking, logging out, restarting, shutting down and restarting the shell she asks once before she does it.",
                    sub: "LOCK, LOG OUT, RESTART · SHE ASKS ONCE BEFORE SHE DOES IT"
                },
                {
                    kind: "page",
                    name: "HER VOICE",
                    aka: "STIMME · SPRECHEN · VOICE · TTS",
                    help: "How Velly sounds: the voice engine and the voice itself, speed, volume, the short „Hm, Moment …“ while she thinks, and the hello when she wakes.",
                    sub: "THE ENGINE, THE VOICE, SPEED AND VOLUME",
                    icon: "record_voice_over",
                    items: [
                        {
                            kind: "toggle",
                            key: "velly.voice",
                            name: "VOICE",
                            aka: "STIMME · SPEAK",
                            help: "Velly reads her answers aloud. Off: she answers as text in the island only.",
                            sub: "SHE SPEAKS HER ANSWERS · WITHOUT AN ENGINE THE BLIPS TALK UNTIL A REAL VOICE IS THERE"
                        },
                        {
                            kind: "choice",
                            key: "velly.voiceEngine",
                            name: "VOICE ENGINE",
                            aka: "STIMM-ENGINE · TTS",
                            help: "What she speaks with. QWEN3 is the new voice (Qwen3-TTS 1.7B on the graphics card, ~2.5 GB): in the tests every word was understood, streamed, one fixed voice sentence by sentence. NATURAL is the older Orpheus voice (~3 GB). Neither speaks during a fullscreen game — then Piper takes over. PIPER is fast and runs on the CPU; ESPEAK-NG sounds robotic but is always there; CLOUD needs a key; ANIMALESE is only blips; SILENT says nothing. AUTO takes the best that works right now.",
                            sub: "QWEN3: THE CLEAREST VOICE, STREAMED (GRAPHICS CARD) · NATURAL: ORPHEUS · AUTO TAKES THE BEST THAT WORKS",
                            options: [
                                { value: "auto", label: "AUTO" },
                                { value: "qwen", label: "QWEN3 · THE CLEAREST" },
                                { value: "natural", label: "NATURAL (ORPHEUS)" },
                                { value: "piper", label: "PIPER" },
                                { value: "espeak", label: "ESPEAK-NG" },
                                { value: "cloud", label: "CLOUD" },
                                { value: "animalese", label: "ANIMALESE (BLIPS)" },
                                { value: "none", label: "SILENT" }
                            ]
                        },
                        {
                            kind: "choice",
                            key: "velly.qwenVoice",
                            name: "QWEN VOICE",
                            aka: "QWEN-STIMME",
                            help: "Who Velly is with the Qwen3 voice. Each is a fixed sample every sentence is cloned from — so it stays the same voice. NOVA: bright, lively (the most even over five test sentences); MIRA: calmer; ELLA: a little higher; THEO: male. Applies when the voice engine is QWEN3 (or AUTO picks it).",
                            sub: "WHO SPEAKS AS VELLY · NOVA · MIRA · ELLA · THEO",
                            options: [
                                { value: "Nova", label: "NOVA · LIVELY" },
                                { value: "Mira", label: "MIRA · CALM" },
                                { value: "Ella", label: "ELLA · BRIGHT" },
                                { value: "Theo", label: "THEO · MALE" }
                            ]
                        },
                        {
                            kind: "choice",
                            key: "velly.naturalVoice",
                            name: "NATURAL VOICE",
                            aka: "NATÜRLICHE STIMME · ORPHEUS",
                            help: "Which speaker the natural voice is. Measured (speech recognition over seven sentences): LEA is understood most clearly, then LINA and MARIE; MARIA speaks the calmest. Only applies when the voice engine is NATURAL (or AUTO picks it).",
                            sub: "WHO SPEAKS AS VELLY — REAL VOICES",
                            options: [
                                { value: "Lea", label: "LEA · THE CLEAREST" },
                                { value: "Lina", label: "LINA" },
                                { value: "Marie", label: "MARIE" },
                                { value: "Maria", label: "MARIA · CALM" },
                                { value: "Sophie", label: "SOPHIE" },
                                { value: "Mia", label: "MIA" },
                                { value: "Sophia", label: "SOPHIA" },
                                { value: "Julian", label: "JULIAN" },
                                { value: "Jakob", label: "JAKOB" },
                                { value: "Felix", label: "FELIX" },
                                { value: "Jonas", label: "JONAS" },
                                { value: "Noah", label: "NOAH" }
                            ]
                        },
                        {
                            kind: "choice",
                            key: "velly.voiceName",
                            name: "PIPER VOICE",
                            aka: "STIMME · PIPER",
                            help: "Which Piper voice she uses (German). A voice that is missing downloads itself with the first sentence.",
                            sub: "PIPER'S GERMAN VOICES · A MISSING ONE DOWNLOADS WITH THE FIRST SENTENCE",
                            options: [
                                { value: "", label: "AUTO" },
                                { value: "de_DE-thorsten-medium", label: "THORSTEN · MEDIUM" },
                                { value: "de_DE-thorsten-high", label: "THORSTEN · HIGH" },
                                { value: "de_DE-thorsten-low", label: "THORSTEN · LOW" },
                                { value: "de_DE-thorsten_emotional-medium", label: "THORSTEN · EMOTIONAL" },
                                { value: "de_DE-kerstin-low", label: "KERSTIN" },
                                { value: "de_DE-eva_k-x_low", label: "EVA K" },
                                { value: "de_DE-ramona-low", label: "RAMONA" },
                                { value: "de_DE-karlsson-low", label: "KARLSSON" },
                                { value: "de_DE-pavoque-low", label: "PAVOQUE" },
                                { value: "de_DE-mls-medium", label: "MLS" }
                            ]
                        },
                        {
                            kind: "slider",
                            key: "velly.voiceSpeed",
                            name: "VOICE SPEED",
                            aka: "STIMM-TEMPO · SPEECH RATE",
                            help: "How fast she speaks. 100% is the voice's own pace; higher is faster, lower is slower.",
                            sub: "100% IS THE VOICE'S OWN PACE · ABOVE IT SHE SPEAKS FASTER",
                            min: 0.6, max: 1.5, step: 0.05, fmt: "percent"
                        },
                        {
                            kind: "slider",
                            key: "velly.voiceVolume",
                            name: "VOICE VOLUME",
                            aka: "STIMM-LAUTSTÄRKE",
                            help: "The volume of Velly's voice only, apart from the system volume. The shell's own sounds have their own slider (SHELL → SOUND).",
                            sub: "HER VOICE ONLY — THE SHELL'S SOUNDS HAVE THEIR OWN SLIDER",
                            min: 0, max: 1.2, step: 0.05, fmt: "percent"
                        },
                        {
                            kind: "toggle",
                            key: "velly.fillers",
                            name: "THINKING ALOUD",
                            aka: "LAUT DENKEN · FILLERS",
                            help: "When she thinks for longer, she says a short „Hm, Moment …“ after a second or so — so you know she heard you.",
                            sub: "A SHORT „HM, MOMENT …“ WHEN SHE THINKS LONGER — LIKE A PERSON"
                        },
                        {
                            kind: "toggle",
                            key: "velly.greet",
                            name: "GREETING",
                            aka: "BEGRÜSSUNG",
                            help: "A short spoken hello when she wakes (with your name, if she knows it).",
                            sub: "A SHORT WORD WHEN SHE WAKES"
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "HER EARS",
                    aka: "OHREN · MIKROFON · ZUHÖREN · HEY VELLY",
                    help: "How Velly hears you: the microphone during a session, „Hey Velly“, how loud you must be, music turned down while she listens, and how long you hold the pill to wake her.",
                    sub: "MICROPHONE, HEY VELLY, SENSITIVITY",
                    icon: "hearing",
                    items: [
                        {
                            kind: "toggle",
                            key: "velly.ears",
                            name: "EARS",
                            aka: "OHREN · MICROPHONE · MIKROFON",
                            help: "Velly listens while a session is open. The microphone runs only then — when she sleeps, the process is gone (unless HEY VELLY is on).",
                            sub: "THE MIC ONLY DURING A SESSION · NOTHING RUNS WHILE SHE SLEEPS"
                        },
                        {
                            kind: "toggle",
                            key: "velly.autoListen",
                            name: "LISTEN AT ONCE",
                            aka: "SOFORT ZUHÖREN",
                            help: "The microphone opens the moment she wakes, so you can just start talking. Off: you start the listening yourself.",
                            sub: "THE MIC GOES ON AS SHE WAKES"
                        },
                        {
                            kind: "toggle",
                            key: "velly.wakeWord",
                            name: "HEY VELLY",
                            help: "Wakes Velly without a press when you say „Hey Velly, …“. For that the microphone listens all the time; it is recognised here on the PC only, nothing is uploaded.",
                            sub: "WAKE HER WITHOUT A PRESS: „HEY VELLY, …“ · THE MIC THEN ALWAYS LISTENS, RECOGNISED ON THIS PC ONLY"
                        },
                        {
                            kind: "slider",
                            key: "velly.earsSensitivity",
                            name: "SENSITIVITY",
                            aka: "EMPFINDLICHKEIT",
                            help: "How loud you have to be for her to react. Higher if she does not hear you in a loud room; lower if she jumps at background noise.",
                            sub: "HOW LOUD YOU HAVE TO BE · HIGH IN A LOUD ROOM",
                            min: 0.4, max: 3, step: 0.1, fmt: "float1", unit: "×"
                        },
                        {
                            kind: "toggle",
                            key: "velly.duckMedia",
                            name: "MUSIC DOWN",
                            aka: "MUSIK LEISER · DUCK",
                            help: "While Velly is awake, music that is playing is turned down (or paused when the player has no volume of its own) and restored afterwards. So the microphone hears you instead of the song — lyrics used to be taken for questions — and you understand her answer.",
                            sub: "WHILE SHE IS AWAKE · AFTERWARDS AS BEFORE"
                        },
                        {
                            kind: "slider",
                            key: "velly.longPress",
                            name: "HOLD TIME",
                            aka: "HALTEDAUER · LONG PRESS",
                            help: "How long you hold the pill before Velly wakes, in milliseconds. Shorter wakes her faster — and by accident more often.",
                            sub: "HOW LONG YOU HOLD THE PILL BEFORE SHE WAKES",
                            min: 250, max: 1500, step: 10, fmt: "int", unit: "ms"
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "HER BRAIN",
                    aka: "GEHIRN · MODELL · PROVIDER · KI-MODELL",
                    help: "What Velly thinks with: the local brain or a provider, the model, how long it stays loaded, how freely she words things and how long an answer may be.",
                    sub: "LOCAL OR A PROVIDER, THE MODEL, HOW LONG IT STAYS",
                    icon: "psychology",
                    items: [
                        {
                            kind: "choice",
                            key: "velly.provider",
                            name: "BRAIN",
                            aka: "GEHIRN · PROVIDER · ANBIETER",
                            help: "What Velly thinks with. AUTO takes the local brain first (free, nothing leaves the PC), then a local Ollama, then a stored cloud key. The other entries force exactly that provider.",
                            sub: "AUTO TAKES THE LOCAL BRAIN FIRST, THEN OLLAMA, THEN A KEY",
                            options: [
                                { value: "auto", label: "AUTO" },
                                { value: "local", label: "LOCAL · FREE" },
                                { value: "openai", label: "OPENAI" },
                                { value: "deepseek", label: "DEEPSEEK" },
                                { value: "anthropic", label: "ANTHROPIC" },
                                { value: "ollama", label: "OLLAMA (LOCAL)" }
                            ]
                        },
                        {
                            kind: "choice",
                            key: "velly.model",
                            name: "MODEL",
                            aka: "MODELL",
                            help: "Which model the chosen provider uses. Empty lets the provider decide; the local brain is picked in SETUP.",
                            sub: "EMPTY LETS THE PROVIDER DECIDE · SETUP CAN SET ANY NAME",
                            options: [
                                { value: "", label: "PROVIDER DEFAULT" },
                                { value: "gpt-4o-mini", label: "GPT-4O-MINI" },
                                { value: "gpt-4.1-mini", label: "GPT-4.1-MINI" },
                                { value: "deepseek-chat", label: "DEEPSEEK-CHAT" },
                                { value: "claude-haiku-4-5-20251001", label: "CLAUDE HAIKU 4.5 · FAST" },
                                { value: "claude-sonnet-5", label: "CLAUDE SONNET 5" },
                                { value: "llama3.2", label: "LLAMA 3.2 (LOCAL)" }
                            ]
                        },
                        {
                            kind: "toggle",
                            key: "velly.forceTier",
                            name: "ANYWAY MODE",
                            aka: "TROTZDEM-MODUS · FORCE SIZE",
                            help: "Runs the chosen model size even when it is far from fitting into free graphics memory (say, while a game holds the card). Much of it then sits in system RAM and she answers slowly. If only a little is missing, your size always runs — just a few expert layers move to RAM. Off: the biggest size that fits right now runs.",
                            sub: "YOUR SIZE EVEN WITHOUT ROOM · A NEAR FIT RUNS ANYWAY"
                        },
                        {
                            kind: "choice",
                            key: "velly.keepWarm",
                            name: "STAY WARM",
                            aka: "WACH BLEIBEN · KEEP LOADED",
                            help: "How long the brain stays loaded after a session. Wake Velly again within that time and she answers at once instead of loading the model again (12 GB for the big one). AT ONCE frees the graphics card right after the session. A fullscreen game always gets the card back immediately.",
                            sub: "STAYS LOADED AFTER A SESSION · A GAME GETS THE CARD AT ONCE",
                            options: [
                                { value: 0, label: "UNLOAD AT ONCE" },
                                { value: 2, label: "2 MINUTES" },
                                { value: 5, label: "5 MINUTES" },
                                { value: 15, label: "15 MINUTES" },
                                { value: 60, label: "1 HOUR" }
                            ]
                        },
                        {
                            kind: "slider",
                            key: "velly.temperature",
                            name: "TEMPERATURE",
                            aka: "TEMPERATUR",
                            help: "How freely she words things. Low is matter-of-fact and predictable, high is looser and more varied (and wrong more often).",
                            sub: "HOW FREELY SHE WORDS THINGS",
                            min: 0, max: 1.2, step: 0.1, fmt: "float1"
                        },
                        {
                            kind: "slider",
                            key: "velly.maxTokens",
                            name: "ANSWER LENGTH",
                            aka: "ANTWORTLÄNGE · MAX TOKENS",
                            help: "The longest an answer may be, in tokens (roughly parts of words). She usually answers shorter; the cap stops novels.",
                            sub: "A CAP FOR ONE ANSWER · THE CAPSULE IS 462 PX WIDE",
                            min: 64, max: 1024, step: 16, fmt: "int", unit: " tok"
                        },
                        {
                            kind: "action",
                            fn: "vellyTest",
                            name: "TEST THE LINK",
                            aka: "VERBINDUNG TESTEN",
                            help: "Sends a real request to the chosen provider and shows whether an answer comes back — checks the key, the network and the model.",
                            sub: "A REAL ROUND TRIP TO THE PROVIDER, NOT A GUESS"
                        },
                        {
                            kind: "action",
                            fn: "vellyPrune",
                            name: "FREE THE DISK",
                            aka: "SPEICHER FREIGEBEN · PRUNE",
                            help: "Deletes the model sizes you do not use. The chosen size stays, and SMALL, which Velly falls back to while a game holds the graphics card. A deleted size downloads again when you pick it.",
                            sub: "DELETE UNUSED MODELS FROM THE DISK",
                            danger: true
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "HER MEMORY",
                    aka: "GEDÄCHTNIS · ERINNERUNGEN · LERNEN",
                    help: "What Velly remembers about you from one session to the next — and the button that erases it.",
                    sub: "WHAT SHE KEEPS, LEARNING, ERASE",
                    icon: "neurology",
                    items: [
                        {
                            kind: "info",
                            live: "vellyFacts",
                            name: "MEMORY",
                            aka: "GEDÄCHTNIS · FACTS",
                            help: "Shows what Velly has remembered across sessions (facts about you, what you like). You can erase it further down.",
                            sub: "WHAT SHE KEEPS FROM ONE SESSION TO THE NEXT"
                        },
                        {
                            kind: "toggle",
                            key: "velly.learn",
                            name: "LEARN",
                            aka: "LERNEN",
                            help: "At the end of every session she sums up what she learned about you and keeps it for next time.",
                            sub: "EVERY SESSION ENDS AS A FEW MEMORIES"
                        },
                        {
                            kind: "action",
                            fn: "vellyForgetFacts",
                            name: "ERASE MEMORY",
                            aka: "GEDÄCHTNIS LÖSCHEN · FORGET",
                            help: "Erases everything Velly remembered about you. This cannot be undone.",
                            sub: "FORGET EVERYTHING SHE REMEMBERED",
                            danger: true
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "NIGHT SHIFT",
                    aka: "NACHTSCHICHT · MONITOR AUS · BILDSCHIRM AUS · NACHTS ARBEITEN · WENN DER PC AN IST",
                    help: "While your screens are dark and the PC is on, Velly works: books for the shelf (BOOK STUDIO), live wallpapers for new favourites, her memory, the update count. She starts a few minutes after the last screen went dark — switched off, unplugged or in standby — and stops the moment one wakes, never while a game runs. In the morning a note says what she did.",
                    sub: "SHE WORKS WHILE THE SCREENS ARE DARK · STOPS WHEN ONE WAKES",
                    icon: "bedtime",
                    items: [
                        {
                            kind: "toggle",
                            key: "night.enabled",
                            name: "NIGHT SHIFT",
                            aka: "NACHTSCHICHT",
                            help: "Velly works while every screen is dark and the PC is on. Off: nothing runs at night.",
                            sub: "SHE WORKS WHILE THE SCREENS ARE DARK"
                        },
                        {
                            kind: "info",
                            live: "nightStatus",
                            name: "RIGHT NOW",
                            help: "What the night shift is doing this moment.",
                            sub: "WORKING, WAITING, OR OFF"
                        },
                        {
                            kind: "info",
                            live: "nightScreen",
                            name: "THE SCREENS",
                            help: "What Velvet sees: dark (switched off, unplugged, in standby) or lit. Some monitors stay connected when you press their power button — Velvet cannot see that one switch off. SCREEN OFF AFTER (below), SCREENS OFF NOW or „Velly, mach den Bildschirm aus“ put them into standby, and that it does see.",
                            sub: "DARK OR LIT, AND WHY"
                        },
                        {
                            kind: "info",
                            live: "nightLast",
                            name: "LAST NIGHT",
                            help: "What she did during the last night shift: books finished, books begun, live wallpapers, updates waiting.",
                            sub: "WHAT SHE DID"
                        },
                        {
                            kind: "slider",
                            key: "night.startAfter",
                            name: "START AFTER",
                            aka: "STARTVERZÖGERUNG",
                            help: "How long every screen must be dark before she starts — so switching the monitor off and on again for a moment starts nothing.",
                            sub: "MINUTES OF DARK SCREENS FIRST",
                            min: 1, max: 30, step: 1, fmt: "int", unit: " min"
                        },
                        {
                            kind: "choice",
                            key: "night.screenOff",
                            name: "SCREEN OFF AFTER",
                            aka: "BILDSCHIRM AUS NACH · STANDBY · DPMS · ENERGIE SPAREN",
                            help: "After this many minutes without a key or the mouse, the screens go to standby (a key or the mouse wakes them). Never while a fullscreen window is open (a game, a film) or something is playing. It is also what lets the night shift begin when your monitor stays connected after its power button.",
                            sub: "IDLE MINUTES → STANDBY · NEVER UNDER A GAME OR A FILM",
                            options: [
                                { value: 0, label: "NEVER" },
                                { value: 5, label: "5 MINUTES" },
                                { value: 10, label: "10 MINUTES" },
                                { value: 20, label: "20 MINUTES" },
                                { value: 30, label: "30 MINUTES" },
                                { value: 60, label: "1 HOUR" }
                            ]
                        },
                        {
                            kind: "toggle",
                            key: "night.books",
                            name: "BOOKS",
                            aka: "BÜCHER",
                            help: "She works on the books of the BOOK STUDIO until the shelf holds as many finished books as SHELF SIZE says.",
                            sub: "THE BOOK STUDIO'S SHELF"
                        },
                        {
                            kind: "toggle",
                            key: "night.livewalls",
                            name: "LIVE WALLPAPERS",
                            help: "Live wallpapers for favourites that have none yet.",
                            sub: "NEW FAVOURITES MOVE"
                        },
                        {
                            kind: "toggle",
                            key: "night.tidy",
                            name: "TIDY HER MEMORY",
                            aka: "GEDÄCHTNIS AUFRÄUMEN",
                            help: "She merges what she remembered twice and drops what is out of date.",
                            sub: "DUPLICATES MERGED, OLD NOTES GONE"
                        },
                        {
                            kind: "toggle",
                            key: "night.updates",
                            name: "COUNT THE UPDATES",
                            aka: "UPDATES ZÄHLEN",
                            help: "She counts the system updates waiting (checkupdates, read only — nothing is installed) and tells you in the morning.",
                            sub: "COUNTED, NEVER INSTALLED"
                        },
                        {
                            kind: "action",
                            fn: "nightStartNow",
                            name: "START NOW",
                            aka: "JETZT STARTEN",
                            help: "Runs the night shift right now, with the screen on — to try it, or to get a book done — until it is out of work or you press STOP.",
                            sub: "WITH THE SCREEN ON, UNTIL DONE"
                        },
                        {
                            kind: "action",
                            fn: "nightStop",
                            name: "STOP",
                            help: "Stops the night shift at once. Unfinished work goes on next time (every step is saved).",
                            sub: "NOTHING IS LOST"
                        },
                        {
                            kind: "action",
                            fn: "screenOffNow",
                            name: "SCREENS OFF NOW",
                            aka: "BILDSCHIRM JETZT AUS",
                            help: "Puts the screens into standby now. A key or the mouse wakes them; the night shift starts after START AFTER.",
                            sub: "STANDBY NOW · A KEY WAKES THEM"
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "BOOK STUDIO",
                    aka: "BUCHSTUDIO · BÜCHER · KDP · AMAZON · BILDERBUCH · MALBUCH · RÄTSELBUCH · GELD VERDIENEN · PASSIVES EINKOMMEN",
                    help: "Velly makes paperbacks for Amazon KDP: the print PDF, the full cover with spine, the listing (title, description, seven keywords, categories, price) and a checklist for the upload. Colouring books (mandalas) and puzzle books (sudoku, word search, mazes) need nothing to download; picture books need the picture engine (~7 GB, once). You look each book over and upload it yourself — KDP has no upload for programs, and the account is yours. Honest: a book sells when there is demand and its cover works; nobody can promise income.",
                    sub: "BOOKS FOR AMAZON KDP · YOU CHECK AND UPLOAD",
                    icon: "menu_book",
                    items: [
                        {
                            kind: "info",
                            live: "booksShelf",
                            name: "THE SHELF",
                            aka: "REGAL",
                            help: "Books ready to upload, books in the making, books already on KDP. Each one is a folder in Dokumente/Velly Bücher with review.html (every page, every field with a copy button), interior.pdf, cover.pdf, listing.txt and CHECKLIST.md.",
                            sub: "READY · IN THE MAKING · ON KDP"
                        },
                        {
                            kind: "info",
                            live: "booksNow",
                            name: "RIGHT NOW",
                            help: "What the studio is doing this moment.",
                            sub: "WHICH BOOK, WHICH STEP"
                        },
                        {
                            kind: "action",
                            fn: "booksOpenShelf",
                            name: "OPEN THE SHELF",
                            aka: "REGAL ÖFFNEN · ORDNER",
                            help: "Opens the folder with every book (Dokumente/Velly Bücher). Open a book's review.html to look it over.",
                            sub: "DOKUMENTE/VELLY BÜCHER"
                        },
                        {
                            kind: "action",
                            fn: "booksMakeNow",
                            name: "MAKE ONE NOW",
                            aka: "JETZT EIN BUCH MACHEN",
                            help: "Velly starts the next book now instead of tonight. A colouring or puzzle book is done in seconds (plus a minute for the listing); a picture book takes longer and needs the picture engine. A game pauses it.",
                            sub: "NOW INSTEAD OF TONIGHT"
                        },
                        {
                            kind: "text",
                            key: "books.author",
                            name: "AUTHOR NAME",
                            aka: "AUTORENNAME · PSEUDONYM · PEN NAME",
                            help: "The name on the cover and the title page — a pen name is fine on KDP, as long as it is not someone else's. A book already made gets a new name with its next cover (in the shelf: velvet-books redo ID --cover).",
                            sub: "ON THE COVER AND THE TITLE PAGE",
                            placeholder: "e.g. Lina Sommer",
                            examples: [],
                            empty: "EMPTY · „VELLY STUDIO“"
                        },
                        {
                            kind: "choice",
                            key: "books.lang",
                            name: "LANGUAGE",
                            aka: "SPRACHE",
                            help: "The books' language — titles, stories, rules, listings.",
                            sub: "GERMAN OR ENGLISH",
                            options: [
                                { value: "de", label: "DEUTSCH" },
                                { value: "en", label: "ENGLISH" }
                            ]
                        },
                        {
                            kind: "slider",
                            key: "books.maxWaiting",
                            name: "SHELF SIZE",
                            aka: "REGALGRÖSSE",
                            help: "How many finished books may wait for your upload before she pauses. KDP takes at most three new titles a day per account — and every book needs your look first.",
                            sub: "FINISHED BOOKS WAITING FOR YOU",
                            min: 1, max: 10, step: 1, fmt: "int", unit: " books"
                        },
                        {
                            kind: "toggle",
                            key: "books.coloring",
                            name: "COLOURING BOOKS",
                            aka: "MALBÜCHER · MANDALAS",
                            help: "Mandala colouring books (adults, children, seniors, flowers, geometry, hearts): 40–50 designs, single-sided, 8.5 × 11 in. Drawn by a program — nothing to download.",
                            sub: "MANDALAS · NOTHING TO DOWNLOAD"
                        },
                        {
                            kind: "toggle",
                            key: "books.puzzle",
                            name: "PUZZLE BOOKS",
                            aka: "RÄTSELBÜCHER · SUDOKU · SUCHSEL · LABYRINTHE",
                            help: "Sudoku (every one with exactly one solution), word searches and mazes, with all solutions — also in large print for seniors. Computed by a program — nothing to download.",
                            sub: "SUDOKU · WORD SEARCH · MAZES · WITH SOLUTIONS"
                        },
                        {
                            kind: "toggle",
                            key: "books.picture",
                            name: "PICTURE BOOKS",
                            aka: "BILDERBÜCHER · KINDERBÜCHER",
                            help: "Story picture books for ages 3–6: the local brain writes the story, an editor round checks and improves it (at least once, until 9 of 10), the picture engine paints 14 spreads and the cover. Needs the picture engine.",
                            sub: "STORY, EDITOR, PICTURES · NEEDS THE PICTURE ENGINE"
                        },
                        {
                            kind: "info",
                            live: "booksEngine",
                            name: "PICTURE ENGINE",
                            aka: "BILD-ENGINE · STABLE DIFFUSION · Z-IMAGE",
                            help: "stable-diffusion.cpp (Vulkan) with Z-Image-Turbo — Apache 2.0, so the pictures may be sold — the FLUX VAE, and Velly's Qwen3-4B as its text encoder (already on disk).",
                            sub: "FOR PICTURE BOOKS"
                        },
                        {
                            kind: "action",
                            fn: "booksInstallEngine",
                            name: "INSTALL THE PICTURE ENGINE",
                            aka: "BILD-ENGINE INSTALLIEREN",
                            help: "Opens a terminal that downloads it: first every file with its source and size, then the files (each model checked against its SHA-256). Ctrl+C stops it; it picks up the missing files next time.",
                            sub: "~7 GB · STABLE-DIFFUSION.CPP 37 MB + Z-IMAGE-TURBO 6.6 GB + VAE 335 MB"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "wallpaper.liveAuto",
                    name: "LIVE WALLPAPERS FOR FAVOURITES",
                    aka: "LIVE WALLPAPER · GIF · FAVORITEN",
                    help: "Her standing job: every wallpaper you star, she makes move — leaves, stars, mist, light, whatever suits the picture — a seamless loop and a GIF. All the knobs: WALLPAPER → LIVE WALLPAPERS.",
                    sub: "SHE MAKES EVERY FAVOURITE MOVE · KNOBS IN WALLPAPER → LIVE WALLPAPERS"
                }
            ]
        },
        {
            kind: "page",
            name: "AUDIO-REACTIVE",
            help: "The shell moves with the music that is actually playing: a waveform in the island, the bar's media entry pulsing, and the music drawn on the wallpaper. It reads real levels from cava.",
            sub: "THE SHELL MOVES WITH WHAT IS PLAYING",
            icon: "graphic_eq",
            items: [
                {
                    kind: "info",
                    name: "REAL LEVELS ONLY",
                    help: "Needs cava installed. Without it nothing here moves — there is no fake animation, because it would not show the real music.",
                    sub: "NEEDS CAVA — WITHOUT IT NOTHING MOVES, BECAUSE NOTHING WOULD BE TRUE"
                },
                {
                    kind: "toggle",
                    key: "services.audioReactive",
                    name: "AUDIO-REACTIVE DESKTOP",
                    help: "The master switch for every audio-reactive effect on this page. Off stops the level meter entirely (the lock's visualizer has its own switch).",
                    sub: "THE WHOLE IDEA, ONE SWITCH"
                },
                {
                    kind: "toggle",
                    key: "services.audioIsland",
                    name: "ISLAND WAVEFORM",
                    help: "Live frequency bands under the island's play controls, like a small equaliser display.",
                    sub: "LIVE BANDS UNDER THE TRANSPORT, LIKE AN EQ"
                },
                {
                    kind: "toggle",
                    key: "services.audioBar",
                    name: "BAR PULSE",
                    help: "The bar's now-playing entry breathes with the beat.",
                    sub: "THE NOW-PLAYING ENTRY BREATHES WITH THE MUSIC"
                },
                {
                    kind: "toggle",
                    key: "services.audioWave",
                    name: "WALLPAPER WAVE",
                    help: "Draws the music on the wallpaper itself, under every window. Its look, edge and height are set below.",
                    sub: "THE MUSIC ON THE PICTURE ITSELF · UNDER EVERY WINDOW"
                },
                {
                    kind: "choice",
                    key: "services.audioWaveStyle",
                    name: "WAVE LOOK",
                    help: "How the wallpaper music looks. HAIRLINE is one quiet line across the middle; WAVE is a smooth filled wave, BARS rounded bars and LINE a single stroke, each standing on the screen edge chosen below.",
                    sub: "A QUIET HAIRLINE, OR THE MUSIC ALONG A SCREEN EDGE",
                    options: [
                        {
                            value: "hairline",
                            label: "HAIRLINE · QUIET, IN THE MIDDLE"
                        },
                        {
                            value: "wave",
                            label: "WAVE · SMOOTH, FILLED"
                        },
                        {
                            value: "bars",
                            label: "BARS · ROUNDED"
                        },
                        {
                            value: "line",
                            label: "LINE · ONE THIN STROKE"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "services.audioWaveEdge",
                    name: "WAVE EDGE",
                    help: "Which screen edge the wave, bars or line stand on. They start where the desktop starts — under a pinned bar and inside the screen frame. Not used by HAIRLINE.",
                    sub: "WHICH SCREEN EDGE IT STANDS ON · NOT FOR THE HAIRLINE",
                    options: [
                        {
                            value: "bottom",
                            label: "BOTTOM"
                        },
                        {
                            value: "top",
                            label: "TOP"
                        },
                        {
                            value: "left",
                            label: "LEFT"
                        },
                        {
                            value: "right",
                            label: "RIGHT"
                        }
                    ]
                },
                {
                    kind: "slider",
                    key: "services.audioWaveReach",
                    name: "WAVE HEIGHT",
                    help: "How far the music may rise from the edge, as a share of the screen's height (or width, on the left or right edge).",
                    sub: "HOW FAR IT MAY RISE FROM THE EDGE · SHARE OF THE SCREEN",
                    min: 0.04,
                    max: 0.4,
                    step: 0.01,
                    fmt: "percent"
                },
                {
                    kind: "choice",
                    key: "services.audioWaveDensity",
                    name: "BAR DENSITY",
                    help: "How close the bars stand — FINE is dense and thin, WIDE is sparse. Only for the BARS look.",
                    sub: "FOR THE BARS LOOK · HOW CLOSE THEY STAND",
                    options: [
                        {
                            value: "fine",
                            label: "FINE"
                        },
                        {
                            value: "normal",
                            label: "NORMAL"
                        },
                        {
                            value: "wide",
                            label: "WIDE"
                        }
                    ]
                }
            ]
        },
        {
            kind: "page",
            name: "MINI DESKTOP",
            help: "The infinite canvas of your desktop: the monitor with your wallpaper, every window on it and far out around it, and a chip per desktop. With the Dynamic Island on it is the island's DESKTOP module — it opens right inside the island (Super+Shift+M or the bar's button open it there); with the island off it drops as a plate of its own. Click a window to go to it, drag it anywhere or onto a desktop chip, FIT / − / + / HOME or the wheel for the camera.",
            sub: "THE ISLAND'S DESKTOP MODULE  ·  THE INFINITE CANVAS",
            icon: "space_dashboard",
            items: [
                {
                    kind: "toggle",
                    key: "map.enabled",
                    name: "MINI DESKTOP",
                    help: "The mini desktop itself — top edge or Super+Shift+M. Off disables it everywhere.",
                    sub: "REACH FOR THE TOP EDGE, OR SUPER+SHIFT+M"
                },
                {
                    kind: "action",
                    fn: "openMap",
                    name: "OPEN IT",
                    help: "Opens the mini desktop now, as if you had reached for the top edge.",
                    sub: "SAME AS REACHING FOR THE TOP EDGE"
                },
                {
                    kind: "info",
                    name: "RIGHT NOW",
                    help: "What the mini desktop can see right now: how many windows and workspaces, and whether live previews work.",
                    sub: "WHAT THE MAP CAN SEE",
                    live: "deskStatus"
                },
                {
                    kind: "toggle",
                    key: "map.hoverEdge",
                    name: "OPEN ON HOVER",
                    help: "Touching the top edge opens it. Off: only the keyboard shortcut and the bar button open it.",
                    sub: "OFF MAKES IT KEYBOARD AND BAR ONLY"
                },
                {
                    kind: "slider",
                    key: "map.plateWidth",
                    name: "SIZE",
                    help: "How wide the map is, as a share of the screen. Its height follows your monitor's shape, so a workspace fills it exactly.",
                    sub: "SHARE OF THE SCREEN  ·  THE HEIGHT FOLLOWS YOUR MONITOR'S SHAPE",
                    min: 0.18, max: 0.7, step: 0.01, fmt: "percent"
                },
                {
                    kind: "slider",
                    key: "map.desktops",
                    name: "ROOM FOR",
                    help: "How many workspace slots the map keeps ready when you zoom out — so there is always an empty desktop to drop a window onto.",
                    sub: "HOW MANY DESKTOPS TO KEEP A SLOT FOR",
                    min: 1, max: 16, step: 1, fmt: "int", unit: "desktops"
                },
                {
                    kind: "toggle",
                    key: "map.previews",
                    name: "DESKTOP SNAPSHOT",
                    help: "Your wallpaper on the monitor in the map, so the canvas reads as your own desktop. Off: a plain monitor.",
                    sub: "THE WALLPAPER ON THE MONITOR"
                },
                {
                    kind: "toggle",
                    key: "map.showTitles",
                    name: "NAME ON HOVER",
                    help: "Shows the window's full title under the window you point at in the map.",
                    sub: "THE TITLE UNDER THE WINDOW YOU POINT AT"
                },
                {
                    kind: "toggle",
                    key: "map.showWorkspaceLabels",
                    name: "WORKSPACE LABELS",
                    help: "A small number in the corner of each workspace in the map.",
                    sub: "NUMBERS UNDER THE DESKTOPS"
                },
                {
                    kind: "toggle",
                    key: "map.clickFocuses",
                    name: "CLICK FOCUSES",
                    help: "A click on a window in the map takes you to it: the desktop pans until it sits centred, and the map stays open. Off: a click only closes the map.",
                    sub: "A CLICK ON A WINDOW TAKES YOU THERE"
                },
                {
                    kind: "toggle",
                    key: "map.dragFloats",
                    name: "DRAG FLOATS WINDOWS",
                    help: "Dragging a tiled window in the map makes it float so it can land exactly where you drop it — Hyprland cannot place a tiled window by pixel. Press F on it later to tile it again.",
                    sub: "DRAGGING A TILED WINDOW MEANS PUT IT THERE"
                }
            ]
        },
        {
            kind: "page",
            name: "PILL LAUNCHER",
            help: "The app launcher (Super+Space): type to find apps, do maths, run commands or find shell settings. Below: how it looks and moves, on every look.",
            sub: "TYPE TO RUN  ·  APPS · MATHS · COMMANDS",
            icon: "search",
            items: [
                {
                    kind: "toggle",
                    key: "launcher.enabled",
                    name: "PILL LAUNCHER",
                    help: "The launcher itself. Off disables Super+Space and the bar's launcher button.",
                    sub: "SUPER+SPACE — THE ORBITAL APP LAUNCHER"
                },
                {
                    kind: "action",
                    fn: "openLauncher",
                    name: "OPEN IT",
                    help: "Opens the launcher now.",
                    sub: "SUPER+SPACE, FROM HERE"
                },
                {
                    kind: "slider",
                    key: "launcher.maxShown",
                    name: "PLANETS SHOWN",
                    help: "How many results orbit at once.",
                    sub: "HOW MANY RESULTS ORBIT AT ONCE",
                    min: 3, max: 8, step: 1, fmt: "int", unit: "apps"
                },
                {
                    kind: "toggle",
                    key: "launcher.fuzzy",
                    name: "FUZZY MATCHING",
                    help: "Finds apps even with typos or letters out of order (\"frfx\" finds Firefox). Off only matches what you typed, in order.",
                    sub: "FORGIVES TYPOS AND OUT-OF-ORDER KEYS"
                },
                {
                    kind: "toggle",
                    key: "launcher.showIcons",
                    name: "APP ICONS",
                    help: "Shows each app's real icon in the launcher. Off leaves the icons out.",
                    sub: "THE PLANETS WEAR THEIR REAL ICONS"
                },
                {
                    kind: "toggle",
                    key: "launcher.useCalculator",
                    name: "CALCULATOR",
                    help: "Type a sum (like 2+2*3, or =7/3) and the answer appears as the first result.",
                    sub: "= 2+2 ANSWERS INLINE"
                },
                {
                    kind: "toggle",
                    key: "launcher.searchSettings",
                    name: "SEARCH SETTINGS",
                    help: "Shell settings show up in the results too — type \"blur\" and jump straight to that row.",
                    sub: "SHELL SETTINGS APPEAR IN THE RESULTS"
                },
                {
                    kind: "choice",
                    key: "launcher.actionPrefix",
                    name: "COMMAND PREFIX",
                    help: "Starting a query with this character runs it as a shell command instead of searching (e.g. \">htop\").",
                    sub: "THE CHARACTER THAT TURNS A QUERY INTO A SHELL COMMAND",
                    options: [
                        { value: ">", label: ">" },
                        { value: ":", label: ":" },
                        { value: "!", label: "!" }
                    ]
                },
                {
                    kind: "slider",
                    key: "launcher.width",
                    name: "SIZE",
                    help: "How wide the launcher opens, in pixels.",
                    sub: "HOW WIDE THE LAUNCHER OPENS",
                    min: 480, max: 1100, step: 20, fmt: "int", unit: "px"
                }
            ].concat(root.launcherRows)
        },
        {
            kind: "page",
            name: "WALLPAPER CHANGER",
            help: "How wallpapers are chosen and drawn: the Super+W wheel, automatic rotation and Velvet's own renderer.",
            sub: "THE WHEEL  ·  ROTATION  ·  THE BUILT-IN RENDERER",
            icon: "image",
            items: [
                {
                    kind: "toggle",
                    key: "wallpaper.wheel",
                    name: "THE WHEEL",
                    help: "The coverflow of your wallpaper folder on Super+W. Off disables the shortcut.",
                    sub: "SUPER+W — YOUR LIBRARY ON A RING"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.deskMenu",
                    name: "DESKTOP RIGHT-CLICK MENU",
                    help: "Right-click on a free spot of the desktop: edit widgets, add one right there, change the wallpaper, save its look, jump to any desktop or the infinite canvas. Off leaves the bare desktop alone.",
                    sub: "RIGHT-CLICK THE BARE DESKTOP TO EDIT IT"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.drawTerminal",
                    name: "DRAW A TERMINAL",
                    aka: "RIGHT DRAG · DRAG A TERMINAL · OPEN KITTY HERE",
                    help: "Hold the right mouse button on a free spot of the desktop and pull a frame: a terminal opens in it, exactly there and that big. A plain right-click still opens the desktop menu.",
                    sub: "RIGHT-DRAG ON THE DESKTOP: A TERMINAL IN THAT FRAME"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.living",
                    name: "LIVING DESKTOP",
                    help: "Widgets and living light on the wallpaper (clock, weather, music …). All of its knobs are in the WALLPAPER tab.",
                    sub: "WIDGETS AND LIVING LIGHT — KNOBS IN THE WALLPAPER TAB"
                },
                {
                    kind: "action",
                    fn: "openWheel",
                    name: "OPEN THE WHEEL",
                    help: "Opens the wallpaper wheel now.",
                    sub: "SEE IT RIGHT NOW"
                },
                {
                    kind: "choice",
                    key: "wallpaper.renderer",
                    name: "RENDERER",
                    help: "BUILT-IN draws the wallpaper with Velvet itself — no extra program, it comes back after a reboot, and the living desktop (widgets, light, ripples) needs it. SWWW / HYPRPAPER hands the image to that program instead.",
                    sub: "BUILT-IN NEEDS NO DAEMON AND SURVIVES A REBOOT",
                    options: [
                        { value: "builtin", label: "BUILT-IN" },
                        { value: "external", label: "SWWW / HYPRPAPER" }
                    ]
                },
                {
                    kind: "choice",
                    key: "wallpaper.fillMode",
                    name: "FIT",
                    help: "How the picture covers the screen. FILL crops it to fill the screen, CONTAIN shows it whole with bars, STRETCH distorts it to fit.",
                    sub: "HOW THE IMAGE COVERS THE SCREEN",
                    options: [
                        { value: "fill", label: "FILL" },
                        { value: "fit", label: "CONTAIN" },
                        { value: "stretch", label: "STRETCH" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "wallpaper.transition",
                    name: "TRANSITION",
                    help: "Crossfades from the old wallpaper to the new one instead of cutting.",
                    sub: "FADE BETWEEN WALLPAPERS"
                },
                {
                    kind: "slider",
                    key: "wallpaper.fadeDuration",
                    name: "FADE TIME",
                    help: "How long that crossfade takes, in milliseconds.",
                    sub: "HOW LONG THE CROSSFADE TAKES",
                    min: 100, max: 3000, step: 50, fmt: "int", unit: "ms"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.kenBurns",
                    name: "KEN BURNS",
                    help: "A very slow zoom and drift so the desktop feels alive. It pauses while the lock, settings or wheel are open.",
                    sub: "THE WALLPAPER BREATHES, SLOWLY"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.vignette",
                    name: "VIGNETTE",
                    help: "A soft dark gradient across the image so text and widgets read better.",
                    sub: "SOFT GRADIENT ACROSS THE IMAGE"
                },
                {
                    kind: "slider",
                    key: "wallpaper.rotateMinutes",
                    name: "AUTO-ROTATE",
                    help: "Switches to the next wallpaper every N minutes. 0 turns it off.",
                    sub: "ADVANCE TO THE NEXT WALLPAPER  ·  0 = OFF",
                    min: 0, max: 240, step: 5, fmt: "int", unit: "min"
                }
            ]
        },
        {
            kind: "page",
            name: "SCRATCHPAD",
            aka: "NOTIZEN · NOTIZBLOCK · ZEICHNEN · MALEN · SKIZZE · WHITEBOARD · SCRATCH PAD",
            help: "An endless sheet in the Dynamic Island to keep things on: write, draw, sticky notes, lines and arrows, boxes and circles, pasted pictures — on pages, kept for good. SUPER+O opens it from anywhere (change the key in the key menu), or pick its tab in the island at the edge of the screen. F1 in the pad shows every key.",
            sub: "SUPER+O · ITS SIZE · ITS PAPER · ITS PEN",
            icon: "edit_note",
            items: [
                {
                    kind: "toggle",
                    key: "map.islandScratch",
                    name: "IN THE ISLAND",
                    help: "The scratchpad as a module of the Dynamic Island (and SUPER+O). Off: no pad — what is on it stays saved.",
                    sub: "A TAB OF THE ISLAND · SUPER+O"
                },
                {
                    kind: "action",
                    name: "OPEN IT",
                    help: "Opens the pad in the island on this screen — what SUPER+O does.",
                    sub: "WHAT SUPER+O DOES",
                    fn: "scratchOpen"
                },
                {
                    kind: "slider",
                    key: "scratch.width",
                    name: "WIDTH",
                    help: "How wide the pad opens, in pixels — never wider than the screen leaves round it.",
                    sub: "HOW WIDE THE PAD OPENS",
                    min: 620, max: 1800, step: 10, fmt: "int", unit: "px"
                },
                {
                    kind: "slider",
                    key: "scratch.height",
                    name: "HEIGHT",
                    help: "How tall the pad opens, in pixels — never taller than the screen leaves round it.",
                    sub: "HOW TALL THE PAD OPENS",
                    min: 340, max: 1300, step: 10, fmt: "int", unit: "px"
                },
                {
                    kind: "choice",
                    key: "scratch.paper",
                    name: "PAPER",
                    help: "The pattern of the sheet: DOTS, a GRID, LINES like a notebook, or PLAIN. It moves and scales with the sheet.",
                    sub: "DOTS · GRID · LINES · PLAIN",
                    options: [
                        { value: "dots", label: "DOTS" },
                        { value: "grid", label: "GRID" },
                        { value: "lines", label: "LINES" },
                        { value: "plain", label: "PLAIN" }
                    ]
                },
                {
                    kind: "choice",
                    key: "scratch.tone",
                    name: "SHEET",
                    help: "The sheet's colour: the ISLAND's own ground (it follows the look), light PAPER, or dark INK. The first pen is always the colour that reads on it.",
                    sub: "THE ISLAND'S · PAPER · INK",
                    options: [
                        { value: "island", label: "ISLAND" },
                        { value: "paper", label: "PAPER" },
                        { value: "ink", label: "INK" }
                    ]
                },
                {
                    kind: "slider",
                    key: "scratch.pen",
                    name: "PEN SIZE",
                    help: "How thick the pen starts (the marker is four times that). [ and ] change it in the pad.",
                    sub: "[ ] CHANGE IT IN THE PAD",
                    min: 1, max: 24, step: 1, fmt: "int", unit: "px"
                },
                {
                    kind: "slider",
                    key: "scratch.smooth",
                    name: "SMOOTH THE LINES",
                    help: "How much a hand-drawn line is evened out when you let go. 0 keeps it exactly as drawn.",
                    sub: "0 = EXACTLY AS DRAWN",
                    min: 0, max: 1, step: 0.05, fmt: "percent"
                },
                {
                    kind: "choice",
                    key: "scratch.toolbar",
                    name: "TOOLBAR",
                    help: "Where the tools sit: at the TOP of the pad or at the BOTTOM (the pages swap to the other side).",
                    sub: "TOP · BOTTOM",
                    options: [
                        { value: "top", label: "TOP" },
                        { value: "bottom", label: "BOTTOM" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "scratch.labels",
                    name: "TOOL NAMES",
                    help: "Writes each tool's name under its icon.",
                    sub: "A WORD UNDER EVERY ICON"
                }
            ]
        },
        {
            kind: "page",
            name: "NOTIFICATIONS",
            help: "The desktop notifications: the popups that rise in a corner and the history in the notification centre.",
            sub: "POPUPS AND THE CENTRE",
            icon: "notifications",
            items: [
                {
                    kind: "toggle",
                    key: "notifs.enabled",
                    name: "NOTIFICATIONS",
                    help: "Velvet as your notification daemon. Off: no popups and no history (another daemon could take over).",
                    sub: "THE WHOLE SYSTEM, POPUPS AND CENTRE"
                },
                {
                    kind: "toggle",
                    key: "notifs.doNotDisturb",
                    name: "DO NOT DISTURB",
                    help: "Notifications are still collected in the centre, but no popup appears.",
                    sub: "COLLECT QUIETLY — NO POPUPS"
                },
                {
                    kind: "toggle",
                    key: "notifs.expanded",
                    name: "EXPANDED BODIES",
                    help: "Popups show the full message instead of one line.",
                    sub: "SHOW THE FULL TEXT, NOT ONE LINE"
                },
                {
                    kind: "choice",
                    key: "notifs.position",
                    name: "POSITION",
                    help: "Where the popups rise from: a corner, or the middle of the top or bottom edge.",
                    sub: "WHICH CORNER THE POPUPS RISE FROM",
                    options: [
                        { value: "top-right", label: "TOP RIGHT" },
                        { value: "top-left", label: "TOP LEFT" },
                        { value: "bottom-right", label: "BOTTOM RIGHT" },
                        { value: "bottom-left", label: "BOTTOM LEFT" },
                        { value: "top-centre", label: "TOP MIDDLE" },
                        { value: "bottom-centre", label: "BOTTOM MIDDLE" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "notifs.inFrame",
                    name: "IN THE FRAME",
                    aka: "BENACHRICHTIGUNGEN IM RAHMEN · NOTIFICATIONS IN THE FRAME · RAHMEN",
                    help: "The popups come out of the SCREEN FRAME itself: a tab of the frame's own colour grows from the corner (or the middle of the edge) you chose under POSITION, its sides flowing into the frame in soft curves, and the cards sit in it in the frame's ink — frame, bar, island and notifications as one surface. The centre (SUPER+N) comes out of the frame too, as a drawer (THE CENTRE TOO). Needs TASKBAR → SCREEN FRAME.",
                    sub: "A TAB OF THE FRAME THAT THE CARDS SIT IN",
                    when: { key: "bar.frame", is: true }
                },
                {
                    kind: "toggle",
                    key: "notifs.centreInFrame",
                    name: "THE CENTRE TOO",
                    aka: "NOTIFICATION CENTRE IN THE FRAME · CENTRE · SUPER+N · ZENTRALE IM RAHMEN",
                    help: "The notification centre (SUPER+N, or a click on the clock) slides out of the frame's side as a drawer of the frame's own colour, its ends flowing into the frame, instead of a card floating beside it. Off: the card, as before.",
                    sub: "SUPER+N AS A DRAWER OF THE FRAME",
                    when: { key: "notifs.inFrame", is: true }
                },
                {
                    kind: "slider",
                    key: "notifs.width",
                    name: "WIDTH",
                    help: "How wide each popup is, in pixels.",
                    sub: "HOW WIDE EACH POPUP IS",
                    min: 260, max: 720, step: 10, fmt: "int", unit: "px"
                },
                {
                    kind: "slider",
                    key: "notifs.timeout",
                    name: "LINGER",
                    help: "How long a popup stays before it slides away, in milliseconds.",
                    sub: "HOW LONG A POPUP STAYS",
                    min: 1000, max: 15000, step: 100, fmt: "int", unit: "ms"
                },
                {
                    kind: "slider",
                    key: "notifs.maxPopups",
                    name: "MAX POPUPS",
                    help: "How many popups are on screen at once.",
                    sub: "HOW MANY STACK AT ONCE",
                    min: 1, max: 8, step: 1, fmt: "int", unit: "popups"
                }
            ]
        },
        {
            kind: "page",
            name: "OSD",
            help: "The small on-screen bar that appears when you change volume or brightness.",
            sub: "VOLUME AND BRIGHTNESS FEEDBACK",
            icon: "volume_up",
            items: [
                {
                    kind: "toggle",
                    key: "osd.enabled",
                    name: "OSD",
                    help: "Shows the OSD when volume or brightness changes.",
                    sub: "THE ON-SCREEN FEEDBACK FOR VOLUME AND BRIGHTNESS"
                },
                {
                    kind: "choice",
                    key: "osd.position",
                    name: "POSITION",
                    help: "Where the OSD appears on screen.",
                    sub: "WHERE IT APPEARS",
                    options: [
                        { value: "bottom", label: "BOTTOM" },
                        { value: "top", label: "TOP" },
                        { value: "centre", label: "CENTRE" }
                    ]
                },
                {
                    kind: "choice",
                    key: "osd.side",
                    name: "SIDE",
                    help: "Whether the volume and brightness pop-up sits in the middle of its edge or towards the left or right.",
                    sub: "LEFT, MIDDLE OR RIGHT",
                    options: [
                        { value: "left", label: "LEFT" },
                        { value: "centre", label: "MIDDLE" },
                        { value: "right", label: "RIGHT" }
                    ]
                },
                {
                    kind: "slider",
                    key: "osd.timeout",
                    name: "LINGER",
                    help: "How long it stays after the last change, in milliseconds.",
                    sub: "HOW LONG IT STAYS",
                    min: 600, max: 4000, step: 100, fmt: "int", unit: "ms"
                }
            ]
        },
        {
            kind: "page",
            name: "LYRICS",
            help: "Timed lyrics for whatever is playing, fetched from lrclib.net (free, no account) and drawn on the desktop.",
            sub: "THE SONG, ON THE DESKTOP",
            icon: "lyrics",
            items: [
                {
                    kind: "toggle",
                    key: "lyrics.enabled",
                    name: "LYRICS",
                    help: "Fetches and shows the lyrics (also Super+Shift+L). The lock's lyric line works even with this off.",
                    sub: "WORDS TO WHAT IS PLAYING, ON THE DESKTOP"
                },
                {
                    kind: "toggle",
                    key: "lyrics.desktop",
                    name: "ON THE DESKTOP",
                    help: "Draws them on the desktop — over the wallpaper, under every window, never in your way.",
                    sub: "DRAW IT OVER THE WALLPAPER, UNDER THE WINDOWS"
                },
                {
                    kind: "choice",
                    key: "lyrics.position",
                    name: "POSITION",
                    help: "Where the lyrics sit on screen: along the bottom, the top, or in the centre. The STACK card sits in the right corner of that band.",
                    sub: "WHERE THE LINE SITS",
                    options: [
                        { value: "bottom", label: "BOTTOM" },
                        { value: "top", label: "TOP" },
                        { value: "centre", label: "CENTRE" }
                    ]
                },
                {
                    kind: "choice",
                    key: "lyrics.side",
                    name: "SIDE",
                    help: "Whether the lyrics sit in the middle or towards the left or right. MIDDLE keeps the STACK card where it always was.",
                    sub: "LEFT, MIDDLE OR RIGHT",
                    options: [
                        { value: "left", label: "LEFT" },
                        { value: "centre", label: "MIDDLE" },
                        { value: "right", label: "RIGHT" }
                    ]
                },
                {
                    kind: "choice",
                    key: "lyrics.mode",
                    name: "MODE",
                    help: "WORD shows one word at a time, huge; LINE shows the whole line and fills it in as it is sung; STACK shows the line before, the current line and the next one on a card over the blurred album cover.",
                    sub: "ONE WORD AT A TIME, THE WHOLE LINE, OR THREE LINES ON A CARD",
                    options: [
                        { value: "word", label: "WORD" },
                        { value: "line", label: "LINE" },
                        { value: "stack", label: "STACK · THREE LINES ON A CARD" }
                    ]
                },
                {
                    kind: "slider",
                    key: "lyrics.size",
                    name: "SIZE",
                    help: "How big the lyrics are.",
                    sub: "HOW BIG THE TYPE IS",
                    min: 0.5, max: 2.2, step: 0.05, fmt: "float1", unit: "×"
                },
                {
                    kind: "toggle",
                    key: "lyrics.blocky",
                    name: "BLOCKY TYPE",
                    help: "Monospace slab letters instead of the display face, like the inspo. In STACK mode it switches the card to the monospace font.",
                    sub: "PIXEL-SLAB LETTERS, LIKE THE INSPO"
                },
                {
                    kind: "toggle",
                    key: "lyrics.tile",
                    name: "TILE",
                    help: "Draws the lyrics on a bordered panel instead of loose on the desktop (WORD and LINE modes).",
                    sub: "DRAW IT AS A PANEL, NOT LOOSE ON THE DESKTOP"
                },
                {
                    kind: "slider",
                    key: "lyrics.width",
                    name: "TILE WIDTH",
                    help: "How wide that panel is, as a share of the screen.",
                    sub: "SHARE OF THE SCREEN, TILE MODE",
                    min: 0.2, max: 1.0, step: 0.02, fmt: "percent"
                },
                {
                    kind: "toggle",
                    key: "lyrics.shadow",
                    name: "SHADOW",
                    help: "A hard, offset shadow behind the letters that makes them look extruded (WORD and LINE modes).",
                    sub: "THE EXTRUDED DROP BEHIND THE TYPE"
                },
                {
                    kind: "toggle",
                    key: "lyrics.showProgress",
                    name: "PROGRESS",
                    help: "A thin progress line with the artist, the title and the time under the lyrics (WORD and LINE modes).",
                    sub: "A BAR UNDER THE LINE"
                },
                {
                    kind: "toggle",
                    key: "lyrics.romanise",
                    name: "ROMANISE",
                    help: "Writes Japanese kana and Korean hangul in Latin letters so you can sing along. Kanji and Chinese characters need a dictionary and stay as they are; other languages are untouched.",
                    sub: "LATIN LETTERS FOR CJK LYRICS"
                },
                {
                    kind: "slider",
                    key: "lyrics.offsetMs",
                    name: "TIMING NUDGE",
                    help: "Shifts the lyrics against the music, in milliseconds. Positive shows each line later, negative earlier — use it when the words run ahead of or behind the song.",
                    sub: "SHIFT THE WORDS AGAINST THE MUSIC",
                    min: -3000, max: 3000, step: 50, fmt: "int", unit: "ms"
                }
            ]
        }
    ]

    // ================================================================== VIBE
    readonly property var vibe: [
        {
            kind: "choice",
            key: "appearance.skin",
            name: "SETTINGS LAYOUT",
            help: "How this settings window itself is built — not just dressed. PERSONA is the house: big cards, the category rail on the left. CONSOLE is a terminal, ARCADE a game's level select, HUD a sci-fi panel, LEDGER a newspaper, GLASS floating panes, TOME a book, POSTER stacked blocks, CLEAN a quiet single column, VINDOWS a window of the edition you pick below. Each comes with the matching vibe on the LOOKS tab.",
            sub: "PERSONA · CONSOLE · ARCADE · HUD · LEDGER · GLASS · TOME · POSTER · CLEAN · VINDOWS",
            options: [
                { value: "persona", label: "PERSONA · THE HOUSE" },
                { value: "console", label: "CONSOLE · A TERMINAL" },
                { value: "arcade", label: "ARCADE · A GAME MENU" },
                { value: "hud", label: "HUD · A SCI-FI PANEL" },
                { value: "ledger", label: "LEDGER · A NEWSPAPER" },
                { value: "glass", label: "GLASS · FLOATING PANES" },
                { value: "tome", label: "TOME · A BOOK" },
                { value: "poster", label: "POSTER · STACKED BLOCKS" },
                { value: "clean", label: "CLEAN · A QUIET COLUMN" },
                { value: "win", label: "VINDOWS · YOUR EDITION" }
            ]
        },
        {
            kind: "choice",
            key: "appearance.winVersion",
            name: "VINDOWS EDITION",
            aka: "WINDOWS VERSION · WINDOWS EDITION",
            help: "Which edition the VINDOWS look wears — Velvet's homage to the classic desktops. 95 is grey bevelled boxes and a navy title bar; XP a blue title bar, round buttons and a green Start; 7 is glass with a glossy orb; 10 is flat and sharp; 11 is soft rounded cards. Picking one while the VINDOWS look is on turns the whole shell — settings, taskbar, windows, sounds — into that edition. Otherwise it is remembered for the next time you put the VINDOWS look on.",
            sub: "95 · XP · 7 · 10 · 11 — THE WHOLE SHELL FOLLOWS",
            options: [
                { value: "95", label: "VINDOWS 95 · GREY AND BEVELLED" },
                { value: "xp", label: "VINDOWS XP · BLUE AND GREEN" },
                { value: "7", label: "VINDOWS 7 · GLASS AND SHINE" },
                { value: "10", label: "VINDOWS 10 · FLAT AND SHARP" },
                { value: "11", label: "VINDOWS 11 · SOFT AND ROUNDED" }
            ]
        },
        {
            kind: "choice",
            key: "appearance.shape",
            name: "CARD SHAPE",
            help: "The outline of every card, chip, tab and button. SLASH is the house tilt; ROUND and PILL are soft; SQUARE is a plain box; NOTCH cuts two corners like a game HUD; BRACKET marks the four corners only; PIXEL steps them like a sprite; BEVEL raises them like a button in an old window system.",
            sub: "SLASH · ROUND · PILL · SQUARE · NOTCH · BRACKET · PIXEL · BEVEL",
            options: [
                { value: "slash", label: "SLASH" },
                { value: "round", label: "ROUND" },
                { value: "pill", label: "PILL" },
                { value: "square", label: "SQUARE" },
                { value: "notch", label: "NOTCH" },
                { value: "bracket", label: "BRACKET" },
                { value: "pixel", label: "PIXEL" },
                { value: "bevel", label: "BEVEL" }
            ]
        },
        {
            kind: "slider",
            key: "appearance.outline",
            name: "OUTLINE",
            help: "A line drawn round every card, in px. 0 is none; 1 is a hairline; 3 is a comic panel.",
            sub: "THE LINE ROUND EVERY CARD",
            min: 0, max: 5, step: 0.5, fmt: "float1", unit: "px"
        },
        {
            kind: "choice",
            key: "appearance.edge",
            name: "OUTLINE COLOUR",
            help: "What the outline is drawn in. AUTO follows the ground, INK is the text colour, ACCENT the accent, BLACK is near-black on any ground, HAIRLINE is a faint line that hardly shows.",
            sub: "AUTO · INK · ACCENT · BLACK · HAIRLINE",
            options: [
                { value: "auto", label: "AUTO" },
                { value: "ink", label: "INK" },
                { value: "accent", label: "ACCENT" },
                { value: "black", label: "BLACK" },
                { value: "soft", label: "HAIRLINE" }
            ]
        },
        {
            kind: "choice",
            key: "appearance.shadow",
            name: "SHADOW",
            help: "What a card casts. HARD is a solid offset block (arcade, poster); SOFT is a blurred drop; GLOW lights the edge in the accent (neon).",
            sub: "NONE · SOFT · HARD BLOCK · GLOW · NEUMORPHIC · CLAY",
            options: [
                { value: "none", label: "NONE" },
                { value: "soft", label: "SOFT" },
                { value: "hard", label: "HARD" },
                { value: "glow", label: "GLOW" },
                { value: "neu", label: "NEUMORPHIC" },
                { value: "clay", label: "CLAY" }
            ]
        },
        {
            kind: "slider",
            key: "appearance.shadowSize",
            name: "SHADOW SIZE",
            help: "How far the shadow reaches, in px: the offset of a hard block, the blur of a soft shadow or the spread of a glow.",
            sub: "HOW FAR IT REACHES",
            min: 0, max: 20, step: 1, fmt: "int", unit: "px"
        },
        {
            kind: "choice",
            key: "appearance.ground",
            name: "GROUND",
            help: "DARK is the house: light text on dark panels. LIGHT turns the whole palette over — a printed page, dark ink on paper.",
            sub: "DARK PANELS OR A PAPER PAGE",
            options: [
                { value: "dark", label: "DARK" },
                { value: "light", label: "LIGHT" }
            ]
        },
        {
            kind: "choice",
            key: "appearance.groundColour",
            name: "GROUND COLOUR",
            help: "The hue every panel's grey is made of. AUTO takes the accent's, so the panels follow the wallpaper; the others fix it — navy panels under a yellow accent, cream paper under a red one.",
            sub: "WHAT THE GREYS ARE TINTED WITH",
            options: [
                { value: "auto", label: "FOLLOW THE ACCENT" },
                { value: "#000000", label: "BLACK" },
                { value: "#2a2f9e", label: "NAVY" },
                { value: "#0a1830", label: "MIDNIGHT" },
                { value: "#00ff55", label: "PHOSPHOR" },
                { value: "#5a3a1c", label: "BROWN" },
                { value: "#5a6a9a", label: "SLATE" },
                { value: "#6b1d3a", label: "WINE" },
                { value: "#1d5a3a", label: "FOREST" },
                { value: "#f0e4c8", label: "CREAM" },
                { value: "#ffe14d", label: "YELLOW" },
                { value: "#cfe6ff", label: "SKY" }
            ]
        },
        {
            kind: "choice",
            key: "appearance.typeStyle",
            name: "TYPE",
            help: "The voice of all text. PERSONA is heavy italic; SOFT is round and upright; MONO is a terminal; SERIF is a printed page; BLOCK is a poster; ARCADE is a pixel game; TECH is a wide, light HUD; CLEAN is a calm neutral sans; VINDOWS is the face of the Vindows edition you chose.",
            sub: "PERSONA · SOFT · MONO · SERIF · BLOCK · ARCADE · TECH · CLEAN · VINDOWS",
            options: [
                { value: "persona", label: "PERSONA" },
                { value: "soft", label: "SOFT" },
                { value: "mono", label: "MONO" },
                { value: "serif", label: "SERIF" },
                { value: "block", label: "BLOCK" },
                { value: "arcade", label: "ARCADE" },
                { value: "tech", label: "TECH" },
                { value: "clean", label: "CLEAN" },
                { value: "win", label: "VINDOWS" }
            ]
        },
        {
            kind: "choice",
            key: "appearance.caps",
            name: "CASE",
            help: "UPPER shows text as written (mostly capitals). LOWER turns every letter lowercase — the terminal's voice.",
            sub: "CAPITALS OR LOWERCASE",
            options: [
                { value: "upper", label: "AS WRITTEN" },
                { value: "lower", label: "LOWERCASE" }
            ]
        },
        {
            kind: "choice",
            key: "appearance.motion",
            name: "MOTION",
            help: "How things move. PUNCHY is the house: fast in, hard stop. SMOOTH glides; BOUNCY overshoots; CRISP is short and exact.",
            sub: "PUNCHY · SMOOTH · BOUNCY · CRISP",
            options: [
                { value: "punchy", label: "PUNCHY" },
                { value: "smooth", label: "SMOOTH" },
                { value: "bouncy", label: "BOUNCY" },
                { value: "crisp", label: "CRISP" }
            ]
        },
        {
            kind: "choice",
            key: "appearance.backdrop",
            name: "BACKDROP",
            help: "The pattern under the settings, the launcher and the home screen. PERSONA is the speed lines and print dots; the others are quieter.",
            sub: "WHAT SITS BEHIND THE PANELS",
            options: [
                { value: "persona", label: "SPEED LINES" },
                { value: "plain", label: "PLAIN" },
                { value: "grid", label: "GRID" },
                { value: "dots", label: "DOTS" },
                { value: "checker", label: "CHECKER" },
                { value: "ruled", label: "RULED PAPER" },
                { value: "vignette", label: "VIGNETTE" }
            ]
        },
        {
            kind: "slider",
            key: "appearance.scanlines",
            name: "SCANLINES",
            help: "CRT lines laid over the settings. 0 is off.",
            sub: "OLD-MONITOR LINES",
            min: 0, max: 1, step: 0.05, fmt: "percent"
        },
        {
            kind: "choice",
            key: "sfx.pack",
            name: "SOUNDS",
            help: "The sound set of every click and whoosh. VELVET is the house; the others come with the matching look.",
            sub: "THE CLICKS",
            options: [
                { value: "velvet", label: "VELVET" },
                { value: "arcade", label: "ARCADE" },
                { value: "cyber", label: "CYBER" },
                { value: "terminal", label: "TERMINAL" },
                { value: "paper", label: "PAPER" },
                { value: "glass", label: "GLASS" },
                { value: "rpg", label: "RPG" },
                { value: "brutal", label: "BRUTAL" },
                { value: "clean", label: "CLEAN" },
                { value: "windows", label: "VINDOWS" }
            ]
        }
    ]

    // ================================================================ VISUALS
    // The rows of VISUALS under its two pages (THIS LOOK and VIBE). THIS LOOK
    // picks some of them by key, so they are listed apart from `visuals`.
    readonly property var visualRows: [
        {
            kind: "choice",
            key: "appearance.accentSource",
            name: "ACCENT SOURCE",
            help: "Where the shell's colour comes from. WALLPAPER picks the accent out of the current wallpaper and changes with it; MANUAL uses the colour you set in ACCENT COLOUR.",
            sub: "WHERE THE SHELL GETS ITS COLOUR",
            options: [
                {
                    value: "wallpaper",
                    label: "WALLPAPER"
                },
                {
                    value: "manual",
                    label: "MANUAL"
                }
            ]
        },
        {
            kind: "colour",
            key: "appearance.accentColour",
            name: "ACCENT COLOUR",
            help: "Your own accent colour. Pressing Enter on this row switches the source to MANUAL; ← → then turn the hue, or click the strip.",
            sub: "USED WHEN THE SOURCE IS MANUAL"
        },
        {
            kind: "slider",
            key: "appearance.accentSaturation",
            name: "COLOUR STRENGTH",
            help: "How strong the colour taken from the wallpaper may be. 100% is what the picture gives; lower drifts towards grey, higher makes it louder. Has no effect on a MANUAL accent.",
            sub: "HOW LOUD THE WALLPAPER IS ALLOWED TO BE",
            min: 0.2,
            max: 1.3,
            step: 0.02,
            fmt: "float2",
            unit: "×"
        },
        {
            kind: "slider",
            key: "appearance.surfaceLift",
            name: "BRIGHTNESS FLOOR",
            help: "Lifts the darkest greys of every panel so nothing is pure black. Higher reads softer at night.",
            sub: "RAISES THE DARK END — LESS PURE BLACK",
            min: 0,
            max: 0.16,
            step: 0.005,
            fmt: "percent"
        },
        {
            kind: "slider",
            key: "appearance.surfaceTint",
            name: "TINT",
            help: "How much of the accent's hue bleeds into the greys of the panels. 0 is neutral grey; higher tints every surface with the accent.",
            sub: "HOW MUCH ACCENT BLEEDS INTO THE GREYS",
            min: 0,
            max: 0.45,
            step: 0.01,
            fmt: "percent"
        },
        {
            kind: "toggle",
            key: "appearance.contrastGuard",
            name: "READABILITY GUARD",
            help: "Measures every label against its background and brightens or darkens it until it passes WCAG AA, so no wallpaper can make the shell unreadable. Turn off only if you want the raw palette.",
            sub: "FORCE EVERY LABEL PAST WCAG AA AGAINST ITS BACKGROUND"
        },
        {
            kind: "choice",
            key: "appearance.density",
            name: "ROW SIZE",
            help: "How much room each row in these settings gets. COMPACT fits more on screen, SPACIOUS is easier to read and click.",
            sub: "HOW MUCH ROOM EACH SETTING GETS",
            options: [
                {
                    value: "compact",
                    label: "COMPACT"
                },
                {
                    value: "comfortable",
                    label: "COMFORTABLE"
                },
                {
                    value: "spacious",
                    label: "SPACIOUS"
                }
            ]
        },
        {
            kind: "slider",
            key: "appearance.transparency",
            name: "TRANSPARENCY",
            help: "How see-through the notification centre's panel is. (The other panels have their own opacity settings — the bar under TASKBAR, the island under DYNAMIC ISLAND.)",
            sub: "HOW MUCH OF THE DESKTOP SHOWS THROUGH",
            min: 0.3,
            max: 1.0,
            step: 0.01,
            fmt: "percent"
        },
        {
            kind: "slider",
            key: "appearance.roundingScale",
            name: "CORNER ROUNDING",
            help: "Multiplies every corner radius in the shell. 0 is square, 200% is very round.",
            sub: "GLOBAL RADIUS MULTIPLIER",
            min: 0,
            max: 2,
            step: 0.05,
            fmt: "float2",
            unit: "×"
        },
        {
            kind: "toggle",
            key: "appearance.sharpCorners",
            name: "HARD EDGES",
            help: "Removes every corner radius at once — full Persona angularity. Overrides CORNER ROUNDING.",
            sub: "KILL EVERY RADIUS — FULL ANGULARITY"
        },
        {
            kind: "choice",
            key: "appearance.softTone",
            name: "SOFT TONE",
            help: "The colour of all the round pills of the soft looks — the SOFT lock, SOFT desktop widgets, and a bar or frame set to TONE. ACCENT is the accent's own deep shade (pink gives plum, peach gives brown); SURFACE is the shell's grey; BLACK is near-black.",
            sub: "THE COLOUR OF THE ROUND PILLS — SOFT LOCK, SOFT WIDGETS, A TONE BAR OR FRAME",
            options: [
                {
                    value: "accent",
                    label: "ACCENT · ITS DEEP SHADE"
                },
                {
                    value: "surface",
                    label: "SURFACE"
                },
                {
                    value: "black",
                    label: "BLACK"
                }
            ]
        },
        {
            kind: "slider",
            key: "appearance.softToneStrength",
            name: "TONE COLOUR",
            help: "How much of the accent the soft tone carries. 0 is grey, 100% the house mix, 200% strongly coloured. Only for SOFT TONE = ACCENT.",
            sub: "HOW MUCH OF THE ACCENT THE SOFT TONE CARRIES · 0 IS GREY",
            min: 0,
            max: 2,
            step: 0.05,
            fmt: "percent"
        },
        {
            kind: "slider",
            key: "appearance.softToneLight",
            name: "TONE LIGHTNESS",
            help: "How light the soft tone is — lower is darker pills, higher lighter ones. Only for SOFT TONE = ACCENT.",
            sub: "HOW DARK OR LIGHT THE SOFT PILLS ARE",
            min: 0.05,
            max: 0.35,
            step: 0.01,
            fmt: "percent"
        },
        {
            kind: "slider",
            key: "appearance.skew",
            name: "SHEAR ANGLE",
            help: "The slant of the Persona panels and slashes, in degrees. 0 makes them straight rectangles — nice with the SOFT type style.",
            sub: "THE SIGNATURE TILT ON EVERY PANEL",
            min: 0,
            max: 12,
            step: 0.5,
            fmt: "float1",
            unit: "°"
        },
        {
            kind: "toggle",
            key: "appearance.halftone",
            name: "HALFTONE TEXTURE",
            help: "Comic-print dots over the panels and the bar (VELVET style). Off for flat surfaces.",
            sub: "COMIC PRINT DOTS OVER SURFACES"
        },
        {
            kind: "slider",
            key: "appearance.spacingScale",
            name: "SPACING",
            help: "Multiplies the spacing between and inside elements. Lower is denser, higher airier.",
            sub: "BREATHING ROOM MULTIPLIER",
            min: 0.6,
            max: 1.8,
            step: 0.05,
            fmt: "float2",
            unit: "×"
        },
        {
            kind: "slider",
            key: "appearance.fontScale",
            name: "TEXT SIZE",
            help: "Scales every text in the shell. Use it if everything reads too small or too large on your screen.",
            sub: "GLOBAL TYPE SCALE",
            min: 0.75,
            max: 2.2,
            step: 0.05,
            fmt: "float2",
            unit: "×"
        },
        {
            kind: "slider",
            key: "appearance.animationScale",
            name: "ANIMATION SPEED",
            help: "Multiplies the length of every animation. Lower is snappier, higher slower; very low is almost instant.",
            sub: "LOWER IS FASTER",
            min: 0.2,
            max: 2.0,
            step: 0.05,
            fmt: "float2",
            unit: "×"
        },
        {
            kind: "page",
            name: "TYPEFACES",
            help: "The three typefaces the shell uses. AUTO picks the first installed font from a built-in list (and the soft sans with TYPE STYLE = SOFT).",
            sub: "DISPLAY · BODY · MONOSPACE",
            items: [
                {
                    kind: "choice",
                    key: "appearance.fontDisplay",
                    name: "DISPLAY FACE",
                    help: "The big, heavy face used for titles and headings.",
                    sub: "THE BIG SHOUTY ONE",
                    options: root.fontChoices
                },
                {
                    kind: "choice",
                    key: "appearance.fontBody",
                    name: "BODY FACE",
                    help: "The face for everything you read: descriptions, values, lists.",
                    sub: "EVERYTHING YOU ACTUALLY READ",
                    options: root.fontChoices
                },
                {
                    kind: "choice",
                    key: "appearance.fontMono",
                    name: "MONOSPACE FACE",
                    help: "The monospaced face for numbers, times and code.",
                    sub: "NUMBERS AND CODE",
                    options: root.fontChoices
                }
            ]
        }
    ]

    readonly property var visuals: [
        {
            kind: "page",
            name: "THIS LOOK",
            help: "Everything the look you wear is made of, in one place — relief, gloss, pattern, shape, colour, type, motion — and what only this look has (the glass, the light of the soft looks, the rows of the quiet ones). Each look REMEMBERS its own tuning: put another look on, come back, and your values are here again. RESET THIS LOOK returns it to how it was designed.",
            sub: "DEPTH · GLOSS · PATTERN · SHAPE · COLOUR · TYPE · MOTION — REMEMBERED PER LOOK",
            icon: "tune",
            items: root.thisLook
        },
        {
            kind: "page",
            name: "VIBE",
            help: "What every card, chip and panel in the shell is made of: its shape, outline, shadow, ground, type, motion and the pattern behind it. A look on the LOOKS tab sets all of these at once; here you tune them one by one.",
            sub: "SHAPE · OUTLINE · SHADOW · GROUND · TYPE · MOTION",
            icon: "deployed_code",
            items: root.vibe
        }
    ].concat(root.visualRows)

    // A row of VIBE or VISUALS by its key (THIS LOOK shows the same rows).
    function pickRow(key: string): var {
        const all = root.vibe.concat(root.visualRows);
        for (let i = 0; i < all.length; i++)
            if (all[i].key === key)
                return all[i];
        return null;
    }
    function pickRows(keys: var): var {
        const out = [];
        for (let i = 0; i < keys.length; i++) {
            const r = root.pickRow(keys[i]);
            if (r)
                out.push(r);
        }
        return out;
    }

    // MODULES → PILL LAUNCHER and SHELL → LAUNCHER: how every launcher looks
    // and moves (Launcher.qml, the orbit, and LookLauncher.qml, the looks')
    readonly property var launcherRows: [
        { kind: "info", name: "LOOK", sub: "SIZE · BACKDROP · LIGHT · WHAT EACH ROW SHOWS", help: "These work on every look's launcher — Velvet's orbit and the list launchers of the other looks." },
        { kind: "slider", key: "launcher.scale", name: "SIZE", help: "How big the whole launcher is drawn. The orbit still never grows past the screen.", sub: "SMALLER OR BIGGER", min: 0.8, max: 1.3, step: 0.05, fmt: "percent" },
        { kind: "slider", key: "launcher.dim", name: "BACKDROP", help: "How much the desktop behind the launcher is darkened. 0 leaves it as it is; 100 % is the look's own amount.", sub: "HOW DARK THE ROOM GOES", min: 0, max: 2, step: 0.05, fmt: "percent" },
        { kind: "slider", key: "launcher.aura", name: "GLOW", help: "The soft light in the accent colour behind the launcher. It breathes slowly and flares when something opens. 0 switches it off.", sub: "ACCENT LIGHT BEHIND IT", min: 0, max: 1, step: 0.05, fmt: "percent" },
        { kind: "toggle", key: "launcher.highlight", name: "LIGHT THE TYPED LETTERS", help: "The letters you typed light up in every result, so you see why it was found.", sub: "\"FRFX\" LIGHTS F·R·F·X IN FIREFOX" },
        { kind: "toggle", key: "launcher.subtitles", name: "DESCRIPTIONS", help: "The short description next to or under each name (\"Web Browser\").", sub: "A LINE ABOUT EACH RESULT" },
        { kind: "toggle", key: "launcher.preview", name: "DETAIL CARD", help: "A card beside the list with the chosen result big: its icon, name, description and what Enter will do. Not on the terminal line and the poster, which have no room for it.", sub: "THE CHOSEN RESULT, BIG, BESIDE THE LIST" },
        { kind: "toggle", key: "launcher.quickKeys", name: "QUICK KEYS", help: "Hold Alt and the first nine results show a number; Alt+1 … Alt+9 opens that one straight away.", sub: "ALT+1 … ALT+9 OPENS A RESULT" },
        { kind: "toggle", key: "launcher.hints", name: "KEY HINTS", help: "The line at the foot that says which keys do what.", sub: "THE LINE AT THE FOOT" },
        {
            kind: "choice", key: "launcher.position", name: "POSITION", help: "Where the list launchers open. THE LOOK'S OWN keeps each look's place (the start menu at the bottom, the terminal line at the top).", sub: "WHERE IT OPENS",
            options: [
                { value: "auto", label: "THE LOOK'S OWN" },
                { value: "top", label: "HIGH" },
                { value: "centre", label: "MIDDLE" }
            ]
        },
        {
            kind: "choice", key: "launcher.side", name: "SIDE", help: "Whether the launcher opens in the middle or towards the left or right of the screen. The Vindows start menu keeps its corner and the terminal line its full width.", sub: "LEFT, MIDDLE OR RIGHT",
            options: [
                { value: "left", label: "LEFT" },
                { value: "centre", label: "MIDDLE" },
                { value: "right", label: "RIGHT" }
            ]
        },
        { kind: "info", name: "MOTION", sub: "OPENING · RESULTS · SELECTION · LAUNCH", help: "How the launcher moves. ANIMATION SPEED works on all of it, and the system-wide animation speed still applies on top." },
        { kind: "slider", key: "launcher.speed", name: "ANIMATION SPEED", help: "Faster or slower launcher animations. 2× is twice as fast.", sub: "SLOWER · FASTER", min: 0.5, max: 2, step: 0.1, fmt: "float1", unit: "×" },
        {
            kind: "choice", key: "launcher.entrance", name: "OPENING", help: "How the list launchers come in. THE LOOK'S OWN: the start menu rises, the terminal line drops, the arcade menu bounces in, the others grow out of the middle.", sub: "HOW IT COMES IN",
            options: [
                { value: "auto", label: "THE LOOK'S OWN" },
                { value: "rise", label: "RISE" },
                { value: "drop", label: "DROP" },
                { value: "zoom", label: "ZOOM" },
                { value: "swing", label: "SWING" },
                { value: "fade", label: "FADE" },
                { value: "none", label: "INSTANT" }
            ]
        },
        {
            kind: "choice", key: "launcher.cascade", name: "RESULTS ARRIVING", help: "How the results come in when it opens and while you type: one after another sliding in, popping up, fading in, or all at once.", sub: "ONE AFTER ANOTHER OR ALL AT ONCE",
            options: [
                { value: "slide", label: "SLIDE IN" },
                { value: "pop", label: "POP" },
                { value: "fade", label: "FADE" },
                { value: "none", label: "AT ONCE" }
            ]
        },
        {
            kind: "choice", key: "launcher.motion", name: "SELECTION", help: "How the highlight follows you from row to row: with a little spring, smoothly, or jumping.", sub: "HOW THE HIGHLIGHT MOVES",
            options: [
                { value: "spring", label: "SPRING" },
                { value: "smooth", label: "SMOOTH" },
                { value: "snap", label: "JUMP" }
            ]
        },
        {
            kind: "choice", key: "launcher.launchFx", name: "WHEN YOU OPEN SOMETHING", help: "What the launcher does when you start a result: a burst of light from it, a zoom toward you, or simply closing.", sub: "THE LAUNCH EFFECT",
            options: [
                { value: "burst", label: "BURST" },
                { value: "zoom", label: "ZOOM" },
                { value: "none", label: "JUST CLOSE" }
            ]
        },
        { kind: "info", name: "VELVET ORBIT", sub: "ONLY ON VELVET'S OWN LAUNCHER", help: "The orbit is Velvet's launcher: the results circle the search field like planets. These change only the orbit." },
        {
            kind: "choice", key: "launcher.orbitEntrance", name: "PLANETS ARRIVING", help: "How the planets come out when the orbit opens: blooming out of the search field, spiralling out, dropping in from above, or simply there.", sub: "HOW THE ORBIT OPENS",
            options: [
                { value: "bloom", label: "BLOOM" },
                { value: "spiral", label: "SPIRAL" },
                { value: "drop", label: "DROP" },
                { value: "none", label: "INSTANT" }
            ]
        },
        { kind: "slider", key: "launcher.orbitSpin", name: "DRIFT", help: "How fast the planets circle while you do nothing. 0 holds them still.", sub: "THE SLOW CIRCLING", min: 0, max: 3, step: 0.1, fmt: "float1", unit: "×" },
        { kind: "slider", key: "launcher.orbitTilt", name: "LEAN", help: "How far the orbit leans toward the mouse, like a camera in a game. 0 keeps it flat.", sub: "TILTS TOWARD THE POINTER", min: 0, max: 2.5, step: 0.1, fmt: "float1", unit: "×" },
        { kind: "toggle", key: "launcher.orbitRing", name: "ORBIT LINE", help: "A faint dotted line along the path the planets travel.", sub: "THE PATH THE PLANETS TAKE" },
        { kind: "toggle", key: "launcher.reticle", name: "LOCK-ON RING", help: "A slowly turning ring round the chosen planet.", sub: "MARKS THE CHOSEN PLANET" },
        { kind: "toggle", key: "launcher.stars", name: "STARS", help: "The slow twinkling stars behind the orbit.", sub: "THE SKY BEHIND IT" },
        { kind: "action", fn: "resetLauncherLook", name: "BACK TO DEFAULTS", help: "Puts every look and motion setting above back as designed. What the launcher searches is left alone.", sub: "LOOK AND MOTION AS DESIGNED" }
    ]

    // A row may carry `when: { key, is | in | not }`: it is there only while that
    // setting holds that value (the GLASS rows of THIS LOOK on the glass look).
    function shown(it: var): bool {
        const w = it.when;
        if (!w)
            return true;
        const v = Config.get(w.key);
        if (w.is !== undefined)
            return v === w.is;
        if (w.in !== undefined)
            return w.in.indexOf(v) >= 0;
        if (w.not !== undefined)
            return v !== w.not;
        return true;
    }

    // ============================================================ THIS LOOK
    readonly property var thisLook: {
        const v = id => ({ key: "appearance.vibe", is: id });
        const glass = { key: "appearance.vibe", in: ["glass", "chrome"] };
        const soft = { key: "appearance.vibe", in: ["neu", "clay", "fidget"] };
        const quiet = { key: "appearance.skin", is: "clean" };
        const persona = { key: "appearance.skin", is: "persona" };
        const out = [
            {
                kind: "info",
                name: "THE LOOK YOU WEAR",
                help: "These rows belong to the look on now (LOOKS tab). Whatever you change here, that look remembers: switch to another look and back and it is as you left it. RESET THIS LOOK takes it back to how it was designed. Velvet itself, the original, is tuned the same way — everything below works on it too.",
                sub: "REMEMBERED PER LOOK — PUT IT BACK ON AND YOUR TUNING COMES WITH IT"
            },
            {
                kind: "action",
                fn: "resetThisLook",
                name: "RESET THIS LOOK",
                help: "Forgets what you tuned on the look you wear and puts it back exactly as it was designed. Other looks keep their own tuning.",
                sub: "BACK TO HOW IT WAS DESIGNED"
            },
            { kind: "info", name: "SHELL PARTS", sub: "THE LAUNCHER, THE NOTIFICATIONS, THE VOLUME POP-UP, THE POWER MENU", help: "Every look builds these parts its own way. Pick another look's way for any of them — a terminal launcher on the glass look, Vindows toasts on the arcade — and this look remembers it." },
            {
                kind: "choice",
                key: "appearance.launcherStyle",
                name: "LAUNCHER",
                help: "How the launcher (Super+Space) is built: the look's own, or any look's — Velvet's orbit, a terminal prompt, a game menu, a HUD, a newspaper index, a glass spotlight, a grimoire, a poster, a quiet list or a Vindows start menu.",
                sub: "THE LOOK'S OWN OR ANY LOOK'S",
                options: [
                    { value: "auto", label: "THE LOOK'S OWN" },
                    { value: "velvet", label: "VELVET" },
                    { value: "prompt", label: "TERMINAL" },
                    { value: "arcade", label: "ARCADE" },
                    { value: "hud", label: "CYBER HUD" },
                    { value: "index", label: "NEWSPAPER" },
                    { value: "spotlight", label: "GLASS" },
                    { value: "grimoire", label: "GRIMOIRE" },
                    { value: "poster", label: "POSTER" },
                    { value: "raycast", label: "QUIET" },
                    { value: "start", label: "VINDOWS" }
                ]
            },
            {
                kind: "choice",
                key: "appearance.notifStyle",
                name: "NOTIFICATIONS",
                help: "How notifications and the notification centre are built.",
                sub: "POP-UPS AND THE CENTRE",
                options: [
                    { value: "auto", label: "THE LOOK'S OWN" },
                    { value: "velvet", label: "VELVET" },
                    { value: "prompt", label: "TERMINAL" },
                    { value: "arcade", label: "ARCADE" },
                    { value: "hud", label: "CYBER HUD" },
                    { value: "index", label: "NEWSPAPER" },
                    { value: "spotlight", label: "GLASS" },
                    { value: "grimoire", label: "GRIMOIRE" },
                    { value: "poster", label: "POSTER" },
                    { value: "raycast", label: "QUIET" },
                    { value: "start", label: "VINDOWS" }
                ]
            },
            {
                kind: "choice",
                key: "appearance.osdStyle",
                name: "VOLUME POP-UP",
                help: "How the volume and brightness pop-up is built.",
                sub: "THE OSD",
                options: [
                    { value: "auto", label: "THE LOOK'S OWN" },
                    { value: "velvet", label: "VELVET" },
                    { value: "prompt", label: "TERMINAL" },
                    { value: "arcade", label: "ARCADE" },
                    { value: "hud", label: "CYBER HUD" },
                    { value: "index", label: "NEWSPAPER" },
                    { value: "spotlight", label: "GLASS" },
                    { value: "grimoire", label: "GRIMOIRE" },
                    { value: "poster", label: "POSTER" },
                    { value: "raycast", label: "QUIET" },
                    { value: "start", label: "VINDOWS" }
                ]
            },
            {
                kind: "choice",
                key: "appearance.sessionStyle",
                name: "POWER MENU",
                help: "How the power menu (Super+Escape) is built.",
                sub: "LOCK · SLEEP · RESTART · SHUT DOWN · LOG OUT",
                options: [
                    { value: "auto", label: "THE LOOK'S OWN" },
                    { value: "velvet", label: "VELVET" },
                    { value: "prompt", label: "TERMINAL" },
                    { value: "arcade", label: "ARCADE" },
                    { value: "hud", label: "CYBER HUD" },
                    { value: "index", label: "NEWSPAPER" },
                    { value: "spotlight", label: "GLASS" },
                    { value: "grimoire", label: "GRIMOIRE" },
                    { value: "poster", label: "POSTER" },
                    { value: "raycast", label: "QUIET" },
                    { value: "start", label: "VINDOWS" }
                ]
            },
            { kind: "info", name: "COLOURS", sub: "FROM THE WALLPAPER OR THE LOOK'S OWN", help: "Every look can take its colours from your wallpaper: the accent and the hue of its ground follow the picture, and change with it. Or it keeps the colours it was designed in." },
            {
                kind: "choice",
                key: "appearance.lookColours",
                name: "COLOURS",
                help: "FROM THE WALLPAPER: the look's accent and the hue of its ground come from the wallpaper and follow it when it changes. THE LOOK'S OWN: the colours it was designed in. This applies to every look.",
                sub: "THE WALLPAPER'S · THE LOOK'S OWN — FOR EVERY LOOK",
                options: [
                    { value: "wallpaper", label: "FROM THE WALLPAPER" },
                    { value: "own", label: "THE LOOK'S OWN" }
                ]
            },
            {
                kind: "slider",
                key: "appearance.accentSaturation",
                name: "COLOUR STRENGTH",
                help: "How loud the colour taken from the wallpaper may be. 1.00 is what the picture gave; lower drifts toward grey. This look remembers it.",
                sub: "HOW LOUD THE WALLPAPER'S COLOUR IS",
                when: { key: "appearance.accentSource", is: "wallpaper" },
                min: 0.2,
                max: 1.3,
                step: 0.02,
                fmt: "float2"
            },
            {
                kind: "slider",
                key: "appearance.surfaceTint",
                name: "GROUND TINT",
                help: "How much of the colour bleeds into the look's ground and surfaces. This look remembers it.",
                sub: "HOW COLOURED THE GROUND IS",
                min: 0,
                max: 0.45,
                step: 0.01,
                fmt: "percent"
            },
            { kind: "info", name: "RELIEF", sub: "HOW DEEP, HOW GLOSSY, HOW LOUD THE PATTERN", help: "The three dials every look answers to." },
            {
                kind: "slider",
                key: "appearance.depth",
                name: "DEPTH",
                help: "How deep the relief is: every shadow's reach, the raise of neumorphic and clay plates, the lift of glass panes. 100% is the look as designed; 0 is flat.",
                sub: "SHADOWS, RELIEF, LIFT",
                min: 0, max: 2, step: 0.05, fmt: "percent"
            },
            {
                kind: "slider",
                key: "appearance.gloss",
                name: "GLOSS",
                help: "How glossy the look is: the sheen on glass, the shine on clay, the highlight on a bevel. 0 is matt.",
                sub: "SHEEN AND SHINE",
                min: 0, max: 1.5, step: 0.05, fmt: "percent"
            },
            {
                kind: "slider",
                key: "appearance.patternStrength",
                name: "PATTERN",
                help: "How loud the pattern behind the panels is: speed lines, dots, grid, ruled paper, the glass aurora.",
                sub: "WHAT SITS BEHIND THE PANELS",
                min: 0, max: 2, step: 0.05, fmt: "percent"
            },

            // ── what only some looks have
            { kind: "info", name: "GLASS", sub: "FROST · SMOKE · EDGE · AURORA", help: "The panes and the clouds behind them.", when: glass },
            { kind: "slider", key: "appearance.glassFrost", name: "FROST", help: "How white and milky the panes are. Low is clear glass, high is frosted.", sub: "HOW MILKY THE GLASS IS", min: 0.3, max: 2.2, step: 0.05, fmt: "percent", when: glass },
            { kind: "slider", key: "appearance.glassSmoke", name: "SMOKE", help: "A dark tint under the glass that keeps light type readable on a bright aurora. 0 is none.", sub: "DARK UNDER THE GLASS", min: 0, max: 0.6, step: 0.01, fmt: "percent", when: glass },
            { kind: "slider", key: "appearance.glassRim", name: "EDGE", help: "How bright the rim of every pane is.", sub: "THE LIGHT ON THE PANE'S EDGE", min: 0, max: 1, step: 0.02, fmt: "percent", when: glass },
            { kind: "slider", key: "appearance.auroraStrength", name: "AURORA", help: "How strong the clouds of colour behind the glass are.", sub: "THE COLOUR BEHIND THE GLASS", min: 0, max: 1.6, step: 0.05, fmt: "percent", when: glass },
            {
                kind: "choice",
                key: "appearance.auroraPalette",
                name: "AURORA COLOURS",
                help: "The colours of the clouds: violet and cyan, ocean, sunset, forest, or grey.",
                sub: "VIOLET · OCEAN · SUNSET · FOREST · MONO",
                options: [
                    { value: "violet", label: "VIOLET" },
                    { value: "ocean", label: "OCEAN" },
                    { value: "sunset", label: "SUNSET" },
                    { value: "forest", label: "FOREST" },
                    { value: "mono", label: "MONO" }
                ],
                when: glass
            },
            { kind: "info", name: "SOFT RELIEF", sub: "LIGHT AND CLAY", help: "Neumorphism and clay are made of light and shadow.", when: soft },
            {
                kind: "choice",
                key: "appearance.neuLight",
                name: "LIGHT FROM",
                help: "Which corner the light comes from. The lit edge is on that side, the shadow on the other.",
                sub: "TOP LEFT · TOP RIGHT · BOTTOM LEFT · BOTTOM RIGHT",
                options: [
                    { value: "top-left", label: "TOP LEFT" },
                    { value: "top-right", label: "TOP RIGHT" },
                    { value: "bottom-left", label: "BOTTOM LEFT" },
                    { value: "bottom-right", label: "BOTTOM RIGHT" }
                ],
                when: soft
            },
            {
                kind: "choice",
                key: "appearance.clayTint",
                name: "CLAY COLOUR",
                help: "The colour of the clay: its shadow and the tint of its pillows. ACCENT follows your accent colour.",
                sub: "ACCENT · PEACH · MINT · SKY · LILAC",
                options: [
                    { value: "accent", label: "ACCENT" },
                    { value: "peach", label: "PEACH" },
                    { value: "mint", label: "MINT" },
                    { value: "sky", label: "SKY" },
                    { value: "lilac", label: "LILAC" }
                ],
                when: { key: "appearance.vibe", in: ["clay", "fidget"] }
            },
            { kind: "info", name: "THE QUIET SHEET", sub: "ROWS AND SIDEBAR", help: "How the calm settings window lays out its rows.", when: quiet },
            {
                kind: "choice",
                key: "appearance.cleanRows",
                name: "ROW STYLE",
                help: "LINES separate the rows with a hairline, CARDS give each row a card of its own, PLAIN leaves them bare. (Neumorphism and clay mould their rows themselves.)",
                sub: "LINES · CARDS · PLAIN",
                options: [
                    { value: "lines", label: "LINES" },
                    { value: "cards", label: "CARDS" },
                    { value: "plain", label: "PLAIN" }
                ],
                when: quiet
            },
            {
                kind: "choice",
                key: "appearance.cleanSide",
                name: "SIDEBAR",
                help: "TINTED gives the sidebar a wash of its own colour; PLAIN lets it sit on the sheet.",
                sub: "TINTED · PLAIN",
                options: [
                    { value: "tinted", label: "TINTED" },
                    { value: "plain", label: "PLAIN" }
                ],
                when: quiet
            },
            { kind: "info", name: "THE HOUSE TILT", sub: "SHEAR · PRINT DOTS · HARD EDGES", help: "What makes Velvet itself: the slant, the print, the angles.", when: persona }
        ].concat(
            root.pickRows(["appearance.skew", "appearance.halftone", "appearance.sharpCorners"]).map(r => Object.assign({}, r, { when: persona })),
            [{ kind: "info", name: "SHAPE & EDGE", sub: "CARDS · OUTLINE · SHADOW · CORNERS", help: "The outline of every card and what it casts." }],
            root.pickRows(["appearance.shape", "appearance.outline", "appearance.edge", "appearance.shadow", "appearance.shadowSize", "appearance.roundingScale"]),
            [{ kind: "info", name: "COLOUR", sub: "ACCENT · GROUND · TINT · TRANSPARENCY", help: "The palette of the shell." }],
            root.pickRows(["appearance.accentSource", "appearance.accentColour", "appearance.accentSaturation", "appearance.ground", "appearance.groundColour", "appearance.surfaceTint", "appearance.surfaceLift", "appearance.transparency"]),
            [{ kind: "info", name: "TYPE & MOTION", sub: "TYPE · CASE · SIZE · MOTION · BACKDROP · SOUND", help: "How the look speaks and moves." }],
            root.pickRows(["appearance.typeStyle", "appearance.caps", "appearance.fontScale", "appearance.motion", "appearance.animationScale", "appearance.backdrop", "appearance.scanlines", "sfx.pack"])
        );
        return out;
    }

    // ================================================================ TASKBAR
    readonly property var taskbar: [
        {
            kind: "choice",
            key: "bar.position",
            name: "POSITION",
            help: "Which screen edge the bar docks to. Vertical bars stack their modules, horizontal ones line them up; windows make room for it.",
            sub: "WHICH EDGE THE BAR DOCKS TO",
            options: [
                {
                    value: "left",
                    label: "LEFT"
                },
                {
                    value: "right",
                    label: "RIGHT"
                },
                {
                    value: "top",
                    label: "TOP"
                },
                {
                    value: "bottom",
                    label: "BOTTOM"
                }
            ]
        },
        {
            kind: "choice",
            key: "bar.style",
            name: "STYLE",
            help: "VELVET wears the halftone dots, the accent hairline and the accent wedge; CLEAN is a plain strip; FLOATING is a pill only as long as its modules, centred on the edge — clicks beside it go through to the windows.",
            sub: "VELVET WEARS THE HALFTONE AND THE WEDGE · CLEAN IS A PLAIN STRIP · FLOATING IS A PILL THAT HUGS ITS MODULES",
            options: [
                {
                    value: "velvet",
                    label: "VELVET"
                },
                {
                    value: "clean",
                    label: "CLEAN"
                },
                {
                    value: "floating",
                    label: "FLOATING"
                }
            ]
        },
        {
            kind: "choice",
            key: "bar.colour",
            name: "BAR COLOUR",
            help: "The bar's own colour: the shell's SURFACE grey, the accent's deep TONE (the same colour as the soft pills), or BLACK. BACKGROUND OPACITY decides how solid it is.",
            sub: "THE SHELL'S SURFACE, THE ACCENT'S DEEP TONE (LIKE THE SOFT PILLS) OR BLACK",
            options: [
                {
                    value: "surface",
                    label: "SURFACE"
                },
                {
                    value: "tone",
                    label: "TONE"
                },
                {
                    value: "black",
                    label: "BLACK"
                }
            ]
        },
        {
            kind: "toggle",
            key: "bar.frame",
            name: "SCREEN FRAME",
            help: "A thin frame (a border round the whole screen, not round each window) in the bar's colour, with the desktop's corners rounded inside it — the wallpaper looks like it sits in a rounded window. It takes no clicks. A docked island grows out of it.",
            sub: "A THIN FRAME IN THE BAR'S COLOUR ROUND THE DESKTOP, ITS CORNERS ROUNDED INSIDE"
        },
        {
            kind: "slider",
            key: "bar.frameWidth",
            name: "FRAME WIDTH",
            help: "How thick the frame is on the edges the bar does not hold, in pixels.",
            sub: "HOW THICK THE FRAME IS ON THE EDGES WITHOUT THE BAR",
            min: 0,
            max: 24,
            step: 1,
            fmt: "int",
            unit: "px"
        },
        {
            kind: "slider",
            key: "bar.frameRounding",
            name: "FRAME CORNERS",
            help: "How round the desktop's corners are inside the frame, in pixels.",
            sub: "HOW ROUND THE DESKTOP'S CORNERS ARE INSIDE THE FRAME",
            min: 0,
            max: 48,
            step: 1,
            fmt: "int",
            unit: "px"
        },
        {
            kind: "toggle",
            key: "bar.frameConnect",
            name: "CONNECT TO THE TASKBAR",
            help: "Bar and frame become one surface: the bar draws no plate and no Velvet trim of its own, it sits right on the frame's band, so there is no seam and the desktop rounds off exactly where the bar ends. With a bar that hides, the band grows out of the frame as the bar slides in. Not for a FLOATING bar.",
            sub: "BAR AND FRAME BECOME ONE SURFACE — NO SEAM, THE DESKTOP ROUNDS OFF WHERE THE BAR ENDS"
        },
        {
            kind: "choice",
            key: "bar.frameColour",
            name: "FRAME COLOUR",
            help: "The frame's colour: BAR follows BAR COLOUR, TONE is the accent's deep shade, BLACK, or ACCENT for a bold coloured frame.",
            sub: "THE BAR'S OWN, THE ACCENT'S DEEP TONE, BLACK OR THE ACCENT",
            options: [
                {
                    value: "bar",
                    label: "BAR"
                },
                {
                    value: "tone",
                    label: "TONE"
                },
                {
                    value: "black",
                    label: "BLACK"
                },
                {
                    value: "accent",
                    label: "ACCENT"
                }
            ]
        },
        {
            kind: "slider",
            key: "bar.frameOpacity",
            name: "FRAME OPACITY",
            help: "How solid the frame is. With CONNECT on this is also the bar's opacity.",
            sub: "HOW SOLID THE FRAME IS",
            min: 0.2,
            max: 1,
            step: 0.02,
            fmt: "percent"
        },
        {
            kind: "toggle",
            key: "bar.frameShadow",
            name: "FRAME SHADOW",
            help: "A soft shadow the frame casts inwards onto the desktop, so the wallpaper looks set into the frame.",
            sub: "A SOFT SHADOW THE FRAME CASTS ONTO THE DESKTOP"
        },
        {
            kind: "toggle",
            key: "bar.frameOutline",
            name: "FRAME OUTLINE",
            help: "A thin accent line along the inner edge of the frame, right round the desktop.",
            sub: "A HAIRLINE OF ACCENT ROUND THE DESKTOP"
        },
        {
            kind: "slider",
            key: "bar.thickness",
            name: "THICKNESS",
            help: "The bar's width when it is on the left or right, its height when on the top or bottom, in pixels. Windows keep this much room free.",
            sub: "WIDTH WHEN VERTICAL, HEIGHT WHEN HORIZONTAL",
            min: 28,
            max: 140,
            step: 1,
            fmt: "int",
            unit: "px"
        },
        {
            kind: "slider",
            key: "bar.margin",
            name: "SCREEN MARGIN",
            help: "The gap between the bar and the screen edge, in pixels. 0 docks it flush; more makes it float.",
            sub: "GAP BETWEEN BAR AND SCREEN EDGE",
            min: 0,
            max: 32,
            step: 1,
            fmt: "int",
            unit: "px"
        },
        {
            kind: "slider",
            key: "bar.rounding",
            name: "CORNER RADIUS",
            help: "How round the bar plate's corners are, in pixels.",
            sub: "ROUNDING OF THE BAR PLATE",
            min: 0,
            max: 48,
            step: 1,
            fmt: "int",
            unit: "px"
        },
        {
            kind: "slider",
            key: "bar.padding",
            name: "INNER PADDING",
            help: "Space between the bar's edge and its modules, in pixels.",
            sub: "SPACE INSIDE THE PLATE",
            min: 0,
            max: 20,
            step: 1,
            fmt: "int",
            unit: "px"
        },
        {
            kind: "slider",
            key: "bar.spacing",
            name: "MODULE SPACING",
            help: "Space between the modules on the bar, in pixels.",
            sub: "GAP BETWEEN ENTRIES",
            min: 0,
            max: 28,
            step: 1,
            fmt: "int",
            unit: "px"
        },
        {
            kind: "slider",
            key: "bar.opacity",
            name: "BACKGROUND OPACITY",
            help: "How solid the bar plate is. 100% is opaque; lower lets the wallpaper show through (frosted when BLUR is on).",
            sub: "TRANSPARENCY OF THE BAR PLATE",
            min: 0,
            max: 1,
            step: 0.01,
            fmt: "percent"
        },
        {
            kind: "slider",
            key: "bar.fontSize",
            name: "FONT SIZE",
            help: "Text size of the bar's modules (clock, labels), in pixels.",
            sub: "TEXT SIZE IN BAR MODULES",
            min: 8,
            max: 36,
            step: 1,
            fmt: "int",
            unit: "px"
        },
        {
            kind: "slider",
            key: "bar.iconSize",
            name: "ICON SIZE",
            help: "Icon size of the bar's modules, in pixels.",
            sub: "GLYPH SIZE IN BAR MODULES",
            min: 12,
            max: 56,
            step: 1,
            fmt: "int",
            unit: "px"
        },
        {
            kind: "page",
            name: "BEHAVIOUR",
            help: "When the bar is on screen, how it comes back when hidden, and what scrolling on it does.",
            sub: "HIDING, REVEALING, SCROLLING",
            items: [
                {
                    kind: "toggle",
                    key: "bar.persistent",
                    name: "ALWAYS VISIBLE",
                    help: "Keeps the bar on screen and reserves its space so windows never cover it. Off lets it hide (together with REVEAL ON HOVER). With the SCREEN FRAME on, a hidden bar leaves the frame's normal edge, and when it slides out the frame's band on that edge grows with it — the bar comes out of the frame.",
                    sub: "PIN THE BAR AND RESERVE ITS SPACE"
                },
                {
                    kind: "toggle",
                    key: "bar.showOnHover",
                    name: "REVEAL ON HOVER",
                    help: "When the bar is not pinned, touching its screen edge slides it out — with the SCREEN FRAME on, out of the frame, whose band widens to make room. With both this and ALWAYS VISIBLE off the bar still stays — otherwise there would be no way to reach it.",
                    sub: "SLIDE OUT WHEN THE POINTER TOUCHES THE EDGE"
                },
                {
                    kind: "slider",
                    key: "bar.revealEdge",
                    name: "REVEAL THRESHOLD",
                    help: "How wide the invisible strip along the edge is that wakes a hidden bar, in pixels. It takes clicks, so keep it thin if windows sit against that edge.",
                    sub: "HOW WIDE THE INVISIBLE HOVER STRIP IS",
                    min: 1,
                    max: 24,
                    step: 1,
                    fmt: "int",
                    unit: "px"
                },
                {
                    kind: "slider",
                    key: "bar.peek",
                    name: "PEEK",
                    help: "How much of a hidden bar stays visible, in pixels. 0 hides it completely.",
                    sub: "HOW MUCH BAR STAYS VISIBLE WHEN HIDDEN · 0 IS GONE",
                    min: 0,
                    max: 24,
                    step: 1,
                    fmt: "int",
                    unit: "px"
                },
                {
                    kind: "slider",
                    key: "bar.hoverDelay",
                    name: "HOVER DELAY",
                    help: "How long the pointer rests on the edge before the hidden bar slides out, in milliseconds.",
                    sub: "WAIT BEFORE THE BAR SLIDES OUT",
                    min: 0,
                    max: 800,
                    step: 10,
                    fmt: "int",
                    unit: "ms"
                },
                {
                    kind: "slider",
                    key: "bar.hideDelay",
                    name: "HIDE DELAY",
                    help: "How long the bar waits after the pointer leaves before it hides again, in milliseconds — room to reach something without it vanishing.",
                    sub: "GRACE PERIOD BEFORE IT SLIDES BACK AWAY",
                    min: 100,
                    max: 2000,
                    step: 50,
                    fmt: "int",
                    unit: "ms"
                },
                {
                    kind: "toggle",
                    key: "bar.scroll.workspaces",
                    name: "SCROLL: WORKSPACES",
                    help: "The mouse wheel over the first third of the bar (where the workspaces are) switches workspace. Needs the workspaces module on the bar.",
                    sub: "WHEEL OVER THE WORKSPACE AREA SWITCHES"
                },
                {
                    kind: "toggle",
                    key: "bar.scroll.volume",
                    name: "SCROLL: VOLUME",
                    help: "The mouse wheel over the middle third of the bar changes the volume.",
                    sub: "WHEEL OVER THE MIDDLE CHANGES VOLUME"
                },
                {
                    kind: "toggle",
                    key: "bar.scroll.brightness",
                    name: "SCROLL: BRIGHTNESS",
                    help: "The mouse wheel over the last third of the bar changes the brightness.",
                    sub: "WHEEL OVER THE FAR END CHANGES BRIGHTNESS"
                }
            ]
        },
        {
            kind: "page",
            name: "WORKSPACES",
            help: "The workspace indicator on the bar: its look, how many slots it shows, and its marks.",
            sub: "SLOTS, PIPS AND LABELS",
            items: [
                {
                    kind: "choice",
                    key: "bar.workspaces.style",
                    name: "STYLE",
                    help: "SLASH is the accent wedge that springs between slots; PILLS stretches the active workspace into a pill with its number; DOTS are small dots, the active one larger in the accent; NUMBERS shows every number, the active one filled.",
                    sub: "SLASH: THE SLIDING WEDGE · PILLS: THE ACTIVE ONE STRETCHES · DOTS · NUMBERS",
                    options: [
                        {
                            value: "slash",
                            label: "SLASH"
                        },
                        {
                            value: "pills",
                            label: "PILLS"
                        },
                        {
                            value: "dots",
                            label: "DOTS"
                        },
                        {
                            value: "numbers",
                            label: "NUMBERS"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "bar.workspaces.names",
                    name: "NAMES",
                    aka: "WORKSPACE NAMES · GREEK LETTERS · ROMAN NUMERALS",
                    help: "What the workspace slots are called wherever the bar writes them — in the active slash, the pills, the numbers and the text looks. AUTO keeps numbers (Roman in the newspaper and book looks); 1 2 3, I II III and α β γ name every slot the same way.",
                    sub: "AUTO · 1 2 3 · I II III · α β γ",
                    options: [
                        {
                            value: "auto",
                            label: "AUTO"
                        },
                        {
                            value: "numbers",
                            label: "1 2 3"
                        },
                        {
                            value: "roman",
                            label: "I II III"
                        },
                        {
                            value: "greek",
                            label: "α β γ"
                        }
                    ]
                },
                {
                    kind: "slider",
                    key: "bar.workspaces.shown",
                    name: "SLOTS SHOWN",
                    help: "How many workspace slots are shown at once. Beyond that the indicator turns to the next page (6–10 when 5 are shown).",
                    sub: "HOW MANY WORKSPACES PER PAGE",
                    min: 1,
                    max: 12,
                    step: 1,
                    fmt: "int"
                },
                {
                    kind: "toggle",
                    key: "bar.workspaces.activeIndicator",
                    name: "ACTIVE INDICATOR",
                    help: "The sliding accent wedge behind the active workspace. SLASH style only.",
                    sub: "THE SLIDING ACCENT SLASH"
                },
                {
                    kind: "toggle",
                    key: "bar.workspaces.showWindows",
                    name: "WINDOW PIPS",
                    help: "Small marks under a workspace showing how many windows are open on it (up to three). SLASH style only.",
                    sub: "MARKS SHOWING HOW MANY WINDOWS ARE OPEN"
                },
                {
                    kind: "toggle",
                    key: "bar.workspaces.labelOccupied",
                    name: "ALWAYS SHOW NUMBERS",
                    help: "Shows the number of every slot, not only the active one. SLASH style only — NUMBERS style always does.",
                    sub: "NUMBER EVERY SLOT, NOT JUST THE ACTIVE ONE"
                }
            ]
        },
        {
            kind: "page",
            name: "CLOCK",
            help: "The bar's clock: 12 or 24 hours, the date, seconds. Clicking the clock opens the notifications; right-click jumps here.",
            sub: "FORMAT AND DATE",
            items: [
                {
                    kind: "toggle",
                    key: "bar.clock.format24h",
                    name: "24-HOUR TIME",
                    help: "Shows the time as 14:30 instead of 2:30 PM. Also used by the lock and the widgets unless they set their own.",
                    sub: "USE 24H INSTEAD OF AM/PM"
                },
                {
                    kind: "toggle",
                    key: "bar.clock.showDate",
                    name: "SHOW DATE",
                    help: "Shows the date next to the time (or under it on a vertical bar).",
                    sub: "DATE ALONGSIDE THE TIME"
                },
                {
                    kind: "toggle",
                    key: "bar.clock.showSeconds",
                    name: "SHOW SECONDS",
                    help: "Shows the seconds as well. The clock then updates every second instead of every minute.",
                    sub: "TICKS EVERY SECOND"
                }
            ]
        },
        {
            kind: "page",
            name: "TIME & TIME ZONE",
            aka: "ZEIT · ZEITZONE · UHRZEIT ÄNDERN · UHR STELLEN · TIMEZONE · WELTZEIT",
            help: "The time the whole shell shows — the bar, the lock, the desktop widgets, the island, Velly. YOUR COMPUTER is its own clock; A TIME ZONE shows the time somewhere else (summer time comes and goes by itself); SET BY HAND runs from a time you type, on from there. Your computer's clock itself is never changed.",
            sub: "YOUR COMPUTER'S · ANOTHER ZONE · SET BY HAND",
            items: [
                {
                    kind: "info",
                    name: "RIGHT NOW",
                    help: "What the shell shows, where it is from, and your computer's own time beside it.",
                    sub: "WHAT THE SHELL SHOWS",
                    live: "timeStatus"
                },
                {
                    kind: "choice",
                    key: "time.mode",
                    name: "TIME FROM",
                    help: "YOUR COMPUTER: its own clock. A TIME ZONE: the time in the zone below. SET BY HAND: a time you type (or nudge), running on from there.",
                    sub: "YOUR COMPUTER · A TIME ZONE · SET BY HAND",
                    options: [
                        { value: "system", label: "YOUR COMPUTER" },
                        { value: "zone", label: "A TIME ZONE" },
                        { value: "manual", label: "SET BY HAND" }
                    ]
                },
                {
                    kind: "choice",
                    key: "time.zone",
                    name: "TIME ZONE",
                    help: "The city whose time the shell shows. Not in the list? Type any zone under ANY OTHER ZONE.",
                    sub: "WHOSE TIME THE SHELL SHOWS",
                    when: { key: "time.mode", is: "zone" },
                    options: [
                        { value: "America/Los_Angeles", label: "LOS ANGELES" },
                        { value: "America/Denver", label: "DENVER" },
                        { value: "America/Chicago", label: "CHICAGO" },
                        { value: "America/Mexico_City", label: "MEXICO CITY" },
                        { value: "America/New_York", label: "NEW YORK" },
                        { value: "America/Sao_Paulo", label: "SÃO PAULO" },
                        { value: "UTC", label: "UTC" },
                        { value: "Europe/London", label: "LONDON" },
                        { value: "Europe/Berlin", label: "BERLIN" },
                        { value: "Europe/Istanbul", label: "ISTANBUL" },
                        { value: "Europe/Moscow", label: "MOSCOW" },
                        { value: "Asia/Dubai", label: "DUBAI" },
                        { value: "Asia/Kolkata", label: "DELHI · MUMBAI" },
                        { value: "Asia/Bangkok", label: "BANGKOK" },
                        { value: "Asia/Shanghai", label: "SHANGHAI" },
                        { value: "Asia/Seoul", label: "SEOUL" },
                        { value: "Asia/Tokyo", label: "TOKYO" },
                        { value: "Australia/Sydney", label: "SYDNEY" },
                        { value: "Pacific/Auckland", label: "AUCKLAND" },
                        { value: "Pacific/Honolulu", label: "HONOLULU" }
                    ]
                },
                {
                    kind: "text",
                    key: "time.zone",
                    name: "ANY OTHER ZONE",
                    aka: "ZEITZONE EINTIPPEN · STADT",
                    help: "Any of the world's time zones, by its name (Europe/Lisbon) or just the city (lisbon, new york, kathmandu). The shell finds it and writes its full name back.",
                    sub: "BY NAME OR BY CITY",
                    when: { key: "time.mode", is: "zone" },
                    placeholder: "e.g. Lisbon  or  America/Toronto",
                    examples: ["Lisbon", "Toronto", "Kathmandu", "Cairo", "Singapore", "Europe/Zurich"],
                    empty: "NONE YET"
                },
                {
                    kind: "text",
                    key: "time.setTo",
                    name: "SET THE TIME",
                    aka: "UHRZEIT EINSTELLEN · UHR STELLEN",
                    help: "Type the time the shell should show — 7:45, 19:45 or 7:45 pm — and it runs on from there. Your computer's clock is not changed.",
                    sub: "TYPE IT · IT RUNS ON FROM THERE",
                    when: { key: "time.mode", is: "manual" },
                    placeholder: "e.g. 7:45  or  19:45",
                    examples: ["7:00", "12:00", "18:30", "23:59"],
                    empty: "TYPE A TIME"
                },
                {
                    kind: "slider",
                    key: "time.manualOffset",
                    name: "NUDGE IT",
                    aka: "VORSTELLEN · ZURÜCKSTELLEN · MINUTEN",
                    help: "Moves the shown time forward or back by minutes — a clock a few minutes fast, so you are never late.",
                    sub: "MINUTES AHEAD OR BEHIND YOUR COMPUTER",
                    when: { key: "time.mode", is: "manual" },
                    min: -720, max: 720, step: 1, fmt: "int", unit: " min"
                },
                {
                    kind: "toggle",
                    key: "time.showTag",
                    name: "SAY WHERE IT IS FROM",
                    help: "The bar's clock carries a small tag (TOKYO, BY HAND) while it does not show your computer's own time, so you never mistake it.",
                    sub: "A SMALL TAG BESIDE THE BAR'S CLOCK"
                },
                {
                    kind: "action",
                    name: "BACK TO YOUR COMPUTER'S TIME",
                    help: "The shell shows your computer's own clock again.",
                    sub: "NO ZONE, NOTHING SET BY HAND",
                    when: { key: "time.mode", not: "system" },
                    fn: "timeBackToSystem"
                }
            ]
        },
        {
            kind: "page",
            name: "STATUS CLUSTER",
            help: "Which small indicators appear in the bar's status cluster.",
            sub: "WHICH INDICATORS APPEAR",
            items: [
                {
                    kind: "toggle",
                    key: "bar.status.network",
                    name: "NETWORK",
                    help: "Wi-Fi or Ethernet connection state.",
                    sub: "WI-FI OR ETHERNET STATE"
                },
                {
                    kind: "toggle",
                    key: "bar.status.bluetooth",
                    name: "BLUETOOTH",
                    help: "Bluetooth adapter and connection state. Hidden when there is no adapter.",
                    sub: "ADAPTER AND CONNECTION STATE"
                },
                {
                    kind: "toggle",
                    key: "bar.status.volume",
                    name: "VOLUME",
                    help: "Speaker volume and mute state.",
                    sub: "SPEAKER STATE"
                },
                {
                    kind: "toggle",
                    key: "bar.status.battery",
                    name: "BATTERY",
                    help: "Battery charge. Only shows on a machine that has a battery.",
                    sub: "CHARGE LEVEL (LAPTOPS ONLY)"
                },
                {
                    kind: "toggle",
                    key: "bar.status.cpu",
                    name: "CPU GAUGE",
                    help: "A live gauge of processor load.",
                    sub: "LIVE PROCESSOR LOAD"
                },
                {
                    kind: "toggle",
                    key: "bar.status.memory",
                    name: "MEMORY GAUGE",
                    help: "A live gauge of memory in use.",
                    sub: "LIVE RAM USAGE"
                },
                {
                    kind: "toggle",
                    key: "bar.status.temperature",
                    name: "TEMPERATURE",
                    help: "The CPU temperature. Hidden when no sensor reports one.",
                    sub: "CPU PACKAGE TEMPERATURE"
                }
            ]
        },
        {
            kind: "page",
            name: "TRAY",
            help: "The system tray: icons of apps running in the background.",
            sub: "BACKGROUND APP ICONS",
            items: [
                {
                    kind: "toggle",
                    key: "bar.tray.background",
                    name: "ICON BACKGROUNDS",
                    help: "Draws a small plate behind every tray icon. Off shows the icons bare.",
                    sub: "PLATE BEHIND EACH TRAY ICON"
                }
            ]
        }
    ]

    // ================================================================ WINDOWS
    readonly property var windows: [
        {
            kind: "page",
            name: "MINI DESKTOP",
            help: "The mini desktop that drops from the top edge — the same settings as under MODULES, in a second place.",
            sub: "THE MAP THAT DROPS FROM THE TOP EDGE",
            items: [
                {
                    kind: "toggle",
                    key: "map.enabled",
                    name: "MINI DESKTOP",
                    help: "The mini desktop itself — top edge or Super+Shift+M. Off disables it everywhere.",
                    sub: "REACH FOR THE TOP EDGE, OR SUPER+SHIFT+M"
                },
                {
                    kind: "info",
                    name: "WHAT IT IS",
                    help: "A picture of all your desktops. Click one to go there, drag a window to move it (even to another workspace), scroll to zoom out and see more of them.",
                    sub: "A PICTURE OF YOUR DESKTOPS  ·  CLICK GOES THERE  ·  DRAG MOVES A WINDOW  ·  SCROLL ZOOMS OUT TO THE OTHERS"
                },
                {
                    kind: "info",
                    name: "RIGHT NOW",
                    help: "What the mini desktop can see right now.",
                    sub: "WHAT THE MAP CAN SEE",
                    live: "deskStatus"
                },
                {
                    kind: "action",
                    name: "OPEN IT",
                    help: "Opens the mini desktop now.",
                    sub: "SAME AS REACHING FOR THE TOP EDGE",
                    fn: "openMap"
                },
                {
                    kind: "toggle",
                    key: "map.hoverEdge",
                    name: "OPEN ON HOVER",
                    help: "Touching the top edge opens it. Off: only the keyboard shortcut and the bar button do.",
                    sub: "OFF MAKES IT KEYBOARD AND BAR ONLY"
                },
                {
                    kind: "toggle",
                    key: "map.island",
                    name: "DYNAMIC ISLAND",
                    help: "The black pill at the top edge. On: touching the edge raises the pill first; off: the map opens directly.",
                    sub: "THE BLACK PILL  ·  SWIPE FOR MODULES  ·  PULL DOWN TO OPEN"
                },
                {
                    kind: "toggle",
                    key: "map.islandTasks",
                    name: "TASKS IN THE ISLAND",
                    help: "Adds the task checklist to the island's swipe cycle.",
                    sub: "A CHECKLIST MODULE BETWEEN MAP AND WEATHER"
                },
                {
                    kind: "toggle",
                    key: "services.questToasts",
                    name: "QUEST COMPLETE",
                    help: "Checking a task off plays a small flourish and shows a toast.",
                    sub: "A FLOURISH AND A TOAST WHEN YOU CHECK A TASK OFF"
                },
                {
                    kind: "slider",
                    key: "map.edgeWidth",
                    name: "HOT ZONE WIDTH",
                    help: "How much of the top edge reacts to the pointer, in pixels (at least 80).",
                    sub: "HOW MUCH OF THE TOP EDGE LISTENS",
                    min: 120,
                    max: 1400,
                    step: 20,
                    fmt: "int",
                    unit: "PX"
                },
                {
                    kind: "slider",
                    key: "map.openDelay",
                    name: "OPEN DELAY",
                    help: "How long the pointer has to rest on the top edge before it opens, in milliseconds.",
                    sub: "HOW LONG YOU HAVE TO MEAN IT",
                    min: 0,
                    max: 600,
                    step: 10,
                    fmt: "int",
                    unit: "MS"
                },
                {
                    kind: "slider",
                    key: "map.closeDelay",
                    name: "CLOSE DELAY",
                    help: "How long it waits after the pointer leaves before closing, in milliseconds.",
                    sub: "GRACE PERIOD AFTER THE POINTER LEAVES",
                    min: 0,
                    max: 1500,
                    step: 20,
                    fmt: "int",
                    unit: "MS"
                },
                {
                    kind: "slider",
                    key: "map.plateWidth",
                    name: "SIZE",
                    help: "How wide the map is, as a share of the screen; the height follows your monitor's shape.",
                    sub: "SHARE OF THE SCREEN  ·  THE HEIGHT FOLLOWS YOUR MONITOR'S SHAPE",
                    min: 0.18,
                    max: 0.7,
                    step: 0.01,
                    fmt: "percent"
                },
                {
                    kind: "slider",
                    key: "map.desktops",
                    name: "ROOM FOR",
                    help: "How many workspace slots the map keeps ready when you zoom out.",
                    sub: "HOW MANY DESKTOPS TO KEEP A SLOT FOR WHEN YOU ZOOM OUT",
                    min: 1,
                    max: 16,
                    step: 1,
                    fmt: "int",
                    unit: "DESKTOPS"
                },
                {
                    kind: "toggle",
                    key: "map.previews",
                    name: "DESKTOP SNAPSHOT",
                    help: "A live photograph of each workspace. Off shows cards with app icons instead.",
                    sub: "THE MAP PHOTOGRAPHS THE SCREEN  ·  OFF SHOWS ICON CARDS"
                },
                {
                    kind: "toggle",
                    key: "map.showTitles",
                    name: "NAME ON HOVER",
                    help: "Shows the window's title under the card you point at.",
                    sub: "THE WINDOW TITLE UNDER THE CARD YOU POINT AT"
                },
                {
                    kind: "toggle",
                    key: "map.showWorkspaceLabels",
                    name: "NUMBER EACH DESKTOP",
                    help: "A small number in the corner of every workspace in the map.",
                    sub: "A SMALL NUMBER IN THE CORNER OF EVERY WORKSPACE"
                },
                {
                    kind: "toggle",
                    key: "map.clickFocuses",
                    name: "CLICK GOES THERE",
                    help: "Clicking a window in the map focuses it and takes you to its workspace.",
                    sub: "CLICKING A WINDOW FOCUSES IT AND TAKES YOU TO ITS DESKTOP"
                },
                {
                    kind: "toggle",
                    key: "map.dragFloats",
                    name: "DRAG FLOATS A TILED WINDOW",
                    help: "Dragging a tiled window in the map makes it float so it lands exactly where you drop it. Press F on it to tile it again.",
                    sub: "HYPRLAND CANNOT MOVE A TILED WINDOW BY PIXEL  ·  F PUTS IT BACK"
                }
            ]
        },
        {
            kind: "page",
            name: "DISPATCH",
            help: "How Velvet sends commands to Hyprland. Hyprland with a Lua config refuses the classic command strings silently, so Velvet checks which kind works.",
            sub: "HOW VELVET TALKS TO HYPRLAND",
            items: [
                {
                    kind: "info",
                    name: "RIGHT NOW",
                    help: "Which command style was detected and is in use right now.",
                    sub: "PROBED AT STARTUP, AND CORRECTED IF AN ACTION IS REFUSED",
                    live: "dispatchStatus"
                },
                {
                    kind: "info",
                    name: "WHY THIS EXISTS",
                    help: "A hyprland.lua config rejects the classic dispatch strings, and a refused dispatch says nothing — so Velvet probes at startup and switches if a command is refused.",
                    sub: "A HYPRLAND.LUA CONFIG REJECTS THE CLASSIC DISPATCH STRINGS, AND A REFUSED DISPATCH IS SILENT — SO VELVET READS THE ANSWER BACK"
                },
                {
                    kind: "choice",
                    key: "hypr.luaDispatch",
                    name: "DISPATCH STYLE",
                    help: "AUTO detects the right style; LUA or CLASSIC forces one. Only change it if window commands (move, focus, close) stop working.",
                    sub: "LEAVE ON AUTO UNLESS YOU KNOW OTHERWISE",
                    options: [
                        {
                            value: "auto",
                            label: "AUTO"
                        },
                        {
                            value: "lua",
                            label: "LUA"
                        },
                        {
                            value: "classic",
                            label: "CLASSIC"
                        }
                    ]
                }
            ]
        },
        {
            kind: "toggle",
            key: "hypr.manage",
            name: "MANAGE HYPRLAND",
            help: "Lets Velvet write its window settings (gaps, borders, blur …) into its own file — velvet.lua or velvet.conf in ~/.config/hypr — and apply them live. Off: Velvet leaves Hyprland alone and the WINDOWS settings do nothing.",
            sub: "LET VELVET WRITE ITS CONFIG FILE AND APPLY LIVE"
        },
        {
            kind: "choice",
            key: "hypr.format",
            name: "CONFIG LANGUAGE",
            help: "Which language that file is written in. AUTO follows your hyprland config (Lua if you have hyprland.lua).",
            sub: "WHICH FILE VELVET WRITES — AUTO FOLLOWS YOURS",
            options: [
                {
                    value: "auto",
                    label: "AUTO"
                },
                {
                    value: "lua",
                    label: "LUA"
                },
                {
                    value: "conf",
                    label: "HYPRLANG"
                }
            ]
        },
        {
            kind: "toggle",
            key: "hypr.manageBorders",
            name: "TINT WINDOW BORDERS",
            help: "Colours the active window's border with the accent (it changes with the wallpaper). Off keeps your own border colours.",
            sub: "BORDER COLOUR FOLLOWS THE WALLPAPER ACCENT"
        },
        {
            kind: "page",
            name: "DESIGN",
            help: "How windows look: gaps, borders, rounding and opacity. Applied live to Hyprland.",
            sub: "GAPS · BORDERS · OPACITY",
            items: [
                {
                    kind: "slider",
                    key: "hypr.gapsIn",
                    name: "INNER GAPS",
                    help: "Space between neighbouring windows, in pixels.",
                    sub: "SPACE BETWEEN WINDOWS",
                    min: 0,
                    max: 40,
                    step: 1,
                    fmt: "int",
                    unit: "px"
                },
                {
                    kind: "slider",
                    key: "hypr.gapsOut",
                    name: "OUTER GAPS",
                    help: "Space between windows and the screen edge (or the bar), in pixels.",
                    sub: "SPACE TO THE SCREEN EDGE",
                    min: 0,
                    max: 80,
                    step: 1,
                    fmt: "int",
                    unit: "px"
                },
                {
                    kind: "slider",
                    key: "hypr.borderSize",
                    name: "BORDER SIZE",
                    help: "Thickness of the window borders, in pixels. 0 hides them.",
                    sub: "WINDOW BORDER THICKNESS",
                    min: 0,
                    max: 12,
                    step: 1,
                    fmt: "int",
                    unit: "px"
                },
                {
                    kind: "slider",
                    key: "hypr.rounding",
                    name: "WINDOW ROUNDING",
                    help: "Corner radius of windows, in pixels.",
                    sub: "CORNER RADIUS OF WINDOWS",
                    min: 0,
                    max: 30,
                    step: 1,
                    fmt: "int",
                    unit: "px"
                },
                {
                    kind: "slider",
                    key: "hypr.roundingPower",
                    name: "ROUNDING POWER",
                    help: "The shape of the rounded corners. 2 is a plain circle arc; higher is a softer, squircle-like curve.",
                    sub: "SQUIRCLE CURVE — HIGHER IS SOFTER",
                    min: 2,
                    max: 10,
                    step: 0.1,
                    fmt: "float1"
                },
                {
                    kind: "slider",
                    key: "hypr.activeOpacity",
                    name: "ACTIVE OPACITY",
                    help: "Opacity of the window you are working in. Below 100% it becomes see-through (frosted with BLUR).",
                    sub: "TRANSPARENCY OF THE FOCUSED WINDOW",
                    min: 0.3,
                    max: 1,
                    step: 0.01,
                    fmt: "percent"
                },
                {
                    kind: "slider",
                    key: "hypr.inactiveOpacity",
                    name: "INACTIVE OPACITY",
                    help: "Opacity of the windows you are not working in.",
                    sub: "TRANSPARENCY OF UNFOCUSED WINDOWS",
                    min: 0.3,
                    max: 1,
                    step: 0.01,
                    fmt: "percent"
                },
                {
                    kind: "toggle",
                    key: "hypr.unlockFade",
                    name: "WINDOWS FADE IN ON UNLOCK",
                    help: "When you unlock, open windows fade from invisible up to their opacity while the lock lets go, instead of popping in.",
                    sub: "OPEN WINDOWS RISE FROM 0 TO THEIR OPACITY WHILE THE LOCK LETS GO"
                },
                {
                    kind: "toggle",
                    key: "hypr.dimInactive",
                    name: "DIM INACTIVE",
                    help: "Darkens every window except the focused one.",
                    sub: "DARKEN WINDOWS THAT AREN'T FOCUSED"
                },
                {
                    kind: "slider",
                    key: "hypr.dimStrength",
                    name: "DIM STRENGTH",
                    help: "How dark DIM INACTIVE makes the other windows.",
                    sub: "HOW HARD THE DIM HITS",
                    min: 0,
                    max: 1,
                    step: 0.01,
                    fmt: "percent"
                }
            ]
        },
        {
            kind: "page",
            name: "EFFECTS",
            help: "Blur behind see-through windows, and drop shadows.",
            sub: "BLUR AND SHADOWS",
            items: [
                {
                    kind: "toggle",
                    key: "hypr.blur",
                    name: "BLUR",
                    help: "Frosts what is behind see-through windows and shell panels.",
                    sub: "BLUR BEHIND TRANSPARENT WINDOWS"
                },
                {
                    kind: "slider",
                    key: "hypr.blurSize",
                    name: "BLUR SIZE",
                    help: "The radius of each blur pass. Bigger is softer.",
                    sub: "RADIUS OF EACH BLUR PASS",
                    min: 1,
                    max: 20,
                    step: 1,
                    fmt: "int"
                },
                {
                    kind: "slider",
                    key: "hypr.blurPasses",
                    name: "BLUR PASSES",
                    help: "How many times the blur runs. More is smoother and costs more GPU time.",
                    sub: "MORE PASSES, MORE COST",
                    min: 1,
                    max: 6,
                    step: 1,
                    fmt: "int"
                },
                {
                    kind: "slider",
                    key: "hypr.blurNoise",
                    name: "BLUR NOISE",
                    help: "Fine grain over the blur that hides colour banding.",
                    sub: "GRAIN THAT HIDES BANDING",
                    min: 0,
                    max: 0.1,
                    step: 0.002,
                    fmt: "float2"
                },
                {
                    kind: "toggle",
                    key: "hypr.blurXray",
                    name: "BLUR X-RAY",
                    help: "X-RAY blurs only the wallpaper behind a window, ignoring the windows in between — cheaper and cleaner.",
                    sub: "BLUR THE WALLPAPER, NOT THE WINDOWS BELOW"
                },
                {
                    kind: "toggle",
                    key: "hypr.shadow",
                    name: "SHADOWS",
                    help: "Soft shadows behind windows.",
                    sub: "DROP SHADOWS BEHIND WINDOWS"
                },
                {
                    kind: "slider",
                    key: "hypr.shadowRange",
                    name: "SHADOW RANGE",
                    help: "How far the shadows spread, in pixels.",
                    sub: "HOW FAR THE SHADOW SPREADS",
                    min: 0,
                    max: 60,
                    step: 1,
                    fmt: "int",
                    unit: "px"
                },
                {
                    kind: "slider",
                    key: "hypr.shadowRenderPower",
                    name: "SHADOW FALLOFF",
                    help: "How quickly a shadow fades out. Higher is a tighter shadow.",
                    sub: "CURVE OF THE SHADOW GRADIENT",
                    min: 1,
                    max: 4,
                    step: 1,
                    fmt: "int"
                }
            ]
        },
        {
            kind: "page",
            name: "BEHAVIOUR",
            help: "How windows arrange themselves, and how you focus and resize them.",
            sub: "LAYOUT AND INPUT",
            items: [
                {
                    kind: "choice",
                    key: "hypr.layout",
                    name: "TILING LAYOUT",
                    help: "DWINDLE splits the space in half again and again as windows open; MASTER keeps one big window with the others stacked beside it.",
                    sub: "HOW NEW WINDOWS ARRANGE THEMSELVES",
                    options: [
                        {
                            value: "dwindle",
                            label: "DWINDLE"
                        },
                        {
                            value: "master",
                            label: "MASTER"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "hypr.resizeOnBorder",
                    name: "RESIZE ON BORDER",
                    help: "Drag a window's edge with the mouse to resize it.",
                    sub: "DRAG WINDOW EDGES TO RESIZE"
                },
                {
                    kind: "toggle",
                    key: "hypr.followMouse",
                    name: "FOCUS FOLLOWS MOUSE",
                    help: "The window under the pointer gets focus without clicking.",
                    sub: "HOVER TO FOCUS INSTEAD OF CLICKING"
                },
                {
                    kind: "toggle",
                    key: "hypr.vrr",
                    name: "VARIABLE REFRESH RATE",
                    help: "Lets a FreeSync/G-Sync screen change its refresh rate to match games and video — smoother, less tearing.",
                    sub: "FREESYNC / G-SYNC"
                },
                {
                    kind: "choice",
                    key: "hypr.vrrWhen",
                    when: { key: "hypr.vrr", is: true },
                    name: "VRR WHEN",
                    help: "ALWAYS lets the screen follow every frame, the desktop too. FULLSCREEN only while a window fills the screen — on an OLED the desktop then never flickers when its frame rate drops. GAMES only for fullscreen games and video.",
                    sub: "ALWAYS · FULLSCREEN (BEST FOR OLED) · GAMES AND VIDEO",
                    options: [
                        {
                            value: "always",
                            label: "ALWAYS"
                        },
                        {
                            value: "fullscreen",
                            label: "FULLSCREEN"
                        },
                        {
                            value: "games",
                            label: "GAMES AND VIDEO"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "hypr.animations",
                    name: "ANIMATIONS",
                    help: "Hyprland's window and workspace animations. Off makes everything instant.",
                    sub: "WINDOW AND WORKSPACE MOTION"
                }
            ]
        },
        {
            kind: "action",
            name: "RELOAD HYPRLAND",
            help: "Makes Hyprland re-read all of its config files now.",
            sub: "RE-READ EVERY CONFIG FILE",
            fn: "reloadHyprland"
        }
    ]

    // ================================================================== AUDIO
    readonly property var audio: [
        {
            kind: "slider",
            live: "volume",
            name: "MASTER OUTPUT",
            help: "The system output volume.",
            sub: "SYSTEM SPEAKER LEVEL",
            min: 0,
            max: 1,
            step: 0.01,
            fmt: "percent"
        },
        {
            kind: "toggle",
            live: "muteSpeaker",
            name: "MUTE SPEAKERS",
            help: "Mutes the speakers (the output device), not just one app.",
            sub: "HARDWARE MUTE THE OUTPUT SINK"
        },
        {
            kind: "slider",
            live: "micVolume",
            name: "MICROPHONE GAIN",
            help: "The microphone's input level.",
            sub: "INPUT RECORDING LEVEL",
            min: 0,
            max: 1,
            step: 0.01,
            fmt: "percent"
        },
        {
            kind: "toggle",
            live: "muteMic",
            name: "MUTE MICROPHONE",
            help: "Mutes the microphone (the input device).",
            sub: "HARDWARE MUTE THE INPUT SOURCE"
        },
        {
            kind: "slider",
            key: "services.volumeStep",
            name: "SCROLL STEP",
            help: "How much one wheel click or volume key changes the volume.",
            sub: "HOW MUCH ONE WHEEL CLICK MOVES VOLUME",
            min: 0.01,
            max: 0.25,
            step: 0.01,
            fmt: "percent"
        },
        {
            kind: "slider",
            key: "services.volumeOverdrive",
            name: "MAXIMUM VOLUME",
            help: "The highest volume you can set. Above 100% amplifies in software and can distort — use with care.",
            sub: "ABOVE 100% CLIPS — USE WITH CARE",
            min: 1.0,
            max: 1.5,
            step: 0.05,
            fmt: "percent"
        },
        {
            kind: "action",
            name: "AUDIO MIXER",
            help: "Opens pavucontrol: choose output and input devices and set per-app volumes.",
            sub: "PAVUCONTROL — ROUTING AND PER-APP LEVELS",
            exec: "pavucontrol"
        },
        {
            kind: "action",
            name: "EQUALISER",
            help: "Opens EasyEffects — equaliser, compressor, reverb — if it is installed (otherwise a toast says it is missing).",
            sub: "EASYEFFECTS — EQ, COMPRESSOR, REVERB",
            exec: "easyeffects"
        },
        {
            kind: "action",
            name: "BLUETOOTH",
            help: "Pair, connect and trust Bluetooth devices right inside the shell (QUICK SETTINGS).",
            sub: "PAIR, CONNECT AND TRUST — INSIDE THE SHELL, NO MANAGER APP",
            fn: "openBluetooth"
        },
        {
            kind: "page",
            name: "SOUND PROBLEMS",
            aka: "SOUND DROPS · TON BRICHT AB · BLUETOOTH ABBRÜCHE · AUSSETZER · LAUTSPRECHER · CRACKLE · STOTTERN",
            help: "Why the sound drops, cuts or turns thin — and what stops it. Velvet reads the facts itself: which output plays, how often a Bluetooth device dropped today (the journal says so), which band the Wi-Fi uses and which codec the Bluetooth sound runs. Two different devices dropping the same way is the PC's Bluetooth link, not the speakers.",
            sub: "DROPOUTS, THE CAUSE AND THE FIX",
            icon: "graphic_eq",
            items: [
                {
                    kind: "info",
                    name: "THE CAUSE",
                    help: "What the facts point to. Bluetooth shares the 2.4 GHz band with Wi-Fi — on a combined card (MediaTek, many Intel and Realtek ones) even one antenna — so a busy 2.4 GHz Wi-Fi is the most common reason Bluetooth sound stutters or drops. One device dropping alone can also be distance, a wall or a USB 3 port right next to the PC's antenna.",
                    sub: "WHAT THE FACTS POINT TO",
                    live: "soundVerdict"
                },
                {
                    kind: "info",
                    name: "PLAYS ON",
                    help: "The output that plays now, and how: the Bluetooth codec, or the kind of connection.",
                    sub: "THE OUTPUT AND ITS CODEC",
                    live: "soundPlays"
                },
                {
                    kind: "info",
                    name: "DROPOUTS",
                    help: "How often a Bluetooth device lost its link in the last 24 hours (WirePlumber logs every one), when the last one was, and on how many devices.",
                    sub: "BLUETOOTH, THE LAST 24 HOURS",
                    live: "soundDrops"
                },
                {
                    kind: "info",
                    name: "WI-FI BAND",
                    help: "The band your Wi-Fi uses. 2.4 GHz is Bluetooth's band. The fix: your router's 5 GHz network (QUICK → WI-FI shows each network's band), or a network cable — then Bluetooth has the air to itself.",
                    sub: "2.4 GHZ IS BLUETOOTH'S BAND",
                    live: "soundWifi"
                },
                {
                    kind: "toggle",
                    key: "services.btReconnect",
                    name: "RECONNECT AFTER A DROP",
                    aka: "AUTO RECONNECT · WIEDER VERBINDEN",
                    help: "When a Bluetooth device's link breaks (not when you switch it off), Velvet connects it again — after 2, 8 and 25 seconds — and the sound goes back to it.",
                    sub: "A DROPPED DEVICE COMES BACK BY ITSELF"
                },
                {
                    kind: "choice",
                    key: "services.btQuality",
                    name: "BLUETOOTH SOUND",
                    aka: "CODEC · APTX · LDAC · SBC · AAC",
                    help: "BEST is the codec with the most detail (aptX HD, LDAC) — and the highest bitrate, the first to break up when the air is busy. STABLE takes aptX, AAC or SBC: a lower bitrate that rides out a busy band, you will hardly hear the difference. SAFEST is plain SBC. Applied to every Bluetooth output the moment it connects.",
                    sub: "STABLE IF IT DROPS",
                    options: [
                        { value: "best", label: "BEST · APTX HD, LDAC" },
                        { value: "stable", label: "STABLE · APTX, AAC, SBC" },
                        { value: "safest", label: "SAFEST · SBC" }
                    ]
                },
                {
                    kind: "toggle",
                    live: "keepMusicQuality",
                    name: "KEEP MUSIC QUALITY",
                    aka: "HEADSET MODE · HFP · CALL MODE · MONO",
                    help: "An app that opens a microphone (a call, Discord, a game) can switch a Bluetooth headset into its call mode: mono, thin, telephone sound. On, the headset stays in music mode — right when you speak into another microphone. This is WirePlumber's own setting, saved by WirePlumber.",
                    sub: "NO THIN CALL MODE WHEN AN APP OPENS A MIC"
                },
                {
                    kind: "action",
                    fn: "soundTest",
                    name: "PLAY A TEST SOUND",
                    aka: "SOUND TEST · TESTTON",
                    help: "A short chime on the output that plays now. Heard it clean? The output and the device work — a problem is in the app or the stream. Switch the output in the bar's sound menu and test the next one to compare.",
                    sub: "A SHORT CHIME ON THE OUTPUT THAT PLAYS NOW"
                },
                {
                    kind: "action",
                    fn: "openQuick",
                    name: "WI-FI NETWORKS AND THEIR BANDS",
                    help: "Opens QUICK: every network shows its band (2.4 GHZ or 5 GHZ). Join the 5 GHz one of your router to give Bluetooth its band back.",
                    sub: "JOIN A 5 GHZ NETWORK"
                }
            ]
        },
        {
            kind: "action",
            name: "RESTART SOUND SERVER",
            help: "Restarts PipeWire, its Pulse layer and WirePlumber. Fixes missing sound or stuck devices; audio cuts out for a moment.",
            sub: "RELOAD PIPEWIRE AND WIREPLUMBER",
            exec: "systemctl --user restart pipewire pipewire-pulse wireplumber"
        }
    ]

    // ================================================================ DISPLAY
    readonly property var display: [
        {
            kind: "toggle",
            key: "display.manage",
            name: "AUTO SCREEN SETUP",
            aka: "RESOLUTION AUTO · AUFLÖSUNG AUTOMATISCH · SCREEN SIZE",
            help: "Velvet reads every screen itself — its own resolution and its size, from the screen's EDID — and sets the sharpest resolution, the fastest refresh at it and a scale that suits its size: at every start, whenever a screen is plugged in, and again after a Hyprland config reload. Written into velvet.lua too, so the next login starts right. Off: the monitor lines in your hyprland.lua decide.",
            sub: "THE SCREEN'S OWN RESOLUTION AND THE RIGHT SIZE — AUTOMATICALLY"
        },
        {
            kind: "choice",
            key: "display.mode",
            name: "RESOLUTION",
            aka: "AUFLÖSUNG · REFRESH RATE · HZ · MODE",
            help: "AUTO is the screen's own resolution (the sharpest — anything else is scaled and soft) at the fastest refresh that works on its port. A mode the screen lists but the port or cable cannot carry (4K at 240 Hz over HDMI often fails: no signal, the screen drops out) is noticed the moment it fails, remembered for that port, and AUTO steps down to the fastest mode below it. SAFE is the screen's own resolution at 60 Hz — every cable carries it. Pick another to override it; it only applies to a screen that offers that mode, and only while AUTO SCREEN SETUP is on.",
            sub: "AUTO = THE SCREEN'S OWN, AT THE FASTEST REFRESH THAT WORKS",
            options: Config.monitorModes
        },
        {
            kind: "info",
            name: "RIGHT NOW",
            aka: "SCREEN STATUS · MONITOR · KEIN SIGNAL · NO SIGNAL",
            help: "What every screen runs now, and which modes failed on its port. A screen that shows NO EDID did not say what it is — usually a loose or too-long cable, or the screen still waking up.",
            sub: "WHAT EACH SCREEN RUNS — AND WHAT FAILED",
            live: "screenStatus"
        },
        {
            kind: "action",
            fn: "screensForget",
            name: "TRY THE FAST MODES AGAIN",
            aka: "240 HZ · RETRY · FORGET FAILED MODES · NEU VERSUCHEN",
            help: "Forgets which modes failed on which port and puts every screen on its fastest mode again — after you changed the cable or the port. Should the picture go black: Super + Ctrl + Alt + R puts every screen on 60 Hz, even when the shell itself is stuck (or run  velvet display safe).",
            sub: "AFTER A NEW CABLE · BLACK SCREEN? SUPER+CTRL+ALT+R"
        },
        {
            kind: "choice",
            key: "display.scale",
            name: "SCALE",
            aka: "SKALIERUNG · UI SIZE · GRÖSSE · ZOOM",
            help: "How big everything is drawn. AUTO aims at about 110 logical dots per inch from the screen's real size: 1 on ordinary and coarse screens, 1.5 on a 27\" 4K, 2 on a sharp laptop panel — never below 1, which only blurs. Pick a number to override it.",
            sub: "AUTO = FITS THE SCREEN'S SIZE",
            options: [
                { value: "auto", label: "AUTO" },
                { value: "1", label: "1× · 100 %" },
                { value: "1.25", label: "1.25× · 125 %" },
                { value: "1.5", label: "1.5× · 150 %" },
                { value: "1.75", label: "1.75× · 175 %" },
                { value: "2", label: "2× · 200 %" },
                { value: "2.5", label: "2.5× · 250 %" },
                { value: "3", label: "3× · 300 %" }
            ]
        },
        {
            kind: "slider",
            live: "brightness",
            name: "BRIGHTNESS",
            help: "Screen brightness — brightnessctl for built-in panels, ddcutil for external monitors that support DDC.",
            sub: "PANEL BACKLIGHT LEVEL",
            min: 0.01,
            max: 1,
            step: 0.01,
            fmt: "percent"
        },
        {
            kind: "slider",
            key: "services.brightnessStep",
            name: "BRIGHTNESS STEP",
            help: "How much one wheel click or brightness key changes the brightness.",
            sub: "HOW MUCH ONE WHEEL CLICK MOVES BRIGHTNESS",
            min: 0.01,
            max: 0.25,
            step: 0.01,
            fmt: "percent"
        },
        {
            kind: "toggle",
            key: "services.nightLight",
            name: "NIGHT LIGHT",
            help: "Warms the screen colour to go easier on the eyes at night (hyprsunset, wlsunset or gammastep — whichever is installed).",
            sub: "WARM THE SCREEN AFTER DARK"
        },
        {
            kind: "slider",
            key: "services.nightLightTemp",
            name: "COLOUR TEMPERATURE",
            help: "How warm the night light is, in Kelvin. Lower is warmer and more orange; 6500 K is neutral.",
            sub: "LOWER IS WARMER",
            min: 2000,
            max: 6500,
            step: 100,
            fmt: "int",
            unit: "K"
        },
        {
            kind: "toggle",
            key: "services.idleInhibit",
            name: "KEEP AWAKE",
            help: "Stops the screen from blanking and the machine from sleeping while this is on.",
            sub: "BLOCK IDLE AND SLEEP ENTIRELY"
        },
        {
            kind: "action",
            name: "DISPLAY LAYOUT",
            help: "Opens nwg-displays (or wdisplays) to arrange your monitors — if one of them is installed.",
            sub: "NWG-DISPLAYS — ARRANGE MONITORS",
            exec: "nwg-displays || wdisplays"
        }
    ]

    // ============================================================== WALLPAPER
    readonly property var wallpaper: [
        {
            kind: "carousel",
            name: "BROWSE WALLPAPERS",
            help: "Browse the wallpapers in your folder. Enter applies one, F marks it as a favourite.",
            sub: "ENTER APPLIES · F FAVOURITES"
        },
        {
            kind: "page",
            name: "LIVE WALLPAPERS",
            aka: "LIVE WALLPAPER · LEBENDIGES WALLPAPER · BEWEGTES HINTERGRUNDBILD · GIF · ANIMIERT · ANIMATED",
            help: "Your favourite wallpapers, moving. For every wallpaper you star, Velly reads the picture — its colours, its light, its little stars — and makes it move the way it suits: leaves fall through an autumn road, stars twinkle on a night sky, mist drifts through a forest, light breathes round what glows on black, a sheen sweeps across a poster. A seamless loop, played over the untouched picture (every pixel of the still stays), and a GIF to keep or share. One at a time, at the lowest priority, never while a game runs.",
            sub: "VELLY MAKES EVERY FAVOURITE MOVE · A SEAMLESS LOOP AND A GIF",
            icon: "animation",
            items: [
                {
                    kind: "info",
                    name: "RIGHT NOW",
                    help: "What Velly is making, what waits, how many favourites already move — and the last thing that went wrong, if anything did.",
                    sub: "WHAT VELLY IS MAKING",
                    live: "liveStatus"
                },
                {
                    kind: "info",
                    name: "THIS WALLPAPER",
                    help: "What the wallpaper that is up does: the style Velly chose for it and its loop — or that it is a still so far.",
                    sub: "ITS STYLE AND ITS LOOP",
                    live: "liveThis"
                },
                {
                    kind: "toggle",
                    live: "liveThisMoves",
                    name: "THIS WALLPAPER MOVES",
                    aka: "DIESES WALLPAPER · AUSSCHALTEN · STILL · STANDBILD",
                    help: "Only the wallpaper that is up. Off: it stays its still, and Velly does not make it again — even as a favourite. On again: it moves (and Velly makes it if it has no motion yet).",
                    sub: "OFF: THIS ONE STAYS A STILL"
                },
                {
                    kind: "text",
                    key: "wallpaper.livePrompt",
                    name: "DESCRIBE THE MOTION",
                    aka: "PROMPT · BESCHREIBUNG · WÜNSCH DIR · EFFEKT BESCHREIBEN",
                    help: "Say in your own words what should move and how — German or English: what (leaves, petals, snow, rain, stars, fireflies, floating light, mist, glow, sheen, rays), how much (viel, wenig), how fast (langsam, schnell), how strong (dezent, kräftig), how big (klein, groß), a colour (gold, rosa, blau, #ff8800 …), the wind (von links, nach rechts, windstill) — and what not (kein Nebel, ohne Blätter). Velly shows what she reads while you type. Empty: she reads the picture and chooses.",
                    sub: "IN YOUR OWN WORDS · VELLY SHOWS WHAT SHE READS",
                    placeholder: "e.g. langsamer goldener Schnee, sehr viel, kein Nebel",
                    examples: ["langsamer goldener Schnee, sehr viel", "rote Blätter von links, schnell", "dezente blaue Glühwürmchen", "Sterne funkeln, kein Nebel", "rosa Blüten, wenige, groß", "warmes Leuchten, langsam", "Regen, kräftig, windstill"],
                    understand: "livewall",
                    then: "liveMakePrompt",
                    thenLabel: "SAVE AND MAKE IT",
                    empty: "EMPTY · VELLY CHOOSES"
                },
                {
                    kind: "info",
                    name: "VELLY READS",
                    help: "What Velly understood from the description — exactly what she will make.",
                    sub: "WHAT SHE WILL MAKE OF IT",
                    live: "livePromptRead"
                },
                {
                    kind: "action",
                    fn: "liveMakePrompt",
                    name: "MAKE IT LIKE THIS",
                    aka: "MIT PROMPT · SO MACHEN",
                    help: "Makes the wallpaper that is up with the description and the settings below — about a minute, first in Velly's queue. The version before is kept: BACK TO THE LAST VERSION brings it back.",
                    sub: "THE DESCRIPTION + THE SETTINGS BELOW · ABOUT A MINUTE"
                },
                {
                    kind: "action",
                    fn: "liveRemakeThis",
                    name: "A FRESH TAKE",
                    aka: "NEU MACHEN · REMAKE · ANDERE VARIANTE · GEFÄLLT MIR NICHT",
                    help: "Not quite right? Velly makes it again — the same settings and description, but a new take: everything falls, floats and twinkles in other places. Each press is another one; the one before is kept.",
                    sub: "SAME SETTINGS, NEW PLACES · THE OLD ONE IS KEPT"
                },
                {
                    kind: "action",
                    fn: "liveUndo",
                    name: "BACK TO THE LAST VERSION",
                    aka: "RÜCKGÄNGIG · UNDO · ZURÜCK",
                    help: "The version before the last remake comes back. Press again to go forward to the newer one.",
                    sub: "PRESS AGAIN TO GO FORWARD"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.liveOn",
                    name: "PLAY LIVE WALLPAPERS",
                    aka: "LIVE AN · AUS",
                    help: "Plays the live version of a wallpaper that has one. Off: every wallpaper is its still again (what was made stays). It needs FIT = FILL and the built-in renderer.",
                    sub: "OFF: THE STILLS AGAIN · WHAT WAS MADE STAYS"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.liveAuto",
                    name: "VELLY MAKES THEM FOR FAVOURITES",
                    aka: "AUTOMATISCH · AUTO · FAVORITEN",
                    help: "Velly's standing job: every wallpaper you star becomes live by itself, a few seconds after the star — and anything that was missed (a game that interrupted her, a picture that changed) is picked up every half hour.",
                    sub: "STAR A WALLPAPER — IT STARTS MOVING"
                },
                {
                    kind: "slider",
                    key: "wallpaper.liveStrength",
                    name: "STRENGTH",
                    aka: "STÄRKE · OPACITY",
                    help: "How much of the motion shows — at once, on every live wallpaper, nothing is made again. 0 leaves only the still.",
                    sub: "AT ONCE · NOTHING IS MADE AGAIN",
                    min: 0,
                    max: 1,
                    step: 0.05,
                    fmt: "percent"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.livePauseBehind",
                    name: "REST BEHIND WINDOWS",
                    aka: "PAUSE · AKKU · GPU",
                    help: "The live wallpaper moves only while you can see it: windows that fill the screen pause it, as do a game, the lock and the wallpaper wheel. A moving wallpaper makes the screen redraw all the time — behind windows that is work for nobody.",
                    sub: "IT MOVES ONLY WHILE YOU CAN SEE IT"
                },
                {
                    kind: "choice",
                    key: "wallpaper.liveStyle",
                    name: "STYLE",
                    aka: "EFFEKT · BLÄTTER · STERNE · NEBEL · SCHNEE · REGEN",
                    help: "AUTO lets Velly read each picture and choose: twinkling stars for a night sky, falling leaves for autumn, mist and petals for a soft forest, breathing light for black and white, a sheen for a poster. Or one style for every new one. Changing it affects what is made next — REMAKE puts it on this wallpaper.",
                    sub: "AUTO: VELLY READS EACH PICTURE · APPLIES TO WHAT IS MADE NEXT",
                    options: [
                        { value: "auto", label: "AUTO · VELLY CHOOSES" },
                        { value: "leaves", label: "FALLING LEAVES" },
                        { value: "petals", label: "DRIFTING PETALS" },
                        { value: "snow", label: "SNOW" },
                        { value: "rain", label: "RAIN" },
                        { value: "stars", label: "TWINKLING STARS" },
                        { value: "fireflies", label: "FIREFLIES" },
                        { value: "dust", label: "FLOATING LIGHT" },
                        { value: "fog", label: "DRIFTING MIST" },
                        { value: "glow", label: "BREATHING LIGHT" },
                        { value: "sheen", label: "A SHEEN OF LIGHT" },
                        { value: "rays", label: "LIGHT RAYS" }
                    ]
                },
                {
                    kind: "choice",
                    key: "wallpaper.liveColour",
                    name: "COLOUR",
                    aka: "FARBE",
                    help: "The colour of what moves: the picture's own (Velly takes it from the picture), or one for all. A colour in the description wins over this.",
                    sub: "THE PICTURE'S OWN, OR ONE · FOR WHAT IS MADE NEXT",
                    options: [
                        { value: "picture", label: "THE PICTURE'S OWN" },
                        { value: "gold", label: "GOLD" },
                        { value: "white", label: "WHITE" },
                        { value: "silver", label: "SILVER" },
                        { value: "red", label: "RED" },
                        { value: "orange", label: "ORANGE" },
                        { value: "pink", label: "PINK" },
                        { value: "purple", label: "PURPLE" },
                        { value: "blue", label: "BLUE" },
                        { value: "turquoise", label: "TURQUOISE" },
                        { value: "green", label: "GREEN" }
                    ]
                },
                {
                    kind: "slider",
                    key: "wallpaper.liveScale",
                    name: "SIZE",
                    aka: "GRÖSSE · PARTIKELGRÖSSE",
                    help: "How big what falls, floats and twinkles is: tiny dust or big leaves. For what is made next.",
                    sub: "FOR WHAT IS MADE NEXT",
                    min: 0.4,
                    max: 2.5,
                    step: 0.1,
                    fmt: "float1",
                    unit: "×"
                },
                {
                    kind: "choice",
                    key: "wallpaper.liveWind",
                    name: "WIND",
                    aka: "WINDRICHTUNG",
                    help: "Where what falls drifts: AUTO lets some leaves ride a breeze to the right, LEFT and RIGHT send most along, NONE lets everything fall straight (rain too).",
                    sub: "FOR WHAT IS MADE NEXT",
                    options: [
                        { value: "auto", label: "AUTO · A BREEZE" },
                        { value: "left", label: "TO THE LEFT" },
                        { value: "right", label: "TO THE RIGHT" },
                        { value: "none", label: "NONE · STRAIGHT DOWN" }
                    ]
                },
                {
                    kind: "slider",
                    key: "wallpaper.liveIntensity",
                    name: "INTENSITY",
                    aka: "INTENSITÄT",
                    help: "How strongly the motion is made: brighter light, more opaque leaves. For what is made next — REMAKE for this one.",
                    sub: "FOR WHAT IS MADE NEXT",
                    min: 0.3,
                    max: 1.6,
                    step: 0.1,
                    fmt: "float1",
                    unit: "×"
                },
                {
                    kind: "slider",
                    key: "wallpaper.liveAmount",
                    name: "AMOUNT",
                    aka: "MENGE · ANZAHL · PARTIKEL",
                    help: "How much falls, floats and twinkles. For what is made next.",
                    sub: "HOW MUCH FALLS AND FLOATS",
                    min: 0.3,
                    max: 2,
                    step: 0.1,
                    fmt: "float1",
                    unit: "×"
                },
                {
                    kind: "slider",
                    key: "wallpaper.liveSpeed",
                    name: "SPEED",
                    aka: "TEMPO · GESCHWINDIGKEIT",
                    help: "How fast it moves. Every motion still comes round exactly once per loop — the loop never shows a seam. For what is made next.",
                    sub: "SEAMLESS AT ANY SPEED",
                    min: 0.5,
                    max: 2,
                    step: 0.1,
                    fmt: "float1",
                    unit: "×"
                },
                {
                    kind: "choice",
                    key: "wallpaper.liveSeconds",
                    name: "LOOP",
                    aka: "LÄNGE · DAUER",
                    help: "How long the loop is before it begins again — seamlessly either way. Longer loops repeat less visibly and take a little longer to make.",
                    sub: "LONGER REPEATS LESS VISIBLY",
                    options: [
                        { value: 6, label: "6 SECONDS" },
                        { value: 8, label: "8 SECONDS" },
                        { value: 10, label: "10 SECONDS" },
                        { value: 14, label: "14 SECONDS" },
                        { value: 20, label: "20 SECONDS" }
                    ]
                },
                {
                    kind: "choice",
                    key: "wallpaper.liveFps",
                    name: "SMOOTHNESS",
                    aka: "FPS · BILDRATE",
                    help: "Frames per second of the motion. 30 is smooth for drifting things; 60 for fast rain or a high-refresh screen (twice the file, twice the work to make).",
                    sub: "30 FOR DRIFT · 60 FOR FAST MOTION",
                    options: [
                        { value: 24, label: "24 FPS · FILM" },
                        { value: 30, label: "30 FPS" },
                        { value: 60, label: "60 FPS" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "wallpaper.liveGif",
                    name: "MAKE A GIF TOO",
                    aka: "GIF",
                    help: "Every live wallpaper also becomes a GIF — the picture with its motion, to keep or send.",
                    sub: "THE PICTURE WITH ITS MOTION, TO SEND"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.liveGifPictures",
                    name: "GIFS IN YOUR PICTURES",
                    aka: "BILDER-ORDNER",
                    help: "A copy of every GIF goes to your Pictures folder → Velvet Live, where you find it.",
                    sub: "PICTURES → VELVET LIVE",
                    when: { key: "wallpaper.liveGif", is: true }
                },
                {
                    kind: "choice",
                    key: "wallpaper.liveGifWidth",
                    name: "GIF SIZE",
                    help: "How wide the GIF is. A GIF holds 256 colours per frame and grows fast: 800 is sharp for a chat and stays small.",
                    sub: "800 IS SHARP AND STAYS SMALL",
                    when: { key: "wallpaper.liveGif", is: true },
                    options: [
                        { value: 480, label: "480 PX · TINY" },
                        { value: 640, label: "640 PX" },
                        { value: 800, label: "800 PX" },
                        { value: 1280, label: "1280 PX · BIG FILES" }
                    ]
                },
                {
                    kind: "action",
                    fn: "liveMakeThis",
                    name: "MAKE THIS WALLPAPER LIVE",
                    aka: "JETZT · DIESES",
                    help: "Velly makes the wallpaper that is up live now — a favourite or not — with the style and settings above (about a minute; it is first in her queue).",
                    sub: "NOW · FIRST IN VELLY'S QUEUE"
                },
                {
                    kind: "action",
                    fn: "liveMakeAll",
                    name: "MAKE EVERY FAVOURITE LIVE",
                    help: "Queues every favourite that does not move yet — Velly makes them one after another.",
                    sub: "ONE AFTER ANOTHER"
                },
                {
                    kind: "action",
                    fn: "liveRemakeAll",
                    name: "REMAKE ALL FAVOURITES",
                    help: "Makes every favourite again with the style and settings as they are now (about a minute each).",
                    sub: "WITH THE SETTINGS AS THEY ARE NOW",
                    danger: true
                },
                {
                    kind: "action",
                    fn: "liveStop",
                    name: "STOP",
                    help: "Stops what Velly is making and empties her queue. She starts again when you star a wallpaper or ask her.",
                    sub: "EMPTIES THE QUEUE"
                },
                {
                    kind: "action",
                    fn: "liveOpenFolder",
                    name: "OPEN THE GIFS",
                    help: "Opens Pictures → Velvet Live, where the GIFs are.",
                    sub: "PICTURES → VELVET LIVE"
                },
                {
                    kind: "action",
                    fn: "liveDeleteAll",
                    name: "DELETE EVERY LIVE WALLPAPER",
                    help: "Deletes everything Velly made (the GIFs in your Pictures stay — they are yours). The stills are never touched.",
                    sub: "THE STILLS ARE NEVER TOUCHED",
                    danger: true
                }
            ]
        },
        {
            kind: "toggle",
            key: "wallpaper.living",
            name: "LIVING DESKTOP",
            help: "Widgets and living light on the wallpaper itself — the whole living desktop in one switch.",
            sub: "WIDGETS AND LIVING LIGHT ON THE WALLPAPER ITSELF"
        },
        {
            kind: "page",
            name: "LIVING DESKTOP",
            help: "The wallpaper as a living place: widgets placed on it, light that follows the time of day, ripples, aurora.",
            sub: "THE WALLPAPER AS A LIVING PLACE",
            items: [
                {
                    kind: "info",
                    name: "BUILT-IN RENDERER ONLY",
                    help: "These effects run on Velvet's own wallpaper layer (RENDERER = BUILT-IN), not on swww or hyprpaper.",
                    sub: "LIVING EFFECTS RIDE VELVET'S OWN WALLPAPER LAYER — NOT SWWW"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.living",
                    name: "LIVING DESKTOP",
                    help: "Everything on this page at once.",
                    sub: "EVERYTHING ON THIS PAGE, ONE SWITCH"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.livingWidgets",
                    name: "WIDGETS ON THE WALLPAPER",
                    help: "Shows the widgets you placed in the DESKTOP tab (clock, weather, music …) on the wallpaper.",
                    sub: "CLOCK, WEATHER, MEDIA… PLACED IN DESKTOP → ARRANGE IT"
                },
                {
                    kind: "choice",
                    key: "wallpaper.livingChips",
                    name: "WIDGET FRAME",
                    help: "How widgets are drawn. SHAPES are morphing Material silhouettes in the wallpaper's tones; SOFT are the round inspo pieces (clock in a gear, weather in a slanted pill, the music card) in the soft tone; GLASS is frosted glass; INK a dark ground; RAW sits straight on the picture. Each widget can override this in the DESKTOP tab.",
                    sub: "SHAPES MORPH · SOFT IS THE ROUND MATERIAL LOOK · GLASS FLOATS · INK GROUNDS · RAW MELTS IN",
                    options: [
                        { value: "shapes", label: "SHAPES" },
                        { value: "soft", label: "SOFT" },
                        { value: "glass", label: "GLASS" },
                        { value: "ink", label: "INK" },
                        { value: "raw", label: "RAW" }
                    ]
                },
                {
                    kind: "choice",
                    key: "wallpaper.shapeTone",
                    name: "SHAPE TONE",
                    help: "For the SHAPES frame: DEEP tones for a dark desktop, PASTEL for a light one.",
                    sub: "FOR THE SHAPES FRAME · DEEP FOR A DARK DESKTOP, PASTEL FOR A LIGHT ONE",
                    options: [
                        { value: "deep", label: "DEEP" },
                        { value: "pastel", label: "PASTEL" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "wallpaper.shapeMotion",
                    name: "SHAPE MOTION",
                    help: "Shapes morph with the weather, clock digits roll, bars fill. Off keeps every widget still.",
                    sub: "SHAPES MORPH WITH THE WEATHER · DIGITS ROLL · BARS FILL · NEVER IDLE"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.shapeHoverMorph",
                    name: "SHAPES CHANGE ON HOVER",
                    help: "Point at a widget in the SHAPES or SOFT frame and its shape morphs into another — and back when the pointer leaves. Each widget's HOVER SHAPE (right-click it → edit, or DESKTOP) picks which one; AUTO takes a partner of its own, STAY keeps it still.",
                    sub: "POINT AT A WIDGET AND ITS SHAPE MORPHS · PER WIDGET: HOVER SHAPE"
                },
                {
                    kind: "slider",
                    key: "wallpaper.livingScale",
                    name: "WIDGET SIZE",
                    help: "Scales every widget. The box you dragged for a widget in the DESKTOP tab is always the limit.",
                    sub: "GLOBAL SCALE FOR EVERY WIDGET · THE BOX YOU DRAGGED IS THE LIMIT",
                    min: 0.5,
                    max: 2,
                    step: 0.05,
                    fmt: "float2",
                    unit: "×"
                },
                {
                    kind: "slider",
                    key: "wallpaper.livingOpacity",
                    name: "CHIP OPACITY",
                    help: "How solid the widget backgrounds are. Hovering a widget makes it more solid.",
                    sub: "HOW SOLID THE WIDGET CHIPS ARE",
                    min: 0.3,
                    max: 1,
                    step: 0.01,
                    fmt: "percent"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.livingEntrance",
                    name: "GLIDE IN",
                    help: "Widgets float into place when the wallpaper loads.",
                    sub: "WIDGETS FLOAT INTO PLACE WHEN THE WALLPAPER LOADS"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.livingDepth",
                    name: "DEPTH ON A DESKTOP SWITCH",
                    help: "Switching desktops, the picture moves a few pixels the way your windows slide and springs back; the widgets, nearer, move a little more — the desktop has depth. Follows Hyprland's own workspace animation (up and down, sideways, or a breath of zoom).",
                    sub: "THE PICTURE AND THE WIDGETS MOVE WITH YOUR WINDOWS — AND SPRING BACK"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.livingRipples",
                    name: "WINDOW RIPPLES",
                    help: "A ring of accent light spreads from where a new window opens.",
                    sub: "AN ACCENT WAVE WHERE A NEW WINDOW LANDS"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.livingTimeTint",
                    name: "DAY AND NIGHT",
                    help: "The wallpaper warms slightly at sunset and cools after midnight.",
                    sub: "THE PICTURE WARMS AT SUNSET AND COOLS AFTER MIDNIGHT"
                },
                {
                    kind: "toggle",
                    key: "wallpaper.livingAurora",
                    name: "AURORA",
                    help: "A slow drift of accent light over the wallpaper. It never sits still, so it costs a little GPU all the time.",
                    sub: "A SLOW DRIFT OF ACCENT LIGHT — A DESKTOP THAT NEVER SITS STILL"
                },
                {
                    kind: "action",
                    fn: "openDesktopTab",
                    name: "PLACE THE WIDGETS",
                    help: "Opens the DESKTOP tab, where you drag widgets onto a picture of your screen.",
                    sub: "DRAG THEM ONTO THE DESKTOP TAB'S PICTURE OF YOUR SCREEN"
                }
            ]
        },
        {
            kind: "action",
            name: "THE WHEEL",
            help: "Opens the Super+W wallpaper wheel now.",
            sub: "SUPER+W · YOUR LIBRARY ON A RING",
            fn: "openWheel"
        },
        {
            kind: "page",
            name: "WALLPAPER LOOKS",
            help: "Everything in the settings can be different per wallpaper: colours, where the taskbar sits, window opacity and design, the lock screen, the desktop and the rest. Switch wallpaper and its settings come back. Not the same as the LOOKS tab, which holds whole-shell presets.",
            sub: "EVERY SETTING, PER WALLPAPER",
            items: [
                {
                    kind: "action",
                    fn: "openWallpaperTab",
                    name: "OPEN THE PER WALLPAPER TAB",
                    help: "The easy way to see and manage all of this: the wallpaper that is up, what it remembers, and every wallpaper that has a look.",
                    sub: "SEE AND MANAGE EVERY WALLPAPER'S LOOK IN ONE PLACE"
                },
                {
                    kind: "toggle",
                    key: "looks.enabled",
                    name: "SETTINGS PER WALLPAPER",
                    help: "Switching to a wallpaper restores the settings you had with it. Off: wallpapers never change your settings.",
                    sub: "SWITCH WALLPAPER, GET THAT WALLPAPER'S SETTINGS BACK"
                },
                {
                    kind: "toggle",
                    key: "looks.autoSave",
                    name: "REMEMBER AUTOMATICALLY",
                    help: "Any change you make is saved against the wallpaper that is up, automatically. Off: only SAVE THIS LOOK NOW stores it.",
                    sub: "TWEAK ANYTHING AND IT IS KEPT AGAINST THIS WALLPAPER"
                },
                {
                    kind: "toggle",
                    key: "looks.includeBar",
                    name: "TASKBAR",
                    help: "Where the taskbar sits, its size, opacity, frame, clock and status icons — per wallpaper.",
                    sub: "POSITION, SIZE, OPACITY, FRAME, ICONS"
                },
                {
                    kind: "toggle",
                    key: "looks.includeWindows",
                    name: "WINDOWS",
                    help: "Window opacity (focused and unfocused), gaps, rounding, borders, blur and shadows — per wallpaper.",
                    sub: "OPACITY, GAPS, ROUNDING, BORDERS, BLUR"
                },
                {
                    kind: "toggle",
                    key: "looks.includeLock",
                    name: "LOCK SCREEN",
                    help: "The lock screen's style, clock, widgets, motion and blur — per wallpaper.",
                    sub: "STYLE, CLOCK, WIDGETS, MOTION"
                },
                {
                    kind: "toggle",
                    key: "looks.includeDesktop",
                    name: "DESKTOP AND CANVAS",
                    help: "The living desktop's look and the window map / infinite canvas settings — per wallpaper. The widgets themselves are always per wallpaper (DESKTOP tab).",
                    sub: "LIVING DESKTOP, WIDGET LOOK, WINDOW MAP"
                },
                {
                    kind: "toggle",
                    key: "looks.includeMore",
                    name: "EVERYTHING ELSE",
                    help: "Launcher, notifications, OSD, lyrics, sounds and the audio visuals — per wallpaper. Colours and style are always part of a look.",
                    sub: "LAUNCHER, NOTIFICATIONS, OSD, LYRICS, SOUNDS"
                },
                {
                    kind: "info",
                    help: "How many wallpapers have a look saved.",
                    name: "SAVED LOOKS",
                    live: "looksCount"
                },
                {
                    kind: "action",
                    name: "SAVE THIS LOOK NOW",
                    help: "Stores the current settings for the current wallpaper right now.",
                    sub: "PIN THE CURRENT SETTINGS TO THE CURRENT WALLPAPER",
                    fn: "saveLook"
                },
                {
                    kind: "action",
                    name: "FORGET THIS LOOK",
                    help: "The current wallpaper forgets its look and stops changing your settings.",
                    sub: "THIS WALLPAPER STOPS CHANGING ANYTHING",
                    fn: "forgetLook"
                },
                {
                    kind: "action",
                    name: "FORGET EVERY LOOK",
                    help: "Every wallpaper forgets its look.",
                    sub: "CLEAR THE WHOLE TABLE",
                    fn: "forgetAllLooks",
                    danger: true
                }
            ]
        },
        {
            kind: "choice",
            key: "wallpaper.renderer",
            name: "RENDERER",
            help: "BUILT-IN draws the wallpaper with Velvet itself — no extra program, it comes back after a reboot, and the living desktop needs it. SWWW / HYPRPAPER hands the image to that program instead.",
            sub: "BUILT-IN NEEDS NO DAEMON AND SURVIVES A REBOOT",
            options: [
                {
                    value: "builtin",
                    label: "BUILT-IN"
                },
                {
                    value: "external",
                    label: "SWWW / HYPRPAPER"
                }
            ]
        },
        {
            kind: "choice",
            key: "wallpaper.fillMode",
            name: "FIT",
            help: "How the picture covers the screen. FILL crops it to fill the screen, CONTAIN shows it whole with bars, STRETCH distorts it to fit.",
            sub: "HOW THE IMAGE COVERS THE SCREEN",
            options: [
                {
                    value: "fill",
                    label: "FILL"
                },
                {
                    value: "fit",
                    label: "CONTAIN"
                },
                {
                    value: "stretch",
                    label: "STRETCH"
                }
            ]
        },
        {
            kind: "toggle",
            key: "wallpaper.transition",
            name: "TRANSITION",
            help: "Crossfades from the old wallpaper to the new one instead of cutting.",
            sub: "CROSSFADE THE SWAP INSTEAD OF CUTTING"
        },
        {
            kind: "slider",
            key: "wallpaper.fadeDuration",
            name: "FADE LENGTH",
            help: "How long that crossfade takes, in milliseconds.",
            sub: "HOW LONG THE CROSSFADE TAKES",
            min: 100,
            max: 3000,
            step: 50,
            fmt: "int",
            unit: "ms"
        },
        {
            kind: "toggle",
            key: "wallpaper.kenBurns",
            name: "SLOW DRIFT",
            help: "A very slow zoom and drift so the desktop feels alive. It pauses while the lock, settings or wheel are open.",
            sub: "IMPERCEPTIBLE ZOOM SO THE DESKTOP FEELS ALIVE"
        },
        {
            kind: "toggle",
            key: "wallpaper.vignette",
            name: "CINEMATIC SHADE",
            help: "A soft dark gradient across the image so text and widgets read better.",
            sub: "A SOFT GRADIENT ACROSS THE IMAGE, LIKE THE OLD CAROUSEL"
        },
        {
            kind: "slider",
            key: "wallpaper.rotateMinutes",
            name: "AUTO-ROTATE",
            help: "Switches to the next wallpaper every N minutes. 0 turns it off.",
            sub: "NEXT WALLPAPER EVERY N MINUTES · 0 = OFF",
            min: 0,
            max: 120,
            step: 5,
            fmt: "int",
            unit: "min"
        },
        {
            kind: "action",
            name: "RANDOM WALLPAPER",
            help: "Picks a random wallpaper from your folder.",
            sub: "SURPRISE ME",
            fn: "randomWallpaper"
        },
        {
            kind: "action",
            name: "RESCAN FOLDER",
            help: "Reads the wallpaper folder again, so newly added images show up.",
            sub: "PICK UP NEWLY ADDED IMAGES",
            fn: "rescanWallpapers"
        },
        {
            kind: "info",
            name: "WALLPAPER FOLDER",
            help: "The folder the wallpapers come from. Change it in ~/.config/velvet/config.json (wallpaper.directory).",
            sub: "EDIT CONFIG.JSON TO CHANGE THIS",
            valueKey: "wallpaper.directory"
        }
    ]

    // ================================================================== SHELL
    readonly property var shell: [
        {
            kind: "page",
            name: "SCREEN RECORDING",
            help: "Super+Enter records the screen you are on, with the sound you hear, into ~/Videos; Super+Enter again stops it and offers to play the file. Before it starts, a countdown in the middle of the screen gives you time to get ready — it is gone before the recording begins, so it is never in the video.",
            sub: "SUPER+ENTER  ·  3 · 2 · 1  ·  ~/VIDEOS",
            icon: "fiber_manual_record",
            items: [
                {
                    kind: "choice",
                    key: "record.countdown",
                    name: "COUNTDOWN",
                    help: "How long the countdown in the middle of the screen runs before the recording starts. Press Super+Enter during it to cancel. OFF starts after a one-second note, as before.",
                    sub: "OFF · 3 · 5 · 10 SECONDS",
                    options: [
                        { value: 0, label: "OFF" },
                        { value: 3, label: "3 SECONDS" },
                        { value: 5, label: "5 SECONDS" },
                        { value: 10, label: "10 SECONDS" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "record.sound",
                    name: "TICK EVERY SECOND",
                    help: "A soft tick on every number of the countdown (the shell's own sounds, SHELL → SOUND). The last tick is over before the recording starts.",
                    sub: "A SOFT TICK ON 3, 2 AND 1"
                }
            ]
        },
        {
            kind: "page",
            name: "THE DESKTOP",
            help: "The programs that sit on your desktop (clocks, cava, system monitors in little terminals) and where — arranged per wallpaper in the DESKTOP tab.",
            sub: "WHAT SITS ON YOUR WALLPAPER",
            items: [
                {
                    kind: "info",
                    name: "RIGHT NOW",
                    help: "How many programs are arranged for this wallpaper, and how many of them are running.",
                    sub: "WHAT IS ARRANGED, AND HOW MUCH OF IT IS OPEN",
                    live: "sceneStatus"
                },
                {
                    kind: "action",
                    name: "ARRANGE IT",
                    help: "Opens the DESKTOP tab: drag programs onto a picture of your screen; opening, capturing, clearing and following all happen live there.",
                    sub: "DRAG PROGRAMS ONTO A PICTURE OF YOUR SCREEN — OPEN, CAPTURE, CLEAR AND FOLLOW ALL LIVE THERE",
                    fn: "openDesktopTab"
                },
                {
                    kind: "toggle",
                    key: "scene.autostart",
                    name: "OPEN IT ON LOGIN",
                    help: "Opens the arranged programs when you log in (if their wallpaper is the one on). Programs that are already running are left alone.",
                    sub: "ANYTHING ALREADY RUNNING IS LEFT ALONE"
                },
                {
                    kind: "choice",
                    key: "scene.floatSize",
                    name: "NEW FLOATING WINDOWS",
                    aka: "FLOATING SIZE · FENSTERGRÖSSE · SCHWEBENDE FENSTER · KLEIN ÖFFNEN",
                    help: "How big a window comes up on a FLOATING desktop (DESKTOP → WINDOWS ON DESKTOP n), in the middle of the screen — Hyprland would float it at the size of the whole screen. An app that makes itself big again a moment after it opens (kitty, browsers putting back their last size) is brought back down. SUPER+V floats a window at this size too; dialogs keep their own.",
                    sub: "IN THE MIDDLE · SMALL · MEDIUM · LARGE · HUGE",
                    options: [
                        { value: 45, label: "SMALL" },
                        { value: 60, label: "MEDIUM" },
                        { value: 75, label: "LARGE" },
                        { value: 90, label: "HUGE" }
                    ]
                },
                {
                    kind: "choice",
                    key: "scene.terminal",
                    name: "TERMINAL",
                    help: "Which terminal the little desktop programs open in. AUTO uses the first one installed.",
                    sub: "WHICH EMULATOR THE LITTLE PROGRAMS OPEN IN",
                    options: [
                        {
                            value: "auto",
                            label: "AUTO"
                        },
                        {
                            value: "kitty",
                            label: "KITTY"
                        },
                        {
                            value: "foot",
                            label: "FOOT"
                        },
                        {
                            value: "ghostty",
                            label: "GHOSTTY"
                        },
                        {
                            value: "wezterm",
                            label: "WEZTERM"
                        },
                        {
                            value: "alacritty",
                            label: "ALACRITTY"
                        }
                    ]
                },
                {
                    kind: "info",
                    name: "TERMINAL FOUND",
                    help: "The terminal that was found. The desktop programs need one.",
                    sub: "THE LITTLE PROGRAMS NEED ONE",
                    live: "termStatus"
                }
            ]
        },
        {
            kind: "page",
            name: "ON LOGIN",
            help: "What starts by itself when you log in: a song from Spotify. Play the song in Spotify, press TAKE THE SONG PLAYING NOW, and it starts on every login — after a short wait, faded in. Once per login: a restarted shell does not play it again.",
            sub: "A SONG FROM SPOTIFY · AFTER A WAIT · FADED IN",
            icon: "music_note",
            items: [
                {
                    kind: "toggle",
                    key: "login.songOn",
                    name: "PLAY A SONG WHEN YOU LOG IN",
                    help: "Starts the song below once per login, when the session is up. Spotify is opened for it if it is not running. Off by default.",
                    sub: "ONCE PER LOGIN"
                },
                {
                    kind: "action",
                    name: "TAKE THE SONG PLAYING NOW",
                    help: "Keeps the track Spotify is playing, or paused on, for the login. Play the song in Spotify first; the toast names what was kept.",
                    sub: "NEEDS SPOTIFY RUNNING WITH A SONG IN ITS PLAYER",
                    fn: "takeLoginSong"
                },
                {
                    kind: "action",
                    name: "PLAY THE KEPT SONG NOW",
                    help: "Plays the kept song right away with the same fade — to hear how it starts, without waiting for a login.",
                    sub: "THE SAME START, WITHOUT THE WAIT",
                    fn: "playLoginSong"
                },
                {
                    kind: "slider",
                    key: "login.songDelay",
                    name: "WAIT BEFORE IT PLAYS",
                    help: "Seconds after the session starts before the song begins, so the desktop has settled first.",
                    sub: "SECONDS AFTER YOU LOG IN",
                    when: { key: "login.songOn", is: true },
                    min: 0, max: 60, step: 1, fmt: "int", unit: "s"
                },
                {
                    kind: "slider",
                    key: "login.songFade",
                    name: "FADE IN",
                    help: "Seconds the volume takes to rise to the level Spotify had. 0 starts at full volume.",
                    sub: "SECONDS TO FULL VOLUME",
                    when: { key: "login.songOn", is: true },
                    min: 0, max: 15, step: 1, fmt: "int", unit: "s"
                }
            ]
        },
        {
            kind: "page",
            name: "SCREENSHOT",
            help: "The screenshot button on the bar.",
            sub: "THE BUTTON IN THE BAR",
            items: [
                {
                    kind: "info",
                    name: "COMMAND",
                    help: "The command the screenshot button runs. Change it in ~/.config/velvet/config.json (services.screenshotCommand).",
                    sub: "EDIT IT IN ~/.CONFIG/VELVET/CONFIG.JSON — SERVICES.SCREENSHOTCOMMAND",
                    valueKey: "services.screenshotCommand"
                },
                {
                    kind: "info",
                    name: "WHAT IT NEEDS",
                    help: "The default command needs grim and slurp (select an area) and wl-copy (clipboard) installed. Without them the button tells you what is missing.",
                    sub: "GRIM AND SLURP FOR THE DEFAULT, PLUS WL-COPY TO PUT IT ON THE CLIPBOARD"
                }
            ]
        },
        {
            kind: "page",
            name: "FOCUS MODE",
            help: "One switch for \"leave me alone\" (Super+F): pick below what it does, and one press puts it all back.",
            sub: "ONE SWITCH FOR LEAVE ME ALONE",
            items: [
                {
                    kind: "toggle",
                    key: "services.focusMode",
                    name: "FOCUS MODE",
                    help: "Turns focus mode on or off — also Super+F or the focus chip in the quick panel.",
                    sub: "SUPER + F, OR THE FOCUS CHIP IN THE QUICK PANEL"
                },
                {
                    kind: "info",
                    name: "WHAT IT DOES",
                    help: "Pick what focus mode does. Nothing you set yourself is overwritten; everything is restored when it ends.",
                    sub: "PICK BELOW · NOTHING YOU SET YOURSELF IS OVERWRITTEN"
                },
                {
                    kind: "toggle",
                    key: "services.focusSilences",
                    name: "SILENCE NOTIFICATIONS",
                    help: "Notifications are collected quietly; when focus ends you see how many you missed.",
                    sub: "COLLECT THEM QUIETLY AND COUNT WHAT YOU MISSED"
                },
                {
                    kind: "toggle",
                    key: "services.focusKeepsAwake",
                    name: "KEEP THE SCREEN AWAKE",
                    help: "The screen does not blank and the machine does not sleep while focus is on.",
                    sub: "NO BLANKING, NO SLEEP, WHILE FOCUS IS ON"
                },
                {
                    kind: "toggle",
                    key: "services.focusMutesShell",
                    name: "MUTE SHELL SOUNDS",
                    help: "Velvet's own clicks and whooshes are muted while focus is on.",
                    sub: "NO CLICKS OR WHOOSHES FROM VELVET ITSELF"
                },
                {
                    kind: "toggle",
                    key: "services.focusHidesBar",
                    name: "HIDE THE TASKBAR",
                    help: "The taskbar slides away while focus is on; touch its edge to bring it back.",
                    sub: "SLIDES AWAY UNTIL YOU REACH FOR THE EDGE"
                },
                {
                    kind: "toggle",
                    key: "services.focusDims",
                    name: "DIM THE OTHER WINDOWS",
                    help: "The spotlight: every window except the one you are working in is dimmed.",
                    sub: "THE SPOTLIGHT — EVERY WINDOW YOU ARE NOT LOOKING AT STEPS BACK"
                },
                {
                    kind: "slider",
                    key: "services.focusDimStrength",
                    name: "DIM STRENGTH",
                    help: "How dark the other windows get.",
                    sub: "HOW FAR THEY STEP BACK",
                    min: 0.3,
                    max: 0.8,
                    step: 0.05,
                    fmt: "percent"
                },
                {
                    kind: "toggle",
                    key: "services.focusShades",
                    name: "SHADE THE DESKTOP",
                    help: "The wallpaper behind everything dims too.",
                    sub: "THE PICTURE BEHIND EVERYTHING DIMS TOO"
                }
            ]
        },
        {
            kind: "page",
            name: "LYRICS",
            help: "Timed lyrics for whatever is playing, fetched from lrclib.net (free, no account) and drawn on the desktop.",
            sub: "TIMED LYRICS ON THE DESKTOP",
            items: [
                {
                    kind: "toggle",
                    key: "lyrics.enabled",
                    name: "LYRICS",
                    help: "Fetches and shows the lyrics (also Super+Shift+L). The lock's lyric line works even with this off.",
                    sub: "SUPER+SHIFT+L · FROM LRCLIB, NO ACCOUNT NEEDED"
                },
                {
                    kind: "toggle",
                    key: "lyrics.desktop",
                    name: "ON THE DESKTOP",
                    help: "Draws them on the desktop — over the wallpaper, under every window.",
                    sub: "PAINTED UNDER YOUR WINDOWS, NEVER OVER THEM"
                },
                {
                    kind: "choice",
                    key: "lyrics.position",
                    name: "POSITION",
                    help: "Where the lyrics sit on screen: along the bottom, the top, or in the centre. The STACK card sits in the right corner of that band.",
                    sub: "WHERE THE LINE SITS",
                    options: [
                        {
                            value: "bottom",
                            label: "BOTTOM"
                        },
                        {
                            value: "top",
                            label: "TOP"
                        },
                        {
                            value: "centre",
                            label: "CENTRE"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "lyrics.side",
                    name: "SIDE",
                    help: "Whether the lyrics sit in the middle or towards the left or right. MIDDLE keeps the STACK card where it always was.",
                    sub: "LEFT, MIDDLE OR RIGHT",
                    options: [
                        { value: "left", label: "LEFT" },
                        { value: "centre", label: "MIDDLE" },
                        { value: "right", label: "RIGHT" }
                    ]
                },
                {
                    kind: "slider",
                    key: "lyrics.size",
                    help: "How big the lyrics are.",
                    name: "SIZE",
                    min: 0.5,
                    max: 2,
                    step: 0.05,
                    fmt: "float"
                },
                {
                    kind: "choice",
                    key: "lyrics.mode",
                    name: "MODE",
                    help: "WORD shows one word at a time, huge; LINE shows the whole line and fills it in as it is sung; STACK shows the line before, the current line and the next one on a card over the blurred album cover.",
                    sub: "ONE WORD AT A TIME, THE WHOLE LINE, OR THREE LINES ON A CARD",
                    options: [
                        {
                            value: "word",
                            label: "WORD"
                        },
                        {
                            value: "line",
                            label: "LINE"
                        },
                        {
                            value: "stack",
                            label: "STACK · THREE LINES ON A CARD"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "lyrics.tile",
                    name: "AS A PANEL",
                    help: "Draws the lyrics on a bordered panel instead of loose on the desktop (WORD and LINE modes).",
                    sub: "A BORDERED TILE RATHER THAN LOOSE ACROSS THE DESKTOP"
                },
                {
                    kind: "slider",
                    key: "lyrics.width",
                    name: "PANEL WIDTH",
                    help: "How wide that panel is, as a share of the screen.",
                    sub: "SHARE OF THE SCREEN",
                    min: 0.2,
                    max: 1,
                    step: 0.02,
                    fmt: "percent"
                },
                {
                    kind: "toggle",
                    key: "lyrics.shadow",
                    name: "EXTRUDED TYPE",
                    help: "A hard, offset shadow behind the letters that makes them look extruded (WORD and LINE modes).",
                    sub: "THE HARD DROP BEHIND THE LETTERS"
                },
                {
                    kind: "toggle",
                    key: "lyrics.blocky",
                    name: "SLAB TYPE",
                    help: "Monospace slab letters instead of the display face. In STACK mode it switches the card to the monospace font.",
                    sub: "MONOSPACE SLABS RATHER THAN THE DISPLAY FACE"
                },
                {
                    kind: "toggle",
                    key: "lyrics.showProgress",
                    name: "TRACK AND PROGRESS",
                    help: "A thin progress line with the artist, the title and the time under the lyrics (WORD and LINE modes).",
                    sub: "ARTIST, TITLE AND HOW FAR THROUGH YOU ARE"
                },
                {
                    kind: "slider",
                    key: "lyrics.offsetMs",
                    name: "TIMING NUDGE",
                    help: "Shifts the lyrics against the music, in milliseconds. Positive shows each line later, negative earlier.",
                    sub: "IF THE WORDS RUN EARLY OR LATE",
                    min: -3000,
                    max: 3000,
                    step: 50,
                    fmt: "int",
                    unit: "ms"
                },
                {
                    kind: "info",
                    help: "What the lyrics are doing right now: looking, found synced lyrics, only plain lyrics, none for this song, or offline.",
                    name: "STATUS",
                    live: "lyricsStatus"
                },
                {
                    kind: "action",
                    name: "LOOK AGAIN",
                    help: "Looks the current song's lyrics up again, e.g. after the network came back.",
                    sub: "REFETCH LYRICS FOR THIS TRACK",
                    fn: "refetchLyrics"
                }
            ]
        },
        {
            kind: "page",
            name: "LAUNCHER",
            help: "How the launcher (Super+Space) searches, looks and moves.",
            sub: "SEARCH · LOOK · MOTION",
            items: [
                {
                    kind: "slider",
                    key: "launcher.maxShown",
                    name: "RESULTS SHOWN",
                    help: "How many results are shown at once.",
                    sub: "HOW MANY HITS IN THE LIST",
                    min: 3,
                    max: 14,
                    step: 1,
                    fmt: "int"
                },
                {
                    kind: "toggle",
                    key: "launcher.fuzzy",
                    name: "FUZZY MATCHING",
                    help: "Finds apps even with typos or letters out of order. Off only matches what you typed, in order.",
                    sub: "TOLERATE TYPOS AND SKIPPED LETTERS"
                },
                {
                    kind: "toggle",
                    key: "launcher.showIcons",
                    name: "SHOW ICONS",
                    help: "Shows each app's real icon in the launcher.",
                    sub: "APP ICONS IN THE RESULT LIST"
                },
                {
                    kind: "toggle",
                    key: "launcher.useCalculator",
                    name: "CALCULATOR",
                    help: "Type a sum (like 2+2*3, or =7/3) and the answer appears as the first result.",
                    sub: "TYPE MATHS, GET AN ANSWER"
                },
                {
                    kind: "toggle",
                    key: "launcher.searchSettings",
                    name: "SEARCH SETTINGS TOO",
                    help: "Shell settings show up in the launcher's results too — type a setting's name and jump straight to it.",
                    sub: "FIND SHELL SETTINGS FROM THE LAUNCHER, NOT ONLY APPS"
                },
                {
                    kind: "slider",
                    key: "launcher.width",
                    name: "WIDTH",
                    help: "How wide the launcher opens, in pixels.",
                    sub: "SIZE OF THE LAUNCHER PANEL",
                    min: 480,
                    max: 1100,
                    step: 10,
                    fmt: "int",
                    unit: "px"
                }
            ].concat(root.launcherRows)
        },
        {
            kind: "page",
            name: "NOTIFICATIONS",
            help: "The desktop notifications: the popups and the history in the notification centre.",
            sub: "POPUPS AND HISTORY",
            items: [
                {
                    kind: "toggle",
                    key: "notifs.enabled",
                    name: "NOTIFICATIONS",
                    help: "Velvet as your notification daemon. Off: no popups and no history.",
                    sub: "RECEIVE DESKTOP NOTIFICATIONS AT ALL"
                },
                {
                    kind: "toggle",
                    key: "notifs.doNotDisturb",
                    name: "DO NOT DISTURB",
                    help: "Notifications are still collected in the centre, but no popup appears.",
                    sub: "COLLECT SILENTLY, SHOW NO POPUPS"
                },
                {
                    kind: "toggle",
                    key: "notifs.expanded",
                    name: "EXPANDED BODIES",
                    help: "Popups show the full message instead of one line.",
                    sub: "SHOW THE FULL TEXT, NOT ONE LINE"
                },
                {
                    kind: "slider",
                    key: "notifs.timeout",
                    name: "POPUP TIMEOUT",
                    help: "How long a popup stays before it slides away, in milliseconds.",
                    sub: "HOW LONG A POPUP STAYS UP",
                    min: 1000,
                    max: 15000,
                    step: 500,
                    fmt: "int",
                    unit: "ms"
                },
                {
                    kind: "slider",
                    key: "notifs.maxPopups",
                    name: "MAXIMUM POPUPS",
                    help: "How many popups are on screen at once.",
                    sub: "HOW MANY STACK AT ONCE",
                    min: 1,
                    max: 8,
                    step: 1,
                    fmt: "int"
                },
                {
                    kind: "slider",
                    key: "notifs.width",
                    name: "POPUP WIDTH",
                    help: "How wide each popup is, in pixels.",
                    sub: "SIZE OF EACH NOTIFICATION CARD",
                    min: 280,
                    max: 620,
                    step: 10,
                    fmt: "int",
                    unit: "px"
                }
            ]
        },
        {
            kind: "page",
            name: "ON-SCREEN DISPLAY",
            help: "The small bar that appears when you change volume or brightness.",
            sub: "VOLUME AND BRIGHTNESS FLASH",
            items: [
                {
                    kind: "toggle",
                    key: "osd.enabled",
                    name: "SHOW OSD",
                    help: "Shows it when volume or brightness changes.",
                    sub: "FLASH A BAR WHEN VOLUME OR BRIGHTNESS CHANGES"
                },
                {
                    kind: "slider",
                    key: "osd.timeout",
                    name: "OSD TIMEOUT",
                    help: "How long it stays after the last change, in milliseconds.",
                    sub: "HOW LONG IT LINGERS",
                    min: 600,
                    max: 4000,
                    step: 100,
                    fmt: "int",
                    unit: "ms"
                },
                {
                    kind: "choice",
                    key: "osd.position",
                    name: "OSD POSITION",
                    help: "Where on screen it appears.",
                    sub: "WHERE IT APPEARS",
                    options: [
                        {
                            value: "bottom",
                            label: "BOTTOM"
                        },
                        {
                            value: "top",
                            label: "TOP"
                        },
                        {
                            value: "centre",
                            label: "CENTRE"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "osd.side",
                    name: "OSD SIDE",
                    help: "Whether the pop-up sits in the middle of its edge or towards the left or right.",
                    sub: "LEFT, MIDDLE OR RIGHT",
                    options: [
                        { value: "left", label: "LEFT" },
                        { value: "centre", label: "MIDDLE" },
                        { value: "right", label: "RIGHT" }
                    ]
                }
            ]
        },
        {
            kind: "page",
            name: "SOUND",
            help: "The shell's own interface sounds — clicks, whooshes, confirmations.",
            sub: "MENU FEEDBACK",
            items: [
                {
                    kind: "toggle",
                    key: "sfx.enabled",
                    name: "MENU SOUNDS",
                    help: "Plays the interface sounds as you move through menus and use the shell.",
                    sub: "CLICKS AS YOU MOVE THROUGH THE MENU"
                },
                {
                    kind: "slider",
                    key: "sfx.volume",
                    name: "SOUND VOLUME",
                    help: "How loud the interface sounds are, separate from the system volume.",
                    sub: "HOW LOUD THE CLICKS ARE",
                    min: 0,
                    max: 1,
                    step: 0.05,
                    fmt: "percent"
                },
                {
                    kind: "toggle",
                    key: "sfx.fidget",
                    name: "FIDGET FEEL",
                    aka: "FIDGET TOY · HAPTIK · SPASS · KLICKEN · TACTILE",
                    help: "The shell answers your hand like a toy: switches snap over with a stretch and a bounce, sliders tick past their notches (louder as they fill, firmer at the ends), every press has a small mechanical click under it, and the WLAN | LAN lever clunks into place — or shakes its head when there is no cable. Off: the plain clicks and the calm motion.",
                    sub: "SNAPS · TICKS · CLUNKS · BOUNCES"
                },
                {
                    kind: "slider",
                    key: "sfx.fidgetVolume",
                    name: "FIDGET LOUDNESS",
                    help: "How loud the fidget sounds (ticks, the lever, the bounces) are next to the other clicks.",
                    sub: "THE TICKS AND CLUNKS",
                    when: { key: "sfx.fidget", is: true },
                    min: 0.1,
                    max: 1.5,
                    step: 0.05,
                    fmt: "percent"
                }
            ]
        },
        {
            kind: "page",
            name: "NETWORK · LAN",
            aka: "LAN · KABEL · ETHERNET · NETZWERKKABEL · FESTE IP · STATISCHE IP · DNS · GATEWAY · WIRED",
            help: "The network cable. The WLAN | LAN lever (QUICK SETTINGS) switches between Wi-Fi and the cable without ever leaving you offline: the new way comes up first, then the old one goes. Here the cable gets its address: AUTOMATIC from the router, or a FIXED one you type. A fixed address lives on the shell's own wired profile (Velvet LAN), made for you — so it changes without an administrator password.",
            sub: "THE CABLE · ITS SPEED · AUTOMATIC OR A FIXED ADDRESS",
            icon: "lan",
            items: [
                {
                    kind: "info",
                    name: "RIGHT NOW",
                    help: "The cable (is one in, how fast, which address) and what carries your connection.",
                    sub: "THE CABLE AND THE WI-FI",
                    live: "lanStatus"
                },
                {
                    kind: "action",
                    name: "ON THE CABLE",
                    help: "Connects the cable and lets the Wi-Fi go once the cable is up (its radio stays on, so going back is quick) — what flipping the lever to LAN does.",
                    sub: "THE LEVER TO LAN",
                    fn: "lanUse"
                },
                {
                    kind: "action",
                    name: "BACK TO WI-FI",
                    help: "Joins a Wi-Fi network you have used before and lets the cable go once it is in — what flipping the lever to WLAN does. With no known network in range the cable stays on.",
                    sub: "THE LEVER TO WLAN",
                    fn: "wifiUse"
                },
                {
                    kind: "toggle",
                    key: "lan.autoconnect",
                    name: "CONNECT BY ITSELF",
                    help: "The cable connects as soon as it is plugged in (for the shell's own profile; it takes effect with APPLY).",
                    sub: "AS SOON AS A CABLE GOES IN"
                },
                {
                    kind: "choice",
                    key: "lan.method",
                    name: "ADDRESS",
                    help: "AUTOMATIC: the router hands the cable an address (DHCP) — right for almost every home. FIXED: the address you type below, for a PC others reach by its address.",
                    sub: "AUTOMATIC FROM THE ROUTER · OR FIXED",
                    options: [
                        { value: "auto", label: "AUTOMATIC" },
                        { value: "manual", label: "FIXED" }
                    ]
                },
                {
                    kind: "text",
                    key: "lan.address",
                    name: "FIXED ADDRESS",
                    help: "The address with its network size, like 192.168.178.50/24 (without /24, /24 is assumed). Pick one outside your router's DHCP range.",
                    sub: "LIKE 192.168.178.50/24",
                    when: { key: "lan.method", is: "manual" },
                    placeholder: "e.g. 192.168.178.50/24",
                    examples: ["192.168.178.50/24", "192.168.1.50/24", "10.0.0.50/24"],
                    empty: "NONE YET"
                },
                {
                    kind: "text",
                    key: "lan.gateway",
                    name: "GATEWAY",
                    help: "Your router's address, like 192.168.178.1.",
                    sub: "YOUR ROUTER",
                    when: { key: "lan.method", is: "manual" },
                    placeholder: "e.g. 192.168.178.1",
                    examples: ["192.168.178.1", "192.168.1.1", "10.0.0.1"],
                    empty: "NONE YET"
                },
                {
                    kind: "text",
                    key: "lan.dns",
                    name: "DNS",
                    aka: "NAMESERVER",
                    help: "Which name servers to ask, space or comma between them (1.1.1.1 9.9.9.9). Empty: the router's.",
                    sub: "EMPTY: THE ROUTER'S",
                    placeholder: "e.g. 1.1.1.1 9.9.9.9",
                    examples: ["1.1.1.1 1.0.0.1", "9.9.9.9 149.112.112.112", "8.8.8.8 8.8.4.4"],
                    empty: "THE ROUTER'S"
                },
                {
                    kind: "action",
                    name: "APPLY",
                    help: "Puts the address (and the DNS) on the cable: the shell's own wired profile is made the first time, then the cable reconnects with it.",
                    sub: "THE CABLE RECONNECTS WITH IT",
                    fn: "lanApply"
                },
                {
                    kind: "action",
                    name: "BACK TO THE SYSTEM'S PROFILE",
                    help: "Switches the shell's wired profile off and lets the system's own (automatic) profile run the cable again.",
                    sub: "AUTOMATIC, AS IT CAME",
                    fn: "lanSystem"
                }
            ]
        },
        {
            kind: "page",
            name: "WEATHER",
            help: "Where the weather in the bar, the island, the widgets and the lock comes from.",
            sub: "FOR THE WEATHER BAR MODULE",
            items: [
                {
                    kind: "toggle",
                    key: "services.weather",
                    name: "FETCH WEATHER",
                    help: "Fetches the weather from wttr.in — no account, no API key. Off: every weather display stays empty.",
                    sub: "POLLS WTTR.IN — NO ACCOUNT, NO API KEY"
                },
                {
                    kind: "toggle",
                    key: "services.weatherMetric",
                    name: "CELSIUS",
                    help: "Temperatures in °C. Off uses °F.",
                    sub: "OFF USES FAHRENHEIT"
                },
                {
                    kind: "slider",
                    key: "services.weatherInterval",
                    name: "REFRESH EVERY",
                    help: "How often the weather is fetched again, in minutes.",
                    sub: "HOW OFTEN TO ASK",
                    min: 5,
                    max: 180,
                    step: 5,
                    fmt: "int",
                    unit: " MIN"
                },
                {
                    kind: "info",
                    name: "LOCATION",
                    help: "Your location. Empty lets wttr.in guess it from your IP address; set a city in ~/.config/velvet/config.json (services.weatherLocation) to be exact.",
                    sub: "EMPTY GUESSES FROM YOUR IP — SET IT IN CONFIG.JSON",
                    valueKey: "services.weatherLocation"
                }
            ]
        },
        {
            kind: "page",
            name: "WORKFLOW",
            help: "Your tasks and the checklist in the island.",
            sub: "TASKS · THE ISLAND CHECKLIST",
            items: [
                {
                    kind: "toggle",
                    key: "map.islandTasks",
                    name: "TASKS IN THE ISLAND",
                    help: "Adds the task checklist to the island's swipe cycle.",
                    sub: "A CHECKLIST MODULE BETWEEN MAP AND WEATHER"
                },
                {
                    kind: "action",
                    name: "MANAGE TASKS",
                    help: "Opens WORKFLOW, where you add, pin and check off tasks (also Super+Tab → WORKFLOW).",
                    sub: "ADD, PIN AND CHECK THEM OFF — ALSO IN SUPER+TAB → WORKFLOW",
                    fn: "openWorkflow"
                },
                {
                    kind: "info",
                    name: "RIGHT NOW",
                    help: "What the island's task module would show right now.",
                    sub: "WHAT THE ISLAND WOULD SAY",
                    live: "tasksPill"
                }
            ]
        },
        {
            kind: "action",
            name: "QUICK SETTINGS",
            help: "Opens QUICK SETTINGS: Bluetooth, Wi-Fi and power in one view.",
            sub: "BLUETOOTH · WI-FI · POWER IN ONE VIEW",
            fn: "openQuick"
        },
        {
            kind: "action",
            name: "UPDATE & REPAIR",
            help: "Everything an update needs, in one go: downloads the newest Velvet (never over files you changed yourself), brings Velvet's Hyprland files in ~/.config/hypr up to date (the old ones are kept as *.before-update), rebuilds the zoom plugin if needed and swaps it into the running Hyprland, then reloads Hyprland and restarts the shell. A terminal shows each step. Velvet also checks this by itself a few seconds after it starts and says so when something is out of step.",
            sub: "DOWNLOAD · HYPRLAND FILES · ZOOM PLUGIN · RESTART — IN ONE GO",
            fn: "updateVelvet"
        },
        {
            kind: "action",
            name: "RESTART SHELL",
            help: "Restarts the whole shell from disk. Use it after editing files by hand or if something got stuck.",
            sub: "RELOAD VELVET FROM DISK",
            fn: "restartShell"
        },
        {
            kind: "action",
            name: "UNINSTALL VELVET",
            help: "Removes Velvet completely: the shell, its Hyprland lines and files, its programs, fonts and your Velvet settings. A terminal opens and asks once more before anything happens; your Hyprland config gets back exactly what it had before. Same as running uninstall.sh.",
            sub: "REMOVES THE SHELL COMPLETELY — A TERMINAL ASKS ONCE MORE",
            fn: "uninstall",
            danger: true
        },
        {
            kind: "action",
            name: "RESET ALL SETTINGS",
            help: "Puts every setting back to how Velvet starts on a fresh install, adapted to this screen again. Your looks, desktops, wallpapers and Velly's memory stay. The old settings are kept next to the new ones as config.json.before-reset-<date>. The shell restarts once.",
            sub: "BACK TO A FRESH START — LOOKS AND DESKTOPS STAY",
            fn: "resetSettings",
            danger: true
        }
    ]

    // ================================================================== POWER
    // The lock's own knobs — they live in the LOCK SCREEN tab above.
    readonly property var lockScreen: [
        {
            kind: "choice",
            key: "lock.look",
            name: "LOCK STYLE",
            help: "The lock's face. FLUID is the welcoming card with side columns of modules; SOFT is no card — a big clock and a few round pills; VELVET is the original hard-edged lock; VIBE draws the lock that belongs to the look you wear — a terminal login, a game's title screen, a newspaper front page, frosted glass, a book, a poster, a quiet clock, or the logon screen of the Vindows edition you picked. Each of the first three has its own page below (the one you wear says IN USE); CLOCK, BACKGROUND & MUSIC and PASSWORD & HINTS apply to FLUID and SOFT. PAM and all safety rules are the same for all of them.",
            sub: "FLUID · SOFT · VELVET — OR THE LOCK OF THE VIBE YOU WEAR",
            options: [
                {
                    value: "fluid",
                    label: "FLUID · THE CARD WITH SIDE COLUMNS"
                },
                {
                    value: "soft",
                    label: "SOFT · BIG CLOCK, ROUND PILLS"
                },
                {
                    value: "velvet",
                    label: "VELVET"
                },
                {
                    value: "vibe",
                    label: "VIBE · THE LOCK OF YOUR LOOK"
                }
            ]
        },
        {
            kind: "toggle",
            key: "lock.useBuiltin",
            name: "USE VELVET'S LOCK",
            help: "Uses Velvet's own lock screen. It only locks once PAM has proven it can let you back in, and TEST LOCK tries it safely. If the shell ever crashes while locked, unlock from a text console (Ctrl+Alt+F2, log in, loginctl unlock-session).",
            sub: "READ THIS FIRST: IF THE SHELL CRASHES WHILE LOCKED YOU MUST UNLOCK FROM A TTY"
        },
        {
            kind: "info",
            name: "STATUS",
            help: "What will actually happen when you lock — whether PAM works, which service is used, or which other locker takes over.",
            sub: "WHAT WILL ACTUALLY HAPPEN WHEN YOU LOCK",
            live: "lockStatus"
        },
        {
            kind: "action",
            name: "TEST LOCK",
            help: "Locks the screen and releases it by itself after 20 seconds — to try a look or check that the password works, without risk.",
            sub: "LOCKS, THEN RELEASES ITSELF AFTER 20 SECONDS",
            fn: "testLock"
        },
        {
            kind: "page",
            name: "SOFT LOCK",
            help: "The SOFT lock: no card, the blurred wallpaper, a big clock and a few round pills. Pick a layout or arrange every element by hand, set how it moves and which pills it shows. Its clock and its background are shared with the FLUID lock — they live under CLOCK and BACKGROUND & MUSIC.",
            sub: "LAYOUT · ARRANGE BY HAND · MOTION · PILLS",
            icon: "lock_open",
            style: "soft",
            items: [
                {
                    kind: "info",
                    name: "THE SOFT LOCK",
                    help: "No card: the blurred wallpaper, a big clock and a few round pills. Every piece is an element you can move, resize, reshape or hide — here under ARRANGE BY HAND, or on the lock itself with the pencil next to the password.",
                    sub: "NO CARD: THE BLURRED WALLPAPER, A BIG CLOCK, A FEW ROUND PILLS · EVERY PIECE CAN BE MOVED, RESIZED, RESHAPED"
                },
                {
                    kind: "choice",
                    key: "lock.layout",
                    name: "LAYOUT",
                    help: "VERTICAL puts the pills under the clock, HORIZONTAL beside it; GREETING is a column of shapes (time, date, weather), a big hello with your name in a cloud, the password below and the music card in the corner. CUSTOM is your own arrangement — it appears by itself as soon as you drag an element, and keeps every place you gave it. Picking a preset again does not forget CUSTOM's places.",
                    sub: "CLOCK OVER THE PILLS, SIDE BY SIDE, THE GREETING STAGE — OR YOUR OWN",
                    options: [
                        {
                            value: "vertical",
                            label: "VERTICAL"
                        },
                        {
                            value: "horizontal",
                            label: "HORIZONTAL"
                        },
                        {
                            value: "greeting",
                            label: "GREETING · SHAPES AND A BIG HELLO"
                        },
                        {
                            value: "custom",
                            label: "CUSTOM · ARRANGED BY HAND"
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "ARRANGE BY HAND",
                    help: "Opens the SOFT lock big, with everything on it movable. Drag any element (clock, greeting, date, weather, your photo, the lyric line, the power pills, the bell, the password, the music) to put it anywhere — it snaps to the middle, Alt places it freely. Click one to pick it: give it any of the sixteen shapes, a size, round, soft or square corners, show or hide it. The arrow keys nudge the picked one, Shift a bigger step.",
                    sub: "DRAG ANY ELEMENT ANYWHERE · ANY SHAPE ON ANYTHING · SIZE, CORNERS, SHOW OR HIDE",
                    icon: "open_with",
                    pane: "softlock",
                    items: []
                },
                {
                    kind: "page",
                    name: "MOTION",
                    help: "How the SOFT lock comes up and moves: the entrance and its speed, one element after another, gliding to new places, the slow turn of the shapes, the morph on hover and the digits when the minute turns.",
                    sub: "HOW IT ARRIVES, MOVES AND CHANGES",
                    icon: "animation",
                    items: [
                        {
                            kind: "choice",
                            key: "lock.softAnimation",
                            name: "ENTRANCE",
                            help: "How the elements arrive when the lock comes up (and leave again on unlock). RISE floats them up, FADE only fades, ZOOM grows them, DROP lets them fall in with a bounce, POP springs them out of nothing, SPIN turns them in, SLIDE brings each from its own side of the screen.",
                            sub: "RISE · FADE · ZOOM · DROP · POP · SPIN · SLIDE",
                            options: [
                                {
                                    value: "rise",
                                    label: "RISE"
                                },
                                {
                                    value: "fade",
                                    label: "FADE"
                                },
                                {
                                    value: "zoom",
                                    label: "ZOOM"
                                },
                                {
                                    value: "drop",
                                    label: "DROP · WITH A BOUNCE"
                                },
                                {
                                    value: "pop",
                                    label: "POP"
                                },
                                {
                                    value: "spin",
                                    label: "SPIN"
                                },
                                {
                                    value: "slide",
                                    label: "SLIDE · FROM THE SIDES"
                                }
                            ]
                        },
                        {
                            kind: "slider",
                            key: "lock.animationScale",
                            name: "ENTRANCE SPEED",
                            help: "The speed of the entrance and exit. Lower is faster. Used by every entrance of the FLUID lock except MORPH (which keeps its own timing) and by the SOFT lock.",
                            sub: "EVERY ENTRANCE EXCEPT MORPH HONOURS THIS DIAL — MORPH KEEPS ITS OWN TIMING",
                            min: 0.25,
                            max: 2.0,
                            step: 0.05,
                            fmt: "float2",
                            unit: "×"
                        },
                        {
                            kind: "slider",
                            key: "lock.softStagger",
                            name: "ONE AFTER ANOTHER",
                            help: "How far apart the elements arrive: 0 brings everything at once, higher lets the clock come first, then the shapes, the pills, the password and the music, each a beat later. The speed itself is ENTRANCE SPEED under ANIMATION.",
                            sub: "0 = ALL AT ONCE · HIGHER = CLOCK FIRST, THEN THE REST, A BEAT APART",
                            min: 0,
                            max: 0.14,
                            step: 0.01,
                            fmt: "percent"
                        },
                        {
                            kind: "toggle",
                            key: "lock.softGlide",
                            name: "GLIDE TO NEW PLACES",
                            help: "When the layout changes, an element is nudged or reset, or the bell's list opens, the elements glide to their new places instead of jumping.",
                            sub: "A NEW LAYOUT OR A NUDGE MOVES THE ELEMENTS SMOOTHLY INSTEAD OF JUMPING"
                        },
                        {
                            kind: "toggle",
                            key: "lock.softShapeSpin",
                            name: "SHAPES TURN SLOWLY",
                            help: "Every shape on the lock — the clock's dial, the greeting's cloud, the date, the weather, your photo's frame and the music cover's frame — turns very slowly (once in ninety seconds). Only while the lock is up.",
                            sub: "THE CLOCK'S DIAL, THE CLOUD, THE BADGES AND THE COVER TURN, ONCE IN 90 SECONDS"
                        },
                        {
                            kind: "slider",
                            key: "lock.softOpacity",
                            name: "MODULE OPACITY",
                            help: "How solid every module of the SOFT lock is — the clock's shape, the cloud, the badges, the pills, the password and the music card. Lower lets the blurred wallpaper show through all of them at once. Each module's own colour (TONE, TINT, ACCENT, GLASS, BLACK) and its highlight colour are set under ARRANGE BY HAND, or with the pencil right on the lock.",
                            sub: "LOWER = THE WALLPAPER SHOWS THROUGH · EACH MODULE'S COLOUR UNDER ARRANGE BY HAND",
                            min: 0.2,
                            max: 1,
                            step: 0.05,
                            fmt: "percent"
                        },
                        {
                            kind: "toggle",
                            key: "lock.softHoverMorph",
                            name: "SHAPES CHANGE ON HOVER",
                            help: "Point at a shape on the lock — the clock's dial, the greeting cloud, the date, the weather, your photo, the music cover — and it morphs into another shape, and back when the pointer leaves. Which shape each one turns into is set per element under ARRANGE BY HAND (or with the pencil on the lock); left alone, each picks a partner of its own.",
                            sub: "POINT AT A SHAPE AND IT MORPHS INTO ANOTHER — PER ELEMENT UNDER ARRANGE BY HAND"
                        },
                        {
                            kind: "choice",
                            key: "lock.softDigitMotion",
                            name: "DIGITS CHANGE",
                            help: "What the clock's digits do when the time changes. ROLL slides the old number up and out and the new one in from below, FADE crossfades them, SNAP just swaps them.",
                            sub: "ROLL · FADE · SNAP — WHEN THE MINUTE TURNS",
                            options: [
                                {
                                    value: "roll",
                                    label: "ROLL"
                                },
                                {
                                    value: "fade",
                                    label: "FADE"
                                },
                                {
                                    value: "none",
                                    label: "SNAP"
                                }
                            ]
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "PILLS & PENCIL",
                    help: "The small round pieces round the password: the pencil that turns the lock into its own editor, LOG OUT · RESTART · SHUT DOWN, the bell with the weather (and how many notifications its list shows), and the song that is playing.",
                    sub: "THE PENCIL, THE POWER PILLS, THE BELL, THE MUSIC",
                    icon: "toggle_on",
                    items: [
                        {
                            kind: "toggle",
                            key: "lock.softEdit",
                            name: "PENCIL",
                            help: "The pencil next to the password field. It turns the lock itself into the editor: drag any element, click one to pick it, and two panels (drag them by their title, fold them with the chevron) change its shape, size and corners, the clock's style and font, the layout, the motion, the blur and the visualizer — right there.",
                            sub: "CUSTOMISE ON THE LOCK: DRAG ANYTHING, SHAPES, SIZES, CLOCK, LAYOUT, MOTION"
                        },
                        {
                            kind: "toggle",
                            key: "lock.softPower",
                            name: "POWER PILLS",
                            help: "LOG OUT, RESTART and SHUT DOWN as pills. Each one only arms the password field — nothing happens until you type your password.",
                            sub: "LOG OUT · RESTART · SHUT DOWN — EACH ONE ASKS FOR THE PASSWORD FIRST"
                        },
                        {
                            kind: "toggle",
                            key: "lock.softStatus",
                            name: "BELL & WEATHER",
                            help: "A pill with the number of notifications and the temperature. Click it for the notification list.",
                            sub: "HOW MANY NOTIFICATIONS AND THE TEMPERATURE · CLICK FOR THE LIST"
                        },
                        {
                            kind: "slider",
                            key: "lock.notifsCount",
                            name: "NOTIFICATION ENTRIES",
                            help: "How many notifications (or app groups) the lock shows — in the FLUID lock's dock and in the SOFT lock's bell panel.",
                            sub: "HOW MANY GROUPS OR ITEMS THE DOCK SHOWS",
                            min: 1,
                            max: 8,
                            step: 1,
                            fmt: "int"
                        },
                        {
                            kind: "toggle",
                            key: "lock.hideNotifs",
                            name: "HIDE NOTIFICATION CONTENT",
                            help: "Privacy: the lock only shows how many notifications there are, never what they say.",
                            sub: "PRIVACY: NOTHING SHOWS UNTIL YOU UNLOCK"
                        },
                        {
                            kind: "toggle",
                            key: "lock.softMedia",
                            name: "MUSIC PILL",
                            help: "A pill with the song that is playing. Click it for the music card with cover, buttons and progress.",
                            sub: "WHAT IS PLAYING · CLICK FOR THE CARD WITH THE COVER AND THE BUTTONS"
                        }
                    ]
                },
                {
                    kind: "action",
                    name: "RESET ARRANGEMENT",
                    help: "Forgets every place, shape, size, corner and show/hide you gave the SOFT lock's elements and goes back to the layout's own arrangement (CUSTOM falls back to VERTICAL). The clock's style, font and the other rows stay as they are.",
                    sub: "FORGET EVERY PLACE, SHAPE AND SIZE — BACK TO THE LAYOUT'S OWN",
                    fn: "resetSoftArrangement",
                    danger: true
                }
            ]
        },
        {
            kind: "page",
            name: "FLUID LOCK",
            help: "The FLUID lock: the welcoming card with side columns of modules. Arrange the columns by hand, pick its entrance and size, a background shape and the finer module switches. Its clock and its background blur are shared with the SOFT lock — they live under CLOCK and BACKGROUND & MUSIC.",
            sub: "THE CARD WITH ITS SIDE COLUMNS · ENTRANCE · SIZE",
            icon: "dashboard",
            style: "fluid",
            items: [
                {
                    kind: "page",
                    name: "ARRANGE THE COLUMNS",
                    help: "Opens the lock editor: a picture of the FLUID lock with its side columns. Drag a module to the other column or to a new place in its column; Del removes the selected one. Only the FLUID lock style uses this arrangement.",
                    sub: "DRAG THE MODULES BETWEEN AND WITHIN THE SIDE COLUMNS",
                    icon: "dashboard",
                    pane: "lock",
                    items: []
                },
                {
                    kind: "page",
                    name: "QUICK STYLES",
                    help: "Four ready-made dresses for the FLUID lock in one press — each sets the cards, the big card, the layout and the centre together. Fine-tune anything afterwards in CARDS, LAYOUT and THE CENTRE.",
                    sub: "CLASSIC · GLASS · MINIMAL · FLOATING — IN ONE PRESS",
                    icon: "auto_awesome",
                    items: [
                        {
                            kind: "action",
                            name: "CLASSIC",
                            help: "The FLUID lock as it was made: solid cards, each with its own corners and glyph, on the big frosted card.",
                            sub: "SOLID CARDS ON THE BIG FROSTED CARD — AS IT WAS MADE",
                            fn: "fluidClassic"
                        },
                        {
                            kind: "action",
                            name: "GLASS",
                            help: "See-through glass cards with one soft corner, a thin big card, the wallpaper shining through.",
                            sub: "SEE-THROUGH CARDS · THE WALLPAPER SHINES THROUGH",
                            fn: "fluidGlass"
                        },
                        {
                            kind: "action",
                            name: "MINIMAL",
                            help: "Only outlines, no big card, a small photo, and music and notifications gone while there is nothing to show.",
                            sub: "OUTLINES ONLY · NOTHING THAT IS NOT NEEDED",
                            fn: "fluidMinimal"
                        },
                        {
                            kind: "action",
                            name: "FLOATING",
                            help: "Tinted cards floating on the wallpaper in a card as big as the screen, round corners and air between them.",
                            sub: "TINTED CARDS FLOATING ON THE WALLPAPER, SCREEN-SIZED",
                            fn: "fluidFloating"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "lock.animation",
                    name: "ENTRANCE",
                    help: "How the FLUID lock's card arrives; each style plays a matching exit on unlock. MORPH spins a square up into the card; the others zoom, drop, fade, flip, spiral, glitch or open like shutters.",
                    sub: "HOW THE CARD ARRIVES WHEN THE LOCK ENGAGES — EVERY STYLE GETS A MATCHING UNLOCK",
                    options: [
                        {
                            value: "morph",
                            label: "MORPH"
                        },
                        {
                            value: "zoom",
                            label: "ZOOM"
                        },
                        {
                            value: "drop",
                            label: "DROP"
                        },
                        {
                            value: "fade",
                            label: "FADE"
                        },
                        {
                            value: "flip",
                            label: "FLIP"
                        },
                        {
                            value: "vortex",
                            label: "VORTEX"
                        },
                        {
                            value: "glitch",
                            label: "GLITCH"
                        },
                        {
                            value: "shutter",
                            label: "SHUTTER"
                        }
                    ]
                },
                {
                    kind: "info",
                    name: "UNLOCK",
                    help: "Every entrance has its own exit, played while the screen lets go on unlock.",
                    sub: "EVERY ENTRANCE PLAYS ITS OWN EXIT WHILE THE SCREEN LETS GO — FLIP SWINGS SHUT, VORTEX SPIRALS AWAY, GLITCH TEARS OUT, SHUTTER CLOSES"
                },
                {
                    kind: "slider",
                    key: "lock.animationScale",
                    name: "ENTRANCE SPEED",
                    help: "The speed of the entrance and exit. Lower is faster. Used by every entrance of the FLUID lock except MORPH (which keeps its own timing) and by the SOFT lock.",
                    sub: "EVERY ENTRANCE EXCEPT MORPH HONOURS THIS DIAL — MORPH KEEPS ITS OWN TIMING",
                    min: 0.25,
                    max: 2.0,
                    step: 0.05,
                    fmt: "float2",
                    unit: "×"
                },
                {
                    kind: "choice",
                    key: "lock.scale",
                    name: "LOCK SIZE",
                    help: "How big the FLUID lock's cards, text and buttons are. AUTO grows them with a taller screen.",
                    sub: "HOW BIG THE CARDS, WORDS AND BUTTONS ARE · AUTO GROWS WITH THE SCREEN",
                    options: [
                        {
                            value: "auto",
                            label: "AUTO"
                        },
                        {
                            value: "0.9",
                            label: "90%"
                        },
                        {
                            value: "1",
                            label: "100%"
                        },
                        {
                            value: "1.15",
                            label: "115%"
                        },
                        {
                            value: "1.3",
                            label: "130%"
                        },
                        {
                            value: "1.45",
                            label: "145%"
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "CARDS",
                    help: "How every card in the side columns looks: solid, glass, tinted or only an outline, how much of the fill shows, one corner radius for all, the glyph at their edge, whether they answer the pointer — and the big card behind it all.",
                    sub: "STYLE · STRENGTH · CORNERS · GLYPH · HOVER · THE BIG CARD",
                    icon: "style",
                    items: [
                        {
                            kind: "toggle",
                            key: "lock.tileCards",
                            name: "TILE CARDS",
                            help: "Draws cards around the modules in the side columns. Off shows the modules bare.",
                            sub: "CARDS AROUND THE TILE MODULES · OFF IS BARE"
                        },
                        {
                            kind: "choice",
                            key: "lock.fluidCardStyle",
                            when: { key: "lock.tileCards", is: true },
                            name: "CARD STYLE",
                            help: "SOLID is the opaque card the FLUID lock was made with. GLASS lets the lock show through and catches a little light along the top. TINTED leans into your accent colour. OUTLINE is barely more than its line.",
                            sub: "SOLID · GLASS (SEE-THROUGH) · TINTED (YOUR ACCENT) · OUTLINE (ONLY THE LINE)",
                            options: [
                                {
                                    value: "solid",
                                    label: "SOLID"
                                },
                                {
                                    value: "glass",
                                    label: "GLASS"
                                },
                                {
                                    value: "tinted",
                                    label: "TINTED"
                                },
                                {
                                    value: "outline",
                                    label: "OUTLINE"
                                }
                            ]
                        },
                        {
                            kind: "slider",
                            key: "lock.fluidCardOpacity",
                            when: { key: "lock.tileCards", is: true },
                            name: "CARD STRENGTH",
                            help: "How much of each card's fill shows. Lower lets the lock behind shine through — whatever the style.",
                            sub: "HOW MUCH OF THE FILL SHOWS · LOWER IS MORE SEE-THROUGH",
                            min: 0.2,
                            max: 1.0,
                            step: 0.05,
                            fmt: "percent"
                        },
                        {
                            kind: "choice",
                            key: "lock.fluidCorners",
                            when: { key: "lock.tileCards", is: true },
                            name: "CORNERS",
                            help: "EACH ITS OWN keeps every module's own corner (weather round, notifications tight). A number gives every card the same corner radius.",
                            sub: "EACH MODULE ITS OWN · OR ONE RADIUS FOR EVERY CARD",
                            options: [
                                {
                                    value: "own",
                                    label: "EACH ITS OWN"
                                },
                                {
                                    value: "0",
                                    label: "SQUARE"
                                },
                                {
                                    value: "8",
                                    label: "8 PX"
                                },
                                {
                                    value: "16",
                                    label: "16 PX"
                                },
                                {
                                    value: "24",
                                    label: "24 PX"
                                },
                                {
                                    value: "32",
                                    label: "32 PX"
                                },
                                {
                                    value: "48",
                                    label: "ROUND"
                                }
                            ]
                        },
                        {
                            kind: "toggle",
                            key: "lock.fluidWatermark",
                            when: { key: "lock.tileCards", is: true },
                            name: "GLYPH WATERMARK",
                            help: "Each card wears its module's shape at its right edge, quietly, in your accent colour.",
                            sub: "THE MODULE'S SHAPE AT EACH CARD'S EDGE"
                        },
                        {
                            kind: "toggle",
                            key: "lock.fluidHover",
                            when: { key: "lock.tileCards", is: true },
                            name: "RESPOND TO THE POINTER",
                            help: "Under the mouse a card lifts a little, its edge lights up in the accent and its glyph turns into a new shape.",
                            sub: "A SMALL LIFT, A LIT EDGE AND A NEW GLYPH UNDER THE MOUSE"
                        },
                        {
                            kind: "slider",
                            key: "lock.fluidPanel",
                            name: "BIG CARD",
                            help: "The frosted card everything sits on. At 0% it is gone and the modules float on the wallpaper.",
                            sub: "THE CARD BEHIND IT ALL · 0% LETS THE MODULES FLOAT",
                            min: 0.0,
                            max: 1.0,
                            step: 0.05,
                            fmt: "percent"
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "LAYOUT",
                    help: "How big the FLUID lock's card is and how its inside is laid out: its size and shape, how wide the centre is, the gap between the cards, and whether the side columns stretch to the centre's height.",
                    sub: "SIZE · SHAPE · CENTRE WIDTH · GAP · FILL",
                    icon: "view_quilt",
                    items: [
                        {
                            kind: "slider",
                            key: "lock.fluidSize",
                            name: "CARD SIZE",
                            help: "How tall the card is, as a share of the screen. A bigger card gives the side columns more room.",
                            sub: "HOW TALL THE CARD IS · BIGGER GIVES THE COLUMNS MORE ROOM",
                            min: 0.55,
                            max: 0.95,
                            step: 0.01,
                            fmt: "percent"
                        },
                        {
                            kind: "choice",
                            key: "lock.fluidShape",
                            name: "CARD SHAPE",
                            help: "WIDE is 16:9. WIDER and ULTRA stretch the card sideways for wide screens (the columns get wider, the centre stays). SCREEN takes your screen's own shape.",
                            sub: "WIDE 16:9 · WIDER 2:1 · ULTRA 21:9 · SCREEN (ITS OWN SHAPE)",
                            options: [
                                {
                                    value: "wide",
                                    label: "WIDE · 16:9"
                                },
                                {
                                    value: "wider",
                                    label: "WIDER · 2:1"
                                },
                                {
                                    value: "ultra",
                                    label: "ULTRA · 21:9"
                                },
                                {
                                    value: "screen",
                                    label: "SCREEN"
                                }
                            ]
                        },
                        {
                            kind: "slider",
                            key: "lock.fluidCentre",
                            name: "CENTRE WIDTH",
                            help: "How wide the centre with the clock and the password is. Narrower gives the side columns more room.",
                            sub: "THE CLOCK'S STAGE · NARROWER GIVES THE COLUMNS MORE ROOM",
                            min: 0.7,
                            max: 1.3,
                            step: 0.05,
                            fmt: "float2",
                            unit: "×"
                        },
                        {
                            kind: "slider",
                            key: "lock.fluidGap",
                            name: "GAP",
                            help: "The space between the cards in a column — and twice that between the columns and the centre.",
                            sub: "SPACE BETWEEN THE CARDS · TWICE THAT TO THE CENTRE",
                            min: 6,
                            max: 40,
                            step: 1,
                            fmt: "int",
                            unit: " PX"
                        },
                        {
                            kind: "toggle",
                            key: "lock.fluidFill",
                            name: "FILL THE COLUMNS",
                            help: "On: the side columns end level with the centre and one card (notifications, music or weather) takes the room left over. Off: every card keeps its own height.",
                            sub: "ONE CARD TAKES THE ROOM LEFT OVER · OFF: EVERY CARD ITS OWN HEIGHT"
                        },
                        {
                            kind: "choice",
                            key: "lock.fluidAlign",
                            name: "COLUMNS SIT",
                            help: "With FILL THE COLUMNS off (or when nothing in a column can stretch): where a shorter column sits — at the top, in the middle or at the bottom.",
                            sub: "WHERE A SHORTER COLUMN SITS",
                            options: [
                                {
                                    value: "top",
                                    label: "TOP"
                                },
                                {
                                    value: "centre",
                                    label: "MIDDLE"
                                },
                                {
                                    value: "bottom",
                                    label: "BOTTOM"
                                }
                            ]
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "MOTION & LIGHT",
                    help: "What moves on the FLUID lock: the card leans towards the pointer while the side columns float in front of it, a soft light follows the pointer, the module cards arrive one after another, the clock's digits roll in, and slow colour drifts behind the card. The wallpaper itself stays still.",
                    sub: "DEPTH · POINTER LIGHT · CARDS ONE BY ONE · CLOCK DIGITS · AURORA",
                    icon: "animation",
                    items: [
                        {
                            kind: "slider",
                            key: "lock.fluidDepth",
                            name: "DEPTH",
                            help: "How far the card leans towards the pointer and how far the side columns float in front of it. 0% keeps everything still.",
                            sub: "THE CARD LEANS TOWARDS THE POINTER · 0% IS STILL",
                            min: 0,
                            max: 1,
                            step: 0.05,
                            fmt: "percent"
                        },
                        {
                            kind: "toggle",
                            key: "lock.fluidGlow",
                            name: "POINTER LIGHT",
                            help: "A soft light in your accent colour follows the pointer across the card.",
                            sub: "A SOFT LIGHT UNDER THE POINTER"
                        },
                        {
                            kind: "toggle",
                            key: "lock.fluidStagger",
                            name: "CARDS ONE BY ONE",
                            help: "When the lock appears, the module cards rise into place one after another, left and right taking turns. Off: they come in with the rest of the card.",
                            sub: "THE MODULE CARDS RISE IN ONE AFTER ANOTHER"
                        },
                        {
                            kind: "choice",
                            key: "lock.fluidDigits",
                            name: "CLOCK DIGITS",
                            help: "How a new hour or minute arrives: ROLL slides it up into place as the old one leaves, FADE crosses over, SNAP simply changes.",
                            sub: "ROLL · FADE · SNAP",
                            options: [
                                {
                                    value: "roll",
                                    label: "ROLL"
                                },
                                {
                                    value: "fade",
                                    label: "FADE"
                                },
                                {
                                    value: "none",
                                    label: "SNAP"
                                }
                            ]
                        },
                        {
                            kind: "toggle",
                            key: "lock.fluidAurora",
                            name: "AURORA",
                            help: "Three soft lights in your colours drift slowly behind the card and shift a little against the pointer, so the card stands in front of them.",
                            sub: "SLOW COLOUR DRIFTING BEHIND THE CARD"
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "THE CENTRE",
                    help: "What the FLUID lock's centre shows besides the clock and the password: your photo and how big, the date and how it is written, the AM/PM pill and the line with caps lock and the keyboard layout.",
                    sub: "PHOTO · DATE · AM/PM · STATE LINE",
                    icon: "person",
                    items: [
                        {
                            kind: "choice",
                            key: "lock.fluidAvatar",
                            name: "PHOTO",
                            help: "Your ~/.face photo (or the person icon) between the clock and the password — large, medium, small or not at all.",
                            sub: "LARGE · MEDIUM · SMALL · OFF",
                            options: [
                                {
                                    value: "large",
                                    label: "LARGE"
                                },
                                {
                                    value: "medium",
                                    label: "MEDIUM"
                                },
                                {
                                    value: "small",
                                    label: "SMALL"
                                },
                                {
                                    value: "off",
                                    label: "OFF"
                                }
                            ]
                        },
                        {
                            kind: "choice",
                            key: "lock.fluidDate",
                            name: "DATE",
                            help: "The date under the clock: SATURDAY • 24 OCT, written out in full, short, or not at all.",
                            sub: "SATURDAY • 24 OCT · IN FULL · SHORT · OFF",
                            options: [
                                {
                                    value: "weekday",
                                    label: "SATURDAY • 24 OCT"
                                },
                                {
                                    value: "full",
                                    label: "SATURDAY, 24 OCTOBER 2026"
                                },
                                {
                                    value: "short",
                                    label: "SAT • 24.10"
                                },
                                {
                                    value: "off",
                                    label: "OFF"
                                }
                            ]
                        },
                        {
                            kind: "toggle",
                            key: "lock.fluidAmPm",
                            name: "AM / PM PILL",
                            help: "Under a twelve-hour clock: the pill with AM or PM. (A 24-hour clock never shows it.)",
                            sub: "THE PILL UNDER A TWELVE-HOUR CLOCK"
                        },
                        {
                            kind: "toggle",
                            key: "lock.stateHints",
                            name: "STATE LINE",
                            help: "The line under the password that warns about caps lock and num lock and names the keyboard layout.",
                            sub: "CAPS LOCK · NUM LOCK · KEYBOARD LAYOUT UNDER THE PASSWORD"
                        },
                        {
                            kind: "toggle",
                            key: "lock.avatarFace",
                            name: "YOUR FACE",
                            help: "Shows your ~/.face photo in the lock's avatar.",
                            sub: "YOUR ~/.FACE IN THE PHOTO CIRCLE"
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "BACKGROUND SHAPE",
                    help: "The FLUID lock can sit on one big shape instead of the plain blurred picture: which shape, how big, whether the wheel cycles it, and what fills the screen around it.",
                    sub: "THE BIG SHAPE BEHIND THE CARD",
                    icon: "interests",
                    items: [
                        {
                            kind: "choice",
                            key: "lock.backgroundShape",
                            name: "BACKGROUND SHAPE",
                            help: "The FLUID lock shows the wallpaper through one giant shape. OFF is the plain blurred wallpaper.",
                            sub: "THE GLYPH THE WALLPAPER SITS IN · OFF IS THE PLAIN BLUR",
                            options: [
                                {
                                    value: "off",
                                    label: "OFF · PLAIN BLUR"
                                },
                                {
                                    value: "circle",
                                    label: "CIRCLE"
                                },
                                {
                                    value: "arrow",
                                    label: "ARROW"
                                },
                                {
                                    value: "pill",
                                    label: "PILL"
                                },
                                {
                                    value: "burst",
                                    label: "BURST"
                                },
                                {
                                    value: "diamond",
                                    label: "DIAMOND"
                                },
                                {
                                    value: "clam",
                                    label: "CLAM"
                                },
                                {
                                    value: "pentagon",
                                    label: "PENTAGON"
                                }
                            ]
                        },
                        {
                            kind: "slider",
                            key: "lock.shapeSize",
                            name: "SHAPE SIZE",
                            help: "How far that shape reaches across the screen.",
                            sub: "HOW FAR THE GLYPH REACHES ACROSS THE SCREEN",
                            min: 0.5,
                            max: 1.3,
                            step: 0.02,
                            fmt: "float2",
                            unit: "×"
                        },
                        {
                            kind: "toggle",
                            key: "lock.shapeCycle",
                            name: "SHAPES CYCLE ON SCROLL",
                            help: "Scrolling over the lock background swaps the shape.",
                            sub: "WHEEL OVER THE LOCK BACKGROUND SWAPS THE GLYPH"
                        },
                        {
                            kind: "choice",
                            key: "lock.shapeSurround",
                            name: "AROUND THE SHAPE",
                            help: "With a background shape on the FLUID lock: what fills the rest of the screen — the plain paper colour, or the wallpaper blurred and dimmed.",
                            sub: "WITH A BACKGROUND SHAPE: WHAT FILLS THE REST OF THE SCREEN",
                            options: [
                                {
                                    value: "paper",
                                    label: "PLAIN · THE PAPER COLOUR"
                                },
                                {
                                    value: "blur",
                                    label: "WALLPAPER · BLURRED AND DIMMED"
                                }
                            ]
                        }
                    ]
                },
                {
                    kind: "page",
                    name: "MODULE DETAILS",
                    help: "Finer switches for the modules in the FLUID lock's side columns: what music and notifications do when there is nothing to show, the media cover, the weather forecast, the notifications, the power buttons, the fetch card, your face and the disk cell.",
                    sub: "THE FINER SWITCHES OF THE SIDE MODULES",
                    icon: "tune",
                    items: [
                        {
                            kind: "choice",
                            key: "lock.mediaIdle",
                            name: "IDLE MUSIC",
                            help: "When no song is playing: the full CARD, a SLIM low line (it grows back into the card the moment music starts), or HIDE it until something plays.",
                            sub: "THE FULL CARD · A SLIM LINE · HIDDEN UNTIL MUSIC PLAYS",
                            options: [
                                {
                                    value: "card",
                                    label: "CARD"
                                },
                                {
                                    value: "slim",
                                    label: "SLIM"
                                },
                                {
                                    value: "hide",
                                    label: "HIDE"
                                }
                            ]
                        },
                        {
                            kind: "choice",
                            key: "lock.notifsIdle",
                            name: "NO NOTIFICATIONS",
                            help: "With nothing new: the full dock saying all caught up, a SLIM low line, or HIDE it until a notification arrives.",
                            sub: "THE FULL DOCK · A SLIM LINE · HIDDEN UNTIL ONE ARRIVES",
                            options: [
                                {
                                    value: "card",
                                    label: "CARD"
                                },
                                {
                                    value: "slim",
                                    label: "SLIM"
                                },
                                {
                                    value: "hide",
                                    label: "HIDE"
                                }
                            ]
                        },
                        {
                            kind: "choice",
                            key: "lock.powerLayout",
                            name: "POWER BUTTONS",
                            help: "A ROW of four round icons (they get words once the card is wide enough), or WORDS: four labelled buttons, two by two.",
                            sub: "A ROW OF ICONS · OR FOUR LABELLED BUTTONS TWO BY TWO",
                            options: [
                                {
                                    value: "row",
                                    label: "ROW"
                                },
                                {
                                    value: "words",
                                    label: "WORDS"
                                }
                            ]
                        },
                        {
                            kind: "toggle",
                            key: "lock.sessionPalette",
                            name: "FETCH COLOUR DOTS",
                            help: "The row of your theme's colours under the fetch card's lines.",
                            sub: "YOUR THEME'S COLOURS UNDER THE FETCH LINES"
                        },
                        {
                            kind: "toggle",
                            key: "lock.mediaArtwork",
                            name: "MEDIA COVER BACKGROUND",
                            help: "Fills the media card with the song's cover art behind a veil.",
                            sub: "THE COVER, FULL-BLEED, BEHIND THE MEDIA CARD"
                        },
                        {
                            kind: "toggle",
                            key: "lock.weatherForecast",
                            name: "WEATHER FORECAST",
                            help: "The hourly forecast strip at the bottom of the weather card.",
                            sub: "THE HOURLY STRIP ALONG THE WEATHER CARD'S BOTTOM"
                        },
                        {
                            kind: "toggle",
                            key: "lock.weatherHighLow",
                            name: "WEATHER HIGH / LOW",
                            help: "Today's highest and lowest temperature under the \"feels like\" line.",
                            sub: "TODAY'S RANGE UNDER THE FEELS LINE"
                        },
                        {
                            kind: "slider",
                            key: "lock.notifsCount",
                            name: "NOTIFICATION ENTRIES",
                            help: "How many notifications (or app groups) the lock shows — in the FLUID lock's dock and in the SOFT lock's bell panel.",
                            sub: "HOW MANY GROUPS OR ITEMS THE DOCK SHOWS",
                            min: 1,
                            max: 8,
                            step: 1,
                            fmt: "int"
                        },
                        {
                            kind: "toggle",
                            key: "lock.notifsGrouped",
                            name: "GROUP NOTIFICATIONS",
                            help: "Groups the dock's notifications by app, one row each; click a row to unfold it. Off lists them one by one.",
                            sub: "THE DOCK: ONE ROW PER APP · CLICK UNFOLDS · OFF IS A FLAT LIST"
                        },
                        {
                            kind: "toggle",
                            key: "lock.hideNotifs",
                            name: "HIDE NOTIFICATION CONTENT",
                            help: "Privacy: the lock only shows how many notifications there are, never what they say.",
                            sub: "PRIVACY: NOTHING SHOWS UNTIL YOU UNLOCK"
                        },
                        {
                            kind: "toggle",
                            key: "lock.avatarFace",
                            name: "YOUR FACE",
                            help: "Shows your ~/.face photo in the lock's avatar.",
                            sub: "WEAR THE ~/.FACE PHOTO IN THE AVATAR GLYPH"
                        },
                        {
                            kind: "toggle",
                            key: "lock.resourcesDisk",
                            name: "DISK CELL",
                            help: "Adds a third resource cell with disk usage to the FLUID lock.",
                            sub: "A THIRD RESOURCE CELL WITH DISK USAGE"
                        }
                    ]
                }
            ]
        },
        {
            kind: "page",
            name: "VELVET LOCK",
            help: "The original VELVET lock: the wallpaper dimmed behind it, an enormous clock and the password drawn as tally marks. It has one switch of its own; the dim is under BACKGROUND & MUSIC.",
            sub: "THE ORIGINAL HARD-EDGED LOCK",
            icon: "bolt",
            style: "velvet",
            items: [
                {
                    kind: "toggle",
                    key: "lock.showMedia",
                    name: "SHOW WHAT'S PLAYING",
                    help: "The track and artist on the original VELVET lock style.",
                    sub: "TRACK AND ARTIST ON THE LOCK SCREEN"
                },
                {
                    kind: "choice",
                    key: "lock.vClock",
                    name: "CLOCK HOURS",
                    help: "Which hours the VELVET lock's clock shows: whatever the bar's clock does, always 24 hours, or 12 hours. Shared with the lock of your look.",
                    sub: "FOLLOW THE BAR · 24 H · 12 H · SHARED WITH THE LOCK OF YOUR LOOK",
                    options: [
                        {
                            value: "auto",
                            label: "FOLLOW THE BAR"
                        },
                        {
                            value: "24h",
                            label: "24 HOURS"
                        },
                        {
                            value: "12h",
                            label: "12 HOURS"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "lock.vSeconds",
                    name: "SECONDS",
                    help: "Adds the seconds beside the minutes. Shared with the lock of your look.",
                    sub: "SMALL SECONDS BESIDE THE MINUTES"
                },
                {
                    kind: "slider",
                    key: "lock.vScale",
                    name: "CLOCK SIZE",
                    help: "How big the clock is. Shared with the lock of your look.",
                    sub: "100% = THE ORIGINAL SIZE",
                    min: 0.5,
                    max: 1.3,
                    step: 0.05,
                    fmt: "percent"
                },
                {
                    kind: "choice",
                    key: "lock.vDate",
                    name: "DATE",
                    help: "How the date under the clock is written — or no date. Shared with the lock of your look.",
                    sub: "LONG · SHORT · NUMERIC · OFF",
                    options: [
                        {
                            value: "long",
                            label: "LONG"
                        },
                        {
                            value: "short",
                            label: "SHORT"
                        },
                        {
                            value: "numeric",
                            label: "NUMERIC"
                        },
                        {
                            value: "off",
                            label: "OFF"
                        }
                    ]
                }
            ]
        },
        {
            kind: "page",
            name: "VIBE FACES",
            help: "The lock of the look you wear — the terminal, the game, the HUD, the newspaper, the glass, the book, the poster, the quiet clock, the Vindows logon — and everything you can change about it: the clock, how the date is written, how typing looks, what is shown, how the wallpaper sits behind and how the lock arrives.",
            sub: "REMEMBERED PER LOOK · CLOCK · TYPING · EFFECTS · MUSIC · ENTRANCE",
            icon: "palette",
            style: "vibe",
            items: [
                {
                    kind: "info",
                    name: "THE LOCK OF YOUR LOOK",
                    help: "Every look has its own lock screen — a terminal login, a game's PRESS START, a HUD, a newspaper, frosted glass, a book, a poster, a quiet clock, the logon screen of a Vindows edition. Every switch here belongs to the look you wear: each look remembers its own lock — its clock, typing, effect, music and entrance — and RESET THIS LOOK (VISUALS → THIS LOOK) brings back its design. The picture beside the list updates as you change them.",
                    sub: "EACH LOOK REMEMBERS ITS OWN LOCK · THE PICTURE BESIDE THE LIST SHOWS IT LIVE"
                },
                {
                    kind: "choice",
                    key: "lock.vClock",
                    name: "CLOCK HOURS",
                    help: "Which hours the look's lock clock shows: whatever the bar's clock does, always 24 hours, or 12 hours with AM / PM.",
                    sub: "FOLLOW THE BAR · 24 H · 12 H",
                    options: [
                        {
                            value: "auto",
                            label: "FOLLOW THE BAR"
                        },
                        {
                            value: "24h",
                            label: "24 HOURS"
                        },
                        {
                            value: "12h",
                            label: "12 HOURS · AM / PM"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "lock.vSeconds",
                    name: "SECONDS",
                    help: "Adds the seconds to the clock (the clock gets a little smaller to make room).",
                    sub: "HH:MM:SS INSTEAD OF HH:MM"
                },
                {
                    kind: "slider",
                    key: "lock.vScale",
                    name: "CLOCK SIZE",
                    help: "How big the look's clock is. 100% is the look's own size.",
                    sub: "100% = THE LOOK'S OWN SIZE",
                    min: 0.5,
                    max: 1.4,
                    step: 0.05,
                    fmt: "percent"
                },
                {
                    kind: "choice",
                    key: "lock.vClockColour",
                    name: "CLOCK COLOUR",
                    help: "The clock in the look's own colour, the accent, the second accent, ink, white or black.",
                    sub: "THE LOOK'S OWN · ACCENT · ALT · INK · WHITE · BLACK",
                    options: [
                        { value: "auto", label: "THE LOOK'S OWN" },
                        { value: "accent", label: "ACCENT" },
                        { value: "alt", label: "SECOND ACCENT" },
                        { value: "ink", label: "INK" },
                        { value: "white", label: "WHITE" },
                        { value: "black", label: "BLACK" }
                    ]
                },
                {
                    kind: "choice",
                    key: "lock.vClockFont",
                    name: "CLOCK FONT",
                    help: "The clock's typeface: the look's own, or any of the installed display faces.",
                    sub: "THE LOOK'S OWN OR AN INSTALLED FACE",
                    options: root.lockClockFonts
                },
                {
                    kind: "choice",
                    key: "lock.vDate",
                    name: "DATE",
                    help: "How the date is written under or beside the clock — or no date at all.",
                    sub: "LONG · SHORT · NUMERIC · OFF",
                    options: [
                        {
                            value: "long",
                            label: "LONG · SATURDAY, 3 OCTOBER"
                        },
                        {
                            value: "short",
                            label: "SHORT · SAT 3 OCT"
                        },
                        {
                            value: "numeric",
                            label: "NUMERIC · 03.10.2026"
                        },
                        {
                            value: "off",
                            label: "OFF"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "lock.vMask",
                    name: "TYPING",
                    help: "What typing the password looks like: the look's own dots, stars, a bar that fills, just a count of letters — or nothing at all.",
                    sub: "THE LOOK'S DOTS · STARS · A FILLING BAR · A COUNT · NOTHING",
                    options: [
                        {
                            value: "dots",
                            label: "THE LOOK'S OWN"
                        },
                        {
                            value: "stars",
                            label: "STARS"
                        },
                        {
                            value: "bar",
                            label: "A FILLING BAR"
                        },
                        {
                            value: "count",
                            label: "A COUNT"
                        },
                        {
                            value: "none",
                            label: "NOTHING"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "lock.vHello",
                    name: "WELCOME LINE",
                    help: "The words in the empty password field.",
                    sub: "THE WORDS IN THE EMPTY FIELD",
                    options: [
                        {
                            value: "",
                            label: "THE LOOK'S OWN"
                        },
                        {
                            value: "Welcome back",
                            label: "WELCOME BACK"
                        },
                        {
                            value: "Enter password",
                            label: "ENTER PASSWORD"
                        },
                        {
                            value: "Hello",
                            label: "HELLO"
                        },
                        {
                            value: "Locked",
                            label: "LOCKED"
                        },
                        {
                            value: "Who goes there?",
                            label: "WHO GOES THERE?"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "lock.vUser",
                    name: "NAME AND PICTURE",
                    help: "Shows your name and your ~/.face picture on the lock.",
                    sub: "WHO IS LOGGING IN"
                },
                {
                    kind: "toggle",
                    key: "lock.vInfo",
                    name: "BATTERY AND NETWORK",
                    help: "The small line with the battery and the network.",
                    sub: "BATTERY · NETWORK"
                },
                {
                    kind: "toggle",
                    key: "lock.vMedia",
                    name: "SONG",
                    help: "The track and artist that are playing, under the clock.",
                    sub: "WHAT IS PLAYING"
                },
                {
                    kind: "toggle",
                    key: "lock.vWeather",
                    name: "WEATHER",
                    help: "The weather line (needs a weather location in the bar settings).",
                    sub: "TEMPERATURE · SKY"
                },
                {
                    kind: "toggle",
                    key: "lock.vHints",
                    name: "HINTS",
                    help: "The small hints — Enter to unlock, caps lock.",
                    sub: "KEYS THAT WORK · CAPS LOCK"
                },
                {
                    kind: "choice",
                    key: "lock.vBlur",
                    name: "WALLPAPER BLUR",
                    help: "How soft the wallpaper is behind the look's lock. The look's own blur by default.",
                    sub: "THE LOOK'S OWN · SHARP … FULL",
                    options: [
                        {
                            value: "auto",
                            label: "THE LOOK'S OWN"
                        },
                        {
                            value: "0",
                            label: "SHARP"
                        },
                        {
                            value: "0.3",
                            label: "LIGHT"
                        },
                        {
                            value: "0.6",
                            label: "SOFT"
                        },
                        {
                            value: "1",
                            label: "FULL"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "lock.vDim",
                    name: "WALLPAPER DIM",
                    help: "How far the wallpaper is darkened behind the look's lock. The look's own by default.",
                    sub: "THE LOOK'S OWN · NONE … BLACK",
                    options: [
                        {
                            value: "auto",
                            label: "THE LOOK'S OWN"
                        },
                        {
                            value: "0",
                            label: "NONE"
                        },
                        {
                            value: "0.25",
                            label: "LIGHT"
                        },
                        {
                            value: "0.5",
                            label: "HALF"
                        },
                        {
                            value: "0.75",
                            label: "DEEP"
                        },
                        {
                            value: "0.95",
                            label: "NEARLY BLACK"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "lock.vFx",
                    name: "EFFECT",
                    help: "The atmosphere over the lock: stars drifting up, embers, rain, snow, a CRT's scanlines, film grain or a dark vignette. Each look has its own; change it and the look remembers it.",
                    sub: "STARS · EMBERS · RAIN · SNOW · SCANLINES · GRAIN · VIGNETTE",
                    options: [
                        {
                            value: "none",
                            label: "NONE"
                        },
                        {
                            value: "stars",
                            label: "STARS"
                        },
                        {
                            value: "embers",
                            label: "EMBERS"
                        },
                        {
                            value: "rain",
                            label: "RAIN"
                        },
                        {
                            value: "snow",
                            label: "SNOW"
                        },
                        {
                            value: "scanlines",
                            label: "SCANLINES"
                        },
                        {
                            value: "grain",
                            label: "FILM GRAIN"
                        },
                        {
                            value: "vignette",
                            label: "VIGNETTE"
                        }
                    ]
                },
                {
                    kind: "slider",
                    key: "lock.vFxStrength",
                    name: "EFFECT STRENGTH",
                    help: "How strong the effect is.",
                    sub: "100% = AS DESIGNED",
                    min: 0.2,
                    max: 2.0,
                    step: 0.1,
                    fmt: "percent",
                    when: { key: "lock.vFx", not: "none" }
                },
                {
                    kind: "toggle",
                    key: "lock.vGlow",
                    name: "MUSIC GLOW",
                    help: "The screen's edges glow in the accent with the music — a slow breath while it is quiet.",
                    sub: "THE EDGES BREATHE WITH THE MUSIC"
                },
                {
                    kind: "toggle",
                    key: "lock.vViz",
                    name: "MUSIC ALONG AN EDGE",
                    help: "The music as a wave, bars or a line along one edge of the lock.",
                    sub: "A VISUALIZER ON THE LOOK'S LOCK"
                },
                {
                    kind: "choice",
                    key: "lock.vVizEdge",
                    name: "MUSIC EDGE",
                    help: "Which edge the music stands on.",
                    sub: "BOTTOM · TOP · LEFT · RIGHT",
                    when: { key: "lock.vViz", is: true },
                    options: [
                        { value: "bottom", label: "BOTTOM" },
                        { value: "top", label: "TOP" },
                        { value: "left", label: "LEFT" },
                        { value: "right", label: "RIGHT" }
                    ]
                },
                {
                    kind: "choice",
                    key: "lock.vVizStyle",
                    name: "MUSIC STYLE",
                    help: "A filled wave, rounded bars or a thin line.",
                    sub: "WAVE · BARS · LINE",
                    when: { key: "lock.vViz", is: true },
                    options: [
                        { value: "wave", label: "WAVE" },
                        { value: "bars", label: "BARS" },
                        { value: "line", label: "LINE" }
                    ]
                },
                {
                    kind: "slider",
                    key: "lock.vVizReach",
                    name: "MUSIC HEIGHT",
                    help: "How far the music may rise from its edge.",
                    sub: "SHARE OF THE SCREEN",
                    min: 0.04,
                    max: 0.5,
                    step: 0.01,
                    fmt: "percent",
                    when: { key: "lock.vViz", is: true }
                },
                {
                    kind: "choice",
                    key: "lock.vEntrance",
                    name: "ENTRANCE",
                    help: "How the lock arrives. Picking one plays it in the picture.",
                    sub: "FADE · RISE · ZOOM · NONE",
                    options: [
                        {
                            value: "fade",
                            label: "FADE"
                        },
                        {
                            value: "rise",
                            label: "RISE FROM BELOW"
                        },
                        {
                            value: "zoom",
                            label: "ZOOM IN"
                        },
                        {
                            value: "drop",
                            label: "DROP IN · BOUNCE"
                        },
                        {
                            value: "slam",
                            label: "SLAM"
                        },
                        {
                            value: "glitch",
                            label: "GLITCH"
                        },
                        {
                            value: "none",
                            label: "NO ANIMATION"
                        }
                    ]
                }
            ]
        },
        {
            kind: "page",
            name: "CLOCK",
            help: "The lock's clock, for the FLUID and the SOFT style alike: its size, a face with digits or hands, the shape behind it, its font and the size of its digits, its colours, the lyric line under it, and the quiet mode that leaves only the clock after a while.",
            sub: "SIZE · FACE · SHAPE · FONT · COLOURS — FLUID AND SOFT",
            icon: "schedule",
            items: [
                {
                    kind: "slider",
                    key: "lock.clockScale",
                    name: "CLOCK SIZE",
                    help: "How big the lock's clock is — on the FLUID card and on the SOFT lock.",
                    sub: "THE BIG CLOCK ON THE CARD — OR ON THE SOFT LOCK",
                    min: 0.5,
                    max: 1.4,
                    step: 0.05,
                    fmt: "percent"
                },
                {
                    kind: "choice",
                    key: "lock.clockFace",
                    name: "CLOCK FACE",
                    help: "How the digits are drawn. LIGHT is a thin headline, HEAVY the house type, MONO monospaced, DOTS a drawn dot matrix, ANALOG a round dial with hands. The SOFT lock uses DOTS and ANALOG; its typeface comes from CLOCK FONT.",
                    sub: "HOW THE DIGITS ARE DRAWN",
                    options: [
                        {
                            value: "",
                            label: "LIGHT · A THIN HEADLINE"
                        },
                        {
                            value: "display",
                            label: "HEAVY · THE HOUSE TYPE"
                        },
                        {
                            value: "mono",
                            label: "MONO"
                        },
                        {
                            value: "dots",
                            label: "DOTS · A DRAWN DOT MATRIX"
                        },
                        {
                            value: "analog",
                            label: "ANALOG · HANDS ON A ROUND DIAL"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "lock.clockShape",
                    name: "CLOCK SHAPE",
                    help: "Puts the clock into a shape — any of the sixteen (circle, square, cookie, gear, scallop, flower, clover, wavy, pebble, pentagon, soft pentagon, hexagon, diamond, triangle, star, burst) — with the hours over the minutes and the hands sweeping over them. NONE: side by side on the FLUID lock, stacked on the SOFT lock; LINE: HH:MM on one row.",
                    sub: "THE CLOCK IN A SHAPE · HOURS OVER MINUTES · HANDS SWEEP OVER THEM",
                    options: [
                        {
                            value: "none",
                            label: "NONE · SIDE BY SIDE"
                        },
                        {
                            value: "line",
                            label: "LINE · HH:MM ON ONE ROW"
                        },
                        {
                            value: "circle",
                            label: "CIRCLE"
                        },
                        {
                            value: "square",
                            label: "SQUARE"
                        },
                        {
                            value: "cookie",
                            label: "COOKIE"
                        },
                        {
                            value: "sun",
                            label: "GEAR"
                        },
                        {
                            value: "scallop",
                            label: "SCALLOP"
                        },
                        {
                            value: "flower",
                            label: "FLOWER"
                        },
                        {
                            value: "clover",
                            label: "CLOVER"
                        },
                        {
                            value: "wavy",
                            label: "WAVY"
                        },
                        {
                            value: "blob",
                            label: "PEBBLE"
                        },
                        {
                            value: "penta",
                            label: "PENTAGON"
                        },
                        {
                            value: "pentagon",
                            label: "SOFT PENTAGON"
                        },
                        {
                            value: "hexagon",
                            label: "HEXAGON"
                        },
                        {
                            value: "diamond",
                            label: "DIAMOND"
                        },
                        {
                            value: "triangle",
                            label: "TRIANGLE"
                        },
                        {
                            value: "star",
                            label: "STAR"
                        },
                        {
                            value: "burst",
                            label: "BURST"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "lock.clockFont",
                    name: "CLOCK FONT",
                    help: "The typeface of the digits. BY CLOCK FACE uses the face's own font (and the round soft font on the SOFT lock).",
                    sub: "THE TYPEFACE OF THE DIGITS · DOTS AND MONO COME FROM CLOCK FACE",
                    options: root.clockFontChoices
                },
                {
                    kind: "slider",
                    key: "lock.clockFontScale",
                    name: "CLOCK FONT SIZE",
                    help: "How big the digits sit inside a clock shape — and the size of the SOFT lock's bare digits.",
                    sub: "HOW BIG THE DIGITS SIT INSIDE A CLOCK SHAPE · THE SOFT LOCK'S BARE DIGITS TOO",
                    min: 0.6,
                    max: 1.6,
                    step: 0.05,
                    fmt: "percent"
                },
                {
                    kind: "choice",
                    key: "lock.clockColours",
                    name: "CLOCK COLOURS",
                    help: "The colours of the SOFT lock's digits: TWO-TONE (hours in the accent, minutes white), all ACCENT, or all INK (white).",
                    sub: "TWO-TONE: HOURS IN THE ACCENT · ALL ACCENT · ALL INK",
                    options: [
                        {
                            value: "twotone",
                            label: "TWO-TONE"
                        },
                        {
                            value: "accent",
                            label: "ACCENT"
                        },
                        {
                            value: "ink",
                            label: "INK"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "lock.lyrics",
                    name: "LYRICS",
                    help: "Shows the line the song is singing: under the date on the FLUID lock, in the greeting's cloud on the SOFT lock. Works even with the lyrics panel off.",
                    sub: "THE LINE THE SONG IS SINGING, UNDER THE DATE · WORKS EVEN WITH THE LYRICS PANEL OFF"
                },
                {
                    kind: "choice",
                    key: "lock.ambientAfter",
                    name: "AMBIENT AFTER",
                    help: "After this long without a key or mouse movement the lock steps back — only the clock, the lyric and the music stay. Any key brings everything back; typing works right away.",
                    sub: "NO INPUT FOR A WHILE: ONLY THE CLOCK, THE LYRIC AND THE MUSIC STAY · ANY KEY BRINGS IT BACK",
                    options: [
                        {
                            value: "0",
                            label: "NEVER"
                        },
                        {
                            value: "15",
                            label: "15 S"
                        },
                        {
                            value: "30",
                            label: "30 S"
                        },
                        {
                            value: "60",
                            label: "1 MIN"
                        },
                        {
                            value: "120",
                            label: "2 MIN"
                        }
                    ]
                }
            ]
        },
        {
            kind: "page",
            name: "BACKGROUND & MUSIC",
            help: "What is behind the lock and what moves along its edge: the blur and the dim of the wallpaper, and the cava visualizer — on or off, which edge, bars, wave or line, how tall and how dense.",
            sub: "BLUR · DIM · THE MUSIC ALONG A SCREEN EDGE",
            icon: "blur_on",
            items: [
                {
                    kind: "slider",
                    key: "lock.blur",
                    name: "BLUR LEVEL",
                    help: "How soft the wallpaper behind the lock is. 0 is sharp.",
                    sub: "HOW SOFT THE WALLPAPER BEHIND THE LOCK IS · 0 = SHARP",
                    min: 0,
                    max: 1,
                    step: 0.05,
                    fmt: "percent"
                },
                {
                    kind: "slider",
                    key: "lock.backgroundDim",
                    name: "BACKGROUND DIM",
                    help: "How far the wallpaper behind the lock is darkened. 0 keeps it bright.",
                    sub: "HOW FAR THE WALLPAPER DROPS BACK",
                    min: 0,
                    max: 0.95,
                    step: 0.05,
                    fmt: "percent"
                },
                {
                    kind: "toggle",
                    key: "lock.visualizer",
                    name: "CAVA VISUALIZER",
                    help: "Draws the music along a screen edge while locked (FLUID and SOFT lock). Needs cava.",
                    sub: "THE MUSIC ALONG A SCREEN EDGE WHILE LOCKED"
                },
                {
                    kind: "choice",
                    key: "lock.visualizerEdge",
                    name: "SCREEN EDGE",
                    help: "Which screen edge the visualizer stands on.",
                    sub: "WHERE THE VISUALIZER STANDS",
                    options: [
                        {
                            value: "bottom",
                            label: "BOTTOM"
                        },
                        {
                            value: "top",
                            label: "TOP"
                        },
                        {
                            value: "left",
                            label: "LEFT"
                        },
                        {
                            value: "right",
                            label: "RIGHT"
                        }
                    ]
                },
                {
                    kind: "choice",
                    key: "lock.visualizerStyle",
                    name: "VISUALIZER STYLE",
                    help: "WAVE is a smooth filled wave, BARS rounded bars, LINE one thin stroke.",
                    sub: "SMOOTH WAVE, ROUNDED BARS OR ONE THIN LINE",
                    options: [
                        {
                            value: "wave",
                            label: "WAVE"
                        },
                        {
                            value: "bars",
                            label: "BARS"
                        },
                        {
                            value: "line",
                            label: "LINE"
                        }
                    ]
                },
                {
                    kind: "slider",
                    key: "lock.visualizerReach",
                    name: "VISUALIZER HEIGHT",
                    help: "How far the visualizer may rise from its edge, as a share of the screen.",
                    sub: "HOW FAR IT MAY RISE · SHARE OF THE SCREEN",
                    min: 0.05,
                    max: 0.4,
                    step: 0.01,
                    fmt: "percent"
                },
                {
                    kind: "choice",
                    key: "lock.visualizerDensity",
                    name: "BAR DENSITY",
                    help: "How close the bars stand — FINE is dense and thin, WIDE sparse.",
                    sub: "HOW CLOSE THE VISUALIZER'S BARS STAND",
                    options: [
                        {
                            value: "fine",
                            label: "FINE"
                        },
                        {
                            value: "normal",
                            label: "NORMAL"
                        },
                        {
                            value: "wide",
                            label: "WIDE"
                        }
                    ]
                }
            ]
        },
        {
            kind: "page",
            name: "PASSWORD & HINTS",
            help: "What you see while typing the password, the eye to peek at it, and the caps/num-lock line.",
            sub: "GLYPHS, PEEK AND THE STATE LINE",
            icon: "password",
            items: [
                {
                    kind: "choice",
                    key: "lock.passwordShapes",
                    name: "PASSWORD SHAPES",
                    help: "POP plants a different shape for every letter that pops in and cools to white; SETTLE lets each shape settle into a circle; CIRCLES shows plain dots.",
                    sub: "THE GLYPHS THAT SHOW WHILE YOU TYPE",
                    options: [
                        {
                            value: "pop",
                            label: "POP · SHAPES THAT POP AND COOL"
                        },
                        {
                            value: "settle",
                            label: "SETTLE · A DECK THAT SETTLES INTO CIRCLES"
                        },
                        {
                            value: "circles",
                            label: "CIRCLES ONLY"
                        }
                    ]
                },
                {
                    kind: "toggle",
                    key: "lock.passwordPeek",
                    name: "PEEK AT PASSWORD",
                    help: "An eye in the password field that shows the letters you typed instead of shapes.",
                    sub: "THE EYE IN THE PASSWORD ISLAND TURNS GLYPHS INTO LETTERS"
                },
                {
                    kind: "toggle",
                    key: "lock.stateHints",
                    name: "STATE HINTS",
                    help: "Warns when Caps Lock or Num Lock is on, and (FLUID) shows the keyboard layout.",
                    sub: "CAPS/NUM LOCK WARNINGS AND THE KEYBOARD LAYOUT UNDER THE ISLANDS"
                }
            ]
        },
        {
            kind: "page",
            name: "SECURITY & STARTUP",
            help: "When the lock comes up by itself and how it checks your password: locking at boot, following loginctl lock requests, which PAM service is asked, and the details PAM gives when something went wrong.",
            sub: "LOCK AT BOOT · LOGINCTL · PAM",
            icon: "shield_lock",
            items: [
                {
                    kind: "toggle",
                    key: "lock.lockOnStart",
                    name: "LOCK AT BOOT",
                    help: "Locks as soon as the shell starts. Together with SDDM auto-login the lock becomes your login screen.",
                    sub: "LOG IN THROUGH THE LOCK — PAIR WITH SDDM AUTO-LOGIN"
                },
                {
                    kind: "toggle",
                    key: "lock.listenToLogind",
                    name: "FOLLOW LOGINCTL",
                    help: "Also locks when the system asks for it: loginctl lock-session, and before suspend.",
                    sub: "ALSO LOCK ON loginctl lock-session AND ON SUSPEND"
                },
                {
                    kind: "choice",
                    key: "lock.pamConfig",
                    name: "PAM SERVICE",
                    help: "Which /etc/pam.d service checks your password. AUTO tries velvet, hyprlock, swaylock, system-auth and login in turn. Change it only if a correct password is rejected.",
                    sub: "CHANGE THIS IF A CORRECT PASSWORD IS REJECTED",
                    options: [
                        {
                            value: "auto",
                            label: "AUTO"
                        },
                        {
                            value: "velvet",
                            label: "VELVET"
                        },
                        {
                            value: "hyprlock",
                            label: "HYPRLOCK"
                        },
                        {
                            value: "swaylock",
                            label: "SWAYLOCK"
                        },
                        {
                            value: "system-auth",
                            label: "SYSTEM-AUTH"
                        },
                        {
                            value: "login",
                            label: "LOGIN"
                        }
                    ]
                },
                {
                    kind: "info",
                    name: "PAM DETAIL",
                    help: "Details from PAM, only filled in when authentication went wrong.",
                    sub: "ONLY FILLED IN WHEN SOMETHING WENT WRONG",
                    live: "lockError"
                }
            ]
        }
    ]

    readonly property var power: [
        {
            kind: "info",
            help: "The Velvet version that is running.",
            name: "VELVET BUILD",
            live: "version"
        },
        {
            kind: "action",
            name: "LOCK SCREEN",
            help: "Locks the screen now.",
            sub: "SECURE THE SESSION",
            fn: "lock",
            danger: false
        },
        {
            kind: "action",
            name: "SLEEP",
            help: "Suspends to RAM — quick to wake, needs a little power.",
            sub: "SUSPEND TO RAM",
            fn: "suspend"
        },
        {
            kind: "action",
            name: "HIBERNATE",
            help: "Suspends to disk — no power at all, slower to wake. Needs swap set up for hibernation.",
            sub: "SUSPEND TO DISK",
            fn: "hibernate"
        },
        {
            kind: "action",
            name: "RESTART",
            help: "Restarts the computer.",
            sub: "REBOOT THE MACHINE",
            fn: "reboot",
            danger: true
        },
        {
            kind: "action",
            name: "SHUT DOWN",
            help: "Turns the computer off.",
            sub: "POWER OFF",
            fn: "shutdown",
            danger: true
        },
        {
            kind: "action",
            name: "LOG OUT",
            help: "Ends the Hyprland session and returns to the login screen.",
            sub: "EXIT HYPRLAND",
            fn: "logout",
            danger: true
        }
    ]

    // =============================================================== HOME
    // The Super+Tab title screen's own knobs. The name itself is edited on
    // the HOME page (click it or press E) — a text field belongs where you
    // see the result, not three menus deep.
    readonly property var homePage: [
        {
            kind: "info",
            name: "PLAYER NAME",
            help: "Your name on the HOME title screen. Edit it on the HOME page — click the name or press E.",
            sub: "EDIT IT ON THE HOME PAGE — CLICK THE NAME OR PRESS E"
        },
        {
            kind: "toggle",
            key: "home.avatarFace",
            name: "YOUR FACE",
            help: "Shows your ~/.face photo in the HOME profile card; off shows a badge with your initial.",
            sub: "WEAR THE ~/.FACE PHOTO IN THE PROFILE CARD"
        },
        {
            kind: "action",
            name: "CHOOSE YOUR PHOTO",
            help: "A coverflow of your pictures — pick one and it becomes your ~/.face photo.",
            sub: "A COVERFLOW OVER YOUR PICTURES — PICK ONE AND IT BECOMES YOUR FACE",
            fn: "openFacePicker"
        },
        {
            kind: "choice",
            key: "home.faceStyle",
            name: "MATCH THE WALLPAPER",
            aka: "PROFILBILD WALLPAPER FARBEN · AVATAR FARBE · PROFILBILD ANPASSEN",
            help: "Your picture in the wallpaper's colours — on the lock, in HOME and on the desktop widgets, and again with every new wallpaper. PHOTO wears it as it is; TINT lays the wallpaper's colours over it; DUOTONE paints it in them, from deep to light; POSTER cuts it into four flat tones of them.",
            sub: "PHOTO · TINT · DUOTONE · POSTER — FOLLOWS EVERY WALLPAPER",
            options: [
                { value: "photo", label: "PHOTO" },
                { value: "tint", label: "TINT" },
                { value: "duotone", label: "DUOTONE" },
                { value: "poster", label: "POSTER" }
            ]
        },
        {
            kind: "choice",
            key: "home.winMode",
            name: "SUPER+TAB OPENS",
            help: "How the settings open: FULLSCREEN (the whole screen, the default), MAXIMISED (fills the screen, the bar stays visible) or a WINDOW you can move and resize.",
            sub: "FULLSCREEN · MAXIMISED · A WINDOW",
            options: [
                { value: "fullscreen", label: "FULLSCREEN" },
                { value: "maximized", label: "MAXIMISED" },
                { value: "window", label: "A WINDOW" }
            ]
        },
        {
            kind: "toggle",
            key: "home.welcome",
            name: "WELCOME PAGE AT START",
            help: "The welcome page with the first steps opens every time you log in. Switch it off here or on the page itself; WELCOME PAGE below opens it any time.",
            sub: "THE FIRST STEPS, EVERY TIME YOU LOG IN"
        },
        {
            kind: "action",
            name: "WELCOME PAGE",
            help: "Opens the welcome page with the first steps and every important key.",
            sub: "THE FIRST STEPS AGAIN",
            fn: "openWelcome"
        },
        {
            kind: "action",
            name: "GO TO THE HOME PAGE",
            help: "Shows the HOME title screen.",
            sub: "SEE THE TITLE SCREEN",
            fn: "openHome"
        }
    ]

    // =============================================================== SEARCH
    // Flattens every tab and page into one list so the search overlay can
    // reach a setting three levels deep in one keystroke.
    // A setting looked up by its config key — the layout tab uses this to show
    // a module's own settings next to the module rather than making you go and
    // find them.
    // Every row in the whole schema, info rows included. `flat` deliberately
    // leaves those out — they are not navigable — but a module inspector still
    // has to be able to show one, and looking a key up in `flat` is how
    // WEATHER ended up with a LOCATION line that never appeared.
    readonly property var allRows: {
        const out = [];
        const walk = items => {
            for (let i = 0; i < items.length; i++) {
                const it = items[i];
                if (it.kind === "page")
                    walk(it.items);
                else
                    out.push(it);
            }
        };
        for (let t = 0; t < root.tabs.length; t++)
            walk(root.tabs[t].items ?? []);
        return out;
    }

    function byKey(key: string): var {
        const rows = root.allRows;
        for (let i = 0; i < rows.length; i++)
            if ((rows[i].key ?? rows[i].valueKey) === key)
                return rows[i];
        return null;
    }

    function rowsFor(keys: var): var {
        const out = [];
        for (let i = 0; i < (keys?.length ?? 0); i++) {
            const it = root.byKey(keys[i]);
            if (it)
                out.push(it);
        }
        return out;
    }

    // Pages are in it too ("ARRANGE BY HAND", "SOFT LOCK" …): choosing one
    // opens it. A setting that sits on two pages (ENTRANCE SPEED is on the
    // SOFT and the FLUID page) is listed once — on the page of the lock
    // style you wear, when it is on one.
    readonly property var flat: {
        const out = [];
        const at = {};
        const look = Config.lock.look;
        const walk = (items, trail, tabIndex, style) => {
            for (let i = 0; i < items.length; i++) {
                const it = items[i];
                if (it.kind === "info" || !root.shown(it))
                    continue;
                const entry = {
                    item: it,
                    trail: trail,
                    tabIndex: tabIndex,
                    style: it.kind === "page" ? (it.style ?? style) : style,
                    path: trail.concat([it.name]).join("  ›  ")
                };
                const key = it.key ?? "";
                if (key !== "" && at[key] !== undefined) {
                    if (entry.style === look && out[at[key]].style !== look)
                        out[at[key]] = entry;
                } else {
                    if (key !== "")
                        at[key] = out.length;
                    out.push(entry);
                }
                if (it.kind === "page")
                    walk(it.items ?? [], trail.concat([it.name]), tabIndex, it.style ?? style);
            }
        };
        for (let t = 0; t < root.tabs.length; t++)
            walk(root.tabs[t].items ?? [], [root.tabs[t].name], t, "");
        return out;
    }
}
