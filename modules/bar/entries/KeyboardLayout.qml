//  VELVET  ·  KeyboardLayout — which layout is live. Click cycles.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    readonly property string layout: Hypr.keyboardLayout

    padding: 4
    visible: layout !== ""
    tip: "KEYBOARD LAYOUT  ·  CLICK CYCLES  ·  RIGHT-CLICK REARRANGES"

    onClicked: {
        Sfx.cursor();
        Hypr.nextKeyboardLayout();
        cycle.restart();
    }
    onRightClicked: Panels.openSettingsTabNamed("ARRANGE MODULES")

    Timer {
        id: cycle
        interval: 150
        onTriggered: Hypr.refreshKeyboard()
    }

    P5Text {
        id: label

        display: true
        text: root.layout
        color: root.containsMouse ? Colours.accent : Colours.ink
        font.pixelSize: Config.bar.fontSize * 0.92
        tracking: 1

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        // Flips over when the layout actually changes.
        onTextChanged: flip.restart()

        SequentialAnimation {
            id: flip

            NumberAnimation {
                target: label
                property: "scale"
                to: 0.6
                duration: 90
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: label
                property: "scale"
                to: 1.0
                duration: 190
                easing.type: Easing.OutBack
                easing.overshoot: 3
            }
        }
    }
}
