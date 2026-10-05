//  VELVET  ·  modules/osd/VibeFlash.qml
//  The beat between two vibes: when the shell changes its whole character,
//  the screen is wiped in the new one's own way — pixel bars for the arcade,
//  a scan line for the HUD, a fine comb for the terminal, two pages closing
//  for the paper and the book, a
//  veil for the rest (glass, clean, the Windows editions) — and it names itself in a small plate. Under a second;
//  it takes no clicks.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property real t: 0
    property bool running: false
    property string name: ""
    property string vibe: ""
    property string mood: "persona"

    readonly property string mode: ({
            arcade: "bars",
            brutal: "bars",
            terminal: "bars",
            cyber: "scan",
            paper: "curtain",
            rpg: "curtain",
            glass: "fade"
        })[root.vibe] ?? "fade"
    readonly property int count: ({ arcade: 10, brutal: 5, terminal: 40 })[root.vibe] ?? 8

    // 0 → 1 → 0 with a hold in the middle
    function env(x: real): real {
        if (x < 0.42)
            return Math.pow(x / 0.42, 2);
        if (x < 0.58)
            return 1;
        return Math.pow(Math.max(0, 1 - (x - 0.58) / 0.42), 2);
    }

    screen: Hypr.focusedScreen
    visible: root.running
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-vibe"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: nothing
    }

    Item {
        id: nothing

        width: 0
        height: 0
    }

    // Started by shell.qml whenever the vibe changes: the window is loaded
    // for the occasion (Parked), so it begins the moment it exists — and when
    // it is still around from the last change, shell.qml calls start() again.
    function start(): void {
        const id = Config.appearance.vibe;
        const look = id === "windows" ? Presets.winCurrent : Presets.find(id !== "" ? id : Presets.applied);
        if (!look)
            return;
        root.vibe = id;
        root.name = Presets.nameOf(look);
        root.mood = look.mood ?? Appearance.mood;
        root.t = 0;
        root.running = true;
        run.restart();
    }

    Timer {
        running: true
        interval: 1
        onTriggered: root.start()
    }

    NumberAnimation {
        id: run

        target: root
        property: "t"
        from: 0
        to: 1
        duration: 1000
        onFinished: root.running = false
    }

    // ── bars: strips that grow down the screen, hold, then leave downwards
    Repeater {
        model: root.mode === "bars" ? root.count : 0

        Rectangle {
            required property int index

            readonly property real stagger: index / Math.max(1, root.count) * 0.34
            readonly property real grow: Math.max(0, Math.min(1, (root.t - stagger) / 0.26))
            readonly property real shrink: Math.max(0, Math.min(1, (root.t - 0.62 - stagger) / 0.26))

            x: Math.floor(index * root.width / root.count)
            width: Math.ceil(root.width / root.count) + 1
            y: root.height * shrink
            height: root.height * grow - root.height * shrink
            color: root.vibe === "brutal" ? (index % 2 === 0 ? Colours.alpha(Colours.edge, 0.7) : Colours.alpha(Colours.accent, 0.7)) : (root.vibe === "arcade" ? (index % 2 === 0 ? Colours.alpha(Colours.accent, 0.6) : Colours.alpha(Colours.surface, 0.8)) : Colours.alpha(Colours.accent, 0.5))
        }
    }

    // ── curtain: two halves meet in the middle and part again
    Repeater {
        model: root.mode === "curtain" ? 2 : 0

        Rectangle {
            required property int index

            readonly property real e: root.env(root.t)

            x: index === 0 ? 0 : root.width - width
            width: root.width / 2 * e + 1
            height: root.height
            color: Colours.alpha(index === 0 ? Colours.surface : Colours.paper, 0.9)

            Rectangle {
                anchors.right: index === 0 ? parent.right : undefined
                anchors.left: index === 1 ? parent.left : undefined
                width: 2
                height: parent.height
                color: Colours.accent
            }
        }
    }

    // ── scan: a bright line travels down the screen, tinting what it passes
    Item {
        visible: root.mode === "scan"
        anchors.fill: parent

        Rectangle {
            width: root.width
            height: root.height * root.t
            color: Colours.alpha(Colours.accent, 0.08 * (1 - root.t))
        }
        Rectangle {
            y: root.height * root.t - 140
            width: root.width
            height: 140
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: Colours.alpha(Colours.accent, 0.28)
                }
            }
        }
        Rectangle {
            y: root.height * root.t
            width: root.width
            height: 2
            color: Colours.accent
        }
    }

    // ── fade: the screen frosts over and clears
    Rectangle {
        visible: root.mode === "fade"
        anchors.fill: parent
        color: Colours.alpha(root.vibe === "glass" || root.vibe === "clean" || root.vibe === "windows" ? Colours.paper : Colours.accent, 0.5 * root.env(root.t))
    }

    // ── the name, on a plate of its own so it reads over any wipe
    Item {
        anchors.centerIn: parent
        width: label.implicitWidth + 56
        height: label.implicitHeight + 26
        opacity: Math.max(0, Math.min(1, (root.t - 0.28) / 0.12)) * Math.max(0, Math.min(1, (0.78 - root.t) / 0.14))
        scale: 0.9 + 0.1 * Math.min(1, root.t / 0.5)

        Slash {
            anchors.fill: parent
            shear: 0
            color: Colours.surfaceHigh
            borderColor: Colours.alpha(Colours.edge, 0.8)
            borderWidth: 1
        }

        Text {
            id: label

            anchors.centerIn: parent
            text: root.name
            color: Colours.light ? Colours.ink : Colours.accent
            font.family: Appearance.familyOf(root.mood, true)
            font.pixelSize: 40
            font.weight: Font.DemiBold
            font.letterSpacing: root.mood === "tech" ? 8 : 2
            font.capitalization: root.vibe === "terminal" ? Font.AllLowercase : Font.MixedCase
        }
    }
}
