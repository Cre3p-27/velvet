//  VELVET  ·  services/LoginSong.qml
//  A song from Spotify that starts when the session does. bin/velvet-autostart
//  does the work (wait, open Spotify if it is not running, fade in); this keeps
//  the chosen song and starts it once per login, from the settings' ON LOGIN page.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // named by the shell at start, so the singleton exists and the login start runs
    readonly property bool ready: true
    readonly property string script: Qt.resolvedUrl("../bin/velvet-autostart").toString().replace(/^file:\/\//, "")

    // the settings are read first: the song, the wait and the fade
    Timer {
        id: first

        interval: 800
        repeat: true
        running: true
        onTriggered: {
            if (!Config.loaded)
                return;
            first.stop();
            root.atLogin();
        }
    }

    function atLogin(): void {
        if (!Config.login.songOn || Config.login.song === "")
            return;
        start.command = [root.script, "run", Config.login.song, "--delay", String(Config.login.songDelay), "--fade", String(Config.login.songFade), "--once"];
        start.running = true;
    }

    // the login start: one per login (--once), and it logs what it did
    Process {
        id: start

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                Toast.show("COULD NOT START THE LOGIN SONG · SEE ~/.cache/velvet-autostart.log", "error", 7000);
        }
    }

    // SETTINGS → ON LOGIN → TAKE THE SONG PLAYING NOW: keep what Spotify plays
    function takeNow(): void {
        take.command = [root.script, "now"];
        take.running = true;
    }

    Process {
        id: take

        stdout: StdioCollector {
            onStreamFinished: {
                let info = null;
                try {
                    info = JSON.parse(text.trim());
                } catch (e) {
                    info = null;
                }
                if (!info || !info.uri) {
                    Toast.show(info && info.error ? info.error.toUpperCase() : "COULD NOT READ SPOTIFY", "error", 6000);
                    return;
                }
                const label = info.artist ? `${info.title} — ${info.artist}` : info.title;
                Config.setMany({
                    "login.song": info.uri,
                    "login.songTitle": label
                });
                Toast.show(`KEPT FOR THE LOGIN · ${label.toUpperCase()}`, "info", 4500);
            }
        }
    }

    // SETTINGS → ON LOGIN → PLAY THE KEPT SONG NOW: the same start, without the wait
    function playNow(): void {
        if (Config.login.song === "") {
            Toast.show("TAKE A SONG FIRST · PLAY IT IN SPOTIFY, THEN PRESS TAKE", "error", 6000);
            return;
        }
        play.command = [root.script, "run", Config.login.song, "--fade", String(Config.login.songFade)];
        play.running = true;
    }

    Process {
        id: play

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                Toast.show("SPOTIFY DID NOT PLAY THE SONG · SEE ~/.cache/velvet-autostart.log", "error", 7000);
        }
    }
}
