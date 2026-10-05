//  VELVET  ·  components/M3Shape.qml
//  A soft, Material-3-style shape — cookie, clover, flower, sun, pentagon,
//  circle — drawn as one closed outline and filled. Changing `kind` MORPHS
//  the outline from whatever is on screen now to the new shape, so a widget
//  can change its silhouette with the weather instead of popping.
//
//  Every shape is a radius function r(θ) sampled at the same 192 angles, so
//  any two shapes line up point for point and a morph is a plain blend.
//  The outline stretches to the item's box: a wide box gives a wide shape.
//
//  No idle animation: the outline only moves when `kind` changes (and once
//  on birth when `intro` is on). A still desktop costs nothing.
//
//  `spin` turns the silhouette without re-morphing it (the hover turn of a
//  desktop widget), and `sheen` lays a soft light on it, clipped to the
//  outline itself — both cost nothing while they are 0.
import qs.config
import qs.services
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string kind: "cookie"
    property color color: "white"
    property color borderColor: "transparent"
    property real borderWidth: 0
    // Grow in from a circle when the widget appears.
    property bool intro: true
    property bool motion: true
    // Turn the outline (degrees) — static, so the lobes can be lined up.
    property real turn: 0
    // Turn the drawn silhouette (degrees) — live, no morph, for hover.
    property real spin: 0
    // A radial light on the silhouette at (sheenX, sheenY), in this item's
    // pixels; `sheen` is its strength (0 = not drawn at all).
    property real sheen: 0
    property real sheenX: root.width / 2
    property real sheenY: root.height / 2
    property color sheenColor: "white"

    // Enough points that a twelve-lobed gear stays round at lock size
    // (96 turned its lobes into teeth past ~400 px).
    readonly property int samples: 192

    // Normalised radius (≤ 1) of `kind` at angle `a`.
    function radius(kind: string, a: real): real {
        switch (kind) {
        case "circle":
            return 1;
        case "cookie":      // nine soft scallops
            return 0.93 + 0.07 * Math.cos(9 * a);
        case "sun":         // twelve smaller rays
            return 0.92 + 0.08 * Math.cos(12 * a);
        case "flower":      // six round petals
            return 0.74 + 0.26 * Math.pow(Math.abs(Math.cos(3 * a)), 0.7);
        case "clover":      // four leaves
            return 0.64 + 0.36 * Math.pow(Math.abs(Math.cos(2 * a)), 0.55);
        case "pentagon":    // soft pentagon, a point at the top — smooth, no cusps
            return 0.9 + 0.1 * Math.cos(5 * (a + Math.PI / 2));
        case "burst":       // eight sharp-ish points for thunder
            return 0.72 + 0.28 * Math.pow(Math.abs(Math.cos(4 * a)), 2.2);
        case "scallop":     // eight fat round lobes with creased valleys — the greeting's cloud
            return 0.87 + 0.13 * Math.pow(Math.abs(Math.cos(4 * a)), 0.7);
        case "diamond":     // a square on its point, every corner rounded soft
            return root.polygon(4, a, 0);
        case "penta":       // a true pentagon, point up, corners rounded
            return root.polygon(5, a, -Math.PI / 2);
        case "wavy":        // a circle with a fine ripple — the cover's frame
            return 0.95 + 0.05 * Math.cos(10 * a);
        case "square":      // a square, sides straight, corners rounded
            return root.polygon(4, a, -Math.PI / 4);
        case "triangle":    // point up, corners rounded
            return root.polygon(3, a, -Math.PI / 2);
        case "hexagon":     // flat top and bottom
            return root.polygon(6, a, 0);
        case "star":        // five soft points
            return 0.62 + 0.38 * Math.pow(Math.abs(Math.cos(2.5 * (a + Math.PI / 2))), 1.6);
        case "blob":        // an organic pebble, never quite round
            return 0.86 + 0.07 * Math.cos(3 * a + 0.6) + 0.05 * Math.cos(5 * a + 1.9) + 0.02 * Math.cos(2 * a);
        default:
            return 1;
        }
    }

    // A regular n-gon with softly rounded corners, one corner at `corner`
    // (radians; 0 = right, -π/2 = up). The polygon's own polar form is
    // cos(π/n) / cos(triangle wave); squeezing the wave through asin(k·sin)
    // with k < 1 rounds every corner without a kink.
    function polygon(n: int, a: real, corner: real): real {
        const k = 0.94;
        const x = (a - corner) * n / 2 + Math.PI / 2;
        const tri = (2 / n) * Math.asin(k * Math.sin(x));
        return Math.cos(Math.PI / n) / Math.cos(tri);
    }

    function outline(kind: string): var {
        const out = [];
        const t0 = root.turn * Math.PI / 180;
        let peak = 0;
        for (let i = 0; i < root.samples; i++) {
            const a = i / root.samples * 2 * Math.PI;
            const r = root.radius(kind, a - t0);
            peak = Math.max(peak, r);
            out.push([Math.cos(a) * r, Math.sin(a) * r]);
        }
        // Normalise so every shape fills its box the same way.
        const k = peak > 0 ? 1 / peak : 1;
        for (let j = 0; j < out.length; j++)
            out[j] = [out[j][0] * k, out[j][1] * k];
        return out;
    }

    // Plain values, never bindings: a binding on `_to` would already hold the
    // NEW shape by the time onKindChanged runs, and the morph would start
    // from its own end.
    property var _from: []
    property var _to: []
    property real _t: 1

    onKindChanged: root.restart()
    onTurnChanged: root.restart()

    function restart(): void {
        if (root._to.length === 0)
            return;     // not built yet — onCompleted draws the first shape
        // Start from what is on screen right now, so a morph interrupted by
        // another never jumps.
        root._from = root.current();
        root._to = root.outline(root.kind);
        if (!root.motion) {
            root._t = 1;
            return;
        }
        morph.stop();
        root._t = 0;
        morph.start();
    }

    function current(): var {
        const t = root._t;
        const out = [];
        for (let i = 0; i < root._to.length; i++) {
            const f = root._from[i] ?? root._to[i];
            out.push([f[0] + (root._to[i][0] - f[0]) * t, f[1] + (root._to[i][1] - f[1]) * t]);
        }
        return out;
    }

    Component.onCompleted: {
        root._to = root.outline(root.kind);
        if (root.intro && root.motion) {
            root._from = root.outline("circle");
            root._t = 0;
            morph.start();
        } else {
            root._from = root._to;
            root._t = 1;
        }
    }

    NumberAnimation {
        id: morph

        target: root
        property: "_t"
        from: 0
        to: 1
        duration: Math.round(720 * Config.appearance.animationScale)
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
    }

    // The outline in pixels, shared by the fill and the light.
    readonly property var _px: {
        const pts = root.current();
        const hw = root.width / 2;
        const hh = root.height / 2;
        const out = [];
        for (let i = 0; i < pts.length; i++)
            out.push(Qt.point(hw + pts[i][0] * hw, hh + pts[i][1] * hh));
        if (out.length > 0)
            out.push(out[0]);
        return out;
    }

    // The light is placed in the TURNED shape's own frame, so it stays
    // under the pointer while the silhouette spins beneath it.
    readonly property point _light: {
        const a = -root.spin * Math.PI / 180;
        const cx = root.width / 2;
        const cy = root.height / 2;
        const dx = root.sheenX - cx;
        const dy = root.sheenY - cy;
        return Qt.point(cx + dx * Math.cos(a) - dy * Math.sin(a), cy + dx * Math.sin(a) + dy * Math.cos(a));
    }

    Shape {
        id: drawn

        anchors.fill: parent
        rotation: root.spin
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: root.borderWidth > 0 ? root.borderColor : "transparent"
            strokeWidth: root.borderWidth

            PathPolyline {
                path: root._px
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: root.sheen > 0.003 ? light : null

            PathPolyline {
                path: root.sheen > 0.003 ? root._px : []
            }
        }

        RadialGradient {
            id: light

            centerX: root._light.x
            centerY: root._light.y
            focalX: root._light.x
            focalY: root._light.y
            centerRadius: Math.max(root.width, root.height) * 0.72
            focalRadius: 0

            GradientStop {
                position: 0
                color: Colours.alpha(root.sheenColor, Math.min(1, root.sheen))
            }
            GradientStop {
                position: 0.45
                color: Colours.alpha(root.sheenColor, Math.min(1, root.sheen) * 0.35)
            }
            GradientStop {
                position: 1
                color: Colours.alpha(root.sheenColor, 0)
            }
        }
    }
}
