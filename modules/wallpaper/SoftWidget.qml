//  VELVET  ·  modules/wallpaper/SoftWidget.qml
//  The SOFT look for desktop widgets (WALLPAPER → WIDGET FRAME → SOFT):
//  the round Material pieces of the inspo desktops, all in the accent's
//  one deep tone.
//
//    CLOCK      hours over minutes in a gear, the hands sweeping over them
//    WEATHER    a pill on a slant, the temperature and the sky in it —
//               or, with a SHAPE picked, that shape with both upright
//    MEDIA      the music card — the cover in its frame (wavy, or the
//               SHAPE picked), ring, five buttons, squiggle
//    CALENDAR   the date in a pentagon
//    GREETING   hello and your name in a cloud
//
//  Any other widget keeps the SHAPES drawing (Widgets.qml decides). Each
//  answers the pointer through Surface.qml like every other look: it lifts
//  and leans, a click does what WidgetActions says, right-click edits.
//  Sized by content, never by its own height.
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import Quickshell
import QtQuick

Item {
    id: root

    required property string wid
    // Per-widget silhouette override ("" = the widget's own).
    property string shape: ""
    property real fillOpacity: 0.92
    property bool interactive: false
    property var opts: ({})
    readonly property bool h24: root.opts.hours === "24" ? true : (root.opts.hours === "12" ? false : Config.bar.clock.format24h)
    readonly property string name: (root.opts.name ?? "") !== "" ? root.opts.name : SysInfo.user

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

    // The kinds this look draws itself.
    function handles(w: string): bool {
        return ["clock", "weather", "media", "calendar", "greeting"].indexOf(w) >= 0;
    }

    readonly property color accent: Colours.accent
    readonly property color tone: Colours.tone
    readonly property color toneHigh: Colours.toneHigh
    readonly property string family: Appearance.fontFamily.soft

    implicitWidth: body.implicitWidth
    implicitHeight: body.implicitHeight

    SystemClock {
        id: clock

        // The dial's seconds dot needs seconds; the rest is happy with minutes.
        precision: root.wid === "clock" ? SystemClock.Seconds : SystemClock.Minutes
    }

    Loader {
        id: body

        sourceComponent: {
            switch (root.wid) {
            case "clock":
                return sClock;
            case "weather":
                return sWeather;
            case "media":
                return sMedia;
            case "calendar":
                return sCalendar;
            case "greeting":
                return sGreeting;
            default:
                return null;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════ clock
    Component {
        id: sClock

        Surface {
            id: cs

            active: root.interactive
            clickable: false
            round: true
            lift: 0.04
            tilt: 5
            implicitWidth: 240
            implicitHeight: 240

            ClockDial {
                anchors.fill: parent
                size: 240
                now: clock.date
                shape: root.kindOf(root.shape !== "" ? root.shape : "sun", cs.hovered)
                h24: root.h24
                family: root.family
                weight: Font.Bold
                digitScale: 0.8
                fill: Colours.alpha(root.tone, root.fillOpacity + (1 - root.fillOpacity) * 0.6 * cs.heat)
                hourColour: root.accent
                minuteColour: Colours.ink
                spin: cs.spin * 0.3
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ weather
    //  The pill leans; what is in it stands upright. A picked shape stands
    //  upright too, with the sky over the temperature in it.
    Component {
        id: sWeather

        Surface {
            id: ws

            active: root.interactive
            clickable: true
            lift: 0.04
            tilt: 5
            implicitWidth: 250
            implicitHeight: 190
            onActivated: WidgetActions.run("weather")

            readonly property bool slant: root.shape === ""

            Plate {
                anchors.centerIn: parent
                visible: ws.slant
                width: 262
                height: 124
                radius: Appearance.pill(height)
                rotation: -36 + ws.nx * 3
                color: Colours.alpha(root.tone, root.fillOpacity + (1 - root.fillOpacity) * 0.6 * ws.heat)
                antialiasing: true
            }

            Text {
                visible: ws.slant
                x: parent.width * 0.5
                y: parent.height * 0.14
                text: Weather.ready ? Weather.short : "—"
                color: Colours.ink
                font.family: root.family
                font.pixelSize: 46
                font.weight: Font.Bold
            }

            Icon {
                visible: ws.slant
                x: parent.width * 0.16
                y: parent.height * 0.42
                name: Weather.ready ? Weather.icon : "cloud"
                color: root.accent
                font.pixelSize: 64
                filled: true
            }

            M3Shape {
                anchors.centerIn: parent
                visible: !ws.slant
                width: 200
                height: 200
                kind: ws.slant ? "circle" : root.kindOf(root.shape, ws.hovered)
                color: Colours.alpha(root.tone, root.fillOpacity + (1 - root.fillOpacity) * 0.6 * ws.heat)
                intro: false
                spin: ws.spin * 0.3
            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 200 * Appearance.shapeCentre(root.shape)
                visible: !ws.slant
                spacing: 0

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Weather.ready ? Weather.icon : "cloud"
                    color: root.accent
                    font.pixelSize: 52
                    filled: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.ready ? Weather.short : "—"
                    color: Colours.ink
                    font.family: root.family
                    font.pixelSize: 38
                    font.weight: Font.Bold
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════ media
    Component {
        id: sMedia

        Surface {
            id: ms

            active: root.interactive
            clickable: false
            scrollable: true
            lift: 0.03
            tilt: 3
            implicitWidth: card.implicitWidth
            implicitHeight: card.implicitHeight
            onScrolled: steps => WidgetActions.volume(steps)

            SoftMediaCard {
                id: card

                anchors.fill: parent
                u: 0.8
                tone: root.tone
                toneHigh: root.toneHigh
                accent: root.accent
                family: root.family
                interactive: root.interactive
                coverShape: root.kindOf(root.shape !== "" ? root.shape : "wavy", ms.hovered)
                coverSpin: ms.spin * 0.3
                fillOpacity: root.fillOpacity + (1 - root.fillOpacity) * 0.6 * ms.heat
            }
        }
    }

    // ════════════════════════════════════════════════════════════ calendar
    Component {
        id: sCalendar

        Surface {
            id: cal

            active: root.interactive
            clickable: false
            round: true
            lift: 0.04
            tilt: 5
            implicitWidth: 200
            implicitHeight: 200

            M3Shape {
                anchors.fill: parent
                kind: root.kindOf(root.shape !== "" ? root.shape : "penta", cal.hovered)
                color: Colours.alpha(root.tone, root.fillOpacity + (1 - root.fillOpacity) * 0.6 * cal.heat)
                intro: false
                spin: cal.spin * 0.3
            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: root.shape !== "" ? 200 * Appearance.shapeCentre(root.shape) : 8
                spacing: 4

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "calendar_today"
                    color: root.accent
                    font.pixelSize: 28
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "ddd d MMM").toLowerCase()
                    color: Colours.ink
                    font.family: root.family
                    font.pixelSize: 18
                    font.weight: Font.Medium
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "yyyy")
                    color: Colours.alpha(Colours.ink, 0.7)
                    font.family: root.family
                    font.pixelSize: 14
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════ greeting
    Component {
        id: sGreeting

        Surface {
            id: gs

            active: root.interactive
            clickable: true
            round: true
            lift: 0.03
            tilt: 4
            implicitWidth: 380
            implicitHeight: 380
            onActivated: WidgetActions.run("greeting")

            readonly property string hello: {
                const h = clock.date.getHours();
                if (h < 5)
                    return "Good night,";
                if (h < 12)
                    return "Good morning,";
                if (h < 18)
                    return "Good afternoon,";
                if (h < 22)
                    return "Good evening,";
                return "Good night,";
            }

            M3Shape {
                anchors.fill: parent
                kind: root.kindOf(root.shape !== "" ? root.shape : "scallop", gs.hovered)
                color: Colours.alpha(root.tone, root.fillOpacity + (1 - root.fillOpacity) * 0.6 * gs.heat)
                intro: false
                spin: gs.spin * 0.2
            }

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: gs.hello
                    color: Colours.alpha(Colours.ink, 0.5)
                    font.family: root.family
                    font.pixelSize: 32
                    font.weight: Font.Light
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, gs.width * 0.72)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.name
                    color: root.accent
                    font.family: root.family
                    font.pixelSize: 62
                    font.weight: Font.Bold
                }
            }
        }
    }
}
