//  VELVET  ·  modules/wallpaper/DesktopMenuCard.qml
//  What a right-click on the bare desktop offers: edit it, drop a widget right
//  where you clicked, swap the wallpaper, keep this wallpaper's look, and go
//  to any desktop or the infinite canvas. Plain item so DesktopMenu can float
//  it anywhere.
import qs.config
import qs.services
import qs.components
import QtQuick

Plate {
    id: root

    // Where the pointer was, as fractions of the screen — a widget added from
    // here lands under it.
    property real atX: 0.5
    property real atY: 0.5
    property bool adding: false
    readonly property string wallpaperName: (Config.wallpaper.current || "").split("/").pop()
    readonly property var widgetChoices: LockModules.all.filter(m => m.id !== "power" && m.id !== "session").concat([{
                id: "calendar",
                name: "CALENDAR",
                glyph: "calendar_month"
            }])

    signal done

    // DesktopMenu says when the card is up: the lines arrive one by one
    property bool entered: true
    property real reveal: root.entered ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: Appearance.anim.slow
            easing.type: Easing.OutCubic
        }
    }
    // the line under the pointer: ONE plate glides from line to line
    property Item hotLine: null

    width: 420
    height: body.height + 2 * Appearance.spacing.normal
    radius: Appearance.rounding.normal
    color: Colours.alpha(Colours.paper, 0.95)
    border.width: 2
    border.color: Colours.alpha(Colours.accent, 0.85)

    function addWidget(m: var): void {
        const w = 0.24;
        const h = 0.2;
        const x = Math.max(0, Math.min(1 - w, root.atX - w / 2));
        const y = Math.max(0, Math.min(1 - h, root.atY - h / 2));
        // The desk being edited is the one on screen, whatever DESKTOP last had open.
        Scenes.editKey = "";
        Scenes.add({
            kind: "widget",
            widget: m.id,
            name: m.name,
            x: x,
            y: y,
            w: w,
            h: h,
            ws: 0,
            float: true,
            opts: {
                frame: "shapes",
                opacity: -1
            }
        });
        Sfx.select();
        Toast.ok(`${m.name} ADDED  ·  MOVE OR RESIZE IT IN DESKTOP`);
        root.done();
    }

    function saveLook(): void {
        Looks.save();
        Sfx.select();
        Toast.ok("LOOK SAVED  ·  THIS WALLPAPER NOW BRINGS ITS SETTINGS BACK");
        root.done();
    }

    // A menu line: icon, name, a small hint on the right. Lights up under the pointer.
    component Line: Item {
        id: line

        property string icon: ""
        property string label: ""
        property string hint: ""
        property bool open: false
        property int order: 0
        readonly property bool lit: root.hotLine === line
        // its share of the card's arrival
        readonly property real here: Math.max(0, Math.min(1, (root.reveal - line.order * 0.07) / 0.45))
        signal activated

        width: parent?.width ?? 0
        height: 42
        opacity: line.here
        transform: Translate {
            x: (1 - line.here) * -16
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: line.icon
                color: line.lit ? Colours.paper : Colours.accent
                font.pixelSize: 21
                scale: lineLift.value

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
                Spring {
                    id: lineLift

                    to: line.lit ? 1.12 : 1
                    spring: 6
                    damping: 0.38
                    epsilon: 0.002
                }
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: line.label
                color: line.lit ? Colours.paper : Colours.ink
                font.pixelSize: Appearance.font.size.normal

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
        }

        P5Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: line.open ? "▾" : line.hint
            color: line.lit ? Colours.alpha(Colours.paper, 0.85) : Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 2
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                root.hotLine = line;
                Sfx.cursor();
            }
            onExited: {
                if (root.hotLine === line)
                    root.hotLine = null;
            }
            onPressed: pressPlate.restart()
            onClicked: line.activated()
        }
    }

    // the plate under the pointer's line: it glides, it does not blink
    Slash {
        id: plate

        readonly property Item line: root.hotLine
        property real atY: 0
        property real atH: 42

        x: body.x
        width: body.width
        y: atSpring.value
        height: plate.atH
        color: Colours.accent
        opacity: plate.line ? 1 : 0
        scale: pressScale.value
        transformOrigin: Item.Center

        onLineChanged: {
            if (plate.line) {
                plate.atY = body.y + plate.line.y;
                plate.atH = plate.line.height;
            }
        }

        Spring {
            id: atSpring

            to: plate.atY
            live: plate.opacity > 0.05
            spring: 5.5
            damping: 0.42
            epsilon: 0.2
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }

        QtObject {
            id: pressScale

            property real value: 1
        }
        SequentialAnimation {
            id: pressPlate

            NumberAnimation {
                target: pressScale
                property: "value"
                to: 0.96
                duration: 70
            }
            SpringAnimation {
                target: pressScale
                property: "value"
                to: 1
                spring: 6
                damping: 0.35
            }
        }
    }

    Column {
        id: body

        x: Appearance.spacing.normal
        y: Appearance.spacing.normal
        width: parent.width - 2 * Appearance.spacing.normal
        spacing: 4

        Item {
            width: parent.width
            height: 46

            P5Text {
                x: 14
                y: 4
                display: true
                text: "THIS DESKTOP"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.large
            }

            P5Text {
                x: 14
                y: 27
                width: parent.width - 28
                elide: Text.ElideMiddle
                text: `${root.wallpaperName}  ·  ${Looks.hasLook ? "LOOK SAVED" : "NO LOOK YET"}`
                color: Looks.hasLook ? Colours.accent : Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 2
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colours.alpha(Colours.ink, 0.14)
        }

        Line {
            icon: "open_with"
            order: 1
            label: "ARRANGE THE DESK"
            hint: "RIGHT HERE · DRAG"
            onActivated: {
                root.done();
                Panels.openArrange("");
            }
        }

        Line {
            icon: "edit"
            order: 2
            label: "EDIT DESKTOP"
            hint: "WIDGETS · WINDOWS"
            onActivated: {
                root.done();
                WidgetActions.edit();
            }
        }

        Line {
            icon: "widgets"
            order: 3
            label: "ADD WIDGET HERE"
            hint: "AT THE POINTER"
            open: root.adding
            onActivated: {
                root.adding = !root.adding;
                Sfx.select();
            }
        }

        Flow {
            visible: root.adding
            width: parent.width
            spacing: 6
            leftPadding: 6

            Repeater {
                model: root.widgetChoices

                Item {
                    id: chip

                    required property var modelData

                    width: chipRow.width + 22
                    height: 32

                    Slash {
                        anchors.fill: parent
                        color: chipArea.containsMouse ? Colours.accent : Colours.alpha(Colours.surface, 0.9)
                        borderColor: Colours.alpha(Colours.accent, 0.5)
                        borderWidth: chipArea.containsMouse ? 0 : 1.2
                    }

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: chip.modelData.glyph
                            color: chipArea.containsMouse ? Colours.paper : Colours.accent
                            font.pixelSize: 16
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            display: true
                            text: chip.modelData.name
                            color: chipArea.containsMouse ? Colours.paper : Colours.ink
                            font.pixelSize: Appearance.font.size.tiny
                        }
                    }

                    MouseArea {
                        id: chipArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: Sfx.cursor()
                        onClicked: root.addWidget(chip.modelData)
                    }
                }
            }
        }

        Line {
            visible: Config.wallpaper.wheel
            icon: "wallpaper"
            order: 4
            label: "CHANGE WALLPAPER"
            hint: "SUPER+W"
            onActivated: {
                root.done();
                Panels.toggleWheel();
            }
        }

        Line {
            icon: "palette"
            order: 5
            label: Looks.hasLook ? "UPDATE ITS LOOK" : "SAVE ITS LOOK"
            hint: "ALL SETTINGS"
            onActivated: root.saveLook()
        }

        Line {
            icon: "tune"
            order: 6
            label: "PER WALLPAPER"
            hint: "WHAT IT HOLDS"
            onActivated: {
                root.done();
                Panels.openSettingsTabNamed("PER WALLPAPER");
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Colours.alpha(Colours.ink, 0.14)
        }

        P5Text {
            x: 14
            text: "DESKTOPS  ·  INFINITE CANVAS"
            color: Colours.alpha(Colours.accent, 0.9)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 3
        }

        DesktopStrip {
            x: 6
            width: parent.width - 12
            onPicked: root.done()
            onCanvasPicked: root.done()
        }

        Item {
            width: 1
            height: 4
        }
    }
}
