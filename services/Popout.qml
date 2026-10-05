//  VELVET  ·  services/Popout.qml
//  One popout layer per screen, driven from here so bar entries never have to
//  know anything about windows or coordinates.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property string name: ""
    property bool pinned: false
    property real anchorPos: 0        // centre of the trigger, along the bar axis
    property string screenName: ""
    property var trayItem: null
    property string tipText: ""
    property int wsId: 0

    readonly property bool open: name !== ""

    function _measure(item: Item, win: var): void {
        if (!item)
            return;
        const p = item.mapToItem(null, 0, 0);
        const vertical = win ? win.vertical : true;
        root.anchorPos = vertical ? p.y + item.height / 2 : p.x + item.width / 2;
        root.screenName = win && win.screen ? win.screen.name : "";
    }

    // A short label next to whatever you are hovering. Deliberately separate
    // from request(): a tip must never steal a pinned panel.
    function tip(text: string, item: Item, win: var): void {
        if (root.pinned || (root.open && root.name !== "tip"))
            return;
        root.tipText = text;
        _measure(item, win);
        root.name = "tip";
    }

    function workspace(id: int, item: Item, win: var): void {
        if (root.pinned)
            return;
        root.wsId = id;
        _measure(item, win);
        root.name = "ws";
    }

    function request(which: string, item: Item, win: var): void {
        if (root.pinned && root.name !== which)
            return;
        closeTimer.stop();
        _measure(item, win);
        root.name = which;
    }

    function release(which: string): void {
        if (root.pinned)
            return;
        if (root.name === which)
            closeTimer.restart();
    }

    // Hovering the popout itself keeps it alive.
    function hold(): void {
        closeTimer.stop();
    }

    function pin(which: string, item: Item, win: var): void {
        if (root.pinned && root.name === which) {
            root.close();
            return;
        }
        _measure(item, win);
        root.name = which;
        root.pinned = true;
    }

    function close(): void {
        closeTimer.stop();
        root.name = "";
        root.pinned = false;
        root.trayItem = null;
    }

    Timer {
        id: closeTimer
        interval: 260
        onTriggered: root.close()
    }
}
