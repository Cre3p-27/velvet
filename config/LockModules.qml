//  VELVET  ·  config/LockModules.qml
//  The lock's module catalogue — every piece the lock screen can show.
//  The lock renders exactly what LockLayout lists; the LOCK SCREEN editor
//  turns these entries into chips you drag anywhere on the lock.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property var all: [
        {
            id: "clock",
            name: "CLOCK",
            glyph: "schedule"
        },
        {
            id: "avatar",
            name: "AVATAR",
            glyph: "account_circle"
        },
        {
            id: "weather",
            name: "WEATHER",
            glyph: "cloud"
        },
        {
            id: "greeting",
            name: "GREETING",
            glyph: "waving_hand"
        },
        {
            id: "notifs",
            name: "NOTIFICATIONS",
            glyph: "notifications"
        },
        {
            id: "media",
            name: "MEDIA",
            glyph: "music_note"
        },
        {
            id: "user",
            name: "USER",
            glyph: "person"
        },
        {
            id: "battery",
            name: "BATTERY",
            glyph: "battery_full"
        },
        {
            id: "net",
            name: "NETWORK",
            glyph: "wifi"
        },
        {
            id: "power",
            name: "POWER",
            glyph: "power_settings_new"
        },
        {
            id: "resources",
            name: "RESOURCES",
            glyph: "developer_board"
        },
        {
            id: "session",
            name: "SESSION",
            glyph: "terminal"
        }
    ]

    function find(id: string): var {
        for (let i = 0; i < root.all.length; i++)
            if (root.all[i].id === id)
                return root.all[i];
        return null;
    }
}
