//  VELVET  ·  modules/settings/SkinRow.qml
//  One row of the settings list in every skin but the house one. Same
//  contract as SettingRow (it is swapped in by SettingRowAny), completely
//  different bodies: a terminal's `name ..... value` line, a game menu's
//  blocky entry, a HUD plate, a newspaper's table-of-contents line, an
//  iOS-style pane row, a quest-log entry, a poster's headline strip.
//
//  The skin only decides how the row LOOKS. What a click, the arrow keys and
//  the fold (a slider's real slider, a choice's options) DO is the same.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    required property var item
    required property int index
    required property bool selected

    property bool hot: false
    property bool open: false
    property bool armed: false

    property int depth: 0
    property bool expandable: false
    property bool expanded: false
    property int childCount: 0

    signal activate
    signal hovered
    signal unhovered
    signal touched

    readonly property string skin: Appearance.skin
    readonly property bool narrow: root.width > 0 && root.width < 860
    readonly property bool tight: root.width > 0 && root.width < 600

    readonly property string kind: item.kind ?? "info"
    readonly property bool interactive: kind !== "info"
    readonly property bool unfolds: kind === "slider" || kind === "choice"
    readonly property bool styled: (item.style ?? "") !== ""
    readonly property bool inUse: root.styled && Config.lock.look === item.style

    // ── what each skin makes of the same row. No skin paints a solid
    // block behind the selected one any more: it is tinted and edged, and the
    // text stays what it was.
    readonly property bool lit: false
    readonly property color fg: Colours.ink
    readonly property color fgDim: Colours.inkDim
    readonly property color fgAcc: Colours.accentInk
    readonly property color tint: Colours.accent

    readonly property real headH: Math.round(Appearance.row.height * (root.tight ? 0.78 : 1))
    readonly property int namePx: Math.round(Appearance.row.title * (root.tight ? 0.78 : (root.narrow ? 0.9 : 1)))
    readonly property int subPx: Appearance.row.sub
    readonly property int valPx: Math.round(Appearance.row.value * (root.tight ? 0.8 : 1))
    readonly property real pad: Appearance.row.inset * (root.tight ? 0.6 : 1)

    readonly property real foldWant: {
        if (!root.open)
            return 0;
        if (root.kind === "slider")
            return root.skin === "console" ? 40 : Math.round(66 * Appearance.densityScale);
        if (root.kind === "choice")
            return chips.implicitHeight + Math.round((root.skin === "console" ? 12 : 24) * Appearance.densityScale);
        return 0;
    }
    property real fold: root.foldWant

    Behavior on fold {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutExpo
        }
    }

    implicitHeight: root.headH + root.fold
    opacity: root.selected || root.hot ? 1.0 : (root.styled && !root.inUse ? 0.6 : 0.93)
    z: root.selected ? 10 : 1

    // the game menu and the poster nudge the selected entry
    x: root.skin === "arcade" && root.selected ? 4 : (root.skin === "poster" && root.selected ? 6 : 0)

    Behavior on x {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.fast
        }
    }

    // ───────────────────────────────────────────────────────── the surface
    Loader {
        anchors.fill: parent
        z: -1
        sourceComponent: ({
                console: bgConsole,
                arcade: bgArcade,
                hud: bgHud,
                ledger: bgLedger,
                glass: bgGlass,
                tome: bgTome,
                poster: bgPoster
            })[root.skin] ?? null
    }

    Component {
        id: bgConsole

        Item {
            Rectangle {
                width: parent.width
                height: root.headH
                color: root.selected ? Colours.alpha(Colours.accent, 0.14) : (root.hot ? Colours.alpha(Colours.ink, 0.05) : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
            Rectangle {
                width: 2
                height: root.headH
                color: Colours.accent
                opacity: root.selected ? 1 : 0
            }
        }
    }

    Component {
        id: bgArcade

        Item {
            Slash {
                width: parent.width
                height: root.headH
                shear: 0
                color: root.selected ? Colours.mix(Colours.surface, Colours.accent, 0.2) : (root.hot ? Colours.surfaceHigh : Colours.alpha(Colours.surface, 0.85))
                borderColor: root.selected ? Colours.accent : "transparent"
                borderWidth: root.selected ? 2 : 0
                outlineWidth: root.selected ? 0 : 1
                shadowKind: "none"

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
        }
    }

    Component {
        id: bgHud

        Item {
            Slash {
                width: parent.width
                height: root.headH
                shear: 0
                color: root.selected ? Colours.alpha(Colours.accent, 0.14) : (root.hot ? Colours.alpha(Colours.ink, 0.06) : Colours.alpha(Colours.surface, 0.5))
                borderColor: root.selected ? Colours.alpha(Colours.accent, 0.8) : Colours.alpha(Colours.ink, root.hot ? 0.22 : 0.1)
                borderWidth: 1
                outlineWidth: 0
                shadowKind: "none"

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
        }
    }

    Component {
        id: bgLedger

        Item {
            Rectangle {
                width: parent.width
                height: root.headH
                color: root.selected ? Colours.alpha(Colours.accent, 0.1) : (root.hot ? Colours.alpha(Colours.ink, 0.04) : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
            Rectangle {
                y: root.headH - 1
                width: parent.width
                height: 1
                color: Colours.alpha(Colours.ink, 0.18)
            }
            Rectangle {
                width: 3
                height: root.headH - 1
                color: Colours.accent
                opacity: root.selected ? 1 : 0
            }
        }
    }

    Component {
        id: bgGlass

        Item {
            Slash {
                width: parent.width
                height: root.headH
                shear: 0
                color: root.selected ? Qt.rgba(1, 1, 1, 0.17) : (root.hot ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.035))
                borderColor: root.selected ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.08)
                borderWidth: 1
                flat: true

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
        }
    }

    Component {
        id: bgTome

        Item {
            Rectangle {
                width: parent.width
                height: root.headH - 1
                color: root.selected ? Colours.alpha(Colours.accent, 0.12) : (root.hot ? Colours.alpha(Colours.accent, 0.05) : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
            Rectangle {
                width: 2
                height: root.headH - 1
                color: Colours.accent
                opacity: root.selected ? 1 : 0
            }
            Rectangle {
                y: root.headH - 1
                width: parent.width
                height: 1
                color: Colours.alpha(Colours.accent, 0.2)
            }
        }
    }

    Component {
        id: bgPoster

        Item {
            Rectangle {
                width: parent.width
                height: root.headH
                color: root.selected ? Colours.alpha(Colours.accent, 0.22) : (root.hot ? Colours.alpha(Colours.surfaceHigh, 0.95) : Colours.alpha(Colours.surface, 0.9))

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
            Rectangle {
                y: root.headH - 2
                width: parent.width
                height: 2
                color: Colours.edge
            }
            Rectangle {
                width: 5
                height: root.headH
                color: Colours.accent
                opacity: root.selected ? 1 : 0
            }
        }
    }

    // ─────────────────────────────────────────────────────────────── mouse
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }

    HoverHandler {
        onHoveredChanged: hovered ? root.hovered() : root.unhovered()
    }

    // ───────────────────────────────────────────────── the cursor / markers
    // console: a ">" — arcade: a blinking triangle — hud: a double chevron
    // — ledger: a margin arrow — tome: a small blade — poster: none.
    Text {
        id: marker

        visible: root.selected && root.skin !== "poster" && root.skin !== "glass" && root.skin !== "tome"
        x: root.skin === "ledger" ? 12 : (root.skin === "arcade" ? 14 : (root.skin === "hud" ? 14 : (root.skin === "tome" ? 14 : 4)))
        y: (root.headH - height) / 2
        text: ({
                console: ">",
                arcade: "▶",
                hud: "»",
                ledger: "→"
            })[root.skin] ?? ""
        color: root.lit ? Colours.on(Colours.accent) : Colours.accent
        font.family: root.skin === "console" ? Appearance.fontFamily.mono : Appearance.fontFamily.body
        font.pixelSize: root.skin === "arcade" ? 15 : (root.skin === "ledger" ? 18 : 15)
        font.bold: true
    }

    // the hud's index number
    Text {
        visible: root.skin === "hud"
        x: 34
        y: (root.headH - height) / 2
        text: String(root.index + 1).padStart(2, "0")
        color: root.selected ? Colours.accent : Colours.alpha(Colours.accent, 0.55)
        font.family: Appearance.fontFamily.mono
        font.pixelSize: 12
        font.letterSpacing: 1
    }

    // ───────────────────────────────────────────────────────────── the words
    Item {
        id: head

        width: parent.width
        height: root.headH

        // console: one line — "name  # sub ........ value"
        Row {
            visible: root.skin === "console"
            x: root.pad + 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            width: parent.width - root.pad * 2 - valueSide.width - 28

            P5Text {
                id: consoleName

                text: root.item.name ?? ""
                color: root.fg
                font.pixelSize: root.namePx
                font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            P5Text {
                visible: !root.tight && (root.item.sub ?? "") !== ""
                text: `# ${root.item.sub ?? ""}`
                color: root.fgDim
                font.pixelSize: root.subPx
                elide: Text.ElideRight
                width: Math.max(0, parent.width - consoleName.implicitWidth - 14)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // everyone else: a name over a smaller line
        Column {
            id: labels

            visible: root.skin !== "console"
            x: root.skin === "hud" ? root.pad + 2 : root.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.skin === "poster" ? 0 : 2
            width: parent.width - x - valueSide.width - (root.tight ? 18 : 36)

            Row {
                spacing: 12
                width: parent.width

                P5Text {
                    id: nameText

                    display: true
                    text: root.item.name ?? ""
                    color: root.fg
                    font.pixelSize: root.namePx
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 12 : 0))
                }

                Slash {
                    id: badge

                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.inUse
                    width: badgeText.implicitWidth + 20
                    height: 22
                    shear: 0
                    color: root.tint

                    P5Text {
                        id: badgeText

                        anchors.centerIn: parent
                        display: true
                        text: "IN USE"
                        color: Colours.on(root.tint)
                        font.pixelSize: Appearance.font.size.tiny
                    }
                }
            }

            P5Text {
                text: {
                    const sub = root.item.sub ?? "";
                    if (root.styled && !root.inUse)
                        return `FOR THE ${String(root.item.style).toUpperCase()} STYLE — YOURS IS ${String(Config.lock.look).toUpperCase()}${sub ? "   ·   " + sub : ""}`;
                    if (root.expandable && root.childCount > 0)
                        return `${sub}${sub ? "   ·   " : ""}${root.childCount} SETTINGS`;
                    return sub;
                }
                color: root.fgDim
                font.pixelSize: root.subPx
                font.italic: root.skin === "ledger" || root.skin === "tome"
                font.capitalization: root.skin === "ledger" || root.skin === "tome" ? Font.Capitalize : Appearance.type.capitalization
                tracking: root.skin === "ledger" ? 0.2 : 1.0
                elide: Text.ElideRight
                width: parent.width
            }
        }

        // the dotted leader between a ledger's name and its value
        Text {
            visible: root.skin === "ledger" && !root.tight
            x: root.pad + Math.min(nameText.implicitWidth, labels.width) + 14
            y: labels.y + nameText.baselineOffset - 6
            width: Math.max(0, valueSide.x - x - 12)
            clip: true
            text: ". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ."
            color: Colours.alpha(Colours.ink, 0.35)
            font.family: Appearance.fontFamily.body
            font.pixelSize: 14
            wrapMode: Text.NoWrap
        }

        // ── the value side
        Item {
            id: valueSide

            anchors.right: parent.right
            anchors.rightMargin: root.skin === "console" ? 16 : Math.max(14, root.pad * 0.6)
            anchors.verticalCenter: parent.verticalCenter

            width: valueLoader.item ? valueLoader.item.implicitWidth : 0
            height: valueLoader.item ? valueLoader.item.implicitHeight : 0

            Loader {
                id: valueLoader

                sourceComponent: {
                    switch (root.kind) {
                    case "slider":
                        return numberC;
                    case "toggle":
                        return toggleC;
                    case "choice":
                        return choiceC;
                    case "colour":
                        return colourC;
                    case "action":
                        return actionC;
                    case "info":
                        return infoC;
                    default:
                        return openC;
                    }
                }
            }
        }
    }

    // ───────────────────────────────────────────────────────────── the fold
    Item {
        id: foldBox

        y: root.headH
        width: parent.width
        height: root.fold
        clip: true
        visible: root.fold > 1

        // a slider's real slider
        Row {
            visible: root.kind === "slider"
            x: root.pad + (root.skin === "console" ? 14 : 0)
            y: Math.round(4 * Appearance.densityScale)
            width: parent.width - x - root.pad
            spacing: 14
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }

            StepButton {
                icon: "remove"
                onClicked: {
                    root.touched();
                    Bridge.nudge(root.item, -1, 1);
                    Sfx.cursor();
                }
            }

            Loader {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * (stepW + 14)
                height: 30
                sourceComponent: ["console", "arcade", "hud"].indexOf(root.skin) >= 0 ? segSlider : ruleSlider
            }

            StepButton {
                icon: "add"
                onClicked: {
                    root.touched();
                    Bridge.nudge(root.item, 1, 1);
                    Sfx.cursor();
                }
            }
        }

        // every option of a choice, to click
        Flow {
            id: chips

            visible: root.kind === "choice"
            x: root.pad + (root.skin === "console" ? 14 : 0)
            y: Math.round(4 * Appearance.densityScale)
            width: parent.width - x - root.pad
            spacing: root.skin === "console" ? 18 : 10
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }

            Repeater {
                model: root.kind === "choice" && root.open ? (root.item.options ?? []) : []

                Item {
                    id: chip

                    required property var modelData
                    readonly property bool onIt: Bridge.get(root.item) === chip.modelData.value
                    readonly property bool plain: root.skin === "console" || root.skin === "ledger"

                    width: chipText.implicitWidth + (chip.plain ? 4 : 30)
                    height: chip.plain ? 24 : Math.round(38 * Appearance.densityScale)

                    Slash {
                        anchors.fill: parent
                        visible: !chip.plain
                        shear: 0
                        color: chip.onIt ? root.tint : (chipArea.containsMouse ? Colours.alpha(Colours.ink, 0.16) : Colours.alpha(Colours.ink, 0.07))
                        borderColor: chip.onIt ? "transparent" : Colours.alpha(Colours.ink, 0.3)
                        borderWidth: 1
                    }

                    P5Text {
                        id: chipText

                        anchors.centerIn: parent
                        display: !chip.plain
                        text: chip.plain ? (root.skin === "console" ? `${chip.onIt ? "(*)" : "( )"} ${chip.modelData.label ?? chip.modelData.value}` : (chip.modelData.label ?? `${chip.modelData.value}`)) : (chip.modelData.label ?? `${chip.modelData.value}`)
                        color: chip.onIt ? (chip.plain ? Colours.accent : Colours.on(root.tint)) : root.fg
                        font.pixelSize: chip.plain ? root.namePx - 1 : Appearance.font.size.small
                        font.underline: root.skin === "ledger" && chip.onIt
                        font.italic: root.skin === "ledger"
                        font.weight: chip.onIt ? Font.Bold : Font.Normal
                    }

                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.touched();
                            Bridge.set(root.item, chip.modelData.value);
                            Sfx.select();
                        }
                    }
                }
            }
        }
    }

    readonly property real stepW: Math.round((root.skin === "console" ? 30 : 42) * Appearance.densityScale)

    // ─────────────────────────────────────────────────────────── the sliders
    Component {
        id: segSlider

        SegBar {
            fraction: Bridge.fraction(root.item)
            interactive: true
            blocks: root.skin === "console" ? 44 : (root.skin === "hud" ? 48 : 30)
            gap: root.skin === "console" ? 2 : (root.skin === "hud" ? 3 : 4)
            tint: root.tint
            track: Colours.alpha(root.fg, 0.16)
            onMoved: f => {
                root.touched();
                Bridge.set(root.item, Bridge.fromFraction(root.item, f));
            }
            onReleased: Sfx.cursor()
        }
    }

    Component {
        id: ruleSlider

        SlashSlider {
            value: Bridge.fraction(root.item)
            step: (root.item.step ?? 0.01) / Math.max(0.000001, (root.item.max ?? 1) - (root.item.min ?? 0))
            tint: root.tint
            trackHeight: root.skin === "poster" ? 20 : (root.skin === "ledger" ? 6 : 12)
            handleWidth: root.skin === "poster" ? 14 : 10
            wheel: false
            onMoved: f => {
                root.touched();
                Bridge.set(root.item, Bridge.fromFraction(root.item, f));
            }
            onReleased: Sfx.cursor()
        }
    }

    // ───────────────────────────────────────────────────── value variants
    // A slider's head: a little picture of the value, and the number.
    Component {
        id: numberC

        Row {
            spacing: root.skin === "console" ? 10 : 16

            Item {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.open && !root.narrow
                width: ({ console: 150, arcade: 150, hud: 170, ledger: 110, glass: 120, tome: 110, poster: 150 })[root.skin] ?? 120
                height: ({ console: 14, arcade: 22, hud: 16, ledger: 14, glass: 6, tome: 14, poster: 22 })[root.skin] ?? 10

                Loader {
                    anchors.fill: parent
                    sourceComponent: ["console", "arcade", "hud"].indexOf(root.skin) >= 0 ? miniSeg : miniRule
                }

                Component {
                    id: miniSeg

                    SegBar {
                        fraction: Bridge.fraction(root.item)
                        interactive: false
                        blocks: root.skin === "console" ? 14 : (root.skin === "hud" ? 24 : 10)
                        gap: root.skin === "arcade" ? 3 : 2
                        tint: root.tint
                        track: Colours.alpha(root.fg, 0.16)
                    }
                }

                Component {
                    id: miniRule

                    Item {
                        // the track
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: root.skin === "poster" ? parent.height : (root.skin === "glass" ? 6 : 2)
                            radius: Appearance.pill(height)
                            color: Colours.alpha(root.fg, root.skin === "poster" ? 0.18 : 0.3)
                            border.width: root.skin === "poster" ? 2 : 0
                            border.color: Colours.edge
                        }
                        // what is filled
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(height, parent.width * Bridge.fraction(root.item))
                            height: root.skin === "poster" ? parent.height - 6 : (root.skin === "glass" ? 6 : 3)
                            x: root.skin === "poster" ? 3 : 0
                            radius: Appearance.pill(height)
                            color: root.tint
                        }
                        // the marker
                        Rectangle {
                            visible: root.skin === "ledger" || root.skin === "tome"
                            x: Math.max(0, parent.width * Bridge.fraction(root.item) - width / 2)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 10
                            height: 10
                            rotation: root.skin === "tome" ? 45 : 0
                            color: root.tint
                        }
                    }
                }
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: root.skin !== "console"
                text: Bridge.display(root.item)
                color: root.fgAcc
                font.pixelSize: root.valPx
                horizontalAlignment: Text.AlignRight
                font.weight: Font.Bold
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.skin !== "glass"
                text: root.open ? "▴" : "▾"
                color: Colours.alpha(root.fg, 0.55)
                font.pixelSize: root.valPx * 0.8
            }
        }
    }

    Component {
        id: toggleC

        Item {
            implicitWidth: toggleLoader.item ? toggleLoader.item.implicitWidth : 0
            implicitHeight: toggleLoader.item ? toggleLoader.item.implicitHeight : 0

            Loader {
                id: toggleLoader

                sourceComponent: ({
                        console: tConsole,
                        arcade: tBlock,
                        hud: tLed,
                        ledger: tBox,
                        glass: tSwitch,
                        tome: tGem,
                        poster: tBlock
                    })[root.skin] ?? tBlock
            }
        }
    }

    Component {
        id: tConsole

        P5Text {
            readonly property bool checked: Bridge.get(root.item) === true

            text: checked ? "[x] on " : "[ ] off"
            color: checked ? root.fgAcc : root.fgDim
            font.pixelSize: root.valPx
            font.weight: Font.Bold
        }
    }

    Component {
        id: tBlock

        Item {
            readonly property bool checked: Bridge.get(root.item) === true

            implicitWidth: 64
            implicitHeight: 28

            Slash {
                anchors.fill: parent
                shear: 0
                color: parent.checked ? root.tint : "transparent"
                borderColor: parent.checked ? "transparent" : Colours.alpha(root.fg, 0.4)
                borderWidth: 1
                shadowKind: "none"
                outlineWidth: parent.checked ? 1 : 0

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
            P5Text {
                anchors.centerIn: parent
                display: true
                text: parent.checked ? "ON" : "OFF"
                color: parent.checked ? Colours.on(root.tint) : root.fgDim
                font.pixelSize: 13
            }
        }
    }

    Component {
        id: tLed

        Row {
            id: ledRow

            readonly property bool checked: Bridge.get(root.item) === true

            spacing: 12

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                color: parent.checked ? Colours.accent : "transparent"
                border.width: 1.5
                border.color: parent.checked ? Colours.accent : Colours.alpha(Colours.ink, 0.5)

            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: parent.checked ? "ON" : "OFF"
                color: parent.checked ? Colours.accent : Colours.alpha(Colours.ink, 0.55)
                font.pixelSize: root.valPx * 0.8
                tracking: 3
            }
        }
    }

    Component {
        id: tBox

        Row {
            id: boxRow

            readonly property bool checked: Bridge.get(root.item) === true

            spacing: 10

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.checked ? "on" : "off"
                font.italic: true
                color: root.fgDim
                font.pixelSize: root.valPx * 0.9
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                color: parent.checked ? Colours.alpha(Colours.accent, 0.14) : "transparent"
                border.width: 1.5
                border.color: parent.checked ? Colours.accent : Colours.alpha(Colours.ink, 0.6)

                Canvas {
                    anchors.fill: parent
                    visible: boxRow.checked
                    onPaint: {
                        const c = getContext("2d");
                        c.clearRect(0, 0, width, height);
                        c.strokeStyle = `${Colours.accent}`;
                        c.lineWidth = 2;
                        c.lineCap = "round";
                        c.lineJoin = "round";
                        c.beginPath();
                        c.moveTo(4.5, height / 2 + 0.5);
                        c.lineTo(width / 2 - 1, height - 5.5);
                        c.lineTo(width - 4.5, 5.5);
                        c.stroke();
                    }
                    onVisibleChanged: requestPaint()
                }
            }
        }
    }

    Component {
        id: tSwitch

        Item {
            readonly property bool checked: Bridge.get(root.item) === true

            implicitWidth: 52
            implicitHeight: 30

            Rectangle {
                anchors.fill: parent
                radius: Appearance.pill(height)
                color: parent.checked ? root.tint : Colours.alpha(Colours.ink, 0.22)
                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }
            }
            Rectangle {
                y: 3
                x: parent.checked ? parent.width - width - 3 : 3
                width: 24
                height: 24
                radius: Appearance.pill(height)
                color: parent.checked ? Colours.on(root.tint) : Colours.ink

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }

    Component {
        id: tGem

        Row {
            readonly property bool checked: Bridge.get(root.item) === true

            spacing: 10

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.checked ? "On" : "Off"
                font.italic: true
                color: parent.checked ? root.fgAcc : root.fgDim
                font.pixelSize: root.valPx * 0.9
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 13
                height: 13
                rotation: 45
                color: parent.checked ? Colours.accent : "transparent"
                border.width: 1.5
                border.color: Colours.accent
            }
        }
    }

    // ‹ LABEL › — the chevrons step, the label opens the fold.
    Component {
        id: choiceC

        Row {
            spacing: root.skin === "console" ? 4 : 6

            ChevronButton {
                anchors.verticalCenter: parent.verticalCenter
                pointsLeft: true
                onClicked: {
                    root.touched();
                    Bridge.cycleChoice(root.item, -1);
                    Sfx.select();
                }
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: Math.max(root.narrow ? 80 : 110, choiceLabel.implicitWidth + 36)
                implicitHeight: Math.round((root.skin === "console" ? 24 : 42) * Appearance.densityScale)
                width: implicitWidth
                height: implicitHeight

                Slash {
                    anchors.fill: parent
                    visible: ["console", "ledger", "tome"].indexOf(root.skin) < 0
                    shear: 0
                    color: Colours.alpha(Colours.ink, root.hot ? 0.12 : 0.07)
                    borderColor: Colours.alpha(Colours.ink, 0.2)
                    borderWidth: 1
                    shadowKind: "none"
                }

                // a ledger / tome choice is a word with a rule under it
                Rectangle {
                    visible: root.skin === "ledger" || root.skin === "tome"
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 2
                    color: Colours.alpha(Colours.accent, 0.8)
                }

                P5Text {
                    id: choiceLabel

                    anchors.centerIn: parent
                    display: root.skin !== "console"
                    text: root.narrow ? Bridge.choiceLabel(root.item).split(" · ")[0] : Bridge.choiceLabel(root.item)
                    color: root.fgAcc
                    font.pixelSize: root.skin === "console" ? root.valPx : Appearance.font.size.normal
                    font.italic: root.skin === "ledger" || root.skin === "tome"
                    font.weight: Font.Bold
                }
            }

            ChevronButton {
                anchors.verticalCenter: parent.verticalCenter
                pointsLeft: false
                onClicked: {
                    root.touched();
                    Bridge.cycleChoice(root.item, 1);
                    Sfx.select();
                }
            }
        }
    }

    Component {
        id: colourC

        Row {
            spacing: 10

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.skin === "console" ? 1 : 2

                Repeater {
                    model: 24

                    Rectangle {
                        required property int index

                        readonly property real hue: index / 24
                        readonly property bool here: Math.abs(((Colours.accent.hslHue < 0 ? 0 : Colours.accent.hslHue) - hue + 1.5) % 1 - 0.5) < 0.021

                        width: root.skin === "console" ? 7 : 9
                        height: here ? 28 : 18
                        color: Qt.hsla(hue, 0.72, 0.55, 1)

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -2
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.touched();
                                Bridge.setHue(root.item, parent.hue);
                                Sfx.select();
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                height: 24
                color: Colours.accent
                border.width: 2
                border.color: root.fg
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Colours.accent}`.toUpperCase()
                color: root.fg
                font.family: Appearance.fontFamily.mono
                font.pixelSize: Appearance.font.size.normal
            }
        }
    }

    Component {
        id: openC

        Row {
            spacing: 8

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: root.skin !== "console"
                text: root.skin === "console" ? (root.kind === "layout" ? "[arrange]" : "[open]") : (root.kind === "layout" ? "ARRANGE" : ((root.item.pane ?? "") !== "" ? "EDIT" : "OPEN"))
                color: root.fgAcc
                font.pixelSize: root.skin === "console" ? root.valPx : Appearance.font.size.normal
                font.weight: Font.Bold
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ({ console: ">>", arcade: "▶", hud: "»", ledger: "→", glass: "›", tome: "›", poster: "→" })[root.skin] ?? "›"
                color: root.fgAcc
                font.pixelSize: root.skin === "glass" ? root.valPx * 1.5 : root.valPx
                font.weight: Font.Bold
            }
        }
    }

    Component {
        id: actionC

        Item {
            implicitWidth: Math.round((root.armed ? 180 : 112) * Appearance.densityScale)
            implicitHeight: Math.round((root.skin === "console" ? 24 : 40) * Appearance.densityScale)

            Slash {
                anchors.fill: parent
                visible: root.skin !== "console" && root.skin !== "ledger"
                shear: 0
                color: root.item.danger ? Colours.alpha(Colours.danger, root.selected ? 0.3 : 0.14) : (root.selected ? Colours.alpha(root.tint, 0.22) : Colours.alpha(root.fg, 0.07))
                borderColor: root.item.danger ? Colours.danger : (root.selected ? root.tint : Colours.alpha(root.fg, 0.4))
                borderWidth: 1
                shadowKind: "none"
            }
            Rectangle {
                visible: root.skin === "ledger"
                anchors.fill: parent
                color: "transparent"
                border.width: 2
                border.color: root.item.danger ? Colours.danger : Colours.ink
            }
            P5Text {
                anchors.centerIn: parent
                display: root.skin !== "console"
                text: root.skin === "console" ? (root.armed ? "[ sure? click ]" : "[ run ]") : (root.armed ? "SURE? CLICK" : "RUN")
                color: root.item.danger ? Colours.danger : root.fg
                font.pixelSize: root.skin === "console" ? root.valPx : Appearance.font.size.normal
                font.weight: Font.Bold
            }
        }
    }

    Component {
        id: infoC

        P5Text {
            text: `${Bridge.get(root.item)}`
            color: root.fgDim
            font.family: Appearance.fontFamily.mono
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideLeft
            width: 320
            horizontalAlignment: Text.AlignRight
        }
    }

    // ──────────────────────────────────────────────────────────────── parts
    // ‹ and › of a choice — their own hit area, so stepping never opens the
    // fold by accident.
    component ChevronButton: Item {
        id: cb

        property bool pointsLeft: true

        signal clicked

        width: Math.round((root.skin === "console" ? 22 : 36) * Appearance.densityScale)
        height: Math.round((root.skin === "console" ? 24 : 42) * Appearance.densityScale)

        Slash {
            anchors.fill: parent
            visible: cbArea.containsMouse && root.skin !== "console"
            shear: 0
            color: Colours.alpha(root.fg, 0.16)
        }
        P5Text {
            anchors.centerIn: parent
            text: root.skin === "arcade" ? (cb.pointsLeft ? "◀" : "▶") : (cb.pointsLeft ? "‹" : "›")
            color: Colours.alpha(root.fg, cbArea.containsMouse || root.selected ? 0.95 : 0.55)
            font.pixelSize: root.skin === "arcade" ? root.valPx * 0.8 : root.valPx * 1.2
            font.weight: Font.Bold
        }
        MouseArea {
            id: cbArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cb.clicked()
        }
    }

    // − and + beside an open slider.
    component StepButton: Item {
        id: sb

        property string icon: ""

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        width: root.stepW
        height: Math.round(36 * Appearance.densityScale)

        Slash {
            anchors.fill: parent
            shear: 0
            color: sbArea.pressed ? Colours.alpha(root.fg, 0.3) : (sbArea.containsMouse ? Colours.alpha(root.fg, 0.2) : Colours.alpha(root.fg, 0.09))
            borderColor: Colours.alpha(root.fg, 0.35)
            borderWidth: 1
        }

        P5Text {
            anchors.centerIn: parent
            text: sb.icon === "add" ? "+" : "−"
            color: root.fg
            font.pixelSize: root.valPx * 1.1
            font.weight: Font.Bold
        }

        MouseArea {
            id: sbArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                sb.clicked();
                repeat.restart();
            }
            onReleased: repeat.stop()
            onCanceled: repeat.stop()
        }

        Timer {
            id: repeat

            interval: 380
            repeat: true
            onTriggered: {
                repeat.interval = 70;
                sb.clicked();
            }
            onRunningChanged: {
                if (!running)
                    repeat.interval = 380;
            }
        }
    }

    // A bar made of blocks: the terminal's ########----, the arcade's health
    // bar, the HUD's segmented gauge. Drag it, or just look at it.
    component SegBar: Item {
        id: seg

        property real fraction: 0
        property bool interactive: false
        property int blocks: 20
        property real gap: 3
        property color tint: Colours.accent
        property color track: Colours.alpha(Colours.ink, 0.16)

        signal moved(real f)
        signal released(real f)

        readonly property real cell: (seg.width - seg.gap * (seg.blocks - 1)) / seg.blocks
        readonly property int lit: Math.round(Math.max(0, Math.min(1, seg.fraction)) * seg.blocks)

        implicitWidth: 150
        implicitHeight: 16

        Repeater {
            model: seg.blocks

            Rectangle {
                required property int index

                x: index * (seg.cell + seg.gap)
                width: seg.cell
                height: seg.height
                color: index < seg.lit ? seg.tint : seg.track
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            enabled: seg.interactive
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: mouse => seg.moved(Math.max(0, Math.min(1, (mouse.x - 4) / Math.max(1, seg.width))))
            onPositionChanged: mouse => {
                if (pressed)
                    seg.moved(Math.max(0, Math.min(1, (mouse.x - 4) / Math.max(1, seg.width))));
            }
            onReleased: mouse => seg.released(Math.max(0, Math.min(1, (mouse.x - 4) / Math.max(1, seg.width))))
        }
    }
}
