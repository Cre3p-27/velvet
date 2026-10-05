//  VELVET  ·  modules/settings/SkinRowWin.qml
//  One row of the settings list in the WINDOWS look, drawn the way the chosen
//  edition would have: list-view lines with check boxes and trackbars in 95
//  and XP, glass highlights in 7, flat lines with square switches in 10,
//  rounded cards with pill switches in 11. Same contract as SettingRow.
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

    readonly property string v: Appearance.winVer
    readonly property bool old: root.v === "95" || root.v === "xp"
    readonly property bool classic: root.old || root.v === "7"
    readonly property bool narrow: root.width > 0 && root.width < 640
    readonly property string kind: item.kind ?? "info"
    readonly property bool interactive: kind !== "info"
    readonly property bool styled: (item.style ?? "") !== ""
    readonly property bool inUse: root.styled && Config.lock.look === item.style
    // 95 and XP put the line under the name on the same line
    readonly property bool oneLine: root.old

    // text on the row as it is drawn right now
    readonly property bool inverted: root.old && root.selected
    readonly property color fg: root.inverted ? WinTheme.selText : WinTheme.text
    readonly property color fgDim: root.inverted ? Qt.rgba(1, 1, 1, 0.75) : WinTheme.dim
    readonly property color acc: WinTheme.accent

    readonly property real headH: Math.round(Appearance.row.height * (root.narrow ? 0.92 : 1))
    readonly property real foldWant: {
        if (!root.open)
            return 0;
        if (root.kind === "slider")
            return root.old ? 40 : 54;
        if (root.kind === "choice")
            return chips.implicitHeight + (root.old ? 14 : 20);
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

    // ───────────────────────────────────────────────────────── the surface
    Loader {
        anchors.fill: parent
        z: -1
        sourceComponent: ({
                "95": sf95,
                "xp": sfXp,
                "7": sf7,
                "10": sf10,
                "11": sf11
            })[root.v] ?? sf11
    }

    Component {
        id: sf95

        Item {
            Rectangle {
                width: parent.width
                height: root.headH
                color: root.selected ? "#000080" : "transparent"
            }
            Rectangle {
                visible: root.selected
                x: 1
                y: 1
                width: parent.width - 2
                height: root.headH - 2
                color: "transparent"
                border.width: 1
                border.color: "#ffff00"
                opacity: 0.75
            }
        }
    }

    Component {
        id: sfXp

        Item {
            Rectangle {
                width: parent.width
                height: root.headH
                color: root.selected ? "#316ac5" : (root.hot ? "#e6eefb" : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: 80
                    }
                }
            }
        }
    }

    Component {
        id: sf7

        Item {
            Rectangle {
                x: 2
                y: 2
                width: parent.width - 4
                height: root.headH - 4
                radius: 3
                visible: root.selected || root.hot
                border.width: 1
                border.color: root.selected ? "#7da2ce" : "#b8d6f5"
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: root.selected ? "#e5f1fc" : "#f4f9fe"
                    }
                    GradientStop {
                        position: 1
                        color: root.selected ? "#c3dcf3" : "#dcebf9"
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.8)
                }
            }
        }
    }

    Component {
        id: sf10

        Item {
            Rectangle {
                width: parent.width
                height: root.headH
                color: root.selected ? (WinTheme.dark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.07)) : (root.hot ? WinTheme.hover : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: 90
                    }
                }
            }
            Rectangle {
                width: 3
                height: root.selected ? root.headH - 16 : 0
                y: 8
                color: WinTheme.accent

                Behavior on height {
                    NumberAnimation {
                        duration: 110
                    }
                }
            }
        }
    }

    Component {
        id: sf11

        Item {
            WinBox {
                y: 1
                width: parent.width
                height: root.headH - 2
                kind: "panel"
                fill: root.selected ? (WinTheme.dark ? "#323232" : "#ffffff") : (root.hot ? (WinTheme.dark ? "#303030" : "#f9f9f9") : "transparent")
            }
            Rectangle {
                x: 0
                y: root.headH / 2 - (root.selected ? 8 : 3)
                width: 3
                height: root.selected ? 16 : 6
                radius: 1.5
                color: WinTheme.accent
                opacity: root.selected ? 1 : 0

                Behavior on height {
                    NumberAnimation {
                        duration: 110
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 110
                    }
                }
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

    // ───────────────────────────────────────────────────────────── the words
    Item {
        id: head

        width: parent.width
        height: root.headH

        // 95 and XP: name and line on one line
        Row {
            visible: root.oneLine
            x: Appearance.row.inset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            width: parent.width - x - valueSide.width - 20

            P5Text {
                id: oneName

                anchors.verticalCenter: parent.verticalCenter
                text: Appearance.titled(root.item.name ?? "")
                color: root.fg
                font.pixelSize: Appearance.row.title
                font.weight: Font.Bold
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.narrow
                text: root.expandable && root.childCount > 0 ? `${root.childCount} settings` : Appearance.sentence(root.item.sub ?? "")
                color: root.fgDim
                elide: Text.ElideRight
                width: Math.max(0, parent.width - oneName.implicitWidth - 14)
                font.pixelSize: Appearance.row.sub
            }
        }

        // 7, 10, 11: a name over a smaller line
        Column {
            visible: !root.oneLine
            x: Appearance.row.inset
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - valueSide.width - 30
            spacing: 1

            Row {
                spacing: 8
                width: parent.width

                P5Text {
                    id: nameText

                    text: Appearance.tcase(root.item.name ?? "")
                    color: root.v === "7" ? "#1e395b" : WinTheme.text
                    font.pixelSize: Appearance.row.title
                    font.weight: root.v === "10" ? Font.Normal : (root.v === "7" ? Font.Normal : Font.Medium)
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 8 : 0))
                }
                Rectangle {
                    id: badge

                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.inUse
                    width: badgeText.implicitWidth + 14
                    height: 18
                    radius: root.v === "10" ? 0 : 9
                    color: WinTheme.accent

                    P5Text {
                        id: badgeText

                        anchors.centerIn: parent
                        text: "In use"
                        color: WinTheme.selText
                        font.pixelSize: 10
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
                color: WinTheme.dim
                font.pixelSize: Appearance.row.sub
            }
        }

        Item {
            id: valueSide

            anchors.right: parent.right
            anchors.rightMargin: root.old ? 8 : 16
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
        y: root.headH
        width: parent.width
        height: root.fold
        clip: true
        visible: root.fold > 1

        Row {
            visible: root.kind === "slider"
            x: Appearance.row.inset
            y: root.old ? 6 : 8
            width: parent.width - x - Appearance.row.inset
            spacing: 10
            opacity: root.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }

            StepButton {
                glyph: "−"
                onClicked: {
                    root.touched();
                    Bridge.nudge(root.item, -1, 1);
                    Sfx.cursor();
                }
            }
            WinTrack {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 2 * (stepW + 10)
                value: Bridge.fraction(root.item)
                interactive: true
                step: (root.item.step ?? 0.01) / Math.max(0.000001, (root.item.max ?? 1) - (root.item.min ?? 0))
                onMoved: f => {
                    root.touched();
                    Bridge.set(root.item, Bridge.fromFraction(root.item, f));
                }
                onReleased: Sfx.cursor()
            }
            StepButton {
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
            x: Appearance.row.inset
            y: root.old ? 2 : 6
            width: parent.width - x - Appearance.row.inset
            spacing: root.old ? 16 : 18
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

                    width: radio.width + 8 + chipText.implicitWidth
                    height: 24

                    WinRadio {
                        id: radio

                        anchors.verticalCenter: parent.verticalCenter
                        checked: chip.onIt
                        hot: chipArea.containsMouse
                    }
                    P5Text {
                        id: chipText

                        anchors.verticalCenter: parent.verticalCenter
                        x: radio.width + 8
                        text: Appearance.tcase(chip.modelData.label ?? `${chip.modelData.value}`)
                        color: root.fg
                        font.pixelSize: Math.max(11, Appearance.row.sub + 1)
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

    readonly property real stepW: root.old ? 26 : 32

    // ───────────────────────────────────────────────────── value variants
    Component {
        id: numberC

        Row {
            spacing: 10

            WinTrack {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.open && !root.narrow
                width: root.old ? 96 : 110
                value: Bridge.fraction(root.item)
                interactive: false
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Bridge.display(root.item)
                color: root.inverted ? root.fg : root.acc
                font.pixelSize: Appearance.row.value
                font.weight: Font.Bold
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.open ? "▴" : "▾"
                color: root.fgDim
                font.pixelSize: Appearance.row.value * 0.8
            }
        }
    }

    Component {
        id: toggleC

        Row {
            id: toggleRow

            readonly property bool checked: Bridge.get(root.item) === true

            spacing: 10

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.v === "10" || root.v === "11"
                text: toggleRow.checked ? "On" : "Off"
                color: root.fg
                font.pixelSize: Appearance.row.value
            }
            WinCheck {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.classic
                checked: toggleRow.checked
                hot: root.hot
            }
            WinSwitch {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.classic
                checked: toggleRow.checked
                hot: root.hot
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.classic
                text: toggleRow.checked ? "On" : "Off"
                color: root.fg
                font.pixelSize: Appearance.row.value
            }
        }
    }

    Component {
        id: choiceC

        Item {
            implicitWidth: Math.max(root.narrow ? 90 : 130, comboText.implicitWidth + 44)
            implicitHeight: root.old ? 24 : 30

            WinBox {
                anchors.fill: parent
                kind: "field"
                hot: root.hot || root.open
                focused: root.open

                P5Text {
                    id: comboText

                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 8 - 26
                    elide: Text.ElideRight
                    text: {
                        const l = Appearance.tcase(Bridge.choiceLabel(root.item));
                        return root.narrow ? l.split(" · ")[0] : l;
                    }
                    color: WinTheme.text
                    font.pixelSize: Appearance.row.value
                }
            }
            // the drop-down button
            WinBox {
                anchors.right: parent.right
                anchors.rightMargin: root.old ? 2 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: root.old ? 17 : 22
                height: parent.height - (root.old ? 4 : 6)
                visible: root.classic
                kind: "button"
                pressed: root.open

                P5Text {
                    anchors.centerIn: parent
                    text: "▾"
                    color: root.v === "xp" ? "#21429b" : "#000000"
                    font.pixelSize: 10
                }
            }
            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.classic
                name: "expand_more"
                color: WinTheme.dim
                font.pixelSize: 18
                rotation: root.open ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: 110
                    }
                }
            }
        }
    }

    Component {
        id: colourC

        Row {
            spacing: 8

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.old ? 0 : 2

                Repeater {
                    model: 24

                    Rectangle {
                        required property int index

                        readonly property real hue: index / 24
                        readonly property bool here: Math.abs(((Colours.accent.hslHue < 0 ? 0 : Colours.accent.hslHue) - hue + 1.5) % 1 - 0.5) < 0.021

                        width: root.old ? 8 : 8
                        height: here ? 24 : 15
                        radius: root.v === "11" ? 3 : 0
                        color: Qt.hsla(hue, 0.7, 0.55, 1)
                        border.width: here && root.old ? 1 : 0
                        border.color: "#000000"

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
                height: 18
                radius: root.v === "11" ? 4 : 0
                color: Colours.accent
                border.width: 1
                border.color: WinTheme.line
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Colours.accent}`.toUpperCase()
                color: root.fgDim
                font.family: Appearance.fontFamily.mono
                font.pixelSize: 11
            }
        }
    }

    Component {
        id: openC

        Row {
            spacing: 6

            WinBox {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.classic
                width: openText.implicitWidth + 22
                height: root.old ? 22 : 26
                kind: "button"
                hot: root.hot
                primary: root.selected

                P5Text {
                    id: openText

                    anchors.centerIn: parent
                    text: root.kind === "layout" ? Appearance.tcase("ARRANGE") : ((root.item.pane ?? "") !== "" ? Appearance.tcase("EDIT") : Appearance.tcase("OPEN")) + " ▸"
                    color: WinTheme.text
                    font.pixelSize: Appearance.row.value
                }
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.classic && (root.kind === "layout" || (root.item.pane ?? "") !== "")
                text: root.kind === "layout" ? "Arrange" : "Edit"
                color: WinTheme.accent
                font.pixelSize: Appearance.row.value
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.classic
                name: "chevron_right"
                color: root.hot || root.selected ? WinTheme.text : WinTheme.dim
                font.pixelSize: 22
            }
        }
    }

    Component {
        id: actionC

        WinBox {
            implicitWidth: actionText.implicitWidth + 30
            implicitHeight: root.old ? 24 : 30
            kind: "button"
            hot: root.hot
            primary: root.selected && !root.item.danger

            P5Text {
                id: actionText

                anchors.centerIn: parent
                text: root.armed ? Appearance.tcase("SURE? CLICK AGAIN") : Appearance.tcase("RUN")
                color: root.item.danger ? (root.v === "11" || root.v === "10" ? Colours.danger : "#c00000") : (WinTheme.v === "11" && root.selected ? WinTheme.selText : WinTheme.text)
                font.pixelSize: Appearance.row.value
            }
        }
    }

    Component {
        id: infoC

        P5Text {
            text: `${Bridge.get(root.item)}`
            color: root.fgDim
            font.family: Appearance.fontFamily.mono
            font.pixelSize: 11
            elide: Text.ElideLeft
            width: 320
            horizontalAlignment: Text.AlignRight
        }
    }

    // ──────────────────────────────────────────────────────────────── parts
    // The little parts, drawn per edition.
    component WinCheck: Item {
        id: wc

        property bool checked: false
        property bool hot: false

        implicitWidth: 15
        implicitHeight: 15

        WinBox {
            anchors.fill: parent
            kind: "field"
            hot: wc.hot
        }
        P5Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            visible: wc.checked
            text: "✓"
            color: root.v === "xp" ? "#21a121" : (root.v === "7" ? "#1e395b" : "#000000")
            font.pixelSize: 13
            font.weight: Font.Black
        }
    }

    component WinRadio: Item {
        id: wr

        property bool checked: false
        property bool hot: false

        implicitWidth: 14
        implicitHeight: 14
        width: 14
        height: 14

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: root.v === "11" && wr.checked ? WinTheme.accent : (root.v === "10" ? "transparent" : "#ffffff")
            border.width: root.v === "10" ? 2 : 1
            border.color: root.v === "95" ? "#808080" : (root.v === "xp" ? "#1c5180" : (root.v === "7" ? "#8e8f8f" : (wr.checked && root.v === "11" ? WinTheme.accent : (wr.hot ? WinTheme.text : WinTheme.dim))))
        }
        Rectangle {
            anchors.centerIn: parent
            visible: wr.checked
            width: root.v === "10" ? 6 : (root.v === "11" ? 6 : 6)
            height: width
            radius: 3
            color: root.v === "xp" ? "#21a121" : (root.v === "11" ? "#ffffff" : (root.v === "10" ? WinTheme.text : (root.v === "7" ? "#1e395b" : "#000000")))
        }
    }

    component WinSwitch: Item {
        id: wsw

        property bool checked: false
        property bool hot: false

        readonly property bool sharp: root.v === "10"

        implicitWidth: sharp ? 44 : 40
        implicitHeight: sharp ? 20 : 20

        Rectangle {
            anchors.fill: parent
            radius: wsw.sharp ? 10 : 10
            color: wsw.checked ? WinTheme.accent : "transparent"
            border.width: wsw.checked ? 0 : (wsw.sharp ? 2 : 1)
            border.color: wsw.hot ? WinTheme.text : (WinTheme.dark ? "#cfcfcf" : "#5a5a5a")

            Behavior on color {
                ColorAnimation {
                    duration: 110
                }
            }
        }
        Rectangle {
            readonly property real d: wsw.hot ? 14 : 12

            anchors.verticalCenter: parent.verticalCenter
            x: wsw.checked ? wsw.width - d - 4 : 4
            width: d
            height: d
            radius: d / 2
            color: wsw.checked ? WinTheme.selText : (WinTheme.dark ? "#cfcfcf" : "#5a5a5a")

            Behavior on x {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 80
                }
            }
        }
    }

    // A trackbar: a groove and a thumb, per edition. Drag it or click on it.
    component WinTrack: Item {
        id: wt

        property real value: 0
        property bool interactive: false
        property real step: 0.01

        signal moved(real f)
        signal released

        implicitWidth: 110
        implicitHeight: root.old ? 20 : 22
        height: implicitHeight

        readonly property real thumbW: root.v === "95" ? 11 : (root.v === "xp" ? 11 : (root.v === "7" ? 12 : (root.v === "10" ? 8 : 16)))
        readonly property real thumbH: root.v === "95" ? 20 : (root.v === "xp" ? 21 : (root.v === "7" ? 20 : (root.v === "10" ? 18 : 16)))
        readonly property real tx: Math.max(0, Math.min(wt.width - wt.thumbW, (wt.width - wt.thumbW) * wt.value))

        // the groove
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root.v === "95" ? 4 : (root.v === "xp" ? 4 : (root.v === "7" ? 4 : (root.v === "10" ? 2 : 4)))
            radius: root.v === "11" ? 2 : 0
            color: root.v === "95" ? "#808080" : (root.v === "xp" ? "#e1e1d6" : (root.v === "7" ? "#e7eaea" : (WinTheme.dark ? "#9a9a9a" : "#666666")))
            border.width: root.v === "7" || root.v === "xp" ? 1 : 0
            border.color: root.v === "xp" ? "#aca899" : "#a8a8a8"
            opacity: root.v === "10" || root.v === "11" ? 0.5 : 1
        }
        // what is filled (10, 11)
        Rectangle {
            visible: root.v === "10" || root.v === "11"
            anchors.verticalCenter: parent.verticalCenter
            width: wt.tx + wt.thumbW / 2
            height: root.v === "10" ? 2 : 4
            radius: root.v === "11" ? 2 : 0
            color: WinTheme.accent
        }
        // the thumb
        WinBox {
            visible: root.classic
            x: wt.tx
            anchors.verticalCenter: parent.verticalCenter
            width: wt.thumbW
            height: wt.thumbH
            kind: "button"
            hot: wtArea.containsMouse
            pressed: wtArea.pressed
        }
        Rectangle {
            visible: root.v === "10"
            x: wt.tx
            anchors.verticalCenter: parent.verticalCenter
            width: wt.thumbW
            height: wt.thumbH
            color: wtArea.pressed ? WinTheme.accent : (wtArea.containsMouse ? (WinTheme.dark ? "#ffffff" : "#000000") : (WinTheme.dark ? "#cccccc" : "#333333"))
        }
        Rectangle {
            visible: root.v === "11"
            x: wt.tx
            anchors.verticalCenter: parent.verticalCenter
            width: wtArea.pressed ? 12 : wt.thumbW
            height: width
            radius: width / 2
            color: WinTheme.accent
            border.width: 3
            border.color: WinTheme.dark ? "#2d2d2d" : "#ffffff"

            Behavior on width {
                NumberAnimation {
                    duration: 80
                }
            }
        }

        MouseArea {
            id: wtArea

            anchors.fill: parent
            anchors.margins: -4
            enabled: wt.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            onPressed: mouse => wt.moved(Math.max(0, Math.min(1, (mouse.x - 4 - wt.thumbW / 2) / Math.max(1, wt.width - wt.thumbW))))
            onPositionChanged: mouse => {
                if (pressed)
                    wt.moved(Math.max(0, Math.min(1, (mouse.x - 4 - wt.thumbW / 2) / Math.max(1, wt.width - wt.thumbW))));
            }
            onReleased: wt.released()
        }
    }

    // − and + beside an open slider.
    component StepButton: Item {
        id: sb

        property string glyph: "+"

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        width: root.stepW
        height: root.old ? 22 : 28

        WinBox {
            anchors.fill: parent
            kind: "button"
            hot: sbArea.containsMouse
            pressed: sbArea.pressed

            P5Text {
                anchors.centerIn: parent
                text: sb.glyph
                color: WinTheme.text
                font.pixelSize: 14
                font.weight: Font.Bold
            }
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
}
