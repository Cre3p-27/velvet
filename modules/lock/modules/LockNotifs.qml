//  VELVET  ·  modules/lock/modules/LockNotifs.qml
//  The notifications, the fluid lock's dock way: a card with its small 12px
//  corners, the mono title line ("3 notifications"), and one rounded card
//  per app — icon circle, app name, when, a count pill that unfolds the
//  preview on click, and the lines themselves. Critical groups wear its
//  tinted card and a red icon circle. A flat list, a shorter list and
//  hiding content until unlock (privacy) are all SETTINGS.
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

    implicitHeight: root.compact ? 28 : 240
    implicitWidth: root.compact ? compactRow.width : 340

    // Groups by app, newest first — the fluid lock's dock keeps one row per app
    // and folds the rest of the preview behind a click.
    readonly property var groups: {
        const map = {};
        const out = [];
        for (let i = 0; i < Notifs.history.length; i++) {
            const n = Notifs.history[i];
            const key = n.appName || "APP";
            if (!map[key]) {
                map[key] = {
                    app: key,
                    items: []
                };
                out.push(map[key]);
            }
            map[key].items.push(n);
        }
        return out;
    }

    function ago(t: real): string {
        const s = Math.floor((Date.now() - t) / 1000);
        if (s < 60)
            return "now";
        const m = Math.floor(s / 60);
        if (m < 60)
            return `${m}m`;
        const h = Math.floor(m / 60);
        if (h < 24)
            return `${h}h`;
        return `${Math.floor(h / 24)}d`;
    }

    // A group counts as critical when any of its notifications is.
    function critical(items: var): bool {
        for (let i = 0; i < items.length; i++)
            if (items[i].urgency === "critical")
                return true;
        return false;
    }

    ModuleCard {
        anchors.fill: parent
        glyphKind: 0
        radius: 12
        // The fluid lock's dock label: "3 notifications" / "Notifications".
        title: Notifs.total > 0 ? `${Notifs.total} ${Notifs.total === 1 ? "notification" : "notifications"}` : "Notifications"
        carded: root.carded
        visible: !root.compact
    }

    // ── the island rendering: bell in a living glyph and unread count
    Row {
        id: compactRow

        anchors.verticalCenter: parent.verticalCenter
        visible: root.compact
        spacing: 6

        ShapeBadge {
            size: 26
            kind: 5
            hoverKind: -1
            col: Colours.alpha(Notifs.unread > 0 ? Colours.accent : Colours.inkDim, 0.16)
            icon: Notifs.unread > 0 ? "notifications_active" : "notifications"
            iconCol: Notifs.unread > 0 ? Colours.accent : Colours.alpha(Colours.inkDim, 0.6)
            iconSize: 14
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: Notifs.unread > 0 ? `${Notifs.unread}` : "0"
            color: Notifs.unread > 0 ? Colours.ink : Colours.alpha(Colours.inkDim, 0.6)
            font.pixelSize: Appearance.font.size.small
        }
    }

    // ── the card: the dock itself
    Item {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 40
        clip: true
        visible: !root.compact

        // Privacy mode — the fluid lock's hideNotifs: content stays behind the
        // lock, only the promise shows.
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: Config.lock.hideNotifs

            ShapeBadge {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 40
                kind: 5
                hoverKind: -1
                col: Colours.alpha(Colours.accent, 0.16)
                icon: "lock"
                iconCol: Colours.accent
                iconSize: 19
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Unlock for notifications"
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: 12
                font.family: Appearance.fontFamily.mono
            }
        }

        // Nothing arrived yet.
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: !Config.lock.hideNotifs && Notifs.history.length === 0

            ShapeBadge {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 64
                kind: 3
                hoverKind: -1
                col: Colours.alpha(Colours.accent, 0.14)
                icon: "done_all"
                iconCol: Colours.accent
                iconSize: 26
            }

            Item {
                width: 1
                height: 4
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "All caught up"
                color: Colours.alpha(Colours.ink, 0.85)
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Nothing new while you were away"
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: 12
            }
        }

        // The dock: grouped by app or flat, as SETTINGS decides.
        Column {
            width: parent.width
            spacing: 8
            visible: !Config.lock.hideNotifs && Notifs.history.length > 0

            Repeater {
                model: Config.lock.notifsGrouped ? root.groups.slice(0, Config.lock.notifsCount) : Notifs.history.slice(0, Config.lock.notifsCount)

                // GroupRow declares modelData itself — declaring it again
                // here shadowed it, the row's own copy was never filled, and
                // every row failed to build: the dock stayed empty for good.
                GroupRow {
                    width: parent.width
                }
            }

            // What did not fit, said once instead of silently dropped.
            P5Text {
                readonly property int rest: (Config.lock.notifsGrouped ? root.groups.length : Notifs.history.length) - Config.lock.notifsCount

                visible: rest > 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: `+ ${rest} more ${Config.lock.notifsGrouped ? (rest === 1 ? "app" : "apps") : (rest === 1 ? "notification" : "notifications")} — unlock to see ${rest === 1 ? "it" : "them"}`
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: 12
            }
        }
    }

    // ── one dock card: icon circle, app name, when, the count pill, and
    // the preview lines — a click unfolds the rest, the fluid lock's expand.
    component GroupRow: Item {
        id: row

        required property var modelData
        property bool expanded: false

        // Flat mode hands one record at a time; grouped mode a whole app
        // group.
        readonly property var items: Config.lock.notifsGrouped ? row.modelData.items : [row.modelData]
        readonly property bool isCrit: root.critical(row.items)

        readonly property string app: items.length > 0 ? (items[0].appName || "APP") : "APP"
        readonly property real firstTime: items.length > 0 ? (items[0].time ?? 0) : 0

        height: row.expanded ? Math.min(row.items.length, 4) * 20 + 44 : 60

        Behavior on height {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutQuad
            }
        }

        // The fluid lock's group card: tinted for critical ones, quiet for the
        // rest.
        Rectangle {
            anchors.fill: parent
            radius: 16
            color: row.isCrit ? Colours.alpha(Colours.accentAlt, 0.24) : Colours.alpha(Colours.surfaceHigh, 0.6)
            antialiasing: true
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            // The icon circle — red and loud for critical, its signature.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: 18
                color: row.isCrit ? Colours.danger : Colours.alpha(Colours.ink, 0.07)
                antialiasing: true

                // The app's own icon when the theme has one (its desktop
                // icon, or one named like the app) — the bell otherwise.
                readonly property string appIconPath: {
                    if (row.isCrit)
                        return "";
                    const it = row.items.length > 0 ? row.items[0] : null;
                    const byIcon = it?.appIcon ? Quickshell.iconPath(it.appIcon, true) : "";
                    if (byIcon)
                        return byIcon;
                    const name = (row.app || "").toLowerCase().replace(/\s+/g, "-");
                    return name ? Quickshell.iconPath(name, true) : "";
                }

                Image {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    sourceSize: Qt.size(44, 44)
                    source: parent.appIconPath
                    visible: parent.appIconPath !== "" && status === Image.Ready
                    asynchronous: true
                    smooth: true
                }

                Icon {
                    anchors.centerIn: parent
                    visible: parent.appIconPath === ""
                    name: row.isCrit ? "warning" : "notifications"
                    color: row.isCrit ? Colours.paper : Colours.inkDim
                    font.pixelSize: 17
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36 - 10 - 12
                spacing: 2

                P5Text {
                    width: parent.width - 12
                    text: row.app
                    color: Colours.alpha(Colours.inkDim, 0.9)
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                P5Text {
                    width: parent.width - 12
                    visible: row.height > 54
                    text: {
                        const it = row.items[0];
                        const s = `${it?.summary ?? ""}`.replace(/\n/g, " ");
                        const b = `${it?.body ?? ""}`.replace(/\n/g, " ");
                        if (s.length === 0)
                            return b;
                        if (b.length === 0)
                            return s;
                        return `${s} · ${b}`;
                    }
                    color: Colours.ink
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        // The count pill + unfold glyph, the fluid lock's expand chip.
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: 18
            height: 22
            width: Math.max(22, expandRow.implicitWidth + 14)
            radius: 11
            color: Colours.alpha(Colours.ink, 0.06)
            antialiasing: true
            visible: row.items.length > 1

            Row {
                id: expandRow

                anchors.centerIn: parent
                spacing: 2

                P5Text {
                    text: `${row.items.length}`
                    color: Colours.inkDim
                    font.pixelSize: 10
                }

                Icon {
                    name: row.expanded ? "expand_less" : "expand_more"
                    color: Colours.inkDim
                    font.pixelSize: 13
                }
            }
        }

        // The unfolded preview lines.
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.topMargin: 44
            spacing: 2
            visible: row.expanded

            Repeater {
                model: Math.min(row.items.length, 4)

                P5Text {
                    required property int index

                    width: parent.width
                    text: {
                        const it = row.items[index];
                        const s = `${it?.summary ?? ""}`.replace(/\n/g, " ");
                        const b = `${it?.body ?? ""}`.replace(/\n/g, " ");
                        if (s.length === 0)
                            return b;
                        if (b.length === 0)
                            return s;
                        return `${s} · ${b}`;
                    }
                    color: index === 0 ? Colours.ink : Colours.alpha(Colours.ink, 0.75)
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        // The time, quiet and right-aligned under the name.
        P5Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 34
            text: root.ago(row.firstTime)
            color: Colours.alpha(Colours.inkDim, 0.55)
            font.pixelSize: 11
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                Sfx.cursor();
                row.expanded = !row.expanded;
            }
        }
    }
}
