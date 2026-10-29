import qs.config
import qs.services
import qs.components
import QtQuick

// The clock's digits (MOTION & LIGHT → CLOCK DIGITS): a new hour or
// minute ROLLs up into place while the old one leaves upwards, FADEs
// across, or simply changes. The first time is never animated.
Item {
    id: roll

    property string text: ""
    property color color: Colours.ink
    property real px: 100
    // the clock's typeface, handed in by the face (its own properties are
    // out of reach from here)
    property string family: ""
    property bool heavy: false
    property string shown: ""
    property string was: ""
    property real t: 1
    readonly property string motion: Config.lock.fluidDigits
    readonly property real travel: roll.motion === "roll" ? now.height * 0.42 : 0

    implicitWidth: now.implicitWidth
    implicitHeight: now.implicitHeight

    onTextChanged: {
        if (roll.shown === "" || roll.motion === "none") {
            roll.shown = roll.text;
            return;
        }
        if (roll.text === roll.shown)
            return;
        roll.was = roll.shown;
        roll.shown = roll.text;
        swap.restart();
    }
    Component.onCompleted: roll.shown = roll.text

    P5Text {
        id: now

        text: roll.shown
        color: roll.color
        display: roll.heavy
        font.family: roll.family
        font.weight: roll.heavy ? Font.Black : Font.Light
        font.italic: false
        font.pixelSize: roll.px
        tracking: -4
        y: (1 - roll.t) * roll.travel
        opacity: roll.t
    }

    P5Text {
        text: roll.was
        visible: roll.t < 1
        color: roll.color
        display: now.display
        font.family: now.font.family
        font.weight: now.font.weight
        font.italic: false
        font.pixelSize: roll.px
        tracking: -4
        y: -roll.t * roll.travel
        opacity: 1 - roll.t
    }

    NumberAnimation {
        id: swap

        target: roll
        property: "t"
        from: 0
        to: 1
        duration: 640
        easing.type: Easing.OutCubic
    }
}
