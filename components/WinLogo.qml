//  VELVET  ·  components/WinLogo.qml
//  The VINDOWS mark: four panes in a window, parted by a V — wide on top,
//  shut at the bottom. No colours: one ink for all four panes (white, or dark
//  on a light ground). It waves in the old editions (95, XP, 7) and sits flat
//  in the new ones (10, 11). Velvet's own drawing — not Microsoft's logo.
import qs.config
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    // the one ink of the mark
    property color mono: "#ffffff"
    property bool wave: Appearance.winVer === "95" || Appearance.winVer === "xp" || Appearance.winVer === "7"

    implicitWidth: 22
    implicitHeight: 22

    // the four panes as point lists, top-left, bottom-left, top-right, bottom-right
    readonly property var panes: {
        const w = root.width;
        const h = root.height;
        const wave = root.wave;
        const wob = x => wave ? 0.07 * Math.sin(x * Math.PI * 1.9 + 0.3) : 0;
        const X0 = 0.08, X1 = 0.92, Y0 = 0.1, Y1 = 0.9, GH = 0.075;
        // the V between the columns: 0.19 wide on top, closed at the bottom
        const gv = y => 0.19 * (1 - (y - Y0) / (Y1 - Y0));
        const P = (x, y) => Qt.point(x * w, (y + wob(x)) * h);
        const n = wave ? 8 : 1;
        const out = [];
        for (let col = 0; col < 2; col++) {
            for (let row = 0; row < 2; row++) {
                const ya = row === 0 ? Y0 : 0.5 + GH / 2;
                const yb = row === 0 ? 0.5 - GH / 2 : Y1;
                const outer = col === 0 ? X0 : X1;
                const inner = y => col === 0 ? 0.5 - gv(y) / 2 : 0.5 + gv(y) / 2;
                const pts = [];
                for (let k = 0; k <= n; k++)
                    pts.push(P(outer + (inner(ya) - outer) * k / n, ya));
                for (let k = 1; k < n; k++) {
                    const y = ya + (yb - ya) * k / n;
                    pts.push(P(inner(y), y));
                }
                for (let k = 0; k <= n; k++)
                    pts.push(P(inner(yb) + (outer - inner(yb)) * k / n, yb));
                pts.push(pts[0]);
                out.push(pts);
            }
        }
        return out;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.mono
            strokeColor: "transparent"

            PathPolyline {
                path: root.panes[0]
            }
        }
        ShapePath {
            fillColor: root.mono
            strokeColor: "transparent"

            PathPolyline {
                path: root.panes[1]
            }
        }
        ShapePath {
            fillColor: root.mono
            strokeColor: "transparent"

            PathPolyline {
                path: root.panes[2]
            }
        }
        ShapePath {
            fillColor: root.mono
            strokeColor: "transparent"

            PathPolyline {
                path: root.panes[3]
            }
        }
    }
}
