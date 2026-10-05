//  VELVET  ·  modules/bar/entries/ActiveWindow.qml
//  App icon plus title. In a vertical bar the title runs up the strip,
//  card-style, and it always fades out at the clip edge rather than
//  ending in a hard ellipsis.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    property bool vertical: true
    property int span: 30
    property real maxLength: 300
    property var win: null

    readonly property string title: Hypr.activeTitle
    readonly property string appId: Hypr.activeAppId
    readonly property bool has: title.length > 0

    readonly property int iconSize: Math.round(Config.bar.iconSize)
    readonly property real textLength: Math.min(root.maxLength, label.implicitWidth)

    implicitWidth: vertical ? span : iconSize + (has ? textLength + Appearance.spacing.small : 0)
    implicitHeight: vertical ? iconSize + (has ? textLength + Appearance.spacing.small : 0) : span

    opacity: has ? 1 : 0.35

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutExpo
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutExpo
        }
    }

    IconImage {
        id: icon

        implicitSize: root.iconSize
        source: root.appId ? Quickshell.iconPath(root.appId, "application-x-executable") : ""
        visible: root.has

        x: root.vertical ? (root.span - width) / 2 : 0
        y: root.vertical ? 0 : (root.span - height) / 2
    }

    Item {
        id: clipper

        clip: true

        x: root.vertical ? 0 : icon.width + Appearance.spacing.small
        y: root.vertical ? icon.height + Appearance.spacing.small : 0
        width: root.vertical ? root.span : root.textLength
        height: root.vertical ? root.textLength : root.span

        P5Text {
            id: label

            text: root.title
            color: Colours.ink
            font.pixelSize: Config.bar.fontSize
            elide: Text.ElideRight
            maximumLineCount: 1

            // Rotate for the vertical bar so it reads bottom-to-top.
            transformOrigin: Item.Center
            rotation: root.vertical ? -90 : 0
            width: root.vertical ? clipper.height : Math.min(root.maxLength, implicitWidth)

            x: root.vertical ? (clipper.width - width) / 2 : 0
            y: (clipper.height - height) / 2
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.has ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (Hypr.activeToplevel) {
                Sfx.cursor();
                Hypr.activeToplevel.activate();
            }
        }
    }
}
