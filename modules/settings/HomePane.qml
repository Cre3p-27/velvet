//  VELVET  ·  modules/settings/HomePane.qml
//  The HOME room — the title screen Super+Tab lands on. Not the settings
//  menu: a game's main menu instead. v8 is PORTRAIT: one tall column
//  standing upright in the middle of the screen, framed by two accent
//  rails, exactly like an arcade cabinet. A living logo (glow, counter-
//  rotating dashed rings, an orbit dot), the VELVET word with its shimmer,
//  a giant live clock, the player card (name, face, and a row of
//  personalisation: accent colour swatches, a random roll, and the
//  12/24h clock), and six launch tiles stacked like a classic main menu
//  — NEW GAME / CONTINUE / SETTINGS / QUIT energy. When you pick another
//  room, the whole thing tips sideways and the room unfolds to landscape
//  (the flip lives in Settings.qml).
//
//  Keyboard: ↑ ↓ move · ENTER/SPACE fire · 1…6 fire direct · E renames you
//  · A picks your photo · C (or ← →) cycles the accent · ESC closes.
//
//  The MPRIS import never lives here — nothing in this file needs it.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Shapes

FocusScope {
    id: root
    focus: true

    // ---------------------------------------------------------- the profile
    //  ~/.face, probed once like the lock does — a missing picture is a
    //  quiet badge, not a QML warning.
    property bool faceExists: false
    readonly property string faceUrl: `file://${Quickshell.env("HOME") ?? ""}/.face`
    // Bumped by the settings window every time the face picker applies a
    // photo, so the avatar swaps instantly instead of showing a stale cache.
    property int faceRev: 0
    // The settings window answers by raising its face picker overlay.
    signal openFacePicker()

    FileView {
        id: faceProbe

        path: root.faceUrl.replace("file://", "")
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: root.faceExists = true
        onLoadFailed: root.faceExists = false
    }

    readonly property bool wearFace: Config.home.avatarFace && root.faceExists

    // The photo is set imperatively rather than bound: a fresh pick (or a
    // changed ~/.face) must re-read the file, and query-string cache
    // busters on file:// URLs are exactly what breaks the load.
    function refreshFace(): void {
        faceImg.source = "";
        if (root.wearFace)
            faceImg.source = root.faceUrl;
    }

    onFaceRevChanged: root.refreshFace()
    onFaceExistsChanged: root.refreshFace()
    readonly property string playerName: Config.home.displayName !== "" ? Config.home.displayName : Locker.user
    readonly property string initial: root.playerName.length > 0 ? root.playerName[0].toUpperCase() : "?"

    // ------------------------------------------------------- the entrance
    //  Staged like a title screen: the column lands, then the player card,
    //  then the tiles one after another. zoneLoader rebuilds this pane on
    //  every visit, so the entrance plays every time Super+Tab comes home.
    property int stage: 0

    Timer {
        id: t1
        interval: 40
        onTriggered: root.stage = 1
    }
    Timer {
        id: t2
        interval: 150
        onTriggered: root.stage = 2
    }
    Timer {
        id: t3
        interval: 260
        onTriggered: root.stage = 3
    }

    Component.onCompleted: {
        t1.start();
        t2.start();
        t3.start();
        root.refreshFace();
    }

    // ------------------------------------------------------------- geometry
    //  One upright column, centred. If the screen is too short the whole
    //  column scales down like a responsive game UI — nothing gets cut.
    readonly property real colW: Math.min(root.width * 0.44, 640)

    // ---------------------------------------------------------- the clock
    property var now: new Date()

    Timer {
        running: true
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    readonly property string dateLine: Qt.formatDate(root.now, "ddd · d MMM").toUpperCase()
    readonly property string clockH: {
        const h = root.now.getHours();
        if (Config.bar.clock.format24h)
            return h < 10 ? "0" + h : `${h}`;
        return `${h % 12 === 0 ? 12 : h % 12}`;
    }
    readonly property string clockM: {
        const m = root.now.getMinutes();
        return m < 10 ? "0" + m : `${m}`;
    }
    readonly property string clockS: {
        const s = root.now.getSeconds();
        return s < 10 ? "0" + s : `${s}`;
    }
    readonly property bool isPM: root.now.getHours() >= 12

    // -------------------------------------------------------------- the menu
    readonly property var tiles: [
        {
            name: "LAUNCHER",
            sub: "APPS · SUPER+SPACE",
            icon: "rocket_launch"
        },
        {
            name: "DESKTOP MAP",
            sub: "EVERY WINDOW, ONE MAP",
            icon: "map"
        },
        {
            name: "WALLPAPERS",
            sub: "THE COVERFLOW WHEEL",
            icon: "image"
        },
        {
            name: "NOTIFICATIONS",
            // Filled live in the delegate: a binding here rebuilt the whole
            // tile array on every notification and the tiles vanished.
            sub: "",
            icon: "notifications"
        },
        {
            name: "LOCK",
            sub: "SECURE THE SESSION",
            icon: "lock"
        },
        {
            name: "POWER",
            sub: "SLEEP · RESTART · EXIT",
            icon: "power_settings_new"
        }
    ]

    property int menuIdx: 0

    function moveMenu(dy: int): void {
        if (dy === 0)
            return;
        root.menuIdx = (root.menuIdx + dy + root.tiles.length) % root.tiles.length;
        Sfx.cursor();
    }

    function fire(idx: int): void {
        Sfx.select();
        switch (idx) {
        case 0:
            Panels.toggleLauncher();
            break;
        case 1:
            Panels.closeAll();
            Panels.toggleWindowMap();
            break;
        case 2:
            Panels.toggleWheel();
            break;
        case 3:
            Panels.toggleNotifCentre();
            break;
        case 4:
            // Lock everything first — the overlay must never sit on top
            // of the lock screen.
            Panels.closeAll();
            Actions.lock();
            break;
        case 5:
            Panels.toggleSession();
            break;
        }
    }

    // --------------------------------------------------------- the look
    //  Personalisation on the title screen itself: six accent presets,
    //  a random roll, handing the accent back to the wallpaper, and the
    //  12/24h clock. Every pick is one click and the whole shell recolours
    //  live.
    readonly property var accents: ["#e4002b", "#ff6d00", "#ffb300", "#00a884", "#0aa2ff", "#7c4dff"]
    readonly property var accentNames: ["CRIMSON", "EMBER", "GOLD", "EMERALD", "AZURE", "VIOLET"]

    function isAccent(hex: string): bool {
        return Config.appearance.accentSource === "manual"
            && Config.appearance.accentColour.toLowerCase() === hex.toLowerCase();
    }

    function pickAccent(i: int): void {
        const idx = Math.max(0, Math.min(root.accents.length - 1, i));
        Config.set("appearance.accentSource", "manual");
        Config.set("appearance.accentColour", root.accents[idx]);
        Sfx.select();
        Toast.show(`ACCENT → ${root.accentNames[idx]}`, "info", 2500);
    }

    function cycleAccent(d: int): void {
        let i = 0;
        const cur = Config.appearance.accentColour.toLowerCase();
        for (let k = 0; k < root.accents.length; k++) {
            if (root.accents[k].toLowerCase() === cur) {
                i = k;
                break;
            }
        }
        root.pickAccent((i + d + root.accents.length) % root.accents.length);
    }

    function wallpaperAccent(): void {
        Config.set("appearance.accentSource", "wallpaper");
        Sfx.select();
        Toast.show("ACCENT FOLLOWS THE WALLPAPER AGAIN", "info", 2500);
    }

    function randomAccent(): void {
        const c = Qt.hsla(Math.random(), 0.74, 0.5, 1);
        const hex = "#" + [c.r, c.g, c.b]
            .map(v => Math.round(v * 255).toString(16).padStart(2, "0"))
            .join("");
        Config.set("appearance.accentSource", "manual");
        Config.set("appearance.accentColour", hex);
        Sfx.select();
        Toast.show("ACCENT → RANDOM ROLL", "info", 2500);
    }

    function toggleClockMode(): void {
        Config.toggle("bar.clock.format24h");
        Sfx.toggle();
        Toast.show(`CLOCK → ${Config.bar.clock.format24h ? "24H" : "12H"}`, "info", 2500);
    }

    // ----------------------------------------------------------- the name
    function startEdit(): void {
        root.editing = true;
        editFocus.restart();
    }

    property bool editing: false

    Timer {
        id: editFocus
        interval: 30
        onTriggered: {
            if (!root.editing)
                return;
            nameInput.text = root.playerName;
            nameInput.forceActiveFocus();
            nameInput.cursorPosition = nameInput.text.length;
        }
    }

    // ----------------------------------------------------------- parallax
    //  The column leans into the mouse and leans back when the mouse leaves.
    property real hoverX: 0.5
    property real hoverY: 0.5

    HoverHandler {
        id: panHandler

        onPointChanged: p => {
            if (p) {
                root.hoverX = p.position.x;
                root.hoverY = p.position.y;
            }
        }
        onHoveredChanged: {
            if (!hovered) {
                root.hoverX = 0.5;
                root.hoverY = 0.5;
            }
        }
    }

    // -------------------------------------------------------------- keyboard
    Keys.onPressed: event => {
        // While the name field is open it owns the keyboard entirely.
        if (nameInput.activeFocus)
            return;

        switch (event.key) {
        case Qt.Key_Up:
            root.moveMenu(-1);
            event.accepted = true;
            return;
        case Qt.Key_Down:
            root.moveMenu(1);
            event.accepted = true;
            return;
        case Qt.Key_Left:
            root.cycleAccent(-1);
            event.accepted = true;
            return;
        case Qt.Key_Right:
            root.cycleAccent(1);
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.fire(root.menuIdx);
            event.accepted = true;
            return;
        case Qt.Key_E:
            root.startEdit();
            event.accepted = true;
            return;
        case Qt.Key_A:
            root.openFacePicker();
            Sfx.open();
            event.accepted = true;
            return;
        case Qt.Key_C:
            root.cycleAccent(1);
            event.accepted = true;
            return;
        case Qt.Key_1:
        case Qt.Key_2:
        case Qt.Key_3:
        case Qt.Key_4:
        case Qt.Key_5:
        case Qt.Key_6:
            root.fire(event.key - Qt.Key_1);
            event.accepted = true;
            return;
        }
        // ESC and F1 bubble to the settings' key brain via Keys.forwardTo.
    }

    // ================================================================ visuals
    // ── embers: slow motes drifting up the whole pane, behind everything
    Repeater {
        model: 14

        Rectangle {
            id: ember

            width: 3 + Math.random() * 3
            height: width
            radius: width / 2
            x: Math.random() * root.width
            y: root.height + 10
            color: Colours.accent
            opacity: 0

            SequentialAnimation on y {
                running: true
                loops: Animation.Infinite
                NumberAnimation {
                    from: root.height + 10
                    to: -30
                    duration: 9000 + Math.random() * 9000
                    easing.type: Easing.InSine
                }
            }
            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0
                    to: 0.34
                    duration: 2200
                    easing.type: Easing.OutSine
                }
                NumberAnimation {
                    from: 0.34
                    to: 0
                    duration: 7000
                    easing.type: Easing.InSine
                }
            }
        }
    }

    // ── the portrait frame: two upright accent rails flanking the column,
    //  with corner ticks top and bottom. This is what makes the title
    //  screen read as PORTRAIT against the wide room around it.
    Item {
        id: frame

        opacity: root.stage >= 1 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.entrance
                easing.type: Easing.OutExpo
            }
        }

        Slash {
            id: railL

            x: col.x - 40
            y: col.y
            width: 3
            height: col.height * col.scale
            shear: 0
            color: Colours.alpha(Colours.accent, 0.5)
        }

        Slash {
            id: railR

            x: col.x + col.width * col.scale + 37
            y: col.y
            width: 3
            height: col.height * col.scale
            shear: 0
            color: Colours.alpha(Colours.accent, 0.5)
        }

        Repeater {
            model: [railL, railR]

            Slash {
                required property var modelData

                x: modelData.x - 12
                y: modelData.y - 5
                width: 27
                height: 3
                shear: 0
                color: Colours.alpha(Colours.accent, 0.9)
            }
        }

        Repeater {
            model: [railL, railR]

            Slash {
                required property var modelData

                x: modelData.x - 12
                y: modelData.y + modelData.height + 2
                width: 27
                height: 3
                shear: 0
                color: Colours.alpha(Colours.accent, 0.9)
            }
        }
    }

    // ── the column: everything stacked, standing upright
    Item {
        id: col

        width: root.colW
        height: stack.implicitHeight
        // centred by what is SEEN: the column shrinks from its top-left
        // corner on a short window, and was then pushed off to the right
        x: (root.width - root.colW * col.scale) / 2 + (0.5 - root.hoverX) * 16
        y: Math.max(10, (root.height - col.height * col.scale) / 2)
        scale: Math.min(1, (root.height - 24) / col.height)
        transformOrigin: Item.TopLeft
        opacity: root.stage >= 1 ? 1 : 0

        Behavior on x {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutQuad
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutExpo
            }
        }

        transform: Translate {
            y: root.stage >= 1 ? 0 : 34

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.entrance
                    easing.type: Easing.OutExpo
                }
            }
        }

        Column {
            id: stack

            width: parent.width
            spacing: 0

            // ------------------------------------------------ the tag
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 26
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
                    text: "TITLE SCREEN"
                    color: Colours.accentInk
                    font.pixelSize: Appearance.font.size.small
                    tracking: 4
                }
            }

            Item {
                width: parent.width
                height: 14
            }

            // ------------------------------------------------ the logo core
            //  The mark sits in a small solar system: a breathing glow, two
            //  dashed rings turning opposite ways, and a spark riding the
            //  outer ring like a satellite.
            Item {
                id: logo

                width: parent.width
                height: 184

                // the breathing glow — the same RadialGradient recipe Blobs uses
                Shape {
                    id: glow

                    x: (parent.width - 264) / 2
                    y: (184 - 264) / 2
                    width: 264
                    height: 264
                    opacity: root.stage >= 1 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.entrance
                        }
                    }

                    ShapePath {
                        // no outline: a ShapePath strokes 1 px white unless told not to
                        strokeColor: "transparent"
                        strokeWidth: -1
                        fillColor: "transparent"

                        fillGradient: RadialGradient {
                            centerX: glow.width / 2
                            centerY: glow.height / 2
                            focalX: glow.width / 2
                            focalY: glow.height / 2
                            centerRadius: 96
                            focalRadius: 0

                            GradientStop {
                                position: 0.0
                                color: Colours.alpha(Colours.accent, 0.16)
                            }
                            GradientStop {
                                position: 0.6
                                color: Colours.alpha(Colours.accent, 0.05)
                            }
                            GradientStop {
                                position: 1.0
                                color: Colours.alpha(Colours.accent, 0)
                            }
                        }

                        PathPolyline {
                            path: [
                                Qt.point(0, 0),
                                Qt.point(glow.width, 0),
                                Qt.point(glow.width, glow.height),
                                Qt.point(0, glow.height),
                                Qt.point(0, 0)
                            ]
                        }
                    }
                }

                SequentialAnimation on scale {
                    running: root.stage >= 1
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 1
                        to: 1.07
                        duration: 2800
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 1.07
                        to: 1
                        duration: 2800
                        easing.type: Easing.InOutSine
                    }
                }

                // the outer ring, turning right, with the satellite spark
                Item {
                    id: outerRing

                    x: (parent.width - 200) / 2
                    y: -8
                    width: 200
                    height: 200
                    opacity: root.stage >= 1 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.entrance
                        }
                    }

                    RotationAnimation on rotation {
                        running: root.stage >= 1
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 46000
                    }

                    Shape {
                        anchors.fill: parent
                        asynchronous: false

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Colours.alpha(Colours.accent, 0.4)
                            strokeWidth: 1.5
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [1, 10]
                            capStyle: ShapePath.RoundCap

                            PathMove {
                                x: 200
                                y: 100
                            }
                            PathArc {
                                x: 199.99
                                y: 100
                                radiusX: 100
                                radiusY: 100
                                useLargeArc: true
                            }
                        }
                    }

                    // the satellite: a spark and its halo, riding the ring
                    Plate {
                        x: 100 - 7
                        y: -7
                        width: 14
                        height: 14
                        radius: Appearance.r(7)
                        color: Colours.alpha(Colours.accent, 0.16)
                    }

                    Rectangle {
                        x: 100 - 3
                        y: -3
                        width: 6
                        height: 6
                        radius: 3
                        color: Colours.accent
                    }
                }

                // the inner ring, turning against it
                Item {
                    id: innerRing

                    x: (parent.width - 168) / 2
                    y: 8
                    width: 168
                    height: 168
                    opacity: root.stage >= 1 ? 0.8 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.entrance
                        }
                    }

                    RotationAnimation on rotation {
                        running: root.stage >= 1
                        loops: Animation.Infinite
                        direction: RotationAnimation.Counterclockwise
                        from: 0
                        to: 360
                        duration: 30000
                    }

                    Shape {
                        anchors.fill: parent
                        asynchronous: false

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: Colours.alpha(Colours.accent, 0.26)
                            strokeWidth: 1.5
                            strokeStyle: ShapePath.DashLine
                            dashPattern: [3, 7]
                            capStyle: ShapePath.RoundCap

                            PathMove {
                                x: 168
                                y: 84
                            }
                            PathArc {
                                x: 167.99
                                y: 84
                                radiusX: 84
                                radiusY: 84
                                useLargeArc: true
                            }
                        }
                    }
                }

                // the mark itself, assembling and turning its frame
                VelvetMark {
                    id: mark

                    x: (parent.width - 148) / 2
                    y: 18
                    width: 148
                    height: 148
                    reveal: root.stage >= 1 ? 1 : 0
                    spin: true

                    Behavior on reveal {
                        NumberAnimation {
                            duration: Appearance.anim.entrance
                            easing.type: Easing.OutExpo
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 8
            }

            // ------------------------------------------------ the word
            //  A shimmer band sweeps across the letters every few seconds.
            Item {
                id: word

                width: parent.width
                height: 100
                clip: true

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    display: true
                    text: "VELVET"
                    color: Colours.ink
                    font.pixelSize: Math.max(72, Math.min(122, root.colW * 0.17))
                    tracking: -3
                    lineHeight: 0.9
                }

                Slash {
                    id: shimmer

                    y: 8
                    width: 96
                    height: word.height - 16
                    shear: Appearance.skew
                    rotation: -4
                    color: Colours.alpha(Colours.accent, 0.14)
                    x: -140

                    SequentialAnimation on x {
                        running: root.stage >= 1
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: -140
                            to: word.width + 60
                            duration: 1100
                            easing.type: Easing.InOutCubic
                        }
                        PauseAnimation {
                            duration: 4600
                        }
                    }
                }
            }

            Slash {
                id: underline

                anchors.horizontalCenter: parent.horizontalCenter
                width: root.stage >= 1 ? 170 : 0
                height: 4
                shear: Appearance.skew
                color: Colours.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.entrance
                        easing.type: Easing.OutExpo
                    }
                }
            }

            Item {
                width: parent.width
                height: 12
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: "THE DESKTOP, BUILT LIKE A GAME"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.normal
                tracking: 3
            }

            Item {
                width: parent.width
                height: 26
            }

            // ------------------------------------------------ the clock
            //  The title screen's pulse: giant digits, a colon that breathes,
            //  seconds ticking in the margin, and an AM/PM pill when the bar
            //  prefers twelve hours.
            Row {
                id: clockRow

                anchors.horizontalCenter: parent.horizontalCenter
                height: 108
                spacing: 4

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: root.clockH
                    color: Colours.ink
                    font.pixelSize: 108
                    tracking: -2
                    lineHeight: 0.95
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: ":"
                    color: Colours.accent
                    font.pixelSize: 90

                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.15
                            duration: 750
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1
                            duration: 750
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: root.clockM
                    color: Colours.ink
                    font.pixelSize: 108
                    tracking: -2
                    lineHeight: 0.95
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    P5Text {
                        text: root.clockS
                        color: Colours.inkDim
                        font.family: Appearance.fontFamily.mono
                        font.pixelSize: Appearance.font.size.normal
                    }

                    Slash {
                        width: 46
                        height: 24
                        shear: Appearance.skew
                        visible: !Config.bar.clock.format24h
                        color: Colours.alpha(Colours.ink, 0.08)
                        borderColor: Colours.alpha(Colours.ink, 0.3)
                        borderWidth: 1

                        P5Text {
                            anchors.centerIn: parent
                            display: true
                            text: root.isPM ? "PM" : "AM"
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 6
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateLine
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.small
                tracking: 2
            }

            Item {
                width: parent.width
                height: 26
            }

            // ------------------------------------------------ the player card
            Item {
                id: profile

                width: parent.width
                height: 118
                opacity: root.stage >= 2 ? 1 : 0
                scale: root.stage >= 2 ? 1 : 0.96

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }

                Slash {
                    anchors.fill: parent
                    shear: Appearance.skew
                    color: Colours.alpha(Colours.ink, 0.05)
                    borderColor: Colours.alpha(Colours.ink, 0.18)
                    borderWidth: 1
                }

                // The face — the ~/.face photo, or the initial glyph.
                Item {
                    id: face

                    x: 22
                    anchors.verticalCenter: parent.verticalCenter
                    width: 76
                    height: 76

                    Plate {
                        anchors.fill: parent
                        radius: Appearance.r(38)
                        color: Colours.alpha(Colours.ink, 0.08)
                        clip: true
                        antialiasing: true

                        Image {
                            id: faceImg

                            anchors.fill: parent
                            visible: root.wearFace
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            smooth: true
                        }

                        // The fallback: your initial, cut in the accent.
                        P5Text {
                            anchors.centerIn: parent
                            display: true
                            visible: !root.wearFace
                            text: root.initial
                            color: Colours.on(Colours.accent)
                            font.pixelSize: 40
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: !root.wearFace
                            color: Colours.alpha(Colours.accent, 0.85)
                            z: -1
                        }
                    }

                    // The accent ring, and it is the avatar toggle.
                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.r(38)
                        color: "transparent"
                        border.width: 2
                        border.color: Colours.accent
                        antialiasing: true
                    }

                    Ripple {
                        id: faceRipple

                        anchors.fill: parent
                        color: Colours.accent
                        maxOpacity: 0.3
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: event => {
                            faceRipple.pop(event.x, event.y);
                            root.openFacePicker();
                            Sfx.open();
                        }
                    }
                }

                Column {
                    anchors.left: face.right
                    anchors.leftMargin: 22
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    P5Text {
                        display: true
                        text: "PLAYER"
                        color: Colours.accentInk
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 3
                    }

                    Row {
                        spacing: 10

                        TextInput {
                            id: nameInput

                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(120, Math.min(nameInput.implicitWidth + 8, profile.width - 180))
                            text: root.playerName
                            color: Colours.ink
                            font.family: Appearance.fontFamily.display
                            font.pixelSize: 30
                            readOnly: !root.editing
                            selectByMouse: true
                            cursorDelegate: Rectangle {
                                width: 2
                                color: Colours.accent
                            }

                            onEditingFinished: {
                                // Commit what the player typed; empty keeps the
                                // login name.
                                Config.set("home.displayName", text.trim());
                                root.editing = false;
                                Sfx.select();
                            }

                            Keys.onEscapePressed: event => {
                                text = root.playerName;
                                root.editing = false;
                                focus = false;
                                root.forceActiveFocus();
                                Sfx.back();
                                event.accepted = true;
                            }
                        }

                        Icon {
                            id: editGlyph

                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            name: "edit"
                            color: editArea.containsMouse ? Colours.accent : Colours.inkDim
                            font.pixelSize: 15

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }

                            MouseArea {
                                id: editArea

                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.startEdit()
                            }
                        }
                    }

                    P5Text {
                        text: `${Locker.user}${SysInfo.hostname !== "" ? "@" + SysInfo.hostname : ""}   ·   ${SysInfo.osPrettyName.toUpperCase()}`
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.small
                        tracking: 1
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    P5Text {
                        text: root.wearFace ? "CLICK THE PHOTO TO PICK A NEW ONE  ·  PRESS A" : "NO PHOTO YET  ·  CLICK OR PRESS A TO PICK ONE"
                        color: Colours.accentInk
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.1
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }

            Item {
                width: parent.width
                height: 20
            }

            // ------------------------------------------------ your look
            //  The personalisation row: accent swatches, wallpaper-source
            //  handoff, a random roll, and the clock mode — all live.
            //  Explicit x positions: a Row positioner would override the
            //  right-edge anchor of the clock chip.
            Item {
                id: lookRow

                width: parent.width
                height: 54
                opacity: root.stage >= 2 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                    }
                }

                // The label steps aside on narrow columns so the chips fit.
                readonly property bool narrow: lookRow.width < 560
                readonly property real wallX: lookRow.narrow ? 0 : 100
                readonly property real swatchX: lookRow.wallX + 112
                readonly property real rollX: lookRow.swatchX + 236

                P5Text {
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 92
                    display: true
                    visible: !lookRow.narrow
                    text: "YOUR LOOK"
                    color: Colours.accentInk
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 2
                }

                Item {
                    id: wallChip

                    x: lookRow.wallX
                    anchors.verticalCenter: parent.verticalCenter
                    width: 104
                    height: 38
                    scale: wallArea.containsMouse ? 1.06 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.4
                        }
                    }

                    Slash {
                        anchors.fill: parent
                        shear: Appearance.skew
                        color: Config.appearance.accentSource === "wallpaper" ? Colours.accent : (wallArea.containsMouse ? Colours.alpha(Colours.ink, 0.14) : Colours.alpha(Colours.ink, 0.05))
                        borderColor: Config.appearance.accentSource === "wallpaper" ? "transparent" : Colours.alpha(Colours.ink, 0.24)
                        borderWidth: 1

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            name: "image"
                            color: Config.appearance.accentSource === "wallpaper" ? Colours.on(Colours.accent) : Colours.inkDim
                            font.pixelSize: 13
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            display: true
                            text: "WALLPAPER"
                            color: Config.appearance.accentSource === "wallpaper" ? Colours.on(Colours.accent) : Colours.ink
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 0.6
                        }
                    }

                    MouseArea {
                        id: wallArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.wallpaperAccent()
                    }
                }

                Repeater {
                    model: root.accents

                    Item {
                        id: swatch

                        required property var modelData
                        required property int index

                        x: lookRow.swatchX + swatch.index * 38
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        height: 38
                        scale: swatchArea.containsMouse || root.isAccent(swatch.modelData) ? 1.12 : 1

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
                            color: swatch.modelData
                            borderColor: root.isAccent(swatch.modelData) ? Colours.accent : Colours.alpha(Colours.ink, 0.24)
                            borderWidth: root.isAccent(swatch.modelData) ? 2 : 1

                            Behavior on borderColor {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        Slash {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height + 4
                            width: 16
                            height: 3
                            shear: Appearance.skew
                            color: Colours.accent
                            visible: root.isAccent(swatch.modelData)
                        }

                        MouseArea {
                            id: swatchArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pickAccent(swatch.index)
                        }
                    }
                }

                Item {
                    id: rollChip

                    x: lookRow.rollX
                    anchors.verticalCenter: parent.verticalCenter
                    width: 92
                    height: 38
                    scale: rollArea.containsMouse ? 1.06 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.4
                        }
                    }

                    Slash {
                        anchors.fill: parent
                        shear: Appearance.skew
                        color: rollArea.containsMouse ? Colours.alpha(Colours.ink, 0.14) : Colours.alpha(Colours.ink, 0.05)
                        borderColor: Colours.alpha(Colours.ink, 0.24)
                        borderWidth: 1

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            name: "refresh"
                            color: Colours.inkDim
                            font.pixelSize: 13
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            display: true
                            text: "RANDOM"
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 0.6
                        }
                    }

                    MouseArea {
                        id: rollArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.randomAccent()
                    }
                }

                Item {
                    id: clockChip

                    x: parent.width - 88
                    anchors.verticalCenter: parent.verticalCenter
                    width: 88
                    height: 38
                    scale: clockArea.containsMouse ? 1.06 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.4
                        }
                    }

                    Slash {
                        anchors.fill: parent
                        shear: Appearance.skew
                        color: clockArea.containsMouse ? Colours.alpha(Colours.ink, 0.14) : Colours.alpha(Colours.ink, 0.05)
                        borderColor: Colours.alpha(Colours.ink, 0.24)
                        borderWidth: 1

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            name: "timer"
                            color: Colours.inkDim
                            font.pixelSize: 13
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            display: true
                            text: Config.bar.clock.format24h ? "24H" : "12H"
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 0.6
                        }
                    }

                    MouseArea {
                        id: clockArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleClockMode()
                    }
                }
            }

            Item {
                width: parent.width
                height: 22
            }

            // ------------------------------------------------ the menu
            //  Six launch tiles, stacked like a classic main menu.
            Column {
                id: menu

                width: parent.width
                spacing: 8

                Repeater {
                    model: root.tiles

                    Item {
                        id: tile

                        required property var modelData
                        required property int index

                        readonly property bool sel: tile.index === root.menuIdx
                        // The hover/selection scale rides a Behavior; the fly-in
                        // animates baseScale, so the two never fight over the
                        // same property (a self-referential binding would loop).
                        property real baseScale: 0.9
                        property real baseY: 22

                        width: parent.width
                        height: 60
                        opacity: 0
                        scale: tileArea.containsMouse || tile.sel ? 1.03 : tile.baseScale
                        transform: Translate {
                            y: tile.baseY
                        }

                        // Fly in one after another once the player card has landed.
                        SequentialAnimation {
                            id: flyIn

                            running: false

                            PauseAnimation {
                                duration: tile.index * 55
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: tile
                                    property: "opacity"
                                    to: 1
                                    duration: Appearance.anim.normal
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: tile
                                    property: "baseScale"
                                    to: 1
                                    duration: Appearance.anim.normal
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.9
                                }
                                NumberAnimation {
                                    target: tile
                                    property: "baseY"
                                    to: 0
                                    duration: Appearance.anim.normal
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Connections {
                            target: root

                            function onStageChanged(): void {
                                if (root.stage >= 3)
                                    flyIn.start();
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.4
                            }
                        }

                        Slash {
                            anchors.fill: parent
                            shear: Appearance.skew
                            color: tile.sel ? Colours.accent : (tileArea.containsMouse ? Colours.alpha(Colours.ink, 0.13) : Colours.alpha(Colours.ink, 0.05))
                            borderColor: tile.sel ? "transparent" : Colours.alpha(Colours.ink, 0.2)
                            borderWidth: 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        // The hover sweep — a light band that rakes across the
                        // tile once when the mouse arrives.
                        Rectangle {
                            id: sweep

                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 48
                            rotation: -4
                            x: -70
                            opacity: 0
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: "transparent"
                                }
                                GradientStop {
                                    position: 0.5
                                    color: Colours.alpha(Colours.accent, 0.13)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: "transparent"
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }

                            SequentialAnimation {
                                id: sweepAnim

                                NumberAnimation {
                                    target: sweep
                                    property: "x"
                                    from: -70
                                    to: tile.width + 60
                                    duration: 520
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        // The selection notch, cut into the left edge.
                        Slash {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 0
                            width: 4
                            height: 28
                            shear: Appearance.skew
                            color: tile.sel ? Colours.on(Colours.accent) : "transparent"
                        }

                        // The corner key badge — 1…6, like a controller map.
                        Slash {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            height: 24
                            shear: Appearance.skew
                            color: tile.sel ? Colours.alpha(Colours.on(Colours.accent), 0.22) : Colours.alpha(Colours.accent, 0.14)
                            borderColor: tile.sel ? "transparent" : Colours.alpha(Colours.accent, 0.35)
                            borderWidth: 1

                            P5Text {
                                anchors.centerIn: parent
                                display: true
                                text: `${tile.index + 1}`
                                color: tile.sel ? Colours.on(Colours.accent) : Colours.accent
                                font.pixelSize: Appearance.font.size.tiny
                                tracking: 0
                            }
                        }

                        // The icon chip — an inventory slot for the glyph.
                        Slash {
                            x: 56
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            height: 38
                            shear: Appearance.skew
                            color: tile.sel ? Colours.alpha(Colours.on(Colours.accent), 0.2) : Colours.alpha(Colours.accent, 0.12)
                            borderColor: tile.sel ? "transparent" : Colours.alpha(Colours.accent, 0.35)
                            borderWidth: 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: tile.modelData.icon
                                color: tile.sel ? Colours.on(Colours.accent) : Colours.accent
                                font.pixelSize: 21
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 112
                            anchors.right: parent.right
                            anchors.rightMargin: 44
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            P5Text {
                                width: parent.width
                                display: true
                                text: tile.modelData.name
                                color: tile.sel ? Colours.on(Colours.accent) : Colours.ink
                                font.pixelSize: Appearance.font.size.large
                                tracking: 1
                                elide: Text.ElideRight
                            }

                            P5Text {
                                width: parent.width
                                text: tile.modelData.name === "NOTIFICATIONS" ? `${Notifs.unread} UNREAD` : tile.modelData.sub
                                color: tile.sel ? Colours.alpha(Colours.on(Colours.accent), 0.8) : Colours.inkDim
                                font.pixelSize: Appearance.font.size.tiny
                                tracking: 1.2
                                elide: Text.ElideRight
                            }
                        }

                        Icon {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            name: "chevron_right"
                            color: tile.sel ? Colours.on(Colours.accent) : Colours.alpha(Colours.ink, 0.35)
                            font.pixelSize: 16

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        Ripple {
                            id: tileRipple

                            anchors.fill: parent
                            color: Colours.ink
                            maxOpacity: 0.22
                        }

                        MouseArea {
                            id: tileArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                if (!tile.sel) {
                                    sweep.opacity = 1;
                                    sweep.x = -70;
                                    sweepAnim.restart();
                                }
                            }
                            onExited: sweep.opacity = 0
                            onClicked: event => {
                                root.menuIdx = tile.index;
                                tileRipple.pop(event.x, event.y);
                                root.fire(tile.index);
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 20
            }

            // The breathing call to action, under the menu.
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "↑ ↓ MOVE   ·   ENTER SELECT   ·   1–6 FIRE DIRECT   ·   E RENAMES YOU   ·   A SWAPS THE PHOTO   ·   C CYCLES THE ACCENT"
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.4

                SequentialAnimation on opacity {
                    running: root.stage >= 1
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.2
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }
}
