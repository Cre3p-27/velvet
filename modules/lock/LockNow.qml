//  VELVET  ·  modules/lock/LockNow.qml
//  What is playing, as plain data for a face to dress. Loaded by path from the
//  faces, so a Quickshell built without the MPRIS service costs a face its
//  music line and nothing else.
import qs.config
import qs.services
import Quickshell.Services.Mpris
import QtQuick

Item {
    id: root

    readonly property var player: {
        if (Lyrics.bridge)
            return Lyrics.bridge.player;
        const list = Mpris.players?.values ?? [];
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        return list.length > 0 ? list[0] : null;
    }

    readonly property string title: root.player?.trackTitle ?? ""
    readonly property string artist: root.player?.trackArtist ?? ""
    readonly property bool playing: root.player?.isPlaying ?? false
    readonly property bool any: root.title.length > 0

    width: 0
    height: 0
}
