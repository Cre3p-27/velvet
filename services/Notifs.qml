//  VELVET  ·  services/Notifs.qml
//  The notification daemon.
//
//  The rule this file exists to enforce: **the history holds data, never live
//  objects.** A `Notification` belongs to the server and is destroyed when the
//  app that sent it goes away — and a list still bound to one that has been
//  destroyed is how a shell locks up while you are looking at it. So every
//  notification is copied into a plain record the moment it arrives, and the
//  live object is only ever looked up again, freshly, at the instant a button
//  is actually pressed. Nothing in the UI holds one, so nothing in the UI can
//  be left holding a dead one.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    // Plain records. Each is { id, summary, body, appName, appIcon, image,
    // urgency, actions: [{ identifier, text }], time, seen }
    property var popups: []
    property var history: []

    readonly property int unread: root.history.filter(n => !n.seen).length
    readonly property int total: root.history.length

    // Bounded on purpose. Sixty cards of scrollback is not something anyone
    // reads, and it is something every layout pass has to walk.
    readonly property int cap: 40

    // Focus mode counts as do-not-disturb without touching your own
    // do-not-disturb setting, so leaving focus mode puts it back.
    readonly property bool dnd: Config.notifs.doNotDisturb || Focus.silences

    // Which ids the server still has. Derived, never stored — that is the
    // point. A record whose id has left this set describes a notification that
    // no longer exists, and `isLive` is how a card knows to stop offering
    // buttons that would do nothing.
    readonly property var liveIds: {
        const out = ({});
        const list = server.trackedNotifications?.values ?? [];
        for (let i = 0; i < list.length; i++) {
            const n = list[i];
            if (n)
                out[n.id] = true;
        }
        return out;
    }

    // The one place a live object is ever looked up, and it is looked up fresh
    // every time. Nothing keeps the result.
    function handle(id: int): var {
        const list = server.trackedNotifications?.values ?? [];
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].id === id)
                return list[i];
        return null;
    }

    function isLive(record: var): bool {
        return !!(record && root.liveIds[record.id]);
    }

    // Popups drop themselves when the app that sent them takes them back.
    readonly property var shownPopups: root.popups.filter(p => root.isLive(p))

    // ------------------------------------------------------------------ api
    function dismiss(record: var): void {
        if (!record)
            return;
        root.popups = root.popups.filter(p => p.id !== record.id);
    }

    function close(record: var): void {
        if (!record)
            return;
        const n = root.handle(record.id);
        root.popups = root.popups.filter(p => p.id !== record.id);
        root.history = root.history.filter(p => p.id !== record.id);
        if (n)
            n.dismiss();
    }

    function invoke(record: var, identifier: string): void {
        const n = record ? root.handle(record.id) : null;
        if (!n)
            return;
        const list = n.actions ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].identifier === identifier) {
                list[i].invoke();
                return;
            }
        }
    }

    function clearHistory(): void {
        const list = [...(server.trackedNotifications?.values ?? [])];
        for (let i = 0; i < list.length; i++)
            list[i]?.dismiss();
        root.history = [];
        root.popups = [];
    }

    function markAllSeen(): void {
        root.history = root.history.map(n => n.seen ? n : Object.assign({}, n, {
                    seen: true
                }));
    }

    function urgencyName(u: int): string {
        if (u === NotificationUrgency.Critical)
            return "critical";
        if (u === NotificationUrgency.Low)
            return "low";
        return "normal";
    }

    // ------------------------------------------------------------- the server
    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        actionIconsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            if (!Config.notifs.enabled)
                return;

            // Tracking is what keeps the sender from blocking on us. The
            // server owns the object's lifetime from here; we only ever borrow
            // it, never store it.
            notification.tracked = true;

            const actions = [];
            const raw = notification.actions ?? [];
            for (let i = 0; i < raw.length; i++)
                actions.push({
                    identifier: raw[i].identifier,
                    text: raw[i].text
                });

            const record = {
                id: notification.id,
                summary: `${notification.summary ?? ""}`,
                body: `${notification.body ?? ""}`,
                appName: `${notification.appName ?? ""}`,
                appIcon: `${notification.appIcon ?? ""}`,
                image: `${notification.image ?? ""}`,
                urgency: root.urgencyName(notification.urgency),
                actions: actions,
                time: Date.now(),
                seen: false
            };

            // Records past the cap are gone from the list — let the server
            // drop their live objects too, or they pile up all session
            // (most apps never close their own notifications).
            const next = [record].concat(root.history);
            for (let i = root.cap; i < next.length; i++) {
                const old = root.handle(next[i].id);
                if (old)
                    old.expire();
            }
            root.history = next.slice(0, root.cap);

            if (root.dnd)
                Focus.noteMissed();
            else
                root.popups = [record].concat(root.popups).slice(0, Config.notifs.maxPopups);
        }
    }
}
