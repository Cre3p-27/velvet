//  VELVET  ·  components/SlashSlider.qml
//  The one slider used everywhere. Sheared track, hard handle, drags and
//  scrolls, and reports every intermediate value so things move live.
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    property real value: 0          // 0..1
    property real step: 0.02
    property bool interactive: true
    property color tint: Colours.accent
    property real trackHeight: 10
    property real handleWidth: 7
    property real shear: Appearance.skew * 1.6
    property bool showHandle: true
    // Off: the wheel passes through to whatever scrolls behind the slider
    // (a list of settings must scroll, not change the value it rolls over).
    property bool wheel: true

    signal moved(real value)
    signal released(real value)

    implicitHeight: Math.max(trackHeight, 22)

    // The drag lives in `_drag`, never in `value`: writing `value` from in
    // here destroyed the caller's binding (value: Audio.volume, …) and the
    // slider went stale the first time it was touched.
    property real _drag: -1
    readonly property real clamped: Math.max(0, Math.min(1, _drag >= 0 ? _drag : value))
    readonly property real fillWidth: Math.max(root.trackHeight * 0.6, root.width * clamped)

    // FIDGET FEEL: a tick at every twentieth of the way, louder as it fills,
    // and a firmer one at either end — a dial with notches under the hand
    property int _notch: -1

    function _detent(v: real): void {
        const n = Math.round(v * 20);
        if (root._notch >= 0 && n !== root._notch)
            Sfx.tick(n === 0 || n === 20 ? 0.9 : 0.25 + v * 0.45);
        root._notch = n;
    }

    function _apply(x: real, commit: bool): void {
        const v = Math.max(0, Math.min(1, x / Math.max(1, root.width)));
        root._detent(v);
        root._drag = v;
        root.moved(v);
        if (commit) {
            root.released(v);
            root._settle();
        }
    }

    function nudge(delta: real): void {
        const v = Math.max(0, Math.min(1, root.clamped + delta));
        root._notch = -1;
        Sfx.tick(v <= 0 || v >= 1 ? 0.9 : 0.25 + v * 0.45);
        root._drag = v;
        root.moved(v);
        root.released(v);
        root._settle();
    }

    // Hand the display back to `value` once the caller has had its turn to
    // update it — the handle does not flick back to the old value meanwhile.
    function _settle(): void {
        Qt.callLater(() => root._drag = -1);
    }

    Slash {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        shear: root.shear
        color: Colours.alpha(Colours.ink, 0.13)
        borderColor: Colours.alpha(Colours.ink, 0.18)
        borderWidth: 1
    }

    Slash {
        id: fill

        anchors.verticalCenter: parent.verticalCenter
        width: root.fillWidth
        height: root.trackHeight
        shear: root.shear
        color: root.tint

        Behavior on width {
            enabled: !area.pressed
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }
    }

    Slash {
        id: handle

        visible: root.showHandle
        anchors.verticalCenter: parent.verticalCenter
        width: root.handleWidth
        height: root.trackHeight + (area.pressed ? 12 : (area.containsMouse ? 9 : 6))
        x: Math.min(root.width - width, Math.max(0, fill.width - width / 2))
        shear: root.shear
        color: Colours.ink

        Behavior on height {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
            }
        }
        Behavior on x {
            enabled: !area.pressed
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -6
        enabled: root.interactive
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        onPressed: event => {
            root._notch = -1;
            root._apply(event.x - 6, false);
        }
        onPositionChanged: event => {
            if (pressed)
                root._apply(event.x - 6, false);
        }
        onReleased: event => root._apply(event.x - 6, true)
        onWheel: event => {
            if (!root.wheel) {
                event.accepted = false;
                return;
            }
            root.nudge(event.angleDelta.y > 0 ? root.step : -root.step);
        }
    }
}
