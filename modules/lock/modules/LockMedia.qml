//  VELVET  ·  modules/lock/modules/LockMedia.qml
//  What is playing — the cover artwork fills the card behind a surface
//  veil, the cover itself sits on the left in the card's rounded shape,
//  and beside it the title speaks in the accent, the artist whispers
//  below, a thin line with the times says where the track is, and a row
//  of quiet round buttons (previous, play, next — the middle one bigger,
//  The fluid lock's ButtonRow) sits underneath.
//  The buttons keep their shape: colour and a small lift answer the
//  hover instead — glyph morphing on 40px buttons reads as noise.
//  Nothing playing? The card still speaks — "Nothing playing", dimmed.
//  The compact chip for the pills keeps the art, the ring and the title.
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import Qt5Compat.GraphicalEffects as GE

Item {
    id: root

    property bool compact: false
    property bool carded: true

    readonly property var player: {
        // One choice for the whole shell (services/MprisBridge.qml): it
        // remembers the last player that played, so a pause never hands
        // the controls to a browser tab. The scan below is the fallback.
        if (Lyrics.bridge)
            return Lyrics.bridge.player;
        const list = Mpris.players?.values ?? [];
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        return list.length > 0 ? list[0] : null;
    }

    readonly property string title: root.player?.trackTitle ?? ""
    readonly property string artist: root.player?.trackArtist ?? ""
    readonly property string artUrl: root.player?.trackArtUrl ?? ""
    readonly property bool has: root.player !== null && root.title.length > 0

    // Where the track is, polled while it plays (MPRIS does not push it).
    property real pos: 0
    readonly property real len: root.player?.length ?? 0

    function clock(sec: real): string {
        const t = Math.max(0, Math.floor(sec || 0));
        const m = Math.floor(t / 60);
        const h = Math.floor(m / 60);
        const ss = String(t % 60).padStart(2, "0");
        return h > 0 ? `${h}:${String(m % 60).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }

    implicitHeight: root.compact ? 30 : 152
    implicitWidth: root.compact ? compactRow.width : 340
    opacity: root.compact && !root.has ? 0.55 : 1

    // MPRIS position only moves when asked — poll it while the player is
    // actually playing so the chip ring sweeps instead of sitting.
    Timer {
        interval: 1000
        repeat: true
        running: root.has && root.player.isPlaying
        triggeredOnStart: true
        onTriggered: {
            root.player?.positionChanged();
            root.pos = root.player?.position ?? 0;
        }
    }

    // Paused tracks have a position too — read it when the card or the
    // player arrives, not only while something plays.
    Component.onCompleted: root.pos = root.player?.position ?? 0
    onPlayerChanged: root.pos = root.player?.position ?? 0

    // A new track, a seek or a pause shows at once, not a second later.
    Connections {
        target: root.player
        ignoreUnknownSignals: true

        function onTrackTitleChanged(): void {
            root.pos = root.player?.position ?? 0;
        }

        function onIsPlayingChanged(): void {
            root.pos = root.player?.position ?? 0;
        }
    }

    // ── the compact chip (islands)
    Row {
        id: compactRow

        anchors.verticalCenter: parent.verticalCenter
        visible: root.compact
        spacing: 8

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 34

            CircularProgress {
                anchors.fill: parent
                value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                thickness: 2
                color: Colours.accent
                trackColor: Colours.alpha(Colours.ink, 0.12)
                text: ""
                visible: root.has
            }

            Rectangle {
                anchors.centerIn: parent
                width: 28
                height: 28
                radius: 14
                color: root.has ? Colours.alpha(Colours.accent, 0.85) : Colours.alpha(Colours.inkDim, 0.3)
                clip: true
                antialiasing: true

                Image {
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: root.artUrl !== ""
                }

                Icon {
                    anchors.centerIn: parent
                    name: "music_note"
                    color: root.has ? Colours.on(Colours.accent) : Colours.alpha(Colours.inkDim, 0.6)
                    font.pixelSize: 15
                    visible: root.artUrl === ""
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -1
            width: 130

            P5Text {
                width: parent.width
                text: root.title || "NOTHING PLAYING"
                color: root.has ? Colours.ink : Colours.alpha(Colours.inkDim, 0.6)
                font.pixelSize: Appearance.font.size.tiny + 1
                elide: Text.ElideRight
            }

            P5Text {
                width: parent.width
                text: root.has ? root.artist.toUpperCase() : "—"
                color: root.has ? Colours.accentInk : Colours.alpha(Colours.inkDim, 0.5)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
                elide: Text.ElideRight
            }
        }
    }

    // ── the full card (card columns)
    ModuleCard {
        anchors.fill: parent
        glyphKind: 2
        radius: 28
        carded: root.carded
        // The fluid lock's full-bleed cover behind the card — toggleable.
        image: root.carded && Config.lock.mediaArtwork && root.has ? root.artUrl : ""
        // Softened and veiled deeper than the default: the title and the
        // times sit on it, and a bright cover must not drown them.
        imageDim: 0.72
        imageBlur: 0.85
        visible: !root.compact
    }

    // The card: the cover on the left, and beside it the title, the
    // artist, where the track is, and the buttons — the whole story at a
    // glance, over the cover's own blurred colours.
    Row {
        id: cardRow

        anchors.fill: parent
        anchors.margins: 18
        spacing: 18
        visible: !root.compact

        // ── the cover, in the card's own rounded shape
        Item {
            id: cover

            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(cardRow.height, 116)
            height: cover.width

            Rectangle {
                anchors.fill: parent
                radius: 20
                color: root.has ? Colours.alpha(Colours.accent, 0.22) : Colours.alpha(Colours.ink, 0.06)
                antialiasing: true

                Icon {
                    anchors.centerIn: parent
                    name: "music_note"
                    color: root.has ? Colours.accent : Colours.alpha(Colours.inkDim, 0.6)
                    font.pixelSize: cover.width * 0.4
                    visible: art.status !== Image.Ready
                }
            }

            Image {
                id: art

                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                visible: root.artUrl !== "" && art.status === Image.Ready
                layer.enabled: true
                layer.effect: GE.OpacityMask {
                    maskSource: Rectangle {
                        width: art.width
                        height: art.height
                        radius: 20
                    }
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: cardRow.width - cover.width - cardRow.spacing
            spacing: 6

            P5Text {
                width: parent.width
                text: root.title || "Nothing playing"
                color: root.has ? Colours.accent : Colours.alpha(Colours.inkDim, 0.75)
                font.pixelSize: 17
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            P5Text {
                width: parent.width
                // A browser tab has no artist — name the player instead.
                text: root.has ? (root.artist || root.player?.identity || "Unknown artist") : "Play something — it shows up here"
                color: Colours.alpha(Colours.inkDim, 0.9)
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            // Where the track is.
            Item {
                width: parent.width
                height: 22
                visible: root.has && root.len > 0

                Rectangle {
                    id: track

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    height: 4
                    radius: 2
                    color: Colours.alpha(Colours.ink, 0.14)

                    Rectangle {
                        width: track.width * Math.max(0, Math.min(1, root.len > 0 ? root.pos / root.len : 0))
                        height: parent.height
                        radius: 2
                        color: Colours.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: 900
                                easing.type: Easing.Linear
                            }
                        }
                    }
                }

                P5Text {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    text: root.clock(root.pos)
                    color: Colours.alpha(Colours.inkDim, 0.85)
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: 11
                }

                P5Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    text: root.clock(root.len)
                    color: Colours.alpha(Colours.inkDim, 0.85)
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: 11
                }
            }

            Row {
                spacing: 8
                visible: root.has

                ShapeBadge {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 38
                    kind: 1
                    hoverKind: -1
                    opacity: (root.player?.canGoPrevious ?? false) ? 1 : 0.35
                    col: Colours.alpha(Colours.ink, 0.08)
                    hoverCol: Colours.accent
                    icon: "skip_previous"
                    iconCol: Colours.inkDim
                    hoverIconCol: Colours.on(Colours.accent)
                    iconSize: 18
                    onPressed: Sfx.cursor()
                    onClicked: {
                        if (root.player?.canGoPrevious)
                            root.player.previous();
                    }
                }

                ShapeBadge {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 46
                    kind: 0
                    hoverKind: -1
                    col: Colours.accent
                    icon: root.player?.isPlaying ? "pause" : "play_arrow"
                    iconCol: Colours.on(Colours.accent)
                    iconSize: 22
                    onPressed: Sfx.cursor()
                    onClicked: {
                        // Quickshell's MPRIS API has no playPause() — the call
                        // below is togglePlaying().
                        Sfx.select();
                        root.player?.togglePlaying();
                    }
                }

                ShapeBadge {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 38
                    kind: 4
                    hoverKind: -1
                    opacity: (root.player?.canGoNext ?? false) ? 1 : 0.35
                    col: Colours.alpha(Colours.ink, 0.08)
                    hoverCol: Colours.accent
                    icon: "skip_next"
                    iconCol: Colours.inkDim
                    hoverIconCol: Colours.on(Colours.accent)
                    iconSize: 18
                    onPressed: Sfx.cursor()
                    onClicked: {
                        if (root.player?.canGoNext)
                            root.player.next();
                    }
                }
            }
        }
    }
}
