//  VELVET  ·  modules/lock/ModuleGlyph.qml
//  A module's identity as a shape: each module of the catalogue owns one
//  of the lock's glyph forms, and hovering morphs it into a burst — the
//  same living-glyph language as the badges on the lock, for the editor
//  chips and the tray.
import QtQuick

MorphGlyph {
    id: root

    property string modId: "clock"
    property bool hovered: false

    property int _rand: 0

    onHoveredChanged: {
        if (root.hovered) {
            let r = root._rand;
            do {
                r = Math.floor(Math.random() * 8);
            } while (r === root.baseKind || r === root._rand);
            root._rand = r;
        }
    }

    readonly property int baseKind: {
        switch (root.modId) {
        case "clock":
            return 0;
        case "avatar":
            return 5;
        case "weather":
            return 3;
        case "greeting":
            return 1;
        case "notifs":
            return 5;
        case "media":
            return 2;
        case "user":
            return 0;
        case "battery":
            return 2;
        case "net":
            return 6;
        case "power":
            return 3;
        case "resources":
            return 4;
        }
        return 0;
    }

    kind: root.hovered ? root._rand : root.baseKind
}
