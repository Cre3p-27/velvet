//  VELVET  ·  components/WinLogo.qml
//  Four panes in a window: a small flag that waves in the old editions
//  (95, XP, 7) and sits flat in the new ones (10, 11). One colour per pane,
//  or one colour for all.
import qs.config
import QtQuick

Item {
    id: root

    // "" = the four colours; any colour paints all four panes with it
    property color mono: "transparent"
    property bool wave: Appearance.winVer === "95" || Appearance.winVer === "xp" || Appearance.winVer === "7"

    implicitWidth: 22
    implicitHeight: 22

    readonly property bool plain: root.mono.a > 0
    readonly property var colours: root.plain ? [root.mono, root.mono, root.mono, root.mono] : ["#f25022", "#7fba00", "#00a4ef", "#ffb900"]

    // the flat logo
    Grid {
        anchors.centerIn: parent
        visible: !root.wave
        columns: 2
        spacing: Math.max(2, Math.round(root.width * 0.1))

        Repeater {
            model: 4

            Rectangle {
                required property int index

                width: (root.width * 0.86 - Math.max(2, Math.round(root.width * 0.1))) / 2
                height: width
                color: root.colours[index]
            }
        }
    }

    // the waving one
    Canvas {
        id: flag

        anchors.fill: parent
        visible: root.wave
        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
        Component.onCompleted: requestPaint()

        Connections {
            target: root

            function onColoursChanged(): void {
                flag.requestPaint();
            }
        }

        onPaint: {
            const c = getContext("2d");
            c.clearRect(0, 0, width, height);
            const w = width;
            const h = height;
            const wob = x => 0.07 * Math.sin(x * Math.PI * 1.9 + 0.3);
            for (let i = 0; i < 4; i++) {
                const col = i % 2;
                const row = Math.floor(i / 2);
                const x0 = 0.06 + col * 0.49;
                const x1 = x0 + 0.43;
                const y0 = 0.1 + row * 0.47;
                const y1 = y0 + 0.4;
                c.beginPath();
                const steps = 6;
                for (let k = 0; k <= steps; k++) {
                    const x = x0 + (x1 - x0) * k / steps;
                    const px = x * w;
                    const py = (y0 + wob(x)) * h;
                    if (k === 0)
                        c.moveTo(px, py);
                    else
                        c.lineTo(px, py);
                }
                for (let k = steps; k >= 0; k--) {
                    const x = x0 + (x1 - x0) * k / steps;
                    c.lineTo(x * w, (y1 + wob(x)) * h);
                }
                c.closePath();
                c.fillStyle = `${root.colours[i]}`;
                c.fill();
            }
        }
    }
}
