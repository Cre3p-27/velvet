//  VELVET  ·  services/Books.qml
//  Velly's book studio, the shell's side of it: the shelf (books.json), what
//  the studio does right now, whether the picture engine is there — and the
//  buttons: open the shelf, make one now, install the picture engine (in a
//  terminal you can watch and stop). The work itself is bin/velvet-books, at
//  night through bin/velvet-night (NightShift.qml). Settings → VELLY → BOOK STUDIO.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string helper: `${Qt.resolvedUrl("../bin/velvet-books")}`.replace(/^file:\/\//, "")
    readonly property string dir: `${Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")}/velvet`

    property var shelf: ({})
    property var engine: ({})
    property var now: ({})

    readonly property var books: root.shelf.books ?? []
    readonly property int ready: root.books.filter(b => b.state === "ready").length
    readonly property int making: root.books.filter(b => b.state === "working" || b.state === "waiting-engine").length
    readonly property int uploaded: root.books.filter(b => b.state === "uploaded").length
    readonly property bool busy: maker.running || `${root.now.doing ?? ""}`.length > 0

    readonly property string shelfLine: {
        if (root.books.length === 0)
            return "EMPTY · THE FIRST ONE COMES WITH THE NEXT NIGHT SHIFT";
        const parts = [];
        if (root.ready)
            parts.push(`${root.ready} READY TO UPLOAD`);
        if (root.making)
            parts.push(`${root.making} IN THE MAKING`);
        if (root.uploaded)
            parts.push(`${root.uploaded} ON KDP`);
        return parts.join(" · ") || `${root.books.length} BOOKS`;
    }
    readonly property string nowLine: {
        const d = `${root.now.doing ?? ""}`;
        if (d.length > 0)
            return `BOOK ${root.now.book ?? ""} · ${d.toUpperCase()}`;
        return maker.running ? "STARTING…" : "RESTING";
    }
    readonly property string engineLine: {
        if (root.engine.ok === true)
            return "READY · Z-IMAGE-TURBO";
        if (root.engine.missing_mb !== undefined)
            return `NOT INSTALLED · ~${(Number(root.engine.missing_mb) / 1000).toFixed(1)} GB, ONCE`;
        return "…";
    }

    FileView {
        path: `${root.dir}/books.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.shelf = JSON.parse(text());
            } catch (e) {}
        }
    }

    FileView {
        path: `${root.dir}/books-state.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.now = JSON.parse(text());
            } catch (e) {}
        }
    }

    Process {
        id: engineProbe

        command: ["python3", root.helper, "engine"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.engine = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    // the engine's state while the settings are open (it changes only by a download)
    Timer {
        running: Panels.settings
        interval: 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            engineProbe.running = false;
            engineProbe.running = true;
        }
    }

    function openShelf(): void {
        Quickshell.execDetached(["python3", root.helper, "shelf"]);
    }

    function openBook(id: string): void {
        Quickshell.execDetached(["python3", root.helper, "open", id]);
    }

    // MAKE ONE NOW: the next book, now (a game pauses it; it goes on at night)
    function makeNow(): void {
        if (maker.running) {
            Toast.show("VELLY IS ALREADY MAKING ONE", "info", 2600);
            return;
        }
        maker.running = true;
        Toast.show("VELLY STARTS THE NEXT BOOK · THE SHELF SAYS WHEN IT IS READY", "info", 3600);
    }

    Process {
        id: maker

        command: ["nice", "-n", "8", "python3", root.helper, "work", "--until-done"]
        onRunningChanged: {
            if (!running && root.ready > 0)
                Toast.show(`BOOK STUDIO · ${root.ready} READY TO UPLOAD`, "ok", 4200);
        }
    }

    // The download is yours to start and to watch: a terminal shows every file,
    // its source and its size first, and Ctrl+C stops it.
    function installEngine(): void {
        const cmd = `bash -c 'python3 "$0" engine setup; echo; read -r -p "Enter schließt das Fenster" _' ${root.helper}`;
        const line = Term.wrap("dev.velvet.books", "velvet-picture-engine", cmd, "");
        if (line)
            Quickshell.execDetached(["sh", "-c", line]);
        else
            Toast.show("NO TERMINAL FOUND · RUN: velvet-books engine setup", "warn", 6000);
    }

    readonly property bool started: true
}
