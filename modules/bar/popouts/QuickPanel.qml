//  VELVET  ·  modules/bar/popouts/QuickPanel.qml
//  Everything you reach for ten times a day, one hover away from the bar.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    readonly property int pad: Appearance.padding.large

    implicitWidth: 344
    implicitHeight: column.implicitHeight + pad * 2

    Column {
        id: column

        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: Appearance.spacing.normal

        // ------------------------------------------------------------ header
        Row {
            width: parent.width
            spacing: Appearance.spacing.small

            Slash {
                anchors.verticalCenter: parent.verticalCenter
                width: 5
                height: 20
                color: Colours.accent
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: "QUICK"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.large
            }

            Item {
                width: column.width - 5 - Appearance.spacing.small * 2 - 60
                height: 1
            }
        }

        // ----------------------------------------------------------- sliders
        Row {
            width: parent.width
            spacing: Appearance.spacing.small

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Audio.muted ? "volume_off" : "volume_up"
                color: Audio.muted ? Colours.danger : Colours.ink
                font.pixelSize: Appearance.font.size.large
                width: 24

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sfx.toggle();
                        Audio.toggleMute();
                    }
                }
            }

            SlashSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 - 46 - Appearance.spacing.small * 2
                value: Audio.volume
                tint: Audio.muted ? Colours.alpha(Colours.ink, 0.3) : Colours.accent
                onMoved: v => Audio.setVolume(v)
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                horizontalAlignment: Text.AlignRight
                display: true
                text: `${Math.round(Audio.volume * 100)}`
                color: Colours.ink
                font.pixelSize: Appearance.font.size.normal
            }
        }

        Row {
            width: parent.width
            spacing: Appearance.spacing.small
            visible: Audio.source !== null

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Audio.micMuted ? "mic_off" : "mic"
                color: Audio.micMuted ? Colours.danger : Colours.ink
                font.pixelSize: Appearance.font.size.large
                width: 24

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sfx.toggle();
                        Audio.toggleMicMute();
                    }
                }
            }

            SlashSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 - 46 - Appearance.spacing.small * 2
                value: Audio.micVolume
                tint: Audio.micMuted ? Colours.alpha(Colours.ink, 0.3) : Colours.accentAlt
                onMoved: v => Audio.setMicVolume(v)
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                horizontalAlignment: Text.AlignRight
                display: true
                text: `${Math.round(Audio.micVolume * 100)}`
                color: Colours.ink
                font.pixelSize: Appearance.font.size.normal
            }
        }

        Row {
            width: parent.width
            spacing: Appearance.spacing.small
            visible: Brightness.available

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "light_mode"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.large
                width: 24
            }

            SlashSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 - 46 - Appearance.spacing.small * 2
                value: Brightness.brightness
                tint: Colours.warning
                onMoved: v => Brightness.setBrightness(v)
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                horizontalAlignment: Text.AlignRight
                display: true
                text: `${Math.round(Brightness.brightness * 100)}`
                color: Colours.ink
                font.pixelSize: Appearance.font.size.normal
            }
        }

        // -------------------------------------------- the shell's own fader
        //  Velvet's clicks and whooshes have their own level, deliberately
        //  separate from the desktop's: turning the menu sounds down must
        //  never touch your music. The icon is the master switch, the fader
        //  is the level, and letting go plays one click so you hear what you
        //  just set. Same two values SHELL → SOUND writes.
        Rectangle {
            width: parent.width
            height: 1
            color: Colours.alpha(Colours.ink, 0.12)
        }

        P5Text {
            text: "SHELL SOUND"
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.2
        }

        Row {
            width: parent.width
            spacing: Appearance.spacing.small

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Config.sfx.enabled ? "graphic_eq" : "volume_off"
                color: Config.sfx.enabled ? Colours.ink : Colours.danger
                font.pixelSize: Appearance.font.size.large
                width: 24

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Play on the right side of the toggle: the last click
                        // you hear going off, the first you hear coming back.
                        const goingOff = Config.sfx.enabled;
                        if (goingOff)
                            Sfx.toggle();
                        Config.toggle("sfx.enabled");
                        if (!goingOff)
                            Sfx.toggle();
                    }
                }
            }

            SlashSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 24 - 46 - Appearance.spacing.small * 2
                value: Config.sfx.volume
                tint: Config.sfx.enabled ? Colours.accentAlt : Colours.alpha(Colours.ink, 0.3)
                onMoved: v => Config.set("sfx.volume", v)
                onReleased: Sfx.cursor()
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                horizontalAlignment: Text.AlignRight
                display: true
                text: `${Math.round(Config.sfx.volume * 100)}`
                color: Config.sfx.enabled ? Colours.ink : Colours.inkDim
                font.pixelSize: Appearance.font.size.normal
            }
        }

        // ------------------------------------------------------------- chips
        Flow {
            width: parent.width
            spacing: Appearance.spacing.small

            Chip {
                label: "BLUETOOTH"
                icon: "bluetooth"
                on: Net.btPowered
                visible: Net.btAvailable
                onToggled: Net.toggleBluetooth()
            }

            Chip {
                label: "NIGHT"
                icon: "dark_mode"
                on: Config.services.nightLight
                onToggled: Config.toggle("services.nightLight")
            }

            Chip {
                label: "AWAKE"
                icon: "bedtime"
                on: Config.services.idleInhibit
                onToggled: Config.toggle("services.idleInhibit")
            }

            Chip {
                label: "SILENT"
                icon: "notifications_off"
                on: Config.notifs.doNotDisturb
                onToggled: Config.toggle("notifs.doNotDisturb")
            }

            Chip {
                label: "FOCUS"
                icon: "do_not_disturb_on"
                on: Focus.active
                onToggled: Focus.toggle()
            }

            Chip {
                label: `PAD · P${Pad.player}`
                icon: "sports_esports"
                on: Pad.player === 2
                onToggled: Pad.toggle()
            }
        }

        // -------------------------------------------------------------- info
        Rectangle {
            width: parent.width
            height: 1
            color: Colours.alpha(Colours.ink, 0.12)
        }

        Column {
            width: parent.width
            spacing: 3

            P5Text {
                text: `${Net.label}${Net.type === "wifi" && Net.connected ? "  ·  " + Net.strength + "%" : ""}`
                color: Colours.ink
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
                width: parent.width
            }

            // Battery as a Material ring: the sweep is the charge,
            // the colour speaks before the number does.
            Row {
                width: parent.width
                spacing: Appearance.spacing.small
                visible: Battery.available

                CircularProgress {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    thickness: 4
                    value: Battery.percent / 100
                    color: Battery.charging ? Colours.accentAlt : (Battery.percent < 20 ? Colours.danger : Colours.accent)
                    text: `${Battery.percent}`
                    textSize: Appearance.font.size.tiny - 1
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Battery.charging ? "CHARGING" + (Battery.timeRemaining ? "  ·  " + Battery.timeRemaining + " TO FULL" : "") : (Battery.timeRemaining ? Battery.timeRemaining + " LEFT" : "")
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.small
                }
            }

            P5Text {
                text: `CPU ${Math.round(SysInfo.cpuPercent)}%   ·   RAM ${SysInfo.memoryUsedGb.toFixed(1)} / ${SysInfo.memoryTotalGb.toFixed(1)} GB`
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    // ------------------------------------------------------------ inline chip
    component Chip: Item {
        id: chip

        property string label: ""
        property string icon: ""
        property bool on: false

        signal toggled

        implicitWidth: chipRow.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: 32

        scale: chipArea.pressed ? 0.93 : (chipArea.containsMouse ? 1.05 : 1.0)

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
                easing.overshoot: 2.6
            }
        }

        Slash {
            anchors.fill: parent
            shear: Appearance.skew
            color: chip.on ? Colours.accent : Colours.alpha(Colours.ink, chipArea.containsMouse ? 0.16 : 0.08)

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 5

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                color: chip.on ? Colours.on(Colours.accent) : Colours.inkDim
                font.pixelSize: Appearance.font.size.normal
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: chip.label
                color: chip.on ? Colours.on(Colours.accent) : Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
            }
        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sfx.toggle();
                chip.toggled();
            }
        }
    }
}
