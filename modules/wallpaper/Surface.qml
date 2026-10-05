//  VELVET  ·  modules/wallpaper/Surface.qml
//  What turns a desktop widget from a picture of a thing into the thing:
//  it notices the pointer. Hovered, it lifts and leans a few degrees under
//  the pointer; a soft light follows the pointer across it; a press squashes
//  it; a click does something. Every look reads the same few numbers out of
//  here (`hot`, `down`, `glow`, `spin`, `px`, `py`), so every tile of every
//  widget moves with the same physics.
//
//  Input only while `active` — the DESKTOP editor draws these same widgets
//  as previews and must keep its own drag. Motion follows SHAPE MOTION:
//  with it off a surface still answers the pointer, it just doesn't move.
//  Nothing here runs while the pointer is away: every value settles and
//  every animation stops, so a still desktop still costs nothing.
import qs.config
import QtQuick

Item {
    id: root

    property bool active: false
    property bool motion: Config.wallpaper.shapeMotion
    // Something is behind the primary button: the pointer becomes a hand
    // and a press squashes. Without one the surface only lights up.
    property bool clickable: false
    // Hit-test as the ellipse inside the box (the SHAPES silhouettes)
    // rather than the box itself — the corners of a cookie are not the cookie.
    property bool round: false
    property bool scrollable: false
    // Right-click opens the widget in DESKTOP (WidgetActions.edit).
    property bool editable: true
    // How far it comes up to meet the pointer, and how far it leans.
    property real lift: 0.05
    property real tilt: 6

    signal activated()
    signal secondary()
    signal scrolled(int steps)

    // Qt drops a HoverHandler's hover the moment a MouseArea takes the
    // press, and gives it back on release — a click would make the tile
    // sag for a blink. So a press on this surface, or on any surface
    // inside it (a button on a card), holds the hover until release.
    readonly property bool __velvetSurface: true
    property int held: 0
    readonly property bool hovered: root.active && (hover.hovered || area.pressed || root.held > 0)
    readonly property bool pressed: root.active && root.clickable && area.pressed && (area.pressedButtons & Qt.LeftButton)

    function _holdAncestors(delta: int): void {
        for (let p = root.parent; p; p = p.parent) {
            if (p.__velvetSurface === true)
                p.held = Math.max(0, p.held + delta);
        }
    }

    // 0 → 1 as the pointer arrives. Sprung: it overshoots a hair on the
    // way in and settles, which is what makes the lift feel physical.
    property real hot: root.hovered ? 1 : 0
    Behavior on hot {
        enabled: root.motion
        SpringAnimation {
            spring: 4.2
            damping: 0.34
            epsilon: 0.004
        }
    }

    property real down: root.pressed ? 1 : 0
    Behavior on down {
        enabled: root.motion
        SpringAnimation {
            spring: 7
            damping: 0.42
            epsilon: 0.004
        }
    }

    // The pointer, normalised to -1…1 from the centre — the lean follows it
    // with a little lag, so a quick flick across still reads as smooth.
    property real nx: root.hovered ? Math.max(-1, Math.min(1, hover.point.position.x / Math.max(1, root.width) * 2 - 1)) : 0
    property real ny: root.hovered ? Math.max(-1, Math.min(1, hover.point.position.y / Math.max(1, root.height) * 2 - 1)) : 0
    Behavior on nx {
        enabled: root.motion
        SpringAnimation {
            spring: 3.4
            damping: 0.42
            epsilon: 0.003
        }
    }
    Behavior on ny {
        enabled: root.motion
        SpringAnimation {
            spring: 3.4
            damping: 0.42
            epsilon: 0.003
        }
    }

    // Where the light sits, in this item's pixels. It rides the pointer
    // exactly; the light's strength is what fades in and out.
    readonly property real px: root.hovered ? hover.point.position.x : root.width / 2
    readonly property real py: root.hovered ? hover.point.position.y : root.height / 2

    readonly property real heat: Math.max(0, Math.min(1, root.hot))
    // The light's strength: a glow under the pointer, brighter on a press.
    readonly property real glow: root.heat * 0.16 + Math.max(0, root.down) * 0.14
    // How far a SHAPES silhouette turns: a quarter-lobe on hover, a nudge
    // on a press, and one whole turn when `spinOnce()` is asked for.
    readonly property real spin: root.hot * 16 + root.down * 10 + root.kick * 360
    property real kick: 0

    function spinOnce(): void {
        if (root.motion)
            kickAnim.restart();
    }

    SequentialAnimation {
        id: kickAnim

        NumberAnimation {
            target: root
            property: "kick"
            from: 0
            to: 1
            duration: 1100
            easing.type: Easing.OutCubic
        }
        // One full turn is the same outline again — the jump back is invisible.
        PropertyAction {
            target: root
            property: "kick"
            value: 0
        }
    }

    containmentMask: root.round ? ellipse : null

    QtObject {
        id: ellipse

        function contains(point: point): bool {
            const rx = root.width / 2;
            const ry = root.height / 2;
            if (rx <= 0 || ry <= 0)
                return false;
            const dx = (point.x - rx) / rx;
            const dy = (point.y - ry) / ry;
            return dx * dx + dy * dy <= 1.02;
        }
    }

    // Observes without taking anything: a surface inside a surface lights
    // both, and the innermost one decides what the pointer looks like.
    HoverHandler {
        id: hover

        enabled: root.active
        cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // Under the content on purpose: text and shapes let the press fall
    // through to here, while a nested surface (a button on a card) sits
    // above and answers first.
    MouseArea {
        id: area

        anchors.fill: parent
        enabled: root.active
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        containmentMask: root.round ? ellipse : null

        property real wheelAcc: 0
        property bool holding: false

        onPressedChanged: {
            if (area.pressed !== area.holding) {
                area.holding = area.pressed;
                root._holdAncestors(area.pressed ? 1 : -1);
            }
        }
        Component.onDestruction: {
            if (area.holding)
                root._holdAncestors(-1);
        }

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.secondary();
                if (root.editable)
                    WidgetActions.edit();
            } else if (root.clickable) {
                root.activated();
            }
        }

        onWheel: wheel => {
            if (!root.scrollable) {
                wheel.accepted = false;
                return;
            }
            area.wheelAcc += wheel.angleDelta.y;
            const steps = Math.trunc(area.wheelAcc / 120);
            if (steps !== 0) {
                area.wheelAcc -= steps * 120;
                root.scrolled(steps);
            }
        }
    }

    default property alias content: stage.data

    // The stage carries the content: it comes up to meet the pointer,
    // leans a few degrees away from it (the pointer's side gives a little,
    // as if it were resting there) and squashes on a press.
    Item {
        id: stage

        anchors.fill: parent
        transformOrigin: Item.Center
        scale: 1 + root.lift * root.hot - 0.05 * root.down
        transform: [
            Rotation {
                origin.x: stage.width / 2
                origin.y: stage.height / 2
                axis {
                    x: 0
                    y: 1
                    z: 0
                }
                angle: root.nx * root.tilt * root.heat
            },
            Rotation {
                origin.x: stage.width / 2
                origin.y: stage.height / 2
                axis {
                    x: 1
                    y: 0
                    z: 0
                }
                angle: -root.ny * root.tilt * root.heat
            }
        ]
    }
}
