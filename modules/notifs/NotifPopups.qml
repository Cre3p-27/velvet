//  VELVET  ·  modules/notifs/NotifPopups.qml
//  Transient notification stack in a screen corner.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool onTop: Config.notifs.position.startsWith("top")
    readonly property bool onRight: Config.notifs.position.endsWith("right")
    // top-centre / bottom-centre: anchored to one edge only, the compositor
    // centres the stack along it
    readonly property bool onCentre: Config.notifs.position.endsWith("centre")

    screen: modelData
    visible: Notifs.shownPopups.length > 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-notifs"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        top: root.onTop
        bottom: !root.onTop
        left: !root.onRight && !root.onCentre
        right: root.onRight
    }

    // The window keeps out of a pinned bar's zone by itself (exclusiveZone
    // 0); what is left is the screen frame and a little air. (It used to add a
    // whole bar to the top and the left, wherever the bar actually was.)
    margins {
        top: Appearance.frameRoom("top") + 14
        bottom: Appearance.frameRoom("bottom") + 14
        left: Appearance.frameRoom("left") + 14
        right: Appearance.frameRoom("right") + 14
    }

    implicitWidth: Config.notifs.width + 20
    implicitHeight: Math.max(1, stack.implicitHeight)

    mask: Region {
        item: stack
    }

    Column {
        id: stack

        width: parent.width
        spacing: Appearance.spacing.small

        Repeater {
            // ScriptModel keeps each card alive across list changes: a plain
            // array rebuilt every card (and restarted its timer) on each new one.
            model: ScriptModel {
                values: Notifs.shownPopups
                objectProp: "id"
            }

            NotifCard {
                id: card

                required property var modelData
                required property int index

                wrapper: modelData

                // Fly in from the side the stack lives on, with a small
                // settle-pop — an OutBack stamp on every arrival.
                x: shown ? 0 : (root.onRight ? width + 30 : -width - 30)
                opacity: shown ? 1 : 0
                scale: shown ? 1 : 0.92
                property bool shown: false

                Component.onCompleted: shown = true

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutExpo
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.7
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                onDismissed: Notifs.dismiss(modelData)
                onClosed: Notifs.close(modelData)

                Timer {
                    running: !hovering.hovered
                    interval: card.critical ? Config.notifs.timeout * 2 : Config.notifs.timeout
                    onTriggered: Notifs.dismiss(card.modelData)
                }

                // A HoverHandler sees the pointer even over the card's own
                // MouseAreas; the old MouseArea underneath never did, so a
                // popup vanished while you were reading it.
                HoverHandler {
                    id: hovering
                }
            }
        }
    }
}
