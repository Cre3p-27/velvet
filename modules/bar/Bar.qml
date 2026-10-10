//  VELVET  ·  modules/bar/Bar.qml
//  The strip itself. One layout definition drives both orientations — every
//  entry asks `vertical` and arranges itself accordingly.
import qs.config
import qs.services
import qs.components
import "entries"
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property ShellScreen screen
    required property bool vertical
    required property var barWindow

    readonly property int thickness: Config.bar.thickness
    readonly property int inner: thickness - Config.bar.padding * 2

    // TASKBAR → STYLE: VELVET wears the halftone, the accent hairline and
    // the wedge; CLEAN is the plain strip; FLOATING is a pill that hugs its
    // modules, centred on the edge (spacers close up into gaps).
    readonly property string barStyle: ["velvet", "clean", "floating"].indexOf(Config.bar.style) >= 0 ? Config.bar.style : "velvet"
    readonly property bool floating: root.barStyle === "floating"
    // SCREEN FRAME → CONNECTED: bar and frame are one surface — the bar
    // paints its strip in the frame's colour (BarWindow does, margin and
    // all) and wears no Persona trim, the frame leaves the strip to it. Only
    // while the bar holds its edge (pinned, not floating), exactly like the
    // frame decides it.
    // While the settings are open the bar is lifted above them as a live
    // preview and the frame stays below — then the bar wears its own plate.
    // (a hover bar too: it slides out of the frame's band — BarWindow)
    readonly property bool joined: Config.bar.frame && Config.bar.frameConnect && !root.floating
    readonly property bool plain: root.barStyle !== "velvet" || root.joined

    // Where the plate is drawn — the whole strip, or the floating pill.
    // BarWindow reads these to let clicks beside the pill through.
    readonly property real plateX: root.floating && !root.vertical ? layout.x - Config.bar.padding : 0
    readonly property real plateY: root.floating && root.vertical ? layout.y - Config.bar.padding : 0
    readonly property real plateW: root.floating && !root.vertical ? layout.width + Config.bar.padding * 2 : root.width
    readonly property real plateH: root.floating && root.vertical ? layout.height + Config.bar.padding * 2 : root.height

    property var quickPanel: null

    function handleWheel(pos: real, angleDelta: point): void {
        const along = root.vertical ? root.height : root.width;
        const up = angleDelta.y > 0;

        // Over the workspace cluster: change workspace. Elsewhere: first half
        // of the bar is volume, second half is brightness.
        if (Config.bar.scroll.workspaces && pos < along * 0.34 && root.entries.indexOf("workspaces") !== -1) {
            Hypr.cycleWorkspace(up ? -1 : 1);
        } else if (Config.bar.scroll.volume && pos < along * 0.67) {
            if (up)
                Audio.incrementVolume();
            else
                Audio.decrementVolume();
        } else if (Config.bar.scroll.brightness) {
            if (up)
                Brightness.increment();
            else
                Brightness.decrement();
        }
    }

    // ------------------------------------------------------------------ shell
    Plate {
        id: plate

        x: root.plateX
        y: root.plateY
        width: root.plateW
        height: root.plateH
        radius: Appearance.r(Config.bar.rounding)
        color: root.joined ? "transparent" : Colours.alpha(Colours.barBase, Config.bar.opacity)
        antialiasing: true

        Behavior on x {
            enabled: root.floating
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            enabled: root.floating
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: root.floating
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            enabled: root.floating
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutCubic
            }
        }

        Halftone {
            anchors.fill: parent
            visible: !root.plain
            strength: 0.035
            density: 1.6
        }

        // What the settings skin adds along the edge that faces the desktop.
        BarDeco {
            anchors.fill: parent
            vertical: root.vertical
            visible: Appearance.skinned && !root.floating
        }

        // Hairline in the accent — the one bit of colour when nothing is active.
        Rectangle {
            anchors.fill: parent
            visible: !root.plain
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Colours.alpha(Colours.accent, 0.28)
            antialiasing: true
        }

        // Accent wedge pinned to the leading edge. Pure decoration, pure Persona.
        Slash {
            visible: !root.plain
            width: root.vertical ? 3 : 46
            height: root.vertical ? 46 : 3
            shear: root.vertical ? 0 : Appearance.skew
            color: Colours.accent
            opacity: 0.9

            x: root.vertical ? 0 : Config.bar.rounding
            y: root.vertical ? Config.bar.rounding : 0
        }

        layer.enabled: false
    }

    // ------------------------------------------------------------------ layout
    GridLayout {
        id: layout

        // Full length — or, FLOATING, only as long as the modules need,
        // centred on the edge.
        x: root.floating && !root.vertical ? Math.round((root.width - width) / 2) : Config.bar.padding
        y: root.floating && root.vertical ? Math.round((root.height - height) / 2) : Config.bar.padding
        width: root.floating && !root.vertical ? Math.min(implicitWidth, root.width - Config.bar.padding * 2) : root.width - Config.bar.padding * 2
        height: root.floating && root.vertical ? Math.min(implicitHeight, root.height - Config.bar.padding * 2) : root.height - Config.bar.padding * 2

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        columns: root.vertical ? 1 : -1
        rows: root.vertical ? -1 : 1
        rowSpacing: Config.bar.spacing
        columnSpacing: Config.bar.spacing

        Repeater {
            model: root.entries

            Loader {
                id: slot

                required property var modelData
                required property int index

                // Each module lands a beat after the one before it. Short
                // enough to read as a single ripple down the bar rather than
                // as the bar being rebuilt — which it is, every time you
                // rearrange it in the editor.
                opacity: 0

                Component.onCompleted: entrance.start()

                SequentialAnimation {
                    id: entrance

                    PauseAnimation {
                        duration: slot.index * 28
                    }
                    ParallelAnimation {
                        NumberAnimation {
                            target: slot
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Appearance.anim.fast
                        }
                        NumberAnimation {
                            target: slot
                            property: "scale"
                            from: 0.55
                            to: 1
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.4
                        }
                    }
                }

                Layout.alignment: Qt.AlignCenter
                Layout.fillHeight: modelData === "spacer" && root.vertical && !root.floating
                Layout.fillWidth: modelData === "spacer" && !root.vertical && !root.floating
                Layout.preferredWidth: item?.implicitWidth ?? 0
                Layout.preferredHeight: item?.implicitHeight ?? 0

                active: true
                sourceComponent: {
                    switch (modelData) {
                    case "logo":
                        return logoC;
                    case "workspaces":
                        return workspacesC;
                    case "activeWindow":
                        return activeWindowC;
                    case "tray":
                        return trayC;
                    case "clock":
                        return clockC;
                    case "statusIcons":
                        return statusC;
                    case "power":
                        return powerC;
                    case "media":
                        return mediaC;
                    case "resources":
                        return resourcesC;
                    case "weather":
                        return weatherC;
                    case "notifications":
                        return bellC;
                    case "microphone":
                        return micC;
                    case "keyboard":
                        return keyboardC;
                    case "uptime":
                        return uptimeC;
                    case "screenshot":
                        return shotC;
                    case "launcher":
                        return launcherC;
                    case "focus":
                        return focusC;
                    case "scene":
                        return sceneC;
                    case "map":
                        return mapC;
                    case "lyrics":
                        return lyricsC;
                    case "keys":
                        return keysC;
                    case "separator":
                        return separatorC;
                    default:
                        return spacerC;
                    }
                }
            }
        }
    }

    // Order and membership both come from one array, which the layout editor
    // rewrites live. Nothing here needs to know what is in it — but an empty
    // or malformed value must never leave you with no bar to fix it from.
    // A list read back from config.json is a list-like object, not a JS
    // Array — Array.isArray() said no to it, and after every restart the
    // bar fell back to the default layout. Array.from() takes either.
    readonly property var entries: {
        const l = Config.bar.layout;
        const list = l && typeof l !== "string" && typeof l.length === "number" ? Array.from(l) : [];
        return list.length > 0 ? list : ["logo", "workspaces", "spacer", "activeWindow", "spacer", "tray", "clock", "statusIcons", "power"];
    }

    // ------------------------------------------------------------ components
    Component {
        id: spacerC
        Item {
            implicitWidth: 1
            implicitHeight: 1
        }
    }

    Component {
        id: logoC
        Logo {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: workspacesC
        Workspaces {
            vertical: root.vertical
            span: root.inner
            screen: root.screen
            win: root.barWindow
        }
    }

    Component {
        id: activeWindowC
        ActiveWindow {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
            maxLength: root.vertical ? root.height * 0.34 : root.width * 0.28
        }
    }

    Component {
        id: trayC
        Tray {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: clockC
        Clock {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: statusC
        StatusIcons {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: powerC
        PowerButton {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    // Media goes through a path Loader on purpose: it is the only entry that
    // imports the MPRIS service, and a build without it should cost this
    // module rather than the whole bar.
    Component {
        id: mediaC

        Loader {
            id: mediaSlot

            property bool vertical: root.vertical
            property int span: root.inner

            source: Qt.resolvedUrl("entries/Media.qml")

            onLoaded: {
                item.vertical = Qt.binding(() => mediaSlot.vertical);
                item.span = Qt.binding(() => mediaSlot.span);
            }
        }
    }

    Component {
        id: resourcesC
        Resources {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: weatherC
        WeatherEntry {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: bellC
        NotifBell {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: micC
        Microphone {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: keyboardC
        KeyboardLayout {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: uptimeC
        Uptime {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: shotC
        Screenshot {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: launcherC
        LauncherButton {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: focusC
        FocusToggle {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: sceneC
        SceneButton {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: mapC
        MapButton {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: lyricsC
        LyricsButton {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: keysC
        KeysButton {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }

    Component {
        id: separatorC
        Separator {
            vertical: root.vertical
            span: root.inner
            win: root.barWindow
        }
    }
}
