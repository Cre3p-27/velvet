//  VELVET  ·  modules/dock/DockAdder.qml
//  The dock's + : put something on it. APP finds an app as you type; COMMAND,
//  FOLDER and WEB LINK take what you type (Enter adds it); SHELL lists the
//  shell's own doors — settings, the launcher, the scratchpad, Velly …
pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    required property var dock
    property bool open: false
    property string mode: "app"

    function toggle(): void {
        root.open = !root.open;
        if (root.open) {
            field.text = "";
            root.mode = "app";
            Sfx.open();
            Qt.callLater(() => field.forceActiveFocus());
        } else {
            Sfx.close();
        }
    }

    readonly property var shellDoors: [
        { name: "SETTINGS", icon: "settings", ipc: "panels settings" },
        { name: "LAUNCHER", icon: "apps", ipc: "panels launcher" },
        { name: "SCRATCHPAD", icon: "edit_note", ipc: "scratch toggle" },
        { name: "NOTIFICATIONS", icon: "notifications", ipc: "panels notifications" },
        { name: "THE MAP", icon: "grid_view", ipc: "panels map" },
        { name: "SHORTCUTS", icon: "keyboard", ipc: "panels keys" },
        { name: "POWER", icon: "power_settings_new", ipc: "panels session" }
    ]

    readonly property var hits: {
        if (root.mode === "shell")
            return root.shellDoors.filter(d => d.name.toLowerCase().indexOf(field.text.trim().toLowerCase()) >= 0);
        if (root.mode !== "app" || field.text.trim() === "")
            return [];
        return Apps.search(field.text).filter(r => r.kind === "app").slice(0, 6);
    }
    property int sel: 0

    function addTyped(): void {
        const t = field.text.trim();
        if (root.mode === "app" || root.mode === "shell") {
            const h = root.hits[Math.min(root.sel, root.hits.length - 1)];
            if (h)
                root.pick(h);
            return;
        }
        if (t === "")
            return;
        if (root.mode === "cmd")
            root.dock.add({ kind: "cmd", cmd: t, name: t.split(/\s+/)[0] });
        else if (root.mode === "folder")
            root.dock.add({ kind: "folder", path: t, name: t.replace(/\/+$/, "").split("/").pop() || t });
        else
            root.dock.add({ kind: "url", url: t, name: t.replace(/^[a-z]+:\/\//i, "").split(/[/?#]/)[0] });
        root.open = false;
    }

    function pick(h: var): void {
        if (root.mode === "shell")
            root.dock.add({ kind: "shell", name: h.name, icon: h.icon, ipc: h.ipc });
        else
            root.dock.add({ kind: "app", id: h.id });
        root.open = false;
    }

    width: 440
    height: 286
    visible: root.open || card.opacity > 0.01

    Puff {
        id: card

        anchors.fill: parent
        kind: Appearance.fidget ? "clay" : "plain"
        radius: Appearance.r(22)
        color: Colours.surface
        depth: 6
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.94

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutBack
            }
        }

        // the kinds
        Row {
            id: kinds

            x: 16
            y: 14
            spacing: 6

            Repeater {
                model: [["app", "APP"], ["cmd", "COMMAND"], ["folder", "FOLDER"], ["url", "WEB LINK"], ["shell", "SHELL"]]

                SoftChip {
                    required property var modelData

                    text: modelData[1]
                    on: root.mode === modelData[0]
                    onClicked: {
                        root.mode = modelData[0];
                        root.sel = 0;
                        Sfx.toggle();
                        field.forceActiveFocus();
                    }
                }
            }
        }

        // what you type
        Rectangle {
            id: box

            x: 16
            y: kinds.y + kinds.height + 12
            width: parent.width - 32
            height: 40
            radius: 20
            color: Colours.alpha(Colours.ink, 0.06)
            border.width: 1
            border.color: field.activeFocus ? Colours.alpha(Colours.accent, 0.7) : Colours.alpha(Colours.ink, 0.14)

            TextInput {
                id: field

                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                color: Colours.ink
                selectionColor: Colours.alpha(Colours.accent, 0.4)
                font.family: Appearance.fontFamily.body
                font.pixelSize: Appearance.font.size.normal
                clip: true
                onTextChanged: root.sel = 0

                Keys.onPressed: e => {
                    if (e.key === Qt.Key_Escape) {
                        root.open = false;
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                        root.addTyped();
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Down) {
                        root.sel = Math.min(root.hits.length - 1, root.sel + 1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Up) {
                        root.sel = Math.max(0, root.sel - 1);
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Tab) {
                        const order = ["app", "cmd", "folder", "url", "shell"];
                        root.mode = order[(order.indexOf(root.mode) + 1) % order.length];
                        e.accepted = true;
                    }
                }
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 16
                visible: field.text === ""
                text: ({
                        app: "TYPE AN APP'S NAME",
                        cmd: "A COMMAND, E.G.  kitty -e btop",
                        folder: "A FOLDER, E.G.  ~/Downloads",
                        url: "A WEB ADDRESS, E.G.  github.com",
                        shell: "SETTINGS, SCRATCHPAD, POWER …"
                    })[root.mode]
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: Appearance.font.size.small
            }
        }

        // what it found (APP, SHELL) — or how to finish (the others)
        Column {
            x: 16
            y: box.y + box.height + 8
            width: parent.width - 32
            spacing: 2

            Repeater {
                model: root.hits

                Rectangle {
                    id: row

                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 30
                    radius: 15
                    color: row.index === root.sel || rowHover.hovered ? Colours.alpha(Colours.accent, 0.16) : "transparent"

                    HoverHandler {
                        id: rowHover
                    }

                    AppIcon {
                        visible: root.mode === "app"
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        cls: `${row.modelData.entry?.startupClass || row.modelData.id || ""}`
                    }

                    Icon {
                        visible: root.mode === "shell"
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.modelData.icon ?? ""
                        font.pixelSize: 18
                        color: Colours.accent
                    }

                    P5Text {
                        x: 36
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44
                        text: `${row.modelData.name ?? ""}`.toUpperCase()
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(row.modelData)
                    }
                }
            }

            P5Text {
                visible: root.mode !== "app" && root.mode !== "shell"
                width: parent.width
                text: "ENTER PUTS IT ON THE DOCK  ·  TAB: THE NEXT KIND  ·  ESC: NEVER MIND"
                color: Colours.alpha(Colours.inkDim, 0.75)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
                wrapMode: Text.WordWrap
            }
        }
    }
}
