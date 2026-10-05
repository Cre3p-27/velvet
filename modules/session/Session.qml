//  VELVET  ·  modules/session/Session.qml
//  The power menu. Big targets, hard shapes, one keystroke each.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property bool rendered: false
    property bool entered: false
    property int index: 0

    readonly property var options: [
        {
            name: "LOCK",
            key: "L",
            icon: "lock",
            fn: "lock",
            danger: false
        },
        {
            name: "SLEEP",
            key: "S",
            icon: "bedtime",
            fn: "suspend",
            danger: false
        },
        {
            name: "RESTART",
            key: "R",
            icon: "restart_alt",
            fn: "reboot",
            danger: true
        },
        {
            name: "SHUT DOWN",
            key: "P",
            icon: "power_settings_new",
            fn: "shutdown",
            danger: true
        },
        {
            name: "LOG OUT",
            key: "E",
            icon: "logout",
            fn: "logout",
            danger: true
        }
    ]

    function fire(i: int): void {
        const o = root.options[i];
        if (!o)
            return;
        Sfx.select();
        Bridge.act(o);
        Panels.closeAll();
    }

    screen: Hypr.focusedScreen
    visible: rendered
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-session"
    WlrLayershell.keyboardFocus: root.entered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Opens or closes as Panels.session says — and also when this window is created BY
    // that flag: panels are loaded on demand (shell.qml, Parked), so the flag is
    // often already true by the time the window exists.
    function present(): void {
        if (Panels.session) {
            exitTimer.stop();   // a quick reopen must not be hidden by the old close
            root.rendered = true;
            root.index = 0;
            enterTimer.restart();
            Sfx.open();
        } else {
            root.entered = false;
            exitTimer.restart();
        }
    }

    Connections {
        target: Panels

        function onSessionChanged(): void {
            root.present();
        }
    }

    // (a PanelWindow has no Component.onCompleted — a one-shot timer does the same)
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (Panels.session)
                root.present();
        }
    }

    Timer {
        id: enterTimer
        interval: 1
        onTriggered: {
            root.entered = true;
            keys.forceActiveFocus();
        }
    }

    Timer {
        id: exitTimer
        interval: Appearance.anim.normal
        onTriggered: root.rendered = false
    }

    Rectangle {
        anchors.fill: parent
        color: Colours.alpha(Colours.paper, 0.9)
        opacity: root.entered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.closeAll()
        }
    }

    // Velvet's rays; every look lays its own pattern instead
    Backdrop {
        anchors.fill: parent
        visible: Appearance.skinned
        opacity: root.entered ? 1 : 0
    }
    SpeedLines {
        anchors.fill: parent
        visible: !Appearance.skinned
        color: Colours.danger
        strength: root.entered ? 0.06 : 0
        originX: 0.5
        originY: 0.5
        count: 16
    }

    // only to know the session style's typeface for the title
    StyleCard {
        id: titleFace

        visible: false
        style: Appearance.sessionStyle
    }

    Column {
        anchors.centerIn: parent
        spacing: Appearance.spacing.huge
        opacity: root.entered ? 1 : 0
        scale: root.entered ? 1 : 0.92

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            display: true
            // every look says it its own way
            text: ({
                    velvet: "END SESSION",
                    prompt: "$ shutdown --ask",
                    arcade: "GAME OVER?",
                    hud: "SESSION // TERMINATE",
                    index: "Last Edition",
                    spotlight: "Leaving?",
                    grimoire: "Rest now, traveller",
                    poster: "END.",
                    raycast: Appearance.flavour === "minimal" ? "Goodbye" : "Turn off or leave",
                    start: Appearance.winVer === "xp" ? "Turn off computer" : (Appearance.winVer === "95" ? "Shut Down Velvet" : "Power")
                })[Appearance.sessionStyle] ?? "END SESSION"
            font.italic: Appearance.sessionStyle === "index" || Appearance.sessionStyle === "grimoire" || (Appearance.sessionStyle === "velvet" && Appearance.type.italic)
            font.family: Appearance.sessionStyle === "velvet" ? Appearance.fontFamily.display : titleFace.face
            color: Colours.ink
            font.pixelSize: Appearance.font.size.hero * 0.7
            tracking: -1
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.spacing.large

            Repeater {
                model: root.options

                Item {
                    id: opt

                    required property var modelData
                    required property int index

                    readonly property bool selected: index === root.index

                    width: 190
                    height: 210
                    scale: selected ? 1.06 : 1.0
                    y: selected ? -10 : 0

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.2
                        }
                    }
                    Behavior on y {
                        SpringAnimation {
                            spring: 4.5
                            damping: 0.32
                            epsilon: 0.4
                        }
                    }

                    // the button in the look's way (THIS LOOK → SHELL PARTS)
                    StyleCard {
                        id: card

                        anchors.fill: parent
                        style: Appearance.sessionStyle
                        hot: opt.selected
                        danger: opt.modelData.danger === true
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 14

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: opt.modelData.icon
                            color: card.style === "velvet" ? (opt.selected ? Colours.paper : Colours.ink) : (opt.selected && card.style !== "hud" && card.style !== "spotlight" ? card.ink : (opt.modelData.danger ? Colours.danger : card.ink))
                            font.pixelSize: 58
                        }

                        P5Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            display: true
                            text: card.style === "prompt" ? opt.modelData.name.toLowerCase() : ((card.style === "index" || card.style === "grimoire" || card.style === "raycast" || card.style === "start") ? Appearance.sentence(opt.modelData.name) : opt.modelData.name)
                            font.family: card.style === "velvet" ? Appearance.fontFamily.display : card.face
                            font.italic: card.style === "index" || card.style === "grimoire"
                            color: card.style === "velvet" ? (opt.selected ? Colours.paper : Colours.ink) : card.ink
                            font.pixelSize: Appearance.font.size.normal
                        }

                        Slash {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 30
                            height: 22
                            shear: Appearance.skew
                            color: opt.selected ? Colours.alpha(Colours.paper, 0.25) : Colours.alpha(Colours.ink, 0.12)

                            P5Text {
                                anchors.centerIn: parent
                                display: true
                                text: opt.modelData.key
                                color: opt.selected ? Colours.paper : Colours.inkDim
                                font.pixelSize: Appearance.font.size.tiny
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            if (root.index !== opt.index)
                                Sfx.cursor();
                            root.index = opt.index;
                        }
                        onClicked: root.fire(opt.index)
                    }
                }
            }
        }
    }

    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                Panels.closeAll();
                break;
            case Qt.Key_Left:
                root.index = (root.index - 1 + root.options.length) % root.options.length;
                Sfx.cursor();
                break;
            case Qt.Key_Right:
            case Qt.Key_Tab:
                root.index = (root.index + 1) % root.options.length;
                Sfx.cursor();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.fire(root.index);
                break;
            case Qt.Key_L:
                root.fire(0);
                break;
            case Qt.Key_S:
                root.fire(1);
                break;
            case Qt.Key_R:
                root.fire(2);
                break;
            case Qt.Key_P:
                root.fire(3);
                break;
            case Qt.Key_E:
                root.fire(4);
                break;
            }
            event.accepted = true;
        }
    }
}
