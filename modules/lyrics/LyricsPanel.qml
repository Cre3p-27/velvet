//  VELVET  ·  modules/lyrics/LyricsPanel.qml
//  One word at a time, the size of a headline, on a tile of its own.
//
//  It sits on the background layer with an empty input region, so it is
//  scenery: it never takes a click, never takes focus, and windows draw over
//  it. Which is the point — it should feel painted onto the desktop rather
//  than stuck on top of it.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    readonly property bool active: Config.lyrics.enabled && Config.lyrics.desktop
    readonly property string line: Lyrics.display
    readonly property bool hasLine: root.line !== ""
    readonly property real unit: Config.lyrics.size
    readonly property bool word: Config.lyrics.mode === "word"
    // STACK: the card of the Material shells — the line before, the line
    // now, the line next, over the blurred cover, in a corner.
    readonly property bool stack: Config.lyrics.mode === "stack"

    screen: Hypr.focusedScreen
    visible: root.active
    color: "transparent"

    WlrLayershell.namespace: "velvet-lyrics"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: -1

    anchors {
        left: true
        right: true
        top: Config.lyrics.position !== "bottom"
        bottom: Config.lyrics.position !== "top"
    }

    implicitHeight: Config.lyrics.position === "centre" ? 0 : Math.round(320 * root.unit)

    // Scenery. Never eats a click.
    mask: Region {}

    // ═══════════════════════════════════════════════════════════════ the tile
    Item {
        id: tile

        visible: !root.stack
        width: Config.lyrics.tile ? Math.round(root.width * Math.max(0.2, Math.min(1, Config.lyrics.width))) : root.width - 128
        height: Math.round(240 * root.unit)

        // MODULES → LYRICS → SIDE
        x: Math.round(Appearance.sideX(Config.lyrics.side, parent.width, tile.width, Math.round(32 * root.unit)))
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: Config.lyrics.position === "bottom" ? -20 : (Config.lyrics.position === "top" ? 20 : 0)

        // The plate. In the inspo the type sits on a panel with a lit top edge
        // and a hairline border — that frame is what makes a single word read
        // as a deliberate display rather than as a stray caption.
        Rectangle {
            anchors.fill: parent
            visible: Config.lyrics.tile
            radius: Appearance.rounding.large
            antialiasing: true

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Colours.alpha(Colours.surfaceHigh, 0.9)
                }
                GradientStop {
                    position: 1
                    color: Colours.alpha(Colours.paper, 0.92)
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Colours.alpha(Colours.accent, 0.45)
                antialiasing: true
            }
        }

        // ── the word
        Item {
            id: stage

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            anchors.top: parent.top
            anchors.topMargin: 18
            anchors.bottom: footer.top
            anchors.bottomMargin: 8

            // Every new word lands rather than fades in. Scale with a soft
            // overshoot reads as someone saying it; a plain opacity fade reads
            // as a subtitle track.
            transform: Scale {
                id: pop

                origin.x: stage.width / 2
                origin.y: stage.height / 2
                xScale: 1
                yScale: 1
            }

            SequentialAnimation {
                id: land

                ParallelAnimation {
                    NumberAnimation {
                        target: pop
                        properties: "xScale,yScale"
                        from: root.word ? 0.74 : 0.9
                        to: 1
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.1
                    }
                    NumberAnimation {
                        target: type
                        property: "opacity"
                        from: 0.2
                        to: 1
                        duration: Appearance.anim.fast
                    }
                }
            }

            // The extrusion: the same word, offset and dark, behind the real
            // one. Two Texts rather than a shader, so it costs nothing and
            // cannot fail to build.
            P5Text {
                // Sized like the type, not anchored to it: anchors would
                // override x/y and the extrusion sat exactly behind the word.
                width: type.width
                height: type.height
                minimumPixelSize: type.minimumPixelSize
                fontSizeMode: type.fontSizeMode
                visible: Config.lyrics.shadow
                display: true
                text: type.text
                color: Colours.alpha(Colours.paper, 0.85)
                font: type.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                tracking: type.tracking
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                x: type.x + Math.max(2, Math.round(5 * root.unit))
                y: type.y + Math.max(2, Math.round(5 * root.unit))
                opacity: type.opacity
            }

            P5Text {
                id: type

                anchors.fill: parent
                display: true
                text: root.line.toUpperCase()
                color: Colours.ink
                font.family: Config.lyrics.blocky ? Appearance.fontFamily.mono : Appearance.fontFamily.display
                font.weight: Font.Black
                // P5Text slants its display face by default. A single word
                // held on screen wants to stand up straight.
                font.italic: false
                // One word can be enormous; a whole line has to come down to
                // fit. `fontSizeMode` does the rest, so a long word shrinks
                // instead of running off the tile.
                font.pixelSize: Math.round((root.word ? 128 : 76) * root.unit)
                minimumPixelSize: 18
                fontSizeMode: Text.Fit
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                tracking: Config.lyrics.blocky ? 8 : 2
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }

            // In line mode the words fill in as they are sung; in word mode
            // there is nothing to fill, so this stays out of the way.
            Item {
                anchors.fill: type
                visible: !root.word && Lyrics.hasSynced
                clip: true

                Item {
                    // The line is centred: start the fill where the text starts.
                    width: (parent.width - type.contentWidth) / 2 + type.contentWidth * Lyrics.lineProgress
                    height: parent.height
                    clip: true

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    P5Text {
                        width: type.width
                        height: type.height
                        display: true
                        text: type.text
                        color: Colours.accent
                        font: type.font
                        minimumPixelSize: 18
                        fontSizeMode: Text.Fit
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        tracking: type.tracking
                        wrapMode: Text.NoWrap
                        elide: Text.ElideRight
                    }
                }
            }

            // Nothing to sing: say which of the reasons it is.
            P5Text {
                anchors.centerIn: parent
                visible: !root.hasLine
                text: {
                    switch (Lyrics.status) {
                    case "LOOKING":
                        return "LOOKING FOR LYRICS…";
                    case "PLAIN":
                        return "ONLY UNTIMED LYRICS FOR THIS ONE";
                    case "NONE":
                        return "NO LYRICS FOR THIS TRACK";
                    case "OFFLINE":
                        return "LRCLIB UNREACHABLE";
                    default:
                        return Lyrics.bridgeError !== "" ? "NO MPRIS IN THIS QUICKSHELL BUILD" : (Lyrics.hasPlayer ? "" : "NOTHING PLAYING");
                    }
                }
                color: Colours.alpha(Colours.inkDim, 0.45)
                font.pixelSize: Appearance.font.size.normal
                tracking: 4
            }
        }

        // ── track, and how far through it you are
        Item {
            id: footer

            visible: Config.lyrics.showProgress && Lyrics.title !== ""
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            anchors.bottomMargin: 14
            height: 22

            P5Text {
                id: trackName

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width * 0.4)
                text: `${Lyrics.artist} — ${Lyrics.title}`
                color: Colours.alpha(Colours.inkDim, 0.8)
                font.family: Appearance.fontFamily.mono
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            P5Text {
                id: clockText

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: `${Lyrics.fmt(Lyrics.position)} / ${Lyrics.fmt(Lyrics.duration)}`
                color: Colours.alpha(Colours.inkDim, 0.8)
                font.family: Appearance.fontFamily.mono
                font.pixelSize: Appearance.font.size.small
            }

            Rectangle {
                anchors.left: trackName.right
                anchors.right: clockText.left
                anchors.margins: 24
                anchors.verticalCenter: parent.verticalCenter
                height: 2
                color: Colours.alpha(Colours.ink, 0.16)

                Rectangle {
                    width: parent.width * Lyrics.progress
                    height: parent.height
                    color: Colours.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: 260
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════ STACK
    LyricCard {
        visible: root.stack
        running: root.active && root.stack
        unit: root.unit
        // SIDE left / right puts the card there; MIDDLE keeps the old way
        // (centred in the middle of the screen, on the right otherwise)
        readonly property string at: Config.lyrics.side !== "centre" ? Config.lyrics.side : (Config.lyrics.position === "centre" ? "centre" : "right")
        anchors.right: at === "right" ? parent.right : undefined
        anchors.rightMargin: Math.round(32 * root.unit) + Appearance.barRoom("right")
        anchors.left: at === "left" ? parent.left : undefined
        anchors.leftMargin: Math.round(32 * root.unit) + Appearance.barRoom("left")
        anchors.horizontalCenter: at === "centre" ? parent.horizontalCenter : undefined
        anchors.verticalCenter: parent.verticalCenter
    }

    // A new word restarts the landing animation. Bound to what is actually on
    // screen, so it lands per word in word mode and per line in line mode.
    Connections {
        target: Lyrics

        function onDisplayChanged(): void {
            if (root.active && Lyrics.display !== "")
                land.restart();
        }
    }
}
