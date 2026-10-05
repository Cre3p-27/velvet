//  VELVET  ·  WeatherEntry — wttr.in, no key, no account.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    padding: 4
    visible: Config.services.weather && Weather.ready
    tip: Weather.ready ? `${Weather.description.toUpperCase()}  ·  FEELS ${Math.round(Weather.feelsLike)}°  ·  ${Weather.place.toUpperCase()}` : "WEATHER"
    hoverable: true

    onClicked: {
        Sfx.cursor();
        Weather.refresh();
        spin.restart();
    }
    onRightClicked: Panels.openSettingsKey("services.weather")

    Loader {
        sourceComponent: root.vertical ? stackedC : inlineC
    }

    SequentialAnimation {
        id: spin

        NumberAnimation {
            target: root
            property: "rotation"
            to: 360
            duration: Appearance.anim.slow
            easing.type: Easing.OutCubic
        }
        PropertyAction {
            target: root
            property: "rotation"
            value: 0
        }
    }

    Component {
        id: stackedC

        Column {
            spacing: -1

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: Weather.icon
                font.pixelSize: Config.bar.iconSize
                color: Colours.ink
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: Weather.short
                color: Colours.accentInk
                font.pixelSize: Config.bar.fontSize * 0.8
            }
        }
    }

    Component {
        id: inlineC

        Row {
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Weather.icon
                font.pixelSize: Config.bar.iconSize
                color: Colours.ink
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: Weather.short
                color: Colours.accentInk
                font.pixelSize: Config.bar.fontSize
            }
        }
    }
}
