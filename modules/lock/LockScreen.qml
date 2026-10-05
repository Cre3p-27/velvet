//  VELVET  ·  modules/lock/LockScreen.qml
//  The lock, built in layers. The core — ground colour, clock, password field —
//  has no exotic dependencies and always draws. Everything decorative sits in
//  its own Loader, so if a texture or the media strip fails on some machine you
//  get a plainer lock screen rather than a black one.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

WlSessionLock {
    id: lock

    locked: Locker.locked

    WlSessionLockSurface {
        id: surface

        // Never transparent: this colour is the guarantee that something is
        // painted even if every layer above fails to load.
        color: Colours.paper

        // This look has no exit choreography: hand over at once instead of
        // sitting on the 1.5 s rescue timer after a correct password.
        Connections {
            target: Locker
            function onReleasingChanged(): void {
                if (Locker.releasing)
                    Locker.exitDone();
            }
        }

        // ═══════════════════════════════════════════════════ decorative layers
        Loader {
            anchors.fill: parent
            active: Config.wallpaper.current !== ""

            sourceComponent: Item {
                Image {
                    anchors.fill: parent
                    source: "file://" + Config.wallpaper.current
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    scale: 1.06

                    SequentialAnimation on scale {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 1.06
                            to: 1.12
                            duration: 40000
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 1.12
                            to: 1.06
                            duration: 40000
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Colours.alpha(Colours.paper, Config.lock.backgroundDim)
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: Config.appearance.halftone

            sourceComponent: Item {
                SpeedLines {
                    anchors.fill: parent
                    color: Colours.accent
                    strength: 0.045
                    originX: 0.12
                    originY: 0.75
                    count: 16
                }

                Halftone {
                    anchors.fill: parent
                    strength: 0.04
                    angle: -14
                }
            }
        }

        Slash {
            width: surface.width * 1.4
            height: 4
            x: -surface.width * 0.2
            y: surface.height * 0.78
            shear: 0
            rotation: -4
            color: Colours.accent
            opacity: 0.45
        }

        // ═════════════════════════════════════════════════════════ core: clock
        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }

        // LOCK SCREEN → VIBE FACES → CLOCK: the hours, the seconds, the size and
        // the date's format are shared by this lock and the lock of every look.
        readonly property bool h24: Config.lock.vClock === "24h" || (Config.lock.vClock !== "12h" && Config.bar.clock.format24h)
        readonly property real clockPx: Math.max(48, Math.min(surface.height * 0.28, 360)) * Math.max(0.4, Math.min(1.3, Config.lock.vScale))
        readonly property string dateText: ({
                "off": "",
                "short": Qt.formatDateTime(clock.date, "ddd d MMM"),
                "numeric": Qt.formatDateTime(clock.date, "dd.MM.yyyy")
            })[Config.lock.vDate] ?? Qt.formatDateTime(clock.date, "dddd, dd MMMM")

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.height * 0.12
            spacing: -surface.height * 0.04

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: surface.width * 0.018

                P5Text {
                    display: true
                    text: Qt.formatDateTime(clock.date, surface.h24 ? "HH" : "h AP").split(" ")[0].padStart(2, "0")
                    color: Colours.ink
                    font.pixelSize: surface.clockPx
                    tracking: -10
                }

                P5Text {
                    display: true
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: Colours.accent
                    font.pixelSize: surface.clockPx
                    tracking: -10

                    // The minutes breathe, so the screen is never quite static.
                    // (and the seconds, when asked for, sit small beside them)
                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.78
                            duration: 2600
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1.0
                            duration: 2600
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                P5Text {
                    visible: Config.lock.vSeconds
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: surface.clockPx * 0.16
                    display: true
                    text: Qt.formatDateTime(clock.date, "ss")
                    color: Colours.inkDim
                    font.pixelSize: surface.clockPx * 0.3
                    tracking: -2
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18
                visible: surface.dateText !== ""

                Slash {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7
                    height: 32
                    color: Colours.accent
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: surface.dateText.toUpperCase()
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.large
                    tracking: 4
                }
            }
        }

        // A soft accent aura behind the clock and the card — the colour is
        // the wallpaper's accent, so the glow always matches the picture.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.height * 0.07
            width: Math.min(1100, surface.width * 0.72)
            height: surface.height * 0.52
            radius: height / 2
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Colours.alpha(Colours.accent, 0.10)
                }
                GradientStop {
                    position: 0.55
                    color: Colours.alpha(Colours.accent, 0.035)
                }
                GradientStop {
                    position: 1.0
                    color: Colours.alpha(Colours.accent, 0.0)
                }
            }
        }

        // ══════════════════════════════════════════════════════════ core: auth
        Item {
            id: card

            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.height * 0.52
            width: Math.max(360, Math.min(760, surface.width * 0.5))
            height: 200

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

            // The rejection reads as a rejection: a low step of sound and
            // the pill recoils, on top of the side-to-side shake.
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
                    spacing: 16

                    Slash {
                        width: 60
                        height: 60
                        shear: Appearance.skew
                        color: Colours.accent

                        P5Text {
                            anchors.centerIn: parent
                            display: true
                            text: (Locker.user.charAt(0) || "?").toUpperCase()
                            color: Colours.on(Colours.accent)
                            font.pixelSize: 33
                            tracking: 0
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -2

                        P5Text {
                            display: true
                            text: (Config.lock.greeting || Locker.user || "LOCKED").toUpperCase()
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.title
                        }

                        P5Text {
                            text: Locker.message || "ENTER PASSWORD"
                            color: Locker.failed ? Colours.danger : Colours.accentInk
                            font.pixelSize: Appearance.font.size.small
                            tracking: 2.4
                        }
                    }
                }

                // The password pill — soft and rounded like the rest of the
                // shell's friendlier panels, border in the wallpaper accent.
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

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 32
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7

                        // A fixed slot row — the model used to be the text
                        // length, which rebuilt every slash on each keystroke.
                        // Now only the newest grows in; the row collapses on
                        // clear instead of being torn down.
                        Repeater {
                            model: 28

                            Slash {
                                required property int index

                                readonly property bool lit: index < input.text.length

                                width: 7
                                height: lit ? 28 : 0
                                shear: Appearance.skew * 2
                                color: Colours.ink
                                opacity: lit ? 1 : 0

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Appearance.anim.instant
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.4
                                    }
                                }
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Appearance.anim.instant
                                    }
                                }
                            }
                        }
                    }

                    P5Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 32
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text.length === 0 && !Locker.busy
                        text: "···"
                        color: Colours.alpha(Colours.inkDim, 0.5)
                        font.pixelSize: Appearance.font.size.huge
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

        // Nothing else can hold focus on a lock surface, but a stray click on
        // the background shouldn't leave you typing into nowhere either.
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: input.forceActiveFocus()
        }

        // ═══════════════════════════════════════════════════════════ test mode
        Slash {
            anchors.horizontalCenter: parent.horizontalCenter
            y: surface.height * 0.055
            width: 460
            height: 56
            shear: Appearance.skew
            color: Colours.warning
            visible: Locker.testing

            P5Text {
                anchors.centerIn: parent
                display: true
                text: "TEST — RELEASES ITSELF IN 20 SECONDS"
                color: Colours.paper
                font.pixelSize: Appearance.font.size.normal
            }
        }

        // ══════════════════════════════════════════════════════════ status bar
        Row {
            anchors.right: parent.right
            anchors.rightMargin: surface.width * 0.06
            anchors.bottom: parent.bottom
            anchors.bottomMargin: surface.height * 0.07
            spacing: 26

            Row {
                spacing: 8
                visible: Battery.available

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Battery.charging ? "battery_charging_full" : "battery_full"
                    color: Battery.critical ? Colours.danger : Colours.inkDim
                    font.pixelSize: Appearance.font.size.large
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: `${Battery.percent}%`
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.normal
                }
            }

            Row {
                spacing: 8

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Net.icon
                    color: Net.connected ? Colours.inkDim : Colours.alpha(Colours.inkDim, 0.4)
                    font.pixelSize: Appearance.font.size.large
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Net.label.toUpperCase()
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.normal
                    tracking: 1.6
                }
            }
        }

        Loader {
            anchors.left: parent.left
            anchors.leftMargin: surface.width * 0.075
            anchors.bottom: parent.bottom
            anchors.bottomMargin: surface.height * 0.07
            width: Math.min(620, surface.width * 0.42)

            active: Config.lock.showMedia
            source: "MediaStrip.qml"
        }

        // The way out, spelled out once you have clearly got stuck.
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            visible: Locker.attempts >= 3 || Locker.pamErrors > 0
            text: `${Locker.pamConfig ? "PAM: " + Locker.pamConfig + "   ·   " : ""}STUCK?  CTRL+ALT+F2  ·  LOG IN  ·  loginctl unlock-session`
            color: Colours.alpha(Colours.inkDim, 0.75)
            font.family: Appearance.fontFamily.mono
            font.pixelSize: Appearance.font.size.small
        }
    }
}
