//  VELVET  ·  components/SpectrumEdge.qml
//  The music along a screen edge — drawn by the shell itself from
//  Spectrum's bands, so it stands exactly ON the edge (no terminal, no
//  padding, no cell grid): a smooth filled WAVE, rounded BARS or a thin
//  LINE. The lock wears it (LOCK SCREEN → CLOCK & SOUND), so can the
//  wallpaper (MODULES → AUDIO-REACTIVE → WALLPAPER WAVE).
//
//  The sidecar writes about 30 frames a second; the curve eases toward
//  them at the screen's own rate, so it glides instead of stepping. The
//  bands come in cava's stereo order — the lows meet in the middle, the
//  highs run out to the ends — and a quiet room fades it away rather than
//  leaving a flat strip behind.
import qs.services
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string edge: "bottom"     // bottom | top | left | right
    property string style: "wave"      // wave | bars | line
    property real reach: 160           // how far it may rise from the edge, px
    property color colour: Colours.accent
    // The crest: the same accent, lifted — one colour family, like a real wave.
    property color tip: Qt.tint(Colours.accent, Qt.rgba(1, 1, 1, 0.32))
    property real strength: 0.92       // opacity with music playing
    property bool running: true
    // A preview's switches (DESKTOP → CAVA): lows→highs once instead of
    // cava's mirrored stereo, the other way round, and a calm demo swell
    // while nothing plays, so the look can always be seen.
    property bool mono: false
    property bool reversed: false
    property bool demo: false
    // The bars: one every barPitch px, barFill of that is bar.
    property real barPitch: 16
    property real barFill: 0.5
    property bool roundBars: true
    readonly property bool playing: Spectrum.live && Spectrum.count > 0

    readonly property bool side: root.edge === "left" || root.edge === "right"
    readonly property int bands: root.playing ? Spectrum.count : 24
    readonly property int points: Math.max(2, root.mono ? Math.ceil(root.bands / 2) : root.bands)
    // A hairline that never sinks into the edge while the music plays.
    readonly property real floor: 3

    // The values on screen, eased toward Spectrum's.
    property var shown: []

    opacity: (root.playing || root.demo) && root.running ? root.strength : 0
    visible: root.opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: 700
            easing.type: Easing.OutCubic
        }
    }

    // A gentle lift: quiet passages still move the curve, loud ones round
    // off towards the reach instead of slamming into it.
    property real clock: 0

    // The raw band for point i — the music, or the demo's swell.
    function band(i: int): real {
        const n = root.points;
        let k = root.reversed ? n - 1 - i : i;
        if (!root.playing) {
            // Three slow waves that never line up: alive, never busy.
            const x = n > 1 ? k / (n - 1) : 0;
            const t = root.clock;
            const v = 0.36 + 0.22 * Math.sin(x * 7.1 + t * 1.3) + 0.16 * Math.sin(x * 13.7 - t * 2.1) + 0.1 * Math.sin(x * 3.3 + t * 0.7);
            return Math.max(0.03, Math.min(0.95, v * (root.mono ? 1.05 - 0.55 * x : 1)));
        }
        if (root.mono) {
            // cava's stereo is mirrored (highs out, lows in the middle): the
            // right half runs lows → highs.
            const half = Math.floor(Spectrum.count / 2);
            return Spectrum.at(Math.min(Spectrum.count - 1, half + k));
        }
        return Spectrum.at(k);
    }

    // A gentle lift: quiet passages still move the curve, loud ones round
    // off towards the reach instead of slamming into it.
    function target(i: int): real {
        const b = Number(root.band(i));
        const v = Number.isFinite(b) ? Math.min(1, Math.max(0, b)) : 0;
        return 1 - (1 - v) * (1 - v);
    }

    // The curve between the bands at t (0..1 along the edge) — so there can
    // be many more thin bars than there are bands.
    function sample(vals: var, t: real): real {
        const n = vals.length;
        if (n === 0)
            return 0;
        if (n === 1)
            return vals[0];
        const f = Math.max(0, Math.min(1, t)) * (n - 1);
        const k = Math.min(n - 2, Math.floor(f));
        const u = f - k;
        const p0 = vals[Math.max(0, k - 1)];
        const p1 = vals[k];
        const p2 = vals[k + 1];
        const p3 = vals[Math.min(n - 1, k + 2)];
        const v = 0.5 * (2 * p1 + (p2 - p0) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (3 * p1 - p0 - 3 * p2 + p3) * u * u * u);
        return Math.max(0, Math.min(1, v));
    }

    // A Catmull-Rom curve through the points as cubic Béziers — round hills,
    // no corners, and never above the reach or below the edge.
    function curve(vals: var, w: real, h: real, closed: bool): string {
        const n = vals.length;
        if (n < 2 || !(w > 0) || !(h > 0) || !Number.isFinite(w) || !Number.isFinite(h))
            return "";
        const step = w / (n - 1);
        const room = h - root.floor;
        const ys = [];
        for (let i = 0; i < n; i++)
            ys.push(h - root.floor - Math.min(1, Math.max(0, Number.isFinite(vals[i]) ? vals[i] : 0)) * room);
        const clampY = y => Math.max(0, Math.min(h, y));
        let d = closed ? `M 0 ${h} L 0 ${ys[0].toFixed(1)}` : `M 0 ${ys[0].toFixed(1)}`;
        for (let i = 0; i < n - 1; i++) {
            const y0 = ys[Math.max(0, i - 1)];
            const y1 = ys[i];
            const y2 = ys[i + 1];
            const y3 = ys[Math.min(n - 1, i + 2)];
            const x1 = i * step;
            const x2 = x1 + step;
            d += ` C ${(x1 + step / 3).toFixed(1)} ${clampY(y1 + (y2 - y0) / 6).toFixed(1)} ${(x2 - step / 3).toFixed(1)} ${clampY(y2 - (y3 - y1) / 6).toFixed(1)} ${x2.toFixed(1)} ${y2.toFixed(1)}`;
        }
        if (closed)
            d += ` L ${w.toFixed(1)} ${h} Z`;
        return d;
    }

    FrameAnimation {
        id: tick

        property real since: 0

        // Not `visible` alone: a parent that sets `visible` on this item (the
        // CAVA drawn on the wallpaper does) replaces the binding above, and an
        // invisible-by-opacity edge kept the whole wallpaper repainting at
        // full frame rate in silence (measured: 54 frames a second, ~5 % CPU).
        running: root.visible && root.opacity > 0.01
        onTriggered: {
            root.clock += tick.frameTime;
            const n = root.points;
            let s = root.shown;
            if (!s || s.length !== n) {
                s = [];
                for (let i = 0; i < n; i++)
                    s.push(0);
            }
            // Up quickly, down gently — at any frame rate.
            const up = 1 - Math.exp(-tick.frameTime * 22);
            const down = 1 - Math.exp(-tick.frameTime * 9);
            const next = [];
            for (let i = 0; i < n; i++) {
                const t = root.target(i);
                const was = Number.isFinite(s[i]) ? s[i] : 0;
                const v = was + (t - was) * (t > was ? up : down);
                // one bad number would make the whole path NaN — and Qt's
                // triangulator crash on it (the shell died like that)
                next.push(Number.isFinite(v) ? Math.max(0, Math.min(1, v)) : 0);
            }
            root.shown = next;
            // The path is rebuilt at most ~90 times a second; the bars
            // follow `shown` on their own.
            tick.since += tick.frameTime;
            if (root.style === "bars" || tick.since < 1 / 90)
                return;
            tick.since = 0;
            const d = root.curve(next, canvas.width, canvas.height, root.style === "wave");
            fillPath.path = root.style === "wave" ? d : "";
            linePath.path = root.style === "line" ? d : "";
        }
    }

    // Drawn standing on the bottom, then turned onto the edge it belongs to.
    Item {
        id: canvas

        width: root.side ? root.height : root.width
        height: Math.max(8, root.reach)
        x: (root.side ? (root.edge === "left" ? canvas.height / 2 : root.width - canvas.height / 2) : root.width / 2) - canvas.width / 2
        y: (root.side ? root.height / 2 : (root.edge === "top" ? canvas.height / 2 : root.height - canvas.height / 2)) - canvas.height / 2
        rotation: ({
                bottom: 0,
                top: 180,
                left: 90,
                right: -90
            })[root.edge] ?? 0

        // The geometry renderer, not the curve renderer: this path changes up
        // to 90 times a second, and the curve renderer's triangulation crashed
        // the shell on it once (qTriangulate in QSGCurveProcessor::processFill).
        // Smooth edges come from 4x multisampling while it is on screen.
        Shape {
            anchors.fill: parent
            visible: root.style !== "bars"
            preferredRendererType: Shape.GeometryRenderer
            // (on the wish to be seen, not on the opacity itself: reading
            // the fading opacity here was reported as a binding loop)
            layer.enabled: root.style !== "bars" && (root.playing || root.demo) && root.running
            layer.samples: 4

            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: 0
                    y2: canvas.height
                    GradientStop {
                        position: 0
                        color: root.tip
                    }
                    GradientStop {
                        position: 1
                        color: root.colour
                    }
                }

                PathSvg {
                    id: fillPath
                }
            }

            ShapePath {
                strokeWidth: 3
                strokeColor: root.tip
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    id: linePath
                }
            }
        }

        // Thin rounded bars, one every ~16 px, riding the same curve.
        Repeater {
            id: bars

            model: root.style === "bars" ? Math.max(4, Math.round(canvas.width / Math.max(2, root.barPitch))) : 0

            Rectangle {
                required property int index

                readonly property real step: canvas.width / bars.count
                readonly property real v: root.sample(root.shown, bars.count > 1 ? index / (bars.count - 1) : 0)

                width: Math.max(1, Math.min(root.barPitch > 16 ? step : 8, step * root.barFill))
                height: Math.max(root.roundBars ? width : 1, root.floor + v * (canvas.height - root.floor))
                x: index * step + (step - width) / 2
                y: canvas.height - height
                radius: root.roundBars ? width / 2 : 0
                color: Qt.tint(root.colour, Qt.rgba(root.tip.r, root.tip.g, root.tip.b, v * 0.85))
                antialiasing: true
            }
        }
    }
}
