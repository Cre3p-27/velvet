//  VELVET  ·  modules/lock/SoftClock.qml
//  The SOFT lock's clock, in every style its arrows cycle through:
//
//    VERTICAL  hours over minutes, two-tone, big and bare
//    LINE      HH : MM on one row
//    a SHAPE   hours over minutes in a gear, a cookie, a flower … with
//              the hands sweeping over them (ClockDial)
//    CIRCLE    the analog dial — dotted 12 · 3 · 6 · 9 and the hands
//
//  Any of them in DOTS (the drawn 5 × 7 matrix) or in a typeface. The
//  bare digits are measured, not guessed: `size` is the height of one
//  digit on screen, whatever font carries it, and the rows are spaced
//  from the ink itself — so a font change never makes the clock jump.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property date now: new Date()
    // "none" = VERTICAL, "line" = LINE, any M3Shape kind = the dial.
    property string shape: "none"
    property bool analog: false
    property bool dots: false
    property string family: Appearance.fontFamily.soft
    property int weight: Font.DemiBold
    property bool h24: true
    // Bare: the height of one digit. Dial: the shape's diameter.
    property real size: 200
    property real digitScale: 1.0
    property color hourColour: Colours.accent
    property color minuteColour: Colours.ink
    property color fill: Colours.surfaceHigh
    // The dial's silhouette turned (the lock's SHAPES TURN SLOWLY).
    property real spin: 0
    // How a digit changes: "roll" (the old one rises out, the new one rises
    // in), "fade", or "none".
    property string motion: "roll"

    readonly property bool dial: root.analog || (root.shape !== "" && root.shape !== "none" && root.shape !== "line")
    readonly property bool line: !root.dial && root.shape === "line"
    readonly property string hourText: root.h24 ? Qt.formatDateTime(root.now, "HH") : Qt.formatDateTime(root.now, "hh AP").split(" ")[0]
    readonly property string minuteText: Qt.formatDateTime(root.now, "mm")

    // The digit's own proportions in this font: how tall a "0" stands per
    // pixel of font size.
    TextMetrics {
        id: ref

        font.family: root.family
        font.weight: root.weight
        font.pixelSize: 100
        text: "0"
    }

    readonly property real inkRatio: Math.max(0.3, ref.tightBoundingRect.height / 100)
    readonly property real digitH: root.size * root.digitScale
    readonly property real px: root.digitH / root.inkRatio

    implicitWidth: root.dial ? root.size : (root.line ? lineRow.width : bare.width)
    implicitHeight: root.dial ? root.size : (root.line ? root.digitH * 1.5 : bare.height)

    // ── VERTICAL: hours over minutes
    Item {
        id: bare

        visible: !root.dial && !root.line
        anchors.centerIn: parent
        // One digit, then a row pitch of 1.5 digits — the inspo's rhythm.
        readonly property real pitch: root.digitH * (root.dots ? 1.35 : 1.5)
        width: Math.max(hTop.width, hBottom.width)
        height: root.digitH + bare.pitch

        Glyphs {
            id: hTop

            anchors.horizontalCenter: parent.horizontalCenter
            centreY: root.digitH / 2
            text: root.hourText
            colour: root.hourColour
        }

        Glyphs {
            id: hBottom

            anchors.horizontalCenter: parent.horizontalCenter
            centreY: root.digitH / 2 + bare.pitch
            text: root.minuteText
            colour: root.minuteColour
        }
    }

    // ── LINE: HH : MM
    Row {
        id: lineRow

        visible: root.line
        anchors.centerIn: parent
        height: root.digitH * 1.5
        spacing: root.digitH * 0.12

        Glyphs {
            centreY: lineRow.height / 2
            text: root.hourText
            colour: root.hourColour
        }

        // The colon: two dots, drawn — every font's colon sits differently.
        Item {
            width: root.digitH * 0.16
            height: lineRow.height

            Repeater {
                model: 2

                Rectangle {
                    required property int index

                    width: root.digitH * 0.13
                    height: width
                    radius: width / 2
                    x: (parent.width - width) / 2
                    y: lineRow.height / 2 + (index === 0 ? -root.digitH * 0.24 : root.digitH * 0.24) - height / 2
                    color: Colours.alpha(root.minuteColour, 0.55)
                    antialiasing: true
                }
            }
        }

        Glyphs {
            centreY: lineRow.height / 2
            text: root.minuteText
            colour: root.minuteColour
        }
    }

    // ── a SHAPE or the CIRCLE
    ClockDial {
        anchors.centerIn: parent
        visible: root.dial
        now: root.now
        size: root.size
        shape: root.analog ? "circle" : root.shape
        analog: root.analog
        h24: root.h24
        face: root.dots ? "dots" : ""
        family: root.family
        digitScale: root.digitScale
        weight: root.weight
        fill: root.fill
        hourColour: root.hourColour
        minuteColour: root.minuteColour
        spin: root.spin
    }

    // Two digits, placed by their ink: `centreY` is where the middle of
    // the digits lands, whatever the font's ascent and line gap. A change
    // rolls (or fades) the old pair out and the new pair in.
    component Glyphs: Item {
        id: g

        property string text: ""
        property color colour: "white"
        property real centreY: 0

        // What is on screen, what is leaving, and how far the change is.
        property string current: ""
        property string leaving: ""
        property real k: 1

        Component.onCompleted: g.current = g.text
        onTextChanged: {
            if (root.motion === "none" || g.current === "") {
                g.current = g.text;
                return;
            }
            g.leaving = g.current;
            g.current = g.text;
            change.restart();
        }

        NumberAnimation {
            id: change

            target: g
            property: "k"
            from: 0
            to: 1
            duration: root.motion === "roll" ? 560 : 420
            easing.type: Easing.OutCubic
        }

        readonly property real travel: root.motion === "roll" ? root.digitH * 1.05 : 0
        readonly property real boxH: root.digitH * 1.3

        width: root.dots ? matrixNow.width : typeNow.width
        height: 1

        // The window the digits roll through.
        Item {
            y: g.centreY - g.boxH / 2
            width: Math.max(g.width, root.dots ? matrixWas.width : typeWas.width)
            height: g.boxH
            clip: root.motion === "roll" && g.k < 1

            Text {
                id: typeNow

                visible: !root.dots
                text: g.current
                color: g.colour
                font.family: root.family
                font.weight: root.weight
                font.pixelSize: root.px
                font.letterSpacing: -root.px * 0.02
                // The digit's middle is baselineOffset + ink top + half its
                // height below the item's top.
                y: g.boxH / 2 - typeNow.baselineOffset - ref.tightBoundingRect.y * root.px / 100 - root.digitH / 2 + (1 - g.k) * g.travel
                opacity: root.motion === "none" ? 1 : g.k
                antialiasing: true
                renderType: Text.QtRendering
            }

            Text {
                id: typeWas

                visible: !root.dots && g.k < 1
                text: g.leaving
                color: g.colour
                font: typeNow.font
                y: g.boxH / 2 - typeWas.baselineOffset - ref.tightBoundingRect.y * root.px / 100 - root.digitH / 2 - g.k * g.travel
                opacity: 1 - g.k
                antialiasing: true
                renderType: Text.QtRendering
            }

            DotText {
                id: matrixNow

                visible: root.dots
                text: g.current
                color: g.colour
                pixelSize: root.digitH
                y: g.boxH / 2 - root.digitH / 2 + (1 - g.k) * g.travel
                opacity: root.motion === "none" ? 1 : g.k
            }

            DotText {
                id: matrixWas

                visible: root.dots && g.k < 1
                text: g.leaving
                color: g.colour
                pixelSize: root.digitH
                y: g.boxH / 2 - root.digitH / 2 - g.k * g.travel
                opacity: 1 - g.k
            }
        }
    }
}
