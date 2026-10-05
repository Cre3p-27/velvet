//  VELVET  ·  modules/notifs/NotifCentre.qml
//  Clock click / Super+N. Calendar on top, notification history below.
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

    function move(delta: int): void {
        const n = Notifs.history.length;
        if (n === 0)
            return;
        root.index = Math.max(0, Math.min(n - 1, root.index + delta));
        Sfx.cursor();
    }

    function dismissSelected(): void {
        const n = Notifs.history.length;
        if (n === 0)
            return;
        const item = Notifs.history[Math.min(root.index, n - 1)];
        Notifs.close(item);
        root.index = Math.max(0, Math.min(root.index, Notifs.history.length - 1));
        Sfx.back();
    }

    function activateSelected(): void {
        const n = Notifs.history.length;
        if (n === 0)
            return;
        const item = Notifs.history[Math.min(root.index, n - 1)];
        const actions = item?.actions ?? [];
        if (actions.length > 0) {
            Sfx.select();
            Notifs.invoke(item, actions[0].identifier); // records are plain data
        }
        Notifs.close(item);
    }

    // the centre is built the way the notifications are (THIS LOOK → SHELL PARTS)
    readonly property string style: Appearance.notifStyle
    readonly property bool house: root.style === "velvet"
    readonly property bool fromRight: Config.bar.position !== "right"
    readonly property int panelWidth: Math.min(460, screen ? screen.width * 0.32 : 460)

    screen: Hypr.focusedScreen
    visible: rendered
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-notifcentre"
    WlrLayershell.keyboardFocus: root.entered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Opens or closes as Panels.notifCentre says — and also when this window is created BY
    // that flag: panels are loaded on demand (shell.qml, Parked), so the flag is
    // often already true by the time the window exists.
    function present(): void {
        if (Panels.notifCentre) {
            exitTimer.stop();   // a quick reopen must not be hidden by the old close
            root.rendered = true;
            enterTimer.restart();
            Notifs.markAllSeen();
        } else {
            root.entered = false;
            exitTimer.restart();
        }
    }

    Connections {
        target: Panels

        function onNotifCentreChanged(): void {
            root.present();
        }
    }

    // (a PanelWindow has no Component.onCompleted — a one-shot timer does the same)
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (Panels.notifCentre)
                root.present();
        }
    }

    Timer {
        id: enterTimer
        interval: 1
        onTriggered: {
            root.entered = true;
            root.index = 0;
            keys.forceActiveFocus();
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
            case Qt.Key_Up:
                root.move(-1);
                break;
            case Qt.Key_Down:
                root.move(1);
                break;
            case Qt.Key_PageUp:
                root.move(-5);
                break;
            case Qt.Key_PageDown:
                root.move(5);
                break;
            case Qt.Key_Home:
                root.index = 0;
                break;
            case Qt.Key_End:
                root.index = Math.max(0, Notifs.history.length - 1);
                break;
            case Qt.Key_Delete:
            case Qt.Key_Backspace:
                if (event.modifiers & Qt.ShiftModifier) {
                    Notifs.clearHistory();
                    Sfx.back();
                } else {
                    root.dismissSelected();
                }
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                root.activateSelected();
                break;
            case Qt.Key_D:
                Config.toggle("notifs.doNotDisturb");
                Sfx.toggle();
                break;
            }
            event.accepted = true;
        }
    }

    Timer {
        id: exitTimer
        interval: Appearance.anim.normal + 40
        onTriggered: root.rendered = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Panels.closeAll()
    }

    Item {
        id: panel

        width: root.panelWidth
        height: parent.height - Config.bar.margin * 2 - 20
        y: Config.bar.margin + 10

        x: {
            const edge = Config.bar.position === "left" ? Config.bar.thickness + Config.bar.margin * 2 + 8 : 0;
            if (root.fromRight)
                return root.entered ? root.width - width - Math.max(16, edge === 0 ? Config.bar.thickness + Config.bar.margin * 2 + 8 : 16) : root.width + 20;
            return root.entered ? edge : -width - 20;
        }

        Behavior on x {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutExpo
            }
        }

        StyleCard {
            id: ground

            anchors.fill: parent
            visible: !root.house
            style: root.style
        }

        Plate {
            anchors.fill: parent
            visible: root.house
            radius: Appearance.rounding.large
            color: Colours.alpha(Colours.surface, Math.min(0.98, Config.appearance.transparency + 0.12))
            border.width: 1
            border.color: Colours.alpha(Colours.accent, 0.32)
            antialiasing: true

            Halftone {
                anchors.fill: parent
                strength: 0.03
                density: 1.6
            }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            // ---------------------------------------------------------- head
            Row {
                width: parent.width
                spacing: 10

                Slash {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 26
                    color: Colours.accent
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    // every look heads its inbox its own way
                    text: ({
                            velvet: Qt.formatDateTime(clock.date, "dddd").toUpperCase(),
                            prompt: "~/inbox $",
                            arcade: "MESSAGES",
                            hud: "INBOX //",
                            index: "Correspondence",
                            spotlight: "Notifications",
                            grimoire: "Missives",
                            poster: "NEWS.",
                            raycast: "Notifications",
                            start: Appearance.winVer === "95" || Appearance.winVer === "xp" ? "Notification Area" : "Notifications"
                        })[root.style] ?? Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                    font.family: root.house ? Appearance.fontFamily.display : ground.face
                    font.italic: root.house ? Appearance.type.italic : (root.style === "index" || root.style === "grimoire")
                    color: root.house ? Colours.ink : ground.ink
                    font.pixelSize: Appearance.font.size.large
                }

                Item {
                    width: parent.width - 6 - 10 * 3 - 180
                    height: 1
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.style === "prompt" ? Qt.formatDateTime(clock.date, "yyyy-MM-dd") : Qt.formatDateTime(clock.date, "dd MMM yyyy").toUpperCase()
                    font.family: root.house ? Appearance.fontFamily.body : ground.face
                    color: root.house ? Colours.inkDim : ground.dim
                    font.pixelSize: Appearance.font.size.small
                    tracking: 1.4
                }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            // ------------------------------------------------------ controls
            Row {
                width: parent.width
                spacing: 8

                Slash {
                    width: 132
                    height: 34
                    shear: Appearance.skew
                    color: Config.notifs.doNotDisturb ? Colours.accent : Colours.alpha(Colours.ink, 0.1)
                    borderColor: Colours.alpha(Colours.ink, 0.22)
                    borderWidth: 1

                    P5Text {
                        anchors.centerIn: parent
                        display: true
                        text: Config.notifs.doNotDisturb ? "SILENCED" : "SILENCE"
                        color: Config.notifs.doNotDisturb ? Colours.on(Colours.accent) : Colours.ink
                        font.pixelSize: Appearance.font.size.tiny
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Sfx.toggle();
                            Config.toggle("notifs.doNotDisturb");
                        }
                    }
                }

                Slash {
                    width: 118
                    height: 34
                    shear: Appearance.skew
                    color: "transparent"
                    borderColor: Colours.alpha(Colours.danger, 0.7)
                    borderWidth: 2
                    visible: Notifs.history.length > 0

                    P5Text {
                        anchors.centerIn: parent
                        display: true
                        text: "CLEAR ALL"
                        color: Colours.danger
                        font.pixelSize: Appearance.font.size.tiny
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Sfx.back();
                            Notifs.clearHistory();
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colours.alpha(Colours.ink, 0.12)
            }

            P5Text {
                width: parent.width
                visible: Notifs.history.length > 0
                text: "↑↓ MOVE   ·   ENTER OPEN   ·   DEL DISMISS   ·   SHIFT+DEL CLEAR   ·   D SILENCE"
                color: Colours.alpha(Colours.inkDim, 0.6)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.4
                elide: Text.ElideRight
            }

            // ------------------------------------------------------- history
            Item {
                width: parent.width
                height: parent.height - y

                P5Text {
                    anchors.centerIn: parent
                    visible: Notifs.history.length === 0
                    display: true
                    text: "NOTHING TO SEE"
                    color: Colours.alpha(Colours.inkDim, 0.5)
                    font.pixelSize: Appearance.font.size.large
                }

                ListView {
                    id: notifList

                    anchors.fill: parent
                    model: Notifs.history
                    currentIndex: root.index
                    spacing: Appearance.spacing.small
                    clip: true
                    // Only build what is on screen, and hand the same delegates
                    // back to the next rows rather than making new ones. With
                    // cards this rich, that is the difference between scrolling
                    // and stuttering.
                    reuseItems: true
                    cacheBuffer: 0
                    boundsBehavior: Flickable.StopAtBounds
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: height - 90
                    highlightMoveDuration: Appearance.anim.fast

                    delegate: NotifCard {
                        required property var modelData
                        required property int index

                        width: ListView.view ? ListView.view.width : 0
                        wrapper: modelData
                        showTime: true
                        selected: index === root.index

                        onClosed: Notifs.close(modelData)
                        onDismissed: Notifs.close(modelData)
                    }

                    SmoothScroll {
                        view: notifList
                    }
                }
            }
        }
    }
}
