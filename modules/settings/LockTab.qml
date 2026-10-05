//  VELVET  ·  modules/settings/LockTab.qml
//  The lock screen, arranged by hand — and what you see here is the real
//  thing: the two side tile columns render the actual modules (cards and
//  contents), exactly like the lock will. A slim handle rides above each
//  module for dragging it to the other tile or a new position; Del
//  removes the selected one. The centre is the card's fixed stage —
//  clock, profile and password — shown but not editable.
//
//  The right side is the stage control: the background the wallpaper
//  sits in — the plain blur by default, the big shape glyph if you
//  want it back.
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import Quickshell
import QtQuick

FocusScope {
    id: root

    focus: true

    property string selected: ""
    property string dragId: ""
    property real ghostX: 0
    property real ghostY: 0

    // The tiles render the real modules, scaled so the whole picture fits
    // the editor stage. The scale adapts to the tallest column, so the
    // preview always sits cleanly inside the card.
    readonly property real es: {
        const hts = {
            "weather": 310,
            "media": 162,
            "notifs": 240,
            "resources": 190,
            "user": 84,
            "battery": 84,
            "net": 84,
            "power": 96,
            "session": 206,
            "greeting": 64
        };
        let maxH = 0;
        for (const z of ["left", "right"]) {
            let h = 0;
            for (const id of LockLayout.list(z))
                h += (hts[id] ?? 80) + 28;
            maxH = Math.max(maxH, h);
        }
        const avail = Math.min(stage.height * 0.8, stage.width * 0.5) - 64;
        return Math.min(0.8, Math.max(0.42, avail / Math.max(1, maxH)));
    }

    // A tile column drop — the index comes from the entries' actual
    // positions, so reordering among differently-sized modules works.
    function dropIntoCol(col: var, zone: string): bool {
        const pc = col.mapFromItem(root, root.ghostX, root.ghostY);
        if (pc.x < 0 || pc.y < 0 || pc.x >= col.width || pc.y >= col.height)
            return false;
        let at = 0;
        for (let i = 0; i < col.children.length; i++) {
            const kid = col.children[i];
            if (!kid.entry)
                continue;
            if (pc.y > kid.y + kid.height / 2)
                at++;
        }
        const list = LockLayout.list(zone);
        const old = list.indexOf(root.dragId);
        if (old >= 0 && old < at)
            at--;
        LockLayout.placeTile(root.dragId, zone, at);
        return true;
    }

    // Where a drag ended — one of the two side columns, or nowhere.
    function drop(): void {
        if (root.dragId === "")
            return;

        if (!root.dropIntoCol(mockLeftCol, "left"))
            root.dropIntoCol(mockRightCol, "right");

        LockLayout.commit();
        root.selected = root.dragId;
        root.dragId = "";
    }

    // ────────────────────────────────────────────────── the entrance stage
    // The editor IS a preview: picking an entrance replays it on the
    // card right here, every choreography in miniature.
    function playEntrance(value: string): void {
        const m = mockCard;
        m.opacity = 1;
        pvRotY.angle = 0;
        pvDrop.y = 0;
        pvSquash.xScale = 1;
        pvJit.x = 0;
        pvSeam.opacity = 0;
        switch (value) {
        case "morph":
            m.scale = 0.55;
            m.rotation = -12;
            m.radius = 16;
            pvMorph.restart();
            break;
        case "zoom":
            m.scale = 0.8;
            m.rotation = 0;
            m.radius = 30;
            pvZoom.restart();
            break;
        case "drop":
            m.scale = 1;
            m.rotation = 0;
            m.radius = 30;
            m.opacity = 0;
            pvDrop.y = -stage.height * 0.2;
            pvDropAnim.restart();
            break;
        case "fade":
            m.scale = 1;
            m.rotation = 0;
            m.radius = 30;
            m.opacity = 0;
            pvFade.restart();
            break;
        case "flip":
            m.scale = 0.94;
            m.rotation = 0;
            m.radius = 30;
            pvRotY.angle = -95;
            pvFlip.restart();
            break;
        case "vortex":
            m.scale = 0.08;
            m.rotation = -330;
            m.radius = 30;
            pvVortex.restart();
            break;
        case "glitch":
            m.scale = 1;
            m.rotation = 0;
            m.radius = 30;
            m.opacity = 0;
            pvGlitch.restart();
            break;
        case "shutter":
            m.scale = 1;
            m.rotation = 0;
            m.radius = 30;
            pvSquash.xScale = 0.06;
            pvSeam.opacity = 0.9;
            pvShutter.restart();
            break;
        }
    }

    // The preview choreographies — the same moves the real lock plays,
    // shrunk to the editor's card.
    SequentialAnimation {
        id: pvMorph

        ParallelAnimation {
            NumberAnimation { target: mockCard; property: "scale"; to: 1; duration: 480; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { target: mockCard; property: "rotation"; to: 0; duration: 480; easing.type: Easing.OutCubic }
            NumberAnimation { target: mockCard; property: "radius"; to: 30; duration: 480; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: pvZoom

        NumberAnimation { target: mockCard; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.7 }
    }
    SequentialAnimation {
        id: pvDropAnim

        ParallelAnimation {
            NumberAnimation { target: pvDrop; property: "y"; to: 0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
            NumberAnimation { target: mockCard; property: "opacity"; to: 1; duration: 120 }
        }
    }
    SequentialAnimation {
        id: pvFade

        NumberAnimation { target: mockCard; property: "opacity"; to: 1; duration: 420; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {
        id: pvFlip

        ParallelAnimation {
            NumberAnimation { target: pvRotY; property: "angle"; to: 0; duration: 520; easing.type: Easing.OutCubic }
            NumberAnimation { target: mockCard; property: "scale"; to: 1; duration: 520; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: pvVortex

        ParallelAnimation {
            NumberAnimation { target: mockCard; property: "scale"; to: 1; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 1.35 }
            NumberAnimation { target: mockCard; property: "rotation"; to: 0; duration: 620; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: pvGlitch

        SequentialAnimation {
            ParallelAnimation {
                NumberAnimation { target: pvJit; property: "x"; to: -14; duration: 40 }
                NumberAnimation { target: mockCard; property: "opacity"; to: 0.55; duration: 40 }
            }
            ParallelAnimation {
                NumberAnimation { target: pvJit; property: "x"; to: 10; duration: 50 }
                NumberAnimation { target: mockCard; property: "opacity"; to: 1; duration: 50 }
            }
            ParallelAnimation {
                NumberAnimation { target: pvJit; property: "x"; to: -6; duration: 40 }
                NumberAnimation { target: mockCard; property: "opacity"; to: 0.7; duration: 40 }
            }
            ParallelAnimation {
                NumberAnimation { target: pvJit; property: "x"; to: 0; duration: 60 }
                NumberAnimation { target: mockCard; property: "opacity"; to: 1; duration: 60 }
            }
        }
    }
    SequentialAnimation {
        id: pvShutter

        ParallelAnimation {
            NumberAnimation { target: pvSquash; property: "xScale"; to: 1; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            NumberAnimation { target: pvSeam; property: "opacity"; to: 0; duration: 420 }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            if (root.selected !== "") {
                LockLayout.remove(root.selected);
                root.selected = "";
            }
            event.accepted = true;
        }
    }

    // ═══════════════════════════════════════════════════════════════ the stage
    // The real lock's background — the shape glyph and the wallpaper — plus
    // a dim so the editor stays readable. Scroll swaps the glyph, exactly
    // like on the lock.
    Plate {
        id: stage

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * 0.7
        radius: Appearance.r(26)
        color: Colours.paper
        border.width: 1
        border.color: Colours.alpha(Colours.ink, 0.14)
        antialiasing: true
        clip: true

        ShapeBackdrop {
            anchors.fill: parent
            progress: 1
        }

        Rectangle {
            anchors.fill: parent
            color: Colours.alpha(Colours.paper, 0.42)
        }

        WheelHandler {
            onWheel: event => {
                if (root.dragId !== "" || stageCool.running)
                    return;
                const names = ["off", "circle", "arrow", "pill", "burst", "diamond", "clam", "pentagon"];
                const i = names.indexOf(Config.lock.backgroundShape);
                const next = (i < 0 ? 4 : i) + (event.angleDelta.y > 0 ? 1 : -1);
                Config.set("lock.backgroundShape", names[(next + names.length) % names.length]);
                Config.save();
                stageCool.restart();
            }
        }

        Timer {
            id: stageCool
            interval: 400
        }

        // ── the card — same proportions as the lock's, previewing the
        // chosen entrance animation
        Plate {
            id: mockCard

            readonly property real h: Math.min(stage.height * 0.8, stage.width * 0.5)
            readonly property real w: Math.min(stage.width * 0.9, h * 1.62)

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -stage.height * 0.04
            width: mockCard.w
            height: mockCard.h
            radius: Appearance.r(30)
            color: Colours.alpha(Colours.surface, 0.7)
            border.width: 1
            border.color: Colours.alpha(Colours.accent, 0.35)
            antialiasing: true

            // The entrance preview's stage props — drop slide, flip door,
            // shutter squash and glitch jitter.
            transform: [
                Translate {
                    id: pvDrop

                    y: 0
                },
                Rotation {
                    id: pvRotY

                    origin.x: mockCard.width / 2
                    origin.y: mockCard.height / 2
                    axis: Qt.vector3d(0, 1, 0)
                    angle: 0
                },
                Scale {
                    id: pvSquash

                    origin.x: mockCard.width / 2
                    origin.y: mockCard.height / 2
                    xScale: 1
                    yScale: 1
                },
                Translate {
                    id: pvJit

                    x: 0
                    y: 0
                }
            ]

            Rectangle {
                id: pvSeam

                anchors.centerIn: parent
                width: 3
                height: parent.height
                color: Colours.accent
                opacity: 0
                antialiasing: true
            }

            // ── the three tile columns, rendering the REAL modules
            Row {
                id: tileRow

                anchors.fill: parent
                anchors.leftMargin: 32
                anchors.rightMargin: 32
                anchors.topMargin: 24
                anchors.bottomMargin: 24
                spacing: 24

                Column {
                    id: mockLeftCol

                    width: (tileRow.width - mockCenterCol.width - 48) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: LockLayout.list("left").length === 0
                        text: "LEFT TILE"
                        color: Colours.alpha(Colours.inkDim, 0.5)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 2
                    }

                    Repeater {
                        model: LockLayout.list("left")

                        TileEntry {
                            required property var modelData

                            modId: modelData
                            zone: "left"
                            zoneW: mockLeftCol.width
                        }
                    }
                }

                Column {
                    id: mockCenterCol

                    width: Math.min(420, tileRow.width * 0.4)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // The card's fixed centre — shown, not editable:
                    // the clock, the profile, the password pill. The clock
                    // ticks (it used to freeze at the moment the editor
                    // opened), and twelve-hour mode really counts to twelve.
                    SystemClock {
                        id: editorClock

                        precision: SystemClock.Minutes
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        display: true
                        text: Config.bar.clock.format24h ? Qt.formatDateTime(editorClock.date, "HH:mm") : Qt.formatDateTime(editorClock.date, "hh:mm AP").split(" ")[0]
                        color: Colours.accent
                        font.weight: Font.Light
                        font.pixelSize: 56
                        tracking: -2
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(editorClock.date, "dddd • d MMM").toUpperCase()
                        color: Colours.ink
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    ShapeBadge {
                        anchors.horizontalCenter: parent.horizontalCenter
                        size: 30
                        kind: 0
                        hoverKind: -2
                        col: Colours.surfaceHigh
                        icon: "person"
                        iconCol: Colours.alpha(Colours.inkDim, 0.9)
                        iconSize: 13
                    }

                    Plate {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * 0.8
                        height: 40
                        radius: Appearance.r(20)
                        color: Colours.alpha(Colours.surfaceHigh, 0.95)
                        antialiasing: true

                        P5Text {
                            anchors.centerIn: parent
                            text: "Enter your password"
                            color: Colours.alpha(Colours.inkDim, 0.7)
                            font.pixelSize: 11
                        }
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "THE CENTRE IS FIXED"
                        color: Colours.alpha(Colours.inkDim, 0.45)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 2
                    }
                }

                Column {
                    id: mockRightCol

                    width: (tileRow.width - mockCenterCol.width - 48) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: LockLayout.list("right").length === 0
                        text: "RIGHT TILE"
                        color: Colours.alpha(Colours.inkDim, 0.5)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 2
                    }

                    Repeater {
                        model: LockLayout.list("right")

                        TileEntry {
                            required property var modelData

                            modId: modelData
                            zone: "right"
                            zoneW: mockRightCol.width
                        }
                    }
                }
            }
        }

        // ── the tray: every module, waiting on a chip. Flows onto a second
        // row when the window is narrow.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.max(46, trayFlow.implicitHeight + 16)
            color: Colours.alpha(Colours.surface, 0.75)
            border.width: 1
            border.color: Colours.alpha(Colours.ink, 0.1)
            antialiasing: true

            Flow {
                id: trayFlow

                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                P5Text {
                    width: 96
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    text: "MODULES"
                    color: Colours.alpha(Colours.inkDim, 0.75)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }

                Repeater {
                    // The centre already IS the clock and the profile, so
                    // those two stay out of the tray — everything else is
                    // fair game for the side columns.
                    model: LockModules.all.filter(m => m.id !== "clock" && m.id !== "avatar")

                    ModuleChip {
                        required property var modelData

                        modId: modelData.id
                        placed: LockLayout.has(modelData.id)
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════ the side
    Item {
        anchors.left: stage.right
        anchors.leftMargin: 26
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        P5Text {
            anchors.left: parent.left
            anchors.right: parent.right
            display: root.selected !== ""
            text: root.selected ? LockModules.find(root.selected).name : "ARRANGE THE LOCK"
            color: root.selected ? Colours.ink : Colours.alpha(Colours.inkDim, 0.6)
            font.pixelSize: root.selected ? Appearance.font.size.large : Appearance.font.size.tiny
            tracking: root.selected ? 1 : 3
            elide: Text.ElideRight
        }

        P5Text {
            id: descText

            anchors.top: parent.top
            anchors.topMargin: 30
            anchors.left: parent.left
            anchors.right: parent.right
            wrapMode: Text.WordWrap
            text: {
                if (root.selected === "")
                    return "THE REAL LOCK, SMALL — DRAG A MODULE BY ITS HANDLE ONTO A SIDE TILE, IN ANY ORDER · THE CENTRE IS THE CARD'S FIXED STAGE";
                const it = LockLayout.get(root.selected);
                if (!it)
                    return "";
                switch (it.zone) {
                case "left":
                    return "LEFT TILE  ·  DRAG THE HANDLE TO REORDER OR MOVE";
                case "right":
                    return "RIGHT TILE  ·  DRAG THE HANDLE TO REORDER OR MOVE";
                }
                return "DRAG THE HANDLE TO REORDER OR MOVE";
            }
            color: Colours.alpha(Colours.inkDim, 0.75)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.2
        }

        // ── ENTRANCE — every lock choreography, played live on the card
        Column {
            id: entranceCol

            anchors.top: removeCol.visible ? removeCol.bottom : descText.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            P5Text {
                text: "ENTRANCE  ·  PICK ONE — THE CARD REPLAYS IT"
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 3
            }

            Grid {
                width: parent.width
                columns: 4
                spacing: 6

                EntranceChip {
                    value: "morph"
                    label: "MORPH"
                    width: (parent.width - 18) / 4
                }
                EntranceChip {
                    value: "zoom"
                    label: "ZOOM"
                    width: (parent.width - 18) / 4
                }
                EntranceChip {
                    value: "drop"
                    label: "DROP"
                    width: (parent.width - 18) / 4
                }
                EntranceChip {
                    value: "fade"
                    label: "FADE"
                    width: (parent.width - 18) / 4
                }
                EntranceChip {
                    value: "flip"
                    label: "FLIP"
                    width: (parent.width - 18) / 4
                }
                EntranceChip {
                    value: "vortex"
                    label: "VORTEX"
                    width: (parent.width - 18) / 4
                }
                EntranceChip {
                    value: "glitch"
                    label: "GLITCH"
                    width: (parent.width - 18) / 4
                }
                EntranceChip {
                    value: "shutter"
                    label: "SHUTTER"
                    width: (parent.width - 18) / 4
                }
            }

            P5Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "EVERY STYLE PLAYS ITS OWN EXIT ON UNLOCK — FLIP SWINGS SHUT, VORTEX SPIRALS AWAY, GLITCH TEARS OUT"
                color: Colours.alpha(Colours.accentInk, 0.8)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }
        }

        // ── BACKGROUND SHAPE — the stage behind the card, scrollable on
        // the stage itself too
        Column {
            id: shapeCol

            // The sections stack below each other — no fixed offsets, so
            // nothing overlaps whatever state the editor is in.
            anchors.top: entranceCol.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8

            P5Text {
                text: "BACKGROUND SHAPE  ·  SCROLL ON THE STAGE SWAPS IT TOO"
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 3
            }

            Grid {
                width: parent.width
                columns: 5
                spacing: 6

                GlyphChip {
                    kind: -1
                    value: "off"
                    width: (parent.width - 24) / 5
                }
                GlyphChip {
                    kind: 0
                    value: "circle"
                    width: (parent.width - 24) / 5
                }
                GlyphChip {
                    kind: 1
                    value: "arrow"
                    width: (parent.width - 24) / 5
                }
                GlyphChip {
                    kind: 2
                    value: "pill"
                    width: (parent.width - 24) / 5
                }
                GlyphChip {
                    kind: 3
                    value: "burst"
                    width: (parent.width - 24) / 5
                }
                GlyphChip {
                    kind: 4
                    value: "diamond"
                    width: (parent.width - 24) / 5
                }
                GlyphChip {
                    kind: 5
                    value: "clam"
                    width: (parent.width - 24) / 5
                }
                GlyphChip {
                    kind: 6
                    value: "pentagon"
                    width: (parent.width - 24) / 5
                }
            }

            P5Text {
                text: "SHAPE SIZE"
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 3
            }

            SlashSlider {
                width: parent.width
                value: (Config.lock.shapeSize - 0.5) / 0.8
                onReleased: v => {
                    Config.set("lock.shapeSize", 0.5 + v * 0.8);
                    Config.save();
                }
            }

            SideButton {
                width: parent.width
                label: `CYCLES ON SCROLL — ${Config.lock.shapeCycle ? "ON" : "OFF"}`
                glyph: "autorenew"
                onClicked: {
                    Config.toggle("lock.shapeCycle");
                    Config.save();
                }
            }

            SideButton {
                width: parent.width
                label: `TILE CARDS — ${Config.lock.tileCards ? "ON" : "OFF"}`
                glyph: "dashboard_customize"
                onClicked: {
                    Config.toggle("lock.tileCards");
                    Config.save();
                }
            }
        }

        Column {
            id: nudgeCol

            anchors.top: descText.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8
            visible: root.selected !== "" && LockLayout.get(root.selected) !== null && LockLayout.get(root.selected).zone !== "islandLeft" && LockLayout.get(root.selected).zone !== "islandRight"

            P5Text {
                text: "NUDGE  ·  UP/DOWN REORDERS  ·  LEFT/RIGHT MOVES TILES"
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 3
            }

            Grid {
                width: parent.width
                columns: 3
                spacing: 6

                Item {
                    width: (parent.width - 12) / 3
                    height: 30
                }
                SideButton {
                    width: (parent.width - 12) / 3
                    label: ""
                    glyph: "arrow_upward"
                    onClicked: LockLayout.nudge(root.selected, 0, 1)
                }
                Item {
                    width: (parent.width - 12) / 3
                    height: 30
                }
                SideButton {
                    width: (parent.width - 12) / 3
                    label: ""
                    glyph: "arrow_back"
                    onClicked: LockLayout.nudge(root.selected, -1, 0)
                }
                Item {
                    width: (parent.width - 12) / 3
                    height: 30
                }
                SideButton {
                    width: (parent.width - 12) / 3
                    label: ""
                    glyph: "arrow_forward"
                    onClicked: LockLayout.nudge(root.selected, 1, 0)
                }
                Item {
                    width: (parent.width - 12) / 3
                    height: 30
                }
                SideButton {
                    width: (parent.width - 12) / 3
                    label: ""
                    glyph: "arrow_downward"
                    onClicked: LockLayout.nudge(root.selected, 0, -1)
                }
                Item {
                    width: (parent.width - 12) / 3
                    height: 30
                }
            }
        }

        Column {
            id: removeCol

            anchors.top: nudgeCol.visible ? nudgeCol.bottom : descText.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 8
            visible: root.selected !== ""

            SideButton {
                width: parent.width
                label: "REMOVE"
                glyph: "close"
                danger: true
                onClicked: {
                    LockLayout.remove(root.selected);
                    root.selected = "";
                }
            }

            // The layout is live: it is what the next lock will look like.
            P5Text {
                width: parent.width
                text: "THE LOCK RENDERS THIS EXACTLY — CHANGES APPLY ON YOUR NEXT LOCK"
                color: Colours.alpha(Colours.accentInk, 0.8)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
                wrapMode: Text.WordWrap
            }
        }
    }

    // The dragged module's ghost.
    Item {
        visible: root.dragId !== ""
        x: root.ghostX - width / 2
        y: root.ghostY - height / 2
        width: 118
        height: 40
        z: 200
        opacity: 0.95

        Plate {
            anchors.fill: parent
            radius: Appearance.r(14)
            color: Colours.alpha(Colours.surfaceHigh, 0.96)
            border.width: 1
            border.color: Colours.accent
            antialiasing: true
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            ModuleGlyph {
                anchors.verticalCenter: parent.verticalCenter
                width: 15
                height: 15
                modId: root.dragId
                hovered: true
                col: Colours.accent
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: LockModules.find(root.dragId)?.name ?? ""
                color: Colours.ink
                font.pixelSize: Appearance.font.size.tiny
            }
        }
    }

    // ─────────────────────────────────────────────────────────── components
    // One tile entry: a slim drag handle above the REAL module, scaled to
    // fit the editor, with a click-blocker over the module itself.
    component TileEntry: Column {
        id: entry

        required property string modId
        required property string zone
        required property real zoneW

        property bool entry: true

        spacing: 4
        width: entry.zoneW
        height: (24 + hostItem.height) * root.es + 4

        Item {
            id: inner

            width: entry.zoneW
            height: 24 + hostItem.height
            scale: root.es
            transformOrigin: Item.TopLeft

            // The handle: name + glyph, the drag grip.
            Item {
                id: handle

                width: entry.zoneW
                height: 24

                Plate {
                    anchors.fill: parent
                    radius: Appearance.r(8)
                    color: root.selected === entry.modId ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.surfaceHigh, handleArea.containsMouse ? 0.95 : 0.55)
                    border.width: 1
                    border.color: root.selected === entry.modId ? Colours.accent : Colours.alpha(handleArea.containsMouse ? Colours.accent : Colours.ink, 0.35)
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    ModuleGlyph {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 12
                        height: 12
                        modId: entry.modId
                        hovered: handleArea.containsMouse || root.selected === entry.modId
                        col: root.selected === entry.modId ? Colours.on(Colours.accent) : Colours.accent
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: LockModules.find(entry.modId)?.name ?? entry.modId.toUpperCase()
                        color: root.selected === entry.modId ? Colours.on(Colours.accent) : Colours.ink
                        font.pixelSize: Appearance.font.size.tiny
                    }
                }

                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    name: "drag_indicator"
                    color: root.selected === entry.modId ? Colours.on(Colours.accent) : Colours.alpha(Colours.inkDim, 0.6)
                    font.pixelSize: 14
                }

                MouseArea {
                    id: handleArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.OpenHandCursor

                    property bool moved: false
                    property real fromX: 0
                    property real fromY: 0

                    onPressed: event => {
                        handleArea.moved = false;
                        handleArea.fromX = event.x;
                        handleArea.fromY = event.y;
                        root.selected = entry.modId;
                    }

                    onPositionChanged: event => {
                        if (!pressed)
                            return;
                        if (!handleArea.moved) {
                            if (Math.abs(event.x - handleArea.fromX) + Math.abs(event.y - handleArea.fromY) < 8)
                                return;
                            handleArea.moved = true;
                            root.dragId = entry.modId;
                        }
                        const g = handleArea.mapToItem(root, event.x, event.y);
                        root.ghostX = g.x;
                        root.ghostY = g.y;
                    }

                    onReleased: {
                        if (handleArea.moved) {
                            handleArea.moved = false;
                            root.drop();
                            return;
                        }
                        Sfx.select();
                    }
                }
            }

            // The real module, exactly like the lock — clicks blocked so
            // the editor stays an editor.
            Item {
                id: hostItem

                y: 28
                width: entry.zoneW
                height: realHost.implicitHeight

                ModuleHost {
                    id: realHost

                    wid: entry.modId
                    host: root
                    maxWidth: entry.zoneW
                    fillWidth: true
                    carded: Config.lock.tileCards
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onWheel: we => we.accepted = true
                }
            }
        }
    }

    // One pill entry: a tiny drag grip beside the real compact module.
    component ModuleChip: Item {
        id: chip

        required property string modId
        property bool placed: false

        width: 96
        height: 30

        readonly property bool isSelected: root.selected === chip.modId

        scale: chipArea.pressed ? 0.95 : (chipArea.containsMouse ? 1.04 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }
        }

        Plate {
            anchors.fill: parent
            radius: Appearance.r(10)
            color: chip.isSelected ? Colours.alpha(Colours.accent, 0.9) : (chip.placed ? Colours.alpha(Colours.accent, chipArea.containsMouse ? 0.28 : 0.16) : Colours.alpha(Colours.ink, chipArea.containsMouse ? 0.16 : 0.08))
            border.width: 1
            border.color: chip.isSelected || chip.placed ? Colours.alpha(Colours.accent, 0.6) : Colours.alpha(Colours.ink, 0.12)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            ModuleGlyph {
                anchors.verticalCenter: parent.verticalCenter
                width: 13
                height: 13
                modId: chip.modId
                hovered: chipArea.containsMouse || chip.isSelected
                col: chip.isSelected ? Colours.on(Colours.accent) : (chip.placed ? Colours.accent : Colours.inkDim)
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: LockModules.find(chip.modId)?.name ?? chip.modId.toUpperCase()
                color: chip.isSelected ? Colours.on(Colours.accent) : (chip.placed ? Colours.ink : Colours.inkDim)
                font.pixelSize: Appearance.font.size.tiny
                elide: Text.ElideRight
                width: 58
            }
        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            property bool moved: false
            property real fromX: 0
            property real fromY: 0

            onPressed: event => {
                chipArea.moved = false;
                chipArea.fromX = event.x;
                chipArea.fromY = event.y;
                root.selected = chip.modId;
            }

            onPositionChanged: event => {
                if (!pressed)
                    return;
                if (!chipArea.moved) {
                    if (Math.abs(event.x - chipArea.fromX) + Math.abs(event.y - chipArea.fromY) < 8)
                        return;
                    chipArea.moved = true;
                    root.dragId = chip.modId;
                }
                const g = chipArea.mapToItem(root, event.x, event.y);
                root.ghostX = g.x;
                root.ghostY = g.y;
            }

            onReleased: {
                if (chipArea.moved) {
                    chipArea.moved = false;
                    root.drop();
                    return;
                }
                LockLayout.toggle(chip.modId);
                root.selected = LockLayout.has(chip.modId) ? chip.modId : "";
                Sfx.select();
            }
        }
    }

    // One entrance-animation choice — picking it saves the style and
    // replays the card right here.
    component EntranceChip: Item {
        id: echip

        required property string value
        required property string label

        height: 26

        readonly property bool on: Config.lock.animation === echip.value
        readonly property bool hovered: eArea.containsMouse

        scale: eArea.pressed ? 0.95 : (eArea.containsMouse ? 1.05 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }
        }

        Plate {
            anchors.fill: parent
            radius: Appearance.r(8)
            color: echip.on ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, eArea.containsMouse ? 0.14 : 0.07)
            border.width: 1
            border.color: echip.on ? Colours.accent : Colours.alpha(Colours.ink, 0.12)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        P5Text {
            anchors.centerIn: parent
            display: true
            text: echip.label
            color: echip.on ? Colours.on(Colours.accent) : Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny - 1
            tracking: 0.6
        }

        MouseArea {
            id: eArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Config.set("lock.animation", echip.value);
                Config.save();
                Sfx.select();
                root.playEntrance(echip.value);
            }
        }
    }

    // One background-shape choice — a quiet chip with the glyph itself.
    component GlyphChip: Item {
        id: gchip

        required property int kind          // -1 = off
        required property string value

        width: 44
        height: 36

        readonly property bool on: Config.lock.backgroundShape === gchip.value
        readonly property bool hovered: gArea.containsMouse

        scale: gArea.pressed ? 0.94 : (gArea.containsMouse ? 1.05 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }
        }

        Plate {
            anchors.fill: parent
            radius: Appearance.r(10)
            color: gchip.on ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, gArea.containsMouse ? 0.14 : 0.07)
            border.width: 1
            border.color: gchip.on ? Colours.accent : Colours.alpha(Colours.ink, 0.12)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        P5Text {
            anchors.centerIn: parent
            visible: gchip.kind < 0
            display: true
            text: "OFF"
            color: gchip.on ? Colours.on(Colours.accent) : Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
        }

        LockGlyph {
            anchors.centerIn: parent
            width: 18
            height: 18
            visible: gchip.kind >= 0
            kind: gchip.kind
            col: gchip.on ? Colours.on(Colours.accent) : Colours.inkDim
        }

        MouseArea {
            id: gArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Config.set("lock.backgroundShape", gchip.value);
                Config.save();
            }
        }
    }

    component SideButton: Item {
        id: sb

        property string label: ""
        property string glyph: ""
        property bool danger: false

        signal clicked

        height: 30

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: sb.danger ? Colours.alpha(Colours.danger, sbArea.containsMouse ? 0.95 : 0.75) : Colours.alpha(Colours.ink, sbArea.containsMouse ? 0.16 : 0.08)
            antialiasing: true

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
                visible: sb.glyph !== ""
                name: sb.glyph
                color: sb.danger ? Colours.on(Colours.danger) : Colours.inkDim
                font.pixelSize: 14
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: sb.label
                color: sb.danger ? Colours.on(Colours.danger) : Colours.ink
                font.pixelSize: Appearance.font.size.tiny + 1
                tracking: 0.4
            }
        }

        MouseArea {
            id: sbArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sfx.select();
                sb.clicked();
            }
        }
    }
}
