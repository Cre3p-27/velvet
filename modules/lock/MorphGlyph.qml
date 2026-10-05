//  VELVET  ·  modules/lock/MorphGlyph.qml
//  One shape of the lock's alphabet, drawn on a canvas — and when `kind`
//  changes, the old shape MORPHS into the new one: both paths interpolate
//  point by point over 350ms on the inspo shells' expressive curve, so the
//  glyph cleanly changes form instead of jumping. This is the engine behind
//  every glyph in the lock: the password dots, the background's mask, the
//  badges on the modules and the editor chips.
//
//  `fill` (0..1) draws a liquid fill rising from the bottom of the shape,
//  for gauges that live inside a glyph — the fluid lock's resource cells.
import QtQuick
import "glyphpaths.js" as GP

Canvas {
    id: root

    Component.onCompleted: {
        root._from = GP.pathFor(root.kind, root._n);
        root._to = root._from;
    }

    property int kind: 0
    property color col: "#ffffff"
    property real fill: -1            // -1 = none · 0..1 = fill from the bottom
    property color fillColour: root.col
    property bool wave: false         // true = the fill's top edge ripples

    implicitWidth: 18
    implicitHeight: 18
    antialiasing: true

    readonly property int _n: 48
    property var _from: []
    property var _to: []
    property real morph: 1

    onKindChanged: {
        // If a morph is still in flight, start from the shape it has
        // actually reached so far. Jumping back to the previous target
        // would make rapid kind changes (hover bursts) snap visibly.
        root._from = (root.morph < 1 && root._from.length > 0 && root._to.length > 0)
            ? GP.interpolate(root._from, root._to, root.morph)
            : root._to;
        root._to = GP.pathFor(root.kind, root._n);
        morphAnim.restart();
    }

    NumberAnimation {
        id: morphAnim

        target: root
        property: "morph"
        from: 0
        to: 1
        duration: 350
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90, 1, 1]
    }

    Behavior on fill {
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
        }
    }

    onMorphChanged: root.requestPaint()
    onFillChanged: root.requestPaint()
    onColChanged: root.requestPaint()
    onFillColourChanged: root.requestPaint()
    onWaveChanged: root.requestPaint()
    onWidthChanged: root.requestPaint()
    onHeightChanged: root.requestPaint()

    onPaint: {
        const ctx = root.getContext("2d");
        ctx.clearRect(0, 0, root.width, root.height);
        if (root._from.length === 0 || root._to.length === 0)
            return;
        const pts = GP.interpolate(root._from, root._to, root.morph);
        const s = Math.min(root.width, root.height) / 2;
        ctx.save();
        ctx.translate(root.width / 2, root.height / 2);
        ctx.scale(s, s);
        ctx.beginPath();
        GP.smoothPath(ctx, pts);
        ctx.fillStyle = root.col;
        ctx.fill();
        if (root.fill >= 0 && root.fillColour.a > 0) {
            // The path is still current — clip to it and flood from below.
            ctx.clip();
            ctx.fillStyle = root.fillColour;
            const h = 2 * Math.max(0, Math.min(1, root.fill));
            if (root.wave) {
                // The fluid lock's wavy liquid edge — the surface ripples instead
                // of cutting straight across.
                ctx.beginPath();
                ctx.moveTo(-1.2, 2);
                const n = 14;
                for (let i = 0; i <= n; i++) {
                    const x = -1.2 + 2.4 * i / n;
                    const y = 2 - h + Math.sin((i / n) * Math.PI * 2) * 0.055;
                    ctx.lineTo(x, y);
                }
                ctx.lineTo(1.2, 2);
                ctx.closePath();
                ctx.fill();
            } else {
                ctx.fillRect(-1.2, 2 - h, 2.4, h);
            }
        }
        ctx.restore();
    }
}
