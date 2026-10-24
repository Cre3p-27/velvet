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

    // Nothing new: the fluid lock lets the dock rest (LOCK SCREEN → FLUID
    // LOCK → MODULE DETAILS → NO NOTIFICATIONS) — SLIM is
    // one low line, HIDE takes the tile away (FluidFace), CARD the full dock.
    readonly property bool quiet: Notifs.history.length === 0
    readonly property bool slim: !root.compact && root.quiet && Config.lock.notifsIdle !== "card"

    implicitHeight: root.compact ? 28 : (root.slim ? 64 : 240)
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
        title: root.slim ? "" : (Notifs.total > 0 ? `${Notifs.total} ${Notifs.total === 1 ? "notification" : "notifications"}` : "Notifications")
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
    // ── resting: one low line
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        visible: root.slim
        spacing: 12

        ShapeBadge {
            anchors.verticalCenter: parent.verticalCenter
            size: 32
            kind: 3
            hoverKind: -1
            col: Colours.alpha(Colours.accent, 0.14)
            icon: "done_all"
            iconCol: Colours.accent
            iconSize: 15
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            P5Text {
                width: Math.min(implicitWidth, root.width - 76)
                text: "All caught up"
                color: Colours.alpha(Colours.ink, 0.85)
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            P5Text {
                width: Math.min(implicitWidth, root.width - 76)
                text: "Nothing new while you were away"
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: 40
        clip: true
        visible: !root.compact && !root.slim

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
        // The row answers the pointer: it is a button (it unfolds).
        Rectangle {
            anchors.fill: parent
            radius: 16
            color: {
                if (row.isCrit)
                    return Colours.alpha(Colours.accentAlt, rowArea.containsMouse ? 0.32 : 0.24);
                return rowArea.containsMouse ? Colours.alpha(Colours.mix(Colours.surfaceHigh, Colours.ink, 0.1), 0.8) : Colours.alpha(Colours.surfaceHigh, 0.6);
            }
            border.width: 1
            border.color: Colours.alpha(Colours.accent, rowArea.containsMouse ? 0.3 : 0)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
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
                    // clear of the count chip on the right
                    width: parent.width - (row.items.length > 1 ? 56 : 12)
                    text: row.app
                    color: Colours.alpha(Colours.inkDim, 0.9)
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                P5Text {
                    // clear of the time on the right ("now", "12m", "3h")
                    width: parent.width - 40
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
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sfx.cursor();
                row.expanded = !row.expanded;
            }
        }
    }
}
