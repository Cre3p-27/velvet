//  VELVET  ·  modules/island/IslandWeather.qml
//  The WEATHER body of the Dynamic Island — now, hi/lo, humidity, and the
//  next few hours, straight from the Weather service (wttr.in).
//
//  The island is ALWAYS black, whatever the wallpaper: all text rides on
//  ink (the palette's light text) and never on paper (its dark one).
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    anchors.fill: parent

    readonly property bool on: Config.services.weather

    // ──────────────────────────────────────────────────────────── live weather
    Item {
        anchors.fill: parent
        visible: root.on && Weather.ready

        // The number — the hero of the panel.
        P5Text {
            x: 24
            y: 20
            display: true
            text: `${Math.round(Weather.temperature)}°`
            color: Colours.ink
            font.pixelSize: 54
        }

        P5Text {
            x: 26
            y: 98
            width: 200
            text: Weather.description.toUpperCase()
            color: Colours.accentInk
            font.pixelSize: Appearance.font.size.small
            tracking: 1.4
            elide: Text.ElideRight
        }

        P5Text {
            x: 26
            y: 120
            width: 200
            text: Weather.place
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 0.6
            elide: Text.ElideRight
        }

        // Hi / lo / humidity, right-aligned against the number.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 24
            y: 26
            spacing: 12

            Row {
                spacing: 10

                P5Text {
                    width: 88
                    display: true
                    text: "HI"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.2
                }

                P5Text {
                    text: `${Math.round(Weather.maxTempC)}°`
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.small
                }
            }

            Row {
                spacing: 10

                P5Text {
                    width: 88
                    display: true
                    text: "LO"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.2
                }

                P5Text {
                    text: `${Math.round(Weather.minTempC)}°`
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.small
                }
            }

            Row {
                spacing: 10

                P5Text {
                    width: 88
                    display: true
                    text: "HUMIDITY"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.2
                }

                P5Text {
                    text: `${Weather.humidity}%`
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.small
                }
            }
        }

        // The next hours, newest first: NOW and the three after it. wttr
        // usually delivers a full day, but "usually" is not a layout — the
        // cards share the row they actually have, so a short forecast closes
        // up instead of leaving a hole on the right.
        Row {
            id: hours

            readonly property int cols: Math.max(1, Math.min(4, Weather.hourlyForecast.length))

            x: 24
            y: parent.height - 96
            width: parent.width - 48
            spacing: 8

            Repeater {
                model: Weather.hourlyForecast.slice(0, 4)

                Plate {
                    required property var modelData
                    required property int index

                    readonly property int h: Math.floor((modelData.time ?? 0) / 100)

                    width: (hours.width - (hours.cols - 1) * hours.spacing) / hours.cols
                    height: 74
                    radius: Appearance.r(12)
                    color: Colours.alpha(Colours.ink, 0.07)
                    border.width: 1
                    border.color: Colours.alpha(Colours.ink, 0.1)
                    antialiasing: true

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        text: index === 0 ? "NOW" : (h > 0 ? `${h}` : "—")
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1
                    }

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 24
                        width: 22
                        name: Weather.iconFor(modelData.code)
                        color: Colours.alpha(Colours.ink, 0.9)
                        font.pixelSize: 20
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 50
                        text: `${Math.round(modelData.tempC)}°`
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────── off / no data yet
    Item {
        anchors.fill: parent
        visible: !root.on || !Weather.ready

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 52
            width: 34
            name: "cloud"
            color: Colours.alpha(Colours.ink, 0.35)
            font.pixelSize: 32
        }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 104
            display: true
            text: root.on ? "NO DATA YET" : "WEATHER OFF"
            color: Colours.alpha(Colours.ink, 0.75)
            font.pixelSize: Appearance.font.size.large
            tracking: 1.6
        }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 132
            text: root.on ? "CLICK TO REFRESH" : "ENABLE IT IN THE SETTINGS"
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.2
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.on
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sfx.cursor();
                Weather.refresh();
            }
        }
    }
}
