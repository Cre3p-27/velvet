//  VELVET  ·  modules/bar/BarDeco.qml
//  What each settings skin adds to the bar's plate, along the edge that faces
//  the desktop: a terminal's rule, an arcade's row of lights, a HUD's scale,
//  a newspaper's double rule, a tome's gilt line, a poster's plain rule, a
//  quiet hairline for CLEAN, and for WINDOWS the taskbar of the edition.
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    property bool vertical: false

    readonly property string pos: Config.bar.position
    readonly property string inner: root.pos === "top" ? "bottom" : (root.pos === "bottom" ? "top" : (root.pos === "left" ? "right" : "left"))
    readonly property real along: root.vertical ? root.height : root.width

    // a strip `t` thick along the inner edge
    function stripX(t: real): real {
        return root.inner === "right" ? root.width - t : 0;
    }
    function stripY(t: real): real {
        return root.inner === "bottom" ? root.height - t : 0;
    }
    function stripW(t: real): real {
        return root.vertical ? t : root.width;
    }
    function stripH(t: real): real {
        return root.vertical ? root.height : t;
    }

    Loader {
        anchors.fill: parent
        sourceComponent: ({
                console: consoleC,
                arcade: arcadeC,
                hud: hudC,
                ledger: ledgerC,
                tome: tomeC,
                poster: posterC,
                clean: cleanC,
                win: winC
            })[Appearance.skin] ?? null
    }

    // A single line along the edge that faces the desktop — the whole of
    // what the older skins add to the bar now: quiet, and still different.
    component EdgeLine: Item {
        property real thickness: 1
        property color colour: "white"

        Rectangle {
            x: root.stripX(parent.thickness)
            y: root.stripY(parent.thickness)
            width: root.stripW(parent.thickness)
            height: root.stripH(parent.thickness)
            color: parent.colour
        }
    }

    Component {
        id: consoleC

        EdgeLine {
            colour: Colours.alpha(Colours.accent, 0.35)
        }
    }

    Component {
        id: arcadeC

        EdgeLine {
            thickness: 2
            colour: Colours.alpha(Colours.accent, 0.6)
        }
    }

    Component {
        id: hudC

        EdgeLine {
            colour: Colours.alpha(Colours.accent, 0.45)
        }
    }

    Component {
        id: ledgerC

        EdgeLine {
            colour: Colours.alpha(Colours.ink, 0.6)
        }
    }

    Component {
        id: tomeC

        EdgeLine {
            colour: Colours.alpha(Colours.accent, 0.5)
        }
    }

    Component {
        id: posterC

        Item {
            Rectangle {
                x: root.stripX(2)
                y: root.stripY(2)
                width: root.stripW(2)
                height: root.stripH(2)
                color: Colours.edge
            }
        }
    }

    Component {
        id: cleanC

        Item {
            Rectangle {
                x: root.stripX(1)
                y: root.stripY(1)
                width: root.stripW(1)
                height: root.stripH(1)
                color: Colours.alpha(Colours.ink, 0.1)
            }
        }
    }

    // The taskbar of the chosen Windows edition.
    Component {
        id: winC

        Item {
            // XP: the Luna blue, all the way across
            Rectangle {
                anchors.fill: parent
                visible: Appearance.winVer === "xp"

                gradient: Gradient {
                    orientation: root.vertical ? Gradient.Horizontal : Gradient.Vertical

                    GradientStop {
                        position: root.inner === "top" || root.inner === "left" ? 1 : 0
                        color: "#4a8af0"
                    }
                    GradientStop {
                        position: root.inner === "top" || root.inner === "left" ? 0.9 : 0.1
                        color: "#2b66e0"
                    }
                    GradientStop {
                        position: root.inner === "top" || root.inner === "left" ? 0.15 : 0.85
                        color: "#245edb"
                    }
                    GradientStop {
                        position: root.inner === "top" || root.inner === "left" ? 0 : 1
                        color: "#1f4fc2"
                    }
                }
            }
            // 7: a sheen over the dark glass
            Rectangle {
                anchors.fill: parent
                visible: Appearance.winVer === "7"

                gradient: Gradient {
                    orientation: root.vertical ? Gradient.Horizontal : Gradient.Vertical

                    GradientStop {
                        position: 0
                        color: Qt.rgba(1, 1, 1, root.inner === "top" || root.inner === "left" ? 0.0 : 0.2)
                    }
                    GradientStop {
                        position: 0.5
                        color: Qt.rgba(1, 1, 1, 0.04)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(1, 1, 1, root.inner === "top" || root.inner === "left" ? 0.2 : 0.0)
                    }
                }
            }
            // the line along the edge that faces the desktop
            Rectangle {
                x: root.stripX(1)
                y: root.stripY(1)
                width: root.stripW(1)
                height: root.stripH(1)
                visible: Appearance.winVer !== "95"
                color: Appearance.winVer === "xp" ? "#5a8ff0" : (Appearance.winVer === "7" ? Qt.rgba(1, 1, 1, 0.4) : Colours.alpha(Colours.ink, 0.12))
            }
        }
    }
}
