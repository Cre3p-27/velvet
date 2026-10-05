//  VELVET  ·  components/Parked.qml
//  A window the shell keeps OUT of memory until somebody asks for it.
//
//  The settings, the launcher, the notification centre, the wallpaper wheel …
//  are big QML trees that sit unused almost all the time. Measured on this
//  shell: the eleven of them cost ~240 MB of a 660 MB process, while they were
//  closed. A Parked window is created the moment `open` turns true, stays for
//  `keep` seconds after it closes (so closing animations finish and a quick
//  reopen is instant) and is then destroyed, freeing its memory.
//
//      Parked { open: Panels.settings; Settings {} }
//
//  The window itself has to open when it is CREATED already-open (the flag it
//  listens to went true before it existed) — see `present()` in the panels.
import Quickshell
import QtQuick

Scope {
    id: root

    property bool open: false
    // seconds a closed window stays loaded
    property real keep: 45
    property bool held: false

    readonly property bool loaded: loader.active
    readonly property var item: loader.item
    default property alias contents: loader.component

    // For windows that are summoned by an event rather than a flag (the
    // vibe flash): load it (or keep it) for `keep` seconds, then let it go.
    function pulse(): void {
        root.held = true;
        hold.restart();
    }

    onOpenChanged: {
        if (root.open) {
            hold.stop();
            root.held = true;
        } else {
            root.held = true;
            hold.restart();
        }
    }

    LazyLoader {
        id: loader

        active: root.open || root.held
    }

    Timer {
        id: hold

        interval: Math.max(1, root.keep * 1000)
        onTriggered: root.held = false
    }
}
