//  VELVET  ·  modules/lock/LockArcade.qml
//  The lock of the ARCADE look: a game waiting at its title screen. The time in
//  the pixel face, PLAYER 1 waiting, the password as a row of boxes that fill as
//  you type (a wrong one flashes red and says TRY AGAIN), one blinking line to
//  press. Navy ground, yellow, calm.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var kit: null

    readonly property real u: Math.max(0.5, Math.min(root.width / 1920, root.height / 1080))
    readonly property color gold: Colours.accent
    readonly property color edge: Colours.edge
    readonly property string pixel: Appearance.fontFamily.pixel

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
        kind: "checker"
        colour: Colours.ink
        step: 64 * root.u
    }

    // ── the title screen
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.1
        spacing: 14 * root.u

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.kit.hello !== "" ? root.kit.hello.toUpperCase() : (root.kit.showUser ? "PLAYER 1" : "")
            color: Colours.inkDim
            font.family: root.pixel
            font.pixelSize: 26 * root.u
            tracking: 6
        }
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: timeText.implicitWidth
            height: timeText.implicitHeight

            P5Text {
                x: 6 * root.u
                y: 6 * root.u
                text: timeText.text
                color: root.edge
                font.family: timeText.font.family
                font.pixelSize: timeText.font.pixelSize
                tracking: 4
            }
            FitClock {
                id: timeText

                text: root.kit.clockPadded
                color: root.kit.tint(root.gold)
                font.family: root.kit.typeface(root.pixel)
                want: Math.min(root.height * 0.2, 230 * root.u * 1.2) * root.kit.clockScale
                maxWidth: root.width * 0.9
                tracking: 4
            }
        }
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: root.kit.date(root.kit.stamp("dddd d MMMM")).toUpperCase()
            color: Colours.ink
            font.family: root.pixel
            font.pixelSize: 24 * root.u
            tracking: 4
        }
    }

    // ── the password: a row of boxes
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.58
        spacing: 22 * root.u
        transform: Translate { x: root.kit.shake }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.kit.busy ? "LOADING…" : (root.kit.failed ? "TRY AGAIN" : "ENTER PASSWORD")
            color: root.kit.failed ? Colours.danger : (root.kit.busy ? Colours.warning : root.gold)
            font.family: root.pixel
            font.pixelSize: 30 * root.u
            tracking: 5
        }
        PassMask {
            anchors.horizontalCenter: parent.horizontalCenter
            kit: root.kit
            colour: root.kit.failed ? Colours.danger : root.gold
            track: Colours.surface
            size: 30 * root.u
            family: root.pixel
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * root.u
            scale: root.kit.recoil
            visible: root.kit.mask === "dots"

            Repeater {
                model: 16

                Item {
                    id: box

                    required property int index

                    readonly property bool lit: index < root.kit.length
                    readonly property bool cursor: index === root.kit.length && !root.kit.busy

                    width: 40 * root.u
                    height: 48 * root.u

                    Rectangle {
                        anchors.fill: parent
                        color: root.edge
                    }
                    Rectangle {
                        x: 3 * root.u
                        y: 3 * root.u
                        width: parent.width - 6 * root.u
                        height: parent.height - 6 * root.u
                        color: box.lit ? (root.kit.failed ? Colours.danger : root.gold) : Colours.surface
                        scale: box.lit ? 1 : 0.9

                        Behavior on scale {
                            NumberAnimation { duration: 90; easing.type: Easing.OutBack; easing.overshoot: 3 }
                        }
                    }
                    Rectangle {
                        visible: box.cursor
                        x: 9 * root.u
                        y: parent.height - 12 * root.u
                        width: parent.width - 18 * root.u
                        height: 4 * root.u
                        color: root.gold

                        SequentialAnimation on opacity {
                            running: box.cursor
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 420 }
                            NumberAnimation { to: 1; duration: 420 }
                        }
                    }
                }
            }
        }
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.kit.hints || root.kit.caps
            text: root.kit.length > 0 ? "PRESS ENTER" : (root.kit.caps ? "CAPS LOCK IS ON" : "TYPE YOUR PASSWORD")
            color: root.kit.caps && root.kit.length === 0 ? Colours.warning : Colours.inkDim
            font.family: root.pixel
            font.pixelSize: 20 * root.u
            tracking: 4

            SequentialAnimation on opacity {
                running: root.kit.length > 0 && !root.kit.busy
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: 600 }
                NumberAnimation { to: 1; duration: 600 }
            }
        }
    }

    // ── the status along the foot
    LockExtras {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.06
        width: root.width * 0.8
        kit: root.kit
        colour: Colours.inkDim
        family: root.pixel
        size: 17 * root.u
        upper: true
    }
}
