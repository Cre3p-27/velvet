//  VELVET  ·  modules/settings/WallpaperPane.qml
//  SETTINGS → PER WALLPAPER: everything the shell can remember for one
//  wallpaper, in one place. The wallpaper that is up on top (with whether its
//  settings are saved, and the three things you do about it), then what a
//  look holds as switchable cards, then every wallpaper that has a look —
//  put one on, copy it onto this wallpaper, or let it go.
//
//  The logic is services/Looks.qml; the programs and widgets on the desktop
//  are services/Scenes.qml and are always per wallpaper (DESKTOP tab).
import qs.config
import qs.services
import qs.components
import QtQuick

FocusScope {
    id: root

    focus: true

    readonly property string wp: Looks.wallpaper
    readonly property string wpName: root.nameOf(root.wp)
    readonly property bool lookOn: Config.looks.enabled
    readonly property bool auto: Config.looks.autoSave
    readonly property int changes: Looks.changedCount(root.wp)
    readonly property int onDesk: root.deskCount(root.wp)
    readonly property bool wide: root.width > 980
    readonly property real gap: 14

    // Where each group's own settings live, for the link on its card.
    readonly property var homeTab: ({
            "style": "VISUALS",
            "bar": "MODULES",
            "windows": "WINDOWS",
            "lock": "LOCK SCREEN",
            "desktop": "DESKTOP",
            "more": "SHELL"
        })
    readonly property var groupIcon: ({
            "style": "palette",
            "bar": "dock_to_bottom",
            "windows": "web_asset",
            "lock": "lock",
            "desktop": "space_dashboard",
            "more": "tune"
        })

    // This wallpaper first, then every other one that has a look.
    readonly property var library: {
        const out = [];
        if (root.wp)
            out.push(root.wp);
        const w = Looks.wallpapers;
        for (let i = 0; i < w.length; i++)
            if (w[i] !== root.wp)
                out.push(w[i]);
        return out;
    }

    function nameOf(path: string): string {
        const f = String(path ?? "").split("/").pop().replace(/\.[^.]+$/, "");
        return f === "" ? "NO WALLPAPER" : f.toUpperCase();
    }

    function deskCount(path: string): int {
        const l = Scenes.store[path];
        return Array.isArray(l) ? l.length : 0;
    }

    function groupsHeld(path: string): int {
        let n = 0;
        for (let g = 0; g < Looks.groups.length; g++)
            if (Looks.heldIn(path, Looks.groups[g].id) > 0)
                n++;
        return n;
    }

    function save(): void {
        const had = Looks.hasLook;
        Looks.save();
        Sfx.select();
        Toast.ok(had ? "LOOK UPDATED" : "LOOK SAVED  ·  THIS WALLPAPER BRINGS ITS SETTINGS BACK");
    }

    function undo(): void {
        Looks.restore(root.wp);
        Sfx.back();
        Toast.ok("BACK TO THE SAVED LOOK");
    }

    function forget(path: string): void {
        Looks.forget(path);
        Sfx.back();
        Toast.show(`LOOK FORGOTTEN  ·  ${root.nameOf(path)}`, "info", 2400);
    }

    function copyHere(path: string): void {
        if (Looks.copyFrom(path)) {
            Sfx.select();
            Toast.ok(`LOOK OF ${root.nameOf(path)} IS NOW THIS WALLPAPER'S`);
        }
    }

    function useWallpaper(path: string): void {
        Wallpapers.apply(path);
        Sfx.select();
    }

    Flickable {
        id: flick

        anchors.fill: parent
        contentWidth: width
        contentHeight: body.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body

            width: flick.width - (flick.contentHeight > flick.height ? 14 : 0)
            spacing: 20

            // ── head
            Column {
                spacing: 4

                P5Text {
                    display: true
                    text: "PER WALLPAPER"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.title
                }

                P5Text {
                    text: "EACH WALLPAPER REMEMBERS ITS OWN TASKBAR, WINDOWS, LOCK SCREEN, DESKTOP AND MORE"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.small
                    tracking: 1
                }
            }

            // ── the wallpaper that is up
            Plate {
                id: hero

                width: parent.width
                height: heroRow.height + 36
                radius: Appearance.r(20)
                color: Colours.alpha(Colours.ink, 0.05)
                border.width: 1
                border.color: Colours.alpha(root.changes > 0 ? Colours.accent : Colours.ink, root.changes > 0 ? 0.6 : 0.12)
                antialiasing: true

                Row {
                    id: heroRow

                    x: 18
                    y: 18
                    width: parent.width - 36
                    spacing: 22

                    Plate {
                        id: heroThumb

                        width: root.wide ? 300 : 210
                        height: Math.round(width * 9 / 16)
                        radius: Appearance.r(10)
                        color: Colours.alpha(Colours.ink, 0.1)
                        border.width: 1
                        border.color: Colours.alpha(Colours.ink, 0.2)
                        clip: true
                        antialiasing: true

                        Image {
                            anchors.fill: parent
                            source: root.wp ? "file://" + root.wp : ""
                            sourceSize.width: 600
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }
                    }

                    Column {
                        width: parent.width - heroThumb.width - parent.spacing
                        spacing: 10

                        P5Text {
                            width: parent.width
                            elide: Text.ElideMiddle
                            display: true
                            text: root.wpName
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.large
                        }

                        Row {
                            spacing: 8

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                radius: 5
                                color: !root.lookOn ? Colours.alpha(Colours.ink, 0.3) : (root.changes > 0 ? Colours.accent : (Looks.hasLook ? "#5fcf8a" : Colours.alpha(Colours.ink, 0.4)))
                            }

                            P5Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!root.lookOn)
                                        return "SWITCHED OFF  ·  WALLPAPERS NEVER CHANGE YOUR SETTINGS";
                                    if (!Looks.hasLook)
                                        return root.auto ? "NO LOOK YET  ·  THE FIRST THING YOU CHANGE BECOMES IT" : "NO LOOK YET  ·  PRESS SAVE TO KEEP YOUR SETTINGS HERE";
                                    if (root.changes > 0)
                                        return `${root.changes} CHANGE${root.changes === 1 ? "" : "S"} NOT SAVED YET`;
                                    return "LOOK SAVED  ·  YOU WILL GET IT BACK WITH THIS WALLPAPER";
                                }
                                color: root.changes > 0 && root.lookOn ? Colours.accent : Colours.ink
                                font.pixelSize: Appearance.font.size.small
                                tracking: 1
                            }
                        }

                        P5Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: root.deskCount(root.wp) > 0 ? `${root.onDesk} PROGRAM${root.onDesk === 1 ? "" : "S"} AND WIDGET${root.onDesk === 1 ? "" : "S"} ON ITS DESKTOP  ·  ${root.groupsHeld(root.wp)} OF ${Looks.groups.length} KINDS OF SETTINGS KEPT` : `NOTHING PLACED ON ITS DESKTOP YET  ·  ${root.groupsHeld(root.wp)} OF ${Looks.groups.length} KINDS OF SETTINGS KEPT`
                            color: Colours.inkDim
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1.4
                        }

                        Flow {
                            width: parent.width
                            spacing: 10

                            Btn {
                                strong: !Looks.hasLook || root.changes > 0
                                glyph: "bookmark"
                                text: Looks.hasLook ? "UPDATE LOOK" : "SAVE LOOK"
                                onClicked: root.save()
                            }

                            Btn {
                                visible: root.changes > 0
                                glyph: "undo"
                                text: "UNDO CHANGES"
                                onClicked: root.undo()
                            }

                            Btn {
                                visible: Looks.hasLook
                                glyph: "delete"
                                text: "FORGET LOOK"
                                onClicked: root.forget(root.wp)
                            }

                            Btn {
                                glyph: "space_dashboard"
                                text: "ARRANGE DESKTOP"
                                onClicked: Panels.openSettingsTabNamed("DESKTOP")
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: 10

                            Toggle {
                                text: "SETTINGS PER WALLPAPER"
                                on: root.lookOn
                                onFlipped: Config.toggle("looks.enabled")
                            }

                            Toggle {
                                text: "REMEMBER AUTOMATICALLY"
                                on: root.auto
                                dim: !root.lookOn
                                onFlipped: Config.toggle("looks.autoSave")
                            }
                        }
                    }
                }
            }

            // ── what a look holds
            Column {
                width: parent.width
                spacing: 4

                P5Text {
                    text: "WHAT THIS WALLPAPER REMEMBERS"
                    color: Colours.alpha(Colours.accent, 0.9)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }

                P5Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "SWITCH A KIND OFF AND IT STAYS THE SAME ON EVERY WALLPAPER."
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }
            }

            Grid {
                width: parent.width
                columns: root.wide ? 2 : 1
                columnSpacing: root.gap
                rowSpacing: root.gap

                Repeater {
                    model: Looks.groups

                    GroupCard {
                        required property var modelData

                        group: modelData
                        width: (body.width - root.gap * (root.wide ? 1 : 0)) / (root.wide ? 2 : 1)
                    }
                }

                DeskCard {
                    width: (body.width - root.gap * (root.wide ? 1 : 0)) / (root.wide ? 2 : 1)
                }
            }

            // ── every wallpaper with a look
            Column {
                width: parent.width
                spacing: 4

                P5Text {
                    text: `YOUR WALLPAPERS  ·  ${Looks.count} WITH A LOOK`
                    color: Colours.alpha(Colours.accent, 0.9)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }

                P5Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "PUT ONE ON, COPY ITS LOOK ONTO THE WALLPAPER YOU HAVE UP, OR LET IT GO."
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }
            }

            Flow {
                width: parent.width
                spacing: root.gap

                Repeater {
                    model: root.library

                    WallpaperCard {
                        required property string modelData

                        path: modelData
                    }
                }
            }

            P5Text {
                width: parent.width
                visible: Looks.count === 0
                wrapMode: Text.WordWrap
                text: "NO LOOKS YET. CHANGE A SETTING WHILE A WALLPAPER IS UP AND IT IS KEPT FOR THAT WALLPAPER."
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.small
                tracking: 1
            }
        }

        SmoothScroll {
            view: flick
        }
    }

    // ═══════════════════════════════════════════════════════════ parts
    component Btn: Rectangle {
        id: btn

        property string text: ""
        property string glyph: ""
        property bool strong: false

        signal clicked

        width: btnRow.width + 30
        height: 36
        radius: Appearance.r(18)
        color: btn.strong ? (btnHover.hovered ? Colours.accentHot : Colours.accent) : (btnHover.hovered ? Colours.alpha(Colours.ink, 0.13) : Colours.alpha(Colours.ink, 0.06))
        border.width: btn.strong ? 0 : 1
        border.color: Colours.alpha(Colours.ink, 0.16)
        scale: btnTap.pressed ? 0.95 : (btnHover.hovered ? 1.03 : 1)
        antialiasing: true

        Behavior on scale {
            NumberAnimation {
                duration: 110
            }
        }

        Row {
            id: btnRow

            anchors.centerIn: parent
            spacing: 7

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: btn.glyph !== ""
                name: btn.glyph
                color: btn.strong ? Colours.on(Colours.accent) : Colours.accent
                font.pixelSize: 17
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.text
                color: btn.strong ? Colours.on(Colours.accent) : Colours.ink
                font.pixelSize: Appearance.font.size.small
                tracking: 1
            }
        }

        HoverHandler {
            id: btnHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: btnTap

            onTapped: btn.clicked()
        }
    }

    // A labelled on/off pill.
    component Toggle: Rectangle {
        id: tg

        property string text: ""
        property bool on: false
        property bool dim: false

        signal flipped

        width: tgRow.width + 28
        height: 34
        radius: Appearance.r(17)
        opacity: tg.dim ? 0.5 : 1
        color: tgHover.hovered ? Colours.alpha(Colours.ink, 0.1) : Colours.alpha(Colours.ink, 0.05)
        border.width: 1
        border.color: Colours.alpha(Colours.ink, 0.12)
        antialiasing: true

        Row {
            id: tgRow

            anchors.centerIn: parent
            spacing: 10

            Plate {
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 18
                radius: Appearance.r(9)
                color: tg.on ? Colours.accent : Colours.alpha(Colours.ink, 0.2)

                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                Plate {
                    x: tg.on ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12
                    height: 12
                    radius: Appearance.r(6)
                    color: tg.on ? Colours.on(Colours.accent) : Colours.ink

                    Behavior on x {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tg.text
                color: Colours.ink
                font.pixelSize: Appearance.font.size.small
                tracking: 1
            }
        }

        HoverHandler {
            id: tgHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                Sfx.toggle();
                tg.flipped();
            }
        }
    }

    // One kind of setting a look may hold.
    component GroupCard: Rectangle {
        id: grp

        property var group: ({})

        readonly property bool locked: grp.group.flag === ""
        readonly property bool on: Looks.rev >= 0 && Looks.groupOn(grp.group.id)
        readonly property int kept: Looks.heldIn(root.wp, grp.group.id)

        height: 96
        radius: Appearance.r(16)
        opacity: grp.on ? 1 : 0.62
        color: grpHover.hovered ? Colours.alpha(Colours.ink, 0.09) : Colours.alpha(Colours.ink, 0.045)
        border.width: 1
        border.color: grp.on ? Colours.alpha(Colours.accent, 0.4) : Colours.alpha(Colours.ink, 0.12)
        antialiasing: true

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        Plate {
            id: badge

            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 46
            radius: Appearance.r(23)
            color: grp.on ? Colours.accent : Colours.alpha(Colours.ink, 0.1)

            Icon {
                anchors.centerIn: parent
                name: root.groupIcon[grp.group.id] ?? "tune"
                color: grp.on ? Colours.on(Colours.accent) : Colours.inkDim
                font.pixelSize: 24
            }
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: 14
            anchors.right: sw.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            P5Text {
                width: parent.width
                elide: Text.ElideRight
                display: true
                text: grp.group.name
                color: Colours.ink
                font.pixelSize: Appearance.font.size.normal
            }

            P5Text {
                width: parent.width
                elide: Text.ElideRight
                text: grp.group.sub
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 0.6
            }

            Row {
                spacing: 14

                P5Text {
                    text: grp.kept > 0 ? `${grp.kept} OF ${Looks.groupCount(grp.group.id)} KEPT HERE` : `${Looks.groupCount(grp.group.id)} SETTINGS`
                    color: grp.kept > 0 && grp.on ? Colours.accent : Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.4
                }

                P5Text {
                    text: `CHANGE IN ${root.homeTab[grp.group.id] ?? ""}  ›`
                    color: linkHover.hovered ? Colours.accent : Colours.alpha(Colours.ink, 0.55)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.4

                    HoverHandler {
                        id: linkHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            Sfx.select();
                            Panels.openSettingsTabNamed(root.homeTab[grp.group.id] ?? "");
                        }
                    }
                }
            }
        }

        Plate {
            id: sw

            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 24
            radius: Appearance.r(12)
            color: grp.on ? Colours.accent : Colours.alpha(Colours.ink, 0.2)
            opacity: grp.locked ? 0.6 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }

            Plate {
                x: grp.on ? parent.width - width - 4 : 4
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: Appearance.r(8)
                color: grp.on ? Colours.on(Colours.accent) : Colours.ink

                Behavior on x {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }
            }

            P5Text {
                visible: grp.locked
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 3
                text: "ALWAYS"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny - 2
                tracking: 1
            }
        }

        HoverHandler {
            id: grpHover
        }

        TapHandler {
            enabled: !grp.locked
            onTapped: {
                Sfx.toggle();
                Looks.toggleGroup(grp.group.id);
            }
        }
    }

    // The desktop itself: always per wallpaper, no switch.
    component DeskCard: Rectangle {
        id: dc

        height: 96
        radius: Appearance.r(16)
        color: dcHover.hovered ? Colours.alpha(Colours.ink, 0.09) : Colours.alpha(Colours.ink, 0.045)
        border.width: 1
        border.color: Colours.alpha(Colours.accent, 0.4)
        antialiasing: true

        Plate {
            id: dBadge

            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            height: 46
            radius: Appearance.r(23)
            color: Colours.accent

            Icon {
                anchors.centerIn: parent
                name: "widgets"
                color: Colours.on(Colours.accent)
                font.pixelSize: 24
            }
        }

        Column {
            anchors.left: dBadge.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            P5Text {
                width: parent.width
                elide: Text.ElideRight
                display: true
                text: "PROGRAMS & WIDGETS"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.normal
            }

            P5Text {
                width: parent.width
                elide: Text.ElideRight
                text: "WHAT SITS ON YOUR DESKTOPS  ·  ALWAYS PER WALLPAPER"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 0.6
            }

            P5Text {
                text: dcHover.hovered ? "OPEN THE DESKTOP EDITOR  ›" : `${root.onDesk} PLACED ON THIS WALLPAPER`
                color: dcHover.hovered ? Colours.accent : Colours.alpha(Colours.ink, 0.7)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.4
            }
        }

        HoverHandler {
            id: dcHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: {
                Sfx.select();
                Panels.openSettingsTabNamed("DESKTOP");
            }
        }
    }

    // A wallpaper and what it remembers.
    component WallpaperCard: Rectangle {
        id: wc

        property string path: ""

        readonly property bool current: wc.path === root.wp
        readonly property bool saved: Looks.store[wc.path] !== undefined
        readonly property int kinds: root.groupsHeld(wc.path)
        readonly property int placed: root.deskCount(wc.path)

        width: root.wide ? 236 : 220
        height: thumb.height + info.height + 24
        radius: Appearance.r(14)
        color: wcHover.hovered ? Colours.alpha(Colours.ink, 0.09) : Colours.alpha(Colours.ink, 0.045)
        border.width: wc.current ? 2 : 1
        border.color: wc.current ? Colours.accent : Colours.alpha(Colours.ink, 0.12)
        antialiasing: true

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }

        Plate {
            id: thumb

            x: 8
            y: 8
            width: parent.width - 16
            height: Math.round(width * 9 / 16)
            radius: Appearance.r(8)
            color: Colours.alpha(Colours.ink, 0.1)
            clip: true
            antialiasing: true

            Image {
                anchors.fill: parent
                source: wc.path ? "file://" + wc.path : ""
                sourceSize.width: 360
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            Plate {
                visible: wc.current
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 6
                width: upNow.width + 14
                height: 18
                radius: Appearance.r(9)
                color: Colours.accent

                P5Text {
                    id: upNow

                    anchors.centerIn: parent
                    text: "UP NOW"
                    color: Colours.on(Colours.accent)
                    font.pixelSize: Appearance.font.size.tiny - 1
                    tracking: 1.4
                }
            }

            // Hover: a click anywhere on the picture puts the wallpaper on.
            Rectangle {
                anchors.fill: parent
                visible: !wc.current
                color: Colours.alpha(Colours.paper, thumbHover.hovered ? 0.55 : 0)

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                P5Text {
                    anchors.centerIn: parent
                    opacity: thumbHover.hovered ? 1 : 0
                    display: true
                    text: "USE THIS WALLPAPER"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.small

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }
                }
            }

            HoverHandler {
                id: thumbHover

                cursorShape: wc.current ? Qt.ArrowCursor : Qt.PointingHandCursor
            }

            TapHandler {
                enabled: !wc.current
                onTapped: root.useWallpaper(wc.path)
            }
        }

        Column {
            id: info

            x: 12
            y: thumb.height + 16
            width: parent.width - 24
            spacing: 6

            P5Text {
                width: parent.width
                elide: Text.ElideMiddle
                display: true
                text: root.nameOf(wc.path)
                color: Colours.ink
                font.pixelSize: Appearance.font.size.small
            }

            P5Text {
                width: parent.width
                elide: Text.ElideRight
                text: wc.saved ? `${wc.kinds} OF ${Looks.groups.length} KINDS  ·  ${wc.placed} ON DESKTOP` : "NO LOOK YET"
                color: wc.saved ? Colours.accent : Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
            }

            Row {
                spacing: 14

                Link {
                    visible: !wc.current && wc.saved
                    text: "COPY HERE"
                    onClicked: root.copyHere(wc.path)
                }

                Link {
                    visible: wc.saved
                    text: "FORGET"
                    onClicked: root.forget(wc.path)
                }
            }
        }

        HoverHandler {
            id: wcHover
        }
    }

    component Link: P5Text {
        id: lk

        signal clicked

        color: lkHover.hovered ? Colours.accent : Colours.alpha(Colours.ink, 0.65)
        font.pixelSize: Appearance.font.size.tiny
        tracking: 1.4

        HoverHandler {
            id: lkHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: lk.clicked()
        }
    }
}
