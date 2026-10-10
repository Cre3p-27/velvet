//  VELVET  ·  modules/osd/Osd.qml
//  Volume and brightness flash. Appears on change, gets out of the way fast.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property string mode: "volume"    // volume | brightness
    property bool shown: false

    readonly property real value: mode === "volume" ? Audio.volume : Brightness.brightness
    // how the pop-up is built: the look's way, or VISUALS → THIS LOOK → SHELL PARTS
    readonly property string style: Appearance.osdStyle
    readonly property bool house: root.style === "velvet"
    readonly property int pct: Math.round(Math.min(1, root.value) * 100)
    readonly property bool muted: mode === "volume" && Audio.muted
    readonly property string glyph: {
        if (mode === "brightness")
            return "light_mode";
        if (muted)
            return "volume_off";
        return value > 0.5 ? "volume_up" : "volume_down";
    }

    screen: Hypr.focusedScreen
    // Stay mapped until the card has faded, or the exit easing is never seen.
    visible: Config.osd.enabled && (shown || card.opacity > 0.01)
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        top: Config.osd.position !== "bottom"
        bottom: Config.osd.position !== "top"
        left: true
        right: true
    }

    implicitHeight: 96

    margins {
        top: Config.osd.position === "top" ? 60 : 0
        bottom: Config.osd.position === "bottom" ? 90 : 0
    }

    mask: Region {
        item: card
    }

    Connections {
        target: Audio
        function onVolumeChangedByUser(): void {
            root.mode = "volume";
            root.pop();
        }
    }

    Connections {
        target: Brightness
        function onChangedByUser(): void {
            root.mode = "brightness";
            root.pop();
        }
    }

    function pop(): void {
        // (the settings are a window now: the pop-up shows over it too)
        root.shown = true;
        iconPop.restart();
        textPop.restart();
        hide.restart();
    }

    Timer {
        id: hide
        interval: Config.osd.timeout
        onTriggered: root.shown = false
    }

    Item {
        id: card

        // MODULES → OSD → SIDE: left, middle or right of its edge
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round(Appearance.sideX(Config.osd.side, parent.width, card.width, 24, true))
        width: 420
        height: 68
        scale: root.shown ? 1 : 0.9
        opacity: root.shown ? 1 : 0

        // The inspo OSDs are lively: it pops in with overshoot and eases
        // back out instead of blinking.
        Behavior on opacity {
            NumberAnimation {
                duration: root.shown ? Appearance.anim.entrance : Appearance.anim.normal
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.entrance
                easing.type: root.shown ? Easing.OutBack : Easing.InCubic
            }
        }

        Slash {
            anchors.fill: parent
            visible: root.house
            shear: Appearance.skew
            color: Colours.alpha(Colours.surfaceHigh, 0.96)
            borderColor: Colours.accent
            borderWidth: 3
        }
        StyleCard {
            id: ground

            anchors.fill: parent
            visible: !root.house
            style: root.style
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 30
            anchors.rightMargin: 26
            spacing: 18

            Icon {
                id: icon

                anchors.verticalCenter: parent.verticalCenter
                visible: root.style !== "prompt"
                name: root.glyph
                color: root.muted ? Colours.danger : (root.style === "start" || root.style === "poster" ? ground.ink : Colours.accent)
                font.pixelSize: Appearance.font.size.title
                width: 32
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32 - 78 - 36
                height: 14

                // the look's own bar
                Item {
                    anchors.fill: parent
                    visible: !root.house

                    // a track and a fill (spotlight, raycast, index, grimoire, poster, start)
                    Rectangle {
                        anchors.fill: parent
                        visible: ["arcade", "hud", "prompt"].indexOf(root.style) < 0
                        radius: ["spotlight", "raycast"].indexOf(root.style) >= 0 || (root.style === "start" && Appearance.winVer === "11") ? height / 2 : 0
                        color: Qt.rgba(ground.ink.r, ground.ink.g, ground.ink.b, 0.16)

                        Rectangle {
                            width: Math.max(height, parent.width * Math.min(1, root.value))
                            height: parent.height
                            radius: parent.radius
                            color: root.muted ? Qt.rgba(ground.ink.r, ground.ink.g, ground.ink.b, 0.35) : (root.style === "index" ? Colours.ink : Colours.accent)

                            Behavior on width {
                                NumberAnimation { duration: Appearance.anim.fast; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                    // arcade: ten chunky cells · hud: twenty thin ticks
                    Row {
                        anchors.fill: parent
                        visible: root.style === "arcade" || root.style === "hud"
                        spacing: root.style === "arcade" ? 4 : 2

                        Repeater {
                            model: root.style === "arcade" ? 10 : (root.style === "hud" ? 20 : 0)

                            Rectangle {
                                required property int index

                                readonly property int cells: root.style === "arcade" ? 10 : 20
                                readonly property bool lit: index < Math.round(Math.min(1, root.value) * cells)

                                width: (parent.width - parent.spacing * (cells - 1)) / cells
                                height: root.style === "hud" ? (lit ? parent.height : parent.height * 0.5) : parent.height
                                anchors.bottom: parent.bottom
                                color: lit ? (root.muted ? Colours.inkDim : Colours.accent) : Colours.alpha(Colours.ink, 0.12)
                            }
                        }
                    }
                    // the terminal writes it
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.style === "prompt"
                        text: `${root.mode === "volume" ? "vol" : "bri"} [${"#".repeat(Math.round(Math.min(1, root.value) * 16))}${"-".repeat(16 - Math.round(Math.min(1, root.value) * 16))}]`
                        color: root.muted ? Colours.inkDim : Colours.accent
                        font.family: Appearance.fontFamily.mono
                        font.pixelSize: 15
                    }
                }

                Slash {
                    anchors.fill: parent
                    visible: root.house
                    shear: Appearance.skew * 1.6
                    color: Colours.alpha(Colours.ink, 0.15)
                }

                Slash {
                    visible: root.house
                    width: Math.max(6, parent.width * Math.min(1, root.value))
                    height: parent.height
                    shear: Appearance.skew * 1.6
                    color: root.muted ? Colours.alpha(Colours.ink, 0.35) : Colours.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            P5Text {
                id: valueText

                anchors.verticalCenter: parent.verticalCenter
                width: 78
                horizontalAlignment: Text.AlignRight
                display: true
                text: root.muted ? (root.style === "prompt" ? "mute" : "MUTE") : (root.style === "hud" ? String(root.pct).padStart(3, "0") : (root.style === "prompt" ? `${root.pct}%` : `${root.pct}`))
                font.family: root.house ? Appearance.fontFamily.display : ground.face
                font.italic: root.house ? Appearance.type.italic : (root.style === "index" || root.style === "grimoire")
                color: root.house ? Colours.ink : ground.ink
                font.pixelSize: Appearance.font.size.title
            }
        }

        // The two inspo OSDs both answer to the wheel while they are up:
        // scrolling over the pill adjusts what it shows. A click toggles
        // mute when it is the volume.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (root.mode === "brightness") {
                    if (event.angleDelta.y > 0)
                        Brightness.increment();
                    else
                        Brightness.decrement();
                } else if (event.angleDelta.y > 0) {
                    Audio.incrementVolume();
                } else {
                    Audio.decrementVolume();
                }
                root.pop();
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.mode === "volume") {
                    Sfx.toggle();
                    Audio.toggleMute();
                }
            }
        }
    }

    // The icon and the number each answer every change with a small pop —
    // the same liveliness the inspo OSDs get from their animated icons.
    SequentialAnimation {
        id: iconPop

        NumberAnimation {
            target: icon
            property: "scale"
            to: 1.2
            duration: 90
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: icon
            property: "scale"
            to: 1
            duration: 240
            easing.type: Easing.OutBack
        }
    }

    SequentialAnimation {
        id: textPop

        NumberAnimation {
            target: valueText
            property: "scale"
            to: 1.08
            duration: 90
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: valueText
            property: "scale"
            to: 1
            duration: 240
            easing.type: Easing.OutBack
        }
    }
}
