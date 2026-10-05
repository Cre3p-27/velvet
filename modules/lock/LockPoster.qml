//  VELVET  ·  modules/lock/LockPoster.qml
//  The lock of the BRUTAL look: a plain poster. Warm paper, the time in heavy
//  black block type with one hard block of shadow, a rule, a black bar to type
//  into with white dots and a coral arrow.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var kit: null

    readonly property real u: Math.max(0.5, Math.min(root.width / 1920, root.height / 1080))
    readonly property color ink: Colours.edge
    readonly property color coral: Colours.accent

    Rectangle {
        anchors.fill: parent
        color: Colours.paper
    }
    LockWall {
        anchors.fill: parent
        blur: root.kit.blurOr(1)
        dim: root.kit.dimOr(0.95)
        drift: false
    }
    Backdrop {
        anchors.fill: parent
        kind: "dots"
        colour: root.ink
        step: 40 * root.u
        strength: 0.5
    }

    // the border of the sheet
    Rectangle {
        x: 36 * root.u
        y: 36 * root.u
        width: parent.width - 72 * root.u
        height: parent.height - 72 * root.u
        color: "transparent"
        border.width: 3 * root.u
        border.color: root.ink
    }

    // ── the time
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.1
        width: timeText.implicitWidth
        height: timeText.implicitHeight

        P5Text {
            x: 9 * root.u
            y: 9 * root.u
            display: true
            text: timeText.text
            color: root.coral
            font.family: timeText.font.family
            font.pixelSize: timeText.font.pixelSize
            tracking: -10
        }
        FitClock {
            id: timeText

            display: true
            text: root.kit.clockText
            font.family: root.kit.typeface(Appearance.fontFamily.display)
            color: root.kit.tint(root.ink)
            want: Math.min(root.height * 0.38, 420 * root.u) * Math.min(root.kit.clockScale, 1.3)
            maxWidth: root.width * 0.9
            tracking: -10
        }
    }

    // a rule with the date on it
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.1 + timeText.implicitHeight * 1.0
        width: Math.min(root.width * 0.62, 1100 * root.u)
        height: 40 * root.u

        visible: dateT.text !== ""

        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3 * root.u; color: root.ink }
        Rectangle {
            anchors.centerIn: parent
            width: dateT.implicitWidth + 44 * root.u
            height: parent.height
            color: Colours.paper

            P5Text {
                id: dateT

                anchors.centerIn: parent
                text: root.kit.date(root.kit.stamp("dddd · d MMMM")).toUpperCase()
                color: root.ink
                font.pixelSize: 21 * root.u
                font.weight: Font.Black
                tracking: 5
            }
        }
    }

    // ── the field
    Item {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.75
        width: Math.min(root.width * 0.46, 820 * root.u)
        height: 84 * root.u
        scale: root.kit.recoil
        transform: Translate { x: root.kit.shake }

        Rectangle { x: 6 * root.u; y: 6 * root.u; width: parent.width; height: parent.height; color: root.kit.failed ? Colours.danger : root.coral }
        Rectangle { anchors.fill: parent; color: root.ink }

        P5Text {
            anchors.left: parent.left
            anchors.leftMargin: 28 * root.u
            anchors.verticalCenter: parent.verticalCenter
            visible: root.kit.length === 0
            text: root.kit.busy ? "CHECKING…" : (root.kit.failed ? (root.kit.message || "NOPE.") : (root.kit.hello !== "" ? root.kit.hello.toUpperCase() : "PASSWORD"))
            color: root.kit.failed ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
            font.pixelSize: 26 * root.u
            font.weight: Font.Black
            tracking: 4
        }
        PassMask {
            anchors.left: parent.left
            anchors.leftMargin: 28 * root.u
            anchors.verticalCenter: parent.verticalCenter
            centered: false
            kit: root.kit
            colour: "#ffffff"
            track: Qt.rgba(1, 1, 1, 0.2)
            size: 24 * root.u
            family: Appearance.fontFamily.display
        }
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 28 * root.u
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.u
            visible: root.kit.mask === "dots"

            Repeater {
                model: 18

                Rectangle {
                    required property int index

                    visible: index < root.kit.length
                    width: 20 * root.u
                    height: width
                    color: "#ffffff"
                }
            }
        }
        // the arrow
        Rectangle {
            anchors.right: parent.right
            width: parent.height
            height: parent.height
            color: root.coral
            opacity: root.kit.length > 0 || root.kit.busy ? 1 : 0.35

            Icon {
                anchors.centerIn: parent
                name: "arrow_forward"
                color: root.ink
                font.pixelSize: 44 * root.u
            }
        }
    }
    P5Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.75 + 112 * root.u
        visible: root.kit.hints || root.kit.caps
        text: root.kit.caps ? "CAPS LOCK IS ON" : `${root.kit.showUser ? root.kit.user.toUpperCase() + "  ·  " : ""}LOCKED  ·  ENTER TO UNLOCK`
        color: root.kit.caps ? Colours.warning : Colours.inkDim
        font.pixelSize: 16 * root.u
        font.weight: Font.ExtraBold
        tracking: 4
    }

    LockExtras {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 58 * root.u
        width: root.width * 0.7
        kit: root.kit
        colour: root.ink
        family: Appearance.fontFamily.display
        size: 16 * root.u
        upper: true
    }
}
