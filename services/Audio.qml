//  VELVET  ·  services/Audio.qml
//  Pipewire volume/mute for the default sink and source.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property string sinkName: sink?.description ?? sink?.nickname ?? sink?.name ?? "No output"
    readonly property string sourceName: source?.description ?? source?.nickname ?? source?.name ?? "No input"

    readonly property int volumePercent: Math.round(volume * 100)

    signal volumeChangedByUser
    signal micChangedByUser

    // Media keys (wpctl), pavucontrol, anything: every volume change flashes
    // the OSD, as the README promises. Quiet for the first seconds and when
    // the default output itself changes, so start-up and switching never pop.
    property bool settled: false
    property string lastSink: ""

    Timer {
        running: true
        interval: 2500
        onTriggered: root.settled = true
    }

    function outside(): void {
        const now = root.sink?.name ?? "";
        if (now !== root.lastSink) {
            root.lastSink = now;
            return;
        }
        if (root.settled)
            root.volumeChangedByUser();
    }

    onVolumeChanged: root.outside()
    onMutedChanged: root.outside()

    function setVolume(value: real): void {
        if (!sink?.ready || !sink?.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(Config.services.volumeOverdrive, value));
        root.volumeChangedByUser();
    }

    function incrementVolume(): void {
        setVolume(volume + Config.services.volumeStep);
    }

    function decrementVolume(): void {
        setVolume(volume - Config.services.volumeStep);
    }

    function toggleMute(): void {
        if (!sink?.ready || !sink?.audio)
            return;
        sink.audio.muted = !sink.audio.muted;
        root.volumeChangedByUser();
    }

    function setMicVolume(value: real): void {
        if (!source?.ready || !source?.audio)
            return;
        source.audio.volume = Math.max(0, Math.min(1, value));
        root.micChangedByUser();
    }

    function toggleMicMute(): void {
        if (!source?.ready || !source?.audio)
            return;
        source.audio.muted = !source.audio.muted;
        root.micChangedByUser();
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
