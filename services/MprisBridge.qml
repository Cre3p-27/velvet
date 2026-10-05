//  VELVET  ·  services/MprisBridge.qml
//  The only ALWAYS-LOADED file that imports Quickshell.Services.Mpris. The bar's
//  Media entry and the lock screen's media strip import it too, but both of
//  those are reached through a path Loader, so a build without MPRIS loses
//  those two widgets rather than the shell.
//
//  Quickshell's service modules are build-time options, and a singleton that
//  imports a missing one does not degrade — it takes the whole shell down at
//  load. Lyrics is instantiated at startup, so the import cannot live there.
//  It lives here instead, and Lyrics creates this file with Qt.createComponent:
//  if the module is absent, creation fails, the failure is caught, and you get
//  a lyrics panel that says so rather than a desktop that will not start.
//
//  Same trick as LockAuth.qml does for PAM, for the same reason.
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

QtObject {
    id: root

    // The player the shell talks to — the one that STARTED playing most
    // recently, and it keeps the seat when you pause it. "Whatever is playing
    // wins" was not enough: a browser tab reports Playing all day, so the
    // moment you paused Spotify the controls went to Chrome and play never
    // came back. A player only takes the seat by starting to play.
    property MprisPlayer last: null

    readonly property MprisPlayer playingNow: {
        const list = Mpris.players?.values ?? [];
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying && (list[i].trackTitle ?? "") !== "")
                return list[i];
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        return null;
    }

    // Every player's start, watched: the one that begins playing sits down.
    property Instantiator _starts: Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property MprisPlayer modelData

            target: modelData
            function onIsPlayingChanged(): void {
                if (modelData.isPlaying)
                    root.last = modelData;
            }
        }
    }

    // Whatever was already playing when the shell started is "last" too.
    property Timer _seed: Timer {
        interval: 300
        running: true
        onTriggered: {
            if (root.playingNow && !root.last)
                root.last = root.playingNow;
        }
    }

    // A player that can still be driven. A browser tab that played something
    // once keeps its MPRIS entry after the video is gone — with canPlay and
    // canGoNext false, so every button on it only produced a warning.
    function usable(p: MprisPlayer): bool {
        return p !== null && p.canControl && (p.isPlaying || p.canPlay || p.canTogglePlaying);
    }

    readonly property MprisPlayer player: {
        const list = Mpris.players?.values ?? [];
        for (let i = 0; i < list.length; i++)
            if (list[i] === root.last && root.usable(list[i]))
                return list[i];
        if (root.playingNow)
            return root.playingNow;
        for (let i = 0; i < list.length; i++)
            if ((list[i].trackTitle ?? "") !== "" && root.usable(list[i]))
                return list[i];
        for (let i = 0; i < list.length; i++)
            if (root.usable(list[i]))
                return list[i];
        return list.length > 0 ? list[0] : null;
    }

    readonly property bool canNext: root.player?.canGoNext ?? false
    readonly property bool canPrev: root.player?.canGoPrevious ?? false

    readonly property bool has: root.player !== null
    readonly property string title: root.player?.trackTitle ?? ""
    readonly property string artist: root.player?.trackArtist ?? ""
    readonly property string album: root.player?.trackAlbum ?? ""
    readonly property real length: root.player?.length ?? 0
    readonly property bool playing: root.player?.isPlaying ?? false
    readonly property string artUrl: root.player?.artUrl ?? ""

    // Asked only of a player that can do it — Quickshell warns (and does
    // nothing) otherwise.
    function toggle(): void {
        const p = root.player;
        if (p && p.canTogglePlaying)
            p.togglePlaying();
    }
    function next(): void {
        const p = root.player;
        if (p && p.canGoNext)
            p.next();
    }
    function prev(): void {
        const p = root.player;
        if (p && p.canGoPrevious)
            p.previous();
    }

    // MPRIS position is a poll, not a stream: asking for it is a D-Bus round
    // trip, so the caller decides how often that happens.
    function position(): real {
        const p = root.player;
        if (!p)
            return 0;
        p.positionChanged();
        return p.position ?? 0;
    }

    // Jump to a point in the track. Only when the player lets us: writing
    // position on a player without canSeek is a no-op at best, a D-Bus
    // error at worst.
    function seek(frac: real): void {
        const p = root.player;
        if (!p || !p.canSeek || !(p.length > 0))
            return;
        p.position = Math.max(0, Math.min(1, frac)) * p.length;
    }
}
