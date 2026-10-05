//  VELVET  ·  components/Jagged.qml
//  Torn-paper panel. The edges are pseudo-random but seeded, so a given panel
//  looks identical every time it opens — it reads as a shape, not as noise.
import qs.config
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color color: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0
    property int seed: 7
    property real amplitude: 9      // how deep the tears bite, in px
    property int teeth: 7           // notches per long edge
    property real shear: 0

    // Deterministic LCG — same seed, same silhouette, forever.
    readonly property var _points: {
        const w = width;
        const h = height;
        const a = amplitude;
        const o = Math.tan(shear * Math.PI / 180) * h;
        const pts = [];
        let s = seed * 7919 + 13;

        const step = (n, from, to) => {
            const out = [];
            for (let i = 0; i < n; i++)
                out.push(from + (to - from) * (i / n));
            return out;
        };

        const jitter = () => {
            s = (1103515245 * s + 12345) % 2147483648;
            return ((s / 2147483648) - 0.5) * 2 * a;
        };

        const hTeeth = Math.max(2, teeth);
        const vTeeth = Math.max(2, Math.round(teeth * (h / Math.max(1, w)) * 1.6));

        // top edge, left → right
        for (const x of step(hTeeth, o, w))
            pts.push(Qt.point(x, Math.max(0, jitter() * 0.5 + a * 0.5)));
        // right edge, top → bottom
        for (const y of step(vTeeth, 0, h))
            pts.push(Qt.point(w - (y / Math.max(1, h)) * o + jitter() * 0.4 - a * 0.5, y));
        // bottom edge, right → left
        for (const x of step(hTeeth, w - o, 0))
            pts.push(Qt.point(x, h - Math.max(0, jitter() * 0.5 + a * 0.5)));
        // left edge, bottom → top
        for (const y of step(vTeeth, h, 0))
            pts.push(Qt.point((1 - y / Math.max(1, h)) * o + jitter() * 0.4 + a * 0.5, y));

        pts.push(pts[0]);
        return pts;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Torn edges are the most expensive shape in the shell and never the
        // reason you opened a panel, so they are allowed to arrive a frame
        // late rather than holding the frame up.
        asynchronous: true

        ShapePath {
            fillColor: root.color
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth
            joinStyle: ShapePath.MiterJoin

            PathPolyline {
                path: root._points
            }
        }
    }
}
