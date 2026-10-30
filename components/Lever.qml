//  VELVET  ·  components/Lever.qml
//  A lever you flip — the WLAN | LAN switch (and anything else with two
//  sides that deserves more than a toggle). A stick with a ball on top in a
//  sunken slot: click it, or take the ball and throw it across. It snaps over
//  the middle with a tick, lands with a clunk and a little bounce, and a side
//  that cannot be had (no cable in) lets it get two thirds of the way before
//  it springs back with a shake of the head.
//
//      Lever {
//          atRight: Net.onLan
//          leftLabel: "WLAN"; rightLabel: "LAN"
//          leftLit: Net.type === "wifi"; rightLit: Net.ethConnected
//          onFlipped: toRight => toRight && !Net.ethCable ? lever.refuse() : Net.useLan(toRight)
//      }
//
//  The owner keeps `atRight` honest: `flipped` only says what the hand asked
//  for; the lever shows that side at once and stays there unless `atRight`
//  says otherwise, or `refuse()` sends it home.
import qs.config
import qs.services
import QtQuick

Item {
    id: lever

    property bool atRight: false
    property string leftLabel: "OFF"
    property string rightLabel: "ON"
    property string leftIcon: ""
    property string rightIcon: ""
    // a small lamp beside each label: the side that is live right now
    property bool leftLit: false
    property bool rightLit: false
    // the stick's swing either side of upright, in degrees
    property real swing: 34

    signal flipped(bool toRight)

    implicitWidth: 196
    implicitHeight: 64

    // what the hand asked for, until `atRight` agrees or a refusal sends it back
    property bool wantRight: lever.atRight
    onAtRightChanged: lever.wantRight = lever.atRight

    // the stick's angle: sprung, or straight under the hand while held
    property bool held: false
    property real handAngle: 0
    readonly property real restAngle: lever.wantRight ? lever.swing : -lever.swing
    readonly property real angle: tilt.value

    Spring {
        id: tilt

        to: lever.held ? lever.handAngle : lever.restAngle + lever.kick
        live: !lever.held
        carry: true
        spring: 5.2
        damping: 0.3
        epsilon: 0.05
    }

    // the bounce of a landing and the shake of a refusal, added on top
    property real kick: 0

    SequentialAnimation {
        id: refusal

        // most of the way over …
        NumberAnimation {
            target: lever
            property: "kick"
            to: lever.wantRight ? -lever.swing * 1.25 : lever.swing * 1.25
            duration: 150
            easing.type: Easing.OutQuad
        }
        // … no: back, with a shake
        ScriptAction {
            script: {
                lever.kick = 0;
                Sfx.nope();
                shake.restart();
            }
        }
    }

    SequentialAnimation {
        id: shake

        NumberAnimation { target: base; property: "nudge"; to: 5; duration: 45 }
        NumberAnimation { target: base; property: "nudge"; to: -4; duration: 70 }
        NumberAnimation { target: base; property: "nudge"; to: 3; duration: 70 }
        NumberAnimation { target: base; property: "nudge"; to: 0; duration: 90; easing.type: Easing.OutQuad }
    }

    // the clunk of a landing: the slot dips and the label lamps flare
    SequentialAnimation {
        id: land

        NumberAnimation { target: base; property: "dip"; to: 2.5; duration: 60; easing.type: Easing.OutQuad }
        NumberAnimation { target: base; property: "dip"; to: 0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
    }

    // flip to a side: the owner hears about it, the lever goes there now
    function throwTo(toRight: bool): void {
        if (toRight === lever.wantRight)
            return;
        lever.wantRight = toRight;
        lever.flipped(toRight);
        // the clunk only for a flip the owner took (a refusal has its own sound)
        if (lever.wantRight === toRight) {
            Sfx.lever();
            land.restart();
        }
    }

    // the owner says no: back to the side it came from
    function refuse(): void {
        lever.wantRight = lever.atRight;
        refusal.restart();
    }

    Accessible.role: Accessible.CheckBox
    Accessible.name: `${lever.leftLabel} or ${lever.rightLabel}`
    Accessible.checked: lever.wantRight

    // ── the slot
    Item {
        id: base

        property real nudge: 0
        property real dip: 0

        anchors.fill: parent
        transform: Translate {
            x: base.nudge
            y: base.dip
        }

        // the two labels, the lit one in the accent, with its lamp
        Repeater {
            model: 2

            Item {
                id: side

                required property int index
                readonly property bool isRight: index === 1
                readonly property bool chosen: side.isRight === lever.wantRight
                readonly property bool lit: side.isRight ? lever.rightLit : lever.leftLit

                x: side.isRight ? lever.width - width : 0
                width: Math.max(44, label.implicitWidth + 4)
                height: lever.height

                P5Text {
                    id: label

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: lever.height * 0.5 - height * 0.5 + 6
                    display: true
                    text: side.isRight ? lever.rightLabel : lever.leftLabel
                    color: side.chosen ? Colours.accentInk : Colours.alpha(Colours.inkDim, 0.75)
                    font.pixelSize: Appearance.font.size.small
                    tracking: 1.4
                    scale: side.chosen ? 1.06 : 0.94

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.2
                        }
                    }
                }

                // the lamp: lit while that side carries the connection
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: label.top
                    anchors.bottomMargin: 5
                    width: 7
                    height: 7
                    radius: 3.5
                    color: side.lit ? Colours.success : Colours.alpha(Colours.ink, 0.16)
                    border.width: 1
                    border.color: side.lit ? Colours.alpha(Colours.success, 0.5) : Colours.alpha(Colours.ink, 0.1)

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 2.6
                        height: width
                        radius: width / 2
                        color: Colours.alpha(Colours.success, 0.22)
                        visible: side.lit
                        z: -1
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 240
                        }
                    }
                }
            }
        }

        // the sunken slot the stick swings in
        Rectangle {
            id: slot

            anchors.horizontalCenter: parent.horizontalCenter
            y: lever.height * 0.62
            width: lever.width - 2 * 52
            height: 14
            radius: 7
            color: Colours.alpha(Colours.ink0, 0.55)
            border.width: 1
            border.color: Colours.alpha(Colours.ink, 0.1)

            // a soft groove highlight along the bottom lip
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 2
                height: 1
                color: Colours.alpha(Colours.ink, 0.08)
            }

            // the notches the stick clicks into, and the middle it crosses
            Repeater {
                model: 3

                Rectangle {
                    required property int index

                    x: [6, slot.width / 2 - 1, slot.width - 8][index]
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: index === 1 ? 4 : 6
                    radius: 1
                    color: Colours.alpha(Colours.ink, index === 1 ? 0.12 : 0.2)
                }
            }
        }

        // the stick, turning round its pivot in the slot
        Item {
            id: stick

            readonly property real len: lever.height * 0.62

            x: lever.width / 2 - width / 2
            y: slot.y + slot.height / 2 - stick.len
            width: 30
            height: stick.len
            transform: Rotation {
                origin.x: stick.width / 2
                origin.y: stick.len
                angle: lever.angle
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                width: 6
                height: stick.len - 10
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Colours.alpha(Colours.ink, 0.55) }
                    GradientStop { position: 0.5; color: Colours.alpha(Colours.ink, 0.85) }
                    GradientStop { position: 1; color: Colours.alpha(Colours.ink, 0.45) }
                }
            }

            // the ball: the accent, a highlight on its upper left
            Rectangle {
                id: ball

                anchors.horizontalCenter: parent.horizontalCenter
                width: 24 * (1 + grab.pressedBy * 0.08)
                height: width
                radius: width / 2
                y: 10 - height / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.lighter(Colours.accent, 1.35) }
                    GradientStop { position: 0.55; color: Colours.accent }
                    GradientStop { position: 1; color: Qt.darker(Colours.accent, 1.45) }
                }
                border.width: 1
                border.color: Colours.alpha(Colours.ink0, 0.35)

                Rectangle {
                    x: parent.width * 0.22
                    y: parent.height * 0.16
                    width: parent.width * 0.32
                    height: parent.height * 0.22
                    radius: height / 2
                    rotation: -30
                    color: Qt.rgba(1, 1, 1, 0.42)
                }
            }
        }

        // the pivot cap over the stick's foot
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: slot.y + slot.height / 2 - 5
            width: 10
            height: 10
            radius: 5
            color: Colours.alpha(Colours.ink, 0.5)
            border.width: 1
            border.color: Colours.alpha(Colours.ink0, 0.4)
        }
    }

    // ── the hand: click flips, a drag throws
    MouseArea {
        id: grab

        property real pressX: 0
        property real pressAngle: 0
        property bool moved: false
        property bool crossedSide: false
        readonly property real pressedBy: grab.pressed ? 1 : 0

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: grab.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true

        onPressed: mouse => {
            grab.pressX = mouse.x;
            grab.pressAngle = lever.angle;
            grab.moved = false;
            grab.crossedSide = lever.angle >= 0;
            lever.handAngle = lever.angle;
            lever.held = true;
        }
        onPositionChanged: mouse => {
            if (!grab.pressed)
                return;
            const dx = mouse.x - grab.pressX;
            if (Math.abs(dx) > 3)
                grab.moved = true;
            if (!grab.moved)
                return;
            // the ball follows the hand along its arc, a little past the notch
            const a = Math.max(-lever.swing * 1.12, Math.min(lever.swing * 1.12, grab.pressAngle + dx / (lever.width * 0.32) * lever.swing));
            lever.handAngle = a;
            const side = a >= 0;
            if (side !== grab.crossedSide) {
                grab.crossedSide = side;
                Sfx.tick(0.8);
            }
        }
        onReleased: {
            lever.held = false;
            if (!grab.moved) {
                lever.throwTo(!lever.wantRight);
                return;
            }
            const toRight = lever.handAngle >= 0;
            if (toRight !== lever.wantRight)
                lever.throwTo(toRight);
            else
                land.restart();
        }
        onCanceled: lever.held = false
        onWheel: wheel => {
            const toRight = wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0;
            lever.throwTo(toRight);
        }
    }
}
