//  VELVET  ·  modules/bar/entries/StatusIcons.qml
//  Network, bluetooth, sound, battery, and live CPU/RAM gauges.
//  Hovering the cluster opens the quick panel.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property bool vertical: true
    property int span: 30
    property var win: null

    readonly property int isz: Config.bar.iconSize
    readonly property real gaugeLen: Math.round(root.span * 0.9)

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    Grid {
        id: grid

        flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
        columns: root.vertical ? 1 : 99
        rows: root.vertical ? 99 : 1
        spacing: Math.round(Config.bar.spacing * 0.7)
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        // ------------------------------------------------------------ network
        Icon {
            visible: Config.bar.status.network
            name: Net.icon
            font.pixelSize: root.isz
            color: Net.connected ? Colours.ink : Colours.alpha(Colours.inkDim, 0.55)
        }

        // ---------------------------------------------------------- bluetooth
        Icon {
            visible: Config.bar.status.bluetooth && Net.btAvailable
            name: Net.btPowered ? "bluetooth" : "bluetooth_disabled"
            font.pixelSize: root.isz
            color: Net.btConnectedCount > 0 ? Colours.accent : (Net.btPowered ? Colours.ink : Colours.alpha(Colours.inkDim, 0.55))
        }

        // ------------------------------------------------------------- volume
        Icon {
            id: volumeGlyph

            visible: Config.bar.status.volume
            name: Audio.muted ? "volume_off" : (Audio.volume > 0.5 ? "volume_up" : "volume_down")
            font.pixelSize: root.isz
            color: Audio.muted ? Colours.danger : Colours.ink

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }

            // A small kick whenever the volume actually moves, so scrolling
            // over the bar has feedback even without the OSD.
            Connections {
                target: Audio
                function onVolumeChangedByUser(): void {
                    kick.restart();
                }
            }

            SequentialAnimation {
                id: kick

                NumberAnimation {
                    target: volumeGlyph
                    property: "scale"
                    to: 1.28
                    duration: 70
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: volumeGlyph
                    property: "scale"
                    to: 1.0
                    duration: 210
                    easing.type: Easing.OutBack
                    easing.overshoot: 3
                }
            }
        }

        // ------------------------------------------------------------ battery
        Item {
            visible: Config.bar.status.battery && Battery.available
            implicitWidth: root.vertical ? root.span : batteryRow.implicitWidth
            implicitHeight: root.vertical ? batteryCol.implicitHeight : root.span

            Column {
                id: batteryCol
                visible: root.vertical
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Battery.charging ? "battery_charging_full" : (Battery.critical ? "battery_alert" : "battery_full")
                    font.pixelSize: root.isz
                    color: Battery.critical ? Colours.danger : (Battery.low ? Colours.warning : (Battery.charging ? Colours.success : Colours.ink))
                }

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${Battery.percent}%`
                    color: Colours.inkDim
                    font.pixelSize: Config.bar.fontSize * 0.78
                }
            }

            Row {
                id: batteryRow
                visible: !root.vertical
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Battery.charging ? "battery_charging_full" : (Battery.critical ? "battery_alert" : "battery_full")
                    font.pixelSize: root.isz
                    color: Battery.critical ? Colours.danger : (Battery.low ? Colours.warning : (Battery.charging ? Colours.success : Colours.ink))
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Battery.percent}%`
                    color: Colours.inkDim
                    font.pixelSize: Config.bar.fontSize * 0.86
                }
            }
        }

        // --------------------------------------------------------------- CPU
        Gauge {
            visible: Config.bar.status.cpu
            vertical: root.vertical
            length: root.gaugeLen
            value: SysInfo.cpuPercent / 100
            label: "C"
            tint: Colours.accent
        }

        // --------------------------------------------------------------- RAM
        Gauge {
            visible: Config.bar.status.memory
            vertical: root.vertical
            length: root.gaugeLen
            value: SysInfo.memoryPercent / 100
            label: "M"
            tint: Colours.accentAlt
        }

        // -------------------------------------------------------------- temp
        P5Text {
            visible: Config.bar.status.temperature && SysInfo.temperature > 0
            text: `${Math.round(SysInfo.temperature)}°`
            color: SysInfo.temperature > 80 ? Colours.danger : Colours.inkDim
            font.pixelSize: Config.bar.fontSize * 0.9
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onEntered: Popout.request("quick", root, root.win)
        onExited: Popout.release("quick")
        onClicked: {
            Sfx.open();
            Popout.pin("quick", root, root.win);
        }
    }
}
