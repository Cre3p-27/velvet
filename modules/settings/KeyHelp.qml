//  VELVET  ·  modules/settings/KeyHelp.qml
//  Every shortcut, rendered from config/Keys.qml so it cannot go stale.
import qs.config
import qs.services
import qs.components
import QtQuick

FocusScope {
    id: root

    signal closed

    focus: true

    Component.onCompleted: root.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        color: Colours.alpha(Colours.paper, 0.93)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Halftone {
        anchors.fill: parent
        strength: 0.035
        density: 1.6
    }

    Column {
        id: header

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.05
        spacing: 0

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            display: true
            text: "EVERY KEY"
            color: Colours.ink
            font.pixelSize: Appearance.font.size.hero * 0.5
            tracking: -1
        }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ANY KEY CLOSES THIS"
            color: Colours.accentInk
            font.pixelSize: Appearance.font.size.small
            tracking: 3
        }
    }

    Flickable {
        id: helpFlick

        anchors.top: header.bottom
        anchors.topMargin: Appearance.spacing.huge
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.05

        width: Math.min(parent.width * 0.86, 1500)
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Flow {
            id: grid

            width: parent.width
            spacing: Appearance.spacing.large

            Repeater {
                model: Shortcuts.sections

                Column {
                    id: section

                    required property var modelData
                    required property int index

                    width: Math.floor((grid.width - Appearance.spacing.large * 2) / 3)
                    spacing: 6

                    // Sections arrive in sequence rather than all at once.
                    opacity: 0

                    Component.onCompleted: enter.start()

                    SequentialAnimation {
                        id: enter

                        PauseAnimation {
                            duration: section.index * 55
                        }
                        NumberAnimation {
                            target: section
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Row {
                        spacing: 10

                        Slash {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5
                            height: 20
                            color: Colours.accent
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            display: true
                            text: section.modelData.name
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.large
                        }
                    }

                    P5Text {
                        x: 15
                        text: section.modelData.sub
                        color: Colours.alpha(Colours.inkDim, 0.8)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 2
                        bottomPadding: 6
                    }

                    Repeater {
                        model: section.modelData.keys

                        Row {
                            id: binding

                            required property var modelData

                            spacing: 10
                            height: 28

                            Slash {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(64, cap.implicitWidth + 20)
                                height: 24
                                shear: Appearance.skew
                                color: Colours.alpha(Colours.ink, 0.1)
                                borderColor: Colours.alpha(Colours.ink, 0.25)
                                borderWidth: 1

                                P5Text {
                                    id: cap

                                    anchors.centerIn: parent
                                    display: true
                                    text: binding.modelData.k
                                    color: Colours.ink
                                    font.pixelSize: Appearance.font.size.tiny
                                }
                            }

                            P5Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: binding.modelData.v
                                color: Colours.inkDim
                                font.pixelSize: Appearance.font.size.small
                            }
                        }
                    }
                }
            }
        }

        SmoothScroll {
            view: helpFlick
        }
    }

    Keys.onPressed: event => {
        root.closed();
        event.accepted = true;
    }
}
