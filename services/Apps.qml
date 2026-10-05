//  VELVET  ·  services/Apps.qml
//  Launcher backend: desktop entries, fuzzy matching, a calculator, and
//  ">" prefixed shell actions. Frecency keeps what you actually use on top.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string usagePath: `${Quickshell.env("HOME")}/.config/velvet/usage.json`
    property var usage: ({
    })
    // Pinned apps ride in the same file, under a reserved key. They
    // outrank frecency forever — your loadout, not your habits.
    property var pinned: []

    readonly property var all: {
        const out = [];
        const entries = DesktopEntries.applications?.values ?? [];
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.noDisplay)
                continue;
            out.push(e);
        }
        return out;
    }

    // ------------------------------------------------------------------ scoring
    // Subsequence match, but weight contiguous runs and word starts heavily so
    // "ff" finds Firefox before it finds "Effects".
    function score(haystack: string, needle: string): real {
        if (!needle)
            return 0;
        const h = haystack.toLowerCase();
        const n = needle.toLowerCase();

        if (h === n)
            return 1000;
        if (h.startsWith(n))
            return 800 - h.length;
        const idx = h.indexOf(n);
        if (idx !== -1)
            return 600 - idx * 2 - h.length * 0.1;

        if (!Config.launcher.fuzzy)
            return -1;

        let hi = 0;
        let points = 0;
        let streak = 0;
        for (let ni = 0; ni < n.length; ni++) {
            const c = n[ni];
            let found = -1;
            while (hi < h.length) {
                if (h[hi] === c) {
                    found = hi;
                    break;
                }
                hi++;
            }
            if (found === -1)
                return -1;
            const wordStart = found === 0 || h[found - 1] === " " || h[found - 1] === "-" || h[found - 1] === "_";
            points += wordStart ? 14 : 4;
            points += streak * 6;
            streak = found === hi ? streak + 1 : 0;
            hi = found + 1;
        }
        return points - h.length * 0.15;
    }

    function frecency(id: string): real {
        const u = root.usage[id];
        if (!u)
            return 0;
        const ageDays = (Date.now() - u.last) / 86400000;
        return u.count * Math.exp(-ageDays / 21);
    }

    function isPinned(id: string): bool {
        return root.pinned.indexOf(id) !== -1;
    }

    function togglePin(id: string): void {
        const next = root.pinned.slice();
        const i = next.indexOf(id);
        if (i === -1)
            next.push(id);
        else
            next.splice(i, 1);
        root.pinned = next;
        root.persist();
    }

    function persist(): void {
        const u = Object.assign({}, root.usage);
        u.__pinned = root.pinned;
        usageFile.setText(JSON.stringify(u));
    }

    // 1234567.89 → 1,234,567.89 — big calculator results read at a glance.
    function formatNum(v: real): string {
        const s = `${v}`;
        if (s.indexOf(".") !== -1) {
            const parts = s.split(".");
            parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
            return parts.join(".");
        }
        return s.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }

    function search(query: string): var {
        const q = query.trim();

        // Calculator: "= 2+2" or a bare arithmetic expression.
        if (Config.launcher.useCalculator && /^[=\d(].*[\d)]$/.test(q) && /[+\-*/%^]/.test(q)) {
            const expr = q.replace(/^=/, "").replace(/\^/g, "**");
            if (/^[\d\s+\-*/%.()**]+$/.test(expr)) {
                try {
                    const value = Function(`"use strict";return (${expr})`)();
                    if (typeof value === "number" && isFinite(value))
                        return [
                            {
                                kind: "calc",
                                name: root.formatNum(value),
                                sub: `= ${q.replace(/^=/, "").trim()}   ·   Enter copies`,
                                icon: "calculate",
                                payload: `${value}`
                            }
                        ];
                } catch (e) {}
            }
        }

        // Shell action: "> systemctl suspend"
        if (q.startsWith(Config.launcher.actionPrefix)) {
            const cmd = q.slice(Config.launcher.actionPrefix.length).trim();
            if (cmd)
                return [
                    {
                        kind: "exec",
                        name: cmd,
                        sub: "RUN COMMAND",
                        icon: "terminal",
                        payload: cmd
                    }
                ];
            return [];
        }

        const results = [];
        const apps = root.all;
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i];
            let s = Math.max(root.score(e.name ?? "", q), root.score(e.genericName ?? "", q) * 0.7, root.score(e.id ?? "", q) * 0.6);
            if (q === "")
                s = 1;
            if (s < 0)
                continue;
            results.push({
                kind: "app",
                name: e.name,
                sub: (e.genericName || e.comment || "APPLICATION").toString().toUpperCase(),
                icon: e.icon,
                entry: e,
                id: e.id,
                pinned: root.isPinned(e.id),
                _s: s + root.frecency(e.id) * 40 + (root.isPinned(e.id) ? 100000 : 0)
            });
        }

        // Settings are searchable from here too, so you never have to
        // remember whether a thing lives in an app or in the shell. They rank
        // just under apps, since typing a name usually means "launch it".
        if (Config.launcher.searchSettings && q.length >= 2) {
            const flat = Schema.flat;
            for (let i = 0; i < flat.length; i++) {
                const e = flat[i];
                const s = Math.max(root.score(e.item.name ?? "", q), root.score(e.item.sub ?? "", q) * 0.45, root.score(e.path ?? "", q) * 0.35);
                if (s < 0)
                    continue;
                results.push({
                    kind: "setting",
                    name: e.item.name,
                    sub: e.path.toUpperCase(),
                    icon: "tune",
                    entry: e,
                    _s: s * 0.62
                });
            }
        }

        results.sort((a, b) => b._s - a._s);
        return results.slice(0, Config.launcher.maxShown);
    }

    //  Nothing a launcher starts may live in the shell's own cgroup.
    //  A process spawned as a child of the shell is in the shell's transient
    //  unit, and a restart walks that unit down: SIGTERM to everything in
    //  it, then SIGKILL ninety seconds later. A game started from here once
    //  nearly went down with a shell restart — that is how this was found.
    //  Hyprland's exec spawns in the session's own scope instead, so the
    //  shell can restart all day and the app never notices. Same path the
    //  DESKTOP room already uses for its scene programs.
    function shq(s: string): string {
        // Single-quote for /bin/sh, escaping the quote itself the POSIX way.
        return `'${`${s}`.replace(/'/g, "'\\''")}'`;
    }

    function spawn(entry: var): void {
        const argv = entry?.command ?? [];
        if (argv.length === 0)
            return;
        const cmd = argv.map(root.shq).join(" ");
        const dir = `${entry?.workingDirectory ?? ""}`.trim();
        // `exec` so the shell Hyprland spawned hands over instead of
        // lingering as a parent for the app's whole life.
        Hypr.exec(dir !== "" ? `cd ${root.shq(dir)} && exec ${cmd}` : `exec ${cmd}`);
    }

    function launch(item: var): void {
        if (!item)
            return;

        if (item.kind === "app") {
            const id = item.id;
            const u = Object.assign({}, root.usage);
            u[id] = {
                count: (u[id]?.count ?? 0) + 1,
                last: Date.now()
            };
            root.usage = u;
            root.persist();
            root.spawn(item.entry);
        } else if (item.kind === "exec") {
            // `> some command`: the shell interprets it, Hyprland owns it.
            Hypr.exec(item.payload);
        } else if (item.kind === "setting") {
            Panels.openSettingsAt(item.entry);
        } else if (item.kind === "calc") {
            // wl-copy stays alive to own the selection — it must not live in
            // a cgroup that dies with the shell, and the answer may contain
            // quotes.
            Hypr.exec(`printf '%s' ${root.shq(`${item.payload}`)} | wl-copy`);
        }
    }

    FileView {
        id: usageFile

        path: root.usagePath
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text()) ?? {};
                root.usage = parsed;
                root.pinned = Array.isArray(parsed?.__pinned) ? parsed.__pinned : [];
                delete root.usage.__pinned;
            } catch (e) {
                root.usage = {};
                root.pinned = [];
            }
        }
        onLoadFailed: {
            root.usage = ({});
            root.pinned = [];
        }
    }
}
