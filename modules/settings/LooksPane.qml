//  VELVET  ·  modules/settings/LooksPane.qml
//  SETTINGS → LOOKS: the look store. Every look of the shell on one shelf —
//  searchable, sorted, sorted into VIBES · CLASSIC · WINDOWS · YOURS — as
//  small cards that each draw the look in miniature. FEATURED turns through
//  the house favourites on top; a card opens the look's own page (it grows
//  out of the card), where it is put on, tuned, renamed or deleted.
//
//  Keyboard: arrows walk the shelf, Enter opens a look, Enter again puts it
//  on, Esc closes it, / searches, Backspace takes the look off again.
//  The looks themselves live in services/Presets.qml.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick
import QtQuick.Shapes

FocusScope {
    id: root

    focus: true

    // ── what the shelf shows
    property string cat: "all"              // all | vibes | classic | windows | yours
    property string sortBy: "featured"      // featured | az | recent
    property string query: ""
    // the card the keys are on (a look id)
    property string selected: Presets.applied !== "" ? Presets.applied : "velvet"

    // VELVET (the original) heads the shelf; then every look in its designed order.
    readonly property var everyLook: [Presets.original].concat(Presets.looks)

    function catOf(l: var): string {
        if (!l)
            return "classic";
        if (l.custom === true)
            return "yours";
        if (l.family === "windows")
            return "windows";
        if (l.vibe === true)
            return "vibes";
        return "classic";
    }

    readonly property var cats: [
        {
            id: "all",
            name: "ALL"
        },
        {
            id: "vibes",
            name: "VIBES"
        },
        {
            id: "classic",
            name: "CLASSIC"
        },
        {
            id: "windows",
            name: "WINDOWS"
        },
        {
            id: "yours",
            name: "YOURS"
        }
    ]

    readonly property var counts: {
        const c = {
            all: 0,
            vibes: 0,
            classic: 0,
            windows: 0,
            yours: 0
        };
        for (let i = 0; i < root.everyLook.length; i++) {
            c.all++;
            c[root.catOf(root.everyLook[i])]++;
        }
        return c;
    }

    function hay(l: var): string {
        return [Presets.nameOf(l), l.name ?? "", l.by ?? "", l.blurb ?? "", (l.parts ?? []).join(" "), l.mood ?? "", root.catOf(l), l.custom === true ? "mine my own saved" : ""].join(" ").toLowerCase();
    }

    readonly property var shown: {
        const words = root.query.toLowerCase().split(/\s+/).filter(w => w.length > 0);
        const list = [];
        for (let i = 0; i < root.everyLook.length; i++) {
            const l = root.everyLook[i];
            if (root.cat !== "all" && root.catOf(l) !== root.cat)
                continue;
            if (words.length > 0) {
                const h = root.hay(l);
                if (!words.every(w => h.indexOf(w) >= 0))
                    continue;
            }
            list.push({
                look: l,
                order: i
            });
        }
        if (root.sortBy === "az")
            list.sort((a, b) => Presets.nameOf(a.look).localeCompare(Presets.nameOf(b.look)) || a.order - b.order);
        else if (root.sortBy === "recent") {
            const w = Presets.wornAt ?? ({});
            // what you wear now first, then the most recently worn, then the rest as designed
            const at = l => Presets.applied === l.id || (Presets.applied === "" && l.id === "velvet") ? 1e15 : (w[l.id] ?? 0);
            list.sort((a, b) => at(b.look) - at(a.look) || a.order - b.order);
        }
        return list.map(e => e.look);
    }
    readonly property var shownIds: root.shown.map(l => l.id)

    // ── the shelf's grid
    readonly property real gap: 18
    readonly property int cols: Math.max(1, Math.floor((root.width + root.gap) / (Math.max(230, Math.min(300, root.width / 4.2)) + root.gap)))
    readonly property real tileW: Math.floor((root.width - root.gap * (root.cols - 1)) / root.cols)
    readonly property real artH: Math.round(root.tileW * 0.6)
    readonly property real tileH: root.artH + 74
    readonly property int rows: Math.ceil(root.shown.length / root.cols)

    function accentOf(l: var): color {
        return Presets.withColours || l?.original === true ? (l?.accent ?? Colours.accent) : Colours.accent;
    }
    // a look's accent as text on the cards: some looks are black on black
    function readable(c: color): color {
        return Colours.contrast(c, Colours.surfaceHigh) >= 2.6 ? c : Colours.inkDim;
    }

    // ── putting a look on
    function put(id: string): void {
        const look = Presets.find(id);
        if (!look)
            return;
        if (Presets.wearing(id) && look.original !== true) {
            Panels.openSettingsTabNamed("THIS LOOK");
            return;
        }
        if (Presets.apply(id)) {
            Sfx.select();
            Toast.ok(look.original === true ? "BACK TO VELVET — THE ORIGINAL" : `LOOK · ${Presets.nameOf(look)} IS ON — BACK TO YOUR OWN LOOK SITS ON TOP OF THIS PAGE`);
        }
    }

    function step(dx: int, dy: int): void {
        const ids = root.shownIds;
        if (ids.length === 0)
            return;
        let at = ids.indexOf(root.selected);
        if (at < 0)
            at = 0;
        else
            at = Math.max(0, Math.min(ids.length - 1, at + dx + dy * root.cols));
        root.selected = ids[at];
        Sfx.cursor();
        root.reveal(root.selected);
    }

    // scroll the shelf so a card is in sight
    function reveal(id: string): void {
        const at = root.shownIds.indexOf(id);
        if (at < 0)
            return;
        const top = shelf.y + Math.floor(at / root.cols) * (root.tileH + root.gap);
        const bottom = top + root.tileH;
        if (top < flick.contentY + 10)
            flickWheel.glideTo(Math.max(0, top - 10));
        else if (bottom > flick.contentY + flick.height - 10)
            flickWheel.glideTo(Math.min(flick.contentHeight - flick.height, bottom - flick.height + 10));
    }

    // ── the look's own page
    property string detailId: ""
    property var detailLook: null
    property rect fromRect: Qt.rect(0, 0, 0, 0)
    property real openK: 0
    readonly property bool detailOpen: root.detailId !== ""

    Behavior on openK {
        NumberAnimation {
            duration: Appearance.anim.slow
            easing.type: Easing.OutExpo
        }
    }

    function openDetail(id: string, from: var): void {
        const look = Presets.find(id);
        if (!look)
            return;
        root.selected = id;
        root.detailLook = look;
        root.fromRect = from ? Qt.rect(from.x, from.y, from.width, from.height) : Qt.rect(root.width / 2 - 60, root.height / 2 - 40, 120, 80);
        if (root.detailId === "") {
            root.openK = 0;
            Sfx.select();
        }
        root.detailId = id;
        root.openK = 1;
        detail.forceActiveFocus();
    }

    function closeDetail(): void {
        if (root.detailId === "")
            return;
        // fold back into its card if that card is still on the shelf
        const tile = root.tileOf(root.detailId);
        if (tile) {
            const p = tile.mapToItem(root, 0, 0);
            root.fromRect = Qt.rect(p.x, p.y, tile.width, tile.height);
        }
        root.detailId = "";
        root.openK = 0;
        Sfx.back();
        root.focusShelf();
    }

    function detailStep(d: int): void {
        const ids = root.shownIds;
        const at = ids.indexOf(root.detailId);
        if (at < 0 || ids.length < 2)
            return;
        const next = ids[(at + d + ids.length) % ids.length];
        root.detailLook = Presets.find(next);
        root.detailId = next;
        root.selected = next;
        Sfx.cursor();
    }

    // the keys back to the shelf: the page and the search field let go first
    // (a FocusScope hands its focus back to the child that had it last)
    function focusShelf(): void {
        detail.focus = false;
        search.blur();
        root.forceActiveFocus();
    }

    function tileOf(id: string): var {
        for (let i = 0; i < tiles.count; i++) {
            const t = tiles.itemAt(i);
            if (t && t.look && t.look.id === id && t.rank >= 0)
                return t;
        }
        return null;
    }

    Keys.onPressed: event => {
        if (root.detailOpen)
            return;
        if (event.key === Qt.Key_Right) {
            root.step(1, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            root.step(-1, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            root.step(0, 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            root.step(0, -1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const t = root.tileOf(root.selected);
            root.openDetail(root.selected, t ? t.mapToItem(root, 0, 0, t.width, t.height) : null);
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
            search.focusField();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backspace && Presets.canUndo) {
            Presets.undo();
            Sfx.back();
            event.accepted = true;
        }
    }

    // ═══════════════════════════════════════════════════════════ the shelf
    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: body.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.detailOpen

        Column {
            id: body

            width: flick.width
            spacing: 20

            // ── the head: the store's name, the search, saving your own
            Item {
                width: parent.width
                height: 64

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    P5Text {
                        display: true
                        text: "LOOKS"
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.title
                    }
                    P5Text {
                        text: `THE LOOK STORE · ${root.counts.all} LOOKS · ${root.counts.vibes} VIBES · ${root.counts.windows} WINDOWS · ${root.counts.classic} CLASSIC · ${root.counts.yours} YOURS`
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.small
                        tracking: 1
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    SearchBox {
                        id: search

                        width: Math.min(320, Math.max(200, root.width * 0.24))
                    }
                    BandButton {
                        strong: true
                        icon: "add"
                        text: "SAVE MINE AS A LOOK"
                        onClicked: {
                            const id = Presets.saveCurrent();
                            if (id !== "") {
                                Sfx.select();
                                root.cat = "yours";
                                root.selected = id;
                                Toast.ok("SAVED — YOUR LOOK IS UNDER YOURS");
                            }
                        }
                    }
                    ColourSwitch {}
                }
            }

            // ── the way back
            Plate {
                width: parent.width
                height: Presets.canUndo ? 58 : 0
                visible: height > 1
                radius: Appearance.r(18)
                color: Colours.alpha(Colours.accent, 0.14)
                border.width: 1
                border.color: Colours.alpha(Colours.accent, 0.4)
                clip: true
                antialiasing: true

                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "auto_awesome"
                        color: Colours.accent
                        font.pixelSize: 20
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const l = Presets.find(Presets.applied);
                            return l ? `WEARING ${Presets.nameOf(l)} · YOUR OWN SETUP IS SAVED` : "YOUR OWN SETUP IS SAVED";
                        }
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.normal
                        tracking: 1
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    BandButton {
                        text: "KEEP THIS LOOK"
                        onClicked: {
                            Presets.keep();
                            Sfx.select();
                        }
                    }
                    BandButton {
                        strong: true
                        text: "BACK TO MY OWN LOOK"
                        onClicked: {
                            Presets.undo();
                            Sfx.back();
                            Toast.ok("BACK TO YOUR OWN LOOK");
                        }
                    }
                }
            }

            // ── FEATURED: the house favourites, turning
            Hero {
                id: hero

                width: parent.width
                visible: root.query === "" && root.cat === "all"
                height: visible ? Math.round(Math.min(380, Math.max(260, root.width * 0.27))) : 0
            }

            // ── the shelf's tabs, the order, how many
            Item {
                width: parent.width
                height: 46

                Item {
                    id: tabsBox

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: tabRow.width
                    height: 40

                    // the plate glides from tab to tab
                    Slash {
                        id: tabPlate

                        readonly property var tab: tabRepeater.count > 0 ? tabRepeater.itemAt(Math.max(0, root.cats.findIndex(c => c.id === root.cat))) : null

                        x: tab ? tab.x : 0
                        width: tab ? tab.width : 0
                        height: parent.height
                        shear: 0
                        color: Colours.accent
                        borderColor: "transparent"

                        Behavior on x {
                            SpringAnimation {
                                spring: 4.5
                                damping: 0.36
                                epsilon: 0.25
                            }
                        }
                        Behavior on width {
                            SpringAnimation {
                                spring: 4.5
                                damping: 0.36
                                epsilon: 0.25
                            }
                        }
                    }

                    Row {
                        id: tabRow

                        height: parent.height
                        spacing: 4

                        Repeater {
                            id: tabRepeater

                            model: root.cats

                            Item {
                                id: tab

                                required property var modelData

                                readonly property bool on: root.cat === tab.modelData.id
                                readonly property int n: root.counts[tab.modelData.id] ?? 0

                                width: tabLabel.implicitWidth + tabCount.implicitWidth + 34
                                height: parent.height
                                opacity: tab.n === 0 && !tab.on ? 0.45 : 1

                                Plate {
                                    anchors.fill: parent
                                    radius: Appearance.r(12)
                                    color: tabHover.hovered && !tab.on ? Colours.alpha(Colours.ink, 0.08) : "transparent"

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Appearance.anim.fast
                                        }
                                    }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    P5Text {
                                        id: tabLabel

                                        anchors.verticalCenter: parent.verticalCenter
                                        text: tab.modelData.name
                                        color: tab.on ? Colours.on(Colours.accent) : Colours.ink
                                        font.pixelSize: Appearance.font.size.small
                                        tracking: 1.5

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: Appearance.anim.fast
                                            }
                                        }
                                    }
                                    P5Text {
                                        id: tabCount

                                        anchors.verticalCenter: parent.verticalCenter
                                        text: `${tab.n}`
                                        color: tab.on ? Colours.alpha(Colours.on(Colours.accent), 0.7) : Colours.inkDim
                                        font.pixelSize: Appearance.font.size.tiny
                                        tracking: 1
                                    }
                                }

                                HoverHandler {
                                    id: tabHover

                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: {
                                        if (root.cat !== tab.modelData.id) {
                                            root.cat = tab.modelData.id;
                                            Sfx.toggle();
                                        }
                                        root.focusShelf();
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.shown.length === 1 ? "1 LOOK" : `${root.shown.length} LOOKS`
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.5
                        rightPadding: 10
                    }

                    Repeater {
                        model: [
                            {
                                id: "featured",
                                name: "AS DESIGNED"
                            },
                            {
                                id: "recent",
                                name: "RECENT"
                            },
                            {
                                id: "az",
                                name: "A – Z"
                            }
                        ]

                        Plate {
                            id: sortChip

                            required property var modelData
                            readonly property bool on: root.sortBy === sortChip.modelData.id

                            width: sortText.implicitWidth + 22
                            height: 30
                            radius: Appearance.r(15)
                            color: sortChip.on ? Colours.alpha(Colours.accent, 0.2) : (sortHover.hovered ? Colours.alpha(Colours.ink, 0.08) : "transparent")
                            border.width: 1
                            border.color: sortChip.on ? Colours.alpha(Colours.accent, 0.55) : Colours.alpha(Colours.ink, 0.1)
                            antialiasing: true

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }

                            P5Text {
                                id: sortText

                                anchors.centerIn: parent
                                text: sortChip.modelData.name
                                color: sortChip.on ? Colours.accentInk : Colours.inkDim
                                font.pixelSize: Appearance.font.size.tiny
                                tracking: 1.5
                            }

                            HoverHandler {
                                id: sortHover

                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: {
                                    root.sortBy = sortChip.modelData.id;
                                    Sfx.toggle();
                                    root.focusShelf();
                                }
                            }
                        }
                    }
                }
            }

            // ── the cards: every look, gliding to its place when the shelf changes
            Item {
                id: shelf

                width: parent.width
                height: root.shown.length > 0 ? root.rows * (root.tileH + root.gap) - root.gap : 140

                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.anim.slow
                        easing.type: Easing.OutCubic
                    }
                }

                Repeater {
                    id: tiles

                    model: root.everyLook

                    LookTile {
                        required property var modelData

                        look: modelData
                    }
                }

                // nothing matches
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    opacity: root.shown.length === 0 ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.normal
                        }
                    }

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: "search_off"
                        color: Colours.inkDim
                        font.pixelSize: 34
                    }
                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.query !== "" ? `NO LOOK SAYS “${root.query.toUpperCase()}”` : "NOTHING HERE YET — SAVE MINE AS A LOOK PUTS YOUR SETUP ON THIS SHELF"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.small
                        tracking: 1.5
                    }
                }
            }

            P5Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "A LOOK ONLY WRITES ORDINARY SETTINGS — THE BAR, THE LOCK, THE TYPE, THE MUSIC ALONG THE EDGE. EVERY LOOK KEEPS ITS OWN DESK, WIDGETS AND LOCK LAYOUT PER WALLPAPER. FROM A TERMINAL: qs -c velvet ipc call looks apply sakura"
                color: Colours.alpha(Colours.inkDim, 0.8)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
            }
        }

        SmoothScroll {
            id: flickWheel

            view: flick
        }
    }

    // ═══════════════════════════════════════════════════════════ the page
    //  The look's own page grows out of its card and folds back into it.
    Item {
        id: detail

        anchors.fill: parent
        visible: root.openK > 0.002
        z: 50

        Keys.onPressed: event => {
            if (!root.detailOpen)
                return;
            if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                root.closeDetail();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.detailLook)
                    root.put(root.detailLook.id);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.detailStep(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                root.detailStep(-1);
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.5 * root.openK)

            // a click beside the page closes it
            TapHandler {
                enabled: root.detailOpen
                onTapped: eventPoint => {
                    const p = eventPoint.position;
                    if (p.x < sheet.x || p.x > sheet.x + sheet.width || p.y < sheet.y || p.y > sheet.y + sheet.height)
                        root.closeDetail();
                }
            }
        }

        DetailSheet {
            id: sheet

            readonly property real tw: Math.min(1180, root.width - 40)
            readonly property real extra: root.detailLook?.family === "windows" ? 96 : 0
            readonly property real aw: Math.max(240, Math.min(Math.round(tw * 0.58), Math.round((root.height - 72 - extra) * 1.6)))
            readonly property real th: Math.min(root.height - 40, Math.max(440, Math.round(aw / 1.6) + 32 + extra, sheet.wordsH + 150))
            readonly property real tx: (root.width - tw) / 2
            readonly property real ty: (root.height - th) / 2
            readonly property real k: Math.max(0, Math.min(1, root.openK))

            look: root.detailLook
            artW: aw
            x: root.fromRect.x + (tx - root.fromRect.x) * k
            y: root.fromRect.y + (ty - root.fromRect.y) * k
            width: Math.max(1, root.fromRect.width + (tw - root.fromRect.width) * k)
            height: Math.max(1, root.fromRect.height + (th - root.fromRect.height) * k)
        }
    }

    // ═══════════════════════════════════════════════════════════ parts
    component BandButton: Plate {
        id: bb

        property string text: ""
        property string icon: ""
        property bool strong: false
        property bool danger: false

        signal clicked

        width: bbRow.implicitWidth + 30
        height: 38
        radius: Appearance.r(19)
        color: bb.danger ? (bbHover.hovered ? Colours.danger : Colours.alpha(Colours.danger, 0.2)) : (bb.strong ? (bbHover.hovered ? Colours.accentHot : Colours.accent) : (bbHover.hovered ? Colours.alpha(Colours.ink, 0.12) : Colours.alpha(Colours.ink, 0.05)))
        border.width: bb.strong || bb.danger ? 0 : 1
        border.color: Colours.alpha(Colours.ink, 0.14)
        scale: bbTap.pressed ? 0.94 : (bbHover.hovered ? 1.03 : 1)
        antialiasing: true

        Behavior on scale {
            SpringAnimation {
                spring: 6
                damping: 0.38
                epsilon: 0.002
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        Row {
            id: bbRow

            anchors.centerIn: parent
            spacing: 7

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: bb.icon !== ""
                name: bb.icon
                color: bb.strong || bb.danger && bbHover.hovered ? Colours.on(bb.danger ? Colours.danger : Colours.accent) : (bb.danger ? Colours.danger : Colours.ink)
                font.pixelSize: 17
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bb.text
                color: bb.strong || bb.danger && bbHover.hovered ? Colours.on(bb.danger ? Colours.danger : Colours.accent) : (bb.danger ? Colours.danger : Colours.ink)
                font.pixelSize: Appearance.font.size.small
                tracking: 1
            }
        }

        HoverHandler {
            id: bbHover

            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: bbTap

            gesturePolicy: TapHandler.WithinBounds
            onTapped: bb.clicked()
        }
    }

    component ColourSwitch: Plate {
        id: cs

        width: csRow.implicitWidth + 26
        height: 38
        radius: Appearance.r(19)
        color: csHover.hovered ? Colours.alpha(Colours.ink, 0.1) : Colours.alpha(Colours.ink, 0.05)
        border.width: 1
        border.color: Colours.alpha(Colours.ink, 0.12)
        antialiasing: true

        Row {
            id: csRow

            anchors.centerIn: parent
            spacing: 9

            Plate {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 19
                radius: Appearance.r(9.5)
                color: Presets.withColours ? Colours.accent : Colours.alpha(Colours.ink, 0.18)

                Plate {
                    x: Presets.withColours ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13
                    height: 13
                    radius: Appearance.r(6.5)
                    color: Presets.withColours ? Colours.on(Colours.accent) : Colours.ink

                    Behavior on x {
                        SpringAnimation {
                            spring: 5
                            damping: 0.4
                            epsilon: 0.2
                        }
                    }
                }
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Presets.withColours ? "LOOK COLOURS" : "MY COLOURS"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.small
                tracking: 1
            }
        }

        HoverHandler {
            id: csHover

            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: {
                Presets.withColours = !Presets.withColours;
                Presets.persist();
                Sfx.toggle();
            }
        }
    }

    component SearchBox: Plate {
        id: sb

        function focusField(): void {
            field.forceActiveFocus();
            field.selectAll();
        }
        function blur(): void {
            field.focus = false;
        }

        height: 38
        radius: Appearance.r(19)
        color: field.activeFocus ? Colours.alpha(Colours.ink, 0.1) : (sbHover.hovered ? Colours.alpha(Colours.ink, 0.08) : Colours.alpha(Colours.ink, 0.05))
        border.width: field.activeFocus ? 2 : 1
        border.color: field.activeFocus ? Colours.alpha(Colours.accent, 0.8) : Colours.alpha(Colours.ink, 0.12)
        antialiasing: true

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        Icon {
            id: sbIcon

            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            color: field.activeFocus ? Colours.accent : Colours.inkDim
            font.pixelSize: 18
        }

        TextInput {
            id: field

            anchors.left: sbIcon.right
            anchors.leftMargin: 8
            anchors.right: clear.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            color: Colours.ink
            selectionColor: Colours.alpha(Colours.accent, 0.5)
            selectedTextColor: Colours.ink
            font.family: Appearance.fontFamily.body
            font.pixelSize: Appearance.font.size.normal
            clip: true
            onTextChanged: root.query = field.text

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (field.text !== "")
                        field.text = "";
                    else
                        root.focusShelf();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.shownIds.length > 0 && root.shownIds.indexOf(root.selected) < 0)
                        root.selected = root.shownIds[0];
                    root.focusShelf();
                    event.accepted = true;
                }
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text === ""
                text: field.activeFocus ? "NAME, VIBE, PART …" : "SEARCH LOOKS  ·  /"
                color: Colours.alpha(Colours.inkDim, 0.8)
                font.pixelSize: Appearance.font.size.small
                tracking: 1
            }
        }

        Icon {
            id: clear

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: field.text !== ""
            width: visible ? implicitWidth : 0
            name: "close"
            color: clearHover.hovered ? Colours.ink : Colours.inkDim
            font.pixelSize: 16

            HoverHandler {
                id: clearHover

                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: field.text = ""
            }
        }

        HoverHandler {
            id: sbHover

            cursorShape: Qt.IBeamCursor
        }
        TapHandler {
            onTapped: sb.focusField()
        }
    }

    // ── one card on the shelf
    component LookTile: Item {
        id: tile

        property var look: ({})

        readonly property int rank: root.shownIds.indexOf(tile.look?.id ?? "")
        property int lastRank: 0
        readonly property int slotAt: tile.rank >= 0 ? tile.rank : tile.lastRank
        readonly property bool chosen: root.selected === (tile.look?.id ?? "")
        readonly property bool on: Config.loaded && (tile.look?.original === true ? Presets.applied === "" || Presets.applied === "velvet" : Presets.applied === tile.look?.id)
        readonly property bool hot: tileHover.hovered && !root.detailOpen
        readonly property color accent: root.accentOf(tile.look)
        property bool placed: false
        property bool present: false

        onRankChanged: {
            if (tile.rank >= 0) {
                tile.lastRank = tile.rank;
                arrive.interval = Math.min(360, 40 + tile.rank * 22);
                arrive.restart();
            } else {
                arrive.stop();
                tile.present = false;
            }
        }
        Component.onCompleted: {
            if (tile.rank >= 0)
                tile.lastRank = tile.rank;
            arrive.interval = Math.min(420, 60 + Math.max(0, tile.rank) * 26);
            if (tile.rank >= 0)
                arrive.restart();
            settle.restart();
        }

        Timer {
            id: arrive

            onTriggered: tile.present = tile.rank >= 0
        }
        Timer {
            id: settle

            interval: 30
            onTriggered: tile.placed = true
        }

        width: root.tileW
        height: root.tileH
        x: (tile.slotAt % root.cols) * (root.tileW + root.gap)
        y: Math.floor(tile.slotAt / root.cols) * (root.tileH + root.gap)
        z: tile.hot ? 2 : 1
        enabled: tile.rank >= 0
        opacity: tile.present ? 1 : 0
        visible: opacity > 0.01
        scale: (tile.present ? 1 : 0.9) * (tilePress.pressed ? 0.975 : 1)
        transformOrigin: Item.Center

        Behavior on x {
            enabled: tile.placed
            NumberAnimation {
                duration: Appearance.anim.slow
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: tile.placed
            NumberAnimation {
                duration: Appearance.anim.slow
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: tile.present ? Appearance.anim.normal : Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            SpringAnimation {
                spring: 5
                damping: 0.4
                epsilon: 0.002
            }
        }

        // how far the card has come up to meet the pointer
        property real lift: tile.hot ? 1 : 0
        Behavior on lift {
            SpringAnimation {
                spring: 4.4
                damping: 0.38
                epsilon: 0.004
            }
        }

        // the shadow under a lifted card
        Rectangle {
            x: 6
            width: parent.width - 12
            y: 14 + 6 * tile.lift
            height: parent.height - 10
            radius: Appearance.r(22)
            color: Qt.rgba(0, 0, 0, 0.32 * tile.lift)
            visible: tile.lift > 0.02
        }

        Item {
            id: face

            width: parent.width
            height: parent.height
            y: -6 * tile.lift

            Slash {
                anchors.fill: parent
                shear: 0
                color: tile.hot ? Colours.alpha(Colours.surfaceHigh, 0.98) : Colours.alpha(Colours.surfaceHigh, 0.86)
                borderColor: tile.on ? Colours.accent : (tile.chosen || tile.hot ? Colours.alpha(tile.accent, 0.75) : Colours.alpha(Colours.ink, 0.08))
                borderWidth: tile.on || tile.chosen || tile.hot ? 2 : 1
            }

            // the look, in miniature
            Item {
                id: artBox

                x: 8
                y: 8
                width: parent.width - 16
                height: root.artH - 8
                clip: true

                LookArt {
                    width: artBox.width
                    height: artBox.height
                    look: tile.look
                    scale: 1 + 0.05 * tile.lift
                    transformOrigin: Item.Center
                }

                // the actions rise out of the picture under the pointer
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 56
                    opacity: tile.lift
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(0, 0, 0, 0.55)
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    y: parent.height - 42 + 18 * (1 - tile.lift)
                    opacity: tile.lift
                    // only what you can see takes a click
                    visible: tile.lift > 0.05
                    spacing: 6

                    TileButton {
                        icon: "open_in_full"
                        onClicked: root.openDetail(tile.look.id, tile.mapToItem(root, 0, 0, tile.width, tile.height))
                    }
                    TileButton {
                        strong: true
                        text: tile.on ? (tile.look?.original === true ? "ON" : "TUNE") : "PUT ON"
                        onClicked: {
                            root.selected = tile.look.id;
                            if (!(tile.on && tile.look?.original === true))
                                root.put(tile.look.id);
                        }
                    }
                }

                // ON · YOURS
                Row {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 8
                    spacing: 5

                    Badge {
                        visible: tile.on
                        text: "ON"
                        fill: Colours.accent
                        ink: Colours.on(Colours.accent)
                    }
                    Badge {
                        visible: tile.look?.custom === true
                        text: "YOURS"
                        fill: Colours.alpha(Colours.surface, 0.85)
                        ink: Colours.ink
                    }
                    Badge {
                        visible: tile.look?.original === true
                        text: "THE ORIGINAL"
                        fill: Colours.alpha(Colours.surface, 0.85)
                        ink: Colours.ink
                    }
                }
            }

            // the words
            Column {
                x: 16
                y: root.artH + 10
                width: parent.width - 32
                spacing: 3

                Row {
                    width: parent.width
                    spacing: 8

                    P5Text {
                        id: tileName

                        width: Math.min(implicitWidth, parent.width - kind.width - 8)
                        display: true
                        text: Presets.nameOf(tile.look)
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.large
                        elide: Text.ElideRight
                    }
                    P5Text {
                        id: kind

                        anchors.baseline: tileName.baseline
                        text: ({
                                vibes: "VIBE",
                                classic: tile.look?.original === true ? "HOUSE" : "CLASSIC",
                                windows: "WINDOWS",
                                yours: "MINE"
                            })[root.catOf(tile.look)] ?? ""
                        color: root.readable(tile.accent)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.5
                    }
                }
                Text {
                    width: parent.width
                    text: tile.look?.by ?? ""
                    color: Colours.inkDim
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
                // the look's colours, as a strip of swatches
                Row {
                    spacing: 4
                    topPadding: 4

                    Repeater {
                        model: {
                            const l = tile.look ?? ({});
                            const s = l.swatch ?? ({});
                            const out = [tile.accent];
                            if (s.accent2)
                                out.push(s.accent2);
                            if (s.surface)
                                out.push(s.surface);
                            if (s.paper)
                                out.push(s.paper);
                            if (s.ink)
                                out.push(s.ink);
                            return out.slice(0, 5);
                        }

                        Rectangle {
                            required property var modelData

                            width: 14
                            height: 6
                            radius: 3
                            color: modelData
                            border.width: 1
                            border.color: Colours.alpha(Colours.ink, 0.15)
                        }
                    }
                }
            }
        }

        HoverHandler {
            id: tileHover

            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: tilePress

            onTapped: {
                root.openDetail(tile.look.id, tile.mapToItem(root, 0, 0, tile.width, tile.height));
            }
            onDoubleTapped: root.put(tile.look.id)
        }
    }

    component Badge: Plate {
        id: badge

        property string text: ""
        property color fill: Colours.accent
        property color ink: Colours.on(Colours.accent)

        width: badgeText.implicitWidth + 16
        height: 22
        radius: Appearance.r(11)
        color: badge.fill
        antialiasing: true

        P5Text {
            id: badgeText

            anchors.centerIn: parent
            text: badge.text
            color: badge.ink
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.5
        }
    }

    component TileButton: Plate {
        id: tb

        property string text: ""
        property string icon: ""
        property bool strong: false

        signal clicked

        width: tb.text !== "" ? tbText.implicitWidth + 24 : 32
        height: 32
        radius: Appearance.r(16)
        color: tb.strong ? (tbHover.hovered ? Colours.accentHot : Colours.accent) : (tbHover.hovered ? Colours.alpha(Colours.surface, 0.98) : Colours.alpha(Colours.surface, 0.82))
        scale: tbTap.pressed ? 0.9 : (tbHover.hovered ? 1.06 : 1)
        antialiasing: true

        Behavior on scale {
            SpringAnimation {
                spring: 7
                damping: 0.4
                epsilon: 0.002
            }
        }

        P5Text {
            id: tbText

            anchors.centerIn: parent
            visible: tb.text !== ""
            text: tb.text
            color: tb.strong ? Colours.on(Colours.accent) : Colours.ink
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.5
        }
        Icon {
            anchors.centerIn: parent
            visible: tb.text === ""
            name: tb.icon
            color: Colours.ink
            font.pixelSize: 16
        }

        HoverHandler {
            id: tbHover

            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: tbTap

            // the card under the button must not take the same click
            gesturePolicy: TapHandler.WithinBounds
            onTapped: tb.clicked()
        }
    }

    // ── FEATURED: one big card, turning every few seconds
    component Hero: Item {
        id: heroRoot

        readonly property var picks: ["velvet", "glass", "sakura", "cyber", "clay", "win11", "ember", "arcade", "neu"].map(id => Presets.find(id)).filter(l => l)
        property int at: 0
        property int prev: -1
        readonly property var look: heroRoot.picks.length > 0 ? heroRoot.picks[Math.min(heroRoot.at, heroRoot.picks.length - 1)] : null
        readonly property bool held: heroHover.hovered || root.detailOpen || !root.visible || !heroRoot.visible
        property real progress: 0

        function go(i: int): void {
            const n = heroRoot.picks.length;
            if (n === 0)
                return;
            heroRoot.prev = heroRoot.at;
            heroRoot.at = (i + n) % n;
            heroRoot.progress = 0;
            turn.restart();
        }

        clip: true

        NumberAnimation {
            id: turn

            target: heroRoot
            property: "progress"
            from: 0
            to: 1
            duration: 7000
            running: heroRoot.picks.length > 1
            paused: heroRoot.held
            onFinished: heroRoot.go(heroRoot.at + 1)
        }

        Slash {
            anchors.fill: parent
            shear: 0
            color: Colours.alpha(Colours.surfaceHigh, 0.9)
            borderColor: Colours.alpha(root.accentOf(heroRoot.look), 0.45)
            borderWidth: 1
        }

        Repeater {
            model: heroRoot.picks

            Item {
                id: slide

                required property var modelData
                required property int index

                readonly property bool current: slide.index === heroRoot.at
                readonly property bool wanted: slide.current || slide.index === heroRoot.prev

                anchors.fill: parent
                opacity: slide.current ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.slow
                        easing.type: Easing.InOutCubic
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: slide.wanted

                    sourceComponent: Item {
                        // the picture, drifting a little while it shows
                        Item {
                            id: heroArt

                            x: 14
                            y: 14
                            width: Math.round((heroRoot.height - 28) * 1.66)
                            height: heroRoot.height - 28
                            clip: true

                            LookArt {
                                width: heroArt.width
                                height: heroArt.height
                                look: slide.modelData
                                scale: 1.02 + 0.03 * heroRoot.progress
                                x: (slide.current ? 0 : -24)
                                transformOrigin: Item.Center

                                Behavior on x {
                                    NumberAnimation {
                                        duration: Appearance.anim.slow
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        Column {
                            anchors.left: heroArt.right
                            anchors.leftMargin: 30
                            anchors.right: parent.right
                            anchors.rightMargin: 30
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10
                            transform: Translate {
                                x: slide.current ? 0 : 36

                                Behavior on x {
                                    NumberAnimation {
                                        duration: Appearance.anim.slow
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            P5Text {
                                text: `FEATURED · ${({
                                        vibes: "VIBE",
                                        classic: slide.modelData.original === true ? "THE ORIGINAL" : "CLASSIC",
                                        windows: "WINDOWS",
                                        yours: "YOURS"
                                    })[root.catOf(slide.modelData)] ?? ""}`
                                color: root.readable(root.accentOf(slide.modelData))
                                font.pixelSize: Appearance.font.size.small
                                tracking: 2.5
                            }
                            P5Text {
                                width: parent.width
                                display: true
                                text: Presets.nameOf(slide.modelData)
                                color: Colours.ink
                                font.pixelSize: Math.round(Appearance.font.size.title * 1.25)
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                text: slide.modelData.blurb ?? ""
                                color: Colours.inkDim
                                font.family: Appearance.fontFamily.body
                                font.pixelSize: Appearance.font.size.normal
                                lineHeight: 1.15
                            }
                            Flow {
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: (slide.modelData.parts ?? []).slice(0, 5)

                                    Plate {
                                        required property string modelData

                                        width: heroPart.implicitWidth + 16
                                        height: 24
                                        radius: Appearance.r(12)
                                        color: Colours.alpha(Colours.ink, 0.06)
                                        border.width: 1
                                        border.color: Colours.alpha(Colours.ink, 0.1)

                                        P5Text {
                                            id: heroPart

                                            anchors.centerIn: parent
                                            text: modelData
                                            color: Colours.alpha(Colours.ink, 0.8)
                                            font.pixelSize: Appearance.font.size.tiny
                                            tracking: 1
                                        }
                                    }
                                }
                            }
                            Item {
                                width: 1
                                height: 4
                            }
                            Row {
                                spacing: 10

                                BandButton {
                                    strong: true
                                    readonly property bool wearing: Config.loaded && (slide.modelData.original === true ? Presets.applied === "" || Presets.applied === "velvet" : Presets.applied === slide.modelData.id)
                                    text: wearing ? (slide.modelData.original === true ? "YOU WEAR IT" : "TUNE THIS LOOK") : (slide.modelData.original === true ? "BACK TO VELVET" : "PUT IT ON")
                                    onClicked: {
                                        root.selected = slide.modelData.id;
                                        if (!(wearing && slide.modelData.original === true))
                                            root.put(slide.modelData.id);
                                    }
                                }
                                BandButton {
                                    icon: "open_in_full"
                                    text: "SEE IT"
                                    onClicked: {
                                        const p = heroArt.mapToItem(root, 0, 0);
                                        root.openDetail(slide.modelData.id, Qt.rect(p.x, p.y, heroArt.width, heroArt.height));
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // dots, and the time until the next one
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            spacing: 6

            Repeater {
                model: heroRoot.picks.length

                Item {
                    id: dot

                    required property int index
                    readonly property bool current: dot.index === heroRoot.at

                    width: dot.current ? 34 : 9
                    height: 9

                    Behavior on width {
                        SpringAnimation {
                            spring: 4.5
                            damping: 0.4
                            epsilon: 0.25
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Colours.alpha(Colours.ink, dot.current ? 0.2 : (dotHover.hovered ? 0.45 : 0.25))
                    }
                    Rectangle {
                        visible: dot.current
                        width: parent.width * heroRoot.progress
                        height: parent.height
                        radius: height / 2
                        color: root.accentOf(heroRoot.look)
                    }

                    HoverHandler {
                        id: dotHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: heroRoot.go(dot.index)
                    }
                }
            }
        }

        // ‹ › on the edges, when the pointer is there
        Repeater {
            model: [-1, 1]

            Plate {
                id: arrow

                required property int modelData

                x: arrow.modelData < 0 ? 24 : parent.width - width - 24
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: Appearance.r(20)
                color: arrowHover.hovered ? Colours.alpha(Colours.surface, 0.98) : Colours.alpha(Colours.surface, 0.8)
                opacity: heroHover.hovered ? 1 : 0
                visible: opacity > 0.01 && (arrow.modelData > 0 || true)
                scale: arrowTap.pressed ? 0.9 : 1
                antialiasing: true

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
                Behavior on scale {
                    SpringAnimation {
                        spring: 7
                        damping: 0.4
                        epsilon: 0.002
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: arrow.modelData < 0 ? "chevron_left" : "chevron_right"
                    color: Colours.ink
                    font.pixelSize: 24
                }

                HoverHandler {
                    id: arrowHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    id: arrowTap

                    onTapped: {
                        heroRoot.go(heroRoot.at + arrow.modelData);
                        Sfx.cursor();
                    }
                }
            }
        }

        HoverHandler {
            id: heroHover
        }
    }

    // ── the look's page
    component DetailSheet: Item {
        id: ds

        property var look: null
        property real artW: 600
        readonly property real wordsH: dsCol.height

        readonly property bool on: Config.loaded && ds.look !== null && (ds.look.original === true ? Presets.applied === "" || Presets.applied === "velvet" : Presets.applied === ds.look.id)
        readonly property color accent: root.accentOf(ds.look)
        // the words fade in once the page has nearly grown to size
        readonly property real inside: Math.max(0, Math.min(1, (root.openK - 0.55) / 0.45))
        property bool armed: false

        onLookChanged: ds.armed = false

        Slash {
            anchors.fill: parent
            shear: 0
            color: Colours.alpha(Colours.surfaceHigh, 1)
            borderColor: ds.on ? Colours.accent : Colours.alpha(ds.accent, 0.5)
            borderWidth: 2
        }

        Item {
            id: dsArt

            x: 16
            y: 16
            // the page grows out of a card: the picture keeps its shape all the
            // way. Its width follows the page's WIDTH only — the page's height
            // follows the words beside it, and the words follow this width.
            width: Math.round(Math.min(ds.artW, Math.max(1, ds.width - 32)))
            height: Math.round(dsArt.width / 1.6)
            clip: true

            LookArt {
                width: dsArt.width
                height: dsArt.height
                look: ds.look
            }

            Badge {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 12
                visible: ds.on
                text: "YOU WEAR IT"
                fill: Colours.accent
                ink: Colours.on(Colours.accent)
            }
        }

        // the five editions of the WINDOWS look, under its picture
        Row {
            anchors.left: dsArt.left
            anchors.top: dsArt.bottom
            anchors.topMargin: 12
            spacing: 8
            visible: ds.look?.family === "windows"
            opacity: ds.inside

            Repeater {
                model: Presets.winLooks

                Item {
                    id: ed

                    required property var modelData
                    readonly property bool here: ds.look?.id === ed.modelData.id

                    width: (dsArt.width - 32) / 5
                    height: 76

                    Item {
                        width: parent.width
                        height: 54
                        clip: true

                        WinMini {
                            anchors.fill: parent
                            v: ed.modelData.version ?? "11"
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: ed.here ? 2 : 1
                            border.color: ed.here ? Colours.accent : Colours.alpha(Colours.ink, 0.15)
                        }
                    }
                    P5Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(ed.modelData.name ?? "").replace("WINDOWS ", "")
                        color: ed.here ? Colours.accentInk : Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.5
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: {
                            root.detailLook = Presets.find(ed.modelData.id);
                            root.detailId = ed.modelData.id;
                            root.selected = ed.modelData.id;
                            Sfx.cursor();
                        }
                    }
                }
            }
        }

        Flickable {
            id: dsWords

            anchors.left: dsArt.right
            anchors.leftMargin: 28
            anchors.right: parent.right
            anchors.rightMargin: 26
            anchors.top: parent.top
            anchors.topMargin: 58
            anchors.bottom: dsActions.top
            anchors.bottomMargin: 14
            contentWidth: width
            contentHeight: dsCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            opacity: ds.inside

            Column {
                id: dsCol

                width: dsWords.width
                spacing: 10

                P5Text {
                    text: `${({
                            vibes: "VIBE",
                            classic: ds.look?.original === true ? "THE ORIGINAL" : "CLASSIC LOOK",
                            windows: "WINDOWS",
                            yours: "YOUR OWN LOOK"
                        })[root.catOf(ds.look)] ?? ""} · ${String(ds.look?.by ?? "").toUpperCase()}`
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: root.readable(ds.accent)
                    font.pixelSize: Appearance.font.size.small
                    tracking: 2
                }
                LookName {
                    look: ds.look ?? ({})
                    size: Math.round(Appearance.font.size.title * 1.1)
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: ds.look?.blurb ?? ""
                    color: Colours.inkDim
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: Appearance.font.size.normal
                    lineHeight: 1.2
                }
                Item {
                    width: 1
                    height: 4
                }
                P5Text {
                    text: "WHAT IT CHANGES"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.small
                    tracking: 2
                }
                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: ds.look?.parts ?? []

                        Plate {
                            required property string modelData

                            width: dsPart.implicitWidth + 18
                            height: 26
                            radius: Appearance.r(13)
                            color: Colours.alpha(ds.accent, 0.12)
                            border.width: 1
                            border.color: Colours.alpha(ds.accent, 0.35)

                            P5Text {
                                id: dsPart

                                anchors.centerIn: parent
                                text: modelData
                                color: Colours.ink
                                font.pixelSize: Appearance.font.size.tiny
                                tracking: 1
                            }
                        }
                    }
                }
                Item {
                    width: 1
                    height: 4
                }
                P5Text {
                    text: "WHAT STAYS WITH IT"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.small
                    tracking: 2
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: ds.look?.lockOnly === true ? "Only the lock changes — your bar, desktop and widgets stay exactly as they are." : "Everything you tune while wearing it is remembered for this look alone — its desk and widgets per wallpaper, its lock layout, its dials. Put another look on and that one keeps its own."
                    color: Colours.inkDim
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: Appearance.font.size.small
                    lineHeight: 1.2
                }
            }
        }

        // close, and the neighbours
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.top: parent.top
            anchors.topMargin: 16
            spacing: 8
            opacity: ds.inside

            TileButton {
                icon: "chevron_left"
                onClicked: root.detailStep(-1)
            }
            TileButton {
                icon: "chevron_right"
                onClicked: root.detailStep(1)
            }
            TileButton {
                icon: "close"
                onClicked: root.closeDetail()
            }
        }

        Row {
            id: dsActions

            anchors.left: dsWords.left
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 22
            spacing: 10
            opacity: ds.inside

            BandButton {
                strong: true
                text: ds.on ? (ds.look?.original === true ? "YOU WEAR IT" : "TUNE THIS LOOK") : (ds.look?.original === true ? "BACK TO VELVET" : "PUT IT ON")
                onClicked: {
                    if (!(ds.on && ds.look?.original === true))
                        root.put(ds.look.id);
                }
            }
            BandButton {
                visible: ds.look?.custom === true
                danger: true
                icon: "delete"
                text: ds.armed ? "CLICK AGAIN TO DELETE" : "DELETE"
                onClicked: {
                    if (!ds.armed) {
                        ds.armed = true;
                        disarm.restart();
                        return;
                    }
                    const id = ds.look.id;
                    root.closeDetail();
                    Presets.removeCustom(id);
                    Sfx.back();
                    Toast.ok("LOOK DELETED");
                }
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "ENTER PUTS IT ON · ← → THE NEXT ONE · ESC BACK TO THE SHELF"
                color: Colours.alpha(Colours.inkDim, 0.75)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
                leftPadding: 8
                visible: dsWords.width > 520
            }
        }

        Timer {
            id: disarm

            interval: 3000
            onTriggered: ds.armed = false
        }
    }

    // ── the look, drawn small: its own art for each kind
    component LookArt: Item {
        id: art

        property var look: null

        Loader {
            anchors.fill: parent
            active: art.look !== null
            sourceComponent: art.look?.family === "windows" ? winArt : (art.look?.vibe === true ? vibeArt : classicArt)
        }

        Component {
            id: winArt

            WinMini {
                v: art.look?.version ?? "11"
            }
        }
        Component {
            id: vibeArt

            VibeArt {
                look: art.look
            }
        }
        Component {
            id: classicArt

            ClassicArt {
                look: art.look
            }
        }
    }

    // A classic look (and VELVET, and yours) on YOUR wallpaper: where its bar
    // sits, the music along its edge, its clock, its pills.
    component ClassicArt: Item {
        id: preview

        property var look: ({})

        readonly property color accent: root.accentOf(preview.look)
        readonly property color tone: Qt.hsla(preview.accent.hslHue, Math.min(0.46, preview.accent.hslSaturation * 0.42), 0.13, 1)
        readonly property real u: preview.height / 400
        readonly property string edge: preview.look?.barEdge ?? ""
        readonly property real barT: 22 * preview.u

        clip: true

        Rectangle {
            anchors.fill: parent
            color: Colours.paper
        }

        Image {
            anchors.fill: parent
            source: Config.wallpaper.current !== "" ? "file://" + Config.wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 640
            opacity: 0.9
        }

        // a lock-only look shows the lock's blur and dim
        Rectangle {
            anchors.fill: parent
            color: Colours.alpha(preview.tone, preview.look?.lockOnly ? 0.55 : 0.12)
        }

        // the frame round the desktop
        Shape {
            anchors.fill: parent
            visible: preview.look?.settings?.["bar.frame"] === true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: preview.tone
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill

                PathRectangle {
                    x: 0
                    y: 0
                    width: preview.width
                    height: preview.height
                }
                PathRectangle {
                    x: preview.edge === "left" ? preview.barT : 5 * preview.u
                    y: preview.edge === "top" ? preview.barT : 5 * preview.u
                    width: preview.width - (preview.edge === "left" ? preview.barT : 5 * preview.u) - 5 * preview.u
                    height: preview.height - (preview.edge === "top" ? preview.barT : 5 * preview.u) - 5 * preview.u
                    radius: 16 * preview.u
                }
            }
        }

        // the music along its edge: bars hanging down, or a soft wave
        Row {
            visible: preview.look?.waveStyle === "bars" && preview.look?.waveEdge === "top"
            x: 0
            y: preview.edge === "top" ? preview.barT : 0
            spacing: 3 * preview.u

            Repeater {
                model: preview.u > 0.01 ? Math.min(200, Math.max(0, Math.floor(preview.width / (7 * preview.u)))) : 0

                Rectangle {
                    required property int index

                    width: 4 * preview.u
                    height: (18 + 34 * Math.abs(Math.sin(index * 0.37) * Math.cos(index * 0.11))) * preview.u
                    radius: width / 2
                    color: preview.accent
                    opacity: 0.9
                }
            }
        }

        Shape {
            anchors.fill: parent
            visible: preview.look?.waveStyle === "wave" && preview.look?.waveEdge === "top"
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: preview.accent
                strokeColor: "transparent"

                PathPolyline {
                    path: {
                        const pts = [Qt.point(0, 0)];
                        const w = preview.width;
                        const n = 48;
                        for (let i = 0; i <= n; i++)
                            pts.push(Qt.point(w * i / n, (10 + 9 * Math.sin(i * 0.55) + 6 * Math.sin(i * 1.3)) * preview.u));
                        pts.push(Qt.point(w, 0));
                        return pts;
                    }
                }
            }
        }

        // the bar
        Rectangle {
            visible: preview.edge !== ""
            x: 0
            y: 0
            width: preview.edge === "left" ? preview.barT : preview.width
            height: preview.edge === "left" ? preview.height : preview.barT
            color: preview.look?.house ? Colours.alpha(Colours.surface, 0.92) : preview.tone

            // its workspaces: pills for the soft looks, the wedge for Velvet
            Repeater {
                model: 5

                Rectangle {
                    required property int index

                    readonly property bool act: index === 1
                    readonly property real len: act ? (preview.look?.house ? 12 : 22) * preview.u : 8 * preview.u
                    readonly property real along: 34 * preview.u + index * 12 * preview.u + (index > 1 ? 14 * preview.u : 0)

                    x: preview.edge === "left" ? (preview.barT - width) / 2 : along
                    y: preview.edge === "left" ? along : (preview.barT - height) / 2
                    width: preview.edge === "left" ? 8 * preview.u : len
                    height: preview.edge === "left" ? len : 8 * preview.u
                    radius: preview.look?.house ? 1 : 4 * preview.u
                    rotation: preview.look?.house && act ? 12 : 0
                    color: act ? preview.accent : Colours.alpha("white", 0.5)
                }
            }
        }

        // the lock's clock or the desktop's: the look's own shape
        Item {
            id: miniClock

            readonly property real s: preview.height * 0.44
            x: preview.look?.lockOnly ? (preview.width - width) / 2 : preview.width * 0.2
            y: (preview.height - height) / 2 + (preview.edge === "top" ? preview.barT / 2 : 0)
            width: preview.look?.clock === "line" ? s * 1.4 : s
            height: s

            M3Shape {
                anchors.fill: parent
                visible: ["none", "line"].indexOf(preview.look?.clock ?? "none") < 0
                kind: preview.look?.clock ?? "none"
                color: preview.tone
                intro: false
            }

            Column {
                anchors.centerIn: parent
                spacing: -miniClock.s * 0.06

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: preview.look?.clock !== "line"
                    text: "07"
                    color: preview.accent
                    font.family: preview.look?.house ? Appearance.fontFamily.display : Appearance.fontFamily.soft
                    font.pixelSize: Math.max(1, miniClock.s * (preview.look?.clock === "none" ? 0.46 : 0.3))
                    font.weight: Font.DemiBold
                    font.italic: preview.look?.house === true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: preview.look?.clock === "line" ? "19:53" : "28"
                    color: "white"
                    font.family: preview.look?.house ? Appearance.fontFamily.display : Appearance.fontFamily.soft
                    font.pixelSize: Math.max(1, miniClock.s * (preview.look?.clock === "none" ? 0.46 : (preview.look?.clock === "line" ? 0.42 : 0.3)))
                    font.weight: Font.DemiBold
                    font.italic: preview.look?.house === true
                }
            }
        }

        // the round pills — the password with its pencil, the song
        Column {
            visible: !preview.look?.house
            x: preview.look?.lockOnly ? (preview.width - width) / 2 : preview.width * 0.6
            y: preview.look?.lockOnly ? miniClock.y + miniClock.height + 8 * preview.u : preview.height * 0.46
            spacing: 6 * preview.u

            Row {
                spacing: 3 * preview.u

                Rectangle {
                    width: 118 * preview.u
                    height: 26 * preview.u
                    radius: Appearance.pill(height)
                    topRightRadius: 4 * preview.u
                    bottomRightRadius: 4 * preview.u
                    color: preview.tone
                }
                Rectangle {
                    width: 30 * preview.u
                    height: 26 * preview.u
                    radius: Appearance.pill(height)
                    topLeftRadius: 4 * preview.u
                    bottomLeftRadius: 4 * preview.u
                    color: preview.tone

                    Icon {
                        anchors.centerIn: parent
                        name: "edit"
                        color: "white"
                        font.pixelSize: Math.max(1, 11 * preview.u)
                    }
                }
            }
            Plate {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 70 * preview.u
                height: 14 * preview.u
                radius: Appearance.pill(height)
                color: preview.tone
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Colours.alpha(Colours.ink, 0.1)
        }
    }

    // One vibe, drawn IN ITSELF: its own ground, pattern, shape, outline,
    // shadow and typeface — the picture is the best description of the look.
    component VibeArt: Item {
        id: vc

        property var look: ({})

        readonly property var sw: vc.look?.swatch ?? ({})
        readonly property string mood: vc.look?.mood ?? "persona"
        readonly property color accent: Presets.withColours ? (vc.sw.accent ?? vc.look?.accent ?? Colours.accent) : Colours.accent
        readonly property color paperC: Presets.withColours ? (vc.sw.paper ?? "#111") : Colours.paper
        readonly property color surfaceC: Presets.withColours ? (vc.sw.surface ?? "#222") : Colours.surface
        readonly property color inkC: Presets.withColours ? (vc.sw.ink ?? "#fff") : Colours.ink
        readonly property color edgeC: Presets.withColours ? (vc.look?.edgeHex ?? vc.inkC) : Colours.edge
        readonly property real u: Math.max(0.3, vc.width / 700)
        readonly property real shadowPx: (vc.look?.shadowSize ?? 0) * vc.u * 0.7

        clip: true

        Rectangle {
            anchors.fill: parent
            color: vc.paperC
        }

        Backdrop {
            anchors.fill: parent
            kind: vc.look?.backdrop ?? "plain"
            colour: vc.inkC
            step: 38 * vc.u
        }

        Scanlines {
            anchors.fill: parent
            z: 30
            strength: vc.look?.scanlines ?? 0
        }

        // the bar, on the edge this vibe puts it
        Slash {
            readonly property string edge: vc.look?.barEdge ?? "top"
            readonly property bool vert: edge === "left" || edge === "right"

            x: edge === "right" ? vc.width - width - 10 * vc.u : 10 * vc.u
            y: edge === "bottom" ? vc.height - height - 10 * vc.u : 10 * vc.u
            width: vert ? 26 * vc.u : vc.width - 20 * vc.u
            height: vert ? vc.height - 20 * vc.u : 26 * vc.u
            shear: 0
            shape: vc.look?.shape ?? "square"
            outlineWidth: (vc.look?.outline ?? 0) * 0.7
            outlineColour: vc.edgeC
            shadowKind: vc.look?.shadow ?? "none"
            shadowSize: vc.shadowPx * 0.6
            color: vc.surfaceC
            borderColor: "transparent"

            Row {
                visible: !parent.vert
                anchors.verticalCenter: parent.verticalCenter
                x: 10 * vc.u
                spacing: 6 * vc.u

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        width: (index === 0 ? 18 : 9) * vc.u
                        height: 9 * vc.u
                        color: index === 0 ? vc.accent : Qt.rgba(vc.inkC.r, vc.inkC.g, vc.inkC.b, 0.45)
                    }
                }
            }

            Column {
                visible: parent.vert
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10 * vc.u
                spacing: 6 * vc.u

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        width: 9 * vc.u
                        height: (index === 0 ? 18 : 9) * vc.u
                        color: index === 0 ? vc.accent : Qt.rgba(vc.inkC.r, vc.inkC.g, vc.inkC.b, 0.45)
                    }
                }
            }
        }

        // a card with a title, a bar and two chips
        Slash {
            x: vc.width * (vc.look?.barEdge === "left" ? 0.2 : 0.1)
            y: vc.height * 0.3
            width: vc.width * 0.52
            height: vc.height * 0.46
            shear: 0
            shape: vc.look?.shape ?? "square"
            outlineWidth: vc.look?.outline ?? 0
            outlineColour: vc.edgeC
            shadowKind: vc.look?.shadow ?? "none"
            shadowSize: vc.shadowPx
            color: vc.surfaceC
            borderColor: Qt.rgba(vc.accent.r, vc.accent.g, vc.accent.b, 0.35)
            borderWidth: 1

            Text {
                x: 14 * vc.u
                y: 10 * vc.u
                text: (vc.look?.caps === "lower" || vc.look?.id === "terminal") ? "system ready" : "SYSTEM READY"
                color: vc.accent
                font.family: Appearance.familyOf(vc.mood, true)
                font.pixelSize: Math.max(1, 15 * vc.u * (vc.mood === "arcade" ? 0.85 : 1))
                font.weight: vc.mood === "arcade" ? Font.Normal : Font.Black
                font.letterSpacing: vc.mood === "tech" ? 3 : 1
            }
            Text {
                x: 14 * vc.u
                y: 34 * vc.u
                text: vc.look?.id === "terminal" ? "volume 62%  ·  wifi ok" : "VOLUME 62%  ·  WIFI OK"
                color: vc.inkC
                font.family: Appearance.familyOf(vc.mood, false)
                font.pixelSize: Math.max(1, 10 * vc.u)
                font.letterSpacing: 0.6
            }

            Rectangle {
                x: 14 * vc.u
                y: parent.height - 30 * vc.u
                width: parent.width - 28 * vc.u
                height: 6 * vc.u
                color: Qt.rgba(vc.inkC.r, vc.inkC.g, vc.inkC.b, 0.18)

                Rectangle {
                    width: parent.width * 0.62
                    height: parent.height
                    color: vc.accent
                }
            }
        }

        Repeater {
            model: 2

            Slash {
                required property int index

                x: vc.width * 0.66
                y: vc.height * (0.36 + index * 0.2)
                width: vc.width * 0.24
                height: vc.height * 0.14
                shear: 0
                shape: vc.look?.shape ?? "square"
                outlineWidth: vc.look?.outline ?? 0
                outlineColour: vc.edgeC
                shadowKind: vc.look?.shadow ?? "none"
                shadowSize: vc.shadowPx * 0.8
                color: index === 0 ? vc.accent : vc.surfaceC
                borderColor: "transparent"
            }
        }
    }

    // A little picture of one Windows edition: a desktop, a window, a taskbar
    // with its Start button.
    component WinMini: Item {
        id: wm

        property string v: "11"

        readonly property real u: Math.max(0.3, wm.width / 280)
        readonly property var sw: Presets.winSpecs[wm.v]?.swatch ?? ({})

        clip: true

        // the desktop
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: ({
                            "95": "#008080",
                            "xp": "#4f86d6",
                            "7": "#1b4f8c",
                            "10": "#10294a",
                            "11": "#c9d9f2"
                        })[wm.v] ?? "#333"
                }
                GradientStop {
                    position: 1
                    color: ({
                            "95": "#008080",
                            "xp": "#74b04a",
                            "7": "#2a74c0",
                            "10": "#1b5a9a",
                            "11": "#e9d9ee"
                        })[wm.v] ?? "#222"
                }
            }
        }

        // the window
        Item {
            x: wm.width * 0.12
            y: wm.height * 0.12
            width: wm.width * 0.76
            height: wm.height * 0.64

            Rectangle {
                anchors.fill: parent
                radius: wm.v === "11" ? 8 * wm.u : (wm.v === "xp" ? 6 * wm.u : (wm.v === "7" ? 5 * wm.u : 0))
                color: ({
                        "95": "#c0c0c0",
                        "xp": "#0831d9",
                        "7": "#6fa3d8",
                        "10": "#1f1f1f",
                        "11": "#f3f3f3"
                    })[wm.v] ?? "#999"
                border.width: wm.v === "95" ? 2 : 1
                border.color: ({
                        "95": "#ffffff",
                        "xp": "#0831d9",
                        "7": "#2b4a78",
                        "10": "#0078d7",
                        "11": "#d6d6d6"
                    })[wm.v] ?? "#777"
            }
            // title bar
            Rectangle {
                x: 2 * wm.u
                y: 2 * wm.u
                width: parent.width - 4 * wm.u
                height: (wm.v === "xp" ? 14 : (wm.v === "11" || wm.v === "10" ? 10 : 11)) * wm.u
                radius: wm.v === "xp" ? 4 * wm.u : (wm.v === "11" ? 6 * wm.u : 0)
                visible: wm.v !== "7"

                gradient: Gradient {
                    orientation: wm.v === "95" ? Gradient.Horizontal : Gradient.Vertical

                    GradientStop {
                        position: 0
                        color: ({
                                "95": "#000080",
                                "xp": "#2f86ff",
                                "10": "#1f1f1f",
                                "11": "#f3f3f3"
                            })[wm.v] ?? "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: ({
                                "95": "#1084d0",
                                "xp": "#0a5de6",
                                "10": "#1f1f1f",
                                "11": "#f3f3f3"
                            })[wm.v] ?? "transparent"
                    }
                }
            }
            // the body
            Rectangle {
                x: 3 * wm.u
                y: (wm.v === "7" ? 14 : (wm.v === "xp" ? 17 : 13)) * wm.u
                width: parent.width - 6 * wm.u
                height: parent.height - y - 3 * wm.u
                radius: wm.v === "11" ? 4 * wm.u : 0
                color: ({
                        "95": "#ffffff",
                        "xp": "#ece9d8",
                        "7": "#ffffff",
                        "10": "#2b2b2b",
                        "11": "#ffffff"
                    })[wm.v] ?? "#fff"

                // the navigation and a few rows
                Rectangle {
                    width: parent.width * 0.28
                    height: parent.height
                    color: ({
                            "95": "#ffffff",
                            "xp": "#6e8fe0",
                            "7": "#e9f0fa",
                            "10": "#262626",
                            "11": "#f3f3f3"
                        })[wm.v] ?? "#eee"
                }
                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        x: parent.width * 0.33
                        y: (5 + index * 9) * wm.u
                        width: parent.width * (index === 0 ? 0.5 : 0.6)
                        height: 4 * wm.u
                        radius: wm.v === "11" ? 2 * wm.u : 0
                        color: index === 0 ? (wm.sw.accent ?? "#0067c0") : Qt.rgba(0.5, 0.5, 0.5, 0.45)
                    }
                }
            }
        }

        // the taskbar
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 14 * wm.u
            color: ({
                    "95": "#c0c0c0",
                    "xp": "#245edb",
                    "7": "#16253c",
                    "10": "#101010",
                    "11": "#eef1f7"
                })[wm.v] ?? "#111"
            opacity: wm.v === "7" ? 0.9 : 1

            Rectangle {
                x: wm.v === "11" ? parent.width / 2 - 6 * wm.u : 2 * wm.u
                anchors.verticalCenter: parent.verticalCenter
                width: (({
                            "95": 26,
                            "xp": 34,
                            "7": 11,
                            "10": 10,
                            "11": 11
                        })[wm.v] ?? 11) * wm.u
                height: (({
                            "95": 10,
                            "xp": 11,
                            "7": 11,
                            "10": 10,
                            "11": 11
                        })[wm.v] ?? 10) * wm.u
                radius: wm.v === "xp" ? 5 * wm.u : (wm.v === "7" ? 6 * wm.u : (wm.v === "11" ? 2 * wm.u : 0))
                color: ({
                        "95": "#dcdcdc",
                        "xp": "#3c9a2f",
                        "7": "#3a8ee6",
                        "10": "#e0e0e0",
                        "11": "#0067c0"
                    })[wm.v] ?? "#888"
                border.width: wm.v === "95" ? 1 : 0
                border.color: "#808080"
            }
        }
    }
}
