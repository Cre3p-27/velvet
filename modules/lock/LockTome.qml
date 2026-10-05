//  VELVET  ·  modules/lock/LockTome.qml
//  The lock of the RPG look: the cover of an old book. A leather ground, a gold
//  frame with corner ornaments, the title and the hour in serif gold, and "speak
//  the word" — the password is a line of gold diamonds, one for every letter.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var kit: null

    readonly property real u: Math.max(0.5, Math.min(root.width / 1920, root.height / 1080))
    readonly property color gold: Colours.accent
    readonly property real bw: Math.min(root.width * 0.62, 1080 * root.u)
    readonly property real bh: Math.min(root.height * 0.82, 780 * root.u)
    function ordinal(d: int): string {
        if (d % 100 >= 11 && d % 100 <= 13)
            return `${d}th`;
        return `${d}${({ 1: "st", 2: "nd", 3: "rd" })[d % 10] ?? "th"}`;
    }

    readonly property var roman: ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]

    Rectangle {
        anchors.fill: parent
        color: Colours.paper
    }
    LockWall {
        anchors.fill: parent
        blur: root.kit.blurOr(1)
        dim: root.kit.dimOr(0.93)
        drift: false
    }
    // the corners fall into shadow, like a room lit by one candle
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.5) }
            GradientStop { position: 0.4; color: "transparent" }
            GradientStop { position: 0.75; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) }
        }
    }

    // ── the cover
    Item {
        id: cover

        anchors.centerIn: parent
        width: root.bw
        height: root.bh

        Rectangle {
            anchors.fill: parent
            color: Colours.alpha(Colours.surface, 0.9)
            border.width: 2 * root.u
            border.color: root.gold
        }
        Rectangle {
            x: 14 * root.u
            y: 14 * root.u
            width: parent.width - 28 * root.u
            height: parent.height - 28 * root.u
            color: "transparent"
            border.width: 1
            border.color: Colours.alpha(root.gold, 0.55)
        }
        // corner ornaments: a diamond and two short rules
        Repeater {
            model: 4

            Item {
                id: orn

                required property int index

                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index > 1

                x: orn.atRight ? cover.width - 40 * root.u : 22 * root.u
                y: orn.atBottom ? cover.height - 40 * root.u : 22 * root.u
                width: 18 * root.u
                height: 18 * root.u

                Rectangle { anchors.centerIn: parent; width: 10 * root.u; height: width; rotation: 45; color: root.gold }
                Rectangle { x: orn.atRight ? -22 * root.u : 22 * root.u; y: parent.height / 2; width: 22 * root.u; height: 1; color: root.gold }
                Rectangle { y: orn.atBottom ? -22 * root.u : 22 * root.u; x: parent.width / 2; width: 1; height: 22 * root.u; color: root.gold }
            }
        }
        // the ribbon marking the place
        Rectangle {
            x: cover.width * 0.84
            y: -2
            width: 30 * root.u
            height: 110 * root.u
            color: Colours.danger
            opacity: 0.85

            Rectangle {
                x: 0
                y: parent.height - 14 * root.u
                width: parent.width
                height: 14 * root.u
                color: Colours.paper
                rotation: 0
                visible: false
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 58 * root.u
            spacing: 6 * root.u

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "THE BOOK OF VELVET"
                color: root.gold
                font.pixelSize: 24 * root.u
                font.weight: Font.Medium
                tracking: 9
            }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 180 * root.u; height: 1; color: root.gold }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: cover.height * 0.2
            spacing: 6 * root.u

            FitClock {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: root.kit.clockText
                font.family: root.kit.typeface(Appearance.fontFamily.display)
                color: root.kit.tint(root.gold)
                want: Math.min(cover.height * 0.3, 230 * root.u) * root.kit.clockScale
                maxWidth: cover.width * 0.8
                tracking: 6
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: root.kit.date(`${root.kit.stamp("dddd")} · the ${root.ordinal(root.kit.now.getDate())} of ${root.kit.stamp("MMMM")}`)
                color: Colours.inkDim
                font.pixelSize: 22 * root.u
                font.italic: true
                tracking: 3
            }
        }

        // ── speak the word
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: cover.height * 0.68
            spacing: 14 * root.u
            width: parent.width * 0.62
            transform: Translate { x: root.kit.shake }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.kit.busy ? "the book is reading you…" : (root.kit.failed ? "the word was wrong" : (root.kit.hello !== "" ? root.kit.hello : `speak the word${root.kit.showUser ? ", " + root.kit.name : ""}`))
                color: root.kit.failed ? Colours.danger : Colours.inkDim
                font.pixelSize: 21 * root.u
                font.italic: true
                tracking: 2
            }
            Item {
                width: parent.width
                height: 44 * root.u

                PassMask {
                    anchors.centerIn: parent
                    kit: root.kit
                    colour: root.kit.failed ? Colours.danger : root.gold
                    track: Colours.alpha(root.gold, 0.2)
                    size: 22 * root.u
                    family: Appearance.fontFamily.display
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 8 * root.u
                    visible: root.kit.mask === "dots"

                    Repeater {
                        model: 24

                        Rectangle {
                            required property int index

                            readonly property bool lit: index < root.kit.length

                            width: 14 * root.u
                            height: width
                            rotation: 45
                            color: root.kit.failed ? Colours.danger : root.gold
                            scale: lit ? 1 : 0
                            opacity: lit ? 1 : 0

                            Behavior on scale {
                                NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Colours.alpha(root.gold, 0.7)
                }
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.kit.hints || root.kit.caps
                text: root.kit.caps ? "the caps are raised" : "press enter to open the book"
                color: root.kit.caps ? Colours.warning : Colours.alpha(Colours.inkDim, 0.8)
                font.pixelSize: 15 * root.u
                font.italic: true
                tracking: 2
            }
        }
    }

    // battery · road, the song, the weather — in the corner of the room
    LockExtras {
        anchors.right: parent.right
        anchors.rightMargin: 56 * root.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44 * root.u
        width: root.width * 0.4
        align: Text.AlignRight
        kit: root.kit
        colour: Colours.alpha(Colours.inkDim, 0.85)
        size: 16 * root.u
    }
}
