//  VELVET  ·  modules/island/VellyBuddy.qml
//  Velly on your desktop (VELLY → ON THE DESKTOP): out of the island, a
//  little ball of velvet that lives on the screen's floor, above your windows.
//
//    grab her       and carry her anywhere — let go fast and she flies,
//                   bounces off the edges, squashes on landing ("whee!")
//    click          a giggle and a squish (three quick ones: a spin)
//    double-click   she jumps into the island and listens
//    pet her        move the pointer over her: hearts, a purr
//    left alone     she looks at your pointer when it is near, hops about
//                   now and then, bobs to music, yawns — and after a few
//                   quiet minutes falls asleep (bubbles) until you come back
//    a notification arrives: she jumps
//  While you talk to her (a session in the island) she is there, not here.
import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    // the screen she lives on: the one in use when she came out
    property var home: Hypr.focusedScreen ?? Quickshell.screens[0]

    screen: root.home
    color: "transparent"
    visible: !Focus.hidesBar && !Locker.locked && !Velly.active
    WlrLayershell.namespace: "velvet-velly"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // only she catches the pointer; everything around her is yours
    mask: Region {
        item: body
    }

    readonly property real size: Math.max(80, Math.min(220, Config.velly.buddySize))
    // the floor: above a bottom bar, the dock and the frame
    readonly property real floorY: root.height - root.size - Appearance.frameRoom("bottom") - 6
        - (Config.bar.enabled && Config.bar.position === "bottom" && Config.bar.style !== "floating" ? Config.bar.thickness + Config.bar.margin : 0)
        - (Config.dock.enabled && Config.dock.position === "bottom" && !Config.dock.autoHide ? Config.dock.size + 34 : 0)

    property real px: 0
    property real py: -root.size
    property real vx: 0
    property real vy: 0
    property bool held: false
    property bool moving: true
    property double touched: Date.now()

    // she drops in from the top on the right, when she first comes out
    Timer {
        running: true
        interval: 60
        onTriggered: {
            // the screen is hers from now on, wherever the focus goes
            root.home = root.home;
            root.px = Math.max(0, root.width - root.size - 160);
            root.py = -root.size;
            root.vy = 0;
            root.moving = true;
        }
    }

    function step(dt: real): void {
        if (root.held)
            return;
        root.vy += 2600 * dt;
        root.px += root.vx * dt;
        root.py += root.vy * dt;
        const right = root.width - root.size;
        if (root.px < 0 || root.px > right) {
            root.px = Math.max(0, Math.min(right, root.px));
            if (Math.abs(root.vx) > 300)
                root.bump(Math.abs(root.vx));
            root.vx = -root.vx * 0.55;
        }
        if (root.py >= root.floorY) {
            root.py = root.floorY;
            if (root.vy > 0) {
                if (root.vy > 380)
                    root.bump(root.vy);
                root.vy = -root.vy * 0.42;
                if (Math.abs(root.vy) < 140)
                    root.vy = 0;
            }
            root.vx *= Math.pow(0.06, dt);
            if (root.vy === 0 && Math.abs(root.vx) < 10) {
                root.vx = 0;
                root.moving = false;
            }
        }
    }

    function bump(speed: real): void {
        face.bounce();
        if (speed > 1100)
            Sfx.chirp("boing");
    }

    function jump(dx: real, up: real): void {
        if (root.held)
            return;
        root.vx = dx;
        root.vy = -up;
        root.moving = true;
    }

    function touch(): void {
        root.touched = Date.now();
        if (face.dozing) {
            face.dozing = false;
            root.jump(0, 520);
        }
    }

    FrameAnimation {
        running: root.visible && (root.moving || root.held)
        onTriggered: root.step(Math.min(frameTime, 1 / 30))
    }

    // ── where your pointer is (her eyes follow it when it is near)
    property point hand: Qt.point(-1e6, -1e6)

    Timer {
        running: root.visible && !face.dozing
        interval: 125
        repeat: true
        onTriggered: {
            whereIsIt.running = false;
            whereIsIt.running = true;
        }
    }

    Process {
        id: whereIsIt

        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const at = JSON.parse(text);
                    root.hand = Qt.point(at.x - (root.home?.x ?? 0), at.y - (root.home?.y ?? 0));
                } catch (e) {}
            }
        }
    }

    readonly property bool handNear: Math.hypot(root.hand.x - (root.px + root.size / 2), root.hand.y - (root.py + root.size / 2)) < 650

    onHandNearChanged: {
        if (root.handNear)
            root.touch();
    }

    // ── left alone: a hop now and then — towards your pointer if it is near
    Timer {
        running: root.visible && !face.dozing && !root.held
        interval: 11000
        repeat: true
        onTriggered: {
            interval = 8000 + Math.random() * 9000;
            if (root.moving)
                return;
            const toward = root.handNear ? Math.sign(root.hand.x - (root.px + root.size / 2)) : (Math.random() < 0.5 ? -1 : 1);
            root.jump(toward * (120 + Math.random() * 220), 520 + Math.random() * 260);
        }
    }

    // ── a few quiet minutes with nobody near: she dozes off
    Timer {
        running: root.visible && !face.dozing
        interval: 15000
        repeat: true
        onTriggered: {
            if (Date.now() - root.touched > 180000 && !root.handNear)
                face.dozing = true;
        }
    }

    // ── a notification: she jumps
    property int seen: Notifs.popups.length

    Connections {
        target: Notifs

        function onPopupsChanged(): void {
            if (Notifs.popups.length > root.seen && !face.dozing)
                root.jump((Math.random() - 0.5) * 200, 900);
            root.seen = Notifs.popups.length;
        }
    }

    // ═════════════════════════════════════════════════════════════════ her
    Item {
        id: body

        x: root.px
        y: root.py
        width: root.size
        height: root.size

        VellyFace {
            id: face

            anchors.fill: parent
            alwaysAwake: true
            onScreen: root.visible
            pointer: root.handNear ? Qt.point(root.hand.x - root.px, root.hand.y - root.py) : null
        }

        MouseArea {
            id: hand

            property point grabAt
            property var trail: []
            property real travelled: 0

            anchors.fill: parent
            cursorShape: root.held ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true

            onPressed: e => {
                root.touch();
                hand.grabAt = Qt.point(e.x, e.y);
                hand.trail = [];
                hand.travelled = 0;
                root.held = true;
                root.moving = true;
                root.vx = 0;
                root.vy = 0;
            }
            onPositionChanged: e => {
                if (!hand.pressed)
                    return;
                const dx = e.x - hand.grabAt.x, dy = e.y - hand.grabAt.y;
                hand.travelled += Math.hypot(dx, dy);
                root.px = Math.max(0, Math.min(root.width - root.size, root.px + dx));
                root.py = Math.max(0, Math.min(root.floorY, root.py + dy));
                const now = Date.now();
                hand.trail = hand.trail.concat([
                    {
                        x: root.px,
                        y: root.py,
                        t: now
                    }
                ]).filter(p => now - p.t < 90);
            }
            onReleased: {
                root.held = false;
                const tr = hand.trail;
                if (tr.length >= 2) {
                    const a = tr[0], b = tr[tr.length - 1];
                    const dt = Math.max(0.016, (b.t - a.t) / 1000);
                    root.vx = Math.max(-3200, Math.min(3200, (b.x - a.x) / dt));
                    root.vy = Math.max(-3200, Math.min(3200, (b.y - a.y) / dt));
                    if (Math.hypot(root.vx, root.vy) > 1300)
                        Sfx.chirp("whee");
                }
                root.moving = true;
                if (hand.travelled < 5)
                    face.poke();
            }
            onCanceled: root.held = false
            onDoubleClicked: Bridge.act({
                fn: "vellyWake"
            })
        }
    }
}
