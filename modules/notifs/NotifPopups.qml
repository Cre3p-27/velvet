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

    // NOTIFICATIONS → IN THE FRAME: the cards sit in a tab of the frame
    // itself (drawn by ScreenFrame from Notifs.frameTabs), flush with the
    // frame's inner edge; the tab grows and shrinks on a spring and the cards
    // show through it as it opens.
    readonly property bool inFrame: Config.notifs.inFrame && Config.bar.frame
    readonly property real pad: root.inFrame ? 12 : 0
    readonly property real wantH: Notifs.shownPopups.length > 0 ? stack.implicitHeight + root.pad * 2 : 0
    readonly property real tabH: root.inFrame ? tabSpring.value : 0

    Spring {
        id: tabSpring

        to: root.inFrame ? root.wantH : 0
        spring: 3.4
        damping: 0.5
        epsilon: 0.3
    }

    onTabHChanged: Notifs.setFrameTab(root.modelData?.name ?? "", root.inFrame ? root.implicitWidth : 0, root.tabH)
    onInFrameChanged: Notifs.setFrameTab(root.modelData?.name ?? "", root.inFrame ? root.implicitWidth : 0, root.tabH)

    screen: modelData
    visible: Notifs.shownPopups.length > 0 || root.tabH > 0.5
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
    // In the frame the window sits right on the frame's inner edge.
    margins {
        top: Appearance.frameRoom("top") + (root.inFrame ? 0 : 14)
        bottom: Appearance.frameRoom("bottom") + (root.inFrame ? 0 : 14)
        left: Appearance.frameRoom("left") + (root.inFrame ? 0 : 14)
        right: Appearance.frameRoom("right") + (root.inFrame ? 0 : 14)
    }

    implicitWidth: root.inFrame ? Config.notifs.width + root.pad * 2 : Config.notifs.width + 20
    implicitHeight: Math.max(1, root.inFrame ? root.wantH : stack.implicitHeight)

    mask: Region {
        item: root.inFrame ? clipper : stack
    }

    // What of the tab is open (all of the window, outside the frame).
    Item {
        id: clipper

        width: parent.width
        height: root.inFrame ? Math.min(parent.height, root.tabH) : parent.height
        y: root.inFrame && !root.onTop ? parent.height - height : 0
        clip: root.inFrame

        Column {
            id: stack

            x: root.pad
            y: root.inFrame && !root.onTop ? clipper.height - root.pad - height : root.pad
            width: root.inFrame ? Config.notifs.width : parent.width
            spacing: root.inFrame ? 0 : Appearance.spacing.small

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
                    bare: root.inFrame

                    // in the frame: a hairline between one card and the next
                    Rectangle {
                        visible: root.inFrame && card.index < Notifs.shownPopups.length - 1
                        x: 18
                        y: parent.height - 1
                        width: parent.width - 36
                        height: 1
                        color: Colours.alpha(Colours.ink, 0.12)
                    }

                    // Fly in from the side the stack lives on, with a small
                    // settle-pop — an OutBack stamp on every arrival — and fly
                    // out again when it goes. Dragged sideways it follows the
                    // hand; far enough (or flicked) it is swiped away, else it
                    // springs back. After the entrance x simply IS the sprung
                    // dragX (a timed curve on x chasing a spring never moves).
                    // dragX is where the hand (or the swipe's verdict) puts it;
                    // dragAt is where the spring has it on this frame.
                    readonly property real away: root.inFrame && root.onCentre ? 0 : (root.onRight ? width + 30 : -width - 30)
                    x: card.shown ? card.dragAt : card.away
                    opacity: shown && !leaving ? 1 - Math.min(0.6, Math.abs(card.dragAt) / Math.max(1, width) * 0.9) : 0
                    scale: shown ? 1 : 0.92
                    property bool shown: false
                    property bool inPlace: false
                    property bool leaving: false
                    property bool closing: false
                    property real dragX: 0
                    readonly property real dragAt: dragSpring.value

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
                    // (components/Spring.qml: SpringAnimation's physics, drawn
                    // on every frame of a fast screen; the hand moves it directly)
                    Spring {
                        id: dragSpring

                        to: card.dragX
                        live: !card.swiping
                        spring: 4.5
                        damping: 0.38
                        epsilon: 0.3
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
}
