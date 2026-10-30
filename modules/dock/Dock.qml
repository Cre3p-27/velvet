//  VELVET  ·  modules/dock/Dock.qml
//  The SECOND TASKBAR (TASKBAR → DOCK): a row of your own shortcuts on an
//  edge of its own — apps, terminal commands, folders, web links and the
//  shell's own actions (settings, the scratchpad, Velly …).
//
//    click         open it — an app that is already open comes forward
//                  (again: its next window)
//    middle click  a new one
//    +             add: type to find an app, or switch to COMMAND, FOLDER,
//                  WEB LINK or SHELL and type what it is
//    drag          along the dock: reorder · off the dock: it goes, in a puff
//
//  The look follows the shell (STYLE AUTO): pop-it bubbles in every colour on
//  FIDGET, glass on the glass looks, a solid pill on the rest. Items live in
//  config.json (dock.items).
pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property string edge: ["bottom", "top", "left", "right"].indexOf(Config.dock.position) >= 0 ? Config.dock.position : "bottom"
    readonly property bool across: root.edge === "bottom" || root.edge === "top"
    readonly property int icon: Math.max(28, Math.min(80, Config.dock.size))
    readonly property int slot: root.icon + 14
    readonly property real gap: 8 + Appearance.frameRoom(root.edge)
    readonly property string style: {
        const s = Config.dock.style;
        if (s !== "auto")
            return s;
        if (Appearance.fidget)
            return "bubble";
        return ["glass", "chrome"].indexOf(Config.appearance.vibe) >= 0 ? "glass" : "solid";
    }

    // ── what is on it: the saved items, then (RUNNING) open apps not on it
    // (read back from config.json a list is list-like, not an Array: Array.from takes either)
    readonly property var items: {
        const l = Config.dock.items;
        return l && typeof l !== "string" && typeof l.length === "number" ? Array.from(l).map(it => Object.assign({}, it)) : [];
    }
    readonly property var running: {
        const out = {};
        const tops = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < tops.length; i++) {
            const raw = tops[i].lastIpcObject;
            const cls = `${raw?.class ?? ""}`.toLowerCase();
            if (!cls)
                continue;
            (out[cls] = out[cls] ?? []).push(raw.address ?? "");
        }
        return out;
    }

    function entryOf(id: string): var {
        return id ? DesktopEntries.byId(id.replace(/\.desktop$/, "")) ?? DesktopEntries.byId(id) : null;
    }

    function classOf(it: var): string {
        if (it?.kind !== "app")
            return "";
        const e = root.entryOf(it.id);
        return `${e?.startupClass || it.id.replace(/\.desktop$/, "")}`.toLowerCase();
    }

    function windowsOf(it: var): var {
        const cls = root.classOf(it);
        if (!cls)
            return [];
        return root.running[cls] ?? root.running[cls.split(".").pop()] ?? [];
    }

    readonly property var extras: {
        if (!Config.dock.running)
            return [];
        const mine = {};
        for (const it of root.items)
            if (it.kind === "app")
                mine[root.classOf(it)] = true;
        const out = [];
        for (const cls in root.running) {
            if (mine[cls] || mine[cls.split(".").pop()])
                continue;
            out.push({
                kind: "window",
                cls: cls,
                name: cls
            });
        }
        return out;
    }

    function label(it: var): string {
        if (it.name)
            return it.name;
        if (it.kind === "app")
            return root.entryOf(it.id)?.name ?? it.id;
        return it.cmd ?? it.path ?? it.url ?? "";
    }

    function glyph(it: var): string {
        if (it.icon)
            return it.icon;
        return ({
                cmd: "terminal",
                folder: "folder",
                url: "public",
                shell: "auto_awesome"
            })[it.kind] ?? "apps";
    }

    // ── doing it
    property var cycle: ({})

    function activate(it: var, fresh: bool): void {
        Sfx.pop();
        if (it.kind === "window" || (it.kind === "app" && !fresh)) {
            const wins = it.kind === "window" ? (root.running[it.cls] ?? []) : root.windowsOf(it);
            if (wins.length > 0) {
                const key = it.kind === "window" ? it.cls : it.id;
                const n = ((root.cycle[key] ?? -1) + 1) % wins.length;
                root.cycle = Object.assign({}, root.cycle, {
                    [key]: n
                });
                Hypr.focusWindow(wins[n]);
                return;
            }
        }
        switch (it.kind) {
        case "app":
            {
                const e = root.entryOf(it.id);
                if (e)
                    Apps.spawn(e);
                else
                    Toast.show(`${it.id.toUpperCase()} IS NOT INSTALLED ANY MORE — DRAG IT OFF THE DOCK`, "warn", 3600);
                break;
            }
        case "cmd":
            Hypr.exec(it.cmd);
            break;
        case "folder":
            Hypr.exec(`xdg-open ${Apps.shq(`${it.path}`.replace(/^~(?=\/|$)/, Quickshell.env("HOME")))}`);
            break;
        case "url":
            Hypr.exec(`xdg-open ${Apps.shq(/^[a-z]+:\/\//i.test(it.url) ? it.url : `https://${it.url}`)}`);
            break;
        case "shell":
            Hypr.exec(`qs -c velvet ipc call ${it.ipc}`);
            break;
        }
    }

    function save(list: var): void {
        Config.set("dock.items", list);
    }

    function add(it: var): void {
        root.save(root.items.concat([it]));
        Sfx.snap();
    }

    function removeAt(i: int): void {
        const next = root.items.slice();
        next.splice(i, 1);
        root.save(next);
    }

    function moveItem(from: int, to: int): void {
        if (from === to || from < 0 || to < 0 || from >= root.items.length)
            return;
        const next = root.items.slice();
        const [it] = next.splice(from, 1);
        next.splice(Math.min(to, next.length), 0, it);
        root.save(next);
        Sfx.tick(0.8);
    }

    // The first time it comes up empty: the launcher's pinned apps, else the
    // ones you open most.
    Timer {
        running: true
        interval: 400
        onTriggered: {
            if (root.items.length > 0 || Config.dock.seeded)
                return;
            let ids = Apps.pinned.slice(0, 8);
            if (ids.length === 0)
                ids = Object.keys(Apps.usage).filter(k => !k.startsWith("__") && root.entryOf(k)).sort((a, b) => Apps.frecency(b) - Apps.frecency(a)).slice(0, 6);
            Config.setMany({
                "dock.items": ids.map(id => ({
                            kind: "app",
                            id: id
                        })),
                "dock.seeded": true
            });
        }
    }

    // ── the window: on its edge, as long as what is on it
    screen: modelData
    color: "transparent"
    visible: Config.dock.enabled
    WlrLayershell.namespace: "velvet-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: adder.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: Config.dock.autoHide ? 0 : root.slot + 16 + 4

    anchors {
        bottom: root.edge === "bottom"
        top: root.edge === "top"
        left: root.edge === "left"
        right: root.edge === "right"
    }

    margins {
        bottom: root.edge === "bottom" ? root.gap : 0
        top: root.edge === "top" ? root.gap : 0
        left: root.edge === "left" ? root.gap : 0
        right: root.edge === "right" ? root.gap : 0
    }

    // room for the magnified icons, the labels and the adder
    readonly property int count: root.items.length + root.extras.length + 1
    readonly property real length: root.count * root.slot + (root.extras.length > 0 ? 14 : 0) + 20
    readonly property real reach: root.slot + 16 + (Config.dock.magnify ? root.icon * 0.55 : 0) + 40
    implicitWidth: root.across ? Math.max(root.length + root.icon, adder.open ? 460 : 0) : root.reach + (adder.open ? 380 : 0)
    implicitHeight: root.across ? root.reach + (adder.open ? 300 : 0) : Math.max(root.length + root.icon, adder.open ? 420 : 0)

    // AUTO-HIDE: only a strip along the edge listens until you reach for it
    property bool out: !Config.dock.autoHide || hover.hovered || adder.open || drag.active
    readonly property real shown: slide.value

    Spring {
        id: slide

        to: root.out ? 1 : 0
        spring: 3.6
        damping: 0.5
        epsilon: 0.004
    }

    mask: Region {
        item: root.out || slide.value > 0.02 ? hitArea : strip
    }

    Item {
        id: strip

        x: root.across ? (root.width - root.length) / 2 : (root.edge === "left" ? 0 : root.width - 4)
        y: root.across ? (root.edge === "top" ? 0 : root.height - 4) : (root.height - root.length) / 2
        width: root.across ? root.length : 4
        height: root.across ? 4 : root.length
    }

    Item {
        id: hitArea

        x: root.across ? 0 : (root.edge === "left" ? 0 : root.width - width)
        y: root.across ? (root.edge === "top" ? 0 : root.height - height) : 0
        width: root.across ? root.width : root.slot + 16 + (Config.dock.magnify ? root.icon * 0.55 : 0) + (adder.open ? 380 : 0)
        height: root.across ? root.slot + 16 + (Config.dock.magnify ? root.icon * 0.55 : 0) + (adder.open ? 300 : 0) : root.height
    }

    HoverHandler {
        id: hover
    }

    // ── the plate and the icons
    Item {
        id: dock

        // where the pointer is along the dock (for the magnifier), -1: away
        property real at: -1

        width: root.across ? root.length : root.slot + 16
        height: root.across ? root.slot + 16 : root.length
        x: root.across ? (root.width - width) / 2 : (root.edge === "left" ? -(1 - root.shown) * (width + root.gap + 6) : root.width - width + (1 - root.shown) * (width + root.gap + 6))
        y: root.across ? (root.edge === "top" ? -(1 - root.shown) * (height + root.gap + 6) : root.height - height + (1 - root.shown) * (height + root.gap + 6)) : (root.height - height) / 2

        Puff {
            anchors.fill: parent
            visible: root.style === "bubble"
            kind: "clay"
            radius: Math.min(width, height) / 2
            color: Colours.surface
            depth: 7
        }

        Plate {
            anchors.fill: parent
            visible: root.style !== "bubble"
            radius: Appearance.r(Math.min(width, height) / 2)
            color: root.style === "glass" ? (Colours.light ? Colours.alpha(Colours.surface, 0.6) : Qt.rgba(0.02, 0.022, 0.03, 0.55)) : Colours.alpha(Colours.surface, Math.min(1, Config.appearance.transparency + 0.1))
            border.width: 1
            border.color: root.style === "glass" ? Colours.alpha(Colours.ink, 0.22) : Colours.alpha(Colours.accent, 0.3)

            // glass: light along the top edge
            Rectangle {
                visible: root.style === "glass"
                x: parent.radius * 0.7
                width: parent.width - parent.radius * 1.4
                height: 1
                color: Colours.alpha(Colours.ink, 0.3)
            }
        }

        // the pointer along the dock
        HoverHandler {
            id: along

            onPointChanged: dock.at = along.hovered ? (root.across ? along.point.position.x : along.point.position.y) : -1
            onHoveredChanged: {
                if (!along.hovered)
                    dock.at = -1;
            }
        }

        Repeater {
            model: root.items.length + root.extras.length + 1

            Item {
                id: cell

                required property int index
                readonly property bool isAdd: cell.index === root.items.length + root.extras.length
                readonly property bool isExtra: cell.index >= root.items.length && !cell.isAdd
                readonly property var it: cell.isAdd ? null : (cell.isExtra ? root.extras[cell.index - root.items.length] : root.items[cell.index])
                readonly property int wins: cell.it ? (cell.it.kind === "window" ? (root.running[cell.it.cls] ?? []).length : root.windowsOf(cell.it).length) : 0
                // the slot it sits in, and where a drag puts the others
                readonly property real base: 10 + cell.index * root.slot + (cell.index >= root.items.length && root.extras.length > 0 ? 14 : 0)
                readonly property real shift: {
                    if (!drag.active || cell.index === drag.from || cell.isExtra || cell.isAdd)
                        return 0;
                    if (drag.from < cell.index && drag.to >= cell.index)
                        return -root.slot;
                    if (drag.from > cell.index && drag.to <= cell.index)
                        return root.slot;
                    return 0;
                }
                readonly property real mid: cell.base + cell.shift + root.slot / 2
                // MAGNIFY: the icon under the pointer grows, its neighbours a little
                readonly property real grow: Config.dock.magnify && dock.at >= 0 && !drag.active ? 0.5 * Math.exp(-Math.pow((dock.at - cell.mid) / (root.slot * 1.15), 2)) : 0
                readonly property real hue: (cell.index * 0.13 + 0.55) % 1

                x: root.across ? cell.base + cell.shift : 8
                y: root.across ? 8 : cell.base + cell.shift
                width: root.slot
                height: root.slot
                z: drag.from === cell.index ? 5 : 1

                Behavior on x {
                    enabled: !drag.active || drag.from !== cell.index
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on y {
                    enabled: !drag.active || drag.from !== cell.index
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }

                // the face that moves: it grows out of the dock, squishes when
                // pressed, follows the hand in a drag
                Item {
                    id: face

                    readonly property real lift: cell.grow * root.icon * 0.5
                    property real squish: 1

                    width: root.slot
                    height: root.slot
                    x: root.across ? (drag.from === cell.index ? drag.dx : 0) : (root.edge === "left" ? face.lift : -face.lift) + (drag.from === cell.index ? drag.dy : 0)
                    y: root.across ? (root.edge === "top" ? face.lift : -face.lift) + (drag.from === cell.index ? drag.dy : 0) : (drag.from === cell.index ? drag.dx : 0)
                    scale: (1 + cell.grow) * face.squish
                    transformOrigin: root.edge === "bottom" ? Item.Bottom : (root.edge === "top" ? Item.Top : (root.edge === "left" ? Item.Left : Item.Right))
                    opacity: drag.from === cell.index && drag.away ? 0.45 : 1

                    SequentialAnimation {
                        id: pressPop

                        NumberAnimation {
                            target: face
                            property: "squish"
                            to: 0.8
                            duration: 70
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: face
                            property: "squish"
                            to: 1
                            duration: 380
                            easing.type: Easing.OutBack
                            easing.overshoot: 3.2
                        }
                    }

                    // BUBBLE: every icon in a pop-it bubble of its own colour
                    Puff {
                        anchors.centerIn: parent
                        width: root.icon + 10
                        height: width
                        visible: root.style === "bubble"
                        kind: "clay"
                        radius: width / 2
                        depth: 4
                        color: Qt.hsla(cell.hue, 0.85, Colours.light ? 0.86 : 0.32, 1)
                    }

                    AppIcon {
                        anchors.centerIn: parent
                        width: root.icon * (root.style === "bubble" ? 0.78 : 1)
                        height: width
                        visible: !cell.isAdd && (cell.it?.kind === "app" || cell.it?.kind === "window")
                        cls: cell.it?.kind === "window" ? cell.it.cls : root.classOf(cell.it)
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: cell.isAdd || (cell.it && cell.it.kind !== "app" && cell.it.kind !== "window")
                        name: cell.isAdd ? (adder.open ? "close" : "add") : root.glyph(cell.it ?? {})
                        font.pixelSize: root.icon * (cell.isAdd ? 0.5 : 0.62)
                        color: cell.isAdd ? Colours.alpha(Colours.ink, 0.6) : Colours.accent
                    }
                }

                // open: a dot (or two) beside it
                Row {
                    visible: cell.wins > 0
                    spacing: 3
                    x: root.across ? (parent.width - width) / 2 : (root.edge === "left" ? 1 : parent.width - 5)
                    y: root.across ? (root.edge === "top" ? 1 : parent.height - 5) : (parent.height - height) / 2

                    Repeater {
                        model: Math.min(3, cell.wins)

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: Colours.accent
                        }
                    }
                }

                // the name, above it while you point at it
                Rectangle {
                    // only the one right under the pointer: neighbours never stack names
                    visible: Config.dock.labels && dock.at >= 0 && Math.abs(dock.at - cell.mid) < root.slot / 2 && !drag.active && !cell.isAdd
                    x: root.across ? (parent.width - width) / 2 : (root.edge === "left" ? parent.width + root.icon * 0.6 : -width - root.icon * 0.6)
                    y: root.across ? (root.edge === "top" ? parent.height + root.icon * 0.6 : -height - root.icon * 0.6) : (parent.height - height) / 2
                    width: tip.implicitWidth + 18
                    height: 24
                    radius: 12
                    color: Colours.alpha(Colours.ink0, 0.88)

                    P5Text {
                        id: tip

                        anchors.centerIn: parent
                        text: cell.it ? root.label(cell.it).toUpperCase() : ""
                        color: "#ffffff"
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1
                    }
                }

                MouseArea {
                    id: hand

                    property point pressAt
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: drag.from === cell.index ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    preventStealing: true

                    onPressed: e => {
                        hand.pressAt = Qt.point(e.x, e.y);
                        pressPop.restart();
                    }
                    onPositionChanged: e => {
                        if (!hand.pressed || cell.isAdd || cell.isExtra || e.buttons !== Qt.LeftButton)
                            return;
                        const dx = e.x - hand.pressAt.x;
                        const dy = e.y - hand.pressAt.y;
                        if (drag.from < 0 && Math.hypot(dx, dy) > 8)
                            drag.begin(cell.index);
                        if (drag.from === cell.index)
                            drag.follow(root.across ? dx : dy, root.across ? dy : dx);
                    }
                    onReleased: e => {
                        if (drag.from === cell.index) {
                            drag.finish();
                            return;
                        }
                        if (cell.isAdd) {
                            adder.toggle();
                            return;
                        }
                        root.activate(cell.it, e.button === Qt.MiddleButton);
                    }
                    onCanceled: drag.cancel()
                }
            }
        }

        // the line between your items and the open apps not on the dock
        Rectangle {
            visible: root.extras.length > 0
            x: root.across ? 10 + root.items.length * root.slot + 6 : 14
            y: root.across ? 14 : 10 + root.items.length * root.slot + 6
            width: root.across ? 2 : parent.width - 28
            height: root.across ? parent.height - 28 : 2
            radius: 1
            color: Colours.alpha(Colours.ink, 0.18)
        }
    }

    // ── a drag: along the dock it reorders, off the dock it removes
    QtObject {
        id: drag

        property int from: -1
        property int to: -1
        property real dx: 0
        property real dy: 0
        property bool away: false
        readonly property bool active: drag.from >= 0

        function begin(i: int): void {
            drag.from = i;
            drag.to = i;
            Sfx.tick(0.7);
        }

        function follow(along: real, off: real): void {
            drag.dx = along;
            drag.dy = off;
            drag.away = Math.abs(off) > root.slot * 1.2;
            const t = Math.max(0, Math.min(root.items.length - 1, Math.round(drag.from + along / root.slot)));
            if (t !== drag.to) {
                drag.to = t;
                Sfx.tick(0.5);
            }
        }

        function finish(): void {
            const f = drag.from, t = drag.to, gone = drag.away;
            drag.cancel();
            if (gone) {
                puff.at(f);
                root.removeAt(f);
                Sfx.boing();
            } else {
                root.moveItem(f, t);
            }
        }

        function cancel(): void {
            drag.from = -1;
            drag.to = -1;
            drag.dx = 0;
            drag.dy = 0;
            drag.away = false;
        }
    }

    // the puff an item goes up in
    Item {
        id: puff

        property real t: 1

        function at(i: int): void {
            const base = 10 + i * root.slot + root.slot / 2;
            puff.x = root.across ? dock.x + base : dock.x + dock.width / 2;
            puff.y = root.across ? dock.y + dock.height / 2 : dock.y + base;
            poof.restart();
        }

        visible: puff.t < 1

        NumberAnimation {
            id: poof

            target: puff
            property: "t"
            from: 0
            to: 1
            duration: 520
            easing.type: Easing.OutCubic
        }

        Repeater {
            model: 8

            Rectangle {
                required property int index

                readonly property real a: index * Math.PI / 4
                width: 10 * (1 - puff.t) + 2
                height: width
                radius: width / 2
                x: Math.cos(a) * 30 * puff.t - width / 2
                y: Math.sin(a) * 30 * puff.t - height / 2
                color: Colours.alpha(Colours.ink, 0.5)
                opacity: 1 - puff.t
            }
        }
    }

    // ── + : adding something
    DockAdder {
        id: adder

        dock: root
        x: root.across ? Math.max(8, Math.min(root.width - width - 8, (root.width - width) / 2)) : (root.edge === "left" ? dock.x + dock.width + 12 : dock.x - width - 12)
        y: root.across ? (root.edge === "top" ? dock.y + dock.height + 12 : dock.y - height - 12) : Math.max(8, (root.height - height) / 2)
    }
}
