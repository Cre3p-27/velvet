//  VELVET  ·  modules/lock/modules/LockAvatar.qml
//  The face that is coming back — the fluid lock's way: the initial rides in a
//  clam shell that slowly breathes, on a square card with a burst
//  watermark. Drop a picture at ~/.face and the shell wears your photo
//  instead, masked by the glyph itself (SETTINGS → LOCK SCREEN → YOUR
//  FACE). Hover the shell and it lifts — the clam keeps its shape.
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import Quickshell
import Quickshell.Io
import QtQuick
import "../glyphpaths.js" as GP

Item {
    id: root

    property bool compact: false
    property bool carded: true

    implicitWidth: root.compact ? 40 : 108
    implicitHeight: root.compact ? 40 : 108

    // The hover shape: the SAME glyph the lock's background wears
    // (LOCK SCREEN → BACKGROUND SHAPE) — the whole screen speaks one
    // shape language. With the background OFF there is nothing to echo,
    // so the shell simply keeps its rest form.
    readonly property int hoverTarget: GP.kindOfName(Config.lock.backgroundShape)

    // Probe ~/.face once, so a missing picture never produces a QML
    // warning — the initial simply stays.
    property bool faceExists: false
    readonly property string faceUrl: `file://${Quickshell.env("HOME") ?? ""}/.face`

    FileView {
        id: faceProbe

        path: root.faceUrl.replace("file://", "")
        printErrors: false

        onLoaded: root.faceExists = true
        onLoadFailed: root.faceExists = false
    }

    ModuleCard {
        anchors.fill: parent
        glyphKind: 3
        carded: root.carded
        visible: !root.compact
    }

    // The halo — one slow breath, looped. Full size only.
    Rectangle {
        anchors.centerIn: parent
        width: 68
        height: 68
        radius: 34
        color: "transparent"
        border.width: 2
        border.color: Colours.alpha(Colours.accent, 0.0)
        visible: !root.compact

        SequentialAnimation on border.color {
            loops: Animation.Infinite
            running: !root.compact

            ColorAnimation {
                from: Colours.alpha(Colours.accent, 0.0)
                to: Colours.alpha(Colours.accent, 0.45)
                duration: 1600
                easing.type: Easing.InOutSine
            }
            ColorAnimation {
                from: Colours.alpha(Colours.accent, 0.45)
                to: Colours.alpha(Colours.accent, 0.0)
                duration: 1600
                easing.type: Easing.InOutSine
            }
        }

        SequentialAnimation on scale {
            loops: Animation.Infinite
            running: !root.compact

            NumberAnimation {
                from: 1
                to: 1.28
                duration: 1600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 1.28
                to: 1
                duration: 1600
                easing.type: Easing.InOutSine
            }
        }
    }

    ShapeBadge {
        anchors.centerIn: parent
        size: root.compact ? 38 : 72
        kind: 0
        hoverKind: root.hoverTarget >= 0 ? root.hoverTarget : -1
        col: Colours.accent
        text: (Locker.user.charAt(0) || "?").toUpperCase()
        // The fluid lock's profile picture: the photo wears the glyph as its
        // mask; a missing ~/.face simply leaves the initial visible.
        image: Config.lock.avatarFace && root.faceExists ? root.faceUrl : ""
    }
}
