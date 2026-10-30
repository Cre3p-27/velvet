//  VELVET  ·  modules/wallpaper/WidgetMenuCard.qml
//  What a right-click on a desktop widget offers, right where it is: its size,
//  how see-through it is and its look change the widget live while the card
//  stays up; then move it (ARRANGE), make it a still picture, duplicate it,
//  open every option it has (DESKTOP, this widget picked) or take it off — a
//  second click confirms that one. It used to send you to the whole DESKTOP
//  tab for anything at all.
import qs.config
import qs.services
import qs.components
import QtQuick

Plate {
    id: root

    property string widgetId: ""
    property bool entered: true

    // the widget as the live desk has it now
    readonly property var item: Scenes.items.find(it => it && it.id === root.widgetId) ?? null
    readonly property var opts: root.item?.opts ?? ({})
    readonly property string wid: root.item?.widget ?? ""
    readonly property var meta: {
        const m = LockModules.all.find(x => x.id === root.wid);
        if (m)
            return m;
        return root.wid === "calendar" ? {
            id: "calendar",
            name: "CALENDAR",
            glyph: "calendar_month"
        } : {
            id: root.wid,
            name: (root.item?.name ?? "WIDGET").toUpperCase(),
            glyph: "widgets"
        };
    }
    readonly property string frameNow: root.opts.frame ?? "auto"
    readonly property real opacityNow: (root.opts.opacity ?? -1) >= 0 ? root.opts.opacity : Config.wallpaper.livingOpacity
    readonly property bool still: (root.opts.pointer ?? "live") === "still"
    property bool confirmOff: false

    signal done

    width: 400
    height: body.height + 2 * Appearance.spacing.normal
    radius: Appearance.rounding.normal
    color: Colours.alpha(Colours.paper, 0.95)
    border.width: 2
    border.color: Colours.alpha(Colours.accent, 0.85)

    onWidgetIdChanged: root.confirmOff = false
    onEnteredChanged: {
        if (!root.entered)
            root.confirmOff = false;
    }

    function patch(fields: var): void {
        if (root.widgetId !== "")
            Scenes.patchLive(root.widgetId, fields);
    }

    function setOpt(key: string, value: var): void {
        const next = Object.assign({}, root.opts);
        next[key] = value;
        root.patch({
            opts: next
        });
        Sfx.toggle();
    }

    // bigger or smaller about its centre, kept on the screen
    function resize(k: real): void {
        const it = root.item;
        if (!it)
            return;
        const w = Math.max(0.06, Math.min(0.9, (it.w ?? 0.24) * k));
        const h = Math.max(0.05, Math.min(0.9, (it.h ?? 0.2) * k));
        const cx = (it.x ?? 0) + (it.w ?? 0.24) / 2;
        const cy = (it.y ?? 0) + (it.h ?? 0.2) / 2;
        root.patch({
            x: Math.max(0, Math.min(1 - w, cx - w / 2)),
            y: Math.max(0, Math.min(1 - h, cy - h / 2)),
            w: w,
            h: h
        });
        Sfx.toggle();
    }

    function seeThrough(step: real): void {
        const v = Math.round(Math.max(0.1, Math.min(1, root.opacityNow + step)) * 10) / 10;
        root.setOpt("opacity", v);
    }

    function duplicate(): void {
        const it = root.item;
        if (!it)
            return;
        const copy = JSON.parse(JSON.stringify(it));
        delete copy.id;
        // a little down and to the right, still on the screen
        copy.x = Math.min(1 - (it.w ?? 0.24), (it.x ?? 0) + 0.03);
        copy.y = Math.min(1 - (it.h ?? 0.2), (it.y ?? 0) + 0.04);
        Scenes.editKey = "";
        Scenes.add(copy);
        Sfx.select();
        Toast.ok(`${root.meta.name} DUPLICATED`);
        root.done();
    }

    function takeOff(): void {
        if (!root.confirmOff) {
            root.confirmOff = true;
            Sfx.cursor();
            return;
        }
        const name = root.meta.name;
        Scenes.removeLive(root.widgetId);
        Sfx.close();
        Toast.ok(`${name} TAKEN OFF`);
        root.done();
    }

    // ── the pieces ──────────────────────────────────────────────────────────
    // a small square button: − or +
    component Step: Item {
        id: step

        property string glyph: "add"
        signal hit

        width: 34
        height: 30

        Slash {
            anchors.fill: parent
            color: stepArea.pressed ? Colours.accentHot : (stepArea.containsMouse ? Colours.accent : Colours.alpha(Colours.ink, 0.07))
            borderColor: Colours.alpha(Colours.accent, 0.5)
            borderWidth: stepArea.containsMouse ? 0 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: step.glyph
            color: stepArea.containsMouse ? Colours.paper : Colours.ink
            font.pixelSize: 17
        }

        MouseArea {
            id: stepArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: step.hit()
        }
    }

    // a labelled row with − value + on the right
    component Dial: Item {
        id: dial

        property string icon: ""
        property string label: ""
        property string value: ""
        signal less
        signal more

        width: parent?.width ?? 0
        height: 40

        Icon {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            name: dial.icon
            color: Colours.accent
            font.pixelSize: 19
        }

        P5Text {
            x: 44
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: dial.label
            color: Colours.ink
            font.pixelSize: Appearance.font.size.small
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Step {
                glyph: "remove"
                onHit: dial.less()
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                horizontalAlignment: Text.AlignHCenter
                display: true
                text: dial.value
                color: Colours.ink
                font.pixelSize: Appearance.font.size.small
            }

            Step {
                glyph: "add"
                onHit: dial.more()
            }
        }
    }

    // a menu line: icon, name, a hint; lights up under the pointer
    component Line: Item {
        id: line

        property string icon: ""
        property string label: ""
        property string hint: ""
        property bool danger: false
        signal activated

        width: parent?.width ?? 0
        height: 40

        Rectangle {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: line.danger ? Colours.danger : Colours.accent
            opacity: lineArea.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Row {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: line.icon
                color: lineArea.containsMouse ? Colours.paper : (line.danger ? Colours.danger : Colours.accent)
                font.pixelSize: 19
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                // never into the hint: it gives way (…) first
                width: Math.min(implicitWidth, line.width - 14 - 31 - (lineHint.text !== "" ? lineHint.implicitWidth + 26 : 14))
                elide: Text.ElideRight
                display: true
                text: line.label
                color: lineArea.containsMouse ? Colours.paper : (line.danger ? Colours.danger : Colours.ink)
                font.pixelSize: Appearance.font.size.small
            }
        }

        P5Text {
            id: lineHint

            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: line.hint
            color: lineArea.containsMouse ? Colours.alpha(Colours.paper, 0.85) : Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.6
        }

        MouseArea {
            id: lineArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: Sfx.hover()
            onClicked: line.activated()
        }
    }

    Column {
        id: body

        x: Appearance.spacing.normal
        y: Appearance.spacing.normal
        width: parent.width - 2 * Appearance.spacing.normal
        spacing: 4

        // ── whose card this is
        Item {
            width: parent.width
            height: 48

            Icon {
                x: 14
                y: 6
                name: root.meta.glyph
                color: Colours.accent
                font.pixelSize: 22
            }

            P5Text {
                x: 46
                y: 4
                display: true
                text: root.meta.name
                color: Colours.ink
                font.pixelSize: Appearance.font.size.large
            }

            P5Text {
                x: 46
                y: 28
                width: parent.width - 60
                elide: Text.ElideRight
                text: root.still ? "A STILL PICTURE · CHANGES SHOW AT ONCE" : "ON THIS WALLPAPER · CHANGES SHOW AT ONCE"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.6
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colours.alpha(Colours.ink, 0.14)
        }

        Dial {
            icon: "aspect_ratio"
            label: "SIZE"
            value: `${Math.round((root.item?.w ?? 0.24) / 0.24 * 100)} %`
            onLess: root.resize(1 / 1.15)
            onMore: root.resize(1.15)
        }

        Dial {
            icon: "opacity"
            label: "SOLID"
            value: `${Math.round(root.opacityNow * 100)} %`
            onLess: root.seeThrough(-0.1)
            onMore: root.seeThrough(0.1)
        }

        // the look: one chip per frame, the one it wears lit
        Flow {
            width: parent.width
            spacing: 6
            leftPadding: 10
            topPadding: 4
            bottomPadding: 6

            Repeater {
                model: [
                    {
                        v: "auto",
                        t: "AUTO"
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
                        t: "NONE"
                    }
                ]

                Item {
                    id: chip

                    required property var modelData
                    readonly property bool on: root.frameNow === chip.modelData.v

                    width: chipText.width + 22
                    height: 28

                    Slash {
                        anchors.fill: parent
                        color: chip.on ? Colours.accent : (chipArea.containsMouse ? Colours.alpha(Colours.accent, 0.25) : Colours.alpha(Colours.surface, 0.9))
                        borderColor: Colours.alpha(Colours.accent, 0.5)
                        borderWidth: chip.on ? 0 : 1.2

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    P5Text {
                        id: chipText

                        anchors.centerIn: parent
                        display: true
                        text: chip.modelData.t
                        color: chip.on ? Colours.paper : Colours.ink
                        font.pixelSize: Appearance.font.size.tiny
                    }

                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: Sfx.hover()
                        onClicked: root.setOpt("frame", chip.modelData.v)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colours.alpha(Colours.ink, 0.14)
        }

        Line {
            icon: "open_with"
            label: "MOVE AND RESIZE"
            hint: "DRAG IT · ARRANGE"
            onActivated: {
                root.done();
                Panels.openArrange("");
            }
        }

        Line {
            icon: root.still ? "touch_app" : "image"
            label: root.still ? "MAKE IT LIVE" : "STILL PICTURE"
            hint: root.still ? "HOVER · CLICKS AGAIN" : "NO HOVER · NO CLICKS"
            onActivated: root.setOpt("pointer", root.still ? "live" : "still")
        }

        Line {
            icon: "content_copy"
            label: "DUPLICATE"
            hint: "A SECOND ONE"
            onActivated: root.duplicate()
        }

        Line {
            icon: "tune"
            label: "ALL ITS OPTIONS"
            hint: "DESKTOP"
            onActivated: {
                root.done();
                WidgetActions.editOne(root.widgetId);
            }
        }

        Line {
            icon: root.confirmOff ? "delete_forever" : "delete"
            label: root.confirmOff ? "CLICK AGAIN TO TAKE IT OFF" : "TAKE IT OFF"
            hint: root.confirmOff ? "" : "FROM THIS DESK"
            danger: true
            onActivated: root.takeOff()
        }

        Item {
            width: 1
            height: 2
        }
    }
}
