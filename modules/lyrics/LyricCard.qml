//  VELVET  ·  modules/lyrics/LyricCard.qml
//  LYRICS → MODE → STACK: the lyric card of the Material shells — the
//  line before, the line now, the line next — over the song's own cover,
//  blurred under a veil. A new line slides the three up by one.
import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Effects

Item {
    id: card

    // LYRICS → SIZE.
    property real unit: 1
    // Only a card on screen follows the song.
    property bool running: true

    width: Math.round(Math.max(340, 384) * card.unit)
    height: Math.round(150 * card.unit)

    readonly property string art: Lyrics.bridge?.artUrl ?? ""
    readonly property string family: Config.lyrics.blocky ? Appearance.fontFamily.mono : Appearance.fontFamily.body
    readonly property real pitch: Math.round(34 * card.unit)
    // A new line arrives from one line below and settles.
    property real slideOff: 0

    NumberAnimation {
        id: slide

        target: card
        property: "slideOff"
        from: card.pitch
        to: 0
        duration: 320
        easing.type: Easing.OutCubic
    }

    Connections {
        target: Lyrics
        enabled: card.running

        function onCurrentChanged(): void {
            if (Lyrics.current !== "")
                slide.restart();
        }
    }

    // The cover, blurred, under a veil — the card wears the song.
    Item {
        id: cardArt

        anchors.fill: parent
        visible: false

        Rectangle {
            anchors.fill: parent
            color: Colours.surfaceHigh
        }
        Image {
            anchors.fill: parent
            source: card.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
            sourceSize.height: 256
        }
    }

    Plate {
        id: cardMask

        anchors.fill: parent
        radius: Appearance.rounding.large
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: cardArt
        blurEnabled: true
        blur: 1
        blurMax: 48
        maskEnabled: true
        maskSource: cardMask
    }

    Plate {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Colours.alpha(Colours.paper, 0.62)
        border.width: 1
        border.color: Colours.alpha(Colours.ink, 0.08)
        antialiasing: true
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Math.round(22 * card.unit)
        anchors.rightMargin: Math.round(22 * card.unit)
        clip: true

        Column {
            id: lines

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: card.slideOff

            Repeater {
                model: [Lyrics.previous, Lyrics.current !== "" ? Lyrics.current : (Lyrics.status === "LOOKING" ? "looking for lyrics…" : (Lyrics.hasPlayer ? "♪" : "nothing playing")), Lyrics.upcoming]

                Text {
                    required property string modelData
                    required property int index

                    width: lines.width
                    height: card.pitch
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    elide: Text.ElideRight
                    color: index === 1 ? Colours.ink : Colours.alpha(Colours.ink, 0.42)
                    font.family: card.family
                    font.pixelSize: Math.round((index === 1 ? 19 : 15) * card.unit)
                    font.weight: index === 1 ? Font.DemiBold : Font.Normal
                    antialiasing: true
                }
            }
        }
    }
}
