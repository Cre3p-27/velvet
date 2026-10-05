//  VELVET  ·  modules/lock/modules/LockGreeting.qml
//  A quiet hello that knows the time of day — "Good evening, Creep" —
//  on a card with an arrow watermark and a living burst beside the words
//  (its icon follows the day too: dawn, sun, moon, sleep).
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import Quickshell
import QtQuick

Item {
    id: root

    property bool compact: false
    property bool carded: true

    implicitHeight: root.compact ? 18 : 64
    implicitWidth: root.compact ? 160 : 340

    // The greeting follows the day: morning, afternoon, evening, night.
    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    readonly property string who: {
        const n = Config.lock.greeting || Locker.user || "";
        return n ? n.charAt(0).toUpperCase() + n.slice(1) : "";
    }
    readonly property string part: {
        const h = clock.date.getHours();
        if (h >= 5 && h < 12)
            return "Good morning";
        if (h >= 12 && h < 18)
            return "Good afternoon";
        if (h >= 18 && h < 23)
            return "Good evening";
        return "Good night";
    }
    readonly property string icon: {
        const h = clock.date.getHours();
        if (h >= 5 && h < 12)
            return "wb_twilight";
        if (h >= 12 && h < 18)
            return "light_mode";
        if (h >= 18 && h < 23)
            return "nights_stay";
        return "bedtime";
    }

    ModuleCard {
        anchors.fill: parent
        glyphKind: 1
        carded: root.carded
        visible: !root.compact
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        ShapeBadge {
            size: root.compact ? 24 : 28
            kind: 3
            hoverKind: -1
            col: Colours.alpha(Colours.accent, 0.16)
            icon: root.icon
            iconCol: Colours.accent
            iconSize: root.compact ? 13 : 16
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.compact ? `Hi, ${root.who || "there"}` : (root.who ? `${root.part}, ${root.who}` : root.part)
            color: Colours.alpha(Colours.ink, 0.88)
            font.pixelSize: root.compact ? Appearance.font.size.tiny : 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }
}
