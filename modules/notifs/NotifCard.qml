//  VELVET  ·  modules/notifs/NotifCard.qml
//  One notification, in the house style. Used by both popups and the centre.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    required property var wrapper
    property bool showTime: false
    property bool selected: false

    signal dismissed
    signal closed

    readonly property bool critical: wrapper?.urgency === "critical"
    // Read as text further down, so it has to clear the contrast threshold.
    readonly property color edge: critical ? Colours.danger : (root.style === "start" ? root.ink : Colours.accentInk)

    // ── every look writes its own notification (Appearance.uiStyle):
    //  velvet the slanted card · prompt a log line · arcade a NEW MESSAGE box ·
    //  hud a bracketed INCOMING panel · index a bulletin clipping · spotlight a
    //  frosted card · grimoire a sealed note · poster a black block · raycast
    //  the quiet card of each flavour · start the toast of the Windows edition.
    readonly property string style: Appearance.notifStyle
    readonly property string fl: Appearance.flavour
    readonly property string wv: Appearance.winVer
    readonly property bool velvet: root.style === "velvet"
    readonly property color ink: {
        if (root.style === "poster")
            return Colours.paper;
        if (root.style === "start")
            return root.wv === "10" || root.wv === "7" ? "#ffffff" : "#111111";
        if (root.style === "raycast" && root.fl === "flat")
            return Colours.ink;
        return Colours.ink;
    }
    readonly property color dim: root.style === "poster" ? Colours.alpha(Colours.paper, 0.75) : (root.style === "start" ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.72) : Colours.inkDim)
    readonly property string face: ({
            prompt: Appearance.fontFamily.mono,
            arcade: Appearance.fontFamily.pixel,
            hud: Appearance.fontFamily.tech,
            index: Appearance.fontFamily.serif,
            grimoire: Appearance.fontFamily.serif,
            poster: Appearance.fontFamily.block,
            start: Appearance.fontFamily.win
        })[root.style] ?? Appearance.fontFamily.body
    readonly property string kicker: ({
            prompt: "[" + Qt.formatDateTime(new Date(root.wrapper?.time ?? Date.now()), "HH:mm") + "]",
            arcade: "NEW MESSAGE!",
            hud: "INCOMING //",
            index: "BULLETIN",
            grimoire: "A missive",
            poster: "NOTICE"
        })[root.style] ?? ""
    readonly property real lead: ({
            velvet: 30,
            prompt: 16,
            arcade: 20,
            hud: 22,
            index: 22,
            spotlight: 64,
            grimoire: 26,
            poster: 26,
            raycast: root.fl === "minimal" ? 14 : 60,
            start: root.wv === "95" || root.wv === "xp" ? 50 : 60
        })[root.style] ?? 30

    implicitWidth: Config.notifs.width
    implicitHeight: body.implicitHeight + Appearance.padding.large * 2

    // Lifts slightly under the pointer, and again when the keyboard is on it.
    scale: root.selected ? 1.015 : (hover.containsMouse ? 1.008 : 1.0)

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutCubic
        }
    }

    // ── the card of each look
    Item {
        anchors.fill: parent
        visible: !root.velvet

        // shadows: arcade hard, glass and the quiet looks soft, clay tinted
        Rectangle {
            visible: ["arcade", "spotlight", "raycast", "start", "poster"].indexOf(root.style) >= 0 && !(root.style === "raycast" && root.fl === "minimal")
            x: root.style === "arcade" || root.style === "poster" ? 6 : 0
            y: root.style === "arcade" || root.style === "poster" ? 6 : 6
            width: parent.width
            height: parent.height
            radius: card.radius
            color: root.style === "poster" ? Colours.accent : (root.style === "raycast" && root.fl === "clay" ? Colours.alpha(Config.appearance.clayTint === "accent" ? Colours.accent : Colours.clay, 0.45) : Qt.rgba(0, 0, 0, root.style === "arcade" ? 0.55 : 0.18))
        }
        Rectangle {
            visible: root.style === "raycast" && root.fl === "neu"
            x: -6
            y: -6
            width: parent.width
            height: parent.height
            radius: card.radius
            color: Colours.light ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.06)
        }
        Rectangle {
            id: card

            anchors.fill: parent
            radius: ({
                    prompt: 0,
                    arcade: 0,
                    hud: 0,
                    index: 0,
                    spotlight: 22,
                    grimoire: 4,
                    poster: 0,
                    raycast: ({ clean: 14, minimal: 0, flat: 4, neu: 22, clay: 26 })[root.fl] ?? 14,
                    start: root.wv === "11" ? 10 : (root.wv === "95" || root.wv === "xp" || root.wv === "7" ? 6 : 0)
                })[root.style] ?? 12
            color: {
                switch (root.style) {
                case "prompt":
                    return Colours.alpha(Colours.paper, 0.94);
                case "arcade":
                    return Colours.paper;
                case "hud":
                    return Colours.alpha(Colours.paper, 0.88);
                case "index":
                    return Colours.surface;
                case "spotlight":
                    return Qt.rgba(1, 1, 1, 0.12 + 0.08 * Config.appearance.glassFrost);
                case "grimoire":
                    return Colours.surface;
                case "poster":
                    return Colours.ink;
                case "start":
                    return root.wv === "95" || root.wv === "xp" ? "#ffffe1" : (root.wv === "7" ? Qt.rgba(0.1, 0.18, 0.3, 0.92) : (root.wv === "10" ? "#1f1f1f" : Qt.rgba(0.97, 0.97, 0.98, 0.97)));
                default:
                    if (root.fl === "minimal")
                        return Colours.alpha(Colours.paper, 0.96);
                    if (root.fl === "neu")
                        return Colours.paper;
                    if (root.fl === "clay")
                        return Colours.mix(Colours.surface, Config.appearance.clayTint === "accent" ? Colours.accent : Colours.clay, 0.14);
                    return Colours.surface;
                }
            }
            border.width: ({
                    arcade: 3,
                    hud: 1,
                    index: 1,
                    spotlight: 1,
                    grimoire: 2,
                    start: 1,
                    raycast: root.fl === "clean" ? 1 : 0
                })[root.style] ?? 0
            border.color: root.critical ? Colours.danger : (({
                        arcade: Colours.accent,
                        hud: Colours.alpha(Colours.accent, 0.6),
                        index: Colours.ink,
                        spotlight: Qt.rgba(1, 1, 1, Math.min(1, Config.appearance.glassRim)),
                        grimoire: Colours.accent,
                        start: root.wv === "95" || root.wv === "xp" ? "#000000" : Qt.rgba(1, 1, 1, 0.2),
                        raycast: Colours.alpha(Colours.ink, 0.12)
                    })[root.style] ?? "transparent")
        }
        // terminal: a coloured gutter; hud: brackets; flat: a solid head;
        // grimoire: an inner rule; index: a double rule
        Rectangle {
            visible: root.style === "prompt" || (root.style === "raycast" && root.fl === "minimal")
            width: root.style === "prompt" ? 4 : 2
            height: parent.height
            color: root.critical ? Colours.danger : (root.style === "prompt" ? Colours.accent : Colours.ink)
        }
        Repeater {
            model: root.style === "hud" ? 4 : 0

            Item {
                required property int index

                x: index % 2 === 0 ? -4 : root.width - 16
                y: index < 2 ? -4 : root.height - 16
                width: 20
                height: 20

                Rectangle { x: parent.index % 2 === 0 ? 0 : 18; width: 2; height: 20; color: Colours.accent }
                Rectangle { y: parent.index < 2 ? 0 : 18; width: 20; height: 2; color: Colours.accent }
            }
        }
        Rectangle {
            visible: root.style === "raycast" && root.fl === "flat"
            width: parent.width
            height: 6
            color: root.critical ? Colours.danger : Colours.accent
        }
        Rectangle {
            visible: root.style === "grimoire"
            anchors.fill: parent
            anchors.margins: 5
            color: "transparent"
            border.width: 1
            border.color: Colours.alpha(Colours.accent, 0.5)
        }
        Rectangle {
            visible: root.style === "index"
            x: 14
            y: 8
            width: parent.width - 28
            height: 2
            color: Colours.ink
        }
        Rectangle {
            visible: root.style === "poster"
            width: 10
            height: parent.height
            color: Colours.accent
        }
        // the app's picture for the card looks
        Item {
            visible: ["spotlight", "raycast", "start"].indexOf(root.style) >= 0 && !(root.style === "raycast" && root.fl === "minimal")
            x: root.style === "start" && (root.wv === "95" || root.wv === "xp") ? 12 : 16
            anchors.verticalCenter: parent.verticalCenter
            width: root.style === "start" && (root.wv === "95" || root.wv === "xp") ? 28 : 34
            height: width

            Rectangle {
                anchors.fill: parent
                radius: root.style === "start" ? 2 : width * 0.28
                color: Colours.alpha(Colours.accent, 0.14)
                visible: bigIcon.status !== Image.Ready
            }
            IconImage {
                id: bigIcon

                anchors.fill: parent
                source: root.wrapper?.appIcon ? Quickshell.iconPath(root.wrapper.appIcon, true) : ""
                asynchronous: true
            }
            Icon {
                anchors.centerIn: parent
                visible: bigIcon.status !== Image.Ready
                name: root.style === "start" && (root.wv === "95" || root.wv === "xp") ? "info" : "notifications"
                color: Colours.accent
                font.pixelSize: parent.width * 0.6
            }
        }
    }

    Slash {
        anchors.fill: parent
        visible: !root.critical && root.velvet
        shear: Appearance.skew * 0.6
        color: Colours.alpha(Colours.surfaceHigh, root.selected ? 1.0 : 0.96)
        borderColor: root.selected ? Colours.ink : Colours.alpha(root.edge, hover.containsMouse ? 1.0 : 0.7)
        borderWidth: root.selected ? 3 : 2

        Behavior on borderColor {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    // Critical alerts tear the card open — you should not be able to mistake
    // one. Loaded rather than declared: a torn edge is a Shape with a few
    // dozen points, and the notification centre can hold forty cards. One
    // built per critical alert is nothing; forty built and re-laid-out on
    // every resize is the difference between a list and a freeze.
    Loader {
        anchors.fill: parent
        active: root.critical && root.velvet
        asynchronous: true

        sourceComponent: Jagged {
            shear: Appearance.skew * 0.6
            amplitude: 5
            teeth: 11
            seed: 3
            color: Colours.alpha(Colours.surfaceHigh, 0.97)
            borderColor: Colours.danger
            borderWidth: 2
        }
    }

    // Urgency stripe down the leading edge.
    Rectangle {
        visible: root.velvet
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 4
        height: parent.height * 0.62
        color: root.edge
        antialiasing: true
    }

    Column {
        id: body

        anchors.left: parent.left
        anchors.leftMargin: root.lead
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.style === "index" || root.style === "poster" ? 5 : 3

        Row {
            width: parent.width
            spacing: 8

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.kicker !== ""
                text: root.kicker
                color: root.style === "poster" ? Colours.accent : (root.style === "arcade" || root.style === "hud" ? Colours.accent : root.dim)
                font.family: root.style === "prompt" ? Appearance.fontFamily.mono : root.face
                font.pixelSize: Appearance.font.size.tiny
                font.bold: root.style !== "grimoire"
                font.italic: root.style === "grimoire"
                tracking: root.style === "hud" || root.style === "index" ? 3 : 1

                SequentialAnimation on opacity {
                    running: root.style === "arcade"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 420 }
                    NumberAnimation { to: 1; duration: 420 }
                }
            }

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                visible: source !== "" && (root.velvet || root.style === "prompt" || root.style === "hud" || (root.style === "raycast" && root.fl === "minimal"))
                implicitSize: 15
                source: root.wrapper?.appIcon ? Quickshell.iconPath(root.wrapper.appIcon, true) : ""
                asynchronous: true
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.style === "prompt" ? (root.wrapper?.appName ?? "system").toLowerCase() + ":" : (root.style === "grimoire" || root.style === "start" || root.style === "raycast" || root.style === "spotlight" ? (root.wrapper?.appName ?? "System") : (root.wrapper?.appName ?? "SYSTEM").toUpperCase())
                font.family: root.velvet ? Appearance.fontFamily.body : root.face
                color: root.velvet ? root.edge : (root.style === "poster" ? Colours.paper : (root.critical ? Colours.danger : (root.style === "start" ? root.dim : Colours.accentInk)))
                font.pixelSize: Appearance.font.size.tiny
                tracking: 2
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showTime && root.style !== "prompt"
                text: Qt.formatDateTime(new Date(root.wrapper?.time ?? Date.now()), "HH:mm")
                color: Colours.alpha(root.dim, 0.7)
                font.pixelSize: Appearance.font.size.tiny
            }
        }

        P5Text {
            display: true
            width: parent.width - 26
            text: root.style === "arcade" || root.style === "poster" || root.style === "hud" ? (root.wrapper?.summary ?? "").toUpperCase() : (root.wrapper?.summary ?? "")
            color: root.ink
            font.family: root.velvet ? Appearance.fontFamily.display : root.face
            font.italic: root.velvet ? Appearance.type.italic : (root.style === "index" || root.style === "grimoire")
            font.pixelSize: Appearance.font.size.normal + (root.style === "poster" ? 8 : (root.style === "index" ? 6 : 2))
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
        }

        P5Text {
            width: parent.width - 26
            visible: text.length > 0
            text: root.wrapper?.body ?? ""
            color: root.dim
            font.family: root.velvet ? Appearance.fontFamily.body : root.face
            font.pixelSize: Appearance.font.size.small
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: Config.notifs.expanded ? 8 : 2
        }

        Item {
            width: 1
            height: actions.visible ? 6 : 0
        }

        Row {
            id: actions

            spacing: 8
            // Buttons vanish once the app that offered them has gone, rather
            // than staying there doing nothing.
            visible: (root.wrapper?.actions?.length ?? 0) > 0 && Notifs.isLive(root.wrapper)

            Repeater {
                model: root.wrapper?.actions ?? []

                Slash {
                    id: action

                    required property var modelData

                    width: actionText.implicitWidth + 26
                    height: 28
                    shear: Appearance.skew
                    color: actionArea.containsMouse ? Colours.accent : Colours.alpha(Colours.ink, 0.1)
                    borderColor: Colours.alpha(Colours.ink, 0.25)
                    borderWidth: 1

                    P5Text {
                        id: actionText

                        anchors.centerIn: parent
                        display: true
                        text: (action.modelData.text ?? "").toUpperCase()
                        color: actionArea.containsMouse ? Colours.on(Colours.accent) : Colours.ink
                        font.pixelSize: Appearance.font.size.tiny
                    }

                    MouseArea {
                        id: actionArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Sfx.select();
                            // The record carries the action's name, not the
                            // action object — the live one is looked up now,
                            // at the moment of the press, and if the app has
                            // gone this quietly does nothing.
                            Notifs.invoke(root.wrapper, action.modelData.identifier);
                            root.closed();
                        }
                    }
                }
            }
        }
    }

    // Close button, top-right.
    Item {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        width: 24
        height: 24
        opacity: hover.containsMouse || closeArea.containsMouse ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }

        Icon {
            anchors.centerIn: parent
            name: "close"
            color: closeArea.containsMouse ? Colours.danger : Colours.inkDim
            font.pixelSize: Appearance.font.size.normal
        }

        MouseArea {
            id: closeArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sfx.close();
                root.closed();
            }
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        z: -1

        onClicked: event => {
            if (event.button === Qt.MiddleButton) {
                Sfx.close();
                root.closed();
            } else {
                Sfx.cursor();
                root.dismissed();
            }
        }
    }
}
