//  VELVET  ·  modules/lock/AuthCard.qml
//  The greeting and the password pill of the fluid lock, in one card.
//  The mechanics — invisible TextInput, submit on Enter, hard shake on a
//  wrong password — are the proven ones from LockScreen.qml; the dressing is
//  The fluid lock's: a welcome instead of a shout, round password dots, and the
//  status spoken inside the pill like a placeholder.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick

Item {
    id: root

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: parent.height * 0.055
    width: Math.max(340, Math.min(480, parent.width * 0.34))
    height: 210

    // The card arrives with the rest of the screen, one gesture.
    property real reveal: Locker.locked ? 1 : 0

    scale: 0.82 + 0.18 * root.reveal
    opacity: root.reveal

    Behavior on reveal {
        NumberAnimation {
            duration: Appearance.anim.entrance
            easing.type: Easing.OutExpo
        }
    }

    function takeFocus(): void {
        input.forceActiveFocus();
    }

    transform: Translate {
        id: shakeT
        x: 0
    }

    SequentialAnimation {
        id: shakeAnim

        NumberAnimation {
            target: shakeT
            property: "x"
            to: -22
            duration: 45
        }
        NumberAnimation {
            target: shakeT
            property: "x"
            to: 18
            duration: 55
        }
        NumberAnimation {
            target: shakeT
            property: "x"
            to: -9
            duration: 45
        }
        NumberAnimation {
            target: shakeT
            property: "x"
            to: 0
            duration: 60
        }
    }

    // The rejection reads as a rejection: on top of the side-to-side shake
    // the pill itself recoils, then settles back with a bounce.
    SequentialAnimation {
        id: punch

        NumberAnimation {
            target: pill
            property: "scale"
            to: 0.965
            duration: 70
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: pill
            property: "scale"
            to: 1
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 2.2
        }
    }

    Connections {
        target: Locker
        function onShake(): void {
            shakeAnim.restart();
            Sfx.back();
            punch.restart();
        }
    }

    Column {
        width: parent.width
        spacing: 16

        Row {
            width: root.width
            spacing: 16

            // The fluid lock's face box: round, accent-filled — and it blushes
            // danger on a wrong password, so the failure shows on the face.
            Rectangle {
                id: avatarBox

                width: 60
                height: 60
                radius: 30
                color: Locker.failed ? Colours.danger : Colours.accent

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                P5Text {
                    anchors.centerIn: parent
                    display: true
                    text: (Locker.user.charAt(0) || "?").toUpperCase()
                    color: Colours.on(avatarBox.color)
                    font.pixelSize: 33
                    tracking: 0
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                width: parent.width - 76

                P5Text {
                    width: parent.width
                    text: "Welcome back, " + (Config.lock.greeting || Locker.user || "friend")
                    color: Colours.ink
                    font.weight: Font.DemiBold
                    font.pixelSize: Appearance.font.size.title
                    elide: Text.ElideRight
                }

                P5Text {
                    width: parent.width
                    text: "Logging in to " + (Quickshell.env("XDG_CURRENT_DESKTOP") || Quickshell.env("XDG_SESSION_DESKTOP") || "this machine")
                    color: Colours.alpha(Colours.inkDim, 0.85)
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }
        }

        // The pill — soft and rounded, border in the wallpaper accent.
        Rectangle {
            id: pill

            width: parent.width
            height: 74
            radius: 37
            color: Colours.alpha(Colours.surfaceHigh, 0.85)
            border.width: 2
            border.color: Locker.failed ? Colours.danger : (Locker.busy ? Colours.warning : Colours.accent)

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }

            // The fluid lock's password glyphs: round dots that pop in as you
            // type. A fixed row of slots — only the newest dot pops, and
            // the row melts back on clear, instead of the whole row being
            // torn down and rebuilt on every keystroke.
            Row {
                anchors.centerIn: parent
                spacing: 8

                Repeater {
                    model: 18

                    Rectangle {
                        required property int index

                        readonly property bool lit: index < input.text.length

                        width: 11
                        height: 11
                        radius: 5.5
                        color: Colours.ink
                        scale: lit ? 1 : 0.45
                        opacity: lit ? 1 : 0.16

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.anim.instant
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.2
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                }
            }

            // The silent password-killer, caught: caps lock surfaces as a
            // warning chip whenever the field is empty.
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                width: capLabel.implicitWidth + 24
                height: 26
                radius: 13
                color: Colours.alpha(Colours.warning, 0.16)
                border.width: 1
                border.color: Colours.alpha(Colours.warning, 0.7)
                opacity: Kbd.capsLock && input.text.length === 0 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                P5Text {
                    id: capLabel

                    anchors.centerIn: parent
                    display: true
                    text: "CAPS"
                    color: Colours.warning
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.8
                }
            }

            // The status, spoken inside the field — the fluid lock's placeholder.
            P5Text {
                anchors.centerIn: parent
                visible: input.text.length === 0
                text: Locker.busy ? "CHECKING…" : (Locker.failed ? (Locker.message || "WRONG PASSWORD") : "ENTER PASSWORD")
                color: Locker.failed ? Colours.danger : (Locker.busy ? Colours.warning : Colours.alpha(Colours.inkDim, 0.55))
                font.pixelSize: Appearance.font.size.normal + 1
                tracking: 3
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: Locker.busy

                Repeater {
                    model: 3

                    Rectangle {
                        required property int index

                        width: 8
                        height: 8
                        radius: 4
                        color: Colours.accent

                        SequentialAnimation on opacity {
                            running: Locker.busy
                            loops: Animation.Infinite
                            PauseAnimation {
                                duration: index * 130
                            }
                            NumberAnimation {
                                to: 0.2
                                duration: 300
                            }
                            NumberAnimation {
                                to: 1.0
                                duration: 300
                            }
                            PauseAnimation {
                                duration: (2 - index) * 130
                            }
                        }
                    }
                }
            }

            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 28
                anchors.verticalCenter: parent.verticalCenter
                visible: !Locker.busy && input.text.length > 0
                name: "arrow_forward"
                color: Colours.accent
                font.pixelSize: Appearance.font.size.huge
            }

            TextInput {
                id: input

                anchors.fill: parent
                opacity: 0
                focus: true
                enabled: !Locker.busy
                echoMode: TextInput.Password

                onAccepted: {
                    Locker.submit(text, "");
                    text = "";
                }

                Keys.onEscapePressed: input.text = ""

                Component.onCompleted: input.forceActiveFocus()
            }

            MouseArea {
                anchors.fill: parent
                onClicked: input.forceActiveFocus()
            }
        }
    }
}
