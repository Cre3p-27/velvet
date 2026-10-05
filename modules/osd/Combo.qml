//  VELVET  ·  modules/osd/Combo.qml
//  The combo chip — a small accent pill that says ×3, ×5, ×8 in the second
//  or two after you chain a few actions together. Game juice, quiet enough
//  for a desktop: it pops in, it names the milestone, it gets out of the way.
//
//  The arithmetic lives in services/Combo.qml; this file only shows it.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    readonly property bool shown: Config.services.comboMeter && Combo.shown && Combo.count >= 2
    readonly property string word: Combo.milestones[Combo.count] ?? ""

    // The kick is its own plain property, animated by the pop below; the
    // chip's scale stays a binding that reads it. Animating a bound property
    // directly would eat the binding on the first run — this keeps both.
    property real kick: 0

    screen: Hypr.focusedScreen
    visible: root.shown
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-combo"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: 84

    margins {
        // Above the OSD's own band, so a volume change never hides a streak.
        bottom: 168
    }

    mask: Region {
        item: chip
    }

    Connections {
        target: Combo

        function onCountChanged(): void {
            if (root.shown)
                pop.restart();
        }
    }

    SequentialAnimation {
        id: pop

        NumberAnimation {
            target: root
            property: "kick"
            to: 1
            duration: 80
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "kick"
            to: 0
            duration: 280
            easing.type: Easing.OutBack
        }
    }

    Item {
        id: chip

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        // The pill is as wide as what it says — ×12 UNSTOPPABLE is a longer
        // sentence than ×2.
        width: Math.max(104, inner.implicitWidth + 46)
        height: 48
        scale: root.shown ? 1 : 0.84
        opacity: root.shown ? 1 : 0

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.entrance
                easing.type: Easing.OutBack
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutExpo
            }
        }

        Item {
            id: core

            anchors.fill: parent
            scale: 1 + root.kick * 0.16

            Slash {
                anchors.fill: parent
                shear: Appearance.skew
                color: Colours.alpha(Colours.surfaceHigh, 0.96)
                borderColor: Colours.accent
                borderWidth: 2
            }

            Row {
                id: inner

                anchors.centerIn: parent
                spacing: 12

                P5Text {
                    display: true
                    text: `×${Combo.count}`
                    color: Colours.accent
                    font.pixelSize: Appearance.font.size.title
                }

                P5Text {
                    visible: root.word.length > 0
                    text: root.word
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.6
                }
            }
        }
    }
}
