//  VELVET  ·  services/Toast.qml
//  Transient messages from the shell to you. Exists because the alternative —
//  an action that quietly does nothing — is the worst thing a desktop can do.
//  Anything that can fail should say so here rather than in a log you will
//  never read.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    property var items: []
    property int nextId: 1

    // kind: info | ok | warn | error
    function show(text: string, kind: string, ms: int): void {
        if (!text)
            return;

        const entry = {
            id: root.nextId++,
            text: text,
            kind: kind ?? "info",
            ms: ms && ms > 0 ? ms : 3600
        };
        // Newest first, and never more than a handful on screen.
        root.items = [entry].concat(root.items).slice(0, 4);
    }

    function ok(text: string): void {
        root.show(text, "ok", 2600);
    }

    function warn(text: string): void {
        root.show(text, "warn", 5000);
    }

    function error(text: string): void {
        root.show(text, "error", 7000);
    }

    function dismiss(id: int): void {
        root.items = root.items.filter(i => i.id !== id);
    }

    function clear(): void {
        root.items = [];
    }
}
