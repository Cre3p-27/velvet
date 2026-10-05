//  VELVET  ·  modules/lock/LockExtras.qml
//  The small lines a lock face can carry under its clock — battery · network,
//  the song that is playing, the weather — each only when the user switched it
//  on (LOCK SCREEN → VIBE FACES → SHOW). A face places this where it likes and
//  gives it its own colour, type and size.
import qs.config
import qs.services
import qs.components
import QtQuick

Column {
    id: root

    property var kit: null
    property color colour: Colours.inkDim
    property string family: Appearance.fontFamily.body
    property real size: 15
    property bool upper: false
    // a face that draws battery and network its own way turns this off
    property bool info: true
    property int align: Text.AlignHCenter

    readonly property var lines: {
        const out = [];
        if (!root.kit)
            return out;
        if (root.info && root.kit.showInfo && root.kit.infoLine !== "")
            out.push(root.kit.infoLine);
        if (root.kit.mediaLine !== "")
            out.push("♪  " + root.kit.mediaLine);
        if (root.kit.weatherLine !== "")
            out.push(root.kit.weatherLine);
        return out;
    }

    visible: root.lines.length > 0
    spacing: root.size * 0.35

    Repeater {
        model: root.lines

        Text {
            required property string modelData

            width: root.width > 0 ? root.width : implicitWidth
            horizontalAlignment: root.align
            text: root.upper ? modelData.toUpperCase() : modelData
            color: root.colour
            font.family: root.family
            font.pixelSize: root.size
            elide: Text.ElideRight
        }
    }
}
