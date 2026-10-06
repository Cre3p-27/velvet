//  VELVET  ·  modules/welcome/Welcome.qml
//  The welcome page: opens once per login (HOME → WELCOME PAGE AT START, or the
//  switch on the page itself), a real window in the look you wear. Six big
//  first steps — each one a click that takes you there — and every key a
//  beginner needs. Escape, the button or the compositor closes it.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick

FloatingWindow {
    id: root

    property bool rendered: false

    title: "Welcome to Velvet"
    visible: root.rendered
    color: Colours.paper
    implicitWidth: Math.min(1180, Math.round((Hypr.focusedScreen?.width ?? 1600) * 0.8))
    implicitHeight: Math.min(820, Math.round((Hypr.focusedScreen?.height ?? 900) * 0.84))
    minimumSize: Qt.size(820, 600)

    readonly property string style: Appearance.uiStyle
    readonly property real u: Math.max(0.8, Math.min(1.3, root.width / 1180))

    function present(): void {
        root.rendered = Panels.welcome;
        if (root.rendered)
            focusTimer.restart();
    }
    function go(fn: var): void {
        Sfx.select();
        Panels.welcome = false;
        fn();
    }

    Connections {
        target: Panels

        function onWelcomeChanged(): void {
            root.present();
        }
    }
    Timer {
        running: true
        interval: 1
        onTriggered: root.present()
    }
    Timer {
        id: focusTimer

        interval: 80
        onTriggered: keys.forceActiveFocus()
    }
    // closed by the compositor: the flag follows
    onVisibleChanged: if (!root.visible && Panels.welcome && root.rendered) {
        root.rendered = false;
        Panels.welcome = false;
    }

    readonly property var steps: [
        {
            icon: "palette",
            title: "Pick a look",
            text: "Velvet is many desktops in one: arcade, glass, terminal, newspaper, Windows … one click changes everything.",
            key: "Super + Tab → LOOKS",
            run: () => Panels.openSettingsTabNamed("LOOKS")
        },
        {
            icon: "wallpaper",
            title: "Choose a wallpaper",
            text: "Spin the wheel and pick one. The colours of the whole shell follow your picture.",
            key: "Super + W",
            run: () => Panels.toggleWheel()
        },
        {
            icon: "apps",
            title: "Open your apps",
            text: "Start typing the name of any program and press Enter. = does maths, > runs a command.",
            key: "Super + Space",
            run: () => Panels.toggleLauncher()
        },
        {
            icon: "dashboard_customize",
            title: "Arrange your desktop",
            text: "Drag clocks, music, weather and programs onto a picture of your screen. They come back on every login.",
            key: "Super + Tab → DESKTOP",
            run: () => Panels.openSettingsTabNamed("DESKTOP")
        },
        {
            icon: "zoom_out_map",
            title: "Your infinite desktop",
            text: "Super + Z / X switch desktops, Super + Alt + mouse wheel zooms out over everything, Super + D tiles your windows.",
            key: "Super + Shift + M  the map",
            run: () => Panels.toggleWindowMap()
        },
        {
            icon: "keyboard",
            title: "Every shortcut",
            text: "All keys on one screen — and every one of them can be changed.",
            key: "Super + Shift + K",
            run: () => {
                Panels.keys = true;
            }
        }
    ]

    readonly property var keyList: [["Super + Tab", "settings — just start typing to search"], ["Super + Space", "launcher"], ["Super + N", "notifications"], ["Super + Escape", "power menu"], ["Super + L", "lock the screen"], ["Super + Z / X", "previous / next desktop"], ["Super + D", "floating ⇄ tiled windows"], ["Super + Alt + wheel", "zoom the desktop out"], ["Super + Alt + right click", "every window at a glance (left click: 1:1)"], ["Super + W", "wallpapers"], ["Super + Shift + K", "every shortcut"]]

    Rectangle {
        anchors.fill: parent
        color: Colours.paper
    }
    Backdrop {
        anchors.fill: parent
        visible: Appearance.skinned
        opacity: 0.6
    }

    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Panels.welcome = false

        Flickable {
            id: flick

            anchors.fill: parent
            anchors.bottomMargin: 80 * root.u
            contentHeight: page.height + 60 * root.u
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: page

                x: Math.max(24, (flick.width - width) / 2)
                y: 34 * root.u
                width: Math.min(flick.width - 48, 1080 * root.u)
                spacing: 22 * root.u

                // ── the head
                Row {
                    spacing: 18 * root.u

                    VelvetMark {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 64 * root.u
                        height: width
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        P5Text {
                            display: true
                            text: Appearance.tcase("WELCOME TO VELVET")
                            color: Colours.ink
                            font.pixelSize: 40 * root.u
                        }
                        P5Text {
                            text: `Hello ${SysInfo.user} — six first steps. Click any of them and it takes you there.`
                            color: Colours.inkDim
                            font.pixelSize: 16 * root.u
                        }
                    }
                }

                // ── six first steps
                Grid {
                    width: page.width
                    columns: page.width > 900 ? 3 : 2
                    columnSpacing: 16 * root.u
                    rowSpacing: 16 * root.u

                    Repeater {
                        model: root.steps

                        Item {
                            id: step

                            required property var modelData
                            required property int index

                            width: (page.width - (parent.columns - 1) * 16 * root.u) / parent.columns
                            height: 200 * root.u
                            scale: hover.hovered ? 1.02 : 1

                            Behavior on scale {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }

                            StyleCard {
                                id: card

                                anchors.fill: parent
                                hot: hover.hovered
                            }
                            Column {
                                x: 22 * root.u
                                y: 18 * root.u
                                width: parent.width - 44 * root.u
                                spacing: 8 * root.u

                                Row {
                                    spacing: 10 * root.u

                                    Rectangle {
                                        width: 34 * root.u
                                        height: width
                                        radius: Appearance.r(10)
                                        color: Colours.alpha(Colours.accent, card.hot ? 0.3 : 0.16)

                                        Text {
                                            anchors.centerIn: parent
                                            text: `${step.index + 1}`
                                            color: card.hot && card.style === "velvet" ? card.ink : Colours.accentInk
                                            font.family: card.face
                                            font.pixelSize: 17 * root.u
                                            font.bold: true
                                        }
                                    }
                                    Icon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: step.modelData.icon
                                        color: card.hot && (card.style === "velvet" || card.style === "poster") ? card.ink : Colours.accentInk
                                        font.pixelSize: 26 * root.u
                                    }
                                }
                                Text {
                                    width: parent.width
                                    text: step.modelData.title
                                    color: card.ink
                                    font.family: card.face
                                    font.pixelSize: 21 * root.u
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: step.modelData.text
                                    color: card.dim
                                    font.family: Appearance.fontFamily.body
                                    font.pixelSize: 14 * root.u
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                x: 22 * root.u
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 14 * root.u
                                text: step.modelData.key
                                color: card.hot && (card.style === "velvet" || card.style === "poster" || card.style === "arcade") ? card.ink : Colours.accentInk
                                font.family: Appearance.fontFamily.mono
                                font.pixelSize: 13 * root.u
                            }

                            HoverHandler {
                                id: hover

                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: root.go(step.modelData.run)
                            }
                        }
                    }
                }

                // ── the keys
                P5Text {
                    display: true
                    text: Appearance.tcase("THE KEYS YOU NEED")
                    color: Colours.ink
                    font.pixelSize: 22 * root.u
                }
                Grid {
                    width: page.width
                    columns: 2
                    columnSpacing: 30 * root.u
                    rowSpacing: 8 * root.u

                    Repeater {
                        model: root.keyList

                        Row {
                            id: keyRow

                            required property var modelData

                            width: (page.width - 30 * root.u) / 2
                            spacing: 14 * root.u

                            Rectangle {
                                width: 190 * root.u
                                height: 30 * root.u
                                radius: Appearance.r(6)
                                color: Colours.alpha(Colours.ink, 0.07)
                                border.width: 1
                                border.color: Colours.alpha(Colours.ink, 0.14)

                                Text {
                                    anchors.centerIn: parent
                                    text: keyRow.modelData[0]
                                    color: Colours.ink
                                    font.family: Appearance.fontFamily.mono
                                    font.pixelSize: 13 * root.u
                                    font.bold: true
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: keyRow.modelData[1]
                                color: Colours.inkDim
                                font.family: Appearance.fontFamily.body
                                font.pixelSize: 14 * root.u
                            }
                        }
                    }
                }

            }

            SmoothScroll {
                view: flick
            }
        }
        // ── the foot: the switch and the way out
        Item {
            id: foot

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18 * root.u
            x: page.x
            width: page.width
            height: 48 * root.u

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * root.u

                Rectangle {
                    id: box

                    anchors.verticalCenter: parent.verticalCenter
                    width: 24 * root.u
                    height: width
                    radius: Appearance.r(5)
                    color: Config.home.welcome ? Colours.accent : "transparent"
                    border.width: 2
                    border.color: Config.home.welcome ? Colours.accent : Colours.alpha(Colours.ink, 0.4)

                    Icon {
                        anchors.centerIn: parent
                        visible: Config.home.welcome
                        name: "check"
                        color: Colours.on(Colours.accent)
                        font.pixelSize: 18 * root.u
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Show this page every time I log in  (also in Super+Tab → HOME)"
                    color: Colours.ink
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: 14 * root.u
                }

                TapHandler {
                    onTapped: {
                        Sfx.toggle();
                        Config.toggle("home.welcome");
                    }
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }

            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 220 * root.u
                height: 46 * root.u

                StyleCard {
                    id: goCard

                    anchors.fill: parent
                    hot: true
                }
                Text {
                    anchors.centerIn: parent
                    text: "Let's go"
                    color: goCard.ink
                    font.family: goCard.face
                    font.pixelSize: 18 * root.u
                    font.bold: true
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        Sfx.select();
                        Panels.welcome = false;
                    }
                }
            }
        }
    }
}
