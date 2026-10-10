//  VELVET  ·  modules/map/WindowMap.qml
//  The map plate, for when the Dynamic Island is switched off: the infinite
//  canvas (MapCanvas.qml — the same one the island opens as its DESKTOP
//  module) on a plate that slides in from the island's edge. Opened by the
//  map shortcut / the bar (pinned, with the keyboard) or by reaching for the
//  edge (hover, no keyboard). It closes when the pointer leaves it, on Esc,
//  or with a click off the plate.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool pinned: Panels.windowMap
    readonly property bool mine: root.modelData === Hypr.focusedScreen
    // Opened by reaching for the edge (EdgeSensor) — takes no keyboard.
    readonly property bool hovered: Panels.mapHover !== "" && Panels.mapHover === (root.modelData?.name ?? "")

    // Opened on purpose on the screen you are looking at, or reached for with
    // the pointer on this one. Never on every monitor at once.
    readonly property bool shown: (root.pinned && root.mine) || root.hovered

    // ═══════════════════════════════════════════════════════════════ the window
    screen: modelData
    color: "transparent"
    WlrLayershell.namespace: "velvet-map"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.pinned && root.mine ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: -1

    visible: Config.map.enabled

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // Input while open, silence while closed. OPENING is the EdgeSensor's
    // job — a dedicated strip window beside this one, shaped like the bar.
    // When closed, this window eats NOTHING.
    mask: Region {
        item: root.shown ? inputArea : deadZone
    }

    Item {
        id: inputArea

        anchors.fill: parent
    }

    Item {
        id: deadZone

        width: 0
        height: 0
    }

    // Everything that counts as "still using the map".
    Item {
        id: shield

        readonly property int span: Math.max(plate.width + 44, Math.max(80, Config.map.edgeWidth) + 44)
        readonly property string edge: Appearance.islandEdge
        // on a side edge: the plate and its margin, reaching the edge, and
        // the whole hot zone beside it
        readonly property real zone: Math.max(80, Config.map.edgeWidth) + 44
        readonly property real sideTop: Math.min(plate.y - 28, plate.y + plate.height / 2 - zone / 2)
        readonly property real sideBottom: Math.max(plate.y + plate.height + 28, plate.y + plate.height / 2 + zone / 2)

        x: shield.edge === "left" ? 0 : (shield.edge === "right" ? plate.x - 28 : Math.round(plate.x + plate.width / 2 - shield.span / 2))
        y: shield.edge === "top" ? 0 : shield.sideTop
        width: shield.edge === "left" ? plate.x + plate.width + 28 : (shield.edge === "right" ? root.width - plate.x + 28 : shield.span)
        height: shield.edge === "top" ? plate.y + plate.height + 28 : shield.sideBottom - shield.sideTop

        z: 50

        HoverHandler {
            id: plateHover

            onHoveredChanged: {
                if (hovered)
                    closeTimer.stop();
                else
                    closeTimer.restart();
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Config.map.closeDelay

        // The ONLY way the map closes: the pointer leaves the plate and its
        // margin. Clicking windows, desktops or tabs never closes it.
        onTriggered: {
            if (plateHover.hovered)
                return;
            if (canvas.busy) {
                closeTimer.restart();
                return;
            }
            root.closeQuiet();
        }
    }

    function close(): void {
        Sfx.close();
        Panels.windowMap = false;
        Panels.mapHover = "";
    }

    function closeQuiet(): void {
        Panels.windowMap = false;
        Panels.mapHover = "";
    }

    // Hard watchdog: three quiet minutes close the map, pinned or not.
    Timer {
        id: openWatchdog

        interval: 180000
        onTriggered: {
            if (canvas.busy || plateHover.hovered) {
                openWatchdog.restart();
                return;
            }
            console.warn("MAP: watchdog closed the map after three quiet minutes");
            root.closeQuiet();
        }
    }

    function poke(): void {
        openWatchdog.restart();
    }

    onPinnedChanged: {
        if (root.pinned)
            Sfx.open();
        else
            Panels.mapHover = "";
    }

    onShownChanged: {
        if (!root.shown) {
            openWatchdog.stop();
            return;
        }
        openWatchdog.restart();
        if (root.pinned)
            keyboard.forceActiveFocus();
        else
            closeTimer.restart();   // reached for but never entered: let it go again
    }

    // The map is created when it is first needed (shell.qml, Parked), by which
    // time `shown` is already true and has gone by: say it once more.
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (root.shown)
                root.shownChanged();
        }
    }

    // An opened-on-purpose map still has to be dismissable with the mouse:
    // a click off the plate closes it (it used to swallow every click).
    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        onPressed: {
            if (root.pinned && !plateHover.hovered)
                root.close();
        }
    }

    Item {
        id: keyboard

        anchors.fill: parent
        focus: root.pinned && root.mine

        Keys.onPressed: event => {
            root.poke();
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
                return;
            }
            event.accepted = canvas.handleKey(event);
        }
    }

    // ═════════════════════════════════════════════════════════════════ the plate
    Item {
        id: plate

        readonly property int pad: 14

        readonly property real aspect: {
            const m = Desk.focusedMonitor;
            if (m && m.h > 0)
                return m.w / m.h;
            return root.width / Math.max(1, root.height);
        }

        // the canvas keeps the monitor's shape; MAP SIZE of the screen wide,
        // never taller than the screen leaves room for
        readonly property int fieldW: {
            let w = Math.round(Math.max(420, Math.min(root.width - 120, root.width * Config.map.plateWidth)));
            const roomH = Math.max(200, root.height - 60 - plate.pad * 2 - canvas.stripH - canvas.barH - canvas.gap * 2);
            if (w / plate.aspect > roomH)
                w = Math.round(roomH * plate.aspect);
            return w;
        }
        readonly property int fieldH: Math.round(plate.fieldW / Math.max(0.3, plate.aspect))

        width: plate.fieldW + plate.pad * 2
        height: plate.fieldH + canvas.stripH + canvas.barH + canvas.gap * 2 + plate.pad * 2
        // where the island lives: the map slides in from the same edge
        // (MODULES → DYNAMIC ISLAND → POSITION) — down from the top, or out
        // of the left or right side at ISLAND HEIGHT
        readonly property string edge: Appearance.islandEdge
        x: plate.edge === "left" ? 14 + Appearance.edgeInset("left") : (plate.edge === "right" ? root.width - width - 14 - Appearance.edgeInset("right") : Math.round((root.width - width) / 2))
        y: plate.edge === "top" ? 14 + Appearance.edgeInset("top") : Math.round(Math.max(14, Math.min(root.height - height - 14, root.height * Math.max(0.05, Math.min(0.95, Config.map.islandEdgeY)) + Config.map.islandShift - height / 2)))

        opacity: root.shown ? 1 : 0
        visible: opacity > 0.01

        transform: Translate {
            x: root.shown || plate.edge === "top" ? 0 : (plate.edge === "left" ? -plate.width - 30 : plate.width + 30)
            y: root.shown || plate.edge !== "top" ? 0 : -plate.height - 30

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

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Colours.alpha(Colours.surface, 0.97)
            antialiasing: true

            // The house texture — every panel in the shell carries it.
            Halftone {
                anchors.fill: parent
                strength: 0.03
                density: 1.6
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Colours.alpha(Colours.ink, 0.14)
                antialiasing: true
            }
        }

        MapCanvas {
            id: canvas

            anchors.fill: parent
            anchors.margins: plate.pad
            live: root.shown
            keys: root.pinned
            ground: Colours.surface
            onPoked: root.poke()
            onCloseRequested: root.close()
        }
    }
}
