//  VELVET  ·  services/Dispatch.qml
//  Talking to Hyprland, and checking that it listened.
//
//  Hyprland speaks two dialects over one socket. With a hyprland.conf a
//  dispatch is `focuswindow address:0x…`; with a hyprland.lua that exact
//  string is REJECTED and it wants `hl.dsp.focus({ window = "address:0x…" })`
//  instead. Guessing which one from the filename is what left half of this
//  shell's buttons dead — a wrong guess raises no error anywhere the shell can
//  see it. It just quietly does nothing, forever.
//
//  So nothing guesses any more:
//    · the dialect is PROBED once, with a harmless dispatch;
//    · every one-shot action goes through act(), which reads Hyprland's reply
//      and retries in the other dialect if the answer was not "ok";
//    · the first successful retry is remembered for the rest of the session.
//
//  This lives apart from Hypr.qml on purpose. It is the newest and most
//  involved machinery in the shell, and a QML file that fails to load does not
//  say so where you are looking — it registers its name and answers with
//  nothing on it. Keeping it in its own file means a failure here costs
//  dispatch and nothing else, and the log names the file.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ════════════════════════════════════════════════════════════ the dialect
    //  0 = not probed yet · 1 = classic strings · 2 = lua expressions
    property int dialect: 0
    property bool luaDetected: false
    property string lastReply: ""
    property bool unpinned: false

    readonly property bool usingLua: {
        const forced = Config.hypr.luaDispatch;
        if (forced === "lua")
            return true;
        if (forced === "classic")
            return false;
        if (root.dialect === 1)
            return false;
        if (root.dialect === 2)
            return true;
        return root.luaDetected;
    }

    readonly property string dialectName: {
        if (root.dialect === 1)
            return "CLASSIC";
        if (root.dialect === 2)
            return "LUA";
        return root.luaDetected ? "LUA (GUESSED)" : "CLASSIC (GUESSED)";
    }

    readonly property string status: {
        const bits = [`DISPATCH: ${root.dialectName}`];
        if (Config.hypr.luaDispatch !== "auto")
            bits.push(`PINNED TO ${Config.hypr.luaDispatch.toUpperCase()}`);
        if (root.lastReply && !root.lastReply.toLowerCase().startsWith("ok"))
            bits.push(`LAST ERROR: ${root.lastReply.slice(0, 60).toUpperCase()}`);
        return bits.join("  ·  ");
    }

    // Which config file exists, as the opening guess. Only ever a guess: the
    // probe below overrules it a second later.
    Process {
        running: true
        command: ["bash", "-c", 'test -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua" && echo lua || echo conf']

        stdout: StdioCollector {
            onStreamFinished: root.luaDetected = text.trim() === "lua"
        }
    }

    // ─────────────────────────────────────────────────────────────── the probe
    //  `exec true` is the one dispatch that is both harmless and decisive:
    //  /bin/true opens no window and exits at once, and the dialect Hyprland
    //  does not speak answers with an error rather than with "ok".
    Timer {
        interval: 1400
        running: true
        onTriggered: {
            classicProbe.running = false;
            classicProbe.running = true;
        }
    }

    Process {
        id: classicProbe

        command: ["hyprctl", "dispatch", "exec", "true"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().toLowerCase().startsWith("ok")) {
                    root.dialect = 1;
                    return;
                }
                luaProbe.running = false;
                luaProbe.running = true;
            }
        }
    }

    Process {
        id: luaProbe

        command: ["hyprctl", "dispatch", 'hl.dsp.exec_cmd("true")']

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().toLowerCase().startsWith("ok"))
                    root.dialect = 2;
            }
        }
    }

    // ══════════════════════════════════════════════════════ verified dispatch
    //  One job at a time, and the job in flight is held OUT of the queue in
    //  `job`. That is not tidiness: while it lived at queue[0], a reply that
    //  arrived late — after the guard had given up on it — was applied to
    //  whatever job had moved into its place, cancelling that job's timeout,
    //  dropping it unrun, and blaming it for the first job's error.
    //
    //  There is no sequence number to go with that, because there does not
    //  need to be: the guard clears `job` FIRST and then kills the process, so
    //  an abandoned reply finds nothing to be attributed to and a dead process
    //  cannot answer later.
    property var queue: []
    property var job: null

    function act(classic: string, lua: string): void {
        if (!classic && !lua)
            return;
        // Only waiting jobs are ever trimmed — the one in flight is not here.
        const q = root.queue.length > 64 ? root.queue.slice(root.queue.length - 64) : root.queue;
        root.queue = q.concat([
            {
                c: classic,
                l: lua
            }
        ]);
        root.pump();
    }

    function pump(): void {
        if (root.job)
            return;
        while (root.queue.length > 0) {
            const next = root.queue[0];
            root.queue = root.queue.slice(1);
            if (!next.c && !next.l)
                continue;
            root.send({
                c: next.c,
                l: next.l,
                lua: root.usingLua,
                tried: 0
            });
            return;
        }
    }

    function send(j: var): void {
        const line = j.lua ? j.l : j.c;
        if (!line) {
            // Nothing to say in that dialect. Try the other one rather than
            // dropping the action on the floor.
            if (j.tried === 0) {
                root.send({
                    c: j.c,
                    l: j.l,
                    lua: !j.lua,
                    tried: 1
                });
                return;
            }
            root.job = null;
            root.pump();
            return;
        }

        root.job = j;

        // Stop first, then re-aim, then go: assigning a command to a process
        // that is still running is not guaranteed to take. `2>&1` because
        // hyprctl prints a rejected dispatcher on stderr, and an empty reply
        // is indistinguishable from silence — which is the exact failure this
        // file exists to end.
        runner.running = false;
        runner.command = ["bash", "-c", "hyprctl dispatch \"$1\" 2>&1", "velvet", line];
        runner.running = true;
        guard.restart();
    }

    function answered(reply: string): void {
        const j = root.job;
        // A reply for a job the guard already abandoned. It belongs to nobody.
        if (!j)
            return;

        guard.stop();
        root.job = null;

        const said = reply.trim();
        root.lastReply = said;

        if (said.toLowerCase().startsWith("ok")) {
            if (j.tried === 1)
                root.learn(!j.lua); // learn() wants the dialect that FAILED
            root.pump();
            return;
        }

        if (j.tried === 0) {
            // Same action, the other dialect. This is the self-healing step.
            root.send({
                c: j.c,
                l: j.l,
                lua: !j.lua,
                tried: 1
            });
            return;
        }

        root.complain(said || "REFUSED, AND SAID NOTHING");
        root.pump();
    }

    property string lastComplaint: ""

    function complain(said: string): void {
        if (said === root.lastComplaint)
            return;
        root.lastComplaint = said;
        Toast.warn(`HYPRLAND: ${said.slice(0, 70).toUpperCase()}`);
        quiet.restart();
    }

    // One of a kind of error is a message; forty is noise.
    Timer {
        id: quiet

        interval: 6000
        onTriggered: root.lastComplaint = ""
    }

    // The retry worked, so `wasLua` — the dialect that FAILED — was the wrong
    // one. Told which was tried rather than re-reading the belief, because the
    // belief can change between sending and hearing back.
    function learn(wasLua: bool): void {
        root.dialect = wasLua ? 1 : 2;

        // A hand-pinned style would keep overruling what we just proved, and
        // every action after this would pay two round trips. Unpin it and say
        // so — silently ignoring the setting would be worse.
        if (Config.hypr.luaDispatch !== "auto") {
            Config.set("hypr.luaDispatch", "auto");
            if (!root.unpinned) {
                root.unpinned = true;
                Toast.warn("DISPATCH STYLE WAS PINNED TO THE WRONG ONE — BACK TO AUTO");
            }
        }
    }

    Process {
        id: runner

        command: ["true"]

        stdout: StdioCollector {
            onStreamFinished: root.answered(text)
        }
    }

    // hyprctl not answering must not wedge everything behind it. `job` is
    // cleared BEFORE the process is killed, so the kill's own final reply
    // finds nothing to attach itself to.
    Timer {
        id: guard

        interval: 2500
        onTriggered: {
            root.job = null;
            runner.running = false;
            root.complain("NO ANSWER FROM HYPRCTL");
            root.pump();
        }
    }

    // Lua string literal, with the characters that would end it early escaped.
    function luaStr(s: string): string {
        let out = String(s);
        out = out.split("\\").join("\\\\");
        out = out.split('"').join('\\"');
        out = out.split("\n").join(" ");
        out = out.split("\r").join(" ");
        return '"' + out + '"';
    }
}
