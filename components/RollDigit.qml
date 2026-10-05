//  VELVET  ·  components/RollDigit.qml
//  One character that ROLLS when it changes: the old one slides up and out,
//  the new one rises into its place. Used by the desktop clock, so a minute
//  turning over is a small event instead of a silent swap.
//
//  Tall and narrow on purpose: the face is squeezed horizontally (xScale),
//  which gives any display font the condensed look without needing a
//  condensed cut to be installed.
import qs.config
import QtQuick

Item {
    id: root

    property string text: ""
    property color color: "white"
    property string family: Appearance.fontFamily.display
    property int pixelSize: 96
    property int weight: Font.Normal
    property real squeeze: 0.66
    property bool motion: true

    implicitWidth: Math.max(a.implicitWidth, b.implicitWidth) * root.squeeze
    implicitHeight: a.implicitHeight
    clip: true

    // `a` is on screen; `b` is the one leaving.

    onTextChanged: {
        if (!root.motion || a.text === "") {
            a.text = root.text;
            return;
        }
        b.text = a.text;
        a.text = root.text;
        roll.restart();
    }

    Component.onCompleted: a.text = root.text

    Text {
        id: a

        y: 0
        color: root.color
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        renderType: Text.QtRendering
        transform: Scale {
            xScale: root.squeeze
        }
    }

    Text {
        id: b

        y: -root.height
        opacity: 0
        color: root.color
        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        renderType: Text.QtRendering
        transform: Scale {
            xScale: root.squeeze
        }
    }

    ParallelAnimation {
        id: roll

        NumberAnimation {
            target: a
            property: "y"
            from: root.height * 0.9
            to: 0
            duration: Math.round(520 * Config.appearance.animationScale)
            easing.type: Easing.OutBack
            easing.overshoot: 0.9
        }
        NumberAnimation {
            target: a
            property: "opacity"
            from: 0
            to: 1
            duration: Math.round(260 * Config.appearance.animationScale)
        }
        NumberAnimation {
            target: b
            property: "y"
            from: 0
            to: -root.height * 0.8
            duration: Math.round(420 * Config.appearance.animationScale)
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: b
            property: "opacity"
            from: 1
            to: 0
            duration: Math.round(380 * Config.appearance.animationScale)
        }
    }
}
