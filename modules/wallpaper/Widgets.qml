//  VELVET  ·  modules/wallpaper/Widgets.qml
//  The desktop's own widgets — purpose-built for the wallpaper's living
//  layer. The lock keeps its modules; these are smaller, sized entirely by
//  their CONTENT (never by their own height), and they assume nothing about
//  a lock surface, a card, or an auth flow. That is the whole difference:
//  a widget that sizes itself from what it shows can never enter a
//  size-binding loop when the wallpaper layer scales it to its box.
//
//  Every widget draws itself twice — inside the glass chip (framed) and
//  loose (raw) — and the chip's opacity touches only the glass, never the
//  content, so a translucent chip still carries crisp ink.
//
//  With `interactive` on (the wallpaper sets it; the DESKTOP previews do
//  not) every look answers the pointer through Surface.qml: the chip lifts,
//  leans, lights up under the pointer and does what WidgetActions says on
//  a click. `hovered` tells the wallpaper when to show the hint.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick
import QtQuick.Effects

Item {
    id: root

    required property string wid

    // MprisBridge is a plain type (not a singleton) — the live one is Lyrics'.
    readonly property var mpris: Lyrics.bridge
    property bool framed: true
    // glass | ink | raw | shapes — SHAPES draws the widget as soft Material
    // silhouettes (ShapeWidget.qml) instead of content in a chip.
    property string look: "glass"
    // Per-widget silhouette for the SHAPES look ("" = the widget decides).
    property string shape: ""
    // Per-widget SHAPES choices from the DESKTOP inspector.
    property string tone: ""
    // (not called `slot`: the wallpaper's delegate has that id, and the
    // name would shadow it inside the binding that fills it)
    property int colourSlot: 0
    property bool details: true
    // The DESKTOP inspector's per-widget choices, whole (hours, name, show …).
    property var opts: ({})
    readonly property bool h24: root.opts.hours === "24" ? true : (root.opts.hours === "12" ? false : Config.bar.clock.format24h)
    readonly property string name: (root.opts.name ?? "") !== "" ? root.opts.name : SysInfo.user
    readonly property string show: root.opts.show ?? "both"
    readonly property bool shaped: root.look === "shapes"
    // SOFT: the round Material pieces (SoftWidget.qml) for the widgets it
    // draws; any other widget keeps the SHAPES drawing.
    readonly property bool softened: root.look === "soft"
    readonly property bool chipped: root.framed && !root.shaped && !root.softened
    property color chipFill: Colours.alpha(Colours.surface, 0.55)
    property color chipBorder: Colours.alpha(Colours.accent, 0.28)
    property real chipOpacity: 1
    property real pad: 16
    property bool interactive: false
    // How much the wallpaper scales this widget up: the glass is rendered
    // at that size instead of being stretched from a small texture.
    property real renderScale: 1
    readonly property bool hovered: root.interactive && anyHover.hovered
    // Set by any Surface inside while it is pressed (Surface._holdAncestors
    // walks up to here too): the wallpaper uses it to tell a click from a
    // leave, so the hint does not come back after you clicked.
    readonly property bool __velvetSurface: true
    property int held: 0

    HoverHandler {
        id: anyHover

        enabled: root.interactive
    }

    implicitWidth: root.chipped ? Math.max(64, content.width + root.pad * 2) : content.width
    implicitHeight: root.chipped ? Math.max(44, content.height + root.pad * 2) : content.height

    // ────────────────────────────────────────────────────────── the glass chip
    //  GLASS · INK · RAW ride one surface; SHAPES brings its own per tile,
    //  so this one stays asleep for it.
    Surface {
        id: chip

        anchors.fill: parent
        active: root.interactive && !root.shaped && !root.softened
        clickable: WidgetActions.clickable(root.wid, false)
        scrollable: root.wid === "media"
        lift: 0.04
        tilt: 4

        onActivated: WidgetActions.run(root.wid)
        onScrolled: steps => WidgetActions.volume(steps)

        Plate {
            id: glass

            visible: root.chipped
            anchors.fill: parent
            radius: Appearance.rounding.large   // follows ROUNDING and SHARP CORNERS
            color: root.chipFill
            border.width: 1
            border.color: root.chipBorder
            opacity: Math.min(1, root.chipOpacity + (1 - root.chipOpacity) * 0.5 * chip.heat)
            antialiasing: true

            layer.enabled: true
            layer.textureSize: Qt.size(Math.ceil(glass.width * Math.max(1, root.renderScale)), Math.ceil(glass.height * Math.max(1, root.renderScale)))
            layer.smooth: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 32
                shadowColor: Qt.rgba(0, 0, 0, 0.5 + 0.12 * chip.heat)
                shadowBlur: 0.6 + 0.25 * chip.heat
                shadowVerticalOffset: 6 + 6 * chip.heat
            }
        }

        // The accent edge brightens under the pointer, over the layer.
        Rectangle {
            visible: root.chipped && chip.heat > 0.01
            anchors.fill: parent
            radius: glass.radius
            color: "transparent"
            border.width: 1
            border.color: Colours.alpha(Colours.accent, 0.6 * chip.heat)
            antialiasing: true
        }

        Sheen {
            visible: root.chipped && chip.glow > 0.003
            anchors.fill: parent
            radius: glass.radius
            strength: chip.glow * 0.7
            lightX: chip.px
            lightY: chip.py
        }

        // Only the widget that was asked for is built. Every kind used to be
        // instantiated and hidden — the chip was sized to the union of all of
        // them (childrenRect counts invisible children) and the hidden ones
        // kept their clocks, pulses and polls running.
        Loader {
            id: content

            anchors.centerIn: parent
            sourceComponent: {
                if (root.softened)
                    return ["clock", "weather", "media", "calendar", "greeting"].indexOf(root.wid) >= 0 ? k_soft : k_shaped;
                if (root.shaped)
                    return k_shaped;
                switch (root.wid) {
                case "calendar":
                    return k_calendar;
                case "clock":
                    return k_clock;
                case "weather":
                    return k_weather;
                case "media":
                    return k_media;
                case "resources":
                    return k_resources;
                case "notifs":
                    return k_notifs;
                case "battery":
                    return k_battery;
                case "net":
                    return k_net;
                case "user":
                    return k_user;
                case "avatar":
                    return k_avatar;
                case "greeting":
                    return k_greeting;
                default:
                    return null;
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════ the clock
    //  Hours in the accent, minutes in the alt — and the minute hand
    //  lands with a small pop, the clock's heartbeat.
    Component {
        id: k_clock

        Item {
            width: clockCol.implicitWidth
            height: clockCol.implicitHeight

            SystemClock {
                id: clock

                precision: SystemClock.Minutes   // HH:mm — waking every second bought nothing
            }

            Column {
                id: clockCol

                spacing: 2

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5

                    P5Text {
                        text: (root.h24 ? Qt.formatDateTime(clock.date, "HH") : Qt.formatDateTime(clock.date, "hh AP").split(" ")[0])
                        color: Colours.accent
                        font.weight: Font.Light
                        font.pixelSize: 46
                        tracking: -2
                    }

                    P5Text {
                        id: clockMin

                        text: Qt.formatDateTime(clock.date, "mm")
                        color: Colours.accentAlt
                        font.weight: Font.Light
                        font.pixelSize: 46
                        tracking: -2

                        property string last: clockMin.text
                        onTextChanged: {
                            if (clockMin.text !== clockMin.last) {
                                clockMin.last = clockMin.text;
                                tick.restart();
                            }
                        }

                        SequentialAnimation {
                            id: tick

                            NumberAnimation {
                                target: clockMin
                                property: "scale"
                                to: 1.06
                                duration: 90
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: clockMin
                                property: "scale"
                                to: 1
                                duration: 260
                                easing.type: Easing.OutBack
                            }
                        }
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.h24
                        text: Qt.formatDateTime(clock.date, "AP").toUpperCase()
                        color: Colours.alpha(Colours.inkDim, 0.9)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1
                    }
                }

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd • d MMM").toUpperCase()
                    color: Colours.alpha(Colours.inkDim, 0.85)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════ the weather
    //  The icon in the accent, the temperature large, the sky in words.
    Component {
        id: k_weather

        Item {
            width: weatherBody.implicitWidth
            height: weatherBody.implicitHeight

            Column {
                id: weatherBody

                spacing: 6
                visible: Weather.ready

                Row {
                    spacing: 12

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Weather.icon
                        color: Colours.accent
                        font.pixelSize: 44
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        width: 150

                        P5Text {
                            width: parent.width
                            text: Weather.short
                            color: Colours.ink
                            font.weight: Font.Light
                            font.pixelSize: 40
                            tracking: -2
                            elide: Text.ElideRight
                        }

                        P5Text {
                            width: parent.width
                            text: Weather.description.toUpperCase()
                            color: Colours.alpha(Colours.inkDim, 0.9)
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 2
                            elide: Text.ElideRight
                        }

                        P5Text {
                            width: parent.width
                            visible: Weather.place !== ""
                            text: Weather.place.toUpperCase()
                            color: Colours.alpha(Colours.inkDim, 0.6)
                            font.pixelSize: Appearance.font.size.tiny - 1
                            tracking: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Column {
                spacing: 3
                visible: !Weather.ready

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "WEATHER OFFLINE"
                    color: Colours.alpha(Colours.inkDim, 0.9)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NO ANSWER FROM THE SKY"
                    color: Colours.alpha(Colours.inkDim, 0.55)
                    font.pixelSize: Appearance.font.size.tiny - 1
                    tracking: 2
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════ the media
    //  Art, title, artist — and the progress as an accent hairline that
    //  breathes while it plays.
    Component {
        id: k_media

        Item {
            id: mediaBox

            width: mediaBody.implicitWidth
            height: mediaBody.implicitHeight

            property real mediaPos: 0

            Timer {
                interval: 1000
                repeat: true
                running: root.wid === "media" && (root.mpris?.has ?? false)
                onTriggered: mediaBox.mediaPos = (root.mpris ? root.mpris.position() : 0)
            }

            Column {
                id: mediaBody

                spacing: 8
                width: 220
                visible: (root.mpris?.has ?? false)

                Row {
                    spacing: 10

                    Plate {
                        width: 44
                        height: 44
                        radius: Appearance.r(10)
                        color: Colours.alpha(Colours.ink, 0.08)
                        clip: true
                        antialiasing: true

                        Image {
                            anchors.fill: parent
                            visible: (root.mpris?.artUrl ?? "") !== ""
                            source: (root.mpris?.artUrl ?? "")
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: (root.mpris?.artUrl ?? "") === ""
                            name: "music_note"
                            color: Colours.accent
                            font.pixelSize: 22
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        width: 132

                        P5Text {
                            width: parent.width
                            text: (root.mpris?.title ?? "")
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.small
                            elide: Text.ElideRight
                        }

                        P5Text {
                            width: parent.width
                            text: (root.mpris?.artist ?? "")
                            color: Colours.alpha(Colours.inkDim, 0.85)
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1
                            elide: Text.ElideRight
                        }
                    }

                    // The playing pulse — a slow heartbeat while the track runs.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: Colours.accent
                        opacity: 1
                        antialiasing: true

                        SequentialAnimation on opacity {
                            running: (root.mpris?.playing ?? false) && !Locker.locked
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // progress hairline
                Rectangle {
                    width: parent.width
                    height: 2
                    radius: 1
                    color: Colours.alpha(Colours.ink, 0.1)
                    visible: (root.mpris?.has ?? false) && (root.mpris?.length ?? 0) > 0
                    antialiasing: true

                    Rectangle {
                        height: 2
                        radius: 1
                        width: Math.max(0, Math.min(parent.width, parent.width * ((root.mpris?.length ?? 0) > 0 ? mediaBox.mediaPos / (root.mpris?.length ?? 0) : 0)))
                        color: Colours.accent
                        antialiasing: true

                        Behavior on width {
                            NumberAnimation {
                                duration: 900
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                }
            }

            Column {
                spacing: 3
                visible: !(root.mpris?.has ?? false)

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NOTHING PLAYING"
                    color: Colours.alpha(Colours.inkDim, 0.9)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════ resources
    //  CPU and memory as two hairlines that crawl with the load.
    Component {
        id: k_resources

        Item {
            width: 200
            height: resCol.implicitHeight

            Column {
                id: resCol

                spacing: 7

                Repeater {
                    // A fixed count: an array literal here was a NEW model on every
                    // SysInfo tick, so both rows were rebuilt and the hairlines
                    // jumped instead of crawling.
                    model: 2

                    Row {
                        required property int index
                        visible: index === 0 ? root.show !== "ram" : root.show !== "cpu"
                        readonly property var modelData: ({
                                label: index === 0 ? "CPU" : "MEM",
                                color: index === 0 ? Colours.accent : Colours.accentAlt,
                                value: index === 0 ? SysInfo.cpuPercent : SysInfo.memoryPercent
                            })

                        width: 200
                        spacing: 8

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30
                            text: modelData.label
                            color: Colours.alpha(Colours.inkDim, 0.9)
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 2
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 118
                            height: 3
                            radius: 1.5
                            color: Colours.alpha(Colours.ink, 0.1)
                            antialiasing: true

                            Rectangle {
                                height: 3
                                radius: 1.5
                                width: Math.max(2, Math.min(parent.width, parent.width * (modelData.value / 100)))
                                color: modelData.color
                                antialiasing: true

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 700
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            horizontalAlignment: Text.AlignRight
                            text: `${Math.round(modelData.value)}%`
                            color: Colours.inkDim
                            font.family: Appearance.fontFamily.mono
                            font.pixelSize: Appearance.font.size.tiny
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════ notifs
    //  The bell and what is waiting behind it.
    Component {
        id: k_notifs

        Item {
            width: notifRow.implicitWidth
            height: notifRow.implicitHeight

            Row {
                id: notifRow

                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "notifications"
                    color: Colours.accent
                    font.pixelSize: 30
                }

                P5Text {
                    id: notifCount

                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.unread > 0 ? `${Notifs.unread} NEW` : "ALL CLEAR"
                    color: Notifs.unread > 0 ? Colours.ink : Colours.alpha(Colours.inkDim, 0.85)
                    font.pixelSize: Notifs.unread > 0 ? Appearance.font.size.large : Appearance.font.size.small
                    tracking: 2

                    property int last: Notifs.unread
                    onLastChanged: pop.restart()

                    SequentialAnimation {
                        id: pop

                        NumberAnimation {
                            target: notifCount
                            property: "scale"
                            to: 1.12
                            duration: 110
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: notifCount
                            property: "scale"
                            to: 1
                            duration: 300
                            easing.type: Easing.OutBack
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════ battery
    Component {
        id: k_battery

        Item {
            width: battRow.implicitWidth
            height: battRow.implicitHeight

            Row {
                id: battRow

                spacing: 10
                visible: Battery.available

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Battery.charging ? "bolt" : (Battery.full ? "battery_full" : (Battery.low ? "battery_alert" : "battery_5_bar"))
                    color: Battery.critical ? Colours.danger : (Battery.low ? Colours.warning : Colours.accent)
                    font.pixelSize: 30
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Battery.percent}%`
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.large
                    tracking: -1
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Battery.charging
                    text: "CHARGING"
                    color: Colours.alpha(Colours.success, 0.95)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 2
                }
            }

            P5Text {
                visible: !Battery.available
                text: "NO BATTERY"
                color: Colours.alpha(Colours.inkDim, 0.85)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 3
            }
        }
    }

    // ══════════════════════════════════════════════════════════════ the net
    Component {
        id: k_net

        Item {
            width: netRow.implicitWidth
            height: netRow.implicitHeight

            Row {
                id: netRow

                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Net.connected ? (Net.type === "wifi" ? "wifi" : "lan") : "wifi_off"
                    color: Net.connected ? Colours.accent : Colours.alpha(Colours.inkDim, 0.7)
                    font.pixelSize: 28
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    P5Text {
                        text: Net.label.toUpperCase()
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                        width: 130
                    }

                    P5Text {
                        visible: Net.connected && Net.type === "wifi"
                        text: `${Net.strength}% SIGNAL`
                        color: Colours.alpha(Colours.inkDim, 0.7)
                        font.pixelSize: Appearance.font.size.tiny - 1
                        tracking: 2
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════ the user
    //  Your face and your machine, at a glance.
    Component {
        id: k_user

        Item {
            width: userRow.implicitWidth
            height: userRow.implicitHeight

            Row {
                id: userRow

                spacing: 10

                Plate {
                    width: 40
                    height: 40
                    radius: Appearance.r(20)
                    color: Colours.alpha(Colours.accent, 0.18)
                    border.width: 1.5
                    border.color: Colours.alpha(Colours.accent, 0.6)
                    clip: true
                    antialiasing: true

                    Icon {
                        anchors.centerIn: parent
                        name: "person"
                        color: Colours.accent
                        font.pixelSize: 22
                    }

                    Image {
                        anchors.fill: parent
                        source: `file://${Quickshell.env("HOME") ?? ""}/.face`
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    P5Text {
                        text: root.name.toUpperCase()
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.small
                        tracking: 1
                    }

                    P5Text {
                        text: SysInfo.hostname.toUpperCase()
                        color: Colours.alpha(Colours.inkDim, 0.7)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 2
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════ greeting
    //  The time of day, said politely.
    Component {
        id: k_greeting

        Item {
            width: greetCol.implicitWidth
            height: greetCol.implicitHeight

            SystemClock {
                id: greetClock

                precision: SystemClock.Minutes
            }

            Column {
                id: greetCol

                spacing: 2

                P5Text {
                    readonly property int h: greetClock.date.getHours()
                    text: (h >= 5 && h < 12 ? "GOOD MORNING" : (h >= 12 && h < 18 ? "GOOD AFTERNOON" : (h >= 18 && h < 23 ? "GOOD EVENING" : "GOOD NIGHT"))).toUpperCase()
                    color: Colours.accent
                    display: true
                    font.pixelSize: 30
                    tracking: 2
                }

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.name.toUpperCase()
                    color: Colours.alpha(Colours.inkDim, 0.85)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════ the avatar
    //  Just the face — the palette offers it, so the desktop draws it too
    //  instead of an empty chip.
    Component {
        id: k_avatar

        Plate {
            width: 72
            height: 72
            radius: Appearance.r(36)
            color: Colours.alpha(Colours.accent, 0.18)
            border.width: 2
            border.color: Colours.alpha(Colours.accent, 0.7)
            clip: true
            antialiasing: true

            Icon {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                name: "person"
                color: Colours.accent
                font.pixelSize: 36
            }

            Image {
                id: face

                anchors.fill: parent
                source: `file://${Quickshell.env("HOME") ?? ""}/.face`
                sourceSize.width: 144
                sourceSize.height: 144
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
    }

    // ════════════════════════════════════════════════════════════ SOFT look
    Component {
        id: k_soft

        SoftWidget {
            wid: root.wid
            interactive: root.interactive
            opts: root.opts
            shape: root.shape
            fillOpacity: root.chipOpacity
        }
    }

    // ═══════════════════════════════════════════════════════════ SHAPES look
    Component {
        id: k_shaped

        ShapeWidget {
            wid: root.wid
            interactive: root.interactive
            opts: root.opts
            shape: root.shape
            tone: root.tone
            slot: root.colourSlot
            details: root.details
            fillOpacity: root.chipOpacity
        }
    }

    // ══════════════════════════════════════════════════════════ the calendar
    //  The day at a glance: month, the number, the weekday.
    Component {
        id: k_calendar

        Column {
            spacing: 0

            SystemClock {
                id: calClock

                precision: SystemClock.Minutes
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(calClock.date, "MMMM").toUpperCase()
                color: Colours.accent
                font.pixelSize: Appearance.font.size.tiny
                tracking: 3
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(calClock.date, "d")
                color: Colours.ink
                font.weight: Font.Light
                font.pixelSize: 56
                tracking: -2
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(calClock.date, "dddd").toUpperCase()
                color: Colours.alpha(Colours.inkDim, 0.85)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 2
            }
        }
    }
}
