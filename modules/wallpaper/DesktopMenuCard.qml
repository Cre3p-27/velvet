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
        signal activated

        width: parent?.width ?? 0
        height: 42

        Slash {
            anchors.fill: parent
            color: area.containsMouse ? Colours.accent : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: line.icon
                color: area.containsMouse ? Colours.paper : Colours.accent
                font.pixelSize: 21
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: line.label
                color: area.containsMouse ? Colours.paper : Colours.ink
                font.pixelSize: Appearance.font.size.normal
            }
        }

        P5Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: line.open ? "▾" : line.hint
            color: area.containsMouse ? Colours.alpha(Colours.paper, 0.85) : Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 2
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: Sfx.cursor()
            onClicked: line.activated()
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
            icon: "edit"
            label: "EDIT DESKTOP"
            hint: "WIDGETS · WINDOWS"
            onActivated: {
                root.done();
                WidgetActions.edit();
            }
        }

        Line {
            icon: "widgets"
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
            label: "CHANGE WALLPAPER"
            hint: "SUPER+W"
            onActivated: {
                root.done();
                Panels.toggleWheel();
            }
        }

        Line {
            icon: "palette"
            label: Looks.hasLook ? "UPDATE ITS LOOK" : "SAVE ITS LOOK"
            hint: "ALL SETTINGS"
            onActivated: root.saveLook()
        }

        Line {
            icon: "tune"
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
