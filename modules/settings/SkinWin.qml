//  VELVET  ·  modules/settings/SkinWin.qml
//  The settings window of the WINDOWS look: one frame per edition (the title
//  bar, tabs, navigation and status line differ), picked by WINDOWS VERSION.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var host: null
    property bool back: false

    Loader {
        anchors.fill: parent
        sourceComponent: ({
                "95": f95,
                "xp": fXp,
                "7": f7,
                "10": f10,
                "11": f11
            })[Appearance.winVer] ?? f11
    }

    Component {
        id: f95

        WinFrame95 {
            host: root.host
            back: root.back
        }
    }

    Component {
        id: fXp

        WinFrameXp {
            host: root.host
            back: root.back
        }
    }

    Component {
        id: f7

        WinFrame7 {
            host: root.host
            back: root.back
        }
    }

    Component {
        id: f10

        WinFrame10 {
            host: root.host
            back: root.back
        }
    }

    Component {
        id: f11

        WinFrame11 {
            host: root.host
            back: root.back
        }
    }
}
