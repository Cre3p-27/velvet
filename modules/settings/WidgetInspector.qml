//  VELVET  ·  modules/settings/WidgetInspector.qml
//  Everything one desktop widget can be, on one scrollable card — every
//  choice laid out where you can see it instead of hidden behind "click to
//  cycle". Every change is written to the wallpaper's own desk at once and
//  the widget on the wallpaper follows live, so what you pick here is what
//  comes back whenever this wallpaper does.
//
//    LOOK            frame · silhouette · tone · colour · opacity · details
//    SIZE & PLACE    size presets and nudges · nine spots on the screen
//    <WIDGET>        what only this widget has (hours, a name, CPU/RAM …)
//    POINTER         live (hover + clicks) or still (a picture)
//    duplicate · reset · remove
import qs.config
import qs.services
import qs.components
import qs.modules.wallpaper as WP
import QtQuick

Flickable {
    id: root

    required property var item      // the chosen scene entry (kind "widget")
    required property int itemIndex // its place in Scenes.editing

    // A text field has the keyboard: the designer must not take Backspace
    // or the arrows for itself (Backspace there deletes the widget).
    readonly property bool typing: nameField.activeFocus

    signal picked(int index)
    signal removeRequested()

    readonly property var opts: root.item?.opts ?? ({})
    readonly property string wid: root.item?.widget ?? ""
    readonly property string frameNow: {
        const o = root.opts.frame ?? "auto";
        return o === "auto" ? Config.wallpaper.livingChips : o;
    }
    readonly property bool shaped: root.frameNow === "shapes"
    // SOFT draws the clock, weather, media, calendar and greeting its own
    // way; their silhouette can still be picked.
    readonly property bool softened: root.frameNow === "soft"
    readonly property bool pastel: ((root.opts.tone ?? "") !== "" ? root.opts.tone : Config.wallpaper.shapeTone) === "pastel"

    contentWidth: width
    contentHeight: col.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    function set(key: string, value: var): void {
        const patch = {};
        patch[key] = value;
        Scenes.patchAt(root.itemIndex, {
            opts: Object.assign({}, root.opts, patch)
        });
        Sfx.toggle();
    }

    // The box is the widget's size: resize it about its centre, keep it on
    // the screen.
    function resize(k: real): void {
        const it = root.item;
        if (!it)
            return;
        const w = Math.max(0.06, Math.min(1, (it.w ?? 0.24) * k));
        const h = Math.max(0.06, Math.min(1, (it.h ?? 0.2) * k));
        const cx = (it.x ?? 0) + (it.w ?? 0.24) / 2;
        const cy = (it.y ?? 0) + (it.h ?? 0.2) / 2;
        Scenes.patchAt(root.itemIndex, {
            x: Math.max(0, Math.min(1 - w, cx - w / 2)),
            y: Math.max(0, Math.min(1 - h, cy - h / 2)),
            w: w,
            h: h
        });
        Sfx.toggle();
    }

    function sizeTo(k: real): void {
        const it = root.item;
        if (!it)
            return;
        root.resize(k * 0.24 / Math.max(0.01, it.w ?? 0.24));
    }

    // Nine spots: the corners, the edges' middles and the centre.
    function place(col: int, row: int): void {
        const it = root.item;
        if (!it)
            return;
        const w = it.w ?? 0.24;
        const h = it.h ?? 0.2;
        const x = col === 0 ? 0.02 : (col === 1 ? (1 - w) / 2 : 1 - w - 0.02);
        const y = row === 0 ? 0.04 : (row === 1 ? (1 - h) / 2 : 1 - h - 0.04);
        Scenes.patchAt(root.itemIndex, {
            x: Math.max(0, Math.min(1 - w, x)),
            y: Math.max(0, Math.min(1 - h, y))
        });
        Sfx.toggle();
    }

    readonly property int spotCol: {
        const cx = (root.item?.x ?? 0) + (root.item?.w ?? 0.24) / 2;
        return cx < 0.36 ? 0 : (cx > 0.64 ? 2 : 1);
    }
    readonly property int spotRow: {
        const cy = (root.item?.y ?? 0) + (root.item?.h ?? 0.2) / 2;
        return cy < 0.36 ? 0 : (cy > 0.64 ? 2 : 1);
    }

    function duplicate(): void {
        const it = root.item;
        if (!it)
            return;
        const copy = JSON.parse(JSON.stringify(it));
        delete copy.id;
        const w = copy.w ?? 0.24;
        const h = copy.h ?? 0.2;
        copy.x = Math.max(0, Math.min(1 - w, (copy.x ?? 0) + 0.03));
        copy.y = Math.max(0, Math.min(1 - h, (copy.y ?? 0) + 0.04));
        Scenes.add(copy);
        root.picked(Scenes.editing.length - 1);
        Toast.ok(`${(Scenes.labelFor(it) || "WIDGET").toUpperCase()} DUPLICATED`);
    }

    // What only this widget has.
    readonly property bool hasOwn: ["clock", "greeting", "user", "resources", "media"].indexOf(root.wid) !== -1

    Column {
        id: col

        width: root.width
        spacing: 16

        // ═════════════════════════════════════════════════════════════ LOOK
        InsSection {
            title: "LOOK"
            note: root.softened ? "ROUND MATERIAL PIECES IN THE ACCENT'S DEEP TONE" : (root.shaped ? "SOFT SHAPES IN THE WALLPAPER'S COLOURS" : (root.frameNow === "glass" ? "FROSTED GLASS" : (root.frameNow === "ink" ? "GROUNDED BLACK" : "STRAIGHT ON THE PICTURE")))
        }

        InsOption {
            label: "FRAME"

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: "auto",
                        t: `AUTO · ${String(Config.wallpaper.livingChips).toUpperCase()}`
                    },
                    {
                        v: "shapes",
                        t: "SHAPES"
                    },
                    {
                        v: "soft",
                        t: "SOFT"
                    },
                    {
                        v: "glass",
                        t: "GLASS"
                    },
                    {
                        v: "ink",
                        t: "INK"
                    },
                    {
                        v: "raw",
                        t: "RAW"
                    }
                ]
                current: root.opts.frame ?? "auto"
                onChosen: v => root.set("frame", v)
            }
        }

        InsOption {
            label: root.softened && root.wid === "media" ? "COVER SHAPE" : "SHAPE"
            visible: root.shaped || (root.softened && ["clock", "calendar", "greeting", "weather", "media"].indexOf(root.wid) >= 0)

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    // AUTO is the widget's own (the soft weather's slanted
                    // pill, the cover's wavy frame); then every shape.
                    model: [""].concat(Appearance.shapeKinds.map(k => k.v))

                    Item {
                        id: sw

                        required property string modelData
                        readonly property bool lit: (root.opts.shape ?? "") === sw.modelData

                        width: 40
                        height: 40

                        Plate {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: sw.lit ? Colours.alpha(Colours.accent, 0.22) : Colours.alpha(Colours.ink, swArea.containsMouse ? 0.12 : 0.05)
                            border.width: sw.lit ? 1.5 : 1
                            border.color: sw.lit ? Colours.accent : Colours.alpha(Colours.ink, 0.1)
                            antialiasing: true
                        }

                        M3Shape {
                            anchors.centerIn: parent
                            visible: sw.modelData !== ""
                            width: 26
                            height: 26
                            kind: sw.modelData !== "" ? sw.modelData : "circle"
                            color: sw.lit ? Colours.accent : Colours.alpha(Colours.ink, 0.7)
                            intro: false
                            motion: false
                        }

                        P5Text {
                            anchors.centerIn: parent
                            visible: sw.modelData === ""
                            text: "AUTO"
                            color: sw.lit ? Colours.accent : Colours.inkDim
                            font.pixelSize: Appearance.font.size.tiny - 1
                            tracking: 0.6
                        }

                        MouseArea {
                            id: swArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.set("shape", sw.modelData)
                        }
                    }
                }
            }
        }

        // What the shape turns into under the pointer (SHAPES CHANGE ON
        // HOVER under WALLPAPER): AUTO a partner, STAY none, or any shape.
        InsOption {
            label: Config.wallpaper.shapeHoverMorph ? "HOVER SHAPE" : "HOVER SHAPE · OFF FOR ALL (WALLPAPER)"
            visible: root.shaped || (root.softened && ["clock", "calendar", "greeting", "weather", "media"].indexOf(root.wid) >= 0)

            Flow {
                width: parent.width
                spacing: 6
                opacity: Config.wallpaper.shapeHoverMorph ? 1 : 0.5

                Repeater {
                    model: ["", "none"].concat(Appearance.shapeKinds.map(k => k.v))

                    Item {
                        id: hw

                        required property string modelData
                        readonly property bool word: hw.modelData === "" || hw.modelData === "none"
                        readonly property bool lit: (root.opts.hoverShape ?? "") === hw.modelData

                        width: hw.word ? 52 : 40
                        height: 40

                        Plate {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: hw.lit ? Colours.alpha(Colours.accent, 0.22) : Colours.alpha(Colours.ink, hwArea.containsMouse ? 0.12 : 0.05)
                            border.width: hw.lit ? 1.5 : 1
                            border.color: hw.lit ? Colours.accent : Colours.alpha(Colours.ink, 0.1)
                            antialiasing: true
                        }

                        M3Shape {
                            anchors.centerIn: parent
                            visible: !hw.word
                            width: 26
                            height: 26
                            // The chip shows the morph itself under the pointer.
                            kind: hw.word ? "circle" : (hwArea.containsMouse ? Appearance.hoverPartner(hw.modelData) : hw.modelData)
                            color: hw.lit ? Colours.accent : Colours.alpha(Colours.ink, 0.7)
                            intro: false
                        }

                        P5Text {
                            anchors.centerIn: parent
                            visible: hw.word
                            text: hw.modelData === "" ? "AUTO" : "STAY"
                            color: hw.lit ? Colours.accent : Colours.inkDim
                            font.pixelSize: Appearance.font.size.tiny - 1
                            tracking: 0.6
                        }

                        MouseArea {
                            id: hwArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.set("hoverShape", hw.modelData)
                        }
                    }
                }
            }
        }

        InsOption {
            label: "TONE"
            visible: root.shaped

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: "",
                        t: `AUTO · ${String(Config.wallpaper.shapeTone).toUpperCase()}`
                    },
                    {
                        v: "deep",
                        t: "DEEP"
                    },
                    {
                        v: "pastel",
                        t: "PASTEL"
                    }
                ]
                current: root.opts.tone ?? ""
                onChosen: v => root.set("tone", v)
            }
        }

        InsOption {
            label: "COLOUR"
            visible: root.shaped

            Row {
                spacing: 8

                Repeater {
                    model: 3

                    Item {
                        id: tone

                        required property int index
                        readonly property bool lit: (((root.opts.slot ?? 0) % 3) + 3) % 3 === tone.index
                        readonly property var bases: WP.WidgetActions.bases(root.pastel)

                        width: 58
                        height: 40

                        Plate {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: tone.bases[tone.index]
                            border.width: tone.lit ? 2 : 1
                            border.color: tone.lit ? Colours.accent : Colours.alpha(Colours.ink, toneArea.containsMouse ? 0.4 : 0.14)
                            antialiasing: true

                            // The other two tones this choice pairs with.
                            Row {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 5
                                spacing: 3

                                Repeater {
                                    model: 2

                                    Rectangle {
                                        required property int index

                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: tone.bases[(tone.index + 1 + index) % 3]
                                        border.width: 1
                                        border.color: Colours.alpha(Colours.ink, 0.25)
                                    }
                                }
                            }
                        }

                        Icon {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 4
                            visible: tone.lit
                            name: "check"
                            color: Colours.ink
                            font.pixelSize: 14
                        }

                        MouseArea {
                            id: toneArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.set("slot", tone.index)
                        }
                    }
                }
            }
        }

        InsOption {
            label: "OPACITY"

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: -1,
                        t: `AUTO · ${Math.round(Config.wallpaper.livingOpacity * 100)}%`
                    },
                    {
                        v: 0.4,
                        t: "40%"
                    },
                    {
                        v: 0.6,
                        t: "60%"
                    },
                    {
                        v: 0.8,
                        t: "80%"
                    },
                    {
                        v: 1,
                        t: "SOLID"
                    }
                ]
                current: root.opts.opacity ?? -1
                onChosen: v => root.set("opacity", v)
            }
        }

        InsOption {
            label: "DETAILS"
            note: "THE SMALL LINE · DATE, SSID, ARTIST, HOSTNAME …"

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: true,
                        t: "SHOWN"
                    },
                    {
                        v: false,
                        t: "HIDDEN"
                    }
                ]
                current: root.opts.details ?? true
                onChosen: v => root.set("details", v)
            }
        }

        // ═════════════════════════════════════════════════════ SIZE & PLACE
        InsSection {
            title: "SIZE & PLACE"
            note: "OR DRAG IT ON THE PICTURE · PULL ITS CORNER"
        }

        InsOption {
            label: "SIZE"

            Row {
                width: parent.width
                spacing: 6

                InsChip {
                    text: "−"
                    width: 34
                    onClicked: root.resize(1 / 1.12)
                }

                Repeater {
                    model: [
                        {
                            k: 0.7,
                            t: "S"
                        },
                        {
                            k: 1,
                            t: "M"
                        },
                        {
                            k: 1.35,
                            t: "L"
                        },
                        {
                            k: 1.75,
                            t: "XL"
                        }
                    ]

                    InsChip {
                        required property var modelData

                        width: 40
                        text: modelData.t
                        lit: Math.abs((root.item?.w ?? 0.24) / 0.24 - modelData.k) < 0.06
                        onClicked: root.sizeTo(modelData.k)
                    }
                }

                InsChip {
                    text: "+"
                    width: 34
                    onClicked: root.resize(1.12)
                }
            }
        }

        InsOption {
            label: "PLACE"

            Row {
                spacing: 14

                // A little screen with nine spots on it.
                Plate {
                    width: 96
                    height: 60
                    radius: Appearance.rounding.small
                    color: Colours.alpha(Colours.ink, 0.05)
                    border.width: 1
                    border.color: Colours.alpha(Colours.ink, 0.14)
                    antialiasing: true

                    Grid {
                        anchors.fill: parent
                        anchors.margins: 4
                        columns: 3
                        rows: 3

                        Repeater {
                            model: 9

                            Item {
                                id: spot

                                required property int index
                                readonly property int c: spot.index % 3
                                readonly property int r: Math.floor(spot.index / 3)
                                readonly property bool lit: spot.c === root.spotCol && spot.r === root.spotRow

                                width: (96 - 8) / 3
                                height: (60 - 8) / 3

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: spot.lit ? 18 : (spotArea.containsMouse ? 14 : 8)
                                    height: spot.lit ? 10 : (spotArea.containsMouse ? 8 : 5)
                                    radius: 2
                                    color: spot.lit ? Colours.accent : Colours.alpha(Colours.ink, spotArea.containsMouse ? 0.7 : 0.3)
                                    antialiasing: true

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Appearance.anim.fast
                                        }
                                    }
                                }

                                MouseArea {
                                    id: spotArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.place(spot.c, spot.r)
                                }
                            }
                        }
                    }
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: col.width - 96 - 14 - 90
                    wrapMode: Text.WordWrap
                    text: "CLICK A SPOT TO SEND IT THERE"
                    color: Colours.alpha(Colours.inkDim, 0.75)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.2
                }
            }
        }

        // ══════════════════════════════════════════ what only this one has
        InsSection {
            visible: root.hasOwn
            title: `${(Scenes.labelFor(root.item) || root.wid).toUpperCase()} ONLY`
            note: "OPTIONS NO OTHER WIDGET HAS"
        }

        InsOption {
            label: "HOURS"
            visible: root.wid === "clock"

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: "",
                        t: `AUTO · ${Config.bar.clock.format24h ? "24H" : "12H"}`
                    },
                    {
                        v: "24",
                        t: "24H"
                    },
                    {
                        v: "12",
                        t: "12H"
                    }
                ]
                current: root.opts.hours ?? ""
                onChosen: v => root.set("hours", v)
            }
        }

        InsOption {
            label: root.wid === "greeting" ? "YOUR NAME" : "NAME SHOWN"
            note: `EMPTY = ${String(SysInfo.user).toUpperCase()}`
            visible: root.wid === "greeting" || root.wid === "user"

            Plate {
                width: parent.width
                height: 32
                radius: Appearance.rounding.small
                color: Colours.alpha(Colours.ink, nameField.activeFocus ? 0.12 : 0.06)
                border.width: 1
                border.color: nameField.activeFocus ? Colours.accent : Colours.alpha(Colours.ink, 0.14)
                antialiasing: true

                TextInput {
                    id: nameField

                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colours.ink
                    selectionColor: Colours.alpha(Colours.accent, 0.5)
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: Appearance.font.size.small
                    maximumLength: 32
                    clip: true

                    // Follows the widget you pick; typing saves after a beat.
                    readonly property string saved: root.opts.name ?? ""
                    onSavedChanged: if (!nameField.activeFocus)
                        nameField.text = nameField.saved
                    Component.onCompleted: nameField.text = nameField.saved
                    onTextEdited: nameSave.restart()
                    onEditingFinished: {
                        nameSave.stop();
                        if (nameField.text !== nameField.saved)
                            root.set("name", nameField.text.trim());
                    }
                    Keys.onEscapePressed: event => {
                        nameField.text = nameField.saved;
                        nameField.focus = false;
                        event.accepted = true;
                    }

                    Timer {
                        id: nameSave

                        interval: 600
                        onTriggered: {
                            if (nameField.text.trim() !== nameField.saved)
                                root.set("name", nameField.text.trim());
                        }
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: nameField.text === "" && !nameField.activeFocus
                        text: String(SysInfo.user)
                        color: Colours.alpha(Colours.inkDim, 0.55)
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }

        InsOption {
            label: "SHOW"
            visible: root.wid === "resources"

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: "both",
                        t: "CPU + RAM"
                    },
                    {
                        v: "cpu",
                        t: "CPU"
                    },
                    {
                        v: "ram",
                        t: "RAM"
                    }
                ]
                current: root.opts.show ?? ((root.opts.details ?? true) ? "both" : "cpu")
                onChosen: v => root.set("show", v)
            }
        }

        InsOption {
            label: "CONTROLS"
            note: "PREVIOUS · NEXT · TIME ON THE CARD"
            visible: root.wid === "media"

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: "hover",
                        t: "ON HOVER"
                    },
                    {
                        v: "always",
                        t: "ALWAYS"
                    }
                ]
                current: root.opts.controls ?? "hover"
                onChosen: v => root.set("controls", v)
            }
        }

        // ══════════════════════════════════════════════════════════ POINTER
        InsSection {
            title: "POINTER"
            note: (root.opts.pointer ?? "live") === "still" ? "A PICTURE · CLICKS GO THROUGH TO THE DESKTOP" : "LIGHTS UP UNDER THE POINTER · CLICK TO USE · RIGHT-CLICK TO EDIT"
        }

        InsChoice {
            width: parent.width
            model: [
                {
                    v: "live",
                    t: "LIVE"
                },
                {
                    v: "still",
                    t: "STILL"
                }
            ]
            current: root.opts.pointer ?? "live"
            onChosen: v => root.set("pointer", v)
        }

        // ══════════════════════════════════════════════════════════ actions
        Row {
            width: parent.width
            spacing: 6
            topPadding: 4

            InsChip {
                width: (parent.width - 12) / 3
                height: 32
                glyph: "content_copy"
                text: "DUPLICATE"
                onClicked: root.duplicate()
            }
            InsChip {
                width: (parent.width - 12) / 3
                height: 32
                glyph: "restart_alt"
                text: "RESET"
                onClicked: {
                    Scenes.patchAt(root.itemIndex, {
                        opts: {}
                    });
                    Sfx.toggle();
                    Toast.ok("LOOK RESET · FOLLOWS WALLPAPER → LIVING DESKTOP");
                }
            }
            InsChip {
                width: (parent.width - 12) / 3
                height: 32
                glyph: "delete"
                text: "REMOVE"
                danger: true
                onClicked: root.removeRequested()
            }
        }
    }

    SmoothScroll {
        view: root
    }
}
