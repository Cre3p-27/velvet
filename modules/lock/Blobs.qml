//  VELVET  ·  modules/lock/Blobs.qml
//  The fluid half of the lock: soft gradient blobs in the wallpaper's
//  own colours, slowly morphing. No shader — the same Shape machinery the
//  rest of the shell already uses. Every hue comes from Colours, so the
//  field re-tints itself the moment the wallpaper does.
//
//  Loaded by path from FluidLock.qml like every other decorative layer:
//  if this file ever fails on some machine, the lock loses its fluid and
//  nothing else.
import qs.services
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    clip: true
    opacity: 0.9

    readonly property real u: Math.max(width, height)

    // ------------------------------------------------------------- one blob
    // A square ShapePath filled with a radial gradient whose last stop is
    // transparent, so it renders as a soft-edged circle. Centre, focus and
    // spread are fractions of the blob's own size — the motion reads the
    // same on every monitor. `…Base` properties stay fixed while the live
    // values wander around them, so the cycles never drift.
    component Blob: Shape {
        id: blob

        property color tint: Colours.accent
        property real glow: 0.4             // peak alpha at the core
        property real size: 1.0             // × root.u
        property int period: 23000          // unharmonic per blob

        property real spreadBase: 0.55
        property real driftXBase: 0.5
        property real driftYBase: 0.5
        property real cxBase: 0.5
        property real pulse: 0.06

        property real spread: spreadBase
        property real driftX: driftXBase
        property real driftY: driftYBase
        property real cx: cxBase

        width: root.u * size
        height: width
        x: driftX * (root.width - width)
        y: driftY * (root.height - height)

        preferredRendererType: Shape.CurveRenderer
        asynchronous: true

        ShapePath {
            // no outline: a ShapePath strokes 1 px white unless told not to
            strokeColor: "transparent"
            strokeWidth: -1
            fillColor: "transparent"

            fillGradient: RadialGradient {
                centerX: blob.cx * blob.width
                centerY: 0.5 * blob.height
                focalX: (blob.cx - 0.08) * blob.width
                focalY: 0.46 * blob.height
                centerRadius: blob.spread * blob.width / 2
                focalRadius: 0

                GradientStop {
                    position: 0.0
                    color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, blob.glow)
                }
                GradientStop {
                    position: 0.6
                    color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, blob.glow * 0.38)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0)
                }
            }

            PathPolyline {
                path: [
                    Qt.point(0, 0),
                    Qt.point(blob.width, 0),
                    Qt.point(blob.width, blob.height),
                    Qt.point(0, blob.height),
                    Qt.point(0, 0)
                ]
            }
        }

        // The whole field is one unharmonic cycle: every blob drifts on its
        // own period and breathes on a different one, so nothing repeats.
        ParallelAnimation {
            running: true
            loops: Animation.Infinite

            SequentialAnimation {
                NumberAnimation {
                    target: blob
                    property: "driftX"
                    from: blob.driftXBase - 0.16
                    to: blob.driftXBase + 0.16
                    duration: blob.period
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: blob
                    property: "driftX"
                    from: blob.driftXBase + 0.16
                    to: blob.driftXBase - 0.16
                    duration: blob.period
                    easing.type: Easing.InOutSine
                }
            }
            SequentialAnimation {
                NumberAnimation {
                    target: blob
                    property: "driftY"
                    from: blob.driftYBase - 0.12
                    to: blob.driftYBase + 0.12
                    duration: Math.round(blob.period * 1.27)
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: blob
                    property: "driftY"
                    from: blob.driftYBase + 0.12
                    to: blob.driftYBase - 0.12
                    duration: Math.round(blob.period * 1.27)
                    easing.type: Easing.InOutSine
                }
            }
            SequentialAnimation {
                NumberAnimation {
                    target: blob
                    property: "cx"
                    from: blob.cxBase - blob.pulse
                    to: blob.cxBase + blob.pulse
                    duration: Math.round(blob.period * 0.73)
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: blob
                    property: "cx"
                    from: blob.cxBase + blob.pulse
                    to: blob.cxBase - blob.pulse
                    duration: Math.round(blob.period * 0.73)
                    easing.type: Easing.InOutSine
                }
            }
            SequentialAnimation {
                NumberAnimation {
                    target: blob
                    property: "spread"
                    from: blob.spreadBase - 0.05
                    to: blob.spreadBase + 0.05
                    duration: Math.round(blob.period * 1.61)
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: blob
                    property: "spread"
                    from: blob.spreadBase + 0.05
                    to: blob.spreadBase - 0.05
                    duration: Math.round(blob.period * 1.61)
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    // ------------------------------------------------------------ the field
    Blob {
        // The main event: one large, hot shape left of centre — the
        // reference lock's single morphing ribbon, in wallpaper colours.
        tint: Colours.accentHot
        glow: 0.85
        size: 1.3
        spreadBase: 0.68
        driftXBase: 0.32
        driftYBase: 0.42
        pulse: 0.1
        period: 27000
    }

    Blob {
        tint: Colours.accentDeep
        glow: 0.5
        size: 1.0
        spreadBase: 0.6
        driftXBase: 0.72
        driftYBase: 0.34
        pulse: 0.07
        period: 34000
    }

    Blob {
        tint: Colours.accent
        glow: 0.45
        size: 0.62
        spreadBase: 0.55
        driftXBase: 0.5
        driftYBase: 0.62
        pulse: 0.08
        period: 23000
    }
}
