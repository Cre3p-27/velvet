//  VELVET  ·  modules/settings/CavaPreview.qml
//  CAVA drawn by the shell — on the wallpaper (where the desk's CAVA modules
//  live since v8.38: part of the picture, on every desktop, never zoomed or
//  tiled) and in the designer. Live. The same switches the module
//  runs with (STYLE, DIRECTION, COLOUR, BAR WIDTH, GAP, HEIGHT, CHANNELS,
//  ORDER), drawn by the shell from the music that is playing right now;
//  with nothing playing a calm demo swell stands in, so every pick can be
//  seen at once. It is a picture of the look, not a second cava: the real
//  one draws in terminal cells, this one in pixels.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    // The entry's own switches (opts.o) — "" means the default everywhere.
    property var o: ({})
    // About how many terminal columns the real window has — bar width and
    // gap are counted in cells.
    property real columns: 180
    property bool running: true
    // a calm swell while nothing plays (the designer); the wallpaper stays still
    property bool demo: true

    readonly property string style: ["wave", "line"].indexOf(String(root.o.style ?? "")) >= 0 ? String(root.o.style) : "bars"
    readonly property string orient: String(root.o.orient ?? "")
    readonly property real cell: Math.max(1, root.along / Math.max(8, root.columns))
    readonly property bool side: root.orient === "left" || root.orient === "right"
    readonly property real along: root.side ? root.height : root.width
    readonly property int bar: Math.max(1, parseInt(root.o.bar ?? "") || 2)
    readonly property int gap: (root.o.gap ?? "") === "" ? 1 : Math.max(0, parseInt(root.o.gap) || 0)
    readonly property real reachShare: ((root.o.height ?? "") === "" ? 100 : (parseInt(root.o.height) || 100)) / 100

    // The palette the module paints with.
    readonly property color base: {
        switch (String(root.o.colour ?? "")) {
        case "accent":
            return Qt.darker(Colours.accent, 1.6);
        case "alt":
            return Qt.darker(Colours.accentAlt, 1.6);
        case "ink":
            return Colours.inkDim;
        case "plain":
            return Colours.alpha(Colours.ink, 0.7);
        default:
            return Qt.darker(Colours.accent, 1.5);
        }
    }
    readonly property color crest: {
        switch (String(root.o.colour ?? "")) {
        case "accent":
            return Qt.tint(Colours.accent, Qt.rgba(1, 1, 1, 0.25));
        case "alt":
            return Qt.tint(Colours.accentAlt, Qt.rgba(1, 1, 1, 0.25));
        case "ink":
            return Colours.ink;
        case "plain":
            return Colours.alpha(Colours.ink, 0.7);
        default:
            return Colours.accentAlt;
        }
    }

    clip: true

    component Half: SpectrumEdge {
        running: root.running
        style: root.style
        mono: String(root.o.channels ?? "") === "mono"
        reversed: String(root.o.reverse ?? "") === "on"
        demo: root.demo
        strength: 1
        colour: root.base
        tip: root.crest
        barPitch: (root.bar + root.gap) * root.cell
        barFill: root.bar / (root.bar + root.gap)
        roundBars: false
    }

    // One edge: up / down / left / right.
    Half {
        anchors.fill: parent
        visible: root.orient !== "centre"
        edge: ({
                "": "bottom",
                up: "bottom",
                down: "top",
                left: "left",
                right: "right"
            })[root.orient] ?? "bottom"
        reach: (root.side ? root.width : root.height) * root.reachShare
    }

    // FROM THE MIDDLE: two halves back to back on the centre line.
    Item {
        anchors.fill: parent
        visible: root.orient === "centre"

        Half {
            x: 0
            y: 0
            width: parent.width
            height: parent.height / 2
            edge: "bottom"
            reach: height * root.reachShare
        }

        Half {
            x: 0
            y: parent.height / 2
            width: parent.width
            height: parent.height / 2
            edge: "top"
            reach: height * root.reachShare
        }
    }
}
