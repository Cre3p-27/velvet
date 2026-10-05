//  VELVET  ·  modules/settings/SettingRow.qml
//  One row of the settings list. Every kind of setting renders through here,
//  which is why adding a setting to Schema.qml costs zero UI work.
//
//  A row is a HEAD (name, what it does, its value) and, for the two kinds
//  that need room, a FOLD that opens under it:
//
//    slider  the head shows the value and a little gauge; click the row (or
//            Enter, or ← →) and the fold opens with the real slider and
//            − / + beside it. The wheel never changes a value — it scrolls
//            the list, so scrolling past a slider cannot move it.
//    choice  ‹ and › in the head step through the options; click the row
//            (or Enter) and the fold lays every option out to click.
//
//  The owner decides which row is open (`open`) and which is the cursor
//  (`selected`); the pointer only lights a row up (`hot`).
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    required property var item
    required property int index
    required property bool selected

    // The pointer is on it — a light-up only; it does not move the cursor.
    property bool hot: false
    // Its fold is open (sliders and choices).
    property bool open: false
    // A dangerous action asking for its second click.
    property bool armed: false

    // Kept for the owners that still draw nesting.
    property int depth: 0
    property bool expandable: false
    property bool expanded: false
    property int childCount: 0

    // A click on the row itself.
    signal activate
    // The pointer arrived / left.
    signal hovered
    signal unhovered
    // A control inside the row was used (a chevron, − / +, an option):
    // the row should become the cursor, nothing else.
    signal touched

    // A narrow list (the LOCK SCREEN one, beside its live picture) gets a
    // smaller name and value, and no gauge, so neither is cut to "CLOCK SI…".
    // A very narrow one (a module's own settings beside the bar editor)
    // goes smaller still.
    readonly property bool narrow: root.width > 0 && root.width < 860
    readonly property bool tight: root.width > 0 && root.width < 600
    readonly property int titlePx: Math.round(Appearance.row.title * (root.tight ? 0.6 : (root.narrow ? 0.78 : 1)))
    readonly property int valuePx: Math.round(Appearance.row.value * (root.tight ? 0.55 : (root.narrow ? 0.7 : 1)))

    readonly property string kind: item.kind ?? "info"
    readonly property bool interactive: kind !== "info"
    readonly property bool unfolds: kind === "slider" || kind === "choice"

    // Lock-style pages carry `style`: the page of the style you wear says so,
    // the others step back a little.
    readonly property bool styled: (item.style ?? "") !== ""
    readonly property bool inUse: root.styled && Config.lock.look === item.style

    readonly property real headH: Math.round(Appearance.row.height * (root.tight ? 0.72 : (root.narrow ? 0.8 : 1)))
    readonly property real foldWant: {
        if (!root.open)
            return 0;
        if (root.kind === "slider")
            return Math.round(70 * Appearance.densityScale);
        if (root.kind === "choice")
            return chips.implicitHeight + Math.round(26 * Appearance.densityScale);
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

    // The cursor is a bar and a lift; the rest of the list stays readable.
    x: selected ? 10 : (hot ? 4 : 0)
    scale: selected ? 1.006 : 1.0
    opacity: selected || hot ? 1.0 : (root.styled && !root.inUse ? 0.62 : 0.9)
    z: selected ? 10 : 1

    Behavior on x {
        SpringAnimation {
            spring: 4.0
            damping: 0.34
            epsilon: 0.5
        }
    }
    Behavior on scale {
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

    // ------------------------------------------------------------ background
    // Breathing accent halo behind the selected row.
    Slash {
        anchors.fill: parent
        anchors.margins: -4
        shear: Appearance.skew
        color: Colours.accent
        opacity: root.selected ? 0.22 : 0
        z: -2

        SequentialAnimation on opacity {
            running: root.selected
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.34
                duration: 1100
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 0.16
                duration: 1100
                easing.type: Easing.InOutSine
            }
        }
    }

    Slash {
        anchors.fill: parent
        shear: Appearance.skew
        color: root.selected ? Colours.accent : (root.hot ? Colours.mix(Colours.paper, Colours.accent, 0.12) : Colours.alpha(Colours.paper, 0.72))
        borderColor: root.selected ? Colours.ink : Colours.alpha(Colours.ink, root.hot ? 0.34 : 0.14)
        borderWidth: root.selected ? 2 : 1
        z: -1

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    // The white tab that punches out on the left when selected.
    Rectangle {
        width: root.selected ? 13 : 0
        height: root.headH * 0.66
        y: (root.headH - height) / 2
        anchors.left: parent.left
        anchors.leftMargin: -20
        color: Colours.ink
        antialiasing: true
        transform: Matrix4x4 {
            matrix: Qt.matrix4x4(1, Math.tan(Appearance.skew * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        }

        Behavior on width {
            SpringAnimation {
                spring: 4.5
                damping: 0.3
                epsilon: 0.3
            }
        }
    }

    // ----------------------------------------------------------------- mouse
    // The whole row is one button; the controls inside sit on top of it.
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activate()
    }

    HoverHandler {
        onHoveredChanged: hovered ? root.hovered() : root.unhovered()
    }

    // ---------------------------------------------------------------- labels
    readonly property color ink: root.selected ? Colours.on(Colours.accent) : Colours.ink
    // accentInk, not accent: this is text on a panel, so it has to clear the
    // body-text contrast threshold even when the wallpaper hands us something
    // dark. On the filled row we ride the accent's own contrast pair.
    readonly property color inkSub: root.selected ? Colours.alpha(Colours.on(Colours.accent), 0.82) : Colours.accentInk

    Item {
        id: head

        width: parent.width
        height: root.headH

        Column {
            id: labels

            anchors.left: parent.left
            anchors.leftMargin: root.tight ? Math.round(Appearance.row.inset * 0.5) : Appearance.row.inset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            width: parent.width - anchors.leftMargin - valueSide.width - (root.tight ? 20 : 44)

            Row {
                width: parent.width
                spacing: 12

                P5Text {
                    id: nameText

                    display: true
                    text: root.item.name ?? ""
                    color: root.ink
                    font.pixelSize: root.titlePx
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 12 : 0))
                }

                // IN USE on the page of the lock style you wear.
                Slash {
                    id: badge

                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.inUse
                    width: badgeText.implicitWidth + 22
                    height: Math.round(24 * Appearance.densityScale)
                    shear: Appearance.skew
                    color: root.selected ? Colours.on(Colours.accent) : Colours.accent

                    P5Text {
                        id: badgeText

                        anchors.centerIn: parent
                        display: true
                        text: "IN USE"
                        color: root.selected ? Colours.accent : Colours.on(Colours.accent)
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
                color: root.inkSub
                font.pixelSize: Appearance.row.sub
                tracking: 1.1
                elide: Text.ElideRight
                width: parent.width
            }
        }

        // -------------------------------------------------------- right side
        Item {
            id: valueSide

            anchors.right: parent.right
            anchors.rightMargin: Appearance.row.inset * (root.tight ? 0.35 : 0.7)
            anchors.verticalCenter: parent.verticalCenter
            scale: root.tight ? 0.82 : 1
            transformOrigin: Item.Right

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
                    case "page":
                    case "layout":
                        return openC;
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

    // ------------------------------------------------------------ the fold
    Item {
        id: foldBox

        y: root.headH
        width: parent.width
        height: root.fold
        clip: true
        visible: root.fold > 1

        // The slider, with a step on either side.
        Row {
            visible: root.kind === "slider"
            x: Appearance.row.inset
            y: Math.round(4 * Appearance.densityScale)
            width: parent.width - Appearance.row.inset - Appearance.row.inset * 0.7
            spacing: 18
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

            SlashSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * (Math.round(44 * Appearance.densityScale) + 18)
                value: root.kind === "slider" ? Bridge.fraction(root.item) : 0
                step: (root.item.step ?? 0.01) / Math.max(0.000001, (root.item.max ?? 1) - (root.item.min ?? 0))
                tint: root.selected ? Colours.on(Colours.accent) : Colours.accent
                trackHeight: Math.round(14 * Appearance.densityScale)
                handleWidth: Math.round(11 * Appearance.densityScale)
                // The wheel belongs to the list.
                wheel: false
                onMoved: f => {
                    root.touched();
                    Bridge.set(root.item, Bridge.fromFraction(root.item, f));
                }
                onReleased: Sfx.cursor()
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

        // Every option of a choice, to click.
        Flow {
            id: chips

            visible: root.kind === "choice"
            x: Appearance.row.inset
            y: Math.round(4 * Appearance.densityScale)
            width: parent.width - Appearance.row.inset - Appearance.row.inset * 0.7
            spacing: 10
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }

            Repeater {
                model: root.kind === "choice" && root.open ? (root.item.options ?? []) : []

                Slash {
                    id: chip

                    required property var modelData
                    readonly property bool lit: Bridge.get(root.item) === chip.modelData.value

                    width: chipText.implicitWidth + 34
                    height: Math.round(42 * Appearance.densityScale)
                    shear: Appearance.skew
                    color: chip.lit ? (root.selected ? Colours.on(Colours.accent) : Colours.accent) : (chipArea.containsMouse ? Colours.alpha(root.ink, 0.16) : Colours.alpha(root.ink, 0.07))
                    borderColor: chip.lit ? "transparent" : Colours.alpha(root.ink, 0.3)
                    borderWidth: 1

                    P5Text {
                        id: chipText

                        anchors.centerIn: parent
                        display: true
                        text: chip.modelData.label ?? `${chip.modelData.value}`
                        color: chip.lit ? (root.selected ? Colours.accent : Colours.on(Colours.accent)) : root.ink
                        font.pixelSize: Appearance.font.size.small
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

    // -------------------------------------------------------------- variants
    // A slider's head: a little gauge and the number. The gauge is a picture
    // only — the real slider is in the fold.
    Component {
        id: numberC

        Row {
            spacing: 18

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(120 * Appearance.densityScale)
                height: Math.round(10 * Appearance.densityScale)
                visible: !root.open && !root.narrow

                Slash {
                    anchors.fill: parent
                    shear: Appearance.skew * 1.6
                    color: Colours.alpha(root.ink, 0.14)
                }
                Slash {
                    width: Math.max(height, parent.width * Bridge.fraction(root.item))
                    height: parent.height
                    shear: Appearance.skew * 1.6
                    color: root.selected ? Colours.on(Colours.accent) : Colours.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: Bridge.display(root.item)
                color: root.ink
                font.pixelSize: root.valuePx
                horizontalAlignment: Text.AlignRight
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.open ? "expand_less" : "expand_more"
                color: Colours.alpha(root.ink, root.selected || root.hot ? 0.85 : 0.4)
                font.pixelSize: Appearance.font.size.large
            }
        }
    }

    Component {
        id: toggleC

        Item {
            readonly property bool checked: Bridge.get(root.item) === true

            implicitWidth: Math.round(118 * Appearance.densityScale)
            implicitHeight: Math.round(46 * Appearance.densityScale)

            Slash {
                anchors.fill: parent
                shear: Appearance.skew
                color: parent.checked ? (root.selected ? Colours.on(Colours.accent) : Colours.accent) : Colours.alpha(Colours.ink, 0.16)
                borderColor: root.selected ? Colours.alpha(Colours.on(Colours.accent), 0.5) : Colours.alpha(Colours.ink, 0.25)
                borderWidth: 1
            }

            Slash {
                width: Math.round(38 * Appearance.densityScale)
                height: parent.height - 10
                y: 5
                x: parent.checked ? parent.width - width - 5 : 5
                shear: Appearance.skew
                color: parent.checked ? (root.selected ? Colours.accent : Colours.paper) : Colours.ink

                Behavior on x {
                    SpringAnimation {
                        spring: 5.0
                        damping: 0.34
                        epsilon: 0.4
                    }
                }
            }

            P5Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: parent.checked ? -18 : 18
                display: true
                text: parent.checked ? "ON" : "OFF"
                color: parent.checked ? (root.selected ? Colours.accent : Colours.on(Colours.accent)) : Colours.alpha(Colours.ink, 0.75)
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    // ‹ LABEL › — the chevrons step, the label opens the fold.
    Component {
        id: choiceC

        Row {
            spacing: 6

            ChevronButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron_left"
                onClicked: {
                    root.touched();
                    Bridge.cycleChoice(root.item, -1);
                    Sfx.select();
                }
            }

            Slash {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(root.narrow ? 90 : 120, choiceLabel.implicitWidth + 64)
                height: Math.round(46 * Appearance.densityScale)
                shear: Appearance.skew
                color: root.selected ? Colours.alpha(Colours.on(Colours.accent), 0.18) : Colours.alpha(Colours.ink, root.hot ? 0.16 : 0.1)
                borderColor: root.selected ? Colours.alpha(Colours.on(Colours.accent), 0.55) : Colours.alpha(Colours.ink, 0.22)
                borderWidth: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    P5Text {
                        id: choiceLabel

                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        // Long labels ("LIGHT · A THIN HEADLINE") keep
                        // their first part in a narrow row; the fold shows all.
                        text: root.narrow ? Bridge.choiceLabel(root.item).split(" · ")[0] : Bridge.choiceLabel(root.item)
                        color: root.ink
                        font.pixelSize: Appearance.font.size.normal
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.open ? "expand_less" : "expand_more"
                        color: Colours.alpha(root.ink, 0.7)
                        font.pixelSize: Appearance.font.size.normal
                    }
                }
            }

            ChevronButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "chevron_right"
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
            spacing: 12

            // A hue strip you can actually hit. Twenty-four steps is enough to
            // land near any colour by eye; ← → then walk it a degree at a time.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: 24

                    Rectangle {
                        required property int index

                        readonly property real hue: index / 24
                        readonly property bool here: Math.abs(((Colours.accent.hslHue < 0 ? 0 : Colours.accent.hslHue) - hue + 1.5) % 1 - 0.5) < 0.021

                        width: 11
                        height: here ? 34 : 22
                        color: Qt.hsla(hue, 0.72, 0.55, 1)
                        antialiasing: true

                        Behavior on height {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                                easing.type: Easing.OutBack
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
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

            Slash {
                anchors.verticalCenter: parent.verticalCenter
                width: 46
                height: 34
                shear: Appearance.skew
                color: Colours.accent
                borderColor: Colours.alpha(root.ink, 0.6)
                borderWidth: 2
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Colours.accent}`.toUpperCase()
                color: root.ink
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
                display: true
                text: root.kind === "layout" ? "ARRANGE" : ((root.item.pane ?? "") !== "" ? "EDIT" : "OPEN")
                color: Colours.alpha(root.ink, root.hot || root.selected ? 0.95 : 0.75)
                font.pixelSize: Appearance.font.size.normal
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron_right"
                color: root.ink
                font.pixelSize: Appearance.font.size.huge
            }
        }
    }

    Component {
        id: actionC

        Slash {
            implicitWidth: Math.round((root.armed ? 180 : 128) * Appearance.densityScale)
            implicitHeight: Math.round(46 * Appearance.densityScale)
            shear: Appearance.skew
            color: root.selected ? (root.item.danger ? Colours.danger : Colours.on(Colours.accent)) : (root.hot ? Colours.alpha(root.item.danger ? Colours.danger : Colours.ink, 0.14) : "transparent")
            borderColor: root.item.danger ? Colours.danger : Colours.alpha(root.ink, 0.6)
            borderWidth: 2

            P5Text {
                anchors.centerIn: parent
                display: true
                text: root.armed ? "SURE? CLICK" : "RUN"
                color: root.selected ? (root.item.danger ? Colours.ink : Colours.accent) : (root.item.danger ? Colours.danger : root.ink)
                font.pixelSize: Appearance.font.size.normal
            }
        }
    }

    Component {
        id: infoC

        P5Text {
            text: `${Bridge.get(root.item)}`
            color: Colours.alpha(root.ink, 0.7)
            font.family: Appearance.fontFamily.mono
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideLeft
            width: 340
            horizontalAlignment: Text.AlignRight
        }
    }

    // ----------------------------------------------------------------- parts
    // ‹ and › of a choice: their own hit area, so stepping never opens the
    // fold by accident.
    component ChevronButton: Item {
        id: cb

        property string icon: ""

        signal clicked

        width: Math.round(40 * Appearance.densityScale)
        height: Math.round(46 * Appearance.densityScale)

        Slash {
            anchors.fill: parent
            shear: Appearance.skew
            color: cbArea.containsMouse ? Colours.alpha(root.ink, 0.16) : "transparent"
        }
        Icon {
            anchors.centerIn: parent
            name: cb.icon
            color: Colours.alpha(root.ink, cbArea.containsMouse || root.selected ? 0.95 : (root.hot ? 0.7 : 0.4))
            font.pixelSize: Appearance.font.size.large
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
    component StepButton: Slash {
        id: sb

        property string icon: ""

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(44 * Appearance.densityScale)
        height: Math.round(40 * Appearance.densityScale)
        shear: Appearance.skew
        color: sbArea.pressed ? Colours.alpha(root.ink, 0.28) : (sbArea.containsMouse ? Colours.alpha(root.ink, 0.18) : Colours.alpha(root.ink, 0.08))
        borderColor: Colours.alpha(root.ink, 0.3)
        borderWidth: 1

        Icon {
            anchors.centerIn: parent
            name: sb.icon
            color: root.ink
            font.pixelSize: Appearance.font.size.large
        }

        MouseArea {
            id: sbArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // Held down, it keeps stepping.
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
}
