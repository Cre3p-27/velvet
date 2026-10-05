//  VELVET  ·  components/SmoothScroll.qml
//  The wheel for every scrolling list in the shell. The stock Flickable jumps
//  a fixed few lines per notch and stops dead; a hand-rolled animation per
//  notch restarts at full speed each time and stutters. This one keeps a
//  TARGET and closes the gap to it a little every frame (exponential easing),
//  so quick notches simply move the target further and the view never
//  restarts. A burst of notches speeds up; a touchpad follows the fingers and
//  is only softened. Dragging, the scrollbar and code that sets contentY
//  (arrow keys revealing a row) are noticed and take the target along.
//
//      Flickable { id: flick … SmoothScroll { view: flick } }
import QtQuick

Item {
    id: root

    required property Flickable view

    // pixels a single notch moves
    property real step: 110
    // seconds the view takes to close ~63 % of the gap (smaller = snappier)
    property real tau: 0.085
    // how much a burst of notches may speed up (1 = not at all)
    property real boost: 2.4
    // lets the host react (the settings list drops its hover while it moves)
    signal scrolled

    readonly property bool gliding: frames.running

    property real target: 0
    property bool own: false
    property int burst: 0
    property double lastNotch: 0

    function limits(): var {
        const v = root.view;
        const top = v.originY - v.topMargin;
        const bottom = v.originY + Math.max(0, v.contentHeight - v.height) + v.bottomMargin;
        return [top, Math.max(top, bottom)];
    }

    function clamp(y: real): real {
        const l = root.limits();
        return Math.max(l[0], Math.min(l[1], y));
    }

    // glide to a position the same way the wheel does
    function glideTo(y: real): void {
        if (!frames.running)
            root.target = root.view.contentY;
        root.target = root.clamp(y);
        frames.running = Math.abs(root.target - root.view.contentY) > 0.4;
    }

    // jump to a position (and take the target with it)
    function snapTo(y: real): void {
        root.own = true;
        root.view.contentY = root.clamp(y);
        root.target = root.view.contentY;
        root.own = false;
    }

    Connections {
        target: root.view

        // someone else moved the view: follow it, do not fight it
        function onContentYChanged() {
            if (!root.own && !frames.running)
                root.target = root.view.contentY;
        }
        function onMovementStarted() {
            frames.running = false;
            root.target = root.view.contentY;
        }
        function onContentHeightChanged() {
            if (!frames.running)
                root.target = root.clamp(root.target);
        }
    }

    // One wheel event: angle in eighths of a degree (120 = a notch), pixel
    // delta from a touchpad (0 for a wheel). Also how a test drives it.
    function nudge(angleY: real, pixelY: real): void {
        const v = root.view;
        if (v.contentHeight <= v.height + 1)
            return;
        root.scrolled();
        if (!frames.running)
            root.target = v.contentY;
        if (pixelY !== 0) {
            // a touchpad: the fingers already know the distance
            root.target = root.clamp(root.target - pixelY);
        } else {
            const now = Date.now();
            root.burst = now - root.lastNotch < 140 ? Math.min(8, root.burst + 1) : 0;
            root.lastNotch = now;
            const speedup = 1 + (root.boost - 1) * Math.min(1, root.burst / 5);
            root.target = root.clamp(root.target - angleY / 120 * root.step * speedup);
        }
        frames.running = true;
    }

    WheelHandler {
        parent: root.view
        target: null
        orientation: Qt.Vertical
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        blocking: true

        onWheel: event => root.nudge(event.angleDelta.y, event.pixelDelta.y)
    }

    FrameAnimation {
        id: frames

        onTriggered: {
            const v = root.view;
            const gap = root.target - v.contentY;
            if (Math.abs(gap) < 0.4) {
                root.own = true;
                v.contentY = root.target;
                root.own = false;
                frames.running = false;
                return;
            }
            const k = 1 - Math.exp(-Math.min(frameTime, 0.05) / root.tau);
            root.own = true;
            v.contentY += gap * k;
            root.own = false;
        }
    }
}
