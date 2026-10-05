//  VELVET  ·  modules/lock/SoftInspector.qml
//  The SOFT lock's knobs, in one place — the pencil's panels on the lock
//  and the ARRANGE BY HAND editor in the settings show this same column.
//
//    section "element"  the element you picked: show/hide, its shape, what
//                       it turns into on hover, its corners, its size, its
//                       form, its place — and for
//                       the clock its style, size, digits, font and colours
//    section "global"   the layout, how everything arrives and moves, the
//                       blur and the visualizer, and every element's switch
//
//  It only reads and writes through the face (SoftFace.qml), which owns
//  the arrangement and knows which settings belong to which element.
import qs.config
import qs.services
import qs.components
import QtQuick

Column {
    id: root

    required property var face
    property string section: "element"
    property real u: 1

    readonly property string eid: root.face.selectedId !== "" ? root.face.selectedId : "clock"
    readonly property var est: root.face.st(root.eid)

    spacing: 10 * root.u

    // ═══════════════════════════════════════════════════════ the element
    Column {
        width: parent.width
        spacing: 10 * root.u
        visible: root.section === "element"

        Item {
            width: parent.width
            height: 30 * root.u

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.face.elementNames[root.eid] ?? root.eid
                color: Colours.ink
                font.family: Appearance.fontFamily.soft
                font.pixelSize: 16 * root.u
                font.weight: Font.DemiBold
            }

            SoftChip {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                u: root.u
                icon: root.face.shown(root.eid) ? "visibility" : "visibility_off"
                text: root.face.shown(root.eid) ? "Shown" : "Hidden"
                on: root.face.shown(root.eid)
                onClicked: root.face.setShown(root.eid, !root.face.shown(root.eid))
            }
        }

        // ── the clock's own
        Column {
            width: parent.width
            spacing: 10 * root.u
            visible: root.eid === "clock"

            Label {
                icon: "style"
                text: "Style"
                value: root.face.styles[root.face.styleIndex].name
            }
            Row {
                spacing: 6 * root.u

                SoftChip {
                    u: root.u
                    icon: "chevron_left"
                    onClicked: root.face.stepStyle(-1)
                }
                SoftChip {
                    u: root.u
                    text: root.face.styles[root.face.styleIndex].name
                    on: true
                }
                SoftChip {
                    u: root.u
                    icon: "chevron_right"
                    onClicked: root.face.stepStyle(1)
                }
            }
            Label {
                icon: "schedule"
                text: "Form"
            }
            Row {
                spacing: 6 * root.u

                Repeater {
                    model: [["full", "Digits"], ["hands", "Hands only"]]

                    SoftChip {
                        required property var modelData

                        u: root.u
                        text: modelData[1]
                        on: root.face.clockForm === modelData[0]
                        onClicked: root.face.setStyle("clock", "form", modelData[0])
                    }
                }
            }
            Label {
                icon: "zoom_in"
                text: "Clock size"
                value: `${Math.round(root.face.clockScale * 100)}%`
            }
            SoftSlider {
                width: parent.width
                u: root.u
                from: 0.5
                to: 1.4
                step: 0.05
                value: root.face.clockScale
                onMoved: v => root.face.setKey("lock.clockScale", v)
            }
            Label {
                icon: "format_size"
                text: "Digit size"
                value: `${Math.round(Config.lock.clockFontScale * 100)}%`
            }
            SoftSlider {
                width: parent.width
                u: root.u
                from: 0.6
                to: 1.6
                step: 0.05
                value: Config.lock.clockFontScale
                onMoved: v => root.face.setKey("lock.clockFontScale", v)
            }
            Label {
                icon: "font_download"
                text: "Clock font"
                value: root.face.analog ? "dots on the dial" : ""
            }
            Flow {
                width: parent.width
                spacing: 6 * root.u

                SoftChip {
                    u: root.u
                    text: "Primary"
                    on: !root.face.dots && (Config.lock.clockFont ?? "") === ""
                    dim: root.face.analog
                    onClicked: root.face.setMany({
                        "lock.clockFont": "",
                        "lock.clockFace": root.face.analog ? "analog" : ""
                    })
                }
                Repeater {
                    model: root.face.fontChoices

                    SoftChip {
                        required property string modelData

                        u: root.u
                        text: modelData
                        family: modelData
                        on: !root.face.dots && Config.lock.clockFont === modelData
                        dim: root.face.analog
                        onClicked: root.face.setMany({
                            "lock.clockFont": modelData,
                            "lock.clockFace": root.face.analog ? "analog" : ""
                        })
                    }
                }
                SoftChip {
                    u: root.u
                    text: "Dots"
                    on: root.face.dots
                    dim: root.face.analog
                    onClicked: {
                        if (!root.face.analog)
                            root.face.setKey("lock.clockFace", "dots");
                    }
                }
            }
            Label {
                icon: "palette"
                text: "Colours"
            }
            Row {
                spacing: 6 * root.u

                Repeater {
                    model: [["twotone", "Two-tone"], ["accent", "Accent"], ["ink", "White"]]

                    SoftChip {
                        required property var modelData

                        u: root.u
                        text: modelData[1]
                        on: Config.lock.clockColours === modelData[0]
                        onClicked: root.face.setKey("lock.clockColours", modelData[0])
                    }
                }
            }
        }

        // ── the music's form
        Column {
            width: parent.width
            spacing: 10 * root.u
            visible: root.eid === "media"

            Label {
                icon: "music_note"
                text: "Form"
            }
            Row {
                spacing: 6 * root.u

                Repeater {
                    model: [["pill", "Pill · opens a card"], ["card", "Card"]]

                    SoftChip {
                        required property var modelData

                        u: root.u
                        text: modelData[1]
                        on: root.face.mediaForm === modelData[0]
                        onClicked: root.face.setStyle("media", "form", modelData[0])
                    }
                }
            }
        }

        // ── any shape, on anything that has one
        Column {
            width: parent.width
            spacing: 8 * root.u
            visible: root.face.shapeable.indexOf(root.eid) >= 0

            Label {
                icon: "interests"
                text: root.eid === "media" ? "Cover shape" : (root.eid === "clock" ? "Shape" : "Shape")
                value: root.eid === "clock" && root.face.clockForm === "full" && !root.face.dialClock ? "the style decides" : ""
            }
            Flow {
                width: parent.width
                spacing: 6 * root.u

                Repeater {
                    model: Appearance.shapeKinds

                    Rectangle {
                        id: sh

                        required property var modelData
                        readonly property bool lit: root.face.shapeOf(root.eid) === sh.modelData.v

                        width: 38 * root.u
                        height: 38 * root.u
                        radius: 10 * root.u
                        color: sh.lit ? Colours.alpha(Colours.accent, 0.25) : (shHover.hovered ? Colours.alpha(Colours.ink, 0.12) : Colours.alpha(Colours.ink, 0.04))
                        border.width: sh.lit ? 1.5 : 1
                        border.color: sh.lit ? Colours.accent : Colours.alpha(Colours.ink, 0.1)
                        antialiasing: true

                        M3Shape {
                            anchors.centerIn: parent
                            width: 24 * root.u
                            height: 24 * root.u
                            kind: sh.modelData.v
                            color: sh.lit ? Colours.accent : Colours.alpha(Colours.ink, 0.75)
                            intro: false
                            motion: false
                        }

                        HoverHandler {
                            id: shHover

                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: {
                                Sfx.select();
                                root.face.setShape(root.eid, sh.modelData.v);
                            }
                        }
                    }
                }
            }
        }

        // ── what it turns into under the pointer
        Column {
            width: parent.width
            spacing: 8 * root.u
            visible: root.face.shapeable.indexOf(root.eid) >= 0 && (root.eid !== "clock" || root.face.dialClock || root.face.clockForm === "hands")

            Label {
                icon: "auto_awesome"
                text: "On hover"
                value: !Config.lock.softHoverMorph ? "off for all — see Everything" : ((root.est.hover ?? "") === "none" ? "stays" : "")
            }
            Flow {
                width: parent.width
                spacing: 6 * root.u
                opacity: Config.lock.softHoverMorph ? 1 : 0.45

                SoftChip {
                    u: root.u
                    text: "Auto"
                    on: (root.est.hover ?? "") === ""
                    onClicked: root.face.setStyle(root.eid, "hover", "")
                }
                SoftChip {
                    u: root.u
                    text: "Stay"
                    on: (root.est.hover ?? "") === "none"
                    onClicked: root.face.setStyle(root.eid, "hover", "none")
                }

                Repeater {
                    model: Appearance.shapeKinds

                    Rectangle {
                        id: hv

                        required property var modelData
                        readonly property bool lit: (root.est.hover ?? "") === hv.modelData.v

                        width: 38 * root.u
                        height: 38 * root.u
                        radius: 10 * root.u
                        color: hv.lit ? Colours.alpha(Colours.accent, 0.25) : (hvHover.hovered ? Colours.alpha(Colours.ink, 0.12) : Colours.alpha(Colours.ink, 0.04))
                        border.width: hv.lit ? 1.5 : 1
                        border.color: hv.lit ? Colours.accent : Colours.alpha(Colours.ink, 0.1)
                        antialiasing: true

                        M3Shape {
                            anchors.centerIn: parent
                            width: 24 * root.u
                            height: 24 * root.u
                            // The chip shows the morph too, under the pointer.
                            kind: hvHover.hovered ? Appearance.hoverPartner(hv.modelData.v) : hv.modelData.v
                            color: hv.lit ? Colours.accent : Colours.alpha(Colours.ink, 0.75)
                            intro: false
                        }

                        HoverHandler {
                            id: hvHover

                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: {
                                Sfx.select();
                                root.face.setStyle(root.eid, "hover", hv.modelData.v);
                            }
                        }
                    }
                }
            }
        }

        // ── corners, for the pills
        Column {
            width: parent.width
            spacing: 8 * root.u
            visible: root.face.cornered.indexOf(root.eid) >= 0

            Label {
                icon: "rounded_corner"
                text: "Corners"
            }
            Row {
                spacing: 6 * root.u

                Repeater {
                    model: [["round", "Round"], ["soft", "Soft"], ["square", "Square"]]

                    SoftChip {
                        required property var modelData

                        u: root.u
                        text: modelData[1]
                        on: (root.est.corners ?? "round") === modelData[0]
                        onClicked: root.face.setStyle(root.eid, "corners", modelData[0])
                    }
                }
            }
        }

        // ── colour: the element's fill and the colour of its icons
        Column {
            width: parent.width
            spacing: 8 * root.u
            visible: root.eid !== "lyric"

            Label {
                icon: "palette"
                text: "Colour"
                value: ({
                        "": "Tone",
                        tint: "Tint",
                        accent: "Accent",
                        glass: "Glass",
                        black: "Black"
                    })[root.est.fill ?? ""] ?? "Tone"
            }
            Row {
                spacing: 8 * root.u

                Repeater {
                    model: [["", "Tone"], ["tint", "Tint"], ["accent", "Accent"], ["glass", "Glass"], ["black", "Black"]]

                    Item {
                        id: sw

                        required property var modelData
                        readonly property bool lit: (root.est.fill ?? "") === sw.modelData[0]

                        width: 38 * root.u
                        height: 50 * root.u

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 30 * root.u
                            height: width
                            radius: width / 2
                            color: root.face.fillFor(sw.modelData[0])
                            border.width: sw.lit ? 2.5 * root.u : 1
                            border.color: sw.lit ? Colours.accent : Colours.alpha(Colours.ink, swHover.hovered ? 0.6 : 0.25)
                            scale: swHover.hovered ? 1.08 : 1
                            antialiasing: true

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: sw.modelData[1]
                            color: sw.lit ? Colours.accent : Colours.alpha(Colours.ink, 0.6)
                            font.family: Appearance.fontFamily.soft
                            font.pixelSize: 10 * root.u
                        }
                        HoverHandler {
                            id: swHover

                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: {
                                Sfx.select();
                                root.face.setStyle(root.eid, "fill", sw.modelData[0]);
                            }
                        }
                    }
                }
            }
            Row {
                spacing: 6 * root.u

                Repeater {
                    model: [["", "Icons: auto"], ["accent", "Accent"], ["ink", "White"]]

                    SoftChip {
                        required property var modelData

                        u: root.u
                        text: modelData[1]
                        on: (root.est.hi ?? "") === modelData[0]
                        onClicked: root.face.setStyle(root.eid, "hi", modelData[0])
                    }
                }
            }
            SoftChip {
                u: root.u
                text: "Use for all"
                onClicked: {
                    Sfx.select();
                    root.face.setStyleAll("fill", root.est.fill ?? "");
                    root.face.setStyleAll("hi", root.est.hi ?? "");
                }
            }
        }

        // ── how solid all of them are (lock.softOpacity)
        Column {
            width: parent.width
            spacing: 8 * root.u

            Label {
                icon: "opacity"
                text: "All modules: opacity"
                value: `${Math.round(Number(Config.lock.softOpacity ?? 1) * 100)}%`
            }
            SoftSlider {
                width: parent.width
                u: root.u
                from: 0.2
                to: 1
                step: 0.05
                value: Number(Config.lock.softOpacity ?? 1)
                onMoved: v => root.face.setMany({
                        "lock.softOpacity": v
                    })
            }
        }

        // ── size, for everything but the clock (that has its own)
        Column {
            width: parent.width
            spacing: 8 * root.u
            visible: root.eid !== "clock"

            Label {
                icon: "open_in_full"
                text: "Size"
                value: `${Math.round((root.est.scale ?? 1) * 100)}%`
            }
            SoftSlider {
                width: parent.width
                u: root.u
                from: 0.5
                to: 2
                step: 0.05
                value: root.est.scale ?? 1
                onMoved: v => root.face.setStyle(root.eid, "scale", v)
            }
        }

        // ── the place
        Row {
            spacing: 6 * root.u

            SoftChip {
                u: root.u
                icon: "center_focus_strong"
                text: "Centre it"
                onClicked: root.face.centre(root.eid)
            }
            SoftChip {
                u: root.u
                icon: "restart_alt"
                text: "Reset"
                onClicked: root.face.resetElement(root.eid)
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Drag any element to move it · arrow keys nudge the picked one · a click picks another"
            color: Colours.alpha(Colours.ink, 0.5)
            font.family: Appearance.fontFamily.soft
            font.pixelSize: 11 * root.u
        }
    }

    // ═══════════════════════════════════════════════════════ everything
    Column {
        width: parent.width
        spacing: 10 * root.u
        visible: root.section === "global"

        Label {
            icon: "view_quilt"
            text: "Layout"
            value: root.face.layout === "custom" ? "arranged by hand" : ""
        }
        Flow {
            width: parent.width
            spacing: 6 * root.u

            Repeater {
                model: [["vertical", "Vertical"], ["horizontal", "Horizontal"], ["greeting", "Greeting"], ["custom", "Custom"]]

                SoftChip {
                    required property var modelData

                    u: root.u
                    text: modelData[1]
                    on: root.face.layout === modelData[0]
                    onClicked: root.face.setKey("lock.layout", modelData[0])
                }
            }
        }

        Label {
            icon: "animation"
            text: "Entrance"
        }
        Flow {
            width: parent.width
            spacing: 6 * root.u

            Repeater {
                model: [["rise", "Rise"], ["fade", "Fade"], ["zoom", "Zoom"], ["drop", "Drop"], ["pop", "Pop"], ["spin", "Spin"], ["slide", "Slide"]]

                SoftChip {
                    required property var modelData

                    u: root.u
                    text: modelData[1]
                    on: Config.lock.softAnimation === modelData[0]
                    onClicked: {
                        root.face.setKey("lock.softAnimation", modelData[0]);
                        root.face.replay();
                    }
                }
            }
        }
        Label {
            icon: "speed"
            text: "Speed"
            value: `${Math.round(100 / Math.max(0.25, Config.lock.animationScale))}%`
        }
        SoftSlider {
            width: parent.width
            u: root.u
            from: 2
            to: 0.25
            step: 0.05
            value: Config.lock.animationScale
            onMoved: v => root.face.setKey("lock.animationScale", v)
        }
        Label {
            icon: "stacks"
            text: "One after another"
            value: `${Math.round(Math.min(0.14, Config.lock.softStagger) * 1100 * Math.max(0.25, Config.lock.animationScale))} ms`
        }
        SoftSlider {
            width: parent.width
            u: root.u
            from: 0
            to: 0.14
            step: 0.01
            value: Config.lock.softStagger
            onMoved: v => root.face.setKey("lock.softStagger", v)
        }

        Toggle {
            icon: "moving"
            text: "Glide to new places"
            on: Config.lock.softGlide
            onFlip: root.face.setKey("lock.softGlide", !Config.lock.softGlide)
        }
        Toggle {
            icon: "rotate_right"
            text: "Shapes turn slowly"
            on: Config.lock.softShapeSpin
            onFlip: root.face.setKey("lock.softShapeSpin", !Config.lock.softShapeSpin)
        }
        Toggle {
            icon: "auto_awesome"
            text: "Shapes change on hover"
            on: Config.lock.softHoverMorph
            onFlip: root.face.setKey("lock.softHoverMorph", !Config.lock.softHoverMorph)
        }
        Label {
            icon: "123"
            text: "Digits change"
        }
        Row {
            spacing: 6 * root.u

            Repeater {
                model: [["roll", "Roll"], ["fade", "Fade"], ["none", "Snap"]]

                SoftChip {
                    required property var modelData

                    u: root.u
                    text: modelData[1]
                    on: Config.lock.softDigitMotion === modelData[0]
                    onClicked: root.face.setKey("lock.softDigitMotion", modelData[0])
                }
            }
        }

        Label {
            icon: "blur_on"
            text: "Blur level"
            value: `${Math.round(Config.lock.blur * 100)}%`
        }
        SoftSlider {
            width: parent.width
            u: root.u
            from: 0
            to: 1
            step: 0.05
            value: Config.lock.blur
            onMoved: v => root.face.setKey("lock.blur", v)
        }
        Toggle {
            icon: "graphic_eq"
            text: "Cava visualizer"
            on: Config.lock.visualizer
            onFlip: root.face.setKey("lock.visualizer", !Config.lock.visualizer)
        }
        Grid {
            columns: 4
            spacing: 6 * root.u
            opacity: Config.lock.visualizer ? 1 : 0.45

            Repeater {
                model: [["top", "Top"], ["bottom", "Bottom"], ["left", "Left"], ["right", "Right"], ["bars", "Bars"], ["wave", "Wave"], ["line", "Line"]]

                SoftChip {
                    required property var modelData
                    required property int index

                    u: root.u
                    text: modelData[1]
                    on: index < 4 ? Config.lock.visualizerEdge === modelData[0] : Config.lock.visualizerStyle === modelData[0]
                    onClicked: root.face.setKey(index < 4 ? "lock.visualizerEdge" : "lock.visualizerStyle", modelData[0])
                }
            }
        }

        Label {
            icon: "category"
            text: "Elements"
            value: "click to show or hide"
        }
        Flow {
            width: parent.width
            spacing: 6 * root.u

            Repeater {
                model: root.face.elementIds

                SoftChip {
                    required property string modelData

                    u: root.u
                    text: root.face.elementNames[modelData]
                    on: root.face.shown(modelData)
                    onClicked: {
                        root.face.setShown(modelData, !root.face.shown(modelData));
                        root.face.selectedId = modelData;
                    }
                }
            }
        }

        SoftChip {
            u: root.u
            icon: "restart_alt"
            text: "Reset the whole arrangement"
            onClicked: root.face.resetAll()
        }
    }

    // ═══════════════════════════════════════════════════════ the parts
    component Label: Item {
        id: lb

        property string icon: ""
        property string text: ""
        property string value: ""

        width: root.width
        height: 20 * root.u

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.u

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: lb.icon !== ""
                name: lb.icon
                color: Colours.alpha(Colours.ink, 0.8)
                font.pixelSize: 15 * root.u
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: lb.text
                color: Colours.ink
                font.family: Appearance.fontFamily.soft
                font.pixelSize: 13 * root.u
                font.weight: Font.Medium
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: lb.value
            color: Colours.alpha(Colours.ink, 0.55)
            font.family: Appearance.fontFamily.soft
            font.pixelSize: 11 * root.u
        }
    }

    component Toggle: Item {
        id: tg

        property string icon: ""
        property string text: ""
        property bool on: false

        signal flip

        width: root.width
        height: 24 * root.u

        Label {
            anchors.verticalCenter: parent.verticalCenter
            icon: tg.icon
            text: tg.text
        }
        SoftSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            u: root.u
            on: tg.on
            onClicked: tg.flip()
        }
    }
}
