//  VELVET  ·  modules/lock/LockHud.qml
//  The lock of the CYBER look: a quiet sci-fi readout. A ring dial in the middle
//  (the seconds sweep it, sixty ticks on its rim) around the time, telemetry in
//  the corners, and an access code that fills a bar of notched segments.
//  Cyan only where something is happening.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var kit: null

    readonly property real u: Math.max(0.5, Math.min(root.width / 1920, root.height / 1080))
    readonly property color cy: Colours.accent
    readonly property real dial: Math.min(root.height * 0.58, 620 * root.u)

    Rectangle {
        anchors.fill: parent
        color: Colours.paper
    }
    LockWall {
        anchors.fill: parent
        blur: root.kit.blurOr(1)
        dim: root.kit.dimOr(0.9)
        drift: false
    }
    Backdrop {
        anchors.fill: parent
        kind: "grid"
        colour: root.cy
        step: 56 * root.u
        strength: 0.7
    }

    // the corner brackets of the frame
    Repeater {
        model: 4

        Item {
            id: br

            required property int index

            readonly property bool atRight: index % 2 === 1
            readonly property bool atBottom: index > 1

            x: br.atRight ? root.width - 56 * root.u - 70 * root.u : 56 * root.u
            y: br.atBottom ? root.height - 56 * root.u - 70 * root.u : 56 * root.u
            width: 70 * root.u
            height: 70 * root.u

            Rectangle { x: br.atRight ? parent.width - width : 0; y: br.atBottom ? parent.height - height : 0; width: parent.width; height: 2; color: Colours.alpha(root.cy, 0.7) }
            Rectangle { x: br.atRight ? parent.width - width : 0; y: br.atBottom ? parent.height - height : 0; width: 2; height: parent.height; color: Colours.alpha(root.cy, 0.7) }
        }
    }

    // ── the dial
    Item {
        id: dialBox

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.07
        width: root.dial
        height: root.dial

        Canvas {
            id: ring

            anchors.fill: parent
            readonly property int sec: parseInt(root.kit.ss)

            onSecChanged: requestPaint()
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                const c = getContext("2d");
                c.reset();
                const cx = width / 2, cy = height / 2, R = Math.min(cx, cy) - 6;
                const cyan = `${root.cy}`;
                const faint = Qt.rgba(root.cy.r, root.cy.g, root.cy.b, 0.28);
                c.lineWidth = 1.5;
                c.strokeStyle = faint;
                c.beginPath();
                c.arc(cx, cy, R, 0, Math.PI * 2);
                c.stroke();
                c.beginPath();
                c.arc(cx, cy, R * 0.8, 0, Math.PI * 2);
                c.stroke();
                // sixty ticks, every fifth longer
                for (let i = 0; i < 60; i++) {
                    const a = i / 60 * Math.PI * 2 - Math.PI / 2;
                    const long = i % 5 === 0;
                    const r0 = R - (long ? 22 : 11), r1 = R - 2;
                    c.lineWidth = long ? 2.2 : 1.1;
                    c.strokeStyle = i <= sec ? cyan : faint;
                    c.beginPath();
                    c.moveTo(cx + Math.cos(a) * r0, cy + Math.sin(a) * r0);
                    c.lineTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1);
                    c.stroke();
                }
                // the sweep
                c.lineWidth = 4;
                c.strokeStyle = cyan;
                c.beginPath();
                c.arc(cx, cy, R * 0.8, -Math.PI / 2, -Math.PI / 2 + (sec + 1) / 60 * Math.PI * 2);
                c.stroke();
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 4 * root.u

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8 * root.u

                P5Text {
                    display: true
                    text: `${root.kit.hh.padStart(2, "0")}:${root.kit.mm}`
                    color: root.kit.tint(Colours.ink)
                    font.family: root.kit.typeface(Appearance.fontFamily.display)
                    font.pixelSize: root.dial * 0.23 * Math.min(root.kit.clockScale, 1.15)
                    font.weight: Font.Light
                    tracking: 6
                }
                P5Text {
                    anchors.baseline: undefined
                    anchors.bottom: undefined
                    text: root.kit.ss
                    color: root.cy
                    font.pixelSize: root.dial * 0.07
                    tracking: 2
                    y: root.dial * 0.045
                }
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: root.kit.date(root.kit.stamp("dddd · d MMMM")).toUpperCase()
                color: Colours.inkDim
                font.pixelSize: 16 * root.u
                tracking: 5
            }
        }
    }

    // ── telemetry, left and right of the dial
    Repeater {
        model: [
            { side: 0, name: "CPU", v: () => SysInfo.cpuPercent / 100, t: () => `${Math.round(SysInfo.cpuPercent)}%` },
            { side: 0, name: "MEMORY", v: () => SysInfo.memoryPercent / 100, t: () => `${Math.round(SysInfo.memoryPercent)}%` },
            { side: 1, name: "TEMP", v: () => Math.min(1, SysInfo.temperature / 100), t: () => `${Math.round(SysInfo.temperature)}°C` },
            { side: 1, name: Battery.available ? "POWER" : "UPTIME", v: () => Battery.available ? Battery.percent / 100 : 1, t: () => Battery.available ? `${Battery.percent}%` : SysInfo.uptimeText }
        ]

        Item {
            id: tel

            required property var modelData
            required property int index

            x: tel.modelData.side === 0 ? root.width * 0.12 : root.width * 0.88 - width
            y: root.height * (0.2 + (index % 2) * 0.17)
            width: 260 * root.u
            height: 64 * root.u

            P5Text {
                text: tel.modelData.name
                color: Colours.inkDim
                font.pixelSize: 13 * root.u
                tracking: 4
            }
            P5Text {
                anchors.right: parent.right
                text: tel.modelData.t()
                color: Colours.ink
                font.pixelSize: 15 * root.u
                tracking: 2
            }
            Row {
                y: 30 * root.u
                spacing: 3 * root.u

                Repeater {
                    model: 20

                    Rectangle {
                        required property int index

                        width: (tel.width - 19 * 3 * root.u) / 20
                        height: 10 * root.u
                        color: index / 20 < tel.modelData.v() ? root.cy : Colours.alpha(root.cy, 0.16)
                    }
                }
            }
        }
    }

    // ── the access code
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.76
        spacing: 16 * root.u
        transform: Translate { x: root.kit.shake }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.kit.busy ? "VERIFYING…" : (root.kit.failed ? "ACCESS DENIED" : (root.kit.hello !== "" ? root.kit.hello.toUpperCase() : "AWAITING ACCESS CODE"))
            color: root.kit.failed ? Colours.danger : (root.kit.busy ? Colours.warning : root.cy)
            font.pixelSize: 18 * root.u
            tracking: 7
        }
        PassMask {
            anchors.horizontalCenter: parent.horizontalCenter
            kit: root.kit
            colour: root.kit.failed ? Colours.danger : root.cy
            track: Colours.alpha(root.cy, 0.16)
            size: 18 * root.u
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6 * root.u
            scale: root.kit.recoil
            visible: root.kit.mask === "dots"

            Repeater {
                model: 24

                Slash {
                    required property int index

                    readonly property bool lit: index < root.kit.length

                    width: 24 * root.u
                    height: 22 * root.u
                    shear: 0
                    shape: "notch"
                    flat: true
                    color: lit ? (root.kit.failed ? Colours.danger : root.cy) : Colours.alpha(root.cy, 0.12)
                    borderColor: lit ? "transparent" : Colours.alpha(root.cy, 0.3)
                    borderWidth: 1
                }
            }
        }
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.kit.hints || root.kit.caps
            text: root.kit.caps ? "CAPS LOCK ENGAGED" : `${root.kit.showUser ? root.kit.user.toUpperCase() + "  ·  " : ""}SESSION LOCKED  ·  ${root.kit.attempts} FAILED`
            color: root.kit.caps ? Colours.warning : Colours.alpha(Colours.inkDim, 0.9)
            font.pixelSize: 13 * root.u
            tracking: 4
        }
    }

    // ── battery · network, the song, the weather
    LockExtras {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.045
        width: root.width * 0.6
        kit: root.kit
        colour: Colours.alpha(Colours.inkDim, 0.9)
        size: 13 * root.u
        upper: true
    }
}
