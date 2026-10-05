//  VELVET  ·  services/Tasks.qml
//  The workflow list: one source of truth for everything the shell knows
//  about your tasks. Configured in Super+Tab → WORKFLOW, checked off in the
//  Dynamic Island. Persisted to ~/.config/velvet/tasks.json.
//
//  Pinned tasks sort to the top of the open list — that is the whole point
//  of the pin: it survives reordering by hand, because there is none.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string path: `${Quickshell.env("HOME")}/.config/velvet/tasks.json`

    // Bumped on every change so every model binding that reads through it
    // re-evaluates. The island, the workflow pane, the bar — all of them
    // just bind to the lists and never think about persistence.
    property int revision: 0
    property int nextId: 1
    property var data: []          // { id, text, done, pinned, created }

    // Pinned first, then the order you added them. Done tasks live in their
    // own list — the island and the editor each decide how to show them.
    readonly property var open: {
        root.revision;
        return root.data.filter(t => !t.done).sort((a, b) => (b.pinned ? 1 : 0) - (a.pinned ? 1 : 0));
    }

    readonly property var finished: {
        root.revision;
        return root.data.filter(t => t.done);
    }

    readonly property int openCount: root.open.length
    readonly property int doneCount: root.finished.length
    readonly property real progress: root.data.length === 0 ? 0 : root.doneCount / root.data.length

    // The island pill's one-glance line.
    readonly property string pill: root.openCount === 0
        ? "ALL CLEAR"
        : `${root.openCount} OPEN${root.doneCount > 0 ? "  ·  " + root.doneCount + " DONE" : ""}`

    function find(id: int): int {
        for (let i = 0; i < root.data.length; i++)
            if (root.data[i].id === id)
                return i;
        return -1;
    }

    function byId(id: int): var {
        const i = root.find(id);
        return i >= 0 ? root.data[i] : null;
    }

    function bump(): void {
        root.revision++;
        root.persist();
    }

    // Returns the new task's id, or -1 when the text was empty.
    function add(text: string): int {
        const t = `${text ?? ""}`.trim();
        if (t.length === 0)
            return -1;
        const id = root.nextId;
        root.data = root.data.concat([{
            id: id,
            text: t,
            done: false,
            pinned: false,
            created: Date.now()
        }]);
        root.nextId = id + 1;
        root.bump();
        Sfx.select();
        return id;
    }

    function toggle(id: int): void {
        const i = root.find(id);
        if (i < 0)
            return;
        root.setDone(id, !root.data[i].done);
    }

    function setDone(id: int, done: bool): void {
        const i = root.find(id);
        if (i < 0 || root.data[i].done === done)
            return;
        const next = root.data.slice();
        next[i] = Object.assign({}, next[i], { done: done });
        root.data = next;
        root.bump();
        if (done) {
            // Finishing a task is the good direction — the achievement.
            if (Config.services.questToasts) {
                Sfx.quest();
                Toast.show(`QUEST COMPLETE  ·  ${next[i].text}`, "ok", 2800);
            } else {
                Sfx.toggle();
            }
        } else {
            Sfx.toggle();
        }
    }

    function rename(id: int, text: string): void {
        const i = root.find(id);
        const t = `${text ?? ""}`.trim();
        if (i < 0 || t.length === 0 || root.data[i].text === t)
            return;
        const next = root.data.slice();
        next[i] = Object.assign({}, next[i], { text: t });
        root.data = next;
        root.bump();
        Sfx.cursor();
    }

    function togglePin(id: int): void {
        const i = root.find(id);
        if (i < 0 || root.data[i].done)
            return;
        const next = root.data.slice();
        next[i] = Object.assign({}, next[i], { pinned: !next[i].pinned });
        root.data = next;
        root.bump();
        Sfx.cursor();
    }

    function remove(id: int): void {
        const i = root.find(id);
        if (i < 0)
            return;
        root.data = root.data.filter(t => t.id !== id);
        root.bump();
        Sfx.back();
    }

    function clearDone(): void {
        if (root.doneCount === 0)
            return;
        root.data = root.data.filter(t => !t.done);
        root.bump();
        Sfx.back();
    }

    function persist(): void {
        file.setText(JSON.stringify(root.data, null, 1));
    }

    FileView {
        id: file

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (Array.isArray(parsed)) {
                    const cleaned = parsed
                        .filter(t => t && typeof t === "object" && typeof t.text === "string" && t.text.trim().length > 0)
                        .map(t => ({
                            id: Number.isFinite(t.id) ? t.id : 0,
                            text: `${t.text}`.trim(),
                            done: !!t.done,
                            pinned: !!t.pinned,
                            created: Number.isFinite(t.created) ? t.created : 0
                        }));
                    // Ids must stay unique — the counter never goes backwards.
                    let max = 0;
                    for (let i = 0; i < cleaned.length; i++)
                        max = Math.max(max, cleaned[i].id);
                    root.nextId = max + 1;
                    root.data = cleaned;
                }
            } catch (e) {
                // A tasks.json that no longer parses must not take the shell
                // down with it — start empty, the next change rewrites it.
                console.warn("Velvet: tasks.json unreadable — starting fresh:", `${e}`);
                root.data = [];
            }
        }
    }

    // ------------------------------------------------------------------- ipc
    //   qs -c velvet ipc call tasks add "write the song"
    //   qs -c velvet ipc call tasks toggle 1
    //   qs -c velvet ipc call tasks list
    IpcHandler {
        target: "tasks"

        function add(text: string): void {
            root.add(text);
        }
        function toggle(id: int): void {
            root.toggle(id);
        }
        function remove(id: int): void {
            root.remove(id);
        }
        function list(): string {
            return root.data.map(t => `${t.id}\x1f${t.done ? 1 : 0}\x1f${t.text}`).join("\n");
        }
    }
}
