//  VELVET  ·  modules/launcher/LookLauncher.qml
//  The launcher of the LOOKS. Velvet keeps its orbit (Launcher.qml); every
//  look gets a launcher of its own kind, built from one skeleton (a field, a
//  list, a hint line) and dressed by its style:
//    prompt     TERMINAL      a dmenu line across the top, lowercase, `run ▸`
//    arcade     ARCADE        a game's SELECT menu, ▶ cursor, pixel type
//    hud        CYBER         a bracketed console, numbered rows, QUERY //
//    index      PAPER         a newspaper index page, dotted leaders
//    spotlight  GLASS         a frosted search pill and a frosted list
//    grimoire   RPG           a spell book, roman numerals, gold rules
//    poster     BRUTAL        the query in huge black type, bold bars
//    raycast    CLEAN · MINIMAL · FLAT · NEUMORPH · CLAY, each its own way
//    start      WINDOWS       the start menu of the edition (95 · XP · 7 · 10 · 11)
//  Same apps, maths (=) and commands (>) as the orbit; same keys: ↑ ↓ / Tab,
//  Ctrl+J/K, Enter, Alt+P pins, Esc clears first and closes second.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property bool rendered: false
    property bool entered: false
    property int index: 0

    readonly property string skin: Appearance.skin
    readonly property string fl: Appearance.flavour
    readonly property string wv: Appearance.winVer
    // the look's kind of launcher, or the one picked under THIS LOOK → SHELL PARTS
    readonly property string style: Appearance.launcherStyle === "velvet" ? "spotlight" : Appearance.launcherStyle

    readonly property var results: {
        Apps.usage;
        return Apps.search(input.text);
    }
    readonly property var selected: root.results.length > 0 ? root.results[Math.max(0, Math.min(root.results.length - 1, root.index))] : null
    onResultsChanged: root.index = 0

    // ── the style's numbers
    readonly property real sw: root.width
    readonly property real sh: root.height
    readonly property bool winOld: root.wv === "95" || root.wv === "xp" || root.wv === "7"
    readonly property real panelW: ({
            prompt: root.sw,
            arcade: 660,
            hud: 760,
            index: 780,
            spotlight: 760,
            grimoire: 720,
            poster: Math.min(root.sw - 120, 1400),
            raycast: root.fl === "minimal" ? 700 : 720,
            start: root.winOld ? 440 : 640
        })[root.style] ?? 720
    readonly property int rows: root.style === "prompt" ? 9 : (root.style === "poster" ? 6 : (root.style === "start" ? 9 : 8))
    readonly property real rowH: ({
            prompt: 28,
            arcade: 46,
            hud: 40,
            index: 42,
            spotlight: 52,
            grimoire: 46,
            poster: 64,
            raycast: root.fl === "clay" ? 54 : 48,
            start: root.winOld ? 38 : 46
        })[root.style] ?? 48
    readonly property real headH: ({
            prompt: 0,
            arcade: 76,
            hud: 58,
            index: 112,
            spotlight: 0,
            grimoire: 84,
            poster: 0,
            raycast: 0,
            start: root.wv === "xp" ? 64 : (root.wv === "95" ? 0 : 0)
        })[root.style] ?? 0
    readonly property real fieldH: ({
            prompt: 34,
            arcade: 50,
            hud: 46,
            index: 52,
            spotlight: 64,
            grimoire: 50,
            poster: Math.min(170, root.sh * 0.16),
            raycast: 60,
            start: 44
        })[root.style] ?? 56
    readonly property real footH: root.style === "prompt" || root.style === "poster" ? 0 : 34
    readonly property real listH: Math.min(root.rows, Math.max(1, root.results.length)) * root.rowH
    readonly property real panelH: root.headH + root.fieldH + 10 + root.listH + root.footH + (root.style === "prompt" ? 0 : 18)
    readonly property real panelX: root.style === "start" ? (root.wv === "11" ? (root.sw - root.panelW) / 2 : 8) : (root.sw - root.panelW) / 2
    readonly property real panelY: {
        switch (root.style) {
        case "prompt":
            return 0;
        case "spotlight":
        case "raycast":
            return root.sh * 0.18;
        case "poster":
            return root.sh * 0.1;
        case "start":
            return root.sh - root.panelH - (root.winOld ? 44 : 64);
        default:
            return (root.sh - root.panelH) / 2;
        }
    }

    // colours and type of the style
    readonly property color ink: Colours.ink
    readonly property color dim: Colours.inkDim
    readonly property color acc: Colours.accent
    readonly property string face: ({
            prompt: Appearance.fontFamily.mono,
            arcade: Appearance.fontFamily.pixel,
            hud: Appearance.fontFamily.tech,
            index: Appearance.fontFamily.serif,
            grimoire: Appearance.fontFamily.serif,
            poster: Appearance.fontFamily.block,
            start: Appearance.fontFamily.win
        })[root.style] ?? Appearance.fontFamily.body
    readonly property bool upper: root.style === "arcade" || root.style === "hud" || root.style === "poster"
    readonly property bool lower: root.style === "prompt"

    function cased(t: string): string {
        if (root.upper)
            return String(t).toUpperCase();
        if (root.lower)
            return String(t).toLowerCase();
        return t;
    }
    function roman(n: int): string {
        const map = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]];
        let out = "";
        for (const [v, s] of map)
            while (n >= v) {
                out += s;
                n -= v;
            }
        return out;
    }
    function kindWord(it: var): string {
        if (!it)
            return "";
        const w = ({
                app: "app",
                calc: "sum",
                exec: "command",
                setting: "setting"
            })[it.kind] ?? it.kind;
        if (root.style === "grimoire")
            return ({
                    app: "summon",
                    calc: "divine",
                    exec: "incant",
                    setting: "ward"
                })[it.kind] ?? w;
        if (root.style === "arcade")
            return ({
                    app: "play",
                    calc: "score",
                    exec: "cheat",
                    setting: "options"
                })[it.kind] ?? w;
        return w;
    }

    // ── open, close, run
    function present(): void {
        if (Panels.launcher) {
            root.rendered = true;
            enterTimer.restart();
            Sfx.open();
        } else {
            if (root.entered)
                Sfx.close();
            root.entered = false;
            exitTimer.restart();
        }
    }
    function moveCursor(d: int): void {
        const n = root.results.length;
        if (n === 0)
            return;
        root.index = (root.index + d + n) % n;
        list.positionViewAtIndex(root.index, ListView.Contain);
        Sfx.cursor();
    }
    function run(it: var): void {
        if (!it)
            return;
        if (it.kind === "app")
            Sfx.launch();
        else
            Sfx.select();
        Apps.launch(it);
        if (it.kind !== "setting")
            Panels.closeAll();
    }

    Connections {
        target: Panels

        function onLauncherChanged(): void {
            root.present();
        }
    }
    Timer {
        running: true
        interval: 1
        onTriggered: if (Panels.launcher)
            root.present()
    }
    Timer {
        id: enterTimer

        interval: 1
        onTriggered: {
            root.entered = true;
            input.text = "";
            root.index = 0;
            input.forceActiveFocus();
        }
    }
    Timer {
        id: exitTimer

        interval: 200
        onTriggered: root.rendered = false
    }

    screen: Hypr.focusedScreen
    visible: root.rendered
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-launcher"
    WlrLayershell.keyboardFocus: root.entered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // ── the scrim
    Rectangle {
        anchors.fill: parent
        color: ({
                prompt: Qt.rgba(0, 0, 0, 0.35),
                poster: Colours.alpha(Colours.paper, 0.94),
                start: Qt.rgba(0, 0, 0, 0.12),
                spotlight: Qt.rgba(0, 0, 0, 0.28)
            })[root.style] ?? Colours.alpha(Colours.paper, root.style === "raycast" && root.fl === "minimal" ? 0.9 : 0.6)
        opacity: root.entered ? 1 : 0

        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: Panels.closeAll()
        }
    }

    // ── the panel
    Item {
        id: panel

        x: root.panelX
        y: root.panelY + (root.entered ? 0 : (root.style === "start" ? 40 : (root.style === "prompt" ? -root.panelH : (root.style === "arcade" ? -30 : 16))))
        width: root.panelW
        height: root.panelH
        opacity: root.entered ? 1 : 0
        scale: root.entered ? 1 : (root.style === "spotlight" || root.style === "raycast" ? 0.97 : 1)

        Behavior on y {
            NumberAnimation { duration: root.style === "arcade" ? 340 : 200; easing.type: root.style === "arcade" ? Easing.OutBack : Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
        }

        // ── the ground of each style
        // soft shadow under the floating kinds
        Rectangle {
            visible: ["spotlight", "raycast", "start", "arcade"].indexOf(root.style) >= 0 && !(root.style === "raycast" && root.fl === "minimal")
            x: root.style === "arcade" ? 8 : 0
            y: root.style === "arcade" ? 8 : 10
            width: parent.width
            height: parent.height
            radius: body.radius
            color: root.style === "arcade" ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, root.style === "raycast" && root.fl === "clay" ? 0 : 0.22)
        }
        // clay: a fat tinted shadow; neumorph: light + dark
        Rectangle {
            visible: root.style === "raycast" && root.fl === "clay"
            x: 6
            y: 14
            width: parent.width - 12
            height: parent.height
            radius: body.radius
            color: Colours.alpha(Config.appearance.clayTint === "accent" ? Colours.accent : Colours.clay, 0.45)
        }
        Rectangle {
            visible: root.style === "raycast" && root.fl === "neu"
            x: -10
            y: -10
            width: parent.width
            height: parent.height
            radius: body.radius
            color: Colours.light ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.06)
        }
        Rectangle {
            visible: root.style === "raycast" && root.fl === "neu"
            x: 10
            y: 10
            width: parent.width
            height: parent.height
            radius: body.radius
            color: Colours.light ? Qt.rgba(0.4, 0.45, 0.55, 0.32) : Qt.rgba(0, 0, 0, 0.5)
        }

        // glass: the smoke under the frost keeps the type readable over
        // whatever lies behind (VISUALS → THIS LOOK → GLASS)
        Rectangle {
            visible: root.style === "spotlight"
            anchors.fill: parent
            radius: body.radius
            color: Qt.rgba(0.07, 0.08, 0.13, Math.min(0.92, 0.5 + Config.appearance.glassSmoke))
        }
        Rectangle {
            id: body

            anchors.fill: parent
            radius: ({
                    prompt: 0,
                    arcade: 0,
                    hud: 0,
                    index: 0,
                    spotlight: 26,
                    grimoire: 6,
                    poster: 0,
                    raycast: ({ clean: 16, minimal: 0, flat: 4, neu: 30, clay: 34 })[root.fl] ?? 16,
                    start: root.wv === "11" ? 10 : (root.wv === "10" ? 0 : (root.wv === "7" ? 8 : (root.wv === "xp" ? 8 : 0)))
                })[root.style] ?? 12
            color: {
                switch (root.style) {
                case "prompt":
                    return Colours.alpha(Colours.paper, 0.97);
                case "arcade":
                    return Colours.paper;
                case "hud":
                    return Colours.alpha(Colours.paper, 0.9);
                case "index":
                    return Colours.surface;
                case "spotlight":
                    return Qt.rgba(1, 1, 1, 0.1 + 0.08 * Config.appearance.glassFrost);
                case "grimoire":
                    return Colours.surface;
                case "poster":
                    return "transparent";
                case "start":
                    return root.wv === "95" ? "#c0c0c0" : (root.wv === "xp" ? "#ffffff" : (root.wv === "7" ? Qt.rgba(0.12, 0.2, 0.32, 0.88) : (root.wv === "10" ? "#1f1f1f" : Qt.rgba(0.95, 0.96, 0.98, 0.96))));
                default:
                    if (root.fl === "minimal")
                        return "transparent";
                    if (root.fl === "neu")
                        return Colours.paper;
                    if (root.fl === "clay")
                        return Colours.mix(Colours.surface, Config.appearance.clayTint === "accent" ? Colours.accent : Colours.clay, 0.14);
                    return Colours.surface;
                }
            }
            border.width: ({
                    arcade: 3,
                    hud: 1,
                    index: 1,
                    spotlight: 1,
                    grimoire: 2,
                    start: root.wv === "95" ? 2 : 1,
                    raycast: root.fl === "clean" ? 1 : (root.fl === "flat" ? 0 : 0)
                })[root.style] ?? 0
            border.color: ({
                    arcade: Colours.accent,
                    hud: Colours.alpha(Colours.accent, 0.5),
                    index: Colours.ink,
                    spotlight: Qt.rgba(1, 1, 1, Math.min(1, Config.appearance.glassRim)),
                    grimoire: Colours.accent,
                    start: root.wv === "95" ? "#ffffff" : (root.wv === "xp" ? "#0a246a" : Qt.rgba(1, 1, 1, 0.25)),
                    raycast: Colours.alpha(Colours.ink, 0.12)
                })[root.style] ?? "transparent"
        }

        // ── decorations
        // HUD: corner brackets
        Repeater {
            model: root.style === "hud" ? 4 : 0

            Item {
                required property int index

                x: index % 2 === 0 ? -6 : panel.width - 22
                y: index < 2 ? -6 : panel.height - 22
                width: 28
                height: 28

                Rectangle { x: parent.index % 2 === 0 ? 0 : 26; width: 2; height: 28; color: Colours.accent }
                Rectangle { y: parent.index < 2 ? 0 : 26; width: 28; height: 2; color: Colours.accent }
            }
        }
        // GRIMOIRE: an inner gold rule
        Rectangle {
            visible: root.style === "grimoire"
            anchors.fill: parent
            anchors.margins: 8
            color: "transparent"
            border.width: 1
            border.color: Colours.alpha(Colours.accent, 0.55)
        }
        // INDEX: a double rule under the masthead
        Rectangle {
            visible: root.style === "index"
            x: 28
            y: root.headH - 10
            width: parent.width - 56
            height: 3
            color: Colours.ink
        }
        // START 95: the vertical banner
        Rectangle {
            id: banner

            visible: root.style === "start" && root.wv === "95"
            x: 3
            y: 3
            width: visible ? 30 : 0
            height: parent.height - 6
            gradient: Gradient {
                GradientStop { position: 0; color: "#000080" }
                GradientStop { position: 1; color: "#1084d0" }
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                rotation: -90
                transformOrigin: Item.Center
                text: "<b>Velvet</b>95"
                textFormat: Text.StyledText
                color: "#ffffff"
                font.family: root.face
                font.pixelSize: 20
            }
        }
        // START XP / FLAT / ARCADE: the coloured head
        Rectangle {
            visible: root.headH > 0 && (root.style === "start" || root.style === "arcade")
            width: parent.width
            height: root.headH
            radius: body.radius
            gradient: Gradient {
                GradientStop { position: 0; color: root.style === "arcade" ? Colours.mix(Colours.paper, Colours.accent, 0.18) : "#2a5fd8" }
                GradientStop { position: 1; color: root.style === "arcade" ? Colours.paper : "#1945b5" }
            }
        }
        Rectangle {
            visible: root.style === "raycast" && root.fl === "flat"
            width: parent.width
            height: root.fieldH + 6
            radius: body.radius
            color: Colours.accent
        }

        // ── the head
        Column {
            visible: root.headH > 0
            x: root.style === "start" ? 16 : 28
            y: root.style === "index" ? 14 : 16
            width: parent.width - 56
            spacing: 2

            Text {
                width: parent.width
                horizontalAlignment: root.style === "index" || root.style === "grimoire" || root.style === "arcade" ? Text.AlignHCenter : Text.AlignLeft
                text: ({
                        arcade: "SELECT GAME",
                        hud: "QUERY //  LAUNCH SEQUENCE",
                        index: "The Index",
                        grimoire: "Grimoire",
                        start: SysInfo.user
                    })[root.style] ?? ""
                color: root.style === "start" ? "#ffffff" : (root.style === "arcade" ? Colours.accent : (root.style === "hud" ? Colours.accent : root.ink))
                font.family: root.style === "index" || root.style === "grimoire" ? Appearance.fontFamily.serif : root.face
                font.pixelSize: ({
                        arcade: 28,
                        hud: 15,
                        index: 44,
                        grimoire: 36,
                        start: 20
                    })[root.style] ?? 18
                font.italic: root.style === "index" || root.style === "grimoire"
                font.bold: root.style !== "hud"
                font.letterSpacing: root.style === "hud" ? 4 : (root.style === "arcade" ? 3 : 0)
            }
            Text {
                visible: root.style === "arcade" || root.style === "index" || root.style === "grimoire"
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: ({
                        arcade: "PLAYER 1  ·  CREDIT 99",
                        index: Qt.formatDateTime(new Date(), "dddd, d MMMM yyyy").toUpperCase() + "  ·  EVERY PROGRAM ON THIS MACHINE",
                        grimoire: "~ speak the name of what you would summon ~"
                    })[root.style] ?? ""
                color: root.dim
                font.family: root.style === "arcade" ? root.face : Appearance.fontFamily.serif
                font.pixelSize: root.style === "arcade" ? 12 : 12
                font.italic: root.style === "grimoire"
                font.letterSpacing: root.style === "index" ? 2 : 1
            }
        }

        // ── the field
        Item {
            id: fieldBox

            x: root.style === "prompt" ? 0 : (root.style === "start" && root.wv === "95" ? 42 : 16)
            y: root.headH + (root.style === "prompt" ? 0 : 8)
            width: parent.width - x - (root.style === "prompt" ? 0 : 16)
            height: root.fieldH

            Rectangle {
                anchors.fill: parent
                visible: root.style !== "poster" && root.style !== "prompt" && !(root.style === "raycast" && (root.fl === "flat" || root.fl === "minimal"))
                radius: ({
                        spotlight: height / 2,
                        raycast: root.fl === "clay" || root.fl === "neu" ? height / 2 : 10,
                        start: root.wv === "11" ? height / 2 : 0
                    })[root.style] ?? 0
                color: ({
                        arcade: Qt.rgba(0, 0, 0, 0.25),
                        hud: Colours.alpha(Colours.accent, 0.08),
                        index: "transparent",
                        spotlight: Qt.rgba(1, 1, 1, 0.12),
                        grimoire: Qt.rgba(0, 0, 0, 0.2),
                        start: root.wv === "95" ? "#ffffff" : (root.wv === "10" ? "#2b2b2b" : (root.wv === "7" ? Qt.rgba(1, 1, 1, 0.9) : "#ffffff"))
                    })[root.style] ?? (root.fl === "neu" ? Colours.alpha(Colours.ink, 0.04) : Colours.alpha(Colours.ink, 0.04))
                border.width: root.style === "index" ? 0 : 1
                border.color: root.style === "arcade" ? Colours.accent : (root.style === "start" ? Qt.rgba(0, 0, 0, 0.25) : Colours.alpha(root.ink, 0.12))
            }
            // the index's ruled line and the minimal underline
            Rectangle {
                visible: root.style === "index" || (root.style === "raycast" && root.fl === "minimal")
                anchors.bottom: parent.bottom
                width: parent.width
                height: root.style === "index" ? 1 : 2
                color: root.ink
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: root.style === "poster" ? 0 : 16
                anchors.rightMargin: 16
                spacing: 12

                Text {
                    id: promptGlyph

                    anchors.verticalCenter: parent.verticalCenter
                    text: ({
                            prompt: "run ▸",
                            arcade: "▶",
                            hud: ">_",
                            grimoire: "✦",
                            poster: ""
                        })[root.style] ?? ""
                    visible: text !== ""
                    color: root.acc
                    font.family: root.style === "prompt" || root.style === "hud" ? Appearance.fontFamily.mono : root.face
                    font.pixelSize: root.style === "prompt" ? 16 : 20
                    font.bold: true
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.style === "spotlight" || root.style === "raycast" || root.style === "start" || root.style === "index"
                    name: "search"
                    color: root.style === "raycast" && root.fl === "flat" ? Colours.on(Colours.accent) : (root.style === "start" && root.wv !== "10" ? "#333333" : root.dim)
                    font.pixelSize: root.style === "spotlight" ? 28 : 22
                }
                TextInput {
                    id: input

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 80
                    clip: true
                    color: root.style === "raycast" && root.fl === "flat" ? Colours.on(Colours.accent) : (root.style === "start" && root.wv !== "10" ? "#111111" : (root.style === "start" ? "#ffffff" : root.ink))
                    selectionColor: Colours.alpha(Colours.accent, 0.5)
                    font.family: root.face
                    font.pixelSize: ({
                            prompt: 16,
                            arcade: 22,
                            hud: 20,
                            index: 26,
                            spotlight: 28,
                            grimoire: 24,
                            poster: Math.min(130, root.sh * 0.12),
                            start: 16
                        })[root.style] ?? 22
                    font.bold: root.style === "poster" || root.style === "arcade"
                    font.italic: root.style === "index" || root.style === "grimoire"
                    font.capitalization: root.upper ? Font.AllUppercase : (root.lower ? Font.AllLowercase : Font.MixedCase)
                    font.letterSpacing: root.style === "poster" ? -4 : 0

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: ({
                                prompt: "type a program, = sum, > command",
                                arcade: "INSERT NAME",
                                hud: "AWAITING INPUT",
                                index: "Search the index…",
                                spotlight: "Spotlight Search",
                                grimoire: "Name the spell…",
                                poster: "TYPE.",
                                start: root.wv === "95" ? "Run…" : "Type here to search"
                            })[root.style] ?? (root.fl === "minimal" ? "Search" : "Search apps, settings and commands…")
                        color: root.style === "raycast" && root.fl === "flat" ? Qt.rgba(1, 1, 1, 0.7) : (root.style === "start" && root.wv !== "10" ? "#777777" : Colours.alpha(root.dim, 0.7))
                        font: input.font
                    }

                    Keys.onPressed: event => {
                        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                        if (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)) {
                            root.moveCursor(1);
                            event.accepted = true;
                            return;
                        }
                        if (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)) {
                            root.moveCursor(-1);
                            event.accepted = true;
                            return;
                        }
                        if (ctrl && event.key === Qt.Key_Backspace) {
                            input.text = input.text.replace(/\S+\s*$/, "");
                            event.accepted = true;
                            return;
                        }
                        switch (event.key) {
                        case Qt.Key_Escape:
                            if (input.text !== "")
                                input.text = "";
                            else
                                Panels.closeAll();
                            event.accepted = true;
                            return;
                        case Qt.Key_Down:
                        case Qt.Key_Tab:
                            root.moveCursor(1);
                            event.accepted = true;
                            return;
                        case Qt.Key_Up:
                        case Qt.Key_Backtab:
                            root.moveCursor(-1);
                            event.accepted = true;
                            return;
                        case Qt.Key_PageDown:
                            root.moveCursor(root.rows);
                            event.accepted = true;
                            return;
                        case Qt.Key_PageUp:
                            root.moveCursor(-root.rows);
                            event.accepted = true;
                            return;
                        case Qt.Key_P:
                            if (!(event.modifiers & Qt.AltModifier))
                                break;
                            if (root.selected && root.selected.kind === "app") {
                                Apps.togglePin(root.selected.id);
                                Sfx.toggle();
                            }
                            event.accepted = true;
                            return;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.run(root.selected);
                            event.accepted = true;
                            return;
                        }
                    }
                }
            }
        }

        // ── the list
        ListView {
            id: list

            x: fieldBox.x
            y: fieldBox.y + fieldBox.height + (root.style === "prompt" ? 0 : 10)
            width: fieldBox.width
            height: root.listH
            clip: true
            interactive: true
            model: root.results
            currentIndex: root.index
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: root.style === "prompt" ? 0 : 120

            // the selection, drawn per style
            highlight: Item {
                width: list.width
                height: root.rowH

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: root.style === "poster" ? 0 : 2
                    anchors.rightMargin: 2
                    visible: root.style !== "index" && root.style !== "grimoire" && !(root.style === "raycast" && root.fl === "minimal")
                    radius: ({
                            spotlight: 14,
                            raycast: ({ clean: 9, flat: 2, neu: 20, clay: 22 })[root.fl] ?? 9,
                            start: root.wv === "11" ? 6 : 0
                        })[root.style] ?? 0
                    color: ({
                            prompt: Colours.accent,
                            arcade: Colours.alpha(Colours.accent, 0.18),
                            hud: Colours.alpha(Colours.accent, 0.16),
                            spotlight: Qt.rgba(1, 1, 1, 0.18),
                            poster: Colours.ink,
                            start: root.wv === "95" ? "#000080" : (root.wv === "xp" ? "#316ac5" : (root.wv === "10" ? "#3a3a3a" : Colours.alpha(Colours.accent, 0.22)))
                        })[root.style] ?? (root.fl === "flat" ? Colours.accent : Colours.alpha(Colours.accent, root.fl === "clay" ? 0.24 : 0.12))
                    border.width: root.style === "hud" || root.style === "arcade" ? 1 : 0
                    border.color: Colours.accent
                }
                // the index and the grimoire mark the chosen line in the margin
                Text {
                    visible: root.style === "index" || root.style === "grimoire"
                    x: -2
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.style === "index" ? "☞" : "❧"
                    color: Colours.accent
                    font.pixelSize: 20
                }
                Rectangle {
                    visible: root.style === "raycast" && root.fl === "minimal"
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: parent.height * 0.6
                    color: root.ink
                }
            }
            highlightFollowsCurrentItem: true

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                readonly property bool sel: row.index === root.index
                readonly property color fg: {
                    if (row.sel) {
                        if (root.style === "prompt")
                            return Colours.on(Colours.accent);
                        if (root.style === "poster")
                            return Colours.paper;
                        if (root.style === "raycast" && root.fl === "flat")
                            return Colours.on(Colours.accent);
                        if (root.style === "start" && (root.wv === "95" || root.wv === "xp"))
                            return "#ffffff";
                    }
                    if (root.style === "start")
                        return root.wv === "10" || root.wv === "7" ? "#ffffff" : "#111111";
                    return row.sel ? root.ink : (root.style === "arcade" ? root.dim : root.ink);
                }

                width: list.width
                height: root.rowH

                HoverHandler {
                    onHoveredChanged: if (hovered && root.index !== row.index)
                        root.index = row.index
                }
                TapHandler {
                    onTapped: root.run(row.modelData)
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: root.style === "index" || root.style === "grimoire" ? 30 : (root.style === "poster" ? 18 : 14)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    width: parent.width - 28

                    // number / cursor
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: root.style === "hud" ? String(row.index + 1).padStart(2, "0") : (root.style === "arcade" ? (row.sel ? "▶" : " ") : (root.style === "grimoire" ? root.roman(row.index + 1) + "." : (root.style === "prompt" ? (row.sel ? ">" : " ") : "")))
                        width: root.style === "grimoire" ? 46 : (root.style === "hud" ? 26 : 14)
                        color: root.style === "prompt" ? row.fg : Colours.accent
                        font.family: root.style === "hud" || root.style === "prompt" ? Appearance.fontFamily.mono : root.face
                        font.pixelSize: root.style === "grimoire" ? 16 : 14
                        font.bold: true

                        SequentialAnimation on opacity {
                            running: root.style === "arcade" && row.sel
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 380 }
                            NumberAnimation { to: 1; duration: 380 }
                        }
                    }
                    // icon
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Config.launcher.showIcons && ["prompt", "poster", "index", "grimoire", "hud"].indexOf(root.style) < 0
                        width: visible ? root.rowH - 16 : 0
                        height: width

                        Image {
                            anchors.fill: parent
                            visible: row.modelData.kind === "app" && (row.modelData.icon ?? "") !== ""
                            source: visible ? Quickshell.iconPath(row.modelData.icon, "application-x-executable") : ""
                            sourceSize.width: 64
                            sourceSize.height: 64
                            smooth: true
                            asynchronous: true
                        }
                        Icon {
                            anchors.centerIn: parent
                            visible: !(row.modelData.kind === "app" && (row.modelData.icon ?? "") !== "")
                            name: row.modelData.kind === "app" ? "apps" : (row.modelData.icon || "bolt")
                            color: row.fg
                            font.pixelSize: parent.width * 0.75
                        }
                    }
                    Text {
                        id: nameT

                        anchors.verticalCenter: parent.verticalCenter
                        text: root.cased(row.modelData.name ?? "")
                        color: row.fg
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, parent.width * 0.62)
                        font.family: root.face
                        font.pixelSize: ({
                                prompt: 15,
                                arcade: 18,
                                hud: 16,
                                index: 20,
                                spotlight: 18,
                                grimoire: 20,
                                poster: 40,
                                start: 15
                            })[root.style] ?? 16
                        font.bold: root.style === "poster" || (root.style === "start" && root.wv === "xp" && row.sel)
                        font.italic: root.style === "grimoire" && row.sel
                        font.letterSpacing: root.style === "hud" ? 2 : (root.style === "poster" ? -1 : 0)
                    }
                    // the index's dotted leader
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.style === "index" || root.style === "hud"
                        width: Math.max(0, parent.width - nameT.width - kindT.width - 80)
                        clip: true
                        text: (root.style === "hud" ? " ·" : " .").repeat(80)
                        color: Colours.alpha(root.ink, 0.35)
                        font.family: root.face
                        font.pixelSize: 14
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (row.modelData.sub ?? "") !== "" && ["spotlight", "raycast", "start"].indexOf(root.style) >= 0 && root.fl !== "minimal"
                        width: Math.max(0, parent.width - nameT.width - kindT.width - 120)
                        elide: Text.ElideRight
                        text: row.modelData.sub ?? ""
                        color: row.sel && (root.fl === "flat" || root.style === "start") ? Qt.rgba(row.fg.r, row.fg.g, row.fg.b, 0.7) : root.dim
                        font.family: root.face
                        font.pixelSize: 13
                    }
                }
                Text {
                    id: kindT

                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.style !== "start" && root.style !== "poster"
                    text: root.cased(root.kindWord(row.modelData))
                    color: row.sel && root.style !== "index" ? (root.style === "prompt" || root.fl === "flat" ? row.fg : Colours.accent) : Colours.alpha(root.dim, 0.8)
                    font.family: root.style === "hud" || root.style === "prompt" ? Appearance.fontFamily.mono : root.face
                    font.pixelSize: 12
                    font.italic: root.style === "index" || root.style === "grimoire"
                    font.letterSpacing: root.upper ? 2 : 0.5
                }
            }

            SmoothScroll {
                view: list
                step: root.rowH * 2
            }
        }

        // nothing found
        Text {
            visible: root.results.length === 0
            x: list.x + 16
            y: list.y + 8
            text: ({
                    prompt: "no match",
                    arcade: "NO GAMES FOUND",
                    hud: "NO SIGNAL",
                    index: "No entry by that name.",
                    grimoire: "No such spell is written here.",
                    poster: "NOTHING."
                })[root.style] ?? "No results"
            color: root.dim
            font.family: root.face
            font.pixelSize: root.style === "poster" ? 40 : 15
            font.italic: root.style === "index" || root.style === "grimoire"
        }

        // ── the foot: how to move
        Text {
            visible: root.footH > 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            text: ({
                    arcade: "↑↓ SELECT   ⏎ START   ESC BACK",
                    hud: "[↑↓] NAV  ·  [⏎] EXEC  ·  [ESC] ABORT",
                    index: "↑ ↓ to turn · return to read · esc to fold the paper",
                    grimoire: "↑ ↓ to leaf · return to cast · esc to close the book",
                    start: root.wv === "95" ? "" : "Enter to open  ·  Esc to close"
                })[root.style] ?? "↑↓ to move  ·  ⏎ to open  ·  = sum  ·  > command  ·  Alt+P pin"
            color: root.style === "start" && root.wv !== "10" && root.wv !== "7" ? "#555555" : Colours.alpha(root.dim, 0.8)
            font.family: root.face
            font.pixelSize: 11
            font.italic: root.style === "index" || root.style === "grimoire"
            font.letterSpacing: root.upper ? 2 : 0.3
        }
    }
}
