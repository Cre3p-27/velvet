//  VELVET  ·  modules/bar/entries/Logo.qml
//  The mark. Click opens Settings, right-click opens the launcher. In the
//  WINDOWS look it is the Start button of the chosen edition.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    readonly property bool isWin: Appearance.skin === "win"
    readonly property string wv: Appearance.winVer
    readonly property bool pressedLook: Panels.settings

    active: Panels.settings && !root.isWin
    hoverable: !root.isWin
    padding: root.isWin ? 0 : 3
    tip: "SETTINGS  ·  RIGHT-CLICK FOR THE LAUNCHER"

    onClicked: {
        Sfx.open();
        Panels.toggleSettings();
    }
    onRightClicked: {
        Sfx.open();
        Panels.toggleLauncher();
    }

    Item {
        implicitWidth: root.isWin ? (root.vertical ? root.span : ({ "95": 70, "xp": 100, "7": 44, "10": 46, "11": 44 })[root.wv] ?? 46) : root.span
        implicitHeight: root.isWin ? (root.vertical ? ({ "95": 34, "xp": 40, "7": 44, "10": 46, "11": 44 })[root.wv] ?? 44 : root.span + root.padding * 2 + 6) : root.span
        width: implicitWidth
        height: implicitHeight

        Loader {
            anchors.fill: parent
            sourceComponent: root.isWin ? ({
                    "95": start95,
                    "xp": startXp,
                    "7": start7,
                    "10": start10,
                    "11": start11
                })[root.wv] ?? start11 : house
        }
    }

    Component {
        id: house

        Item {
            Slash {
                anchors.fill: parent
                anchors.margins: 1
                shear: Appearance.skew * 1.6
                color: root.active ? Colours.paper : Colours.accent
                borderColor: "transparent"
            }

            P5Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                display: true
                text: "V"
                color: root.active ? Colours.accent : Colours.on(Colours.accent)
                font.pixelSize: root.span * 0.62
                tracking: 0
            }
        }
    }

    // ── 95: a raised grey button that says Start
    Component {
        id: start95

        Item {
            WinBox {
                anchors.fill: parent
                anchors.margins: 3
                kind: "button"
                pressed: root.pressedLook
                hot: root.containsMouse

                Row {
                    anchors.centerIn: parent
                    spacing: 5

                    WinLogo {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.vertical
                        text: "Start"
                        color: "#000000"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }

    // ── XP: the green pill
    Component {
        id: startXp

        Item {
            Item {
                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                clip: true

                Rectangle {
                    x: root.vertical ? 0 : -18
                    width: parent.width + (root.vertical ? 0 : 18)
                    height: parent.height
                    radius: root.vertical ? 8 : 18

                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: root.containsMouse ? "#6ad852" : "#52c53e"
                        }
                        GradientStop {
                            position: 0.45
                            color: root.containsMouse ? "#4cb83a" : "#3c9a2f"
                        }
                        GradientStop {
                            position: 1
                            color: root.pressedLook ? "#2a6b20" : "#2f7d23"
                        }
                    }
                }
            }
            Row {
                anchors.centerIn: parent
                spacing: 7

                WinLogo {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                }
                Item {
                    visible: !root.vertical
                    anchors.verticalCenter: parent.verticalCenter
                    width: xpText.implicitWidth
                    height: xpText.implicitHeight

                    P5Text {
                        x: 1
                        y: 1
                        text: "start"
                        color: "#1c4d14"
                        opacity: 0.7
                        font.pixelSize: 20
                        font.weight: Font.Black
                        font.italic: true
                    }
                    P5Text {
                        id: xpText

                        text: "start"
                        color: "#ffffff"
                        font.pixelSize: 20
                        font.weight: Font.Black
                        font.italic: true
                    }
                }
            }
        }
    }

    // ── 7: the glossy orb
    Component {
        id: start7

        Item {
            Rectangle {
                id: orb

                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) - 4
                height: width
                radius: width / 2
                border.width: 2
                border.color: root.containsMouse || root.pressedLook ? "#d8ecff" : "#9fc4ea"

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: root.containsMouse ? "#bfe0ff" : "#86bff5"
                    }
                    GradientStop {
                        position: 0.5
                        color: root.containsMouse ? "#3f8fe0" : "#2f78cc"
                    }
                    GradientStop {
                        position: 1
                        color: "#14468a"
                    }
                }
            }
            // the highlight on the glass
            Rectangle {
                anchors.horizontalCenter: orb.horizontalCenter
                y: orb.y + 3
                width: orb.width * 0.7
                height: orb.height * 0.38
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.38)
            }
            WinLogo {
                anchors.centerIn: orb
                width: 22
                height: 22
            }
        }
    }

    // ── 10: a flat square with a white logo, a wash under the pointer
    Component {
        id: start10

        Item {
            Rectangle {
                anchors.fill: parent
                color: root.pressedLook ? Colours.alpha(Colours.accent, 0.8) : (root.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: 90
                    }
                }
            }
            WinLogo {
                anchors.centerIn: parent
                width: 20
                height: 20
                mono: root.pressedLook ? Colours.on(Colours.accent) : Colours.ink
            }
        }
    }

    // ── 11: the colour logo, a rounded wash, a small lift
    Component {
        id: start11

        Item {
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 6
                color: root.pressedLook ? Colours.alpha(Colours.ink, 0.1) : (root.containsMouse ? Colours.alpha(Colours.ink, 0.07) : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: 110
                    }
                }
            }
            WinLogo {
                anchors.centerIn: parent
                width: 22
                height: 22
                scale: root.containsMouse ? 1.08 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: 110
                    }
                }
            }
        }
    }
}
