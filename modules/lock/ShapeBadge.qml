//  VELVET  ·  modules/lock/ShapeBadge.qml
//  A module's glyph: an icon or a short label riding inside one of the
//  lock's shapes. Hovering changes the shape — by default to a RANDOM
//  fresh form every time (the fluid lock's shuffled shape queue), morphed
//  cleanly point by point instead of swapping. `hoverKind` can pin a
//  fixed hover form instead, and `hoverSet` restricts the random pool —
//  the avatar only wants full, face-friendly forms, never the half-dome.
//
//  Used by the lock's modules (power buttons, the confirm button, the
//  pill badges, the avatar, the resource cells) and anywhere else a
//  module needs a living glyph.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property int kind: 0              // rest form
    property int hoverKind: -2        // -2 = random (default), -1 = keep, >=0 = fixed
    property var hoverSet: []         // the random pool when hoverKind is -2
    property color col: Colours.accent
    property color hoverCol: root.col
    property color iconCol: Colours.on(root.col)
    property color hoverIconCol: root.iconCol
    property string icon: ""          // material symbol, or…
    property string text: ""          // …a short label instead (avatar initial)
    property bool filled: true        // the filled material-symbol style
    property real iconSize: 0         // 0 = automatic
    property real size: 34
    property real fill: -1            // 0..1 liquid fill inside the shape
    property color fillColour: Colours.alpha(root.col, 0.3)
    property bool waveFill: false     // true = the fill's edge ripples
    property string image: ""         // a photo masked by the glyph (avatar)

    signal clicked

    width: root.size
    height: root.size
    implicitWidth: root.size
    implicitHeight: root.size

    readonly property bool hot: hoverArea.containsMouse

    property int _rand: 0

    onHotChanged: {
        if (root.hot && root.hoverKind === -2) {
            // The pool is either the caller's curated set or the whole
            // deck; the rest form itself never wins, and neither does
            // the shape the badge just wore, so every hover visibly
            // changes the shape.
            const pool = root.hoverSet.length > 0 ? root.hoverSet : [0, 1, 2, 3, 4, 5, 6];
            const options = pool.filter(k => k !== root.kind && k !== root._rand);
            const src = options.length > 0 ? options : pool;
            root._rand = src[Math.floor(Math.random() * src.length)];
        }
    }

    readonly property int effKind: {
        if (!root.hot)
            return root.kind;
        if (root.hoverKind >= 0)
            return root.hoverKind;
        if (root.hoverKind === -2)
            return root._rand;
        return root.kind;
    }
    readonly property color effCol: root.hot ? root.hoverCol : root.col
    readonly property color effIconCol: root.hot ? root.hoverIconCol : root.iconCol

    // A small pop on top of the shape morph keeps the badge feeling alive;
    // pressing dips it fast, so a click visibly lands even before the action
    // fires — every badge in the lock answers the hand.
    scale: root.hot ? 1.08 : (hoverArea.pressed ? 0.88 : 1)

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutBack
            easing.overshoot: 2.5
        }
    }

    MorphGlyph {
        id: _glyph

        anchors.fill: parent
        kind: root.effKind
        col: root.effCol
        fill: root.fill
        fillColour: root.fillColour
        wave: root.waveFill
    }

    // A photo in the avatar — masked by the glyph itself, the fluid lock's
    // way: the photo IS the shell, cut to its shape (the clam dome for
    // the profile, the circle for the media art), and the mask follows
    // the glyph's hover morph. The decode is capped so a huge ~/.face
    // never has to build a monster texture; the glyph underneath is the
    // loading state until the photo arrives.
    Image {
        id: photoImg

        anchors.fill: parent
        source: root.image
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
        visible: root.image !== ""
        sourceSize.width: 768
        sourceSize.height: 768

        layer.enabled: root.image !== ""
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: _glyph
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0
            maskSpreadAtMax: 0
        }
    }

    Icon {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (root.kind === 5 && root.image === "" ? root.size * 0.078 : 0) + (root.text !== "" ? -root.size * 0.16 : 0)
        visible: root.icon !== "" && root.image === ""
        name: root.icon
        filled: root.filled
        color: root.effIconCol
        font.pixelSize: root.iconSize > 0 ? root.iconSize : (root.text !== "" ? root.size * 0.34 : root.size * 0.45)
    }

    P5Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (root.kind === 5 && root.image === "" ? root.size * 0.078 : 0) + (root.icon !== "" ? root.size * 0.24 : 0)
        visible: root.text !== "" && root.image === ""
        display: true
        text: root.text
        color: root.effIconCol
        font.pixelSize: Math.max(10, root.size * 0.22)
        font.weight: Font.Medium
    }

    signal pressed

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onPressed: root.pressed()
        onClicked: root.clicked()
    }
}
