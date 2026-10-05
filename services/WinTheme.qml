//  VELVET  ·  services/WinTheme.qml
//  The palette of the WINDOWS look. Five editions of one window system, each
//  with its own colours: the grey of 95, the cream and Luna blue of XP, the
//  Aero blue of 7, the flat greys of 10 and the mica of 11 (those two follow
//  the ground, dark or light; the older three are what they were).
pragma Singleton

import qs.config
import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property string v: Appearance.winVer
    readonly property bool old: root.v === "95" || root.v === "xp"
    readonly property bool dark: (root.v === "10" || root.v === "11") && !Colours.light

    function pick(a95: var, axp: var, a7: var, a10: var, a11: var): var {
        switch (root.v) {
        case "95":
            return a95;
        case "xp":
            return axp;
        case "7":
            return a7;
        case "10":
            return a10;
        default:
            return a11;
        }
    }

    // ── surfaces
    // the window's face: a dialog, a panel, the strip around the pages
    readonly property color face: root.pick("#c0c0c0", "#ece9d8", "#f0f0f0", root.dark ? "#1f1f1f" : "#ffffff", root.dark ? "#202020" : "#f3f3f3")
    // the page the settings list sits on
    readonly property color page: root.pick("#c0c0c0", "#ffffff", "#ffffff", root.dark ? "#1f1f1f" : "#ffffff", root.dark ? "#202020" : "#f3f3f3")
    // the left navigation
    readonly property color nav: root.pick("#ffffff", "#d6dff7", "#f4f8fd", root.dark ? "#262626" : "#f2f2f2", root.dark ? "#202020" : "#f3f3f3")
    // an input, a list box
    readonly property color field: root.pick("#ffffff", "#ffffff", "#ffffff", root.dark ? "#333333" : "#ffffff", root.dark ? "#2d2d2d" : "#fefefe")
    // a card on the page (11), a raised tile (10)
    readonly property color card: root.pick("#c0c0c0", "#ffffff", "#ffffff", root.dark ? "#2b2b2b" : "#f2f2f2", root.dark ? "#2b2b2b" : "#fbfbfb")

    // ── ink
    readonly property color text: root.dark ? "#ffffff" : root.pick("#000000", "#000000", "#000000", "#000000", "#1b1b1b")
    readonly property color dim: root.dark ? (root.v === "11" ? "#c5c5c5" : "#a0a0a0") : root.pick("#4a4a4a", "#5e5b50", "#5a5a5a", "#5f5f5f", "#5f5f5f")
    readonly property color line: root.pick("#808080", "#aca899", "#a8a8a8", root.dark ? "#4c4c4c" : "#cccccc", root.dark ? "#3a3a3a" : "#e5e5e5")
    readonly property color rule: root.pick("#808080", "#d0cdbd", "#d9d9d9", root.dark ? "#3c3c3c" : "#e6e6e6", root.dark ? "#323232" : "#ebebeb")

    // ── the chosen colour
    readonly property color accent: root.pick("#000080", "#316ac5", "#3399ff", Colours.accent, Colours.accent)
    readonly property color selText: root.pick("#ffffff", "#ffffff", "#ffffff", Colours.on(Colours.accent), Colours.on(Colours.accent))
    // a hovered row
    readonly property color hover: root.pick(Qt.rgba(0, 0, 0, 0.0), "#e4ecfb", "#e8f3fc", root.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05), root.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04))

    // ── the title bar
    readonly property color titleA: root.pick("#000080", "#0a5de6", "#8fb6e0", root.dark ? "#2b2b2b" : "#ffffff", root.dark ? "#202020" : "#f3f3f3")
    readonly property color titleB: root.pick("#1084d0", "#2f86ff", "#5f93cc", root.dark ? "#2b2b2b" : "#ffffff", root.dark ? "#202020" : "#f3f3f3")
    readonly property color titleText: root.pick("#ffffff", "#ffffff", "#000000", root.dark ? "#ffffff" : "#000000", root.dark ? "#ffffff" : "#1b1b1b")

    // ── the old window system's blues and greens, for XP's task pane / start
    readonly property color paneA: "#7ba2e7"
    readonly property color paneB: "#6375d6"
    readonly property color green: "#3c9a2f"
}
