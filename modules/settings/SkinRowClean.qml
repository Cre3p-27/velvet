//  VELVET  ·  modules/settings/SkinRowClean.qml
//  One row of the settings list in the CLEAN look: a name over a quiet line,
//  the control on the right, a hairline underneath. Same contract as
//  SettingRow (SettingRowAny swaps it in); hover and selection ease in.
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

    readonly property bool narrow: root.width > 0 && root.width < 640
    readonly property string kind: item.kind ?? "info"
    readonly property bool interactive: kind !== "info"
    readonly property bool styled: (item.style ?? "") !== ""
    readonly property bool inUse: root.styled && Config.lock.look === item.style
    readonly property color hair: Colours.alpha(Colours.ink, 0.08)
    readonly property string fl: Appearance.flavour
    readonly property bool soft: root.fl === "neu" || root.fl === "clay"
    // what a raised / pressed plate is called in this flavour
    readonly property string raisedKind: root.fl === "neu" ? "raised" : "clay"
    readonly property color plateColour: root.fl === "neu" ? Colours.surface : Colours.mix(Colours.surfaceHigh, Config.appearance.clayTint === "accent" ? Colours.accent : Colours.clay, 0.1)
    // THIS LOOK → CLEAN: lines between the rows, a card for each, or nothing
    readonly property string rowStyle: Config.appearance.cleanRows

    readonly property real headH: Appearance.row.height
    readonly property real foldWant: {
        if (!root.open)
            return 0;
        if (root.kind === "slider")
            return 54;
        if (root.kind === "choice")
            return chips.implicitHeight + 18;
        return 0;
    }
    property real fold: root.foldWant

    Behavior on fold {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutCubic
        }
    }

    implicitHeight: root.headH + root.fold
    opacity: root.styled && !root.inUse && !root.selected && !root.hot ? 0.6 : 1
    z: root.selected ? 10 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.fast
        }
    }

    // ── the surface: a soft wash on hover, a tint and a bar when selected
    Puff {
        visible: root.soft
        x: 4
        y: 5
        width: parent.width - 8
        height: root.headH - 10
        kind: root.fl === "neu" ? (root.selected ? "inset" : "raised") : "clay"
        radius: root.fl === "clay" ? 22 : 16
        depth: root.selected ? 5 : (root.hot ? 8 : (root.fl === "neu" ? 4 : 6))
        color: root.fl === "clay" && root.selected ? Colours.mix(Colours.surfaceHigh, Colours.accent, 0.2) : root.plateColour

        Behavior on depth {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }
    }
    Rectangle {
        visible: !root.soft
        x: 0
        y: 3
        width: parent.width
        height: root.headH - 6
        radius: root.rowStyle === "cards" ? Appearance.r(12) : (root.fl === "clean" ? Appearance.r(10) : (root.fl === "flat" ? 2 : 0))
        color: root.fl === "minimal" ? "transparent" : (root.selected ? Colours.alpha(Colours.accent, root.fl === "flat" ? 0.14 : 0.09) : (root.hot ? Colours.alpha(Colours.ink, 0.04) : (root.rowStyle === "cards" ? Colours.alpha(Colours.ink, 0.035) : "transparent")))

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }
    Rectangle {
        visible: !root.soft
        x: 0
        y: root.headH / 2 - (root.selected ? 13 : 4)
        width: root.fl === "minimal" ? 2 : 3
        height: root.selected ? 26 : 8
        radius: 1.5
        color: Colours.accent
        opacity: root.selected ? 1 : 0

        Behavior on height {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
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
    }
    Rectangle {
        visible: !root.soft && root.rowStyle === "lines"
        y: root.headH + root.fold - 1
        x: 4
        width: parent.width - 8
        height: 1
        color: root.hair
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }
    HoverHandler {
        onHoveredChanged: hovered ? root.hovered() : root.unhovered()
    }

    // ── the words
    Item {
        id: head

        width: parent.width
        height: root.headH

        Column {
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 18 - valueSide.width - 36
            spacing: 2

            Row {
                spacing: 8
                width: parent.width

                P5Text {
                    id: nameText

                    text: Appearance.sentence(root.item.name ?? "")
                    color: Colours.ink
                    font.pixelSize: Math.round(Appearance.row.title * (root.narrow ? 0.93 : 1))
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 8 : 0))
                }
                Rectangle {
                    id: badge

                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.inUse
                    width: badgeText.implicitWidth + 14
                    height: 18
                    radius: 9
                    color: Colours.alpha(Colours.accent, 0.14)

                    P5Text {
                        id: badgeText

                        anchors.centerIn: parent
                        text: "In use"
                        color: Colours.accentInk
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }
            P5Text {
                width: parent.width
                elide: Text.ElideRight
                text: {
                    const sub = Appearance.sentence(root.item.sub ?? "");
                    if (root.styled && !root.inUse)
                        return `For the ${String(root.item.style).toLowerCase()} style — yours is ${String(Config.lock.look).toLowerCase()}${sub ? " · " + sub : ""}`;
                    if (root.expandable && root.childCount > 0)
                        return `${sub}${sub ? " · " : ""}${root.childCount} settings`;
                    return sub;
                }
                color: Colours.inkDim
                font.pixelSize: Appearance.row.sub
            }
        }

        Item {
            id: valueSide

            anchors.right: parent.right
            anchors.rightMargin: 16
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

    // ── the fold
    Item {
        y: root.headH
        width: parent.width
        height: root.fold
        clip: true
        visible: root.fold > 1

        Row {
            visible: root.kind === "slider"
            x: 18
            y: 8
            width: parent.width - 36
            spacing: 12
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }

            RoundButton {
                glyph: "−"
                onClicked: {
                    root.touched();
                    Bridge.nudge(root.item, -1, 1);
                    Sfx.cursor();
                }
            }
            CleanSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * (32 + 12)
                value: Bridge.fraction(root.item)
                step: (root.item.step ?? 0.01) / Math.max(0.000001, (root.item.max ?? 1) - (root.item.min ?? 0))
                onMoved: f => {
                    root.touched();
                    Bridge.set(root.item, Bridge.fromFraction(root.item, f));
                }
                onReleased: Sfx.cursor()
            }
            RoundButton {
                glyph: "+"
                onClicked: {
                    root.touched();
                    Bridge.nudge(root.item, 1, 1);
                    Sfx.cursor();
                }
            }
        }

        Flow {
            id: chips

            visible: root.kind === "choice"
            x: 18
            y: 4
            width: parent.width - 36
            spacing: 8
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

                    width: chipText.implicitWidth + 28
                    height: 30

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.pill(height)
                        color: chip.onIt ? Colours.accent : (chipArea.containsMouse ? Colours.alpha(Colours.ink, 0.1) : Colours.alpha(Colours.ink, 0.05))

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                    P5Text {
                        id: chipText

                        anchors.centerIn: parent
                        text: Appearance.sentence(chip.modelData.label ?? `${chip.modelData.value}`)
                        color: chip.onIt ? Colours.on(Colours.accent) : Colours.ink
                        font.pixelSize: 12
                        font.weight: chip.onIt ? Font.DemiBold : Font.Normal
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

    // ───────────────────────────────────────────────────── value variants
    Component {
        id: numberC

        Row {
            spacing: 14

            Item {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.open && !root.narrow
                width: 112
                height: 14

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 4
                    radius: 2
                    color: Colours.alpha(Colours.ink, 0.1)
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(4, parent.width * Bridge.fraction(root.item))
                    height: 4
                    radius: 2
                    color: Colours.accent
                }
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Bridge.display(root.item)
                color: Colours.alpha(Colours.ink, 0.85)
                font.pixelSize: Appearance.row.value
                font.weight: Font.Medium
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.open ? "expand_less" : "expand_more"
                color: Colours.alpha(Colours.ink, 0.4)
                font.pixelSize: 18
            }
        }
    }

    Component {
        id: toggleC

        Item {
            readonly property bool checked: Bridge.get(root.item) === true

            implicitWidth: 42
            implicitHeight: 24

            // neumorphism and clay: a moulded groove with a moulded knob
            Puff {
                anchors.fill: parent
                visible: root.soft
                kind: root.fl === "neu" ? "inset" : "clay"
                radius: height / 2
                depth: 4
                color: parent.checked ? (root.fl === "neu" ? Colours.mix(Colours.surface, Colours.accent, 0.35) : Colours.accent) : root.plateColour
            }
            P5Text {
                visible: root.fl === "minimal"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: parent.checked ? "on" : "off"
                color: parent.checked ? Colours.ink : Colours.inkDim
                font.pixelSize: 13
                font.underline: parent.checked
            }
            Rectangle {
                visible: !root.soft && root.fl !== "minimal"
                anchors.fill: parent
                radius: root.fl === "flat" ? 3 : 12
                color: parent.checked ? Colours.accent : Colours.alpha(Colours.ink, 0.18)

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
            Puff {
                visible: root.soft
                y: 3
                x: parent.checked ? parent.width - width - 3 : 3
                width: 18
                height: 18
                kind: root.fl === "neu" ? "raised" : "clay"
                radius: 9
                depth: 3
                color: root.fl === "neu" ? Colours.surface : "#ffffff"

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                    }
                }
            }
            Rectangle {
                visible: !root.soft && root.fl !== "minimal"
                y: 3
                x: parent.checked ? parent.width - width - 3 : 3
                width: 18
                height: 18
                radius: root.fl === "flat" ? 2 : 9
                color: "#ffffff"

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    Component {
        id: choiceC

        Item {
            implicitWidth: choiceRow.implicitWidth + 24
            implicitHeight: 32

            Puff {
                anchors.fill: parent
                visible: root.soft
                kind: root.open && root.fl === "neu" ? "inset" : root.raisedKind
                radius: height / 2
                depth: 4
                color: root.plateColour
            }
            Rectangle {
                anchors.fill: parent
                visible: !root.soft
                radius: root.fl === "clean" ? Appearance.pill(height) : (root.fl === "flat" ? 3 : 0)
                color: root.fl === "minimal" ? "transparent" : (root.open ? Colours.alpha(Colours.accent, 0.12) : (root.hot || root.selected ? Colours.alpha(Colours.ink, 0.08) : Colours.alpha(Colours.ink, 0.05)))
                border.width: root.fl === "clean" ? 1 : 0
                border.color: root.open ? Colours.alpha(Colours.accent, 0.4) : root.hair

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
            Row {
                id: choiceRow

                anchors.centerIn: parent
                spacing: 6

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const l = Appearance.sentence(Bridge.choiceLabel(root.item));
                        return root.narrow ? l.split(" · ")[0] : l;
                    }
                    color: root.open ? Colours.accentInk : Colours.ink
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "expand_more"
                    color: Colours.alpha(Colours.ink, 0.45)
                    font.pixelSize: 16
                    rotation: root.open ? 180 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
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
                spacing: 2

                Repeater {
                    model: 24

                    Rectangle {
                        required property int index

                        readonly property real hue: index / 24
                        readonly property bool here: Math.abs(((Colours.accent.hslHue < 0 ? 0 : Colours.accent.hslHue) - hue + 1.5) % 1 - 0.5) < 0.021

                        width: 8
                        height: here ? 26 : 16
                        radius: 3
                        color: Qt.hsla(hue, 0.7, 0.58, 1)

                        Behavior on height {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }

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
                width: 28
                height: 20
                radius: 6
                color: Colours.accent
                border.width: 1
                border.color: root.hair
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Colours.accent}`.toUpperCase()
                color: Colours.inkDim
                font.family: Appearance.fontFamily.mono
                font.pixelSize: 12
            }
        }
    }

    Component {
        id: openC

        Row {
            spacing: 4

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.narrow && (root.item.pane ?? "") !== "" || root.kind === "layout"
                text: root.kind === "layout" ? "Arrange" : "Edit"
                color: Colours.accentInk
                font.pixelSize: 13
                font.weight: Font.Medium
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron_right"
                color: root.hot || root.selected ? Colours.accent : Colours.alpha(Colours.ink, 0.4)
                font.pixelSize: 22

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
        }
    }

    Component {
        id: actionC

        Item {
            implicitWidth: actionText.implicitWidth + 32
            implicitHeight: 32

            Rectangle {
                anchors.fill: parent
                radius: Appearance.pill(height)
                color: root.item.danger ? Colours.alpha(Colours.danger, root.armed || root.selected ? 0.16 : 0.08) : (root.selected ? Colours.alpha(Colours.accent, 0.14) : Colours.alpha(Colours.ink, 0.05))
                border.width: 1
                border.color: root.item.danger ? Colours.alpha(Colours.danger, 0.5) : root.hair

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
            P5Text {
                id: actionText

                anchors.centerIn: parent
                text: root.armed ? "Sure? Click again" : "Run"
                color: root.item.danger ? Colours.danger : Colours.ink
                font.pixelSize: 13
                font.weight: Font.Medium
            }
        }
    }

    Component {
        id: infoC

        P5Text {
            text: `${Bridge.get(root.item)}`
            color: Colours.inkDim
            font.family: Appearance.fontFamily.mono
            font.pixelSize: 12
            elide: Text.ElideLeft
            width: 320
            horizontalAlignment: Text.AlignRight
        }
    }

    // ──────────────────────────────────────────────────────────────── parts
    component RoundButton: Item {
        id: rb

        property string glyph: "+"

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: rbArea.pressed ? Colours.alpha(Colours.ink, 0.16) : (rbArea.containsMouse ? Colours.alpha(Colours.ink, 0.1) : Colours.alpha(Colours.ink, 0.05))

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }
        }
        P5Text {
            anchors.centerIn: parent
            text: rb.glyph
            color: Colours.ink
            font.pixelSize: 17
        }
        MouseArea {
            id: rbArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: {
                rb.clicked();
                rep.restart();
            }
            onReleased: rep.stop()
            onCanceled: rep.stop()
        }
        Timer {
            id: rep

            interval: 380
            repeat: true
            onTriggered: {
                rep.interval = 70;
                rb.clicked();
            }
            onRunningChanged: {
                if (!running)
                    rep.interval = 380;
            }
        }
    }

    // A thin rail with a round handle: drag it, or click anywhere on it.
    component CleanSlider: Item {
        id: cs

        property real value: 0
        property real step: 0.01

        signal moved(real f)
        signal released

        height: 28

        Puff {
            visible: root.soft
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root.fl === "clay" ? 12 : 8
            kind: root.fl === "neu" ? "inset" : "clay"
            radius: height / 2
            depth: 3
            color: root.plateColour
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root.fl === "flat" ? 6 : (root.fl === "minimal" ? 1 : 4)
            radius: root.fl === "clean" ? 2 : 0
            visible: !root.soft
            color: Colours.alpha(Colours.ink, root.fl === "minimal" ? 0.5 : 0.1)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(4, cs.width * cs.value)
            height: root.soft ? (root.fl === "clay" ? 12 : 8) : (root.fl === "flat" ? 6 : (root.fl === "minimal" ? 1 : 4))
            radius: root.soft ? height / 2 : (root.fl === "clean" ? 2 : 0)
            color: root.fl === "neu" ? Qt.rgba(Colours.accent.r, Colours.accent.g, Colours.accent.b, 0.55) : Colours.accent
            visible: root.fl !== "minimal"
        }
        Puff {
            visible: root.soft
            x: Math.max(0, Math.min(cs.width - width, cs.width * cs.value - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: csArea.pressed ? 24 : 22
            height: width
            kind: root.fl === "neu" ? "raised" : "clay"
            radius: width / 2
            depth: 4
            color: root.fl === "neu" ? Colours.surface : "#ffffff"
        }
        Rectangle {
            visible: !root.soft
            x: Math.max(0, Math.min(cs.width - width, cs.width * cs.value - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: root.fl === "minimal" ? 8 : (csArea.pressed ? 20 : 16)
            height: width
            radius: root.fl === "clean" ? width / 2 : (root.fl === "flat" ? 2 : 0)
            color: root.fl === "minimal" ? Colours.ink : (root.fl === "flat" ? Colours.accent : "#ffffff")
            border.width: root.fl === "clean" ? 2 : 0
            border.color: Colours.accent

            Behavior on width {
                NumberAnimation {
                    duration: 90
                }
            }
        }
        MouseArea {
            id: csArea

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: mouse => cs.moved(Math.max(0, Math.min(1, (mouse.x - 4) / Math.max(1, cs.width))))
            onPositionChanged: mouse => {
                if (pressed)
                    cs.moved(Math.max(0, Math.min(1, (mouse.x - 4) / Math.max(1, cs.width))));
            }
            onReleased: cs.released()
        }
    }
}
