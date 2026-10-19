//  VELVET  ·  modules/wallpaper/ArrangeDesk.qml
//  ARRANGE: the desk lifted off the screen and arranged by hand. The desktop
//  shrinks a little into a card (the windows go away behind it), every
//  module on it wiggles to say it can move, and the pointer does the rest:
//  drag a module and it follows on a spring, snaps to the middle, the edges
//  and its neighbours (a line shows where), and settles where you drop it;
//  the corner resizes it, the cross takes it off, the dock adds widgets.
//  Every drop is saved into the LIVE desk of the look you wear (Scenes.
//  patchLive) — the real desktop behind glides to the same place.
//
//  Keys: Esc or Enter done · Ctrl+Z undo · arrows nudge the picked module
//  (Shift: further) · Delete takes it off · Alt while dragging: no snapping.
//  DeskArrange.qml is the window; this Item is the whole thing (so a headless
//  test can drive it).
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick

FocusScope {
    id: root

    signal finished

    // fades in fast while the desk lifts: the windows give way to the desk
    opacity: Math.min(1, root.lift * 3)

    // the host flips it: true lifts the desk, false puts it back
    property bool shown: false
    // 0 → 1 as the desk lifts: the scale, the corners, the dark around it
    property real lift: root.shown ? 1 : 0
    Behavior on lift {
        enabled: Config.appearance.animationScale > 0
        SpringAnimation {
            spring: 3.4
            damping: 0.44
            epsilon: 0.002
        }
    }
    readonly property bool settled: Math.abs(root.lift - (root.shown ? 1 : 0)) < 0.004

    readonly property real topRoom: 84 * root.lift
    readonly property real bottomRoom: 150 * root.lift
    readonly property real sideRoom: 48 * root.lift
    // the desk keeps the screen's shape
    readonly property real k: root.width > 0 && root.height > 0 ? Math.max(0.3, Math.min((root.width - 2 * root.sideRoom) / root.width, (root.height - root.topRoom - root.bottomRoom) / root.height)) : 1
    readonly property real deskW: root.width * root.k
    readonly property real deskH: root.height * root.k
    readonly property real deskX: (root.width - root.deskW) / 2
    readonly property real deskY: root.topRoom + Math.max(0, (root.height - root.topRoom - root.bottomRoom - root.deskH) / 2)
    readonly property real corner: 26 * root.lift
    readonly property color ground: Qt.rgba(0.035, 0.035, 0.045, 1)

    // the modules on the live desk
    readonly property var items: Scenes.items
    property string picked: ""
    readonly property real step: root.deskW / 96        // the grid
    readonly property real magnet: 10                   // px a line pulls from
    property var guidesX: []
    property var guidesY: []

    // the wiggle: one clock for every module, each on its own phase
    property real clock: 0
    readonly property bool wiggles: Config.appearance.animationScale > 0 && Config.wallpaper.shapeMotion
    FrameAnimation {
        running: root.shown && root.wiggles && root.lift > 0.6
        onTriggered: root.clock += Math.min(frameTime, 0.05)
    }

    readonly property string wallpaperName: (Config.wallpaper.current || "").split("/").pop()
    readonly property var widgetChoices: LockModules.all.filter(m => m.id !== "power" && m.id !== "session").concat([
        {
            id: "calendar",
            name: "CALENDAR",
            glyph: "calendar_month"
        }
    ])

    function itemById(id: string): var {
        for (let i = 0; i < root.items.length; i++)
            if (root.items[i] && root.items[i].id === id)
                return root.items[i];
        return null;
    }

    // Where a moving edge goes: a line within reach pulls it (the middle, the
    // margins, every other module's edges and middle), else the grid.
    function snapAxis(pos: real, size: real, total: real, others: var, free: bool): var {
        if (free)
            return {
                pos: pos,
                guide: -1
            };
        const m = total * 0.025;
        const lines = [m, total / 2, total - m];
        for (let i = 0; i < others.length; i++)
            lines.push(others[i][0], others[i][0] + others[i][1] / 2, others[i][0] + others[i][1]);
        const edges = [0, size / 2, size];
        let best = null;
        for (let a = 0; a < lines.length; a++)
            for (let b = 0; b < edges.length; b++) {
                const d = lines[a] - (pos + edges[b]);
                if (Math.abs(d) <= root.magnet && (best === null || Math.abs(d) < Math.abs(best.d)))
                    best = {
                        d: d,
                        line: lines[a]
                    };
            }
        if (best)
            return {
                pos: pos + best.d,
                guide: best.line
            };
        return {
            pos: Math.round(pos / root.step) * root.step,
            guide: -1
        };
    }

    function othersOf(id: string, axis: string): var {
        const out = [];
        for (let i = 0; i < root.items.length; i++) {
            const it = root.items[i];
            if (!it || it.id === id)
                continue;
            if (axis === "x")
                out.push([(it.x ?? 0) * root.deskW, (it.w ?? 0.2) * root.deskW]);
            else
                out.push([(it.y ?? 0) * root.deskH, (it.h ?? 0.2) * root.deskH]);
        }
        return out;
    }

    function nudge(dx: real, dy: real): void {
        const it = root.itemById(root.picked);
        if (!it)
            return;
        const w = it.w ?? 0.2;
        const h = it.h ?? 0.2;
        Scenes.patchLive(it.id, {
            x: Math.max(0, Math.min(1 - w, (it.x ?? 0) + dx)),
            y: Math.max(0, Math.min(1 - h, (it.y ?? 0) + dy))
        });
        Sfx.cursor();
    }

    function addWidget(m: var): void {
        const w = 0.22;
        const h = 0.2;
        // the first free spot from the top left, else the middle
        let at = null;
        for (let gy = 0.06; gy < 0.8 && !at; gy += 0.1)
            for (let gx = 0.04; gx < 0.8 && !at; gx += 0.08) {
                const hit = root.items.some(it => it && gx < (it.x ?? 0) + (it.w ?? 0) && gx + w > (it.x ?? 0) && gy < (it.y ?? 0) + (it.h ?? 0) && gy + h > (it.y ?? 0));
                if (!hit)
                    at = [gx, gy];
            }
        at = at ?? [0.5 - w / 2, 0.5 - h / 2];
        Scenes.editKey = "";
        Scenes.add({
            kind: "widget",
            widget: m.id,
            name: m.name,
            x: at[0],
            y: at[1],
            w: w,
            h: h,
            ws: 0,
            float: true,
            opts: {
                frame: "shapes",
                opacity: -1
            }
        });
        Sfx.select();
    }

    Keys.onPressed: event => {
        const big = (event.modifiers & Qt.ShiftModifier) ? 4 : 1;
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.finished();
            event.accepted = true;
        } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
            Scenes.undo();
            event.accepted = true;
        } else if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && root.picked !== "") {
            Scenes.removeLive(root.picked);
            root.picked = "";
            Sfx.back();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.nudge(-big / 96, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            root.nudge(big / 96, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.nudge(0, -big / 96);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.nudge(0, big / 96);
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab) {
            // walk through the modules
            const ids = root.items.map(it => it?.id ?? "").filter(x => x !== "");
            if (ids.length > 0)
                root.picked = ids[(Math.max(-1, ids.indexOf(root.picked)) + 1) % ids.length];
            Sfx.cursor();
            event.accepted = true;
        }
    }

    // the dark the desk is lifted out of (the windows are behind it)
    Rectangle {
        anchors.fill: parent
        color: root.ground
        opacity: root.lift

        // a click beside the desk lets go of the picked module
        TapHandler {
            onTapped: root.picked = ""
        }
    }

    // ── the desk
    Item {
        id: desk

        x: root.deskX
        y: root.deskY
        width: root.deskW
        height: root.deskH

        Image {
            anchors.fill: parent
            source: Config.wallpaper.current !== "" ? "file://" + Config.wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 1920
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.2 * root.lift
        }

        // the grid, as dots: drawn once per size, not per frame
        Canvas {
            id: dots

            anchors.fill: parent
            opacity: 0.5 * root.lift
            renderStrategy: Canvas.Cooperative
            onWidthChanged: dots.requestPaint()
            onHeightChanged: dots.requestPaint()
            onPaint: {
                const ctx = dots.getContext("2d");
                ctx.reset();
                const st = Math.max(8, root.step * 4);
                ctx.fillStyle = Qt.rgba(1, 1, 1, 0.55);
                for (let gx = st; gx < dots.width; gx += st)
                    for (let gy = st; gy < dots.height; gy += st) {
                        ctx.beginPath();
                        ctx.arc(gx, gy, 1.1, 0, Math.PI * 2);
                        ctx.fill();
                    }
            }
        }

        // where a dragged module snapped to
        Repeater {
            model: root.guidesX

            Rectangle {
                required property real modelData

                x: Math.round(modelData) - 1
                width: 2
                height: desk.height
                color: Colours.accent
                opacity: 0.85
            }
        }
        Repeater {
            model: root.guidesY

            Rectangle {
                required property real modelData

                y: Math.round(modelData) - 1
                height: 2
                width: desk.width
                color: Colours.accent
                opacity: 0.85
            }
        }

        // a count, not the list: a drop rewrites the list, and a list model
        // would rebuild every module mid-glide
        Repeater {
            model: root.items.length

            ArrangeItem {}
        }

        // the rounded corners: the dark painted over them
        Rectangle {
            anchors.fill: parent
            anchors.margins: -root.corner
            radius: root.corner * 2
            color: "transparent"
            border.width: root.corner
            border.color: Qt.rgba(root.ground.r, root.ground.g, root.ground.b, root.lift)
            visible: root.corner > 0.5
        }
        Rectangle {
            anchors.fill: parent
            radius: root.corner
            color: "transparent"
            border.width: 1.5
            border.color: Colours.alpha(Colours.accent, 0.55 * root.lift)
        }
    }

    // ── what this is
    Column {
        x: root.deskX + 6
        y: 22 * root.lift
        opacity: Math.max(0, root.lift * 1.4 - 0.4)
        spacing: 3

        P5Text {
            display: true
            text: "ARRANGE THE DESK"
            color: "white"
            font.pixelSize: Appearance.font.size.huge
        }
        P5Text {
            text: {
                const l = Presets.find(Presets.applied);
                const n = root.items.length;
                return `${l ? Presets.nameOf(l) : "VELVET"} · ${root.wallpaperName.toUpperCase()} · ${n === 1 ? "1 MODULE" : n + " MODULES"} ON IT`;
            }
            color: Qt.rgba(1, 1, 1, 0.62)
            font.pixelSize: Appearance.font.size.small
            tracking: 1.5
        }
    }

    // ── the dock: add, undo, done
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - root.bottomRoom + 22
        opacity: Math.max(0, root.lift * 1.4 - 0.4)
        spacing: 12

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Repeater {
                model: root.widgetChoices

                DockChip {
                    required property var modelData

                    icon: modelData.glyph
                    text: modelData.name
                    onClicked: root.addWidget(modelData)
                }
            }

            Item {
                width: 14
                height: 1
            }

            DockChip {
                visible: Scenes.undoStore !== null && Scenes.undoStore !== undefined
                icon: "undo"
                text: "UNDO"
                onClicked: Scenes.undo()
            }
            DockChip {
                strong: true
                icon: "check"
                text: "DONE"
                onClicked: root.finished()
            }
        }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "DRAG TO MOVE · THE CORNER RESIZES · × TAKES IT OFF · ALT: NO SNAPPING · ARROWS NUDGE · ESC DONE"
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.5
        }
    }

    // ═══════════════════════════════════════════════════════════ parts
    component DockChip: Plate {
        id: chip

        property string text: ""
        property string icon: ""
        property bool strong: false

        signal clicked

        width: chipRow.implicitWidth + 26
        height: 38
        radius: Appearance.r(19)
        color: chip.strong ? (chipHover.hovered ? Colours.accentHot : Colours.accent) : (chipHover.hovered ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.09))
        border.width: chip.strong ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
        scale: chipTap.pressed ? 0.92 : (chipHover.hovered ? 1.05 : 1)
        antialiasing: true

        Behavior on scale {
            SpringAnimation {
                spring: 7
                damping: 0.4
                epsilon: 0.002
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 7

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                color: chip.strong ? Colours.on(Colours.accent) : "white"
                font.pixelSize: 17
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                color: chip.strong ? Colours.on(Colours.accent) : "white"
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.5
            }
        }

        HoverHandler {
            id: chipHover

            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (hovered)
                    Sfx.cursor();
            }
        }
        TapHandler {
            id: chipTap

            gesturePolicy: TapHandler.WithinBounds
            onTapped: chip.clicked()
        }
    }

    // ── one module on the lifted desk
    component ArrangeItem: Item {
        id: ai

        required property int index
        readonly property var modelData: root.items[ai.index] ?? ({})

        readonly property string iid: ai.modelData?.id ?? ""
        readonly property bool isWidget: ai.modelData?.kind === "widget"
        readonly property bool drawn: Scenes.drawnOf(ai.modelData)
        readonly property var opts: ai.modelData?.opts ?? ({})
        readonly property bool chosen: root.picked === ai.iid
        readonly property bool hot: aiHover.hovered || ai.chosen || ai.dragging || ai.resizing

        // where the desk says it is…
        readonly property real fx: (ai.modelData?.x ?? 0) * root.deskW
        readonly property real fy: (ai.modelData?.y ?? 0) * root.deskH
        readonly property real fw: Math.max(24, (ai.modelData?.w ?? 0.2) * root.deskW)
        readonly property real fh: Math.max(24, (ai.modelData?.h ?? 0.2) * root.deskH)
        // …and where the hand has it while it moves
        property bool dragging: false
        property bool resizing: false
        property real gx: 0
        property real gy: 0
        property real gw: 0
        property real gh: 0
        property real grabX: 0
        property real grabY: 0
        property bool moved: false

        x: ai.dragging ? ai.gx : ai.fx
        y: ai.dragging ? ai.gy : ai.fy
        width: ai.resizing ? ai.gw : ai.fw
        height: ai.resizing ? ai.gh : ai.fh
        z: ai.dragging || ai.resizing ? 10 : (ai.hot ? 2 : 1)

        // the hand's spring: the module trails the pointer a little
        Behavior on x {
            enabled: root.settled && !ai.resizing
            SpringAnimation {
                spring: 6
                damping: 0.5
                epsilon: 0.2
            }
        }
        Behavior on y {
            enabled: root.settled && !ai.resizing
            SpringAnimation {
                spring: 6
                damping: 0.5
                epsilon: 0.2
            }
        }

        // the wiggle (still while it is in the hand), the lift in the hand
        rotation: root.wiggles && !ai.dragging && !ai.resizing && !aiHover.hovered ? 0.6 * Math.sin(root.clock * Math.PI * 2 * 1.6 + ai.index * 1.9) * root.lift : 0
        scale: ai.dragging ? 1.045 : (aiHover.hovered ? 1.015 : 1)
        Behavior on scale {
            SpringAnimation {
                spring: 5
                damping: 0.38
                epsilon: 0.002
            }
        }

        // the shadow under a module in the hand
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 10
            anchors.bottomMargin: -14
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            radius: Appearance.r(18)
            color: Qt.rgba(0, 0, 0, ai.dragging ? 0.42 : 0)
            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        // what it is: the widget itself, the music, or a window's card
        Item {
            id: face

            anchors.fill: parent
            clip: !ai.isWidget

            Widgets {
                id: host

                readonly property string chips: {
                    const o = ai.opts.frame ?? "auto";
                    return o === "auto" ? Config.wallpaper.livingChips : o;
                }
                readonly property real fit: Math.max(0.3, Math.min(2.2, Math.min(face.width / Math.max(24, host.implicitWidth), face.height / Math.max(24, host.implicitHeight))))

                anchors.centerIn: parent
                visible: ai.isWidget
                interactive: false
                wid: ai.isWidget ? (ai.modelData?.widget ?? "") : ""
                framed: host.chips !== "raw"
                look: host.chips
                shape: ai.opts.shape ?? ""
                tone: ai.opts.tone ?? ""
                colourSlot: ai.opts.slot ?? 0
                details: ai.opts.details ?? true
                opts: ai.opts
                chipOpacity: host.chips === "raw" ? 1 : ((ai.opts.opacity ?? -1) >= 0 ? ai.opts.opacity : Config.wallpaper.livingOpacity)
                scale: host.fit * Config.wallpaper.livingScale
                renderScale: host.scale
            }

            CavaPreview {
                anchors.fill: parent
                visible: ai.drawn
                o: ai.opts.o ?? ({})
                columns: Math.max(16, width / 6)
                demo: true
                running: ai.drawn && root.shown
            }

            Plate {
                anchors.fill: parent
                visible: !ai.isWidget && !ai.drawn
                radius: Appearance.r(14)
                color: Colours.alpha(Colours.surface, 0.78)
                border.width: 1
                border.color: Colours.alpha(Colours.ink, 0.16)

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: Scenes.iconFor(ai.modelData) || "terminal"
                        color: Colours.accent
                        font.pixelSize: Math.max(16, Math.min(40, face.height * 0.3))
                    }
                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(Scenes.labelFor(ai.modelData) || "").toUpperCase()
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.small
                        tracking: 1.5
                    }
                }
            }
        }

        // its outline: soft on the desk, bright in the hand
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: Appearance.r(16)
            color: Colours.alpha(Colours.accent, ai.dragging ? 0.1 : 0)
            border.width: ai.hot ? 2 : 1
            border.color: ai.hot ? Colours.accent : Qt.rgba(1, 1, 1, 0.35)
            opacity: root.lift
        }

        // its name, over it
        Plate {
            x: 0
            y: -height - 8
            width: tagText.implicitWidth + 16
            height: 22
            radius: Appearance.r(11)
            color: ai.hot ? Colours.accent : Qt.rgba(0, 0, 0, 0.55)
            opacity: root.lift

            P5Text {
                id: tagText

                anchors.centerIn: parent
                text: String(ai.modelData?.name || Scenes.labelFor(ai.modelData) || "").toUpperCase()
                color: ai.hot ? Colours.on(Colours.accent) : "white"
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.5
            }
        }

        // the hand: drag anywhere on the module
        MouseArea {
            id: grip

            anchors.fill: parent
            hoverEnabled: false
            cursorShape: ai.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true

            onPressed: mouse => {
                root.picked = ai.iid;
                root.forceActiveFocus();
                ai.grabX = mouse.x;
                ai.grabY = mouse.y;
                ai.moved = false;
            }
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const p = grip.mapToItem(desk, mouse.x, mouse.y);
                if (!ai.dragging) {
                    if (Math.abs(mouse.x - ai.grabX) < 4 && Math.abs(mouse.y - ai.grabY) < 4)
                        return;
                    Scenes.snapshot(`MOVED ${String(ai.modelData?.name ?? "").toUpperCase()}`);
                    ai.gx = ai.fx;
                    ai.gy = ai.fy;
                    ai.dragging = true;
                    Sfx.cursor();
                }
                const free = (mouse.modifiers & Qt.AltModifier) !== 0;
                const left = Math.max(0, Math.min(root.deskW - ai.width, p.x - ai.grabX));
                const top = Math.max(0, Math.min(root.deskH - ai.height, p.y - ai.grabY));
                const sx = root.snapAxis(left, ai.width, root.deskW, root.othersOf(ai.iid, "x"), free);
                const sy = root.snapAxis(top, ai.height, root.deskH, root.othersOf(ai.iid, "y"), free);
                ai.gx = Math.max(0, Math.min(root.deskW - ai.width, sx.pos));
                ai.gy = Math.max(0, Math.min(root.deskH - ai.height, sy.pos));
                root.guidesX = sx.guide >= 0 ? [sx.guide] : [];
                root.guidesY = sy.guide >= 0 ? [sy.guide] : [];
                ai.moved = true;
            }
            onReleased: {
                if (ai.dragging) {
                    Scenes.patchLive(ai.iid, {
                        x: ai.gx / root.deskW,
                        y: ai.gy / root.deskH
                    });
                    Sfx.select();
                }
                ai.dragging = false;
                root.guidesX = [];
                root.guidesY = [];
            }
            onCanceled: {
                ai.dragging = false;
                root.guidesX = [];
                root.guidesY = [];
            }
        }

        HoverHandler {
            id: aiHover
        }

        // × takes it off
        Plate {
            x: -11
            y: -11
            width: 26
            height: 26
            radius: 13
            color: offHover.hovered ? Colours.danger : Qt.rgba(0.08, 0.08, 0.1, 0.92)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.3)
            opacity: ai.hot && !ai.dragging ? root.lift : 0
            visible: opacity > 0.02
            scale: offHover.hovered ? 1.12 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                SpringAnimation {
                    spring: 7
                    damping: 0.4
                    epsilon: 0.002
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "close"
                color: "white"
                font.pixelSize: 15
            }
            HoverHandler {
                id: offHover

                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                gesturePolicy: TapHandler.WithinBounds
                onTapped: {
                    Scenes.removeLive(ai.iid);
                    if (root.picked === ai.iid)
                        root.picked = "";
                    Sfx.back();
                }
            }
        }

        // the corner resizes
        Plate {
            id: corner

            x: parent.width - width / 2 - 2
            y: parent.height - height / 2 - 2
            width: 22
            height: 22
            radius: 11
            color: cornerArea.pressed ? Colours.accentHot : Colours.accent
            border.width: 2
            border.color: Qt.rgba(1, 1, 1, 0.85)
            opacity: ai.hot && !ai.dragging ? root.lift : 0
            visible: opacity > 0.02

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }

            MouseArea {
                id: cornerArea

                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.SizeFDiagCursor
                preventStealing: true

                property real startX: 0
                property real startY: 0

                onPressed: mouse => {
                    root.picked = ai.iid;
                    const p = cornerArea.mapToItem(desk, mouse.x, mouse.y);
                    cornerArea.startX = p.x;
                    cornerArea.startY = p.y;
                    Scenes.snapshot(`RESIZED ${String(ai.modelData?.name ?? "").toUpperCase()}`);
                    ai.gw = ai.fw;
                    ai.gh = ai.fh;
                    ai.resizing = true;
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    const p = cornerArea.mapToItem(desk, mouse.x, mouse.y);
                    const free = (mouse.modifiers & Qt.AltModifier) !== 0;
                    let w = Math.max(root.deskW * 0.06, Math.min(root.deskW - ai.fx, ai.fw + p.x - cornerArea.startX));
                    let h = Math.max(root.deskH * 0.05, Math.min(root.deskH - ai.fy, ai.fh + p.y - cornerArea.startY));
                    if (!free) {
                        w = Math.round(w / root.step) * root.step;
                        h = Math.round(h / root.step) * root.step;
                    }
                    ai.gw = Math.max(root.deskW * 0.06, w);
                    ai.gh = Math.max(root.deskH * 0.05, h);
                }
                onReleased: {
                    if (ai.resizing)
                        Scenes.patchLive(ai.iid, {
                            w: ai.gw / root.deskW,
                            h: ai.gh / root.deskH
                        });
                    ai.resizing = false;
                    Sfx.select();
                }
                onCanceled: ai.resizing = false
            }
        }
    }
}
