//  VELVET  ·  modules/lock/modules/LockPower.qml
//  The way out of the session, from the lock: SLEEP (one click — the
//  machine wakes up to this lock), and LOG OUT / RESTART / POWER OFF,
//  which are password-guarded — they arm the password pill ("Enter
//  password to power off") and only act once PAM has accepted the
//  password; Escape or a second click disarms. On a tile the four are
//  labelled pills (icons only when the card is too narrow for words); in
//  an island pill it is just the icons.
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import QtQuick

Item {
    id: root

    // The lock face, for its pendingAction state.
    property var host: null

    property bool compact: false
    property bool carded: true

    readonly property var actions: [
        {
            id: "suspend",
            icon: "bedtime",
            label: "Sleep",
            guarded: false
        },
        {
            id: "logout",
            icon: "logout",
            label: "Log out",
            guarded: true
        },
        {
            id: "reboot",
            icon: "restart_alt",
            label: "Restart",
            guarded: true
        },
        {
            id: "poweroff",
            icon: "power_settings_new",
            label: "Power off",
            guarded: true
        }
    ]

    // Words when they fit: four labelled pills need about 450px, plus
    // air on both sides of the row.
    readonly property bool labelled: !root.compact && root.width >= 500

    implicitHeight: root.compact ? 36 : 84
    implicitWidth: root.compact ? powerRow.implicitWidth : Math.max(340, powerRow.implicitWidth + 48)

    function armed(what: string): bool {
        return !!root.host && root.host.pendingAction === what;
    }

    function press(a: var): void {
        if (!a.guarded) {
            Sfx.select();
            if (root.host)
                root.host.pendingAction = "";
            Actions.suspend();
            return;
        }
        Sfx.toggle();
        if (root.host)
            root.host.pendingAction = root.host.pendingAction === a.id ? "" : a.id;
    }

    ModuleCard {
        anchors.fill: parent
        glyphKind: 3
        radius: 28
        carded: root.carded
        visible: !root.compact
    }

    Row {
        id: powerRow

        anchors.centerIn: parent
        spacing: root.compact ? 6 : 8

        Repeater {
            model: root.actions

            Rectangle {
                id: btn

                required property var modelData

                readonly property bool on: root.armed(btn.modelData.id)
                readonly property bool hot: hover.hovered

                width: root.labelled ? label.implicitWidth + 48 : (root.compact ? 30 : 44)
                height: root.compact ? 30 : 44
                radius: height / 2
                color: btn.on ? Colours.warning : (btn.hot ? (btn.modelData.guarded ? Colours.alpha(Colours.warning, 0.22) : Colours.alpha(Colours.accent, 0.22)) : Colours.alpha(Colours.ink, 0.07))
                border.width: 1
                border.color: btn.on ? Colours.warning : Colours.alpha(Colours.ink, btn.hot ? 0.16 : 0.08)
                antialiasing: true
                scale: tap.pressed ? 0.94 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 120
                        easing.type: Easing.OutQuad
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: btn.modelData.icon
                        color: btn.on ? Colours.paper : (btn.hot ? Colours.ink : Colours.inkDim)
                        font.pixelSize: root.compact ? 15 : 19
                    }

                    P5Text {
                        id: label

                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.labelled
                        text: btn.on ? "Enter password" : btn.modelData.label
                        color: btn.on ? Colours.paper : (btn.hot ? Colours.ink : Colours.alpha(Colours.ink, 0.82))
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: tap

                    onPressedChanged: {
                        if (tap.pressed)
                            Sfx.cursor();
                    }
                    onTapped: root.press(btn.modelData)
                }
            }
        }
    }
}
