//  VELVET  ·  modules/lock/modules/LockWeather.qml
//  The weather — the fluid lock's card, radius 48 and all: the description
//  speaks first (16px), the temperature shouts beside a big plain icon,
//  the feels and the day's high/low follow, and the hourly forecast strip
//  fills the card's width along the bottom — as many slots as fit, the
//  first one in a filled pill. In a pill it shrinks to the glyph and the
//  temperature.
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import QtQuick

Item {
    id: root

    property bool compact: false
    property bool carded: true

    // The card is as tall as what it holds — measured, never guessed, so
    // the forecast strip can never slide under the lines above it.
    implicitHeight: root.compact ? 28 : Math.ceil(stack.implicitHeight + 40)
    implicitWidth: root.compact ? compactRow.width : 340

    readonly property bool has: Weather.ready
    readonly property bool showForecast: Config.lock.weatherForecast && root.has && Weather.hourlyForecast.length > 0
    readonly property string tempText: root.has ? Weather.short : "--°"
    readonly property string condText: root.has ? (Weather.description ? Weather.description : "") : "No data"

    ModuleCard {
        anchors.fill: parent
        glyphKind: 3
        radius: 48
        carded: root.carded
        visible: !root.compact
    }

    // ── the island rendering: burst glyph and temperature
    Row {
        id: compactRow

        anchors.verticalCenter: parent.verticalCenter
        visible: root.compact
        spacing: 7

        ShapeBadge {
            size: 28
            kind: 3
            hoverKind: -1
            col: Colours.alpha(root.has ? Colours.accent : Colours.inkDim, 0.16)
            icon: Weather.icon
            iconCol: root.has ? Colours.accent : Colours.alpha(Colours.inkDim, 0.55)
            iconSize: 15
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: root.tempText
            color: root.has ? Colours.ink : Colours.alpha(Colours.inkDim, 0.55)
            font.pixelSize: Appearance.font.size.normal
        }
    }

    // ── the card: the fluid lock's brief info, its sizes — and its hourly
    // strip underneath, in the same column so nothing can overlap.
    Column {
        id: stack

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        anchors.topMargin: 20
        spacing: 10
        visible: !root.compact

        P5Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.condText
            color: Colours.alpha(Colours.inkDim, 0.95)
            font.pixelSize: 16
            elide: Text.ElideRight
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: root.tempText
                color: root.has ? Colours.accent : Colours.alpha(Colours.inkDim, 0.55)
                font.pixelSize: 48
                font.weight: Font.DemiBold
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Weather.icon
                color: root.has ? Colours.accentAlt : Colours.alpha(Colours.inkDim, 0.55)
                font.pixelSize: 44
            }
        }

        P5Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.has
            text: `Feels like ${Math.round(Weather.feelsLike)}°  ·  Humidity ${Weather.humidity}%`
            color: Colours.alpha(Colours.inkDim, 0.9)
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        P5Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.has && Config.lock.weatherHighLow && Weather.hasHighLow
            text: `High ${Math.round(Weather.maxTempC)}°  ·  Low ${Math.round(Weather.minTempC)}°`
            color: Colours.alpha(Colours.inkDim, 0.9)
            font.pixelSize: 13
        }

        P5Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
            text: Weather.place ? Weather.place : ""
            color: Colours.alpha(Colours.inkDim, 0.7)
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        // A breath between the reading and the strip.
        Item {
            width: 1
            height: 4
            visible: forecast.visible
        }

        // ── The fluid lock's hourly strip: as many slots as fit the card,
        // starting NOW — the first one rides a filled pill.
        Row {
            id: forecast

            readonly property int slots: Math.max(0, Math.min(Weather.hourlyForecast.length, Math.floor((width + spacing) / (44 + spacing))))

            width: parent.width
            visible: root.showForecast && forecast.slots > 0
            spacing: 6
            // Centre the slots that fit, instead of hugging the left edge.
            leftPadding: Math.max(0, (width - forecast.slots * 44 - Math.max(0, forecast.slots - 1) * spacing) / 2)

            Repeater {
                model: forecast.slots

                Column {
                    id: slot

                    required property int index

                    readonly property var hour: Weather.hourlyForecast[slot.index] ?? ({})
                    readonly property bool first: slot.index === 0
                    readonly property int h: Math.floor((slot.hour.time ?? 0) / 100) % 24

                    width: 44
                    spacing: 3

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 38
                        height: 24
                        radius: 12
                        color: slot.first ? Colours.alpha(Colours.accent, 0.95) : Colours.alpha(Colours.ink, 0.06)
                        antialiasing: true

                        P5Text {
                            anchors.centerIn: parent
                            display: true
                            font.italic: false
                            text: `${Math.round(slot.hour.tempC ?? 0)}°`
                            color: slot.first ? Colours.on(Colours.accent) : Colours.ink
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                    }

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: Weather.iconFor(slot.hour.code ?? 0)
                        color: Colours.accentAlt
                        font.pixelSize: 17
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: (slot.hour.precip ?? 0) > 0 ? `${slot.hour.precip}%` : " "
                        color: Colours.accent
                        font.pixelSize: 11
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: slot.first ? "Now" : (Config.bar.clock.format24h ? `${slot.h}:00` : `${slot.h % 12 === 0 ? 12 : slot.h % 12}${slot.h < 12 ? "am" : "pm"}`)
                        color: slot.first ? Colours.ink : Colours.alpha(Colours.inkDim, 0.9)
                        font.pixelSize: 12
                        font.weight: slot.first ? Font.Bold : Font.DemiBold
                    }
                }
            }
        }
    }
}
