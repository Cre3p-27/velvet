//  VELVET  ·  modules/lock/ClockDial.qml
//  The lock's clock inside a shape (LOCK SCREEN → CLOCK & SOUND → CLOCK
//  SHAPE): the hours stacked over the minutes in a Material shape — a
//  cookie, a sun, a flower, a clover or a plain circle — with the hands
//  sweeping over the digits and a seconds dot riding the rim. With the
//  ANALOG face there are no digits at all: dotted 12 · 3 · 6 · 9 and the
//  hands on a round dial.
//
//  The hands step once a second and always turn forwards (no spin back
//  at the top of the minute); the shape itself never moves.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property date now: new Date()
    property real size: 320
    property string shape: "cookie"   // an M3Shape kind
    property bool analog: false
    property bool h24: true
    // How the digits are drawn: "" light, "display" heavy, "mono", "dots".
    property string face: ""
    property string family: Appearance.fontFamily.body
    // How big the digits are inside the shape (LOCK SCREEN → CLOCK FONT
    // SIZE), 1 = the house size.
    property real digitScale: 1.0
    // Off leaves only the hands in the shape — the greeting layout's
    // little dial.
    property bool digits: true
    // The ANALOG face's 12 · 3 · 6 · 9.
    property bool numerals: true
    // The shape's own colour, and how far the silhouette alone is turned
    // (a desktop widget's hover turn — the digits stay upright).
    property color fill: Colours.alpha(Colours.surfaceHigh, 0.96)
    property real spin: 0
    // The digits' weight; -1 = by face (light, or black for "display").
    property int weight: -1
    property color hourColour: Colours.accent
    property color minuteColour: Colours.accentAlt

    readonly property int hh: root.now.getHours()
    readonly property int mm: root.now.getMinutes()
    readonly property int ss: root.now.getSeconds()
    readonly property string hourText: root.h24 ? Qt.formatDateTime(root.now, "HH") : Qt.formatDateTime(root.now, "hh AP").split(" ")[0]

    width: root.size
    height: root.size

    M3Shape {
        anchors.fill: parent
        kind: root.analog ? "circle" : root.shape
        color: root.fill
        borderColor: Colours.alpha(Colours.ink, 0.08)
        borderWidth: 1
        intro: false
        spin: root.spin
    }

    // ── the digits, hours over minutes
    Column {
        anchors.centerIn: parent
        visible: !root.analog && root.digits
        spacing: root.face === "dots" ? root.size * 0.05 * root.digitScale : -root.size * 0.06 * root.digitScale

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.face !== "dots"
            text: root.hourText
            color: root.hourColour
            display: root.face === "display"
            font.family: root.family
            font.weight: root.weight >= 0 ? root.weight : (root.face === "display" ? Font.Black : Font.Light)
            font.italic: false
            font.pixelSize: root.size * 0.3 * root.digitScale
            tracking: -2
        }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.face !== "dots"
            text: Qt.formatDateTime(root.now, "mm")
            color: root.minuteColour
            display: root.face === "display"
            font.family: root.family
            font.weight: root.weight >= 0 ? root.weight : (root.face === "display" ? Font.Black : Font.Light)
            font.italic: false
            font.pixelSize: root.size * 0.3 * root.digitScale
            tracking: -2
        }

        DotText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.face === "dots"
            text: root.hourText
            color: root.hourColour
            pixelSize: root.size * 0.2 * root.digitScale
        }

        DotText {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.face === "dots"
            text: Qt.formatDateTime(root.now, "mm")
            color: root.minuteColour
            pixelSize: root.size * 0.2 * root.digitScale
        }
    }

    // ── the analog face: 12 · 3 · 6 · 9 as dots
    Repeater {
        model: root.analog && root.numerals ? [
            { t: "12", a: 0 },
            { t: "3", a: 90 },
            { t: "6", a: 180 },
            { t: "9", a: 270 }
        ] : []

        DotText {
            required property var modelData

            readonly property real rad: modelData.a * Math.PI / 180
            readonly property real reach: root.size * 0.335

            x: root.size / 2 + Math.sin(rad) * reach - width / 2
            y: root.size / 2 - Math.cos(rad) * reach - height / 2
            text: modelData.t
            color: Colours.alpha(Colours.ink, 0.42)
            pixelSize: root.size * 0.095
        }
    }

    // ── the hands: one rounded bar each, turning about the centre
    component Hand: Item {
        id: hand

        property real angle: 0
        property real length: 0.3
        property real thick: 0.05
        property color colour: "white"

        anchors.fill: parent
        rotation: hand.angle

        Behavior on rotation {
            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
        }

        Rectangle {
            readonly property real w: root.size * hand.thick

            x: root.size / 2 - w / 2
            y: root.size / 2 - root.size * hand.length
            width: w
            height: root.size * hand.length + w / 2
            radius: w / 2
            color: hand.colour
            antialiasing: true
        }
    }

    // Bold hands when they are the whole face (ANALOG, or the hands-only
    // dial); quiet ones when they sweep over digits.
    readonly property bool boldHands: root.analog || !root.digits

    Hand {
        angle: ((root.hh % 12) + root.mm / 60) * 30
        length: root.boldHands ? 0.22 : 0.2
        thick: 0.075
        colour: root.boldHands ? Colours.alpha(Colours.ink, 0.85) : Colours.alpha(Colours.ink, 0.28)
    }

    Hand {
        angle: (root.mm + root.ss / 60) * 6
        length: root.boldHands ? 0.33 : 0.3
        thick: 0.035
        colour: root.boldHands ? root.hourColour : Colours.alpha(root.hourColour, 0.55)
    }

    // The seconds: a dot riding the rim.
    Item {
        anchors.fill: parent
        rotation: root.ss * 6

        Behavior on rotation {
            RotationAnimation {
                direction: RotationAnimation.Clockwise
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
        }

        Rectangle {
            readonly property real d: root.size * 0.06

            x: root.size / 2 - d / 2
            y: root.size * (root.boldHands ? 0.08 : 0.1)
            width: d
            height: d
            radius: d / 2
            color: root.boldHands ? Colours.ink : root.hourColour
            antialiasing: true
        }
    }

    // The cap over the hands' pivot.
    Rectangle {
        anchors.centerIn: parent
        width: root.size * 0.05
        height: width
        radius: width / 2
        color: root.boldHands ? root.hourColour : Colours.alpha(Colours.ink, 0.35)
        antialiasing: true
    }
}
