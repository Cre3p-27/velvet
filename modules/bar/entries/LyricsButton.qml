//  VELVET  ·  LyricsButton — lyrics on or off, and whether there are any.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    readonly property bool on: Config.lyrics.enabled

    padding: 4
    active: root.on
    tip: root.on ? (Lyrics.current || `LYRICS  ·  ${Lyrics.status}`) : "LYRICS  ·  TIMED, FROM LRCLIB"

    onClicked: {
        Sfx.toggle();
        Config.set("lyrics.enabled", !Config.lyrics.enabled);
    }
    onRightClicked: Panels.openSettingsKey("lyrics.enabled")

    Icon {
        id: glyph

        name: "lyrics"
        font.pixelSize: Config.bar.iconSize
        color: {
            if (!root.on)
                return root.containsMouse ? Colours.accent : Colours.inkDim;
            return Lyrics.hasSynced ? Colours.accent : Colours.warning;
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        // Pulses on every new line, so you can see it is actually following
        // the song rather than just sitting there.
        SequentialAnimation {
            id: beat

            NumberAnimation {
                target: glyph
                property: "scale"
                from: 1
                to: 1.28
                duration: 90
                easing.type: Easing.OutBack
            }
            NumberAnimation {
                target: glyph
                property: "scale"
                to: 1
                duration: 220
                easing.type: Easing.OutCubic
            }
        }

        Connections {
            target: Lyrics
            enabled: root.on

            function onIndexChanged(): void {
                beat.restart();
            }
        }
    }
}
