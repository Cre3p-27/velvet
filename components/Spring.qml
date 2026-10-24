//  VELVET  ·  components/Spring.qml
//  A spring that moves on every frame of the screen.
//
//  Qt's SpringAnimation works its physics in 16 ms steps and returns early
//  in between ("capped at 62fps", qquickspringanimation.cpp): on a 120, 144
//  or 240 Hz screen every spring in the shell climbed in 60 fps stairs next
//  to animations that run at the screen's rate. This one runs the very same
//  physics — the same 16 ms steps, the same spring, damping and epsilon, so a
//  spring keeps the exact curve and feel it had — and draws every frame in
//  between, eased from one step to the next. Nothing runs while it rests.
//
//      width: grow.value
//      Spring {
//          id: grow
//          to: root.wantedWidth
//          spring: 2.6
//          damping: 0.74
//          epsilon: 0.25
//      }
//
//  `live: false` follows `to` at once, like a disabled Behavior. A new `to`
//  while it moves keeps the speed it has, like SpringAnimation does. It is
//  born resting at `to` (a Behavior does not animate the first value either).
//
//  `carry: true` is for springs a hand drives directly (`live: false` while
//  the pointer holds it): it measures how fast `to` moved under the hand, and
//  let go it keeps that speed — a pill let go of mid-pull swings on the way
//  the hand went and settles, instead of starting again from a standstill.
import QtQuick

QtObject {
    id: root

    // where it is heading (bind it) and where it is now (read it; until it
    // is born it simply equals `to`)
    property real to: 0
    property real value: root.to
    // the numbers mean exactly what they mean on a SpringAnimation
    property real spring: 2.0
    property real damping: 0.5
    property real epsilon: 0.25
    property bool live: true
    property bool carry: false
    readonly property bool running: root.frames.running

    // the physics: the position at the last 16 ms step, the step after it
    // (worked out ahead, so the motion starts on the very next frame), the
    // speed that gets there, and the time already spent inside this step
    property real at: 0
    property real next: 0
    property real speed: 0
    // the speed before this step's push, so a shift can redo the step
    property real speedBefore: 0
    property real inStep: 0
    property bool born: false
    // when the hand last moved it (Date.now() ms), for `carry`
    property double heldAt: 0

    function settle(): void {
        root.frames.running = false;
        root.speed = 0;
        root.inStep = 0;
        root.at = root.to;
        root.next = root.to;
        root.value = root.to;
    }

    // one 16 ms step of SpringAnimation, from `at` with `speed`
    function ahead(): void {
        root.speedBefore = root.speed;
        root.speed = root.speed + root.spring * (root.to - root.at) - root.damping * root.speed;
        root.next = root.at + root.speed * 0.016;
    }

    // held: `to` is followed at once; with `carry` its speed is measured
    function hold(): void {
        const now = Date.now();
        let v = 0;
        if (root.carry) {
            const dt = (now - root.heldAt) / 1000;
            if (root.heldAt > 0 && dt > 0.002 && dt < 0.08)
                v = Math.max(-6000, Math.min(6000, (root.to - root.value) / dt));
            v = root.speed * 0.35 + v * 0.65;
        }
        root.frames.running = false;
        root.inStep = 0;
        root.at = root.to;
        root.next = root.to;
        root.value = root.to;
        root.speed = v;
        root.heldAt = now;
    }

    function chase(): void {
        if (!root.born) {
            root.settle();
            return;
        }
        if (!root.live) {
            root.hold();
            return;
        }
        if (!root.frames.running) {
            // let go: a hand that had already stopped gives no speed
            if (!root.carry || Date.now() - root.heldAt > 70)
                root.speed = 0;
            root.at = root.value;
            root.inStep = 0;
            root.ahead();
            root.frames.running = true;
        }
    }

    // Moves the whole motion by `d` and keeps its speed: a carousel that swaps
    // what it shows mid-flight slides on from where the new face already is.
    function shift(d: real): void {
        root.at += d;
        root.value += d;
        if (!root.born || !root.live)
            return;
        if (root.frames.running) {
            // the step under way was pushed from the old place: push it again
            // from the new one (the hand's speed stays, the pull is redone)
            root.speed = root.speedBefore;
            root.ahead();
            root.value = root.at + (root.next - root.at) * (root.inStep / 16);
        } else {
            root.inStep = 0;
            root.ahead();
            root.frames.running = true;
        }
    }

    onToChanged: root.chase()
    onLiveChanged: {
        if (!root.live) {
            root.settle();
            root.heldAt = Date.now();
        }
    }

    // born at rest: whatever `to` says once the bindings have settled. A
    // timer of its own, not Qt.callLater: a spring in a list that is rebuilt
    // in the same breath is gone before a booked call runs, and the call then
    // lands in a dead context ("invalid context" warnings) — its own timer
    // dies with it.
    property Timer birth: Timer {
        running: true
        interval: 0
        onTriggered: {
            root.born = true;
            root.settle();
        }
    }

    property FrameAnimation frames: FrameAnimation {
        onTriggered: {
            // a long stall is not caught up all at once (Qt would jump)
            root.inStep += Math.min(frameTime, 0.064) * 1000;
            while (root.inStep >= 16) {
                root.inStep -= 16;
                root.at = root.next;
                if (Math.abs(root.speed) < root.epsilon && Math.abs(root.to - root.at) < root.epsilon) {
                    root.settle();
                    return;
                }
                root.ahead();
            }
            root.value = root.at + (root.next - root.at) * (root.inStep / 16);
        }
    }
}
