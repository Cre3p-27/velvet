//  VELVET  ·  modules/lock/ModuleHost.qml
//  One catalogue module — the single host shared by the lock screen and
//  the desktop's widget layer. On the lock it renders raw, because the
//  card is the frame (the fluid lock's way); on the wallpaper it rides in a
//  glass chip, because the desktop is its frame (the Material way). Either
//  home, the same file renders the same module.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick

Item {
    id: root

    required property string wid      // the catalogue id

    property var host: null           // the lock surface (the power module needs it)
    property real maxWidth: 420       // a module never grows past this
    property bool framed: false       // true = wrap in the glass chip (desktop)
    property bool compact: false      // true = the island's small rendering (media)
    property bool carded: true        // true = the fluid lock's card around the module
    property bool fillWidth: false    // true = fill the zone (the fluid lock's cards do)
    property bool fillHeight: false   // true = fill the tile's height (the last module of a column)

    // The chip's own look, when framed. The wallpaper's widget layer
    // recolours these per theme (GLASS / INK); the lock keeps the defaults.
    property color chipFill: Colours.alpha(Colours.surface, 0.55)
    property color chipBorder: Colours.alpha(Colours.accent, 0.28)

    // The module item's size is applied on events, not through a plain
    // binding: the tiles are born while the lock surface is still 0×0
    // (their zone widths are negative then), and bindings installed in
    // the loader's onLoaded have proven to freeze at that first value.
    function applySize(): void {
        if (!innerLoader.item)
            return;
        innerLoader.item.width = root.fillWidth ? root.maxWidth : Math.min(innerLoader.item.implicitWidth, root.maxWidth);
        innerLoader.item.height = root.fillHeight ? root.height : innerLoader.item.implicitHeight;
    }

    onMaxWidthChanged: root.applySize()
    onFillWidthChanged: root.applySize()
    onFillHeightChanged: root.applySize()
    onHeightChanged: {
        if (root.fillHeight)
            root.applySize();
    }

    implicitWidth: root.framed ? slotLoader.implicitWidth : innerLoader.implicitWidth
    implicitHeight: root.framed ? slotLoader.implicitHeight : innerLoader.implicitHeight

    // Which file answers to a catalogue id. Relative to this file, so the
    // mapping works from anywhere ModuleHost is used.
    function sourceOf(id: string): string {
        switch (id) {
        case "clock":
            return "modules/LockClock.qml";
        case "avatar":
            return "modules/LockAvatar.qml";
        case "weather":
            return "modules/LockWeather.qml";
        case "greeting":
            return "modules/LockGreeting.qml";
        case "notifs":
            return "modules/LockNotifs.qml";
        case "media":
            return "modules/LockMedia.qml";
        case "user":
            return "modules/LockUser.qml";
        case "battery":
            return "modules/LockBattery.qml";
        case "net":
            return "modules/LockNet.qml";
        case "power":
            return "modules/LockPower.qml";
        case "resources":
            return "modules/LockResources.qml";
        case "session":
            return "modules/LockSession.qml";
        }
        return "";
    }

    LockChip {
        id: chip

        visible: root.framed
        fill: root.chipFill
        border: root.chipBorder

        Loader {
            id: slotLoader

            active: root.framed
            width: slotLoader.item ? slotLoader.item.width : 0
            height: slotLoader.item ? slotLoader.item.height : 0
            source: root.sourceOf(root.wid)

            onLoaded: {
                slotLoader.item.width = Qt.binding(() => root.fillWidth ? root.maxWidth : Math.min(slotLoader.item.implicitWidth, root.maxWidth));
                // Same rule as applySize() below: a module that asks to
                // fill the tile's height must do so in the chip too.
                slotLoader.item.height = Qt.binding(() => root.fillHeight ? root.height : slotLoader.item.implicitHeight);
                // The power module needs the lock surface for its guarded
                // power actions — hand it over where it is declared.
                if ("host" in slotLoader.item)
                    slotLoader.item.host = Qt.binding(() => root.host);
                if ("compact" in slotLoader.item)
                    slotLoader.item.compact = Qt.binding(() => root.compact);
                if ("carded" in slotLoader.item)
                    slotLoader.item.carded = Qt.binding(() => root.carded);
            }
        }
    }

    // A module that changes its own size later (the weather card grows
    // when its forecast arrives, the dock with its notifications) must
    // take the lock's tile with it — the size above is set on events, so
    // those events have to include the module's own.
    Connections {
        target: innerLoader.item
        ignoreUnknownSignals: true

        function onImplicitHeightChanged(): void {
            root.applySize();
        }

        function onImplicitWidthChanged(): void {
            root.applySize();
        }
    }

    // The raw twin for the lock's card: same loader behaviour, no frame.
    Item {
        id: inner

        width: innerLoader.item ? innerLoader.item.width : 0
        height: innerLoader.item ? innerLoader.item.height : 0

        Loader {
            id: innerLoader

            width: innerLoader.item ? innerLoader.item.width : 0
            height: innerLoader.item ? innerLoader.item.height : 0
            source: root.framed ? "" : root.sourceOf(root.wid)

            onLoaded: {
                root.applySize();
                // A binding, not a copy: the host can arrive after the
                // module (and the power buttons must always reach it).
                if ("host" in innerLoader.item)
                    innerLoader.item.host = Qt.binding(() => root.host);
                if ("compact" in innerLoader.item)
                    innerLoader.item.compact = Qt.binding(() => root.compact);
                if ("carded" in innerLoader.item)
                    innerLoader.item.carded = Qt.binding(() => root.carded);
            }
        }
    }
}
