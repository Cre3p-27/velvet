//  VELVET  ·  modules/bar/BarWindow.qml
//  One layer-shell strip per monitor. Handles docking edge, exclusive zone,
//  hover reveal and the input mask; everything visual lives in Bar.qml.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property string position: Config.bar.position
    readonly property bool vertical: position === "left" || position === "right"
    readonly property bool atStart: position === "left" || position === "top"
    readonly property int thickness: Config.bar.thickness
    readonly property int margin: Config.bar.margin
    readonly property int footprint: thickness + margin * 2

    // Reveal logic: pinned open, or slid away until the pointer touches the edge.
    property bool hovered: false
    // Focus mode can take the bar away entirely — but only until you reach
    // for it, which is what `hovered` is for.
    property bool pinned: (Config.bar.persistent || !Config.bar.showOnHover) && !Focus.hidesBar

    // Stay out while anything the bar owns is still on screen, otherwise the
    // strip slides away underneath its own popout.
    readonly property bool revealed: pinned || hovered || Panels.settings || Popout.open

    // Hidden means hidden. `revealEdge` is the invisible strip that listens for
    // the pointer — it used to double as the slide distance, which is why the
    // bar only went half away. `peek` is the separate, opt-in sliver of bar
    // left showing, and it defaults to none.
    readonly property real hiddenOffset: footprint - Math.max(0, Math.min(footprint, Config.bar.peek))
    readonly property real slide: revealed ? 0 : hiddenOffset

    // ── the SCREEN FRAME on the bar's edge ──────────────────────────────────
    //  The frame's band on this edge is drawn HERE, under the bar, and it is
    //  as wide as the bar is out: the frame's width while a hover bar hides,
    //  the bar's strip once it is out — growing with the slide, so the bar
    //  comes out OF the frame and the desktop's corners make room with it
    //  (ScreenFrame reads `Panels.barOut` and moves its inner edge the same
    //  way). The frame lies above the bar, so it leaves this band out.
    readonly property bool framed: Config.bar.frame && Config.bar.style !== "floating"
    readonly property int strip: root.thickness + root.margin
    property real reveal: root.revealed ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutExpo
        }
    }

    readonly property real band: root.framed ? Math.max(0, Math.min(root.footprint, Config.bar.frameWidth + (root.strip - Config.bar.frameWidth) * root.reveal)) : 0

    onRevealedChanged: Panels.setBarOut(root.modelData?.name ?? "", root.revealed)

    // a PanelWindow root has no Component.onCompleted (shell rule): say it once
    Timer {
        running: true
        interval: 1
        onTriggered: Panels.setBarOut(root.modelData?.name ?? "", root.revealed)
    }

    screen: modelData
    color: "transparent"
    WlrLayershell.namespace: "velvet-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // While the settings menu is open the bar is drawn ON TOP of it, so every
    // taskbar setting is a live preview of the real thing rather than a mockup.
    // (the settings are a window now: the bar stays on its own layer)
    WlrLayershell.layer: WlrLayer.Top

    exclusiveZone: pinned ? thickness + margin : 0

    anchors {
        left: root.position !== "right"
        right: root.position !== "left"
        top: root.position !== "bottom"
        bottom: root.position !== "top"
    }

    implicitWidth: root.vertical ? root.footprint : 0
    implicitHeight: root.vertical ? 0 : root.footprint

    // Only the strip itself eats clicks — the rest of the screen stays live.
    mask: Region {
        item: hitArea
    }

    Item {
        id: hitArea

        // When hidden, only a sliver near the edge listens, so the bar doesn't
        // steal the pointer from maximised windows.
        readonly property int band: root.revealed ? root.footprint : Math.max(2, Config.bar.revealEdge)
        // A FLOATING bar is a pill: beside it the screen stays clickable.
        readonly property bool pill: bar.floating && root.revealed

        x: root.vertical ? (root.position === "left" ? 0 : root.width - band) : (hitArea.pill ? root.margin + bar.plateX : 0)
        y: root.vertical ? (hitArea.pill ? root.margin + bar.plateY : 0) : (root.position === "top" ? 0 : root.height - band)
        width: root.vertical ? band : (hitArea.pill ? bar.plateW : root.width)
        height: root.vertical ? (hitArea.pill ? bar.plateH : root.height) : band
    }

    // The frame's band on this edge (see `band` above), in the frame's colour.
    // CONNECTED, the bar wears no plate of its own: band and bar are one.
    Rectangle {
        visible: root.framed && root.band > 0.5
        x: root.position === "right" ? root.width - root.band : 0
        y: root.position === "bottom" ? root.height - root.band : 0
        width: root.vertical ? root.band : root.width
        height: root.vertical ? root.height : root.band
        color: Colours.alpha(Colours.frameBase, Math.max(0.2, Math.min(1, Config.bar.frameOpacity)))
    }

    Item {
        id: surface

        anchors.fill: parent

        // A HoverHandler, not a MouseArea. A MouseArea here loses hover the
        // moment the pointer crosses onto one of the bar's own buttons — which
        // is exactly when you least want the bar to slide away.
        HoverHandler {
            id: hover

            onHoveredChanged: {
                if (hovered) {
                    hideTimer.stop();
                    showTimer.restart();
                } else {
                    showTimer.stop();
                    hideTimer.restart();
                }
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => bar.handleWheel(root.vertical ? event.y : event.x, event.angleDelta)
        }

        Bar {
            id: bar

            screen: root.modelData
            vertical: root.vertical
            barWindow: root

            anchors.fill: parent
            anchors.margins: root.margin

            transform: Translate {
                x: root.vertical ? (root.position === "left" ? -root.slide : root.slide) : 0
                y: root.vertical ? 0 : (root.position === "top" ? -root.slide : root.slide)

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutExpo
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutExpo
                    }
                }
            }
        }
    }

    Timer {
        id: showTimer
        interval: root.pinned ? 0 : Config.bar.hoverDelay
        onTriggered: root.hovered = true
    }

    // Generous by default: the common way to lose an auto-hiding bar is for it
    // to vanish in the gap between leaving it and reaching what you aimed at.
    Timer {
        id: hideTimer
        interval: Config.bar.hideDelay
        onTriggered: {
            if (!hover.hovered)
                root.hovered = false;
        }
    }
}
