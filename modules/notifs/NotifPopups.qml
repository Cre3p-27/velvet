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

        // a card that left: the ones below close up, they do not jump
        move: Transition {
            NumberAnimation {
                properties: "y"
                duration: Appearance.anim.normal
                easing.type: Easing.OutCubic
            }
        }

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
                // settle-pop — an OutBack stamp on every arrival — and fly
                // out again when it goes. Dragged sideways it follows the
                // hand; far enough (or flicked) it is swiped away, else it
                // springs back. After the entrance x simply IS the sprung
                // dragX (a timed curve on x chasing a spring never moves).
                readonly property real away: root.onRight ? width + 30 : -width - 30
                x: card.shown ? card.dragX : card.away
                opacity: shown && !leaving ? 1 - Math.min(0.6, Math.abs(card.dragX) / Math.max(1, width) * 0.9) : 0
                scale: shown ? 1 : 0.92
                property bool shown: false
                property bool inPlace: false
                property bool leaving: false
                property bool closing: false
                property real dragX: 0

                swipeable: true
                Component.onCompleted: shown = true

                Timer {
                    running: card.shown
                    interval: Appearance.anim.normal + 40
                    onTriggered: card.inPlace = true
                }

                function leave(close: bool): void {
                    if (card.leaving)
                        return;
                    card.closing = close;
                    card.leaving = true;
                    card.inPlace = true;
                    // out the way it was swiped, else back to its side
                    card.dragX = card.dragX < -10 ? -card.width - 30 : (card.dragX > 10 ? card.width + 30 : card.away);
                    gone.restart();
                }

                Timer {
                    id: gone

                    interval: Appearance.anim.normal
                    onTriggered: card.closing ? Notifs.close(card.modelData) : Notifs.dismiss(card.modelData)
                }

                onSwipeMoved: dx => card.dragX = dx
                onSwipeEnded: (dx, vx) => {
                    const far = Math.abs(dx) > card.width * 0.32;
                    // a flick counts only with some way behind it: a twitch of
                    // the hand (or a burst of events) is fast but short
                    const flick = Math.abs(vx) > 900 && Math.abs(dx) > card.width * 0.12 && Math.sign(vx) === Math.sign(dx);
                    if (far || flick) {
                        Sfx.close();
                        card.leave(false);
                    } else {
                        card.dragX = 0;
                    }
                }

                Behavior on x {
                    enabled: !card.inPlace
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutExpo
                    }
                }
                Behavior on dragX {
                    enabled: !card.swiping
                    SpringAnimation {
                        spring: 4.5
                        damping: 0.38
                        epsilon: 0.3
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

                onDismissed: card.leave(false)
                onClosed: card.leave(true)

                Timer {
                    running: !hovering.hovered && !card.swiping && !card.leaving
                    // the sender's own timeout when it asked for one, else the user's
                    interval: (card.modelData?.expire ?? -1) > 0 ? card.modelData.expire : (card.critical ? Config.notifs.timeout * 2 : Config.notifs.timeout)
                    onTriggered: card.leave(false)
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
