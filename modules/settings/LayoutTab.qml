//  VELVET  ·  modules/settings/LayoutTab.qml
//  The taskbar, laid out by hand.
//
//  One surface, three questions, in order:
//    1. WHERE — four pills, one per screen edge, plus thickness and margin
//       dials.
//    2. WHAT, IN WHICH ORDER — the bar as a numbered vertical list, one row
//       per module. Every row has its own ↑ ↓ ✕ buttons; drag&drop still
//       works — drag rows to reorder, drag one off the list to remove it,
//       drag in from the shelf below. The gap a drop will land in is drawn
//       while you drag: a drop should never be a guess.
//    3. HOW — click a module and its own settings appear beside it: the
//       clock's format next to the clock, not three levels down a list
//       somewhere else.
//
//  Everything commits immediately, and the real bar is drawn on top of this
//  overlay, so the thing you are editing is also the thing you are watching.
import qs.config
import qs.services
import qs.components
import QtQuick

FocusScope {
    id: root

    focus: true

    // ─────────────────────────────────────────────────────────────── the bar
    // Array.from: the list read back from config.json is list-like, not an
    // Array (Array.isArray said no, and the editor showed an empty bar).
    readonly property var strip: {
        const l = Config.bar.layout;
        return l && typeof l !== "string" && typeof l.length === "number" ? Array.from(l) : [];
    }
    readonly property bool vertical: Config.bar.position === "left" || Config.bar.position === "right"

    // What is not on the bar. Spacers and separators are pure layout, so they
    // stay available however many you have already used.
    readonly property var tray: {
        const out = [];
        for (let i = 0; i < Modules.all.length; i++) {
            const m = Modules.all[i];
            if (m.repeatable || root.strip.indexOf(m.id) === -1)
                out.push(m.id);
        }
        return out;
    }

    property int selected: -1          // index into the strip
    readonly property string selectedId: root.selected >= 0 && root.selected < root.strip.length ? root.strip[root.selected] : ""

    property int dragIndex: -1
    property string dragId: ""
    property bool fromTray: false
    property real dragX: 0
    property real dragY: 0
    property bool dragging: false
    property bool willRemove: false

    function commit(next: var): void {
        Config.set("bar.layout", next);
        // Write it to disk NOW. The adapter usually saves itself when it
        // notices the change, but an array swap has been known to slip past
        // that notice — and a taskbar that forgets your arrangement when the
        // shell restarts is a taskbar you cannot trust.
        Config.save();
        // Changes are written live; this just says so once the hand has
        // settled, so dragging a module does not spam the screen.
        savedToast.restart();
    }

    Timer {
        id: savedToast

        interval: 500
        onTriggered: Toast.ok("TASKBAR LAYOUT SAVED")
    }

    // ── where a drop will land, drawn as a live marker in the list
    //  Rows are 44px tall, 5px apart: one stride of 49px each. The marker is
    //  a bar drawn into the gap, in content coordinates so it stays put
    //  while the list scrolls.
    readonly property int dropSlot: {
        if (!root.dragging)
            return -1;
        const p = stripBox.mapFromItem(root, root.dragX, root.dragY);
        if (p.x < -20 || p.x > stripBox.width + 20)
            return -1;
        if (p.y < -20 || p.y > stripBox.height + 20)
            return -1;
        const y = p.y + stripList.contentY;
        return Math.max(0, Math.min(root.strip.length, Math.round((y + 2.5) / 49)));
    }

    readonly property real dropMarkY: {
        if (root.dropSlot < 0)
            return 0;
        return stripList.y + root.dropSlot * 49 - 2.5 - stripList.contentY - 1.5;
    }

    function move(from: int, to: int): void {
        if (from === to || from < 0 || from >= root.strip.length)
            return;
        const next = root.strip.slice();
        const [item] = next.splice(from, 1);
        next.splice(Math.max(0, Math.min(next.length, to)), 0, item);
        root.commit(next);
        root.selected = Math.max(0, Math.min(next.length - 1, to));
    }

    function insert(id: string, at: int): void {
        const next = root.strip.slice();
        next.splice(Math.max(0, Math.min(next.length, at)), 0, id);
        root.commit(next);
        root.selected = at;
        Sfx.select();
    }

    function removeAt(i: int): void {
        if (i < 0 || i >= root.strip.length)
            return;
        const next = root.strip.slice();
        next.splice(i, 1);
        root.commit(next);
        root.selected = Math.min(next.length - 1, i);
        Sfx.back();
    }

    function usePreset(p: var): void {
        root.commit(p.layout.slice());
        root.selected = -1;
        Sfx.select();
        Toast.ok(`LAYOUT: ${p.name}`);
    }

    // ══════════════════════════════════════════════════════ the left column
    Item {
        id: stage

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * 0.62

        // ─────────────────────────────────────────────────────── 1. WHERE
        P5Text {
            id: whereHead

            text: "WHERE THE BAR LIVES"
            color: Colours.alpha(Colours.inkDim, 0.7)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 3
            y: 6
        }

        Row {
            id: posPills

            anchors.left: parent.left
            anchors.top: whereHead.bottom
            anchors.topMargin: 10
            spacing: 8

            PosPill {
                label: "TOP"
                active: Config.bar.position === "top"
                onPicked: {
                    Config.set("bar.position", "top");
                    Sfx.select();
                }
            }
            PosPill {
                label: "RIGHT"
                active: Config.bar.position === "right"
                onPicked: {
                    Config.set("bar.position", "right");
                    Sfx.select();
                }
            }
            PosPill {
                label: "BOTTOM"
                active: Config.bar.position === "bottom"
                onPicked: {
                    Config.set("bar.position", "bottom");
                    Sfx.select();
                }
            }
            PosPill {
                label: "LEFT"
                active: Config.bar.position === "left"
                onPicked: {
                    Config.set("bar.position", "left");
                    Sfx.select();
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.top: posPills.bottom
            anchors.topMargin: 14
            spacing: 12

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "THICKNESS"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.6
            }

            SlashSlider {
                id: thickDial

                anchors.verticalCenter: parent.verticalCenter
                width: 200
                value: (Config.bar.thickness - 24) / 96
                onMoved: v => Config.set("bar.thickness", Math.max(24, Math.min(120, Math.round(24 + v * 96))))
                onReleased: Sfx.toggle()
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                display: true
                text: `${Config.bar.thickness} PX`
                color: Colours.accent
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
            }
        }

        Row {
            anchors.left: parent.left
            anchors.top: posPills.bottom
            anchors.topMargin: 44
            spacing: 12

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "MARGIN"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.6
            }

            SlashSlider {
                id: marginDial

                anchors.verticalCenter: parent.verticalCenter
                width: 200
                value: Config.bar.margin / 40
                onMoved: v => Config.set("bar.margin", Math.max(0, Math.min(40, Math.round(v * 40))))
                onReleased: Sfx.toggle()
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                display: true
                text: `${Config.bar.margin} PX`
                color: Colours.accent
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
            }
        }

        // ────────────────────────────────────────────────── 2. WHAT, IN ORDER
        P5Text {
            id: whatHead

            anchors.left: parent.left
            anchors.top: posPills.bottom
            anchors.topMargin: 78
            text: "ON THE BAR — DRAG TO REORDER"
            color: Colours.alpha(Colours.inkDim, 0.7)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 3
        }

        Item {
            id: stripBox

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.top: whatHead.bottom
            anchors.topMargin: 10
            height: Math.max(54, Math.min(278, root.strip.length * 49 + 2))

            Plate {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Colours.alpha(Colours.ink, root.dragging && !root.willRemove ? 0.09 : 0.05)
                border.width: 1
                border.color: root.willRemove ? Colours.alpha(Colours.danger, 0.55) : Colours.alpha(Colours.ink, 0.12)
                antialiasing: true

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            P5Text {
                anchors.centerIn: parent
                visible: root.strip.length === 0
                text: "DRAG A MODULE UP HERE FROM THE SHELF"
                color: Colours.alpha(Colours.inkDim, 0.6)
                font.pixelSize: Appearance.font.size.small
                tracking: 2
            }

            ListView {
                id: stripList

                anchors.fill: parent
                anchors.margins: 8
                spacing: 5
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: !root.dragging

                model: root.strip

                delegate: ModuleRow {
                    required property var modelData
                    required property int index

                    width: stripList.width
                    moduleId: modelData
                    slot: index
                }

                SmoothScroll {
                    view: stripList
                }
            }

            // The gap a drop will land in, drawn while you drag.
            Rectangle {
                id: dropMark

                width: stripList.width - 16
                height: 3
                x: stripList.x + 8
                y: root.dropMarkY
                radius: 1.5
                visible: root.dragging && !root.willRemove && root.dropSlot >= 0
                color: Colours.accent
                antialiasing: true
            }
        }

        P5Text {
            anchors.left: parent.left
            anchors.top: stripBox.bottom
            anchors.topMargin: 4
            width: stripBox.width
            text: "CLICK = ITS SETTINGS  ·  ↑ ↓ = MOVE  ·  ✕ = REMOVE  ·  OR DRAG AND DROP  ·  SHIFT + ← → = MOVE"
            color: Colours.alpha(Colours.inkDim, 0.55)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1
            elide: Text.ElideRight
        }

        // ───────────────────────────────────────────────────── 3. THE SHELF
        P5Text {
            id: addHead

            anchors.left: parent.left
            anchors.top: stripBox.bottom
            anchors.topMargin: 26
            text: "ADD FROM THE SHELF"
            color: Colours.alpha(Colours.inkDim, 0.7)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 3
        }

        Flow {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.top: addHead.bottom
            anchors.topMargin: 10
            spacing: 8

            Repeater {
                model: root.tray

                ModuleChip {
                    required property string modelData
                    required property int index

                    moduleId: modelData
                    slot: -1
                    placed: false
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════ the side
    Item {
        id: side

        anchors.left: stage.right
        anchors.leftMargin: 28
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // ── presets
        P5Text {
            id: presetLabel

            text: "START FROM"
            color: Colours.alpha(Colours.inkDim, 0.7)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 3
            y: 6
        }

        Column {
            id: presets

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: presetLabel.bottom
            anchors.topMargin: 10
            spacing: 6

            Repeater {
                model: Modules.presets

                Item {
                    id: preset

                    required property var modelData

                    width: presets.width
                    height: 44

                    readonly property bool current: JSON.stringify(modelData.layout) === JSON.stringify(root.strip)

                    Plate {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: preset.current ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, presetArea.containsMouse ? 0.14 : 0.06)
                        antialiasing: true

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -1

                        P5Text {
                            display: true
                            text: preset.modelData.name
                            color: preset.current ? Colours.on(Colours.accent) : Colours.ink
                            font.pixelSize: Appearance.font.size.normal
                        }

                        P5Text {
                            text: preset.modelData.sub
                            color: preset.current ? Colours.alpha(Colours.on(Colours.accent), 0.8) : Colours.inkDim
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1
                        }
                    }

                    MouseArea {
                        id: presetArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.usePreset(preset.modelData)
                    }
                }
            }
        }

        // ── the selected module's own settings
        Item {
            id: inspector

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: presets.bottom
            anchors.topMargin: 28
            anchors.bottom: parent.bottom

            readonly property var module: root.selectedId ? Modules.byId(root.selectedId) : null
            readonly property var rows: inspector.module ? Schema.rowsFor(inspector.module.keys) : []

            P5Text {
                id: insLabel

                text: inspector.module ? inspector.module.name : "PICK A MODULE"
                color: inspector.module ? Colours.ink : Colours.alpha(Colours.inkDim, 0.6)
                display: inspector.module !== null
                font.pixelSize: inspector.module ? Appearance.font.size.large : Appearance.font.size.tiny
                tracking: inspector.module ? 1 : 3
            }

            P5Text {
                id: insSub

                anchors.top: insLabel.bottom
                anchors.topMargin: 2
                width: inspector.width
                text: inspector.module ? inspector.module.sub : "ITS OWN SETTINGS APPEAR HERE"
                color: Colours.alpha(Colours.inkDim, 0.8)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.4
                wrapMode: Text.WordWrap
            }

            P5Text {
                anchors.top: insSub.bottom
                anchors.topMargin: 22
                visible: inspector.module !== null && inspector.rows.length === 0
                text: "NOTHING TO SET — IT JUST WORKS"
                color: Colours.alpha(Colours.inkDim, 0.5)
                font.pixelSize: Appearance.font.size.small
                tracking: 1.5
            }

            ListView {
                id: inspectorList

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: insSub.bottom
                anchors.topMargin: 18
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8

                model: inspector.rows
                spacing: Appearance.row.gap
                clip: true
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: SettingRowAny {
                    id: insRow

                    required property var modelData
                    // A slider or a choice opens its fold on a click.
                    property bool unfolded: false

                    width: ListView.view ? ListView.view.width : 0
                    item: modelData
                    selected: false
                    open: insRow.unfolded
                    hot: insHover.hovered

                    ListView.onPooled: insRow.unfolded = false

                    HoverHandler {
                        id: insHover
                    }

                    onActivate: {
                        if (modelData.kind === "slider" || modelData.kind === "choice") {
                            insRow.unfolded = !insRow.unfolded;
                            Sfx.select();
                            return;
                        }
                        if (modelData.kind === "toggle")
                            Bridge.set(modelData, !Bridge.get(modelData));
                        Sfx.toggle();
                    }
                }

                SmoothScroll {
                    view: inspectorList
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════ what you carry
    ModuleChip {
        id: ghost

        moduleId: root.dragId
        slot: -1
        placed: false
        visible: root.dragging
        floating: true
        x: root.dragX - width / 2
        y: root.dragY - height / 2
        z: 100
        opacity: root.willRemove ? 0.4 : 0.95
    }

    // ═══════════════════════════════════════════════════════ the list row
    component ModuleRow: Item {
        id: row

        property string moduleId: ""
        property int slot: -1

        readonly property var module: Modules.byId(row.moduleId)
        readonly property bool isSelected: row.slot === root.selected

        height: 44

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: row.isSelected ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, rowArea.containsMouse ? 0.14 : 0.06)
            border.width: 1
            border.color: row.isSelected ? Colours.ink : Colours.alpha(Colours.ink, 0.12)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        // The slot number, so the order reads at a glance.
        Plate {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            radius: Appearance.r(12)
            color: row.isSelected ? Colours.alpha(Colours.on(Colours.accent), 0.2) : Colours.alpha(Colours.ink, 0.08)
            antialiasing: true

            P5Text {
                anchors.centerIn: parent
                display: true
                text: `${row.slot + 1}`
                color: row.isSelected ? Colours.on(Colours.accent) : Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
            }
        }

        Icon {
            anchors.left: parent.left
            anchors.leftMargin: 42
            anchors.verticalCenter: parent.verticalCenter
            name: row.module?.icon ?? "extension"
            color: row.isSelected ? Colours.on(Colours.accent) : Colours.accent
            font.pixelSize: 17
        }

        P5Text {
            anchors.left: parent.left
            anchors.leftMargin: 68
            anchors.right: rowButtons.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: row.module?.name ?? row.moduleId
            color: row.isSelected ? Colours.on(Colours.accent) : Colours.ink
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        // ↑ ↓ ✕ — the same three things a drag can do, as visible buttons.
        Row {
            id: rowButtons
            z: 1 // above rowArea, or the buttons only select the row

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            IconButton {
                glyph: "keyboard_arrow_up"
                available: row.slot > 0
                onClicked: root.move(row.slot, row.slot - 1)
            }
            IconButton {
                glyph: "keyboard_arrow_down"
                available: row.slot < root.strip.length - 1
                onClicked: root.move(row.slot, row.slot + 1)
            }
            IconButton {
                glyph: "close"
                danger: true
                onClicked: root.removeAt(row.slot)
            }
        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            property bool moved: false
            property real pressX: 0
            property real pressY: 0

            onPressed: event => {
                moved = false;
                pressX = event.x;
                pressY = event.y;
            }

            onPositionChanged: event => {
                if (!pressed)
                    return;
                const g = row.mapToItem(root, event.x, event.y);
                if (!moved && Math.abs(event.x - pressX) + Math.abs(event.y - pressY) < 6)
                    return;

                if (!moved) {
                    moved = true;
                    root.dragging = true;
                    root.dragId = row.moduleId;
                    root.fromTray = false;
                    root.dragIndex = row.slot;
                }
                root.dragX = g.x;
                root.dragY = g.y;

                const inStrip = stripBox.mapFromItem(root, g.x, g.y);
                root.willRemove = inStrip.x < -20 || inStrip.x > stripBox.width + 20 || inStrip.y < -20 || inStrip.y > stripBox.height + 20;
            }

            onReleased: {
                if (!root.dragging) {
                    // A plain click: select it.
                    root.selected = row.slot;
                    Sfx.cursor();
                    return;
                }

                const target = root.dropSlot;

                if (root.willRemove) {
                    root.removeAt(row.slot);
                } else if (target >= 0) {
                    root.move(row.slot, target > row.slot ? target - 1 : target);
                    Sfx.select();
                }

                root.dragging = false;
                root.dragIndex = -1;
                root.willRemove = false;
            }

            onCanceled: {
                root.dragging = false;
                root.dragIndex = -1;
                root.willRemove = false;
            }
        }
    }

    // ═══════════════════════════════════════════════════════ the shelf chip
    component ModuleChip: Item {
        id: chip

        property string moduleId: ""
        property int slot: -1
        property bool placed: false
        property bool floating: false

        readonly property var module: Modules.byId(chip.moduleId)

        implicitWidth: chipRow.implicitWidth + 26
        implicitHeight: 46
        width: implicitWidth
        height: implicitHeight

        opacity: chip.floating ? 0.95 : 1

        scale: chipArea.pressed && !chip.floating ? 0.97 : (chipArea.containsMouse ? 1.03 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }
        }

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Colours.alpha(Colours.surfaceHigh, chipArea.containsMouse ? 1 : 0.75)
            border.width: 1
            border.color: Colours.alpha(Colours.ink, chipArea.containsMouse ? 0.3 : 0.12)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 7

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.module?.icon ?? "extension"
                color: Colours.accent
                font.pixelSize: 17
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(140, implicitWidth)
                display: true
                text: chip.module?.name ?? chip.moduleId
                color: Colours.ink
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            enabled: !chip.floating
            hoverEnabled: true
            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

            property bool moved: false
            property real pressX: 0
            property real pressY: 0

            onPressed: event => {
                moved = false;
                pressX = event.x;
                pressY = event.y;
            }

            onPositionChanged: event => {
                if (!pressed)
                    return;
                const g = chip.mapToItem(root, event.x, event.y);
                if (!moved && Math.abs(event.x - pressX) + Math.abs(event.y - pressY) < 6)
                    return;

                if (!moved) {
                    moved = true;
                    root.dragging = true;
                    root.dragId = chip.moduleId;
                    root.fromTray = true;
                    root.dragIndex = -1;
                }
                root.dragX = g.x;
                root.dragY = g.y;
                root.willRemove = false;
            }

            onReleased: {
                if (!root.dragging) {
                    // A plain click: add it at the end of the bar.
                    root.insert(chip.moduleId, root.strip.length);
                    return;
                }

                const target = root.dropSlot;
                if (target >= 0)
                    root.insert(chip.moduleId, target);

                root.dragging = false;
                root.dragIndex = -1;
                root.willRemove = false;
            }

            onCanceled: {
                root.dragging = false;
                root.dragIndex = -1;
                root.willRemove = false;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════ keyboard
    Keys.onPressed: event => {
        const n = root.strip.length;
        if (n === 0)
            return;

        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            if (event.modifiers & Qt.ShiftModifier)
                root.move(root.selected, Math.max(0, root.selected - 1));
            else
                root.selected = root.selected <= 0 ? n - 1 : root.selected - 1;
            Sfx.cursor();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            if (event.modifiers & Qt.ShiftModifier)
                root.move(root.selected, Math.min(n - 1, root.selected + 1));
            else
                root.selected = (root.selected + 1) % n;
            Sfx.cursor();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.removeAt(root.selected);
            event.accepted = true;
        }
    }

    // ═══════════════════════════════════════════════════ inline components
    component PosPill: Item {
        id: pill

        property string label: ""
        property bool active: false

        signal picked

        width: 92
        height: 36

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: pill.active ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, pillArea.containsMouse ? 0.16 : 0.06)
            border.width: 1
            border.color: pill.active ? Colours.ink : Colours.alpha(Colours.ink, 0.14)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        P5Text {
            anchors.centerIn: parent
            display: true
            text: pill.label
            color: pill.active ? Colours.on(Colours.accent) : Colours.ink
            font.pixelSize: Appearance.font.size.small
            tracking: 1.6
        }

        MouseArea {
            id: pillArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.picked()
        }
    }

    component IconButton: Item {
        id: ib

        property string glyph: "chevron_right"
        property bool danger: false
        // Not `enabled`: that is the Item's own property, and shadowing it
        // would quietly switch the whole button off.
        property bool available: true

        signal clicked

        width: 26
        height: 26
        opacity: ib.available ? 1 : 0.35

        Plate {
            anchors.fill: parent
            radius: Appearance.pill(height)
            color: Colours.alpha(ib.danger ? Colours.danger : Colours.ink, ibArea.containsMouse ? 0.3 : 0.1)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: ib.glyph
            color: ib.danger ? Colours.danger : Colours.ink
            font.pixelSize: 15
        }

        MouseArea {
            id: ibArea

            anchors.fill: parent
            hoverEnabled: true
            enabled: ib.available
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sfx.select();
                ib.clicked();
            }
        }
    }
}
