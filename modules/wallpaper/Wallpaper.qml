//  VELVET  ·  modules/wallpaper/Wallpaper.qml
//  The shell paints the wallpaper itself, on a background layer under
//  everything. No swww, no hyprpaper, nothing to autostart — and because it
//  binds straight to the stored path, it is simply there again after a reboot.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool builtin: Config.wallpaper.renderer === "builtin"
    // The living desktop: widgets + living light on the wallpaper itself.
    // Everything below hangs off this one switch.
    readonly property bool living: root.builtin && Config.wallpaper.living
    readonly property string target: Config.wallpaper.current
    readonly property int fill: {
        switch (Config.wallpaper.fillMode) {
        case "fit":
            return Image.PreserveAspectFit;
        case "stretch":
            return Image.Stretch;
        default:
            return Image.PreserveAspectCrop;
        }
    }

    screen: modelData
    visible: root.builtin
    color: Colours.paper

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "velvet-wallpaper"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // -1 makes the surface ignore everyone else's exclusive zones, so the
    // image covers the whole output rather than the leftovers.
    exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // The wallpaper itself never eats a click — only its widgets do. The
    // base is a zero-sized Item, never null: a null region means "the whole
    // window", which on a background layer means every click on bare
    // desktop lands here instead of reaching whatever is underneath. On top
    // of it, one rectangle per widget, exactly where the widget is drawn —
    // so hovering one lights it up and clicking it does something, while a
    // pixel beside it is still bare desktop.
    //
    // The one exception is the desktop's right-click menu: while it is on,
    // the whole surface takes the pointer so a right-click on bare desktop
    // reaches `menuArea` below. Nothing sits under a background layer, so
    // no click is stolen from anything — and the switch is in
    // WALLPAPER CHANGER → DESKTOP RIGHT-CLICK MENU.
    readonly property bool menuOn: root.builtin && Config.wallpaper.deskMenu && !Locker.locked

    mask: Region {
        item: root.menuOn ? ground : deadZone
        regions: hitRegions.instances
    }

    Variants {
        id: hitRegions

        model: slotsBox.children

        Region {
            required property var modelData

            readonly property bool live: widgetLayer.visible && !Locker.locked && (modelData?.hitW ?? 0) > 0 && (modelData?.takesPointer ?? false)

            x: live ? Math.floor(modelData.hitX) : 0
            y: live ? Math.floor(modelData.hitY) : 0
            width: live ? Math.ceil(modelData.hitW) : 0
            height: live ? Math.ceil(modelData.hitH) : 0
        }
    }

    Item {
        id: deadZone

        width: 0
        height: 0
    }

    Item {
        id: ground

        anchors.fill: parent

        // ---------------------------------------------------------- crossfade
        // `back` holds what was there; `front` fades in over it once it has
        // actually decoded, so a slow image never flashes the bare colour.
        //
        // Both decode at SCREEN size, never at the file's own: a 6000px
        // wallpaper decoded full-res is ~80 MB per copy plus its mipmap
        // pyramid, in system RAM (an APU shares it with the GPU). On a
        // machine without swap that is a freeze waiting to happen. The
        // screen cannot show more than this anyway.
        Image {
            id: back

            anchors.fill: parent
            scale: root.kbScale
            fillMode: root.fill
            cache: false
            asynchronous: true
            smooth: true
            mipmap: true
            sourceSize.width: Math.max(64, Math.round(root.width * 1.1))
            sourceSize.height: Math.max(64, Math.round(root.height * 1.1))
            visible: source !== ""
        }

        // The incoming picture lives in a wrapper, so the cinematic
        // dissolve can zoom it from 1.07 down to 1 without fighting the
        // Ken Burns drift, which owns the image's own scale.
        Item {
            id: frontWrap

            anchors.fill: parent
            scale: 1

            Image {
                id: front

                anchors.fill: parent
                scale: root.kbScale
                fillMode: root.fill
                cache: false
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize.width: Math.max(64, Math.round(root.width * 1.1))
                sourceSize.height: Math.max(64, Math.round(root.height * 1.1))
                opacity: 0
                visible: source !== ""

                onStatusChanged: {
                    if (status === Image.Ready) {
                        fade.restart();
                        zoomIn.restart();
                    } else if (status === Image.Error) {
                        opacity = 1;   // show whatever we have rather than a black screen
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════ the living light — aurora
    //  A slow drift of accent light behind everything: two huge soft blobs
    //  in the accent colours, moving on minute-long curves at a whisper of
    //  opacity. Off by default — WALLPAPER → LIVING DESKTOP → AURORA.
    //  Paused while locked: the lock covers the screen, so no repaints
    //  are spent on light nobody can see.
    Item {
        id: aurora

        anchors.fill: parent
        visible: root.living && Config.wallpaper.livingAurora && !Locker.locked

        // The drift is stepped four times a second (it moves a few pixels a
        // second at most) instead of four infinite animations repainting the
        // whole screen every frame. It rests under Velvet's own overlays.
        property real t: 0
        function wave(a: real, b: real, period: real): real {
            return a + (b - a) * (1 - Math.cos(2 * Math.PI * aurora.t / period)) / 2;
        }

        Timer {
            interval: 250
            repeat: true
            running: aurora.visible && !(Panels.wheel || Panels.windowMap)
            onTriggered: aurora.t = (aurora.t + 0.25) % 44928   // common period of all four curves: no jump on wrap
        }

        Shape {
            id: blobA

            x: aurora.wave(-aurora.width * 0.2, aurora.width * 0.35, 144)
            y: aurora.wave(-aurora.height * 0.25, aurora.height * 0.12, 108)
            width: parent.width * 0.95
            height: parent.height * 0.95

            ShapePath {
                startX: 0
                startY: 0
                strokeColor: "transparent"
                strokeWidth: 0
                PathLine { x: blobA.width; y: 0 }
                PathLine { x: blobA.width; y: blobA.height }
                PathLine { x: 0; y: blobA.height }
                PathLine { x: 0; y: 0 }
                fillGradient: RadialGradient {
                    centerX: blobA.width / 2
                    centerY: blobA.height / 2
                    focalX: blobA.width / 2
                    focalY: blobA.height / 2
                    centerRadius: Math.max(220, Math.min(blobA.width, blobA.height) * 0.38)
                    focalRadius: 0
                    GradientStop { position: 0.0; color: Colours.alpha(Colours.accent, 0.16) }
                    GradientStop { position: 0.6; color: Colours.alpha(Colours.accent, 0.07) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        Shape {
            id: blobB

            x: aurora.wave(aurora.width * 0.45, aurora.width * 0.15, 128)
            y: aurora.wave(aurora.height * 0.5, aurora.height * 0.25, 156)
            width: parent.width * 0.8
            height: parent.height * 0.8

            ShapePath {
                startX: 0
                startY: 0
                strokeColor: "transparent"
                strokeWidth: 0
                PathLine { x: blobB.width; y: 0 }
                PathLine { x: blobB.width; y: blobB.height }
                PathLine { x: 0; y: blobB.height }
                PathLine { x: 0; y: 0 }
                fillGradient: RadialGradient {
                    centerX: blobB.width / 2
                    centerY: blobB.height / 2
                    focalX: blobB.width / 2
                    focalY: blobB.height / 2
                    centerRadius: Math.max(200, Math.min(blobB.width, blobB.height) * 0.34)
                    focalRadius: 0
                    GradientStop { position: 0.0; color: Colours.alpha(Colours.accentAlt, 0.15) }
                    GradientStop { position: 0.6; color: Colours.alpha(Colours.accentAlt, 0.06) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // ══════════════════════════════════════════ the living light — day & night
    //  The picture itself knows what time it is: warm at sunset, cool and
    //  deep after midnight, clean through the day. One overlay, gliding on
    //  a slow colour fade so the change never snaps. WALLPAPER → LIVING.
    SystemClock {
        id: tclock

        precision: SystemClock.Minutes
    }

    Rectangle {
        id: timeVeil

        anchors.fill: parent
        color: "transparent"

        Behavior on color {
            ColorAnimation { duration: 4200 }
        }

        function refresh(): void {
            if (!root.living || !Config.wallpaper.livingTimeTint) {
                timeVeil.color = "transparent";
                return;
            }
            const h = tclock.date.getHours() + tclock.date.getMinutes() / 60;
            let c = Qt.rgba(0.30, 0.38, 0.85);
            let a = 0;
            if (h >= 4.5 && h < 8) {
                // dawn: the night lets go
                const t = (h - 4.5) / 3.5;
                a = 0.10 * (1 - t);
            } else if (h >= 16.5 && h < 20) {
                // dusk: the picture warms up
                const t = (h - 16.5) / 3.5;
                c = Qt.rgba(1.0, 0.50, 0.22);
                a = 0.11 * t;
            } else if (h >= 20 && h < 23) {
                // evening: warmth hands over to the cool of night
                const t = (h - 20) / 3;
                a = 0.10 * t;
            } else if (h >= 23 || h < 4.5) {
                // deep night
                a = 0.10;
            }
            // The weather gets a vote too: rain cools the picture, sun warms
            // it, fog takes the colour out. Same veil, second source — the
            // mood comes from the Weather service so the code tables live in
            // one place. WALLPAPER → LIVING DESKTOP → DAY AND NIGHT.
            if (Config.services.weather && Weather.ready) {
                let wc = null;
                let wa = 0;
                switch (Weather.mood) {
                case "clear":
                    wc = Qt.rgba(1.0, 0.78, 0.42);
                    wa = (h >= 9 && h < 18) ? 0.045 : 0;
                    break;
                case "cloud":
                    wc = Qt.rgba(0.55, 0.58, 0.66);
                    wa = 0.035;
                    break;
                case "fog":
                    wc = Qt.rgba(0.62, 0.66, 0.72);
                    wa = 0.065;
                    break;
                case "rain":
                    wc = Qt.rgba(0.34, 0.44, 0.72);
                    wa = 0.07;
                    break;
                case "thunder":
                    wc = Qt.rgba(0.30, 0.34, 0.60);
                    wa = 0.09;
                    break;
                case "snow":
                    wc = Qt.rgba(0.78, 0.84, 0.95);
                    wa = 0.075;
                    break;
                }
                if (wc !== null && wa > 0) {
                    // Blend, never replace: the hour keeps its ground and the
                    // sky only leans on it.
                    c = Qt.rgba((c.r + wc.r) / 2, (c.g + wc.g) / 2, (c.b + wc.b) / 2);
                    a = Math.min(0.17, a + wa);
                }
            }
            timeVeil.color = Qt.rgba(c.r, c.g, c.b, a);
        }

        Connections {
            target: Config.wallpaper
            function onLivingChanged(): void { timeVeil.refresh(); }
            function onLivingTimeTintChanged(): void { timeVeil.refresh(); }
        }

        // The clock ticks, the veil follows. Without this the tint was
        // computed once at startup and never moved again — the day-and-night
        // cycle only existed for people who restarted their shell at dusk.
        Connections {
            target: tclock
            function onDateChanged(): void { timeVeil.refresh(); }
        }

        // …and the sky changes slower than the hour but still changes.
        Connections {
            target: Weather
            function onMoodChanged(): void { timeVeil.refresh(); }
        }

        Connections {
            target: Config.services
            function onWeatherChanged(): void { timeVeil.refresh(); }
        }

        Component.onCompleted: timeVeil.refresh()
    }

    // The old carousel's signature, folded into the built-in renderer: a soft
    // gradient grounding the picture. Off in WALLPAPER → CINEMATIC SHADE.
    Item {
        anchors.fill: parent
        visible: Config.wallpaper.vignette

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.68; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.42) }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.12) }
                GradientStop { position: 0.12; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // Right-click on a free spot: the desktop menu, at the pointer. Under the
    // widget layer, so a widget answers its own right-click (edit it) first.
    MouseArea {
        id: menuArea

        anchors.fill: parent
        enabled: root.menuOn
        acceptedButtons: Qt.RightButton
        onClicked: mouse => Panels.openDeskMenu(root.modelData.name, mouse.x, mouse.y)
    }

    // ═══════════════════════════════════ the desktop's widget layer
    //  The lock's own modules, parked on the wallpaper exactly where the
    //  live scene puts them. They ride the background layer — always beneath
    //  your windows, never eating a click — and the binding follows the
    //  scene, so switching the wallpaper swaps the widgets with it.
    //
    //  The box you dragged in DESKTOP is the widget's stage: the module
    //  scales to fill it, so pulling the corner resizes the widget itself.
    //  FRAME and OPACITY can be overridden per widget in the DESKTOP
    //  inspector; the global defaults live in WALLPAPER → LIVING DESKTOP.
    //  The layer draws only on the focused screen — the scene's windows
    //  are placed there, so that is where the desk lives.
    Item {
        id: widgetLayer

        anchors.fill: parent
        visible: root.living && Config.wallpaper.livingWidgets && root.modelData?.name === Hypr.focusedScreen?.name

        // A stable model: liveWidgets() is a NEW array on every scene write
        // (any tile moved in DESKTOP), which destroyed every widget and
        // replayed the glide-in. Now the list is swapped only when its
        // content really changed, and the glide replays when the wallpaper
        // (the desk) changes.
        property var list: []
        property string listJson: "[]"
        property string listKey: ""
        property int epoch: 0

        function sync(): void {
            const next = Scenes.liveWidgets();
            const j = JSON.stringify(next);
            if (j !== widgetLayer.listJson) {
                widgetLayer.listJson = j;
                widgetLayer.list = next;
            }
            if (Scenes.key !== widgetLayer.listKey) {
                widgetLayer.listKey = Scenes.key;
                widgetLayer.epoch++;
            }
        }

        Component.onCompleted: widgetLayer.sync()

        Connections {
            target: Scenes
            function onItemsChanged(): void {
                widgetLayer.sync();
            }
            function onKeyChanged(): void {
                widgetLayer.sync();
            }
        }

        // The slots live in their own box so the input mask can walk its
        // children (the Repeater itself is one of them and brings no hitW).
        Item {
            id: slotsBox

            anchors.fill: parent

        Repeater {
            model: widgetLayer.list.length

            Item {
                id: slot

                required property int index
                readonly property var modelData: widgetLayer.list[slot.index] ?? ({})

                readonly property real fx: slot.modelData.x ?? 0
                readonly property real fy: slot.modelData.y ?? 0
                readonly property real fw: slot.modelData.w ?? 0.24
                readonly property real fh: slot.modelData.h ?? 0.2
                readonly property var opts: slot.modelData.opts ?? ({})

                // per-widget override, else the global setting
                readonly property string chips: {
                    const o = slot.opts.frame ?? "auto";
                    return o === "auto" ? Config.wallpaper.livingChips : o;
                }
                readonly property real chipOpacity: {
                    const o = slot.opts.opacity ?? -1;
                    return o >= 0 ? o : Config.wallpaper.livingOpacity;
                }

                x: parent.width * slot.fx
                y: parent.height * slot.fy
                width: parent.width * slot.fw
                height: parent.height * slot.fh

                // The glide-in: staggered, so a wall of widgets arrives as
                // a wave rather than a pop. WALLPAPER → LIVING → GLIDE IN.
                opacity: Config.wallpaper.livingEntrance ? 0 : 1
                scale: Config.wallpaper.livingEntrance ? 1.07 : 1
                transformOrigin: Item.Center

                Component.onCompleted: {
                    remeasure.restart();
                    if (Config.wallpaper.livingEntrance)
                        slotAppear.restart();
                }

                Connections {
                    target: widgetLayer
                    function onEpochChanged(): void {
                        if (!Config.wallpaper.livingEntrance)
                            return;
                        slot.opacity = 0;
                        slot.scale = 1.07;
                        slotAppear.restart();
                    }
                }

                SequentialAnimation {
                    id: slotAppear

                    PauseAnimation {
                        duration: Math.min(720, slot.index * 90)
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: slot
                            property: "opacity"
                            to: 1
                            duration: 430
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: slot
                            property: "scale"
                            to: 1
                            duration: 560
                            easing.type: Easing.OutBack
                        }
                    }
                }

                // Where the widget really is on screen (the box you dragged
                // is usually larger than what fills it): the input mask
                // takes exactly this, plus a little air for the lift.
                // MEASURED, not bound: reading a freshly built widget's
                // size lays its rows and columns out right there, so the
                // size moves under the read — every binding on it reported
                // a loop. One tick later it has settled; any later change
                // (a new look, a resize, the scale dial) measures again.
                property real hitW: 0
                property real hitH: 0
                readonly property bool takesPointer: host.interactive
                readonly property real hitX: slot.x + (slot.width - slot.hitW) / 2
                readonly property real hitY: slot.y + (slot.height - slot.hitH) / 2

                function measure(): void {
                    slot.hitW = host.width * host.scale + 12;
                    slot.hitH = host.height * host.scale + 12;
                }

                Timer {
                    id: remeasure

                    interval: 0
                    onTriggered: slot.measure()
                }

                Connections {
                    target: host
                    function onWidthChanged(): void {
                        remeasure.restart();
                    }
                    function onHeightChanged(): void {
                        remeasure.restart();
                    }
                    function onScaleChanged(): void {
                        remeasure.restart();
                    }
                }

                Widgets {
                    id: host

                    anchors.centerIn: parent
                    // STILL (DESKTOP inspector → POINTER) makes it a picture
                    // again: no hover, no clicks, no input region.
                    interactive: (slot.opts.pointer ?? "live") !== "still"
                    renderScale: host.scale
                    opts: slot.opts
                    wid: slot.modelData.widget ?? ""
                    framed: slot.chips !== "raw"
                    look: slot.chips
                    shape: slot.opts.shape ?? ""
                    tone: slot.opts.tone ?? ""
                    colourSlot: slot.opts.slot ?? 0
                    details: slot.opts.details ?? true
                    chipFill: slot.chips === "ink" ? Qt.rgba(0.02, 0.03, 0.05, 0.62) : Colours.alpha(Colours.surface, 0.55)
                    chipBorder: slot.chips === "ink" ? Qt.rgba(1, 1, 1, 0.14) : Colours.alpha(Colours.accent, 0.28)
                    chipOpacity: slot.chips === "raw" ? 1 : slot.chipOpacity

                    // The box is the size: the widget scales to fill it,
                    // with the global dial on top and a ceiling above.
                    readonly property real fit: Math.max(0.4, Math.min(2.2,
                        Math.min(slot.width / Math.max(24, host.implicitWidth),
                            slot.height / Math.max(24, host.implicitHeight))))
                    scale: host.fit * Config.wallpaper.livingScale
                }

                // ── the hint: what a click does, once the pointer rests ──
                //  Shown under the widget after a short dwell (above it when
                //  it sits too low), gone the moment the pointer leaves.
                Item {
                    id: hint

                    readonly property string words: WidgetActions.hint(slot.modelData.widget ?? "", host.look === "shapes")
                    property bool armed: false

                    // The widget's drawn edges, from the measured box.
                    readonly property real visTop: (slot.height - Math.max(0, slot.hitH - 12)) / 2
                    readonly property real visBottom: (slot.height + Math.max(0, slot.hitH - 12)) / 2
                    readonly property bool above: slot.y + hint.visBottom + 48 > root.height

                    width: pill.width
                    height: pill.height
                    x: (slot.width - hint.width) / 2
                    y: hint.above ? hint.visTop - hint.height - 12 : hint.visBottom + 12
                    opacity: hint.armed ? 1 : 0
                    visible: opacity > 0.01
                    transformOrigin: hint.above ? Item.Bottom : Item.Top
                    scale: hint.armed ? 1 : 0.92

                    Behavior on opacity {
                        NumberAnimation {
                            duration: hint.armed ? 220 : 120
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutBack
                        }
                    }

                    // Once you have clicked, the hint has done its job: it
                    // stays away until the pointer really leaves. A press
                    // drops Qt's hover for a blink (see Surface.qml), so a
                    // leave only counts after a short grace.
                    property bool clicked: false

                    Connections {
                        target: host
                        function onHeldChanged(): void {
                            if (host.held > 0) {
                                hint.clicked = true;
                                hint.armed = false;
                                dwell.stop();
                            }
                        }
                        function onHoveredChanged(): void {
                            if (host.hovered) {
                                grace.stop();
                                if (!hint.clicked && !hint.armed)
                                    dwell.restart();
                            } else {
                                dwell.stop();
                                hint.armed = false;
                                grace.restart();
                            }
                        }
                    }

                    Timer {
                        id: dwell

                        interval: 650
                        onTriggered: hint.armed = host.hovered && !hint.clicked
                    }

                    Timer {
                        id: grace

                        interval: 300
                        onTriggered: hint.clicked = false
                    }

                    Plate {
                        id: pill

                        width: hintRow.implicitWidth + 24
                        height: hintRow.implicitHeight + 12
                        radius: Appearance.pill(height)
                        color: Colours.alpha(Colours.surface, 0.82)
                        border.width: 1
                        border.color: Colours.alpha(Colours.accent, 0.35)
                        antialiasing: true

                        Row {
                            id: hintRow

                            anchors.centerIn: parent
                            spacing: 8

                            P5Text {
                                visible: hint.words !== ""
                                text: hint.words
                                color: Colours.ink
                                font.pixelSize: Appearance.font.size.tiny
                                font.weight: Font.DemiBold
                                tracking: 2
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: hint.words !== ""
                                width: 3
                                height: 3
                                radius: 1.5
                                color: Colours.alpha(Colours.accent, 0.8)
                            }
                            P5Text {
                                text: "RIGHT-CLICK TO EDIT"
                                color: Colours.alpha(Colours.inkDim, 0.85)
                                font.pixelSize: Appearance.font.size.tiny
                                font.weight: Font.DemiBold
                                tracking: 2
                            }
                        }
                    }
                }
            }
        }
        }
    }

    // ═════════════════════════════════════════════════════════ window ripples
    //  A window opening on this screen drops a soft accent ring on the
    //  wallpaper — the desktop reacts to what you do, like a game.
    //  WALLPAPER → LIVING DESKTOP → WINDOW RIPPLES.
    Item {
        id: rippleLayer

        anchors.fill: parent
        visible: root.living && Config.wallpaper.livingRipples && !Locker.locked

        Repeater {
            id: ripples

            model: 4

            Item {
                id: ripple

                property real rx: 0
                property real ry: 0
                property real rw: 0
                property real rh: 0

                function spawn(px: real, py: real, pw: real, ph: real): void {
                    ripple.rx = px;
                    ripple.ry = py;
                    ripple.rw = pw;
                    ripple.rh = ph;
                    wash.x = px;
                    wash.y = py;
                    wash.width = pw;
                    wash.height = ph;
                    ring.x = px - 40;
                    ring.y = py - 40;
                    ring.width = pw + 80;
                    ring.height = ph + 80;
                    wash.opacity = 0.13;
                    ring.opacity = 0.55;
                    rippleAnim.restart();
                }

                Plate {
                    id: wash

                    radius: Appearance.r(12)
                    color: Colours.accent
                    opacity: 0
                }

                Rectangle {
                    id: ring

                    radius: Appearance.r(16)
                    color: "transparent"
                    border.width: 2
                    border.color: Colours.accent
                    opacity: 0
                }

                ParallelAnimation {
                    id: rippleAnim

                    NumberAnimation { target: wash; property: "opacity"; to: 0; duration: 620; easing.type: Easing.OutQuad }
                    NumberAnimation { target: ring; property: "opacity"; to: 0; duration: 760; easing.type: Easing.OutQuad }
                    NumberAnimation { target: ring; property: "width"; to: ripple.rw + 220; duration: 760; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ring; property: "height"; to: ripple.rh + 220; duration: 760; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ring; property: "x"; to: ripple.rx - 110; duration: 760; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ring; property: "y"; to: ripple.ry - 110; duration: 760; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // ═══════════════════════════════════════ the sound on the wall
    //  A hairline of live cava bands along the bottom of the picture — the
    //  desktop breathing with the music, quiet enough to leave on all day.
    //  MODULES → AUDIO-REACTIVE → WALLPAPER WAVE. Silent without cava, and
    //  paused under the lock like everything else on this layer.
    Item {
        id: audioWave

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(root.height * 0.055)
        width: Math.min(parent.width * 0.5, Spectrum.count * 3 + Math.max(0, Spectrum.count - 1) * 5)
        height: 30
        visible: root.living && Config.services.audioReactive && Config.services.audioWave && Config.services.audioWaveStyle === "hairline" && Spectrum.live && !Locker.locked

        Row {
            id: waveRow

            anchors.fill: parent
            spacing: 5

            Repeater {
                model: Spectrum.count

                Rectangle {
                    required property int index

                    readonly property real band: Spectrum.at(index)

                    width: 3
                    height: 2 + band * 26
                    y: waveRow.height - height
                    radius: 1.5
                    color: Colours.alpha(Colours.accent, 0.22 + band * 0.5)
                    antialiasing: true
                }
            }
        }
    }

    //  The desk's CAVA modules, drawn here in the picture (Scenes.drawnOf):
    //  each in its own box, from its own switches. Being part of the
    //  wallpaper they are on every desktop, stay put and keep their size
    //  when the desktop zooms out, and SUPER+D's tiling never touches them.
    Item {
        anchors.fill: parent
        // (modelData is null for a moment while a screen goes away)
        visible: !Locker.locked && !!root.modelData && (Desk.focusedMonitor?.name ?? root.modelData.name) === root.modelData.name

        Repeater {
            model: Scenes.drawnItems

            CavaPreview {
                required property var modelData

                x: Math.round((modelData.x ?? 0) * parent.width)
                y: Math.round((modelData.y ?? 0) * parent.height)
                width: Math.round((modelData.w ?? 1) * parent.width)
                height: Math.round((modelData.h ?? 0.2) * parent.height)
                o: modelData.opts?.o ?? ({})
                columns: Math.max(16, width / (Math.max(4, Number(modelData.opts?.win?.size ?? 7)) * 0.9))
                demo: false
                running: parent.visible
            }
        }
    }

    //  The same music as a WAVE, BARS or a LINE standing on a screen edge
    //  (MODULES → AUDIO-REACTIVE → WAVE LOOK) — drawn on the picture, so it
    //  sits exactly on the edge and under every window.
    SpectrumEdge {
        // It starts where the desktop starts: under a pinned bar on its edge,
        // inside the SCREEN FRAME on the others — never hidden beneath them.
        readonly property bool barHolds: Config.bar.enabled && Config.bar.style !== "floating" && (Config.bar.persistent || !Config.bar.showOnHover) && !Focus.hidesBar
        function inset(side: string): real {
            if (side === Config.bar.position && barHolds)
                return Config.bar.thickness + Config.bar.margin;
            return Config.bar.frame ? Config.bar.frameWidth : 0;
        }

        anchors.fill: parent
        anchors.leftMargin: inset("left")
        anchors.rightMargin: inset("right")
        anchors.topMargin: inset("top")
        anchors.bottomMargin: inset("bottom")
        running: root.living && Config.services.audioReactive && Config.services.audioWave && Config.services.audioWaveStyle !== "hairline" && !Locker.locked
        edge: Config.services.audioWaveEdge
        style: Config.services.audioWaveStyle
        reach: (edge === "left" || edge === "right" ? root.width : root.height) * Math.max(0.03, Config.services.audioWaveReach)
        strength: 0.85
        // MODULES → AUDIO-REACTIVE → BAR DENSITY.
        barPitch: Config.services.audioWaveDensity === "fine" ? 10 : (Config.services.audioWaveDensity === "wide" ? 24 : 16)
    }

    // ═══════════════════════════════════════════ focus mode — the spotlight
    //  With focus on, the desktop itself steps back: a quiet shade over the
    //  picture while Velvet dims every window you are not looking at. Both
    //  are put back the moment focus goes off (and the Hyprland half is
    //  re-applied — never rewritten — by services/Focus.qml).
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.024, 0.03, 1)
        opacity: (Focus.active && Config.services.focusShades) ? 0.26 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 520
                easing.type: Easing.OutCubic
            }
        }

        visible: opacity > 0.001
    }

    // ── which windows the ripples have already greeted ────────────────────
    //  The shell listens for Hyprland's openwindow event, waits a beat for
    //  the toplevel list to refresh, then ripples once per genuinely new
    //  window on THIS screen and the active workspace. The first sweep only
    //  seeds the seen-set, so everything that was already open before the
    //  shell started never ripples.
    property bool rippleSeeded: false
    property int rippleIdx: 0
    property var rippleSeen: ({})

    function noteWindows(): void {
        const tops = Hyprland.toplevels?.values ?? [];
        const mon = Hyprland.monitorFor(root.modelData);
        const now = ({});
        const fresh = [];
        for (let i = 0; i < tops.length; i++) {
            const raw = tops[i]?.lastIpcObject ?? null;
            const a = raw?.address ?? "";
            if (!a)
                continue;
            now[a] = true;
            if (root.rippleSeeded && !(a in root.rippleSeen) && (raw.workspace?.id ?? -999) === Hypr.activeWsId && mon) {
                // hyprctl clients: at [x,y] / size [w,h]; the monitor has width/height in pixels.
                const x = raw.at?.[0] ?? 0;
                const y = raw.at?.[1] ?? 0;
                const w = raw.size?.[0] ?? 0;
                const h = raw.size?.[1] ?? 0;
                const sc = mon.scale > 0 ? mon.scale : 1;
                const mw = mon.width / sc;
                const mh = mon.height / sc;
                if (x + w > mon.x && x < mon.x + mw && y + h > mon.y && y < mon.y + mh)
                    fresh.push({ x: x - mon.x, y: y - mon.y, w: w, h: h });
            }
        }
        root.rippleSeen = now;
        if (!root.rippleSeeded) {
            root.rippleSeeded = true;
            return;
        }
        if (fresh.length === 0 || !root.living || !Config.wallpaper.livingRipples || Locker.locked)
            return;
        for (let i = 0; i < fresh.length; i++) {
            const f = fresh[i];
            const r = ripples.itemAt(root.rippleIdx);
            root.rippleIdx = (root.rippleIdx + 1) % 4;
            if (r && typeof r.spawn === "function")
                r.spawn(f.x, f.y, f.w, f.h);
        }
    }

    Connections {
        target: Hypr
        function onWindowOpened(): void {
            if (!root.living || !Config.wallpaper.livingRipples)
                return;
            rippleWait.restart();
        }
    }

    Timer {
        id: rippleWait

        interval: 90
        onTriggered: root.noteWindows()
    }

    // Seeds the seen-set once the desktop has settled after startup.
    Timer {
        running: true
        interval: 2500
        onTriggered: root.noteWindows()
    }

    NumberAnimation {
        id: fade

        target: front
        property: "opacity"
        from: 0
        to: 1
        duration: Config.wallpaper.transition ? Config.wallpaper.fadeDuration : 0
        easing.type: Easing.InOutQuad
    }

    // The cinematic dissolve: the new picture settles in from a slight
    // push-in instead of merely fading — a cut you feel rather than see.
    NumberAnimation {
        id: zoomIn

        target: frontWrap
        property: "scale"
        from: 1.07
        to: 1.0
        duration: Config.wallpaper.transition ? Config.wallpaper.fadeDuration * 1.6 : 0
        easing.type: Easing.OutCubic
    }

    onTargetChanged: root.swap()
    // Switching the renderer back to BUILTIN must paint at once.
    onBuiltinChanged: root.swap()

    function swap(): void {
        if (!root.builtin || root.target === "")
            return;
        const url = "file://" + root.target;
        if (String(front.source) === url)
            return;
        // Hand the current picture down to `back` BEFORE the new one lands,
        // so a fast run of picks always crossfades from the picture that
        // was actually on screen — never from a stale one.
        if (front.source !== "")
            back.source = front.source;
        front.opacity = 0;
        frontWrap.scale = 1.07;
        front.source = url;
    }

    // A wallpaper that never moves reads as a screenshot. This is a very slow
    // drift — you should never catch it happening, only notice the desktop
    // feels alive.
    //
    // It pauses while Velvet's own overlays are up: the map, the settings and
    // the wheel are full-screen surfaces, and the compositor should not have
    // to repaint a drifting wallpaper underneath them at the same time.
    // Four small steps a second instead of a full-screen repaint on every
    // frame: the drift moves about a pixel a second, so nothing is lost to
    // the eye, and an idle desktop stops costing the GPU (and the blur of
    // every window above it) forever. Pausing keeps the phase — no snap
    // back when an overlay closes — and turning it off returns to 1.
    property real kbT: 0
    readonly property real kbScale: Config.wallpaper.kenBurns ? 1 + 0.0175 * (1 - Math.cos(root.kbT * Math.PI / 90)) : 1

    Timer {
        id: drift

        interval: 250
        repeat: true
        running: Config.wallpaper.kenBurns && root.builtin && !Locker.locked && !(Panels.wheel || Panels.windowMap)
        onTriggered: root.kbT = (root.kbT + 0.25) % 180
    }

    // Restore whatever was set the last time the shell ran.
    Timer {
        running: true
        interval: 60
        onTriggered: root.swap()
    }
}
