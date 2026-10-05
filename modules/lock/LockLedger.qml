//  VELVET  ·  modules/lock/LockLedger.qml
//  The lock of the PAPER look: the front page of a newspaper. The masthead with
//  its double rule, the time as the day's big number, a headline that says what
//  happened (the desk is locked), the weather and the music as small columns, and
//  a subscriber's box to type the password into — a line to write on.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var kit: null

    readonly property real u: Math.max(0.5, Math.min(root.width / 1920, root.height / 1080))
    readonly property color ink: Colours.ink
    readonly property color red: Colours.accent
    readonly property real m: root.width * 0.07

    Rectangle {
        anchors.fill: parent
        color: Colours.paper
    }
    LockWall {
        anchors.fill: parent
        blur: root.kit.blurOr(1)
        dim: root.kit.dimOr(0.94)
        drift: false
    }

    // ── masthead
    Item {
        x: root.m
        y: root.height * 0.05
        width: root.width - root.m * 2
        height: 190 * root.u

        P5Text { text: "VOL. 8  ·  NO. 33"; color: Colours.inkDim; font.pixelSize: 15 * root.u; font.italic: true }
        P5Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.kit.date(root.kit.stamp("dddd, d MMMM yyyy")); color: Colours.inkDim; font.pixelSize: 15 * root.u; font.italic: true }
        P5Text { anchors.right: parent.right; text: "LATE CITY EDITION · FREE"; color: Colours.inkDim; font.pixelSize: 15 * root.u; font.italic: true }

        Rectangle { y: 30 * root.u; width: parent.width; height: 4 * root.u; color: root.ink }
        Rectangle { y: 40 * root.u; width: parent.width; height: 1.5 * root.u; color: root.ink }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 52 * root.u
            display: true
            text: "THE VELVET GAZETTE"
            color: root.ink
            font.pixelSize: 92 * root.u
            tracking: 4
        }
        Rectangle { y: 168 * root.u; width: parent.width; height: 1.5 * root.u; color: root.ink }
        Row {
            y: 176 * root.u
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 36 * root.u

            Repeater {
                model: ["SESSION", "SECURITY", "WEATHER", "MUSIC", "SYSTEM"]

                P5Text {
                    required property string modelData

                    text: modelData
                    color: Colours.inkDim
                    font.pixelSize: 13 * root.u
                    tracking: 4
                }
            }
        }
    }

    // ── the headline and the day's number
    Item {
        x: root.m
        y: root.height * 0.33
        width: root.width - root.m * 2
        height: root.height * 0.36

        // left: the story
        Column {
            width: parent.width * 0.5
            spacing: 14 * root.u

            P5Text {
                width: parent.width
                display: true
                text: root.kit.hello !== "" ? root.kit.hello.toUpperCase() : "THE DESK IS LOCKED"
                color: root.ink
                font.pixelSize: 76 * root.u
                font.italic: true
                wrapMode: Text.WordWrap
            }
            P5Text {
                width: parent.width
                text: `Nobody has been at the keyboard since ${root.kit.stamp("HH:mm")}. ${root.kit.showUser ? root.kit.name : "The owner"} is asked to identify themselves with a password. ${root.kit.attempts > 0 ? `${root.kit.attempts} ${root.kit.attempts === 1 ? "attempt has" : "attempts have"} failed so far.` : "No failed attempts have been reported."}`
                color: Colours.inkDim
                font.pixelSize: 21 * root.u
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }
            Row {
                spacing: 28 * root.u

                Repeater {
                    model: {
                        const out = [];
                        if (root.kit.showInfo) {
                            out.push({ k: "WEATHER", v: Weather.ready ? `${Math.round(Weather.temperature)}° ${Weather.description}` : "—" });
                            out.push({ k: "SYSTEM", v: `CPU ${Math.round(SysInfo.cpuPercent)}% · MEM ${Math.round(SysInfo.memoryPercent)}%` });
                            out.push({ k: Battery.available ? "POWER" : "NETWORK", v: Battery.available ? `${Battery.percent}%${Battery.charging ? " ⚡" : ""}` : (Net.label || "offline") });
                        }
                        if (root.kit.mediaLine !== "")
                            out.push({ k: "MUSIC", v: root.kit.mediaLine });
                        else if (root.kit.weatherLine !== "" && !root.kit.showInfo)
                            out.push({ k: "WEATHER", v: root.kit.weatherLine });
                        return out;
                    }

                    Column {
                        required property var modelData

                        spacing: 2 * root.u

                        P5Text { text: modelData.k; color: root.red; font.pixelSize: 12 * root.u; font.weight: Font.Black; tracking: 3 }
                        P5Text { text: modelData.v; color: root.ink; font.pixelSize: 18 * root.u; font.italic: true }
                    }
                }
            }
        }

        // right: the number
        Item {
            id: numberBox

            anchors.right: parent.right
            width: parent.width * 0.42
            height: parent.height

            Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2 * root.u; border.color: root.ink }
            Rectangle { x: 8 * root.u; y: 8 * root.u; width: parent.width - 16 * root.u; height: parent.height - 16 * root.u; color: "transparent"; border.width: 1; border.color: Colours.alpha(root.ink, 0.5) }

            Column {
                anchors.centerIn: parent
                spacing: 4 * root.u

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "THE HOUR"
                    color: root.red
                    font.pixelSize: 15 * root.u
                    font.weight: Font.Black
                    tracking: 8
                }
                FitClock {
                    anchors.horizontalCenter: parent.horizontalCenter
                    display: true
                    text: root.kit.clockText
                    font.family: root.kit.typeface(Appearance.fontFamily.display)
                    color: root.kit.tint(root.ink)
                    want: Math.min(root.height * 0.2, 220 * root.u) * root.kit.clockScale
                    maxWidth: numberBox.width - 40 * root.u
                    tracking: 2
                }
                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: text !== ""
                    text: root.kit.date(root.kit.stamp("dddd d MMMM"))
                    color: Colours.inkDim
                    font.pixelSize: 18 * root.u
                    font.italic: true
                }
            }
        }
    }

    // ── the subscriber's box
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.78
        width: Math.min(760 * root.u, root.width - root.m * 2)
        height: 140 * root.u
        transform: Translate { x: root.kit.shake }

        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2 * root.u; border.color: root.kit.failed ? Colours.danger : root.ink }

        P5Text {
            x: 22 * root.u
            y: 12 * root.u
            text: root.kit.busy ? "THE CLERK IS CHECKING THE LIST…" : (root.kit.failed ? "NOT ON THE LIST — TRY AGAIN" : "SUBSCRIBERS: PLEASE SIGN IN")
            color: root.kit.failed ? Colours.danger : root.red
            font.pixelSize: 14 * root.u
            font.weight: Font.Black
            tracking: 4
        }
        // the line to write on
        Rectangle { x: 22 * root.u; y: parent.height - 44 * root.u; width: parent.width - 44 * root.u; height: 1.5 * root.u; color: root.ink }
        PassMask {
            x: 26 * root.u
            y: parent.height - 76 * root.u
            kit: root.kit
            colour: root.kit.failed ? Colours.danger : root.ink
            track: Colours.alpha(root.ink, 0.15)
            size: 22 * root.u
            centered: false
        }
        Row {
            x: 26 * root.u
            y: parent.height - 78 * root.u
            spacing: 5 * root.u
            visible: root.kit.mask === "dots"

            Repeater {
                model: 26

                P5Text {
                    required property int index

                    visible: index < root.kit.length
                    text: "●"
                    color: root.kit.failed ? Colours.danger : root.ink
                    font.pixelSize: 24 * root.u
                }
            }
            Rectangle {
                anchors.verticalCenter: undefined
                width: 2 * root.u
                height: 28 * root.u
                color: root.red
                visible: !root.kit.busy

                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite
                    NumberAnimation { to: 0; duration: 520 }
                    NumberAnimation { to: 1; duration: 520 }
                }
            }
        }
        P5Text {
            anchors.right: parent.right
            anchors.rightMargin: 22 * root.u
            y: parent.height - 34 * root.u
            visible: root.kit.hints || root.kit.caps
            text: root.kit.caps ? "CAPS LOCK IS ON" : "PRESS RETURN TO SUBMIT"
            color: root.kit.caps ? Colours.warning : Colours.inkDim
            font.pixelSize: 12 * root.u
            font.italic: true
            tracking: 2
        }
    }
}
