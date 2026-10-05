//  VELVET  ·  modules/bar/entries/Clock.qml
//  Stacks hours over minutes in a vertical bar, runs inline when horizontal.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick

BarButton {
    id: root

    readonly property date now: clock.date
    readonly property string hh: (Config.bar.clock.format24h ? Qt.formatDateTime(now, "HH") : Qt.formatDateTime(now, "hh AP").split(" ")[0])
    readonly property string mm: Qt.formatDateTime(now, "mm")
    readonly property string ss: Qt.formatDateTime(now, "ss")
    readonly property string ampm: Qt.formatDateTime(now, "AP")
    readonly property real fs: Config.bar.fontSize + 1

    padding: 4
    active: Panels.notifCentre
    tip: "NOTIFICATIONS  ·  RIGHT-CLICK FOR CLOCK SETTINGS"

    onClicked: {
        Sfx.open();
        Panels.toggleNotifCentre();
    }
    onRightClicked: Panels.openSettingsKey("bar.clock.format24h")

    SystemClock {
        id: clock
        precision: Config.bar.clock.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Loader {
        sourceComponent: root.vertical ? stackedC : inlineC
    }

    // --------------------------------------------------------------- vertical
    Component {
        id: stackedC

        Column {
            spacing: -1

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: root.hh
                color: Colours.ink
                font.pixelSize: root.fs
                tracking: 0.5
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: root.mm
                color: Colours.accentInk
                font.pixelSize: root.fs
                tracking: 0.5
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Config.bar.clock.showSeconds
                height: visible ? implicitHeight : 0
                text: root.ss
                color: Colours.inkDim
                font.pixelSize: root.fs * 0.7

                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutExpo
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Config.bar.clock.showDate
                width: root.fs * 1.4
                height: visible ? 1 : 0
                color: Colours.alpha(Colours.inkDim, 0.4)

                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutExpo
                    }
                }
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Config.bar.clock.showDate
                height: visible ? implicitHeight : 0
                text: Qt.formatDateTime(root.now, "dd")
                color: Colours.inkDim
                font.pixelSize: root.fs * 0.74

                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutExpo
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- horizontal
    Component {
        id: inlineC

        Row {
            spacing: Appearance.spacing.small

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: `${root.hh}:${root.mm}${Config.bar.clock.showSeconds ? ":" + root.ss : ""}${Config.bar.clock.format24h ? "" : " " + root.ampm}`
                color: Colours.ink
                font.pixelSize: root.fs
                tracking: 0.8
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.bar.clock.showDate
                width: visible ? 1 : 0
                height: root.fs
                color: Colours.alpha(Colours.inkDim, 0.4)
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.bar.clock.showDate
                width: visible ? implicitWidth : 0
                text: Qt.formatDateTime(root.now, "dd MMM").toUpperCase()
                color: Colours.inkDim
                font.pixelSize: root.fs * 0.86

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutExpo
                    }
                }
            }
        }
    }
}
