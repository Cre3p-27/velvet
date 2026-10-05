//  VELVET  ·  Resources — two minutes of CPU and memory, drawn as a filled
//  sparkline. A number tells you the moment; a graph tells you whether you are
//  climbing out of a spike or into one.
import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property bool vertical: true
    property int span: 30
    property var win: null

    readonly property real graphW: root.vertical ? root.span : Math.round(root.span * 2.6)
    readonly property real graphH: root.vertical ? Math.round(root.span * 1.5) : Math.round(root.span * 0.62)

    implicitWidth: root.vertical ? root.span : root.graphW
    implicitHeight: root.vertical ? root.graphH + label.implicitHeight : root.span

    // Lifts toward the pointer, so the graph feels like a physical thing
    // before the quick panel slides out.
    scale: ma.containsMouse ? 1.06 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutBack
            easing.overshoot: 2.4
        }
    }

    // Turns a history array into a closed polygon hugging the bottom edge.
    function trace(history: var, w: real, h: real): var {
        const n = SysInfo.historyLength;
        const pts = [Qt.point(0, h)];
        if (!history || history.length === 0)
            return pts.concat([Qt.point(w, h), Qt.point(0, h)]);

        // Right-align so the newest sample is always at the leading edge.
        const offset = n - history.length;
        // historyLength is 1 only in pathological configs — but a zero
        // divisor here would flood the paths with NaN points.
        const denom = Math.max(1, n - 1);
        for (let i = 0; i < history.length; i++) {
            const x = ((offset + i) / denom) * w;
            const y = h - Math.max(0, Math.min(1, history[i] / 100)) * h;
            pts.push(Qt.point(x, y));
        }
        pts.push(Qt.point(w, h));
        pts.push(Qt.point(0, h));
        return pts;
    }

    Item {
        id: graph

        width: root.graphW
        height: root.graphH
        x: root.vertical ? 0 : 0
        y: root.vertical ? 0 : (root.span - height) / 2

        Slash {
            anchors.fill: parent
            shear: 0
            color: Colours.alpha(Colours.ink, 0.07)
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // Memory sits behind, CPU in front — CPU is the one you watch.
            ShapePath {
                fillColor: Colours.alpha(Colours.accentAlt, 0.35)
                strokeColor: Colours.alpha(Colours.accentAlt, 0.7)
                strokeWidth: 1

                PathPolyline {
                    path: root.trace(SysInfo.memHistory, graph.width, graph.height)
                }
            }

            ShapePath {
                fillColor: Colours.alpha(Colours.accent, 0.4)
                strokeColor: Colours.accent
                strokeWidth: 1.5

                PathPolyline {
                    path: root.trace(SysInfo.cpuHistory, graph.width, graph.height)
                }
            }
        }

        // Current value, sitting on the graph rather than beside it.
        P5Text {
            anchors.right: parent.right
            anchors.rightMargin: 3
            anchors.top: parent.top
            anchors.topMargin: 1
            display: true
            text: `${Math.round(SysInfo.cpuPercent)}`
            color: SysInfo.cpuPercent > 85 ? Colours.danger : Colours.ink
            font.pixelSize: Config.bar.fontSize * 0.74
            tracking: 0
        }
    }

    P5Text {
        id: label

        visible: root.vertical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: graph.bottom
        text: `${Math.round(SysInfo.memoryPercent)}%`
        color: Colours.inkDim
        font.pixelSize: Config.bar.fontSize * 0.7
    }

    MouseArea {
        id: ma

        anchors.fill: parent
        hoverEnabled: true
        onEntered: Popout.request("quick", root, root.win)
        onExited: Popout.release("quick")
    }
}
