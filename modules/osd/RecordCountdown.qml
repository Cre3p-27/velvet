//  VELVET  ·  modules/osd/RecordCountdown.qml
//  3 · 2 · 1 before a screen recording starts (Super+Enter → hypr/scripts/
//  velvet-record.sh → `ipc call record begin` → Panels.recordLeft). A big
//  number in the middle of the screen you are on, a ring that runs out with
//  each second, and the key that cancels. It is gone (faded in 140 ms) before
//  the script starts the recorder, so it never ends up in the video, and it
//  never takes a click or a key.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: root

    readonly property int remaining: Panels.recordLeft
    readonly property bool counting: root.remaining > 0
    // stays a beat after the last number, for the fade
    property bool shown: false

    onCountingChanged: {
        if (root.counting) {
            outro.stop();
            root.shown = true;
        } else {
            outro.restart();
        }
    }
    onRemainingChanged: {
        if (root.counting)
            beat.restart();
    }

    Timer {
        id: outro

        interval: 160
        onTriggered: root.shown = false
    }

    screen: Hypr.focusedScreen
    visible: root.shown
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-countdown"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: nothing
    }

    Item {
        id: nothing

        width: 0
        height: 0
    }

    // Created for the occasion (shell.qml, Parked): the first number is already
    // up when the window exists, so say it once more.
    Timer {
        running: true
        interval: 1
        onTriggered: root.countingChanged()
    }

    Item {
        id: stage

        anchors.fill: parent
        opacity: root.counting ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.counting ? Appearance.anim.fast : 140
                easing.type: Easing.OutCubic
            }
        }

        // a light veil, so the number reads on any picture
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.28)
        }

        Item {
            id: dial

            readonly property real size: Math.round(Math.min(root.width, root.height) * 0.22)
            // 1 → 0 across each second: the ring runs out
            property real share: 1

            anchors.centerIn: parent
            width: dial.size
            height: dial.size

            Plate {
                anchors.fill: parent
                radius: width / 2
                color: Colours.alpha(Colours.paper, 0.92)
                border.width: 2
                border.color: Colours.alpha(Colours.accent, 0.35)
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colours.accent
                    strokeWidth: Math.max(4, dial.size * 0.035)
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: dial.size / 2
                        centerY: dial.size / 2
                        radiusX: dial.size / 2 - Math.max(6, dial.size * 0.05)
                        radiusY: radiusX
                        startAngle: -90
                        sweepAngle: 360 * dial.share
                    }
                }
            }

            P5Text {
                id: number

                anchors.centerIn: parent
                display: true
                text: String(Math.max(1, root.remaining))
                color: Colours.ink
                font.pixelSize: Math.round(dial.size * 0.5)
                tracking: 0
            }
        }

        // every new number: it lands with a little pop, the ring starts full
        ParallelAnimation {
            id: beat

            NumberAnimation {
                target: number
                property: "scale"
                from: 1.45
                to: 1
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
            NumberAnimation {
                target: number
                property: "opacity"
                from: 0
                to: 1
                duration: 180
            }
            NumberAnimation {
                target: dial
                property: "share"
                from: 1
                to: 0
                duration: 1000
            }
        }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dial.bottom
            anchors.topMargin: Math.round(dial.size * 0.16)
            display: true
            text: "RECORDING STARTS"
            color: "white"
            font.pixelSize: Appearance.font.size.large
            tracking: 3
        }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: dial.bottom
            anchors.topMargin: Math.round(dial.size * 0.16) + Appearance.font.size.large + 14
            text: `${Binds.display("record").toUpperCase()} AGAIN CANCELS`
            color: Qt.rgba(1, 1, 1, 0.72)
            font.pixelSize: Appearance.font.size.small
        }
    }
}
