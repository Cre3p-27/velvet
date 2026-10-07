//  VELVET  ·  modules/wallpaper/ShapeWidget.qml
//  The SHAPES look for desktop widgets — soft Material-3 silhouettes in
//  tones taken from the wallpaper, instead of a rectangle of glass.
//
//    CLOCK      tall split digits that roll when they change
//    WEATHER    a shape that follows the sky (sun · cookie · clover · flower …)
//    RESOURCES  a CPU card with its history + memory in a pentagon
//    BATTERY    a pill that fills
//    NETWORK    a clover with the signal
//    MEDIA      a card with round art and a thick progress line
//    NOTIFS     a cookie that turns into a sun when something is waiting
//    USER · AVATAR · GREETING · CALENDAR
//
//  Every tile is a Surface (Surface.qml): with `interactive` on it answers
//  the pointer — lifts and leans, solidifies out of the wallpaper, a light
//  follows the pointer across the silhouette, the silhouette turns a
//  quarter-lobe, a press squashes. Clicks do what the widget is about
//  (WidgetActions.qml): the media card plays, pauses, skips, seeks and
//  takes the wheel as volume; the clock and calendar peek at the date and
//  the week; the rest open what they stand for. Right-click edits.
//
//  Everything is sized by its content (never by its own height), so the
//  wallpaper layer can scale it into the box you dragged without loops.
//  Motion is event-driven only — a morph, a roll, a fill, the pointer —
//  never an idle loop, so a still desktop costs nothing. WALLPAPER →
//  LIVING DESKTOP → SHAPE MOTION switches all of it off.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    required property string wid
    // Per-widget silhouette override ("" = the widget's own choice).
    property string shape: ""
    property real fillOpacity: 0.85
    readonly property var mpris: Lyrics.bridge
    // The wallpaper turns this on; the DESKTOP editor's previews leave it
    // off so its tiles keep their own drag.
    property bool interactive: false

    // SHAPES CHANGE ON HOVER: what a silhouette turns into under the pointer
    // — the widget's HOVER SHAPE, "none" to stay, or a partner of its own.
    function kindOf(own: string, hot: bool): string {
        if (!hot || !Config.wallpaper.shapeHoverMorph)
            return own;
        const want = root.opts.hoverShape ?? "";
        if (want === "none")
            return own;
        return want !== "" && want !== own ? want : Appearance.hoverPartner(own);
    }

    // Per-widget choices (DESKTOP inspector); empty/-1 = the global setting.
    property string tone: ""       // "" | deep | pastel
    property int slot: 0           // which tone carries the widget: 0 · 1 · 2
    property bool details: true    // the secondary line(s): date, SSID, RAM …
    // Everything else the DESKTOP inspector can set for this one widget.
    property var opts: ({})
    readonly property bool h24: root.opts.hours === "24" ? true : (root.opts.hours === "12" ? false : Config.bar.clock.format24h)
    readonly property string name: (root.opts.name ?? "") !== "" ? root.opts.name : SysInfo.user
    // resources: both | cpu | ram (older desks: DETAILS off meant CPU only)
    readonly property string show: root.opts.show ?? (root.details ? "both" : "cpu")
    readonly property bool controlsAlways: root.opts.controls === "always"

    readonly property bool motion: Config.wallpaper.shapeMotion
    readonly property bool pastel: (root.tone !== "" ? root.tone : Config.wallpaper.shapeTone) === "pastel"

    // ─────────────────────────────────────────────────────────────── tones
    //  Three containers and their ink, from the accent's hue. DEEP sits on
    //  a dark desktop; PASTEL is the soft light look.
    readonly property real hue: Colours.accent.hslHue
    readonly property real hue2: Colours.accentAlt.hslHue
    readonly property var bases: WidgetActions.bases(root.pastel)
    readonly property var inks: [root.pastel ? Qt.hsla(root.hue, 0.62, 0.20, 1) : Qt.hsla(root.hue, 0.80, 0.86, 1), root.pastel ? Qt.hsla(root.hue2, 0.50, 0.20, 1) : Qt.hsla(root.hue2, 0.70, 0.86, 1), root.pastel ? Qt.hsla(root.hue, 0.30, 0.22, 1) : Colours.ink]
    // COLOUR in the inspector rotates which tone is the widget's main one.
    readonly property int rot: ((root.slot % 3) + 3) % 3
    readonly property color tone1: root.bases[root.rot]
    readonly property color tone2: root.bases[(root.rot + 1) % 3]
    readonly property color tone3: root.bases[(root.rot + 2) % 3]
    readonly property color on1: root.inks[root.rot]
    readonly property color on2: root.inks[(root.rot + 1) % 3]
    readonly property color on3: root.inks[(root.rot + 2) % 3]
    readonly property color strong: root.pastel ? Qt.hsla(root.hue, 0.58, 0.34, 1) : Colours.accent
    readonly property color strong2: root.pastel ? Qt.hsla(root.hue2, 0.34, 0.40, 1) : Colours.accentAlt
    readonly property color quiet: root.pastel ? root.on3 : Colours.ink

    // A container at rest melts into the wallpaper at the chosen opacity;
    // under the pointer it solidifies most of the way — it wakes up.
    function fill(c: color, heat: real): color {
        const h = Math.max(0, Math.min(1, heat));
        return Colours.alpha(c, Math.min(1, root.fillOpacity + (1 - root.fillOpacity) * 0.6 * h));
    }

    // The hover ring: a hairline of the tile's own ink, drawn only while lit.
    function ring(c: color, heat: real): color {
        return Colours.alpha(c, 0.5 * Math.max(0, Math.min(1, heat)));
    }
    function ringWidth(heat: real): real {
        return heat > 0.02 ? 1.5 : 0;
    }

    function isoWeek(d: date): int {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - y0) / 86400000 + 1) / 7);
    }

    function clockOf(s: real): string {
        const v = Math.max(0, Math.floor(s));
        const m = Math.floor(v / 60);
        const r = v % 60;
        return `${m}:${r < 10 ? "0" : ""}${r}`;
    }

    // A tall face for the clock: a real condensed cut when one is
    // installed, otherwise the display face squeezed.
    readonly property string tallFamily: Appearance.firstAvailable(["Bebas Neue", "Oswald", "Anton", "Archivo Narrow", "Roboto Condensed"], Appearance.fontFamily.display)
    readonly property real tallSqueeze: root.tallFamily === Appearance.fontFamily.display ? 0.66 : 0.95

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    Loader {
        id: body

        sourceComponent: {
            switch (root.wid) {
            case "clock":
                return sClock;
            case "weather":
                return sWeather;
            case "resources":
                return sResources;
            case "battery":
                return sBattery;
            case "net":
                return sNet;
            case "media":
                return sMedia;
            case "notifs":
                return sNotifs;
            case "user":
                return sUser;
            case "avatar":
                return sAvatar;
            case "greeting":
                return sGreeting;
            case "calendar":
                return sCalendar;
            default:
                return null;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════ clock
    //  Click: the digits roll over to the date (day · month) for a few
    //  seconds and roll back — the clock's own animation, on demand.
    Component {
        id: sClock

        Surface {
            id: clockSurf

            active: root.interactive
            motion: root.motion
            clickable: true
            lift: 0.035
            tilt: 4
            implicitWidth: clockCol.implicitWidth
            implicitHeight: clockCol.implicitHeight

            property bool peek: false

            onActivated: {
                clockSurf.peek = !clockSurf.peek;
                if (clockSurf.peek)
                    peekTimer.restart();
                else
                    peekTimer.stop();
                Sfx.select();
            }

            Timer {
                id: peekTimer

                interval: 4200
                onTriggered: clockSurf.peek = false
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            Column {
                id: clockCol

                spacing: 0

                readonly property string hh: clockSurf.peek ? Qt.formatDateTime(clock.date, "dd") : (root.h24 ? Qt.formatDateTime(clock.date, "HH") : Qt.formatDateTime(clock.date, "hh AP").split(" ")[0])
                readonly property string mm: clockSurf.peek ? Qt.formatDateTime(clock.date, "MM") : Qt.formatDateTime(clock.date, "mm")

                Row {
                    id: digits

                    spacing: 10

                    Row {
                        spacing: 0

                        RollDigit {
                            text: clockCol.hh.charAt(0)
                            color: root.strong
                            family: root.tallFamily
                            squeeze: root.tallSqueeze
                            pixelSize: 120
                            weight: Font.Medium
                            motion: root.motion
                        }
                        RollDigit {
                            text: clockCol.hh.charAt(1)
                            color: root.strong
                            family: root.tallFamily
                            squeeze: root.tallSqueeze
                            pixelSize: 120
                            weight: Font.Medium
                            motion: root.motion
                        }
                    }

                    // The minutes sit a step lower — the split that gives the
                    // clock its rhythm.
                    Row {
                        spacing: 0
                        y: 22

                        RollDigit {
                            text: clockCol.mm.charAt(0)
                            color: root.strong2
                            family: root.tallFamily
                            squeeze: root.tallSqueeze
                            pixelSize: 120
                            weight: Font.Medium
                            motion: root.motion
                        }
                        RollDigit {
                            text: clockCol.mm.charAt(1)
                            color: root.strong2
                            family: root.tallFamily
                            squeeze: root.tallSqueeze
                            pixelSize: 120
                            weight: Font.Medium
                            motion: root.motion
                        }
                    }
                }

                // The line under the digits opens up a little under the
                // pointer; while peeking it says what the digits mean.
                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.details || clockSurf.peek
                    topPadding: 26
                    text: clockSurf.peek ? `DAY  ·  MONTH  ·  ${Qt.formatDateTime(clock.date, "yyyy")}` : Qt.formatDateTime(clock.date, "dddd · d MMMM").toUpperCase() + (root.h24 ? "" : "  " + Qt.formatDateTime(clock.date, "AP").toUpperCase())
                    color: Colours.alpha(root.quiet, 0.8 + 0.2 * clockSurf.heat)
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.DemiBold
                    tracking: 3 + 1.2 * clockSurf.heat
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ weather
    //  Click: ask the sky again — the silhouette turns once while it does.
    Component {
        id: sWeather

        Surface {
            id: wx

            active: root.interactive
            motion: root.motion
            clickable: true
            round: true
            implicitWidth: 176
            implicitHeight: 176

            onActivated: {
                WidgetActions.run("weather");
                wx.spinOnce();
            }

            readonly property string sky: {
                if (root.shape !== "")
                    return root.shape;
                if (!Weather.ready)
                    return "circle";
                switch (Weather.mood) {
                case "clear":
                    return "sun";
                case "rain":
                    return "clover";
                case "thunder":
                    return "burst";
                case "snow":
                    return "flower";
                case "fog":
                    return "circle";
                default:
                    return "cookie";
                }
            }

            M3Shape {
                anchors.fill: parent
                kind: root.kindOf(wx.sky, wx.hovered)
                color: root.fill(root.tone1, wx.heat)
                motion: root.motion
                spin: wx.spin
                sheen: wx.glow
                sheenX: wx.px
                sheenY: wx.py
                borderColor: root.ring(root.on1, wx.heat)
                borderWidth: root.ringWidth(wx.heat)
            }

            P5Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 30
                anchors.topMargin: 34
                text: Weather.ready ? Weather.short : "—"
                color: root.on1
                font.family: Appearance.fontFamily.display
                font.pixelSize: 54
                font.weight: Font.Medium
                tracking: -2
            }

            Icon {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 34
                anchors.bottomMargin: 34
                name: Weather.ready ? Weather.icon : "cloud_off"
                filled: true
                color: root.on1
                font.pixelSize: 50
                // The icon drifts toward the pointer a touch — parallax
                // against the lean of the shape behind it.
                transform: Translate {
                    x: wx.nx * 4 * wx.heat
                    y: wx.ny * 4 * wx.heat
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════ resources
    //  Two tiles, each its own surface. Click either: the system monitor.
    //  Under the pointer the CPU history fills in below its line.
    Component {
        id: sResources

        Row {
            spacing: 10

            // CPU — a card with its own recent history drawn inside it.
            Surface {
                id: cpuSurf

                active: root.interactive
                motion: root.motion
                clickable: true
                lift: 0.04
                tilt: 5
                visible: root.show !== "ram"
                width: 208
                height: 124

                onActivated: WidgetActions.run("resources")

                property real shown: SysInfo.cpuPercent
                Behavior on shown {
                    enabled: root.motion
                    NumberAnimation {
                        duration: 700
                        easing.type: Easing.OutCubic
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 30
                    color: root.fill(root.tone1, cpuSurf.heat)
                    border.width: root.ringWidth(cpuSurf.heat)
                    border.color: root.ring(root.on1, cpuSurf.heat)
                    antialiasing: true
                }

                Sheen {
                    anchors.fill: parent
                    radius: 30
                    strength: cpuSurf.glow
                    lightX: cpuSurf.px
                    lightY: cpuSurf.py
                }

                P5Text {
                    x: 20
                    y: 16
                    text: "CPU"
                    color: root.on1
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.DemiBold
                    tracking: 2
                }

                Shape {
                    id: spark

                    x: 16
                    y: 36
                    width: parent.width - 32
                    height: 44
                    // a live polyline: the geometry renderer (see Resources.qml)
                    preferredRendererType: Shape.GeometryRenderer
                    layer.enabled: true
                    layer.samples: 4

                    readonly property var pts: {
                        const h = SysInfo.cpuHistory ?? [];
                        const n = Math.min(h.length, 36);
                        const out = [];
                        for (let i = 0; i < n; i++) {
                            const v = Math.max(0, Math.min(100, h[h.length - n + i] ?? 0));
                            out.push(Qt.point(n > 1 ? i / (n - 1) * spark.width : 0, spark.height - v / 100 * spark.height));
                        }
                        return out;
                    }
                    // The same line closed down to the floor — the area
                    // under it, shown only while the card is lit.
                    readonly property var area: {
                        if (cpuSurf.heat < 0.01 || spark.pts.length < 2)
                            return [];
                        const out = spark.pts.slice();
                        out.push(Qt.point(spark.pts[spark.pts.length - 1].x, spark.height));
                        out.push(Qt.point(spark.pts[0].x, spark.height));
                        out.push(spark.pts[0]);
                        return out;
                    }

                    ShapePath {
                        strokeColor: "transparent"
                        strokeWidth: 0
                        fillColor: Colours.alpha(root.on1, 0.16 * Math.max(0, Math.min(1, cpuSurf.heat)))

                        PathPolyline {
                            path: spark.area
                        }
                    }

                    ShapePath {
                        strokeColor: root.on1
                        strokeWidth: 2 + 0.6 * Math.max(0, Math.min(1, cpuSurf.heat))
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin

                        PathPolyline {
                            path: spark.pts
                        }
                    }
                }

                P5Text {
                    x: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    text: `${Math.round(cpuSurf.shown)}%`
                    color: root.on1
                    font.family: Appearance.fontFamily.display
                    font.pixelSize: 30
                    font.weight: Font.Medium
                }
            }

            // Memory — a pentagon, the number in its heart.
            Surface {
                id: memSurf

                active: root.interactive
                motion: root.motion
                clickable: true
                round: true
                visible: root.show !== "cpu"
                width: 124
                height: 124

                onActivated: WidgetActions.run("resources")

                property real shown: SysInfo.memoryPercent
                Behavior on shown {
                    enabled: root.motion
                    NumberAnimation {
                        duration: 700
                        easing.type: Easing.OutCubic
                    }
                }

                M3Shape {
                    anchors.fill: parent
                    kind: root.kindOf(root.shape !== "" ? root.shape : "pentagon", memSurf.hovered)
                    color: root.fill(root.tone2, memSurf.heat)
                    motion: root.motion
                    spin: memSurf.spin
                    sheen: memSurf.glow
                    sheenX: memSurf.px
                    sheenY: memSurf.py
                    borderColor: root.ring(root.on2, memSurf.heat)
                    borderWidth: root.ringWidth(memSurf.heat)
                }

                Column {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 4
                    spacing: 0

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${Math.round(memSurf.shown)}%`
                        color: root.on2
                        font.family: Appearance.fontFamily.display
                        font.pixelSize: 28
                        font.weight: Font.Medium
                    }
                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "RAM"
                        color: Colours.alpha(root.on2, 0.8)
                        font.pixelSize: Appearance.font.size.tiny
                        font.weight: Font.DemiBold
                        tracking: 2
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ battery
    //  Under the pointer the pill tells you how long it has left.
    Component {
        id: sBattery

        Surface {
            id: battSurf

            active: root.interactive
            motion: root.motion
            lift: 0.05
            tilt: 7
            implicitWidth: 84
            implicitHeight: 176

            readonly property real level: Battery.available ? Battery.percent / 100 : 1

            Rectangle {
                id: pill

                anchors.fill: parent
                radius: 42
                color: root.fill(root.tone3, battSurf.heat)
                clip: true
                antialiasing: true

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(parent.radius * 0.6, parent.height * battSurf.level)
                    radius: parent.radius
                    color: Battery.critical ? Colours.alpha(Colours.danger, 0.85) : (Battery.low ? Colours.alpha(Colours.warning, 0.85) : root.fill(root.tone1, battSurf.heat))
                    antialiasing: true

                    Behavior on height {
                        enabled: root.motion
                        NumberAnimation {
                            duration: 900
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 42
                color: "transparent"
                border.width: root.ringWidth(battSurf.heat)
                border.color: root.ring(root.on1, battSurf.heat)
                antialiasing: true
            }

            Sheen {
                anchors.fill: parent
                radius: 42
                strength: battSurf.glow
                lightX: battSurf.px
                lightY: battSurf.py
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 22 - 6 * (1 - battSurf.heat)
                visible: Battery.timeRemaining !== "" && battSurf.heat > 0.01
                opacity: Math.max(0, Math.min(1, battSurf.heat))
                text: Battery.timeRemaining.toUpperCase()
                color: root.quiet
                font.pixelSize: Appearance.font.size.tiny
                font.weight: Font.DemiBold
                tracking: 1
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                spacing: 2

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: !Battery.available ? "power" : (Battery.charging ? "bolt" : "battery_full")
                    filled: true
                    color: root.on1
                    font.pixelSize: 24
                }
                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Battery.available ? `${Battery.percent}%` : "AC"
                    color: root.on1
                    font.family: Appearance.fontFamily.display
                    font.pixelSize: 22
                    font.weight: Font.Medium
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ network
    //  Click: QUICK SETTINGS, where the networks are.
    Component {
        id: sNet

        Column {
            spacing: 8

            Surface {
                id: netSurf

                anchors.horizontalCenter: parent.horizontalCenter
                active: root.interactive
                motion: root.motion
                clickable: true
                round: true
                width: 132
                height: 132

                onActivated: WidgetActions.run("net")

                M3Shape {
                    anchors.fill: parent
                    kind: root.kindOf(root.shape !== "" ? root.shape : (Net.connected ? "clover" : "circle"), netSurf.hovered)
                    color: root.fill(root.tone2, netSurf.heat)
                    motion: root.motion
                    spin: netSurf.spin
                    sheen: netSurf.glow
                    sheenX: netSurf.px
                    sheenY: netSurf.py
                    borderColor: root.ring(root.on2, netSurf.heat)
                    borderWidth: root.ringWidth(netSurf.heat)
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: Net.connected ? (Net.type === "wifi" ? "wifi" : "lan") : "wifi_off"
                        filled: true
                        color: root.on2
                        font.pixelSize: 38
                    }
                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Net.connected && Net.type === "wifi"
                        text: `${Net.strength}%`
                        color: root.on2
                        font.pixelSize: Appearance.font.size.small
                        font.weight: Font.DemiBold
                    }
                }
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 150
                visible: root.details
                horizontalAlignment: Text.AlignHCenter
                text: Net.connected ? Net.label.toUpperCase() : "OFFLINE"
                color: Colours.alpha(root.quiet, 0.8 + 0.2 * netSurf.heat)
                font.pixelSize: Appearance.font.size.tiny
                font.weight: Font.DemiBold
                tracking: 2 + netSurf.heat
                elide: Text.ElideRight
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════ media
    //  The art is the play button (a veil and the glyph rise over it under
    //  the pointer). Hover the card and the artist line hands over to the
    //  transport: previous · next · elapsed / length. The progress line
    //  thickens under the pointer and seeks on a click or a drag. The wheel
    //  anywhere on the card is the volume.
    Component {
        id: sMedia

        Surface {
            id: card

            active: root.interactive
            motion: root.motion
            scrollable: true
            lift: 0.03
            tilt: 3.5
            implicitWidth: 300
            implicitHeight: 116

            onScrolled: steps => WidgetActions.volume(steps)

            readonly property bool has: root.mpris?.has ?? false
            readonly property bool playing: root.mpris?.playing ?? false
            readonly property real length: root.mpris?.length ?? 0
            readonly property bool canSeek: card.has && card.length > 0 && (root.mpris?.player?.canSeek ?? false)
            readonly property string art: root.mpris?.artUrl ?? ""
            property real pos: 0
            // -1 = not scrubbing; 0…1 while the progress line is held.
            property real scrub: -1
            readonly property real frac: card.scrub >= 0 ? card.scrub : Math.min(1, card.pos / Math.max(1, card.length))

            Timer {
                interval: 1000
                repeat: true
                running: card.has && card.playing && !Locker.locked
                triggeredOnStart: true
                onTriggered: card.pos = root.mpris ? root.mpris.position() : 0
            }

            Rectangle {
                anchors.fill: parent
                radius: 32
                color: root.fill(root.tone3, card.heat)
                border.width: root.ringWidth(card.heat)
                border.color: root.ring(root.on3, card.heat)
                antialiasing: true
            }

            Sheen {
                anchors.fill: parent
                radius: 32
                strength: card.glow * 0.8
                lightX: card.px
                lightY: card.py
            }

            Surface {
                id: artSurf

                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 88
                height: 88
                active: root.interactive
                motion: root.motion
                clickable: card.has
                round: true
                lift: 0.08
                tilt: 8

                onActivated: WidgetActions.run("media")

                M3Shape {
                    anchors.fill: parent
                    kind: root.kindOf(root.shape !== "" ? root.shape : "cookie", artSurf.hovered)
                    color: root.fill(root.tone1, Math.max(card.heat * 0.5, artSurf.heat))
                    motion: root.motion
                    spin: artSurf.spin
                    sheen: artSurf.glow
                    sheenX: artSurf.px
                    sheenY: artSurf.py
                }

                ClippingRectangle {
                    anchors.centerIn: parent
                    width: 68
                    height: 68
                    radius: 34
                    color: "transparent"
                    visible: card.art !== ""

                    Image {
                        id: artImg

                        anchors.fill: parent
                        source: card.art
                        sourceSize.width: 136
                        sourceSize.height: 136
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        opacity: status === Image.Ready ? 1 : 0

                        Behavior on opacity {
                            enabled: root.motion
                            NumberAnimation {
                                duration: 420
                            }
                        }
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    visible: card.art === ""
                    opacity: 1 - (card.has ? Math.max(0, Math.min(1, artSurf.heat)) : 0)
                    name: card.has ? "music_note" : "music_off"
                    filled: true
                    color: root.on1
                    font.pixelSize: 34
                }

                // The play button, rising out of the art under the pointer.
                Rectangle {
                    anchors.centerIn: parent
                    width: 68
                    height: 68
                    radius: 34
                    visible: card.has && artSurf.heat > 0.01
                    color: card.art !== "" ? Qt.rgba(0, 0, 0, 0.42 * Math.max(0, Math.min(1, artSurf.heat))) : "transparent"
                    antialiasing: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: card.has && artSurf.heat > 0.01
                    opacity: Math.max(0, Math.min(1, artSurf.heat))
                    scale: 0.7 + 0.3 * Math.max(0, Math.min(1, artSurf.heat)) - 0.1 * artSurf.down
                    name: card.playing ? "pause" : "play_arrow"
                    filled: true
                    color: card.art !== "" ? "white" : root.on1
                    font.pixelSize: 40
                }
            }

            Column {
                anchors.left: artSurf.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                P5Text {
                    width: parent.width
                    text: card.has ? (root.mpris?.title ?? "") : "NOTHING PLAYING"
                    color: root.on3
                    font.pixelSize: Appearance.font.size.normal
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                // The artist at rest; the transport while the card is lit.
                Item {
                    width: parent.width
                    height: 26
                    visible: card.has

                    readonly property real swap: root.controlsAlways ? 1 : Math.max(0, Math.min(1, card.heat))

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -6 * parent.swap
                        width: parent.width
                        visible: root.details && opacity > 0.01
                        opacity: 1 - parent.swap
                        text: root.mpris?.artist ?? ""
                        color: Colours.alpha(root.on3, 0.7)
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 6 * (1 - parent.swap)
                        spacing: 4
                        visible: opacity > 0.01
                        opacity: parent.swap

                        Repeater {
                            model: 2

                            Surface {
                                id: btn

                                required property int index

                                width: 26
                                height: 26
                                readonly property bool can: btn.index === 0 ? (root.mpris?.canPrev ?? false) : (root.mpris?.canNext ?? false)

                                active: root.interactive && (card.hovered || root.controlsAlways)
                                motion: root.motion
                                clickable: btn.can
                                opacity: btn.can ? 1 : 0.35
                                round: true
                                lift: 0.12
                                tilt: 0

                                onActivated: {
                                    if (btn.index === 0)
                                        root.mpris?.prev();
                                    else
                                        root.mpris?.next();
                                    Sfx.select();
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: Colours.alpha(root.on3, 0.08 + 0.14 * Math.max(0, Math.min(1, btn.heat)))
                                    antialiasing: true
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    name: btn.index === 0 ? "skip_previous" : "skip_next"
                                    filled: true
                                    color: root.on3
                                    font.pixelSize: 18
                                }
                            }
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: 6
                            visible: card.length > 0
                            text: `${root.clockOf(card.frac * card.length)} / ${root.clockOf(card.length)}`
                            color: Colours.alpha(root.on3, 0.75)
                            font.family: Appearance.fontFamily.mono
                            font.pixelSize: Appearance.font.size.tiny
                        }
                    }
                }

                // The progress line — the seek bar under the pointer.
                Item {
                    id: seekBar

                    width: parent.width
                    height: 16
                    visible: card.has && card.length > 0

                    readonly property real thick: seekArea.containsMouse || seekArea.pressed ? 10 : 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: seekBar.thick
                        radius: height / 2
                        color: Colours.alpha(root.on3, 0.15)
                        antialiasing: true

                        Behavior on height {
                            enabled: root.motion
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        height: seekBar.thick
                        radius: height / 2
                        color: root.strong
                        antialiasing: true
                        width: Math.max(height, parent.width * card.frac)

                        Behavior on height {
                            enabled: root.motion
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on width {
                            enabled: root.motion && card.scrub < 0
                            NumberAnimation {
                                duration: 900
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    MouseArea {
                        id: seekArea

                        anchors.fill: parent
                        anchors.topMargin: -4
                        anchors.bottomMargin: -4
                        enabled: root.interactive && card.canSeek
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true

                        function at(x: real): real {
                            return Math.max(0, Math.min(1, x / Math.max(1, seekBar.width)));
                        }

                        onPressed: mouse => card.scrub = seekArea.at(mouse.x)
                        onPositionChanged: mouse => {
                            if (seekArea.pressed)
                                card.scrub = seekArea.at(mouse.x);
                        }
                        onReleased: {
                            if (card.scrub >= 0) {
                                root.mpris?.seek(card.scrub);
                                card.pos = card.scrub * card.length;
                            }
                            card.scrub = -1;
                        }
                        onCanceled: card.scrub = -1
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════ notifs
    //  Click: the notification centre.
    Component {
        id: sNotifs

        Surface {
            id: bell

            active: root.interactive
            motion: root.motion
            clickable: true
            round: true
            implicitWidth: 132
            implicitHeight: 132

            onActivated: WidgetActions.run("notifs")

            readonly property int n: Notifs.unread

            M3Shape {
                id: bellShape

                anchors.fill: parent
                kind: root.kindOf(root.shape !== "" ? root.shape : (bell.n > 0 ? "sun" : "cookie"), bell.hovered)
                color: root.fill(bell.n > 0 ? root.tone1 : root.tone3, bell.heat)
                motion: root.motion
                spin: bell.spin
                sheen: bell.glow
                sheenX: bell.px
                sheenY: bell.py
                borderColor: root.ring(bell.n > 0 ? root.on1 : root.on3, bell.heat)
                borderWidth: root.ringWidth(bell.heat)
            }

            Column {
                anchors.centerIn: parent
                spacing: -2

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: bell.n > 0 ? "notifications_active" : "notifications"
                    filled: bell.n > 0 || bell.heat > 0.5
                    color: bell.n > 0 ? root.on1 : root.on3
                    font.pixelSize: 34
                    // A little ring of the bell under the pointer.
                    rotation: 12 * Math.sin(Math.max(0, Math.min(1, bell.heat)) * Math.PI) * (bell.n > 0 ? 1 : 0.5)
                    transformOrigin: Item.Top
                }
                P5Text {
                    id: count

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bell.n > 0 ? `${bell.n}` : "CLEAR"
                    color: bell.n > 0 ? root.on1 : Colours.alpha(root.on3, 0.75)
                    font.family: bell.n > 0 ? Appearance.fontFamily.display : Appearance.fontFamily.body
                    font.pixelSize: bell.n > 0 ? 30 : Appearance.font.size.tiny
                    font.weight: Font.DemiBold
                    tracking: bell.n > 0 ? 0 : 2
                }
            }

            onNChanged: if (root.motion)
                pop.restart()

            SequentialAnimation {
                id: pop

                NumberAnimation {
                    target: bell
                    property: "scale"
                    to: 1.08
                    duration: 120
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: bell
                    property: "scale"
                    to: 1
                    duration: 380
                    easing.type: Easing.OutBack
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════ user
    //  The whole row is one surface. Click: the session menu.
    Component {
        id: sUser

        Surface {
            id: userSurf

            active: root.interactive
            motion: root.motion
            clickable: true
            lift: 0.04
            tilt: 3
            implicitWidth: userRow.implicitWidth
            implicitHeight: userRow.implicitHeight

            onActivated: WidgetActions.run("user")

            Row {
                id: userRow

                spacing: 14

                Item {
                    width: 92
                    height: 92

                    M3Shape {
                        anchors.fill: parent
                        kind: root.kindOf(root.shape !== "" ? root.shape : "cookie", userSurf.hovered)
                        color: root.fill(root.tone1, userSurf.heat)
                        motion: root.motion
                        spin: userSurf.spin
                        sheen: userSurf.glow
                        sheenX: userSurf.px - parent.x
                        sheenY: userSurf.py - parent.y
                        borderColor: root.ring(root.on1, userSurf.heat)
                        borderWidth: root.ringWidth(userSurf.heat)
                    }
                    ClippingRectangle {
                        anchors.centerIn: parent
                        width: 70
                        height: 70
                        radius: 35
                        color: "transparent"

                        Icon {
                            anchors.centerIn: parent
                            name: "person"
                            color: root.on1
                            font.pixelSize: 36
                            visible: userFace.status !== Image.Ready
                        }
                        Image {
                            id: userFace

                            anchors.fill: parent
                            source: `file://${Quickshell.env("HOME") ?? ""}/.face`
                            sourceSize.width: 140
                            sourceSize.height: 140
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    P5Text {
                        text: root.name
                        color: root.quiet
                        font.family: Appearance.fontFamily.display
                        font.pixelSize: 28
                        font.weight: Font.Medium
                    }
                    P5Text {
                        visible: root.details
                        text: SysInfo.hostname.toUpperCase()
                        color: Colours.alpha(root.quiet, 0.65 + 0.25 * userSurf.heat)
                        font.pixelSize: Appearance.font.size.tiny
                        font.weight: Font.DemiBold
                        tracking: 2 + userSurf.heat
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════ avatar
    //  Click: the session menu.
    Component {
        id: sAvatar

        Surface {
            id: avSurf

            active: root.interactive
            motion: root.motion
            clickable: true
            round: true
            implicitWidth: 140
            implicitHeight: 140

            onActivated: WidgetActions.run("avatar")

            M3Shape {
                anchors.fill: parent
                kind: root.kindOf(root.shape !== "" ? root.shape : "flower", avSurf.hovered)
                color: root.fill(root.tone1, avSurf.heat)
                motion: root.motion
                spin: avSurf.spin
                sheen: avSurf.glow
                sheenX: avSurf.px
                sheenY: avSurf.py
                borderColor: root.ring(root.on1, avSurf.heat)
                borderWidth: root.ringWidth(avSurf.heat)
            }
            ClippingRectangle {
                anchors.centerIn: parent
                width: 104
                height: 104
                radius: 52
                color: "transparent"

                Icon {
                    anchors.centerIn: parent
                    name: "person"
                    color: root.on1
                    font.pixelSize: 52
                    visible: avatarFace.status !== Image.Ready
                }
                Image {
                    id: avatarFace

                    anchors.fill: parent
                    source: `file://${Quickshell.env("HOME") ?? ""}/.face`
                    sourceSize.width: 208
                    sourceSize.height: 208
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════ greeting
    //  Click: the launcher. An accent line draws itself under the words
    //  while the pointer rests on them — the greeting as a link.
    Component {
        id: sGreeting

        Surface {
            id: greetSurf

            active: root.interactive
            motion: root.motion
            clickable: true
            lift: 0.03
            tilt: 3
            implicitWidth: greetCol.implicitWidth
            implicitHeight: greetCol.implicitHeight

            onActivated: WidgetActions.run("greeting")

            SystemClock {
                id: gclock
                precision: SystemClock.Minutes
            }

            Column {
                id: greetCol

                spacing: 2

                readonly property int h: gclock.date.getHours()

                P5Text {
                    id: greetWords

                    text: greetCol.h >= 5 && greetCol.h < 12 ? "Good morning" : (greetCol.h >= 12 && greetCol.h < 18 ? "Good afternoon" : (greetCol.h >= 18 && greetCol.h < 23 ? "Good evening" : "Good night"))
                    color: root.strong
                    font.family: root.tallFamily
                    font.pixelSize: 56
                    font.weight: Font.Medium
                }

                Rectangle {
                    width: greetWords.width * Math.max(0, Math.min(1, greetSurf.heat))
                    height: 3
                    radius: 1.5
                    color: root.strong2
                    visible: width > 0.5
                    antialiasing: true
                }

                P5Text {
                    visible: root.details
                    text: root.name.toUpperCase()
                    color: Colours.alpha(root.quiet, 0.7 + 0.2 * greetSurf.heat)
                    font.pixelSize: Appearance.font.size.small
                    font.weight: Font.DemiBold
                    tracking: 3 + greetSurf.heat
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════ calendar
    //  Click: the day rolls over to the week number for a few seconds.
    Component {
        id: sCalendar

        Surface {
            id: calSurf

            active: root.interactive
            motion: root.motion
            clickable: true
            lift: 0.05
            tilt: 7
            implicitWidth: 132
            implicitHeight: 150

            property bool peek: false

            onActivated: {
                calSurf.peek = !calSurf.peek;
                if (calSurf.peek)
                    calPeek.restart();
                else
                    calPeek.stop();
                Sfx.select();
            }

            Timer {
                id: calPeek

                interval: 4200
                onTriggered: calSurf.peek = false
            }

            SystemClock {
                id: cal
                precision: SystemClock.Minutes
            }

            Rectangle {
                anchors.fill: parent
                radius: 34
                color: root.fill(root.tone3, calSurf.heat)
                border.width: root.ringWidth(calSurf.heat)
                border.color: root.ring(root.on3, calSurf.heat)
                antialiasing: true
            }

            Sheen {
                anchors.fill: parent
                radius: 34
                strength: calSurf.glow
                lightX: calSurf.px
                lightY: calSurf.py
            }

            Column {
                anchors.centerIn: parent
                spacing: -4

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: calSurf.peek ? "WEEK" : Qt.formatDateTime(cal.date, "MMMM").toUpperCase()
                    color: root.strong
                    font.pixelSize: Appearance.font.size.tiny
                    font.weight: Font.Bold
                    tracking: 2
                }
                RollDigit {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: calSurf.peek ? `${root.isoWeek(cal.date)}` : Qt.formatDateTime(cal.date, "d")
                    color: root.on3
                    family: root.tallFamily
                    squeeze: root.tallSqueeze
                    pixelSize: 78
                    weight: Font.Medium
                    motion: root.motion
                }
                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.details || calSurf.peek
                    text: calSurf.peek ? Qt.formatDateTime(cal.date, "yyyy") : Qt.formatDateTime(cal.date, "dddd").toUpperCase()
                    color: Colours.alpha(root.on3, 0.7)
                    font.pixelSize: Appearance.font.size.tiny
                    font.weight: Font.DemiBold
                    tracking: 2
                }
            }
        }
    }
}
