//  VELVET  ·  modules/bar/Popouts.qml
//  The panel that slides out beside the bar. One per screen; what it shows
//  is whatever Popout currently points at.
import qs.config
import qs.services
import qs.components
import "popouts"
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property string position: Config.bar.position
    readonly property bool vertical: position === "left" || position === "right"
    readonly property bool atStart: position === "left" || position === "top"
    readonly property int barFootprint: Config.bar.thickness + Config.bar.margin * 2
    readonly property bool shown: Popout.open && (Popout.screenName === "" || Popout.screenName === modelData.name)

    property bool entered: false
    // The card needs one beat to leave after the popout closes — `shown`
    // flips immediately, but hiding the window on that same frame would
    // throw away the slide/fade Behaviors below.
    property bool closing: false
    // The content must not swap while the card is leaving: Popout.name is
    // already "" by then, and the loader would flash the default panel.
    property string frozenName: "quick"

    Connections {
        target: Popout
        function onNameChanged(): void {
            if (root.shown)
                root.frozenName = Popout.name;
        }
    }

    onShownChanged: {
        if (shown) {
            root.frozenName = Popout.name;
            root.closing = false;
            enterTimer.restart();
        } else {
            root.entered = false;
            root.closing = true;
            exitTimer.restart();
        }
    }

    Timer {
        id: enterTimer
        interval: 1
        onTriggered: root.entered = true
    }

    Timer {
        id: exitTimer
        interval: Appearance.anim.normal
        onTriggered: root.closing = false
    }

    screen: modelData
    visible: root.shown || root.closing
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-popout"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        left: root.position !== "right"
        right: root.position !== "left"
        top: root.position !== "bottom"
        bottom: root.position !== "top"
    }

    implicitWidth: root.vertical ? root.barFootprint + 380 : 0
    implicitHeight: root.vertical ? 0 : root.barFootprint + 320

    mask: Region {
        item: (root.shown || root.closing) ? card : null
    }

    Item {
        id: card

        readonly property real gap: 6
        readonly property real slide: root.entered ? 0 : 30

        // One card that MORPHS from what it showed to what it shows (a tip
        // to the next tip, a tip to the quick panel): its size springs, the
        // new content fades in once there is room for it.
        width: card.cw
        height: card.ch
        property real cw: content.implicitWidth
        property real ch: content.implicitHeight
        Behavior on cw {
            enabled: root.entered
            SpringAnimation {
                spring: 5
                damping: 0.42
                epsilon: 0.3
            }
        }
        Behavior on ch {
            enabled: root.entered
            SpringAnimation {
                spring: 5
                damping: 0.42
                epsilon: 0.3
            }
        }

        // The anchor glides (a tip moving on to the next button), the slide
        // eases, the size springs — and the position is simply where they put
        // it. A curve on x itself was restarted by every frame of the size's
        // spring and never moved (measured: stuck at the old place).
        property real ax: Popout.anchorPos
        Behavior on ax {
            enabled: root.entered
            SpringAnimation {
                spring: 5
                damping: 0.42
                epsilon: 0.3
            }
        }
        property real sl: card.slide
        Behavior on sl {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutExpo
            }
        }

        x: {
            if (root.vertical)
                return root.position === "left" ? root.barFootprint - Config.bar.margin + gap + card.sl : root.width - root.barFootprint + Config.bar.margin - gap - width - card.sl;
            return Math.max(Config.bar.margin, Math.min(root.width - width - Config.bar.margin, card.ax - width / 2));
        }

        y: {
            if (!root.vertical)
                return root.position === "top" ? root.barFootprint - Config.bar.margin + gap + card.sl : root.height - root.barFootprint + Config.bar.margin - gap - height - card.sl;
            return Math.max(Config.bar.margin, Math.min(root.height - height - Config.bar.margin, card.ax - height / 2));
        }

        opacity: root.entered ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Colours.alpha(Colours.surface, Math.min(0.97, Config.bar.opacity + 0.12))
            border.width: 1
            border.color: Colours.alpha(Colours.accent, 0.3)
            antialiasing: true

            Halftone {
                anchors.fill: parent
                strength: 0.03
                density: 1.6
            }
        }

        // the content's window: it is cut to the card while the card grows
        Item {
            anchors.fill: parent
            clip: true

            Loader {
                id: content

                active: root.shown || root.closing
                // centred while the card grows round it
                x: Math.round((card.width - width) / 2)
                y: Math.round((card.height - height) / 2)
                opacity: 1

                onSourceComponentChanged: {
                    if (root.entered) {
                        content.opacity = 0;
                        contentIn.restart();
                    }
                }

                NumberAnimation {
                    id: contentIn

                    target: content
                    property: "opacity"
                    to: 1
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
                sourceComponent: {
                    switch (root.frozenName) {
                    case "tray":
                        return trayC;
                    case "tip":
                        return tipC;
                    case "ws":
                        return wsC;
                    default:
                        return quickC;
                    }
                }
            }
        }

        // A HoverHandler observes without becoming the hovered item: the
        // MouseArea that sat here on top swallowed hover for everything in
        // the card, so no row, chip or slider inside ever lit up.
        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    Popout.hold();
                else
                    Popout.release(Popout.name);
            }
        }
    }

    Component {
        id: quickC
        QuickPanel {}
    }

    Component {
        id: trayC
        TrayMenu {}
    }

    Component {
        id: tipC
        Tip {}
    }

    Component {
        id: wsC
        WorkspacePeek {}
    }
}
