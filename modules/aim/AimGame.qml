//  VELVET  ·  modules/aim/AimGame.qml
//  The secret AIM TRAINER: thirty seconds, targets in the dot-matrix look,
//  hits, combos, reaction time, a rank and a best per mode. Everything the
//  game is lives here (an Item, so it renders in a harness); AimTrainer.qml
//  only hosts it in a full-screen overlay.
//  Ways in: type "aim" in the launcher, the Konami code on the open island,
//  "starte den Aim Trainer" to Velly, `qs -c velvet ipc call panels aim`.
import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    signal quit

    // menu → count → play → done
    property string phase: "menu"
    property string mode: "grid"            // grid | flick | micro
    readonly property var modes: [
        {
            id: "grid",
            name: "GRIDSHOT",
            sub: "THREE AT ONCE",
            size: 34,
            count: 3,
            life: 0
        },
        {
            id: "flick",
            name: "FLICK",
            sub: "ONE · FAR · FAST",
            size: 26,
            count: 1,
            life: 0
        },
        {
            id: "micro",
            name: "MICRO",
            sub: "SMALL · SHRINKING",
            size: 20,
            count: 2,
            life: 1500
        }
    ]
    readonly property var cur: root.modes.find(m => m.id === root.mode) ?? root.modes[0]

    readonly property int roundMs: 30000
    property real remain: root.roundMs
    property int count: 3
    property int score: 0
    property int hits: 0
    property int shots: 0
    property int combo: 0
    property int bestCombo: 0
    property real reactSum: 0
    readonly property real accuracy: root.shots > 0 ? root.hits / root.shots : 0
    readonly property int reaction: root.hits > 0 ? Math.round(root.reactSum / root.hits) : 0
    property var best: ({})
    property bool newBest: false

    // the play field leaves room for the HUD
    readonly property real fieldTop: 120
    readonly property real fieldPad: 80

    focus: true

    // ───────────────────────────────────────────────────────────── the store
    readonly property string path: `${Quickshell.env("HOME")}/.config/velvet/aim.json`

    FileView {
        id: store

        path: root.path
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.best = d && typeof d === "object" ? d : {};
            } catch (e) {
                root.best = {};
            }
        }
    }

    function save(): void {
        store.setText(JSON.stringify(root.best, null, 1));
    }

    // ───────────────────────────────────────────────────────────── the game
    ListModel {
        id: targets
    }

    property int serial: 0

    function spawn(): void {
        const r = root.cur.size;
        const w = Math.max(200, root.width - root.fieldPad * 2);
        const h = Math.max(200, root.height - root.fieldTop - root.fieldPad);
        let x = 0, y = 0;
        for (let tries = 0; tries < 24; tries++) {
            if (root.mode === "flick" && targets.count === 0 && root.lastX >= 0) {
                // far from the last one: the flick is the point
                const a = Math.random() * Math.PI * 2;
                const d = Math.min(w, h) * (0.32 + Math.random() * 0.18);
                x = Math.max(0, Math.min(w, root.lastX - root.fieldPad + Math.cos(a) * d));
                y = Math.max(0, Math.min(h, root.lastY - root.fieldTop + Math.sin(a) * d));
            } else {
                x = Math.random() * w;
                y = Math.random() * h;
            }
            let clear = true;
            for (let i = 0; i < targets.count; i++) {
                const t = targets.get(i);
                if (Math.hypot(t.tx - root.fieldPad - x, t.ty - root.fieldTop - y) < r * 3.2)
                    clear = false;
            }
            if (clear)
                break;
        }
        root.serial++;
        targets.append({
            uid: root.serial,
            tx: root.fieldPad + x,
            ty: root.fieldTop + y,
            born: Date.now(),
            r: r
        });
    }

    property real lastX: -1
    property real lastY: -1

    function begin(): void {
        targets.clear();
        root.score = 0;
        root.hits = 0;
        root.shots = 0;
        root.combo = 0;
        root.bestCombo = 0;
        root.reactSum = 0;
        root.remain = root.roundMs;
        root.newBest = false;
        root.lastX = -1;
        root.count = 3;
        root.phase = "count";
        Sfx.charge();
        countdown.restart();
    }

    function finish(): void {
        targets.clear();
        root.phase = "done";
        Sfx.stopCharge();
        Sfx.quest();
        const prev = root.best[root.mode] ?? 0;
        if (root.score > prev) {
            const b = Object.assign({}, root.best);
            b[root.mode] = root.score;
            root.best = b;
            root.newBest = true;
            root.save();
        }
    }

    function shoot(px: real, py: real): void {
        if (root.phase !== "play")
            return;
        root.shots++;
        for (let i = targets.count - 1; i >= 0; i--) {
            const t = targets.get(i);
            const age = Date.now() - t.born;
            const rr = root.cur.life > 0 ? t.r * Math.max(0.35, 1 - age / root.cur.life * 0.65) : t.r;
            const d = Math.hypot(px - t.tx, py - t.ty);
            if (d <= rr + 3) {
                root.hits++;
                root.combo++;
                root.bestCombo = Math.max(root.bestCombo, root.combo);
                root.reactSum += age;
                // centre hits and quick hits pay; the combo multiplies
                const centre = 1 - Math.min(1, d / Math.max(1, rr));
                const quick = Math.max(0, 1 - age / 1200);
                root.score += Math.round((60 + centre * 40 + quick * 60) * (1 + Math.min(root.combo, 20) * 0.05));
                root.lastX = t.tx;
                root.lastY = t.ty;
                burst.createObject(fx, {
                    x: t.tx,
                    y: t.ty,
                    big: centre > 0.7
                });
                targets.remove(i);
                Sfx.play("cursor", 0.7);
                root.spawn();
                return;
            }
        }
        root.combo = 0;
        miss.createObject(fx, {
            x: px,
            y: py
        });
        Sfx.back();
    }

    Timer {
        id: countdown

        interval: 600
        repeat: true
        onTriggered: {
            root.count--;
            if (root.count > 0) {
                Sfx.cursor();
                return;
            }
            countdown.stop();
            Sfx.stopCharge();
            Sfx.launch();
            root.phase = "play";
            for (let i = 0; i < root.cur.count; i++)
                root.spawn();
            clock.start = Date.now();
        }
    }

    Timer {
        id: clock

        property real start: 0

        interval: 16
        repeat: true
        running: root.phase === "play"
        onTriggered: {
            root.remain = Math.max(0, root.roundMs - (Date.now() - clock.start));
            if (root.remain <= 0) {
                root.finish();
                return;
            }
            // MICRO: a target that shrank away is a miss
            if (root.cur.life > 0) {
                const now = Date.now();
                for (let i = targets.count - 1; i >= 0; i--) {
                    if (now - targets.get(i).born > root.cur.life) {
                        targets.remove(i);
                        root.combo = 0;
                        root.shots++;
                        root.spawn();
                    }
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (root.phase === "play" || root.phase === "count") {
                countdown.stop();
                Sfx.stopCharge();
                targets.clear();
                root.phase = "menu";
            } else {
                root.quit();
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.phase === "menu" || root.phase === "done")
                root.begin();
            event.accepted = true;
            return;
        }
        if (root.phase === "menu" || root.phase === "done") {
            const i = root.modes.findIndex(m => m.id === root.mode);
            if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                const n = root.modes.length;
                root.mode = root.modes[(i + (event.key === Qt.Key_Left ? -1 : 1) + n) % n].id;
                Sfx.cursor();
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                root.mode = root.modes[event.key - Qt.Key_1].id;
                Sfx.cursor();
                event.accepted = true;
            }
        }
    }

    // ───────────────────────────────────────────────────────────── the look
    // the dark glass and the dot grid of a hardware display
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.03, 0.86)
    }

    Image {
        anchors.fill: parent
        fillMode: Image.Tile
        opacity: 0.5
        source: `data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='22' height='22'><circle cx='11' cy='11' r='1.1' fill='${Colours.alpha(Colours.ink, 0.16)}'/></svg>`
    }

    // ── HUD
    Row {
        id: hud

        anchors.horizontalCenter: parent.horizontalCenter
        y: 34
        spacing: 46
        opacity: root.phase === "play" || root.phase === "count" ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }

        Repeater {
            model: [
                {
                    k: "TIME",
                    v: () => (root.remain / 1000).toFixed(1)
                },
                {
                    k: "SCORE",
                    v: () => `${root.score}`
                },
                {
                    k: "ACC",
                    v: () => `${Math.round(root.accuracy * 100)}%`
                },
                {
                    k: "COMBO",
                    v: () => `×${root.combo}`
                },
                {
                    k: "REACT",
                    v: () => root.reaction > 0 ? `${root.reaction}ms` : "—"
                }
            ]

            Column {
                required property var modelData

                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.modelData.k
                    color: Colours.alpha(Colours.ink, 0.45)
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: 11
                    font.letterSpacing: 3
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.modelData.v()
                    color: parent.modelData.k === "TIME" && root.remain < 5000 ? Colours.accentHot : Colours.ink
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: 30
                    font.bold: true
                    font.letterSpacing: 2
                }
            }
        }
    }

    // the time left, as a hairline under the HUD
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: hud.y + hud.height + 14
        width: Math.min(640, root.width * 0.5) * (root.remain / root.roundMs)
        height: 2
        radius: 1
        color: root.remain < 5000 ? Colours.accentHot : Colours.accent
        visible: root.phase === "play"
    }

    // ── targets
    Repeater {
        model: targets

        Item {
            id: tgt

            // the ListModel's roles (no `required` here: the model is ours)
            readonly property real tx: model.tx
            readonly property real ty: model.ty
            readonly property real r: model.r
            readonly property real born: model.born

            x: tgt.tx
            y: tgt.ty
            scale: 0

            Component.onCompleted: pop.start()

            NumberAnimation {
                id: pop

                target: tgt
                property: "scale"
                from: 0.2
                to: 1
                duration: 170
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }

            // MICRO: the target shrinks over its life
            Timer {
                running: root.cur.life > 0
                interval: 16
                repeat: true
                onTriggered: core.shrink = Math.max(0.35, 1 - (Date.now() - tgt.born) / root.cur.life * 0.65)
            }

            Item {
                id: core

                property real shrink: 1

                scale: core.shrink

                // a ring of LEDs, like the round dot-matrix displays
                Repeater {
                    model: 18

                    Rectangle {
                        required property int index

                        readonly property real a: index / 18 * Math.PI * 2
                        x: Math.cos(a) * (tgt.r + 7) - 2
                        y: Math.sin(a) * (tgt.r + 7) - 2
                        width: 4
                        height: 4
                        radius: 2
                        color: Colours.alpha(Colours.accent, 0.75)
                    }
                }

                Rectangle {
                    x: -tgt.r
                    y: -tgt.r
                    width: tgt.r * 2
                    height: tgt.r * 2
                    radius: tgt.r
                    color: Colours.alpha(Colours.accent, 0.22)
                    border.width: 2
                    border.color: Colours.accent
                    antialiasing: true
                }
                Rectangle {
                    x: -tgt.r * 0.34
                    y: -tgt.r * 0.34
                    width: tgt.r * 0.68
                    height: tgt.r * 0.68
                    radius: width / 2
                    color: Colours.ink
                    antialiasing: true
                }
            }
        }
    }

    // ── effects
    Item {
        id: fx

        anchors.fill: parent
    }

    Component {
        id: burst

        Item {
            id: b

            property bool big: false
            property real t: 0

            Repeater {
                model: b.big ? 14 : 9

                Rectangle {
                    required property int index

                    readonly property real a: index / (b.big ? 14 : 9) * Math.PI * 2 + 0.3
                    x: Math.cos(a) * (10 + b.t * (b.big ? 70 : 48)) - width / 2
                    y: Math.sin(a) * (10 + b.t * (b.big ? 70 : 48)) - height / 2
                    width: 5 * (1 - b.t) + 1
                    height: width
                    radius: width / 2
                    color: b.big ? Colours.ink : Colours.accent
                    opacity: 1 - b.t
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -34 - b.t * 26
                text: b.big ? "PERFECT" : `×${root.combo}`
                color: b.big ? Colours.ink : Colours.accent
                font.family: Appearance.fontFamily.mono
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 2
                opacity: 1 - b.t
            }

            NumberAnimation on t {
                from: 0
                to: 1
                duration: 420
                easing.type: Easing.OutCubic
                onFinished: b.destroy()
            }
        }
    }

    Component {
        id: miss

        Rectangle {
            id: m

            property real t: 0

            width: 12 + m.t * 36
            height: width
            radius: width / 2
            transform: Translate {
                x: -m.width / 2
                y: -m.height / 2
            }
            color: "transparent"
            border.width: 2
            border.color: Colours.alpha(Colours.danger, 1 - m.t)

            NumberAnimation on t {
                from: 0
                to: 1
                duration: 320
                easing.type: Easing.OutQuad
                onFinished: m.destroy()
            }
        }
    }

    // ── the countdown
    Text {
        anchors.centerIn: parent
        visible: root.phase === "count"
        text: `${root.count}`
        color: Colours.ink
        font.family: Appearance.fontFamily.mono
        font.pixelSize: 160
        font.bold: true
        scale: 1

        onTextChanged: {
            tick.restart();
        }

        NumberAnimation on scale {
            id: tick

            from: 1.35
            to: 1
            duration: 420
            easing.type: Easing.OutCubic
        }
    }

    // ── menu and results
    Column {
        anchors.centerIn: parent
        spacing: 26
        visible: root.phase === "menu" || root.phase === "done"

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.phase === "done" ? "ROUND OVER" : "AIM/01"
            color: Colours.ink
            font.family: Appearance.fontFamily.mono
            font.pixelSize: 64
            font.bold: true
            font.letterSpacing: 8
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.phase === "menu"
            text: "SECRET REFLEX TRAINER  ·  30 SECONDS  ·  CLICK THE TARGETS"
            color: Colours.alpha(Colours.ink, 0.5)
            font.family: Appearance.fontFamily.mono
            font.pixelSize: 12
            font.letterSpacing: 3
        }

        // the results
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.phase === "done"
            spacing: 42

            Repeater {
                model: root.phase === "done" ? [
                    {
                        k: "RANK",
                        v: root.rank()
                    },
                    {
                        k: "SCORE",
                        v: `${root.score}`
                    },
                    {
                        k: "ACCURACY",
                        v: `${Math.round(root.accuracy * 100)}%`
                    },
                    {
                        k: "REACTION",
                        v: root.reaction > 0 ? `${root.reaction} ms` : "—"
                    },
                    {
                        k: "BEST COMBO",
                        v: `×${root.bestCombo}`
                    }
                ] : []

                Column {
                    required property var modelData

                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.k
                        color: Colours.alpha(Colours.ink, 0.45)
                        font.family: Appearance.fontFamily.mono
                        font.pixelSize: 11
                        font.letterSpacing: 3
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: parent.modelData.v
                        color: parent.modelData.k === "RANK" ? Colours.accent : Colours.ink
                        font.family: Appearance.fontFamily.mono
                        font.pixelSize: parent.modelData.k === "RANK" ? 54 : 32
                        font.bold: true
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.phase === "done"
            text: root.newBest ? "NEW BEST" : `BEST  ${root.best[root.mode] ?? 0}`
            color: root.newBest ? Colours.accentHot : Colours.alpha(Colours.ink, 0.5)
            font.family: Appearance.fontFamily.mono
            font.pixelSize: 13
            font.bold: root.newBest
            font.letterSpacing: 4
        }

        // the modes, as chips
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Repeater {
                model: root.modes

                Rectangle {
                    id: chip

                    required property var modelData
                    required property int index
                    readonly property bool on: chip.modelData.id === root.mode

                    width: 170
                    height: 64
                    radius: Appearance.r(14)
                    color: chip.on ? Colours.alpha(Colours.accent, 0.2) : (chipHover.hovered ? Colours.alpha(Colours.ink, 0.08) : Colours.alpha(Colours.ink, 0.03))
                    border.width: 1
                    border.color: chip.on ? Colours.accent : Colours.alpha(Colours.ink, 0.14)
                    scale: chipArea.pressed ? 0.95 : (chipHover.hovered ? 1.03 : 1)

                    Behavior on scale {
                        SpringAnimation {
                            spring: 4
                            damping: 0.5
                            epsilon: 0.01
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${chip.index + 1}  ${chip.modelData.name}`
                            color: chip.on ? Colours.accent : Colours.ink
                            font.family: Appearance.fontFamily.mono
                            font.pixelSize: 15
                            font.bold: true
                            font.letterSpacing: 2
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${chip.modelData.sub}  ·  BEST ${root.best[chip.modelData.id] ?? 0}`
                            color: Colours.alpha(Colours.ink, 0.45)
                            font.family: Appearance.fontFamily.mono
                            font.pixelSize: 9
                            font.letterSpacing: 1.5
                        }
                    }

                    HoverHandler {
                        id: chipHover
                    }

                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (chip.on) {
                                root.begin();
                            } else {
                                root.mode = chip.modelData.id;
                                Sfx.cursor();
                            }
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.phase === "done" ? "SPACE  AGAIN   ·   ← →  MODE   ·   ESC  LEAVE" : "SPACE / CLICK THE MODE  START   ·   1 2 3  MODE   ·   ESC  LEAVE"
            color: Colours.alpha(Colours.ink, 0.4)
            font.family: Appearance.fontFamily.mono
            font.pixelSize: 11
            font.letterSpacing: 2
        }
    }

    function rank(): string {
        const s = root.score * (0.5 + root.accuracy * 0.5);
        const per = root.mode === "flick" ? 1.6 : (root.mode === "micro" ? 1.35 : 1);
        const v = s * per;
        if (v >= 9000)
            return "S";
        if (v >= 6500)
            return "A";
        if (v >= 4200)
            return "B";
        if (v >= 2200)
            return "C";
        return "D";
    }

    // ── the field: every click is a shot while a round runs; the crosshair
    // follows the pointer (the system cursor hides while you aim)
    MouseArea {
        id: field

        anchors.fill: parent
        z: -1
        enabled: root.phase === "play" || root.phase === "count"
        hoverEnabled: true
        cursorShape: root.phase === "play" ? Qt.BlankCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: e => root.shoot(e.x, e.y)
    }

    Item {
        id: crosshair

        x: field.mouseX
        y: field.mouseY
        visible: root.phase === "play" && field.containsMouse

        Rectangle {
            x: -1
            y: -11
            width: 2
            height: 7
            color: Colours.ink
        }
        Rectangle {
            x: -1
            y: 4
            width: 2
            height: 7
            color: Colours.ink
        }
        Rectangle {
            x: -11
            y: -1
            width: 7
            height: 2
            color: Colours.ink
        }
        Rectangle {
            x: 4
            y: -1
            width: 7
            height: 2
            color: Colours.ink
        }
        Rectangle {
            x: -1.5
            y: -1.5
            width: 3
            height: 3
            radius: 1.5
            color: Colours.accent
        }
    }
}
