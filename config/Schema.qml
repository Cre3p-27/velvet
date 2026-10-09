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
            sub: "BRIGHTNESS · NIGHT LIGHT · IDLE",
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
                    kind: "toggle",
                    key: "map.islandTasks",
                    name: "TASKS MODULE",
                    help: "Adds the task checklist to the island's swipe cycle, between the map and the weather. The tasks themselves are managed in WORKFLOW.",
                    sub: "A CHECKLIST BETWEEN MAP AND WEATHER"
                },
                {
                    kind: "toggle",
                    key: "map.hoverEdge",
                    name: "OPEN ON HOVER",
                    help: "Touching the top edge of the screen raises the pill. Off: the island only opens from the keyboard shortcut or the bar.",
                    sub: "TOUCH THE TOP EDGE AND THE PILL RISES"
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
                    help: "The island's colour. INK BLACK is the classic solid black. GLASS is a dark frost over the blurred desktop. WALLPAPER wears the picture's own colours. FRAME takes the screen frame's colour (and the bar's, when they are connected): docked, the island, frame and bar are one surface. TONE is the accent's deep shade.",
                    sub: "INK BLACK · GLASS · WALLPAPER · FRAME · TONE",
                    options: [
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
                    help: "One click for the integrated look: the screen frame on and connected to the bar, the island docked and wearing the frame's colour.",
                    sub: "FRAME ON · DOCKED · THEME FRAME"
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
                    key: "bar.frameConnect",
                    name: "BAR JOINS THE FRAME",
                    help: "Bar and frame become one surface (no seam). With the island docked and themed FRAME, all three are one.",
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
            help: "Velly, die Assistentin in der Insel. Lang auf die Pille drücken weckt sie; hier stellst du ein, womit sie denkt, wie sie spricht, ob sie zuhört und was sie sich merkt.",
            sub: "DER ASSISTENT IN DER INSEL · LANGES DRÜCKEN WECKT SIE",
            icon: "auto_awesome",
            items: [
                {
                    kind: "toggle",
                    key: "velly.enabled",
                    name: "VELLY",
                    help: "Schaltet Velly als Modul der Insel an oder aus. Aus: Das lange Drücken auf die Pille macht nichts, und nichts von ihr läuft im Hintergrund.",
                    sub: "IHR MODUL IM SWIPE-ZYKLUS · OHNE SIE TUT DAS LANGE DRÜCKEN NICHTS"
                },
                {
                    kind: "action",
                    fn: "vellySetup",
                    name: "SETUP",
                    help: "Öffnet Vellys Einrichtung: lokales Gehirn herunterladen oder auswählen, Stimme wählen, und nur für Cloud-Anbieter einen API-Schlüssel hinterlegen. Der Schlüssel liegt in ~/.config/velvet/ai.json (nur für dich lesbar, 0600).",
                    sub: "LOKALES GEHIRN LADEN, STIMME WÄHLEN · EIN SCHLÜSSEL NUR FÜR WOLKEN (AI.JSON, 0600)"
                },
                {
                    kind: "choice",
                    key: "velly.provider",
                    name: "GEHIRN",
                    help: "Womit Velly denkt. AUTO nimmt zuerst das lokale Gehirn (kostenlos, nichts verlässt den Rechner), dann ein lokales Ollama, dann einen gespeicherten Cloud-Schlüssel. Die anderen Einträge erzwingen genau diesen Anbieter.",
                    sub: "AUTO NIMMT ERST DAS LOKALE GEHIRN, DANN OLLAMA, DANN EINEN SCHLÜSSEL",
                    options: [
                        { value: "auto", label: "AUTO" },
                        { value: "local", label: "LOKAL · GRATIS" },
                        { value: "openai", label: "OPENAI" },
                        { value: "deepseek", label: "DEEPSEEK" },
                        { value: "anthropic", label: "ANTHROPIC" },
                        { value: "ollama", label: "OLLAMA (LOKAL)" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "velly.forceTier",
                    name: "TROTZDEM-MODUS",
                    help: "Lässt die gewählte Modellgröße auch laufen, wenn sie weit davon entfernt ist, in den freien Grafikspeicher zu passen (etwa während ein Spiel die Karte belegt). Dann liegt ein großer Teil im Arbeitsspeicher und sie antwortet langsam. Fehlt nur ein wenig, läuft deine Größe immer — dann wandern nur ein paar Experten-Schichten in den RAM. Aus: Es läuft die größte Größe, die gerade passt.",
                    sub: "DEINE GRÖSSE AUCH OHNE PLATZ · KNAPP PASST SIE OHNEHIN"
                },
                {
                    kind: "choice",
                    key: "velly.keepWarm",
                    name: "WACH BLEIBEN",
                    help: "Wie lange das Gehirn nach einer Sitzung geladen bleibt. Weckst du Velly in dieser Zeit wieder, antwortet sie sofort, statt das Modell (beim großen 12 GB) neu zu laden. SOFORT gibt die Grafikkarte direkt nach der Sitzung frei. Startet ein Vollbild-Spiel, wird sie in jedem Fall sofort freigegeben.",
                    sub: "NACH DER SITZUNG GELADEN BLEIBEN · EIN SPIEL BEKOMMT DIE KARTE SOFORT",
                    options: [
                        { value: 0, label: "SOFORT ENTLADEN" },
                        { value: 2, label: "2 MINUTEN" },
                        { value: 5, label: "5 MINUTEN" },
                        { value: 15, label: "15 MINUTEN" },
                        { value: 60, label: "1 STUNDE" }
                    ]
                },
                {
                    kind: "choice",
                    key: "velly.model",
                    name: "MODELL",
                    help: "Welches Modell beim gewählten Anbieter benutzt wird. Leer lässt den Anbieter entscheiden; das lokale Gehirn wählst du in SETUP.",
                    sub: "LEER LÄSST DEN ANBIETER ENTSCHEIDEN · SETUP KANN FREIE NAMEN SETZEN",
                    options: [
                        { value: "", label: "ANBIETER-STANDARD" },
                        { value: "gpt-4o-mini", label: "GPT-4O-MINI" },
                        { value: "gpt-4.1-mini", label: "GPT-4.1-MINI" },
                        { value: "deepseek-chat", label: "DEEPSEEK-CHAT" },
                        { value: "claude-haiku-4-5-20251001", label: "CLAUDE HAIKU 4.5 · SCHNELL" },
                        { value: "claude-sonnet-5", label: "CLAUDE SONNET 5" },
                        { value: "llama3.2", label: "LLAMA 3.2 (LOKAL)" }
                    ]
                },
                {
                    kind: "info",
                    live: "vellyFacts",
                    name: "GEDÄCHTNIS",
                    help: "Zeigt, was Velly sich über Sitzungen hinweg gemerkt hat (Fakten über dich, Vorlieben). Löschen kannst du es weiter unten.",
                    sub: "WAS SIE ÜBER SESSIONS HINWEG BEHÄLT"
                },
                {
                    kind: "slider",
                    key: "velly.longPress",
                    name: "HALTEDAUER",
                    help: "So lange musst du die Pille gedrückt halten, bis Velly aufwacht, in Millisekunden. Kürzer weckt schneller, aber auch versehentlich.",
                    sub: "SO LANGE HÄLTST DU DIE PILLE, BEVOR SIE AUFWACHT",
                    min: 250, max: 1500, step: 10, fmt: "int", unit: "ms"
                },
                {
                    kind: "toggle",
                    key: "velly.voice",
                    name: "STIMME",
                    help: "Velly liest ihre Antworten laut vor. Aus: Sie antwortet nur als Text in der Insel.",
                    sub: "SIE SPRICHT IHRE ANTWORTEN · OHNE ENGINE REDEN DIE BLIPS BIS EINE ECHTE STIMME DA IST"
                },
                {
                    kind: "choice",
                    key: "velly.voiceEngine",
                    name: "STIMM-ENGINE",
                    help: "Womit sie spricht. NATÜRLICH ist die menschliche Orpheus-Stimme (braucht die Grafikkarte, ~3 GB, spricht nicht während eines Vollbild-Spiels); PIPER ist schnell und läuft auf der CPU; ESPEAK-NG ist robotisch, aber immer da; CLOUD braucht einen Schlüssel; ANIMALESE sind nur Pieptöne; STILL schweigt. AUTO nimmt die beste, die gerade geht.",
                    sub: "NATÜRLICH: ECHTE MENSCHLICHE STIMMEN (KARTOFFEL-ORPHEUS, GRAFIKKARTE) · AUTO NIMMT DIE BESTE, DIE GERADE GEHT",
                    options: [
                        { value: "auto", label: "AUTO" },
                        { value: "natural", label: "NATÜRLICH" },
                        { value: "piper", label: "PIPER" },
                        { value: "espeak", label: "ESPEAK-NG" },
                        { value: "cloud", label: "CLOUD" },
                        { value: "animalese", label: "ANIMALESE (BLIPS)" },
                        { value: "none", label: "STILL" }
                    ]
                },
                {
                    kind: "choice",
                    key: "velly.naturalVoice",
                    name: "NATÜRLICHE STIMME",
                    help: "Welche Sprecherin oder welcher Sprecher die natürliche Stimme ist. Gilt nur, wenn die Stimm-Engine NATÜRLICH ist (oder AUTO sie wählt).",
                    sub: "WER VELLY SPRICHT — ECHTE SPRECHERINNEN UND SPRECHER",
                    options: [
                        { value: "Sophie", label: "SOPHIE" },
                        { value: "Marie", label: "MARIE" },
                        { value: "Mia", label: "MIA" },
                        { value: "Maria", label: "MARIA" },
                        { value: "Sophia", label: "SOPHIA" },
                        { value: "Lina", label: "LINA" },
                        { value: "Lea", label: "LEA" },
                        { value: "Julian", label: "JULIAN" },
                        { value: "Jakob", label: "JAKOB" },
                        { value: "Felix", label: "FELIX" },
                        { value: "Jonas", label: "JONAS" },
                        { value: "Noah", label: "NOAH" }
                    ]
                },
                {
                    kind: "toggle",
                    key: "velly.fillers",
                    name: "LAUT DENKEN",
                    help: "Wenn sie länger nachdenkt, sagt sie nach gut einer Sekunde ein kurzes „Hm, Moment …“ — damit du weißt, dass sie dich gehört hat.",
                    sub: "EIN KURZES „HM, MOMENT …“, WENN SIE LÄNGER ÜBERLEGT — WIE EIN MENSCH"
                },
                {
                    kind: "toggle",
                    key: "velly.wakeWord",
                    name: "HEY VELLY",
                    help: "Weckt Velly ohne Drücken, wenn du „Hey Velly, …“ sagst. Dafür hört das Mikrofon dauerhaft mit; erkannt wird nur hier auf dem Rechner, nichts wird hochgeladen.",
                    sub: "OHNE DRÜCKEN WECKEN: „HEY VELLY, …“ · DAS MIKRO HÖRT DANN IMMER MIT, ERKANNT WIRD NUR HIER AUF DEM RECHNER"
                },
                {
                    kind: "choice",
                    key: "velly.voiceName",
                    name: "STIMME",
                    help: "Welche Piper-Stimme sie benutzt (deutsch). Eine Stimme, die noch fehlt, wird beim ersten Satz automatisch heruntergeladen.",
                    sub: "PIPERS DEUTSCHE STIMMEN · EINE, DIE NOCH FEHLT, LÄDT SICH BEIM ERSTEN SATZ SELBST",
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
                    name: "STIMM-TEMPO",
                    help: "Sprechtempo. 100% ist das eigene Tempo der Stimme; höher spricht schneller, niedriger langsamer.",
                    sub: "100% IST DAS EIGENE TEMPO DER STIMME · DARÜBER SPRICHT SIE SCHNELLER",
                    min: 0.6, max: 1.5, step: 0.05, fmt: "percent"
                },
                {
                    kind: "slider",
                    key: "velly.voiceVolume",
                    name: "STIMM-LAUTSTÄRKE",
                    help: "Lautstärke nur für Vellys Stimme, unabhängig von der Systemlautstärke. Die Klänge der Shell haben einen eigenen Regler (SHELL → SOUND).",
                    sub: "NUR IHRE STIMME — DIE SCHALE-KLÄNGE HABEN EIGENEN REGLER",
                    min: 0, max: 1.2, step: 0.05, fmt: "percent"
                },
                {
                    kind: "toggle",
                    key: "velly.ears",
                    name: "OHREN",
                    help: "Velly hört zu, solange eine Sitzung offen ist. Das Mikrofon läuft nur dann — schläft sie, ist der Prozess beendet (außer HEY VELLY ist an).",
                    sub: "MIKROFON NUR WÄHREND EINER SESSION · SCHLAFEND LÄUFT NICHTS"
                },
                {
                    kind: "toggle",
                    key: "velly.autoListen",
                    name: "SOFORT ZUHÖREN",
                    help: "Das Mikrofon öffnet sich sofort, wenn sie aufwacht, du kannst direkt losreden. Aus: Du startest das Zuhören selbst.",
                    sub: "DAS MIKROFON GEHT MIT DEM AUFWECKEN AN"
                },
                {
                    kind: "toggle",
                    key: "velly.duckMedia",
                    name: "MUSIK LEISER",
                    help: "Solange Velly wach ist, wird laufende Musik leiser gedreht (oder pausiert, wenn der Player keine eigene Lautstärke hat) und danach wiederhergestellt. So hört das Mikrofon dich statt des Songs — vorher wurden Liedzeilen als Fragen erkannt — und du verstehst ihre Antwort.",
                    sub: "WÄHREND SIE WACH IST · DANACH WIE VORHER"
                },
                {
                    kind: "slider",
                    key: "velly.earsSensitivity",
                    name: "EMPFINDLICHKEIT",
                    help: "Wie laut du sein musst, damit sie reagiert. Höher, wenn sie dich in einer lauten Umgebung nicht hört; niedriger, wenn sie auf Hintergrundgeräusche anspringt.",
                    sub: "WIE LAUT DU SEIN MUSST · HOCH IN LAUTER UMGEBUNG",
                    min: 0.4, max: 3, step: 0.1, fmt: "float1", unit: "×"
                },
                {
                    kind: "toggle",
                    key: "velly.learn",
                    name: "LERNEN",
                    help: "Am Ende jeder Sitzung fasst sie zusammen, was sie über dich gelernt hat, und merkt es sich für das nächste Mal.",
                    sub: "JEDE SESSION WIRD AM ENDE ZU ERINNERUNGEN VERDICHTET"
                },
                {
                    kind: "toggle",
                    key: "velly.greet",
                    name: "BEGRÜSSUNG",
                    help: "Ein kurzes, gesprochenes Hallo, wenn sie aufwacht (mit deinem Namen, wenn sie ihn kennt).",
                    sub: "EIN KURZES WORT, WENN SIE AUFWACHT"
                },
                {
                    kind: "toggle",
                    key: "velly.confirmDanger",
                    name: "NACHFRAGEN",
                    help: "Vor Sperren, Abmelden, Neustart, Herunterfahren und dem Neustart der Shell fragt sie einmal nach, bevor sie es tut.",
                    sub: "SPERREN, ABMELDEN, NEUSTART · SIE FRAGT EINMAL, BEVOR SIE ES TUT"
                },
                {
                    kind: "slider",
                    key: "velly.temperature",
                    name: "TEMPERATUR",
                    help: "Wie frei sie formuliert. Niedrig ist sachlich und vorhersehbar, hoch ist lockerer und abwechslungsreicher (und irrt sich eher).",
                    sub: "WIE FREI SIE FORMULIERT",
                    min: 0, max: 1.2, step: 0.1, fmt: "float1"
                },
                {
                    kind: "slider",
                    key: "velly.maxTokens",
                    name: "ANTWORTLÄNGE",
                    help: "Höchstlänge einer Antwort in Tokens (etwa Wortteile). Sie antwortet meist kürzer; der Deckel verhindert Romane.",
                    sub: "DECKEL FÜR EINE ANTWORT · DIE KAPSEL IST 462 PX BREIT",
                    min: 64, max: 1024, step: 16, fmt: "int", unit: " tok"
                },
                {
                    kind: "action",
                    fn: "vellyWake",
                    name: "JETZT WECKEN",
                    help: "Öffnet die Insel und eine Sitzung mit Velly, genau wie das lange Drücken.",
                    sub: "ÖFFNET DIE INSEL UND DIE SESSION — WIE DAS LANGE DRÜCKEN"
                },
                {
                    kind: "action",
                    fn: "vellyTest",
                    name: "VERBINDUNG TESTEN",
                    help: "Schickt eine echte Anfrage an den eingestellten Anbieter und zeigt, ob eine Antwort zurückkommt — prüft Schlüssel, Netz und Modell.",
                    sub: "EIN ECHTER ROUND TRIP ZUM ANBIETER, KEIN GEFÜHL"
                },
                {
                    kind: "action",
                    fn: "vellyForgetFacts",
                    name: "GEDÄCHTNIS LÖSCHEN",
                    help: "Löscht alles, was Velly sich über dich gemerkt hat. Kann nicht rückgängig gemacht werden.",
                    sub: "ALLES VERGESSEN, WAS SIE SICH GEMERKT HAT",
                    danger: true
                },
                {
                    kind: "action",
                    fn: "vellyPrune",
                    name: "SPEICHER FREIGEBEN",
                    help: "Löscht die Modellgrößen, die du nicht benutzt. Es bleiben die gewählte Größe und KLEIN, auf die Velly ausweicht, solange ein Spiel die Grafikkarte belegt. Eine gelöschte Größe wird neu geladen, wenn du sie wieder wählst.",
                    sub: "UNBENUTZTE MODELLE VON DER PLATTE LÖSCHEN",
                    danger: true
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
            help: "A live picture of all your workspaces that drops from the top edge: click a desktop to go there, drag a window to move it, scroll to zoom out.",
            sub: "THE MAP THAT DROPS FROM THE TOP EDGE",
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
                    help: "Shows a live photograph of each workspace. Off shows cards with app icons instead, which costs nothing.",
                    sub: "THE MAP PHOTOGRAPHS THE SCREEN  ·  OFF SHOWS ICON CARDS"
                },
                {
                    kind: "toggle",
                    key: "map.showTitles",
                    name: "NAME ON HOVER",
                    help: "Shows the window's title when you point at it in the map.",
                    sub: "TITLE STRIPS OVER THE PREVIEWS"
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
                    help: "Clicking a desktop in the map switches to it.",
                    sub: "A CLICK ON A DESKTOP BRINGS IT UP"
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
            help: "How this settings window itself is built — not just dressed. PERSONA is the house: big cards, the category rail on the left. CONSOLE is a terminal, ARCADE a game's level select, HUD a sci-fi panel, LEDGER a newspaper, GLASS floating panes, TOME a book, POSTER stacked blocks, CLEAN a quiet single column, WINDOWS a window of the version you pick below. Each comes with the matching vibe on the LOOKS tab.",
            sub: "PERSONA · CONSOLE · ARCADE · HUD · LEDGER · GLASS · TOME · POSTER · CLEAN · WINDOWS",
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
                { value: "win", label: "WINDOWS · YOUR VERSION" }
            ]
        },
        {
            kind: "choice",
            key: "appearance.winVersion",
            name: "WINDOWS VERSION",
            help: "Which Windows the WINDOWS look wears. 95 is grey bevelled boxes and a navy title bar; XP a blue title bar, round buttons and a green Start; 7 is Aero glass with a glossy orb; 10 is flat and sharp; 11 is rounded mica cards. Picking one while the WINDOWS look is on turns the whole shell — settings, taskbar, windows, sounds — into that edition. Otherwise it is remembered for the next time you put the WINDOWS look on.",
            sub: "95 · XP · 7 · 10 · 11 — THE WHOLE SHELL FOLLOWS",
            options: [
                { value: "95", label: "WINDOWS 95 · GREY AND BEVELLED" },
                { value: "xp", label: "WINDOWS XP · LUNA BLUE" },
                { value: "7", label: "WINDOWS 7 · AERO GLASS" },
                { value: "10", label: "WINDOWS 10 · FLAT AND SHARP" },
                { value: "11", label: "WINDOWS 11 · MICA AND ROUNDED" }
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
            help: "The voice of all text. PERSONA is heavy italic; SOFT is round and upright; MONO is a terminal; SERIF is a printed page; BLOCK is a poster; ARCADE is a pixel game; TECH is a wide, light HUD; CLEAN is a calm neutral sans; WINDOWS is the face of the Windows version you chose.",
            sub: "PERSONA · SOFT · MONO · SERIF · BLOCK · ARCADE · TECH · CLEAN · WINDOWS",
            options: [
                { value: "persona", label: "PERSONA" },
                { value: "soft", label: "SOFT" },
                { value: "mono", label: "MONO" },
                { value: "serif", label: "SERIF" },
                { value: "block", label: "BLOCK" },
                { value: "arcade", label: "ARCADE" },
                { value: "tech", label: "TECH" },
                { value: "clean", label: "CLEAN" },
                { value: "win", label: "WINDOWS" }
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
                { value: "windows", label: "WINDOWS" }
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
            kind: "choice", key: "launcher.side", name: "SIDE", help: "Whether the launcher opens in the middle or towards the left or right of the screen. The Windows start menu keeps its corner and the terminal line its full width.", sub: "LEFT, MIDDLE OR RIGHT",
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
        const glass = { key: "appearance.vibe", is: "glass" };
        const soft = { key: "appearance.vibe", in: ["neu", "clay"] };
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
            { kind: "info", name: "SHELL PARTS", sub: "THE LAUNCHER, THE NOTIFICATIONS, THE VOLUME POP-UP, THE POWER MENU", help: "Every look builds these parts its own way. Pick another look's way for any of them — a terminal launcher on the glass look, Windows toasts on the arcade — and this look remembers it." },
            {
                kind: "choice",
                key: "appearance.launcherStyle",
                name: "LAUNCHER",
                help: "How the launcher (Super+Space) is built: the look's own, or any look's — Velvet's orbit, a terminal prompt, a game menu, a HUD, a newspaper index, a glass spotlight, a grimoire, a poster, a quiet list or a Windows start menu.",
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
                    { value: "start", label: "WINDOWS" }
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
                    { value: "start", label: "WINDOWS" }
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
                    { value: "start", label: "WINDOWS" }
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
                    { value: "start", label: "WINDOWS" }
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
                when: v("clay")
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
            help: "Bar and frame become one surface: the frame also paints the bar's strip (the bar then draws no plate and no Velvet trim), so there is no seam and the desktop rounds off exactly where the bar ends. Only while the bar is pinned and not FLOATING.",
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
                    help: "Keeps the bar on screen and reserves its space so windows never cover it. Off lets it hide (together with REVEAL ON HOVER).",
                    sub: "PIN THE BAR AND RESERVE ITS SPACE"
                },
                {
                    kind: "toggle",
                    key: "bar.showOnHover",
                    name: "REVEAL ON HOVER",
                    help: "When the bar is not pinned, touching its screen edge slides it out. With both this and ALWAYS VISIBLE off the bar still stays — otherwise there would be no way to reach it.",
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
            help: "The lock's face. FLUID is the welcoming card with side columns of modules; SOFT is no card — a big clock and a few round pills; VELVET is the original hard-edged lock; VIBE draws the lock that belongs to the look you wear — a terminal login, a game's title screen, a newspaper front page, frosted glass, a book, a poster, a quiet clock, or the logon screen of the Windows edition you picked. Each of the first three has its own page below (the one you wear says IN USE); CLOCK, BACKGROUND & MUSIC and PASSWORD & HINTS apply to FLUID and SOFT. PAM and all safety rules are the same for all of them.",
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
                    kind: "toggle",
                    key: "lock.tileCards",
                    name: "TILE CARDS",
                    help: "Draws cards around the modules in the side columns. Off shows the modules bare.",
                    sub: "CARDS AROUND THE TILE MODULES · OFF IS BARE"
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
                    help: "Finer switches for the modules in the FLUID lock's side columns: the media cover, the weather forecast, the notifications, your face and the disk cell.",
                    sub: "THE FINER SWITCHES OF THE SIDE MODULES",
                    icon: "tune",
                    items: [
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
            help: "The lock of the look you wear — the terminal, the game, the HUD, the newspaper, the glass, the book, the poster, the quiet clock, the Windows logon — and everything you can change about it: the clock, how the date is written, how typing looks, what is shown, how the wallpaper sits behind and how the lock arrives.",
            sub: "REMEMBERED PER LOOK · CLOCK · TYPING · EFFECTS · MUSIC · ENTRANCE",
            icon: "palette",
            style: "vibe",
            items: [
                {
                    kind: "info",
                    name: "THE LOCK OF YOUR LOOK",
                    help: "Every look has its own lock screen — a terminal login, a game's PRESS START, a HUD, a newspaper, frosted glass, a book, a poster, a quiet clock, the logon screen of a Windows edition. Every switch here belongs to the look you wear: each look remembers its own lock — its clock, typing, effect, music and entrance — and RESET THIS LOOK (VISUALS → THIS LOOK) brings back its design. The picture beside the list updates as you change them.",
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
