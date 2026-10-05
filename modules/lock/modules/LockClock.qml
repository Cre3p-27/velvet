//  VELVET  ·  modules/lock/modules/LockClock.qml
//  The lock's clock — hours in the accent, minutes in the alt accent, side
//  by side with no colon, AM/PM in a small pill, the date quiet
//  underneath, all on a card with a faint circle watermark. Every minute
//  the digits pop once, like a heartbeat.
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import Quickshell
import QtQuick

Item {
    id: root

    property bool compact: false
    property bool carded: true

    implicitWidth: root.compact ? compactRow.width : clockRow.width + 64
    implicitHeight: root.compact ? 26 : clockRow.height + 78

    SystemClock {
        id: clock
        precision: root.compact ? SystemClock.Minutes : SystemClock.Seconds
    }

    ModuleCard {
        anchors.fill: parent
        glyphKind: 0
        carded: root.carded
        visible: !root.compact
    }

    // ── the island rendering: just the time
    Row {
        id: compactRow

        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.compact
        spacing: 2

        P5Text {
            text: (Config.bar.clock.format24h ? Qt.formatDateTime(clock.date, "HH:mm") : Qt.formatDateTime(clock.date, "hh:mm AP").split(" ")[0])
            color: Colours.accent
            font.weight: Font.Light
            font.pixelSize: 20
            tracking: -1
        }
    }

    Row {
        id: clockRow

        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.compact ? 0 : 12
        visible: !root.compact
        spacing: root.width * 0.012

        P5Text {
            id: hours

            text: (Config.bar.clock.format24h ? Qt.formatDateTime(clock.date, "HH") : Qt.formatDateTime(clock.date, "hh AP").split(" ")[0])
            color: Colours.accent
            font.weight: Font.Light
            font.pixelSize: Math.max(64, Math.min(root.height * 0.6, 160))
            tracking: -4
        }

        P5Text {
            id: minutes

            text: Qt.formatDateTime(clock.date, "mm")
            color: Colours.accentAlt
            font.weight: Font.Light
            font.pixelSize: Math.max(64, Math.min(root.height * 0.6, 160))
            tracking: -4

            // The minute hand lands with a small pop — the clock's heartbeat.
            property string last: text
            onTextChanged: t => {
                if (t !== last) {
                    last = t;
                    tick.restart();
                }
            }

            SequentialAnimation {
                id: tick

                NumberAnimation {
                    target: minutes
                    property: "scale"
                    to: 1.05
                    duration: 90
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: minutes
                    property: "scale"
                    to: 1
                    duration: 260
                    easing.type: Easing.OutBack
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Config.bar.clock.format24h
            width: amPm.implicitWidth + 18
            height: 26
            radius: 13
            color: Colours.alpha(Colours.surfaceHigh, 0.8)
            antialiasing: true

            P5Text {
                id: amPm

                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "AP").toUpperCase()
                color: Colours.ink
                font.pixelSize: Appearance.font.size.small
                tracking: 1
            }
        }
    }

    P5Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.compact ? 0 : 10
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !root.compact
        text: Qt.formatDateTime(clock.date, "dddd • d MMM").toUpperCase()
        color: Colours.alpha(Colours.inkDim, 0.9)
        font.pixelSize: Appearance.font.size.small
        tracking: 3
    }
}
