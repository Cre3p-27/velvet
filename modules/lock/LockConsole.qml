//  VELVET  ·  modules/lock/LockConsole.qml
//  The lock of the TERMINAL look: a login on a text console. A boot log scrolls
//  the facts of the session, the time stands in block pixels, and `velvet login:`
//  waits at the bottom — every key a `*`, a block cursor that blinks, "Login
//  incorrect" when PAM says no.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var kit: null

    readonly property real u: Math.max(0.5, Math.min(root.width / 1920, root.height / 1080))
    readonly property real fs: Math.round(17 * root.u + 3)
    readonly property string mono: Appearance.fontFamily.mono
    readonly property color mint: Colours.accent
    readonly property color dim: Colours.inkDim
    readonly property var glyphs: ({
            "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
            "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
            "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
            "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
            "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
            "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
            "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
            "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
            "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
            "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
            ":": ["0", "0", "1", "0", "1", "0", "0"]
        })

    Rectangle {
        anchors.fill: parent
        color: Colours.paper
    }
    // a whisper of the wallpaper, as if the console were drawn over it
    LockWall {
        anchors.fill: parent
        blur: root.kit.blurOr(1)
        dim: root.kit.dimOr(0.94)
        drift: false
    }

    // ── the log
    Column {
        x: root.width * 0.06
        y: root.height * 0.07
        spacing: 3 * root.u

        Repeater {
            model: {
                const k = root.kit;
                const rows = [
                    { t: `velvet shell ${Qt.application.version || ""} · tty1 · hyprland`.replace("  ", " "), c: "head" },
                    { t: `session locked at ${k.stamp("HH:mm:ss")}`, c: "ok" },
                    { t: `pam service "${Locker.pamConfig || "velvet"}" is answering`, c: "ok" },
                    { t: `user ${k.user} · ${k.attempts} failed ${k.attempts === 1 ? "attempt" : "attempts"}`, c: k.attempts > 0 ? "warn" : "ok" }
                ];
                if (k.showInfo) {
                    if (Battery.available)
                        rows.push({ t: `battery ${Battery.percent}% ${Battery.charging ? "charging" : "discharging"}`, c: Battery.critical ? "warn" : "ok" });
                    rows.push({ t: `network ${(Net.label || "offline").toLowerCase()}`, c: Net.connected ? "ok" : "warn" });
                    rows.push({ t: `cpu ${Math.round(SysInfo.cpuPercent)}% · mem ${Math.round(SysInfo.memoryPercent)}% · up ${SysInfo.uptimeText}`, c: "ok" });
                }
                if (k.mediaLine !== "")
                    rows.push({ t: `now playing ${k.mediaLine.toLowerCase()}`, c: "ok" });
                if (k.weatherLine !== "")
                    rows.push({ t: `weather ${k.weatherLine.toLowerCase()}`, c: "ok" });
                if (k.caps)
                    rows.push({ t: "caps lock is on", c: "warn" });
                return rows;
            }

            Row {
                id: line

                required property var modelData
                required property int index

                spacing: 10 * root.u
                opacity: 0

                Component.onCompleted: reveal.start()

                SequentialAnimation {
                    id: reveal

                    PauseAnimation { duration: 120 + line.index * 110 }
                    NumberAnimation { target: line; property: "opacity"; to: 1; duration: 90 }
                }

                P5Text {
                    text: line.modelData.c === "head" ? "" : (line.modelData.c === "ok" ? "[  ok  ]" : "[ warn ]")
                    color: line.modelData.c === "warn" ? Colours.warning : root.mint
                    font.family: root.mono
                    font.pixelSize: root.fs
                    visible: line.modelData.c !== "head"
                }
                P5Text {
                    text: line.modelData.t
                    color: line.modelData.c === "head" ? root.mint : root.dim
                    font.family: root.mono
                    font.pixelSize: root.fs
                    font.weight: line.modelData.c === "head" ? Font.Bold : Font.Normal
                }
            }
        }
    }

    // ── the time, in block pixels
    Item {
        id: clockBox

        readonly property real cell: Math.max(4, Math.floor(root.height * 0.036 * Math.min(root.kit.clockScale, 1.5) * (root.kit.seconds ? 0.8 : 1)))
        readonly property string text: root.kit.clockPadded

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.27
        width: clockRow.width
        height: 7 * clockBox.cell

        Row {
            id: clockRow

            spacing: clockBox.cell

            Repeater {
                model: clockBox.text.split("")

                Grid {
                    id: dg

                    required property string modelData

                    readonly property var pattern: root.glyphs[dg.modelData] ?? root.glyphs["0"]

                    columns: dg.pattern[0].length
                    rowSpacing: 0
                    columnSpacing: 0

                    Repeater {
                        model: dg.pattern.length * dg.columns

                        Rectangle {
                            required property int index

                            readonly property bool on: dg.pattern[Math.floor(index / dg.columns)].charAt(index % dg.columns) === "1"

                            width: clockBox.cell - 2
                            height: clockBox.cell - 2
                            x: 1
                            color: on ? root.mint : "transparent"
                        }
                    }
                }
            }
        }
    }

    P5Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.27 + 7 * clockBox.cell + 26 * root.u
        visible: text !== ""
        text: Config.lock.vDate === "off" ? "" : "$ date  →  " + root.kit.date(root.kit.stamp("ddd MMM  d HH:mm:ss yyyy"))
        color: root.dim
        font.family: root.mono
        font.pixelSize: root.fs
    }

    // ── the login
    Column {
        x: root.width * 0.06
        y: root.height * 0.74
        spacing: 8 * root.u
        transform: Translate { x: root.kit.shake }

        Row {
            P5Text {
                text: root.kit.hello !== "" ? `${root.kit.hello}: ` : "velvet login: "
                color: root.mint
                font.family: root.mono
                font.pixelSize: root.fs + 2
            }
            P5Text {
                visible: root.kit.showUser
                text: root.kit.user
                color: Colours.ink
                font.family: root.mono
                font.pixelSize: root.fs + 2
            }
        }
        Row {
            P5Text {
                text: "Password: "
                color: root.mint
                font.family: root.mono
                font.pixelSize: root.fs + 2
            }
            P5Text {
                visible: !root.kit.busy
                text: root.kit.mask === "none" ? "" : (root.kit.mask === "count" ? (root.kit.length > 0 ? `[${root.kit.length}]` : "") : (root.kit.mask === "bar" ? "▮".repeat(Math.min(root.kit.length, 40)) : "*".repeat(root.kit.length)))
                color: Colours.ink
                font.family: root.mono
                font.pixelSize: root.fs + 2
            }
            P5Text {
                id: spin

                visible: root.kit.busy
                text: "authenticating " + ["|", "/", "-", "\\"][Math.floor(Date.now() / 120) % 4]
                color: Colours.warning
                font.family: root.mono
                font.pixelSize: root.fs + 2

                Timer {
                    running: root.kit.busy
                    interval: 120
                    repeat: true
                    onTriggered: spin.text = "authenticating " + ["|", "/", "-", "\\"][Math.floor(Date.now() / 120) % 4]
                }
            }
            Rectangle {
                visible: !root.kit.busy
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round((root.fs + 2) * 0.6)
                height: root.fs + 4
                color: root.mint

                SequentialAnimation on opacity {
                    running: !root.kit.busy
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 520 }
                    NumberAnimation { to: 1; duration: 520 }
                }
            }
        }
        P5Text {
            visible: root.kit.failed
            text: root.kit.message && root.kit.message !== "WRONG PASSWORD" && root.kit.attempts === 0 ? root.kit.message.toLowerCase() : "Login incorrect"
            color: Colours.danger
            font.family: root.mono
            font.pixelSize: root.fs + 2
        }
    }

    // the keys, bottom right, in the voice of a man page
    P5Text {
        anchors.right: parent.right
        anchors.rightMargin: root.width * 0.06
        y: root.height * 0.74
        horizontalAlignment: Text.AlignRight
        visible: root.kit.hints
        text: "enter   log in\nesc     clear the line"
        color: Colours.alpha(root.dim, 0.8)
        font.family: root.mono
        font.pixelSize: root.fs - 1
        lineHeight: 1.3
    }
}
