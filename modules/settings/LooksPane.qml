//  VELVET  ·  modules/settings/LooksPane.qml
//  SETTINGS → LOOKS: whole-shell presets as cards. Each card is a little
//  picture of the look on YOUR wallpaper — where its bar sits, the music
//  along its edge, its clock, its pills — with what it changes spelled
//  out underneath. One click puts it on; the band on top takes you back
//  to your own setup, or keeps the look.
//
//  Keyboard: arrows pick a card, Enter puts it on, Backspace goes back.
//  The looks themselves live in services/Presets.qml.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick
import QtQuick.Shapes

FocusScope {
    id: root

    focus: true

    property int selected: 0
    readonly property int cols: root.width > 1500 ? 2 : 1
    readonly property real gap: 26
    readonly property real cardW: (root.width - root.gap * (root.cols - 1)) / root.cols
    readonly property real previewH: Math.round(root.cardW * 0.4)

    // -1 is VELVET itself, the original — a card of its own above the looks.
    function put(i: int): void {
        const look = i < 0 ? Presets.original : Presets.looks[i];
        if (!look)
            return;
        if (Presets.apply(look.id)) {
            Sfx.select();
            Toast.ok(look.original === true ? "BACK TO VELVET — THE ORIGINAL" : `LOOK · ${Presets.nameOf(look)} IS ON — BACK TO YOUR OWN LOOK SITS ON TOP OF THIS PAGE`);
        }
    }

    // The cards as the page shows them: every vibe (WINDOWS once, as the
    // edition chosen last), then the classic looks and yours.
    readonly property var order: {
        const out = [-1];
        const all = Presets.looks;
        for (let i = 0; i < all.length; i++)
            if (all[i].vibe === true && (all[i].family !== "windows" || all[i].id === Presets.winCurrent.id))
                out.push(i);
        for (let i = 0; i < all.length; i++)
            if (all[i].vibe !== true)
                out.push(i);
        return out;
    }

    function stepBy(d: int): void {
        const o = root.order;
        const at = Math.max(0, o.indexOf(root.selected));
        root.selected = o[Math.max(0, Math.min(o.length - 1, at + d))];
        Sfx.cursor();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Down && root.cols === 1) {
            root.stepBy(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up && root.cols === 1) {
            root.stepBy(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.stepBy(root.cols);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.stepBy(-root.cols);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.put(root.selected);
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace && Presets.canUndo) {
            Presets.undo();
            Sfx.back();
            event.accepted = true;
        }
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: body.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body

            width: flick.width
            spacing: 22

            // ── the head: what this is, and the colour switch
            Item {
                width: parent.width
                height: 64

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    P5Text {
                        display: true
                        text: "LOOKS"
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.title
                    }
                    P5Text {
                        text: "ONE CLICK, A WHOLE SHELL · VIBES CHANGE ITS SHAPE, TYPE AND SOUND · EVERY PART STAYS TUNABLE"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.small
                        tracking: 1
                    }
                }

                // Your own setup, as a card of its own.
                BandButton {
                    anchors.right: colourSwitch.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    strong: true
                    text: "SAVE WHAT I HAVE AS A LOOK"
                    onClicked: {
                        const id = Presets.saveCurrent();
                        if (id !== "") {
                            Sfx.select();
                            root.selected = Presets.looks.length - 1;
                            Toast.ok("SAVED — YOUR LOOK IS THE LAST CARD");
                        }
                    }
                }

                Plate {
                    id: colourSwitch

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: colourRow.implicitWidth + 32
                    height: 40
                    radius: Appearance.r(20)
                    color: colourHover.hovered ? Colours.alpha(Colours.ink, 0.1) : Colours.alpha(Colours.ink, 0.05)
                    border.width: 1
                    border.color: Colours.alpha(Colours.ink, 0.12)
                    antialiasing: true

                    Row {
                        id: colourRow

                        anchors.centerIn: parent
                        spacing: 10

                        Plate {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            height: 20
                            radius: Appearance.r(10)
                            color: Presets.withColours ? Colours.accent : Colours.alpha(Colours.ink, 0.18)

                            Plate {
                                x: Presets.withColours ? parent.width - width - 3 : 3
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                radius: Appearance.r(7)
                                color: Presets.withColours ? Colours.on(Colours.accent) : Colours.ink

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 160
                                    }
                                }
                            }
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Presets.withColours ? "USE THE LOOK'S COLOURS" : "KEEP MY WALLPAPER'S COLOURS"
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.small
                            tracking: 1
                        }
                    }

                    HoverHandler {
                        id: colourHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: {
                            Presets.withColours = !Presets.withColours;
                            Presets.persist();
                            Sfx.toggle();
                        }
                    }
                }
            }

            // ── the way back
            Plate {
                width: parent.width
                height: Presets.canUndo ? 64 : 0
                visible: height > 1
                radius: Appearance.r(18)
                color: Colours.alpha(Colours.accent, 0.14)
                border.width: 1
                border.color: Colours.alpha(Colours.accent, 0.4)
                clip: true
                antialiasing: true

                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "auto_awesome"
                        color: Colours.accent
                        font.pixelSize: 22
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const l = Presets.find(Presets.applied);
                            return l ? `WEARING ${Presets.nameOf(l)} · YOUR OWN SETUP IS SAVED` : "YOUR OWN SETUP IS SAVED";
                        }
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.normal
                        tracking: 1
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    BandButton {
                        text: "KEEP THIS LOOK"
                        onClicked: {
                            Presets.keep();
                            Sfx.select();
                        }
                    }
                    BandButton {
                        strong: true
                        text: "BACK TO MY OWN LOOK"
                        onClicked: {
                            Presets.undo();
                            Sfx.back();
                            Toast.ok("BACK TO YOUR OWN LOOK");
                        }
                    }
                }
            }

            // ── VELVET, the original: not a look, the thing the looks dress
            Column {
                width: parent.width
                spacing: 12

                P5Text {
                    display: true
                    text: "VELVET"
                    color: Colours.accent
                    font.pixelSize: Appearance.font.size.large
                    tracking: 3
                }
                P5Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "THE ORIGINAL — NOT A LOOK. EVERYTHING BELOW DRESSES IT; THIS TAKES IT ALL OFF AGAIN. IT HAS THE FULLEST SET OF SETTINGS, AND SO DOES EVERY LOOK (VISUALS → THIS LOOK)"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }
                LookCard {
                    look: Presets.original
                    chosen: root.selected === -1
                    width: Math.min(root.cardW, 640)
                    onPicked: {
                        root.selected = -1;
                        root.forceActiveFocus();
                    }
                    onPut: root.put(-1)
                }
            }

            // ── the vibes: whole new worlds — shape, type, colour, sound
            Column {
                width: parent.width
                spacing: 12

                P5Text {
                    display: true
                    text: "VIBES"
                    color: Colours.accent
                    font.pixelSize: Appearance.font.size.large
                    tracking: 3
                }
                P5Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "NOT A RECOLOUR — A DIFFERENT SHELL. EVERY CARD, CHIP AND PANEL CHANGES ITS SHAPE, OUTLINE, SHADOW, TYPE, MOTION AND SOUND. EACH ONE IS ONLY SETTINGS: TUNE THEM IN VISUALS → VIBE"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }
            }

            Grid {
                columns: root.cols
                columnSpacing: root.gap
                rowSpacing: root.gap

                Repeater {
                    model: Presets.looks

                    VibeCard {
                        required property var modelData
                        required property int index

                        visible: modelData.vibe === true && (modelData.family !== "windows" || modelData.id === Presets.winCurrent.id)
                        look: modelData
                        chosen: root.selected === index
                        width: root.cardW
                        onPicked: {
                            root.selected = index;
                            root.forceActiveFocus();
                        }
                        onPut: root.put(index)
                    }
                }
            }

            // ── the editions of the WINDOWS look
            Column {
                width: parent.width
                spacing: 12

                P5Text {
                    display: true
                    text: "WINDOWS VERSION"
                    color: Colours.accent
                    font.pixelSize: Appearance.font.size.large
                    tracking: 3
                }
                P5Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "ONE LOOK, FIVE WINDOWS. PICK AN EDITION AND THE WHOLE SHELL BECOMES IT — THE SETTINGS WINDOW, THE TASKBAR, THE START BUTTON, THE SOUNDS. YOU CAN SWITCH ANY TIME UNDER VISUALS → VIBE → WINDOWS VERSION"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }
                Row {
                    spacing: root.gap * 0.5

                    Repeater {
                        model: Presets.winLooks

                        WinPick {
                            required property var modelData

                            look: modelData
                            width: (root.width - root.gap * 0.5 * 4) / 5
                            onPut: {
                                if (Presets.apply(modelData.id)) {
                                    Sfx.select();
                                    Toast.ok(`LOOK · ${Presets.nameOf(modelData)} IS ON`);
                                }
                            }
                        }
                    }
                }
            }

            P5Text {
                display: true
                text: "CLASSIC LOOKS"
                color: Colours.accent
                font.pixelSize: Appearance.font.size.large
                tracking: 3
            }

            // ── the cards
            Grid {
                columns: root.cols
                columnSpacing: root.gap
                rowSpacing: root.gap

                Repeater {
                    model: Presets.looks

                    LookCard {
                        required property var modelData
                        required property int index

                        visible: modelData.vibe !== true
                        look: modelData
                        chosen: root.selected === index
                        width: root.cardW
                        onPicked: {
                            root.selected = index;
                            root.forceActiveFocus();
                        }
                        onPut: root.put(index)
                    }
                }
            }

            P5Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "A LOOK ONLY WRITES ORDINARY SETTINGS — THE BAR, THE LOCK, THE TYPE, THE MUSIC ALONG THE EDGE. WIDGETS ON THE DESKTOP STAY WHERE YOU PUT THEM (DESKTOP TAB). FROM A TERMINAL: qs -c velvet ipc call looks apply sakura"
                color: Colours.alpha(Colours.inkDim, 0.8)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
            }
        }

        SmoothScroll {
            view: flick
        }
    }

    // ═══════════════════════════════════════════════════════════ parts
    component BandButton: Rectangle {
        id: bb

        property string text: ""
        property bool strong: false

        signal clicked

        width: bbText.implicitWidth + 32
        height: 38
        radius: Appearance.r(19)
        color: bb.strong ? (bbHover.hovered ? Colours.accentHot : Colours.accent) : (bbHover.hovered ? Colours.alpha(Colours.ink, 0.12) : Colours.alpha(Colours.ink, 0.05))
        border.width: bb.strong ? 0 : 1
        border.color: Colours.alpha(Colours.ink, 0.14)
        scale: bbTap.pressed ? 0.95 : 1
        antialiasing: true

        Behavior on scale {
            NumberAnimation {
                duration: 110
            }
        }

        P5Text {
            id: bbText

            anchors.centerIn: parent
            text: bb.text
            color: bb.strong ? Colours.on(Colours.accent) : Colours.ink
            font.pixelSize: Appearance.font.size.small
            tracking: 1
        }

        HoverHandler {
            id: bbHover

            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: bbTap

            onTapped: bb.clicked()
        }
    }

    component LookCard: Rectangle {
        id: card

        property var look: ({})
        property bool chosen: false

        signal picked
        signal put

        readonly property bool original: card.look.original === true
        readonly property bool on: Config.loaded && Presets.wearing(card.look.id)
        readonly property bool hot: cardHover.hovered
        readonly property color accent: Presets.withColours || card.original ? card.look.accent : Colours.accent
        readonly property color hue: card.accent
        readonly property color tone: Qt.hsla(card.hue.hslHue, Math.min(0.46, card.hue.hslSaturation * 0.42), 0.13, 1)
        readonly property color toneHigh: Qt.hsla(card.hue.hslHue, Math.min(0.42, card.hue.hslSaturation * 0.38), 0.2, 1)

        height: preview.height + info.height + 34
        radius: Appearance.r(26)
        color: card.hot ? Colours.alpha(Colours.surfaceHigh, 0.98) : Colours.alpha(Colours.surfaceHigh, 0.88)
        border.width: card.chosen || card.on ? 2 : 1
        border.color: card.on ? Colours.accent : (card.chosen ? Colours.alpha(Colours.accent, 0.6) : Colours.alpha(Colours.ink, 0.08))
        antialiasing: true
        scale: card.hot ? 1.01 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }

        // ── the picture: the look on your wallpaper, in miniature
        Item {
            id: preview

            x: 12
            y: 12
            width: card.width - 24
            height: card.original ? Math.round(card.width * 0.34) : root.previewH
            clip: true

            Plate {
                anchors.fill: parent
                radius: Appearance.r(18)
                color: Colours.paper
            }

            Image {
                anchors.fill: parent
                source: Config.wallpaper.current !== "" ? "file://" + Config.wallpaper.current : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 640
                opacity: 0.9
            }

            // A lock-only look shows the lock's blur and dim.
            Rectangle {
                anchors.fill: parent
                color: Colours.alpha(card.tone, card.look.lockOnly ? 0.55 : 0.12)
            }

            readonly property real u: preview.height / 400
            readonly property string edge: card.look.barEdge ?? ""
            readonly property real barT: 22 * preview.u

            // The frame round the desktop.
            Shape {
                anchors.fill: parent
                visible: card.look.settings["bar.frame"] === true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: card.tone
                    strokeColor: "transparent"
                    fillRule: ShapePath.OddEvenFill

                    PathRectangle {
                        x: 0
                        y: 0
                        width: preview.width
                        height: preview.height
                    }
                    PathRectangle {
                        x: preview.edge === "left" ? preview.barT : 5 * preview.u
                        y: preview.edge === "top" ? preview.barT : 5 * preview.u
                        width: preview.width - (preview.edge === "left" ? preview.barT : 5 * preview.u) - 5 * preview.u
                        height: preview.height - (preview.edge === "top" ? preview.barT : 5 * preview.u) - 5 * preview.u
                        radius: 16 * preview.u
                    }
                }
            }

            // The music along its edge: bars hanging down, or a soft wave.
            Row {
                visible: card.look.waveStyle === "bars" && card.look.waveEdge === "top"
                x: 0
                y: preview.edge === "top" ? preview.barT : 0
                spacing: 3 * preview.u

                Repeater {
                    model: preview.u > 0.01 ? Math.min(200, Math.max(0, Math.floor(preview.width / (7 * preview.u)))) : 0

                    Rectangle {
                        required property int index

                        width: 4 * preview.u
                        height: (18 + 34 * Math.abs(Math.sin(index * 0.37) * Math.cos(index * 0.11))) * preview.u
                        radius: width / 2
                        color: card.accent
                        opacity: 0.9
                    }
                }
            }

            Shape {
                anchors.fill: parent
                visible: card.look.waveStyle === "wave" && card.look.waveEdge === "top"
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: card.accent
                    strokeColor: "transparent"

                    PathPolyline {
                        path: {
                            const pts = [Qt.point(0, 0)];
                            const w = preview.width;
                            const n = 48;
                            for (let i = 0; i <= n; i++) {
                                const x = w * i / n;
                                pts.push(Qt.point(x, (10 + 9 * Math.sin(i * 0.55) + 6 * Math.sin(i * 1.3)) * preview.u));
                            }
                            pts.push(Qt.point(w, 0));
                            return pts;
                        }
                    }
                }
            }

            // The bar.
            Rectangle {
                visible: preview.edge !== ""
                x: 0
                y: 0
                width: preview.edge === "left" ? preview.barT : preview.width
                height: preview.edge === "left" ? preview.height : preview.barT
                color: card.look.house ? Colours.alpha(Colours.surface, 0.92) : card.tone

                // Its workspaces: pills for the soft looks, the wedge for Velvet.
                Repeater {
                    model: 5

                    Rectangle {
                        required property int index

                        readonly property bool act: index === 1
                        readonly property real len: act ? (card.look.house ? 12 : 22) * preview.u : 8 * preview.u
                        readonly property real along: 34 * preview.u + index * 12 * preview.u + (index > 1 ? 14 * preview.u : 0)

                        x: preview.edge === "left" ? (preview.barT - width) / 2 : along
                        y: preview.edge === "left" ? along : (preview.barT - height) / 2
                        width: preview.edge === "left" ? 8 * preview.u : len
                        height: preview.edge === "left" ? len : 8 * preview.u
                        radius: card.look.house ? 1 : 4 * preview.u
                        rotation: card.look.house && act ? 12 : 0
                        color: act ? card.accent : Colours.alpha("white", 0.5)
                    }
                }
            }

            // The lock's clock or the desktop's: the look's own shape.
            Item {
                id: miniClock

                readonly property real s: preview.height * 0.44
                x: card.look.lockOnly ? (preview.width - width) / 2 : preview.width * 0.2
                y: (preview.height - height) / 2 + (preview.edge === "top" ? preview.barT / 2 : 0)
                width: card.look.clock === "line" ? s * 1.4 : s
                height: s

                M3Shape {
                    anchors.fill: parent
                    visible: ["none", "line"].indexOf(card.look.clock) < 0
                    kind: card.look.clock
                    color: card.tone
                    intro: false
                }

                Column {
                    anchors.centerIn: parent
                    spacing: -miniClock.s * 0.06

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: card.look.clock !== "line"
                        text: "07"
                        color: card.accent
                        font.family: card.look.house ? Appearance.fontFamily.display : Appearance.fontFamily.soft
                        font.pixelSize: miniClock.s * (card.look.clock === "none" ? 0.46 : 0.3)
                        font.weight: Font.DemiBold
                        font.italic: card.look.house === true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: card.look.clock === "line" ? "19:53" : "28"
                        color: "white"
                        font.family: card.look.house ? Appearance.fontFamily.display : Appearance.fontFamily.soft
                        font.pixelSize: miniClock.s * (card.look.clock === "none" ? 0.46 : (card.look.clock === "line" ? 0.42 : 0.3))
                        font.weight: Font.DemiBold
                        font.italic: card.look.house === true
                    }
                }
            }

            // The round pills — the password with its pencil, the song.
            Column {
                visible: !card.look.house
                x: card.look.lockOnly ? (preview.width - width) / 2 : preview.width * 0.6
                y: card.look.lockOnly ? miniClock.y + miniClock.height + 8 * preview.u : preview.height * 0.46
                spacing: 6 * preview.u

                Row {
                    spacing: 3 * preview.u

                    Rectangle {
                        width: 118 * preview.u
                        height: 26 * preview.u
                        radius: Appearance.pill(height)
                        topRightRadius: 4 * preview.u
                        bottomRightRadius: 4 * preview.u
                        color: card.tone
                    }
                    Rectangle {
                        width: 30 * preview.u
                        height: 26 * preview.u
                        radius: Appearance.pill(height)
                        topLeftRadius: 4 * preview.u
                        bottomLeftRadius: 4 * preview.u
                        color: card.tone

                        Icon {
                            anchors.centerIn: parent
                            name: "edit"
                            color: "white"
                            font.pixelSize: 11 * preview.u
                        }
                    }
                }
                Plate {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 70 * preview.u
                    height: 14 * preview.u
                    radius: Appearance.pill(height)
                    color: card.tone
                }
            }

            // ON — this is what you are wearing.
            Plate {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                visible: card.on
                width: onText.implicitWidth + 24
                height: 28
                radius: Appearance.r(14)
                color: Colours.accent

                P5Text {
                    id: onText

                    anchors.centerIn: parent
                    text: "ON"
                    color: Colours.on(Colours.accent)
                    font.pixelSize: Appearance.font.size.small
                    tracking: 2
                }
            }

            // The rounded window onto the picture.
            Rectangle {
                anchors.fill: parent
                radius: Appearance.r(18)
                color: "transparent"
                border.width: 1
                border.color: Colours.alpha(Colours.ink, 0.1)
            }
        }

        // ── the words
        Item {
            id: info

            x: 24
            y: preview.y + preview.height + 16
            width: card.width - 48
            height: Math.max(words.height, putButton.height)

            Column {
                id: words

                width: info.width - putButton.width - (dropButton.visible ? dropButton.width + 10 : 0) - 20
                spacing: 6

                Row {
                    spacing: 12

                    LookName {
                        anchors.verticalCenter: parent.verticalCenter
                        look: card.look
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (card.look.by ?? "").toUpperCase()
                        color: card.accent
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.5
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: card.look.blurb
                    color: Colours.inkDim
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: Appearance.font.size.small
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: card.look.parts ?? []

                        Plate {
                            required property string modelData

                            width: partText.implicitWidth + 18
                            height: 24
                            radius: Appearance.r(12)
                            color: Colours.alpha(Colours.ink, 0.06)
                            border.width: 1
                            border.color: Colours.alpha(Colours.ink, 0.1)

                            P5Text {
                                id: partText

                                anchors.centerIn: parent
                                text: modelData
                                color: Colours.alpha(Colours.ink, 0.8)
                                font.pixelSize: Appearance.font.size.tiny
                                tracking: 1
                            }
                        }
                    }
                }
            }

            // A look of your own can go again.
            Plate {
                id: dropButton

                anchors.right: putButton.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: card.look.custom === true
                width: 46
                height: 46
                radius: Appearance.r(23)
                color: dropHover.hovered ? Colours.alpha(Colours.danger, 0.25) : Colours.alpha(Colours.ink, 0.06)
                border.width: 1
                border.color: Colours.alpha(Colours.ink, 0.12)
                antialiasing: true

                Icon {
                    anchors.centerIn: parent
                    name: "delete"
                    color: dropHover.hovered ? Colours.danger : Colours.inkDim
                    font.pixelSize: 20
                }

                HoverHandler {
                    id: dropHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        Presets.removeCustom(card.look.id);
                        Sfx.back();
                        root.selected = Math.max(0, Math.min(root.selected, Presets.looks.length - 1));
                    }
                }
            }

            Plate {
                id: putButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: putText.implicitWidth + 40
                height: 46
                radius: Appearance.r(23)
                color: card.on ? (putHover.hovered ? Colours.alpha(Colours.accent, 0.3) : Colours.alpha(Colours.accent, 0.16)) : (putHover.hovered ? Colours.accentHot : Colours.accent)
                scale: putTap.pressed ? 0.94 : 1
                antialiasing: true

                Behavior on scale {
                    NumberAnimation {
                        duration: 110
                    }
                }

                P5Text {
                    id: putText

                    anchors.centerIn: parent
                    text: card.on ? "TUNE THIS LOOK" : (card.original ? "BACK TO VELVET" : "PUT IT ON")
                    color: card.on ? Colours.accent : Colours.on(Colours.accent)
                    font.pixelSize: Appearance.font.size.normal
                    tracking: 1
                }

                HoverHandler {
                    id: putHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    id: putTap

                    onTapped: {
                        card.picked();
                        if (card.on)
                            Panels.openSettingsTabNamed("THIS LOOK");
                        else
                            card.put();
                    }
                }
            }
        }

        HoverHandler {
            id: cardHover
        }
        TapHandler {
            onTapped: card.picked()
            onDoubleTapped: card.put()
        }
    }

    // A little picture of one Windows edition: a desktop, a window, a taskbar
    // with its Start button.
    component WinMini: Item {
        id: wm

        property string v: "11"

        readonly property real u: Math.max(0.6, wm.width / 280)
        readonly property var sw: Presets.winSpecs[wm.v]?.swatch ?? ({})

        // the desktop
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: ({ "95": "#008080", "xp": "#4f86d6", "7": "#1b4f8c", "10": "#10294a", "11": "#c9d9f2" })[wm.v] ?? "#333"
                }
                GradientStop {
                    position: 1
                    color: ({ "95": "#008080", "xp": "#74b04a", "7": "#2a74c0", "10": "#1b5a9a", "11": "#e9d9ee" })[wm.v] ?? "#222"
                }
            }
        }

        // the window
        Item {
            x: wm.width * 0.12
            y: wm.height * 0.12
            width: wm.width * 0.76
            height: wm.height * 0.64

            Rectangle {
                anchors.fill: parent
                radius: wm.v === "11" ? 8 * wm.u : (wm.v === "xp" ? 6 * wm.u : (wm.v === "7" ? 5 * wm.u : 0))
                color: ({ "95": "#c0c0c0", "xp": "#0831d9", "7": "#6fa3d8", "10": "#1f1f1f", "11": "#f3f3f3" })[wm.v]
                border.width: wm.v === "95" ? 2 : 1
                border.color: ({ "95": "#ffffff", "xp": "#0831d9", "7": "#2b4a78", "10": "#0078d7", "11": "#d6d6d6" })[wm.v]
            }
            // title bar
            Rectangle {
                x: 2 * wm.u
                y: 2 * wm.u
                width: parent.width - 4 * wm.u
                height: (wm.v === "xp" ? 14 : (wm.v === "11" || wm.v === "10" ? 10 : 11)) * wm.u
                radius: wm.v === "xp" ? 4 * wm.u : (wm.v === "11" ? 6 * wm.u : 0)
                visible: wm.v !== "7"

                gradient: Gradient {
                    orientation: wm.v === "95" ? Gradient.Horizontal : Gradient.Vertical

                    GradientStop {
                        position: 0
                        color: ({ "95": "#000080", "xp": "#2f86ff", "10": "#1f1f1f", "11": "#f3f3f3" })[wm.v] ?? "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: ({ "95": "#1084d0", "xp": "#0a5de6", "10": "#1f1f1f", "11": "#f3f3f3" })[wm.v] ?? "transparent"
                    }
                }
            }
            // the body
            Rectangle {
                x: 3 * wm.u
                y: (wm.v === "7" ? 14 : (wm.v === "xp" ? 17 : 13)) * wm.u
                width: parent.width - 6 * wm.u
                height: parent.height - y - 3 * wm.u
                radius: wm.v === "11" ? 4 * wm.u : 0
                color: ({ "95": "#ffffff", "xp": "#ece9d8", "7": "#ffffff", "10": "#2b2b2b", "11": "#ffffff" })[wm.v]

                // the navigation and a few rows
                Rectangle {
                    width: parent.width * 0.28
                    height: parent.height
                    color: ({ "95": "#ffffff", "xp": "#6e8fe0", "7": "#e9f0fa", "10": "#262626", "11": "#f3f3f3" })[wm.v]
                }
                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        x: parent.width * 0.33
                        y: (5 + index * 9) * wm.u
                        width: parent.width * (index === 0 ? 0.5 : 0.6)
                        height: 4 * wm.u
                        radius: wm.v === "11" ? 2 * wm.u : 0
                        color: index === 0 ? wm.sw.accent : Qt.rgba(0.5, 0.5, 0.5, 0.45)
                    }
                }
            }
        }

        // the taskbar
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 14 * wm.u
            color: ({ "95": "#c0c0c0", "xp": "#245edb", "7": "#16253c", "10": "#101010", "11": "#eef1f7" })[wm.v]
            opacity: wm.v === "7" ? 0.9 : 1

            Rectangle {
                x: wm.v === "11" ? parent.width / 2 - 6 * wm.u : 2 * wm.u
                anchors.verticalCenter: parent.verticalCenter
                width: ({ "95": 26, "xp": 34, "7": 11, "10": 10, "11": 11 })[wm.v] * wm.u
                height: ({ "95": 10, "xp": 11, "7": 11, "10": 10, "11": 11 })[wm.v] * wm.u
                radius: wm.v === "xp" ? 5 * wm.u : (wm.v === "7" ? 6 * wm.u : (wm.v === "11" ? 2 * wm.u : 0))
                color: ({ "95": "#dcdcdc", "xp": "#3c9a2f", "7": "#3a8ee6", "10": "#e0e0e0", "11": "#0067c0" })[wm.v]
                border.width: wm.v === "95" ? 1 : 0
                border.color: "#808080"
            }
        }
    }

    // One of the five editions, as a card in the strip under the vibes.
    component WinPick: Item {
        id: wp

        property var look: ({})

        signal put

        readonly property bool on: Config.loaded && Presets.wearing(wp.look.id)
        readonly property bool mine: Config.appearance.winVersion === wp.look.version
        readonly property bool hot: wpHover.hovered

        height: 140
        scale: wp.hot ? 1.02 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }

        Slash {
            anchors.fill: parent
            color: wp.hot ? Colours.alpha(Colours.surfaceHigh, 0.98) : Colours.alpha(Colours.surfaceHigh, 0.88)
            borderColor: wp.on ? Colours.accent : (wp.mine ? Colours.alpha(Colours.accent, 0.6) : Colours.alpha(Colours.ink, 0.1))
            borderWidth: wp.on || wp.mine ? 2 : 1
        }
        Item {
            x: 8
            y: 8
            width: parent.width - 16
            height: parent.height - 46
            clip: true

            WinMini {
                anchors.fill: parent
                v: wp.look.version ?? "11"
            }
        }
        P5Text {
            x: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            text: String(wp.look.name ?? "").replace("WINDOWS ", "")
            color: Colours.ink
            display: true
            font.pixelSize: Appearance.font.size.large
        }
        P5Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            text: wp.on ? "ON" : (wp.mine ? "LAST USED" : "")
            color: Colours.accent
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.5
        }
        HoverHandler {
            id: wpHover

            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: wp.put()
        }
    }

    // One vibe, drawn IN ITSELF: its own ground, pattern, shape, outline,
    // shadow and typeface — the card is the best description of the look.
    component VibeCard: Item {
        id: vc

        property var look: ({})
        property bool chosen: false

        signal picked
        signal put

        readonly property bool on: Config.loaded && Presets.wearing(vc.look.id)
        readonly property bool hot: vcHover.hovered
        readonly property var sw: vc.look.swatch ?? ({})
        readonly property string mood: vc.look.mood ?? "persona"
        readonly property color accent: Presets.withColours ? (vc.sw.accent ?? vc.look.accent) : Colours.accent
        readonly property color paperC: Presets.withColours ? (vc.sw.paper ?? "#111") : Colours.paper
        readonly property color surfaceC: Presets.withColours ? (vc.sw.surface ?? "#222") : Colours.surface
        readonly property color inkC: Presets.withColours ? (vc.sw.ink ?? "#fff") : Colours.ink
        readonly property color edgeC: Presets.withColours ? (vc.look.edgeHex ?? vc.inkC) : Colours.edge
        readonly property real u: Math.max(0.7, vc.width / 700)
        readonly property real shadowPx: (vc.look.shadowSize ?? 0) * vc.u * 0.7

        height: previewBox.height + vinfo.height + 34
        scale: vc.hot ? 1.012 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        // the frame this card sits in, in the CURRENT shell's own style
        Slash {
            anchors.fill: parent
            color: vc.hot ? Colours.alpha(Colours.surfaceHigh, 0.98) : Colours.alpha(Colours.surfaceHigh, 0.88)
            borderColor: vc.on ? Colours.accent : (vc.chosen ? Colours.alpha(Colours.accent, 0.7) : Colours.alpha(Colours.ink, 0.1))
            borderWidth: vc.chosen || vc.on ? 2 : 1
        }

        // ── the picture
        Item {
            id: previewBox

            x: 14
            y: 14
            width: vc.width - 28
            height: root.previewH
            clip: true

            Rectangle {
                anchors.fill: parent
                color: vc.paperC
            }

            // the Windows look is drawn as the edition it wears
            WinMini {
                anchors.fill: parent
                visible: vc.look.family === "windows"
                v: vc.look.version ?? "11"
                z: 5
            }

            Backdrop {
                anchors.fill: parent
                kind: vc.look.backdrop ?? "plain"
                colour: vc.inkC
                step: 38 * vc.u
            }

            Scanlines {
                anchors.fill: parent
                z: 30
                strength: vc.look.scanlines ?? 0
            }

            // the bar, on the edge this vibe puts it
            Slash {
                readonly property string edge: vc.look.barEdge ?? "top"
                readonly property bool vert: edge === "left" || edge === "right"

                x: edge === "right" ? previewBox.width - width - 10 * vc.u : 10 * vc.u
                y: edge === "bottom" ? previewBox.height - height - 10 * vc.u : 10 * vc.u
                width: vert ? 26 * vc.u : previewBox.width - 20 * vc.u
                height: vert ? previewBox.height - 20 * vc.u : 26 * vc.u
                shear: 0
                shape: vc.look.shape ?? "square"
                outlineWidth: (vc.look.outline ?? 0) * 0.7
                outlineColour: vc.edgeC
                shadowKind: vc.look.shadow ?? "none"
                shadowSize: vc.shadowPx * 0.6
                color: vc.surfaceC
                borderColor: "transparent"

                Row {
                    visible: !parent.vert
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10 * vc.u
                    spacing: 6 * vc.u

                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index

                            width: (index === 0 ? 18 : 9) * vc.u
                            height: 9 * vc.u
                            color: index === 0 ? vc.accent : Qt.rgba(vc.inkC.r, vc.inkC.g, vc.inkC.b, 0.45)
                        }
                    }
                }

                Column {
                    visible: parent.vert
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 10 * vc.u
                    spacing: 6 * vc.u

                    Repeater {
                        model: 4

                        Rectangle {
                            required property int index

                            width: 9 * vc.u
                            height: (index === 0 ? 18 : 9) * vc.u
                            color: index === 0 ? vc.accent : Qt.rgba(vc.inkC.r, vc.inkC.g, vc.inkC.b, 0.45)
                        }
                    }
                }
            }

            // a card with a title, a bar and two chips
            Slash {
                x: previewBox.width * (vc.look.barEdge === "left" ? 0.2 : 0.1)
                y: previewBox.height * 0.3
                width: previewBox.width * 0.52
                height: previewBox.height * 0.46
                shear: 0
                shape: vc.look.shape ?? "square"
                outlineWidth: vc.look.outline ?? 0
                outlineColour: vc.edgeC
                shadowKind: vc.look.shadow ?? "none"
                shadowSize: vc.shadowPx
                color: vc.surfaceC
                borderColor: Qt.rgba(vc.accent.r, vc.accent.g, vc.accent.b, 0.35)
                borderWidth: 1

                Text {
                    x: 14 * vc.u
                    y: 10 * vc.u
                    text: (vc.look.caps === "lower" || vc.look.id === "terminal") ? "system ready" : "SYSTEM READY"
                    color: vc.accent
                    font.family: Appearance.familyOf(vc.mood, true)
                    font.pixelSize: 15 * vc.u * (vc.mood === "arcade" ? 0.85 : 1)
                    font.weight: vc.mood === "arcade" ? Font.Normal : Font.Black
                    font.letterSpacing: vc.mood === "tech" ? 3 : 1
                }
                Text {
                    x: 14 * vc.u
                    y: 34 * vc.u
                    text: vc.look.id === "terminal" ? "volume 62%  ·  wifi ok" : "VOLUME 62%  ·  WIFI OK"
                    color: vc.inkC
                    font.family: Appearance.familyOf(vc.mood, false)
                    font.pixelSize: 10 * vc.u
                    font.letterSpacing: 0.6
                }

                Rectangle {
                    x: 14 * vc.u
                    y: parent.height - 30 * vc.u
                    width: parent.width - 28 * vc.u
                    height: 6 * vc.u
                    color: Qt.rgba(vc.inkC.r, vc.inkC.g, vc.inkC.b, 0.18)

                    Rectangle {
                        width: parent.width * 0.62
                        height: parent.height
                        color: vc.accent
                    }
                }
            }

            Repeater {
                model: 2

                Slash {
                    required property int index

                    x: previewBox.width * 0.66
                    y: previewBox.height * (0.36 + index * 0.2)
                    width: previewBox.width * 0.24
                    height: previewBox.height * 0.14
                    shear: 0
                    shape: vc.look.shape ?? "square"
                    outlineWidth: vc.look.outline ?? 0
                    outlineColour: vc.edgeC
                    shadowKind: vc.look.shadow ?? "none"
                    shadowSize: vc.shadowPx * 0.8
                    color: index === 0 ? vc.accent : vc.surfaceC
                    borderColor: "transparent"
                }
            }

            // ON — this is what you are wearing.
            Slash {
                visible: vc.on
                z: 10
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                width: vcOnText.implicitWidth + 24
                height: 28
                color: Colours.accent

                P5Text {
                    id: vcOnText

                    anchors.centerIn: parent
                    text: "ON"
                    color: Colours.on(Colours.accent)
                    font.pixelSize: Appearance.font.size.small
                    tracking: 2
                }
            }
        }

        // ── the words
        Item {
            id: vinfo

            x: 26
            y: previewBox.y + previewBox.height + 16
            width: vc.width - 52
            height: Math.max(vwords.height, vcPut.height)

            Column {
                id: vwords

                width: vinfo.width - vcPut.width - 20
                spacing: 6

                Row {
                    spacing: 12

                    LookName {
                        anchors.verticalCenter: parent.verticalCenter
                        look: vc.look
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (vc.look.by ?? "").toUpperCase()
                        color: vc.accent
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.5
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: vc.look.blurb
                    color: Colours.inkDim
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: Appearance.font.size.small
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: vc.look.parts ?? []

                        Slash {
                            required property string modelData

                            width: vcPart.implicitWidth + 18
                            height: 24
                            color: Colours.alpha(Colours.ink, 0.06)
                            borderColor: Colours.alpha(Colours.ink, 0.12)
                            borderWidth: 1
                            flat: true

                            P5Text {
                                id: vcPart

                                anchors.centerIn: parent
                                text: modelData
                                color: Colours.alpha(Colours.ink, 0.8)
                                font.pixelSize: Appearance.font.size.tiny
                                tracking: 1
                            }
                        }
                    }
                }
            }

            Slash {
                id: vcPut

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: vcPutText.implicitWidth + 40
                height: 46
                color: vc.on ? (vcPutHover.hovered ? Colours.alpha(Colours.accent, 0.3) : Colours.alpha(Colours.accent, 0.16)) : (vcPutHover.hovered ? Colours.accentHot : Colours.accent)
                scale: vcPutTap.pressed ? 0.94 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 110
                    }
                }

                P5Text {
                    id: vcPutText

                    anchors.centerIn: parent
                    text: vc.on ? "TUNE THIS LOOK" : "PUT IT ON"
                    color: vc.on ? Colours.accent : Colours.on(Colours.accent)
                    font.pixelSize: Appearance.font.size.normal
                    tracking: 1
                }

                HoverHandler {
                    id: vcPutHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    id: vcPutTap

                    onTapped: {
                        vc.picked();
                        if (vc.on)
                            Panels.openSettingsTabNamed("THIS LOOK");
                        else
                            vc.put();
                    }
                }
            }
        }

        HoverHandler {
            id: vcHover
        }
        TapHandler {
            onTapped: vc.picked()
            onDoubleTapped: vc.put()
        }
    }
}
