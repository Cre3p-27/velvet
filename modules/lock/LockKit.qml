//  VELVET  ·  modules/lock/LockKit.qml
//  The core every vibe's lock shares, so a face can be as different as it
//  likes and still take a password the proven way: an invisible TextInput that
//  hands the text to Locker on Enter, a shake and a sound when PAM says no, the
//  clock, the user's name, caps lock. A face reads this and draws it; it never
//  touches PAM itself.
import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    // true in the settings' picture: no input, no sounds, a made-up time
    property bool preview: false
    // the field itself, for whoever has to look inside (tests)
    property alias field: input

    // ── what a face draws
    readonly property int length: input.text.length
    readonly property string typed: input.text
    readonly property bool busy: Locker.busy && !root.preview
    readonly property bool failed: Locker.failed && !root.preview
    readonly property string message: root.preview ? "" : Locker.message
    readonly property int attempts: Locker.attempts
    readonly property bool testing: Locker.testing && !root.preview
    readonly property string user: Locker.user || "user"
    readonly property string name: Config.lock.greeting || root.user
    readonly property bool caps: Kbd.capsLock && !root.preview
    readonly property date now: root.preview ? new Date(2026, 9, 3, 9, 41, 27) : clock.date

    // ── what the user chose (LOCK SCREEN → VIBE FACES): every face reads these
    // instead of deciding for itself, so the clock, the date, the typing and the
    // little lines are the same options whatever the face looks like.
    readonly property bool h24: Config.lock.vClock === "24h" || (Config.lock.vClock !== "12h" && Config.bar.clock.format24h)
    readonly property bool seconds: Config.lock.vSeconds
    // × the face's own clock size
    readonly property real clockScale: Math.max(0.4, Config.lock.vScale)
    readonly property string mask: Config.lock.vMask
    readonly property string hello: Config.lock.vHello
    readonly property bool showUser: Config.lock.vUser
    readonly property bool showInfo: Config.lock.vInfo
    readonly property bool hints: Config.lock.vHints

    function stamp(fmt: string): string {
        return Qt.formatDateTime(root.now, fmt);
    }
    // 09:41 in 24h, 9:41 in 12h
    readonly property string hh: root.h24 ? root.stamp("HH") : String(parseInt(root.stamp("h")))
    readonly property string mm: root.stamp("mm")
    readonly property string ss: root.stamp("ss")
    readonly property string ampm: root.h24 ? "" : root.stamp("AP")
    // the clock as one string: 09:41, 09:41:27, 9:41 PM …
    readonly property string clockText: `${root.hh}:${root.mm}${root.seconds ? ":" + root.ss : ""}${root.ampm !== "" ? " " + root.ampm : ""}`
    // The same with the hours padded (the pixel and dot-matrix clocks need two).
    readonly property string clockPadded: `${root.hh.padStart(2, "0")}:${root.mm}${root.seconds ? ":" + root.ss : ""}`
    // The date line in the user's format. `own` is what the face would write
    // by itself (its voice: capitals, ordinals …); it is kept when the user
    // left the format on LONG, and replaced by their choice otherwise.
    function date(own: string): string {
        switch (Config.lock.vDate) {
        case "off":
            return "";
        case "short":
            return root.stamp("ddd d MMM");
        case "numeric":
            return root.stamp("dd.MM.yyyy");
        default:
            return own;
        }
    }
    readonly property string dateLong: root.date(root.stamp("dddd, d MMMM"))

    // the small lines under the clock: battery · network, the song, the weather
    readonly property string infoLine: root.preview ? "87%  ·  Wired" : `${Battery.available ? Battery.percent + "%" + (Battery.charging ? " +" : "") + "  ·  " : ""}${Net.label || "Offline"}`
    readonly property string mediaLine: !Config.lock.vMedia ? "" : (root.preview ? "Daft Punk — Digital Love" : (Lyrics.title !== "" ? `${Lyrics.artist !== "" ? Lyrics.artist + " — " : ""}${Lyrics.title}` : ""))
    readonly property string weatherLine: !Config.lock.vWeather ? "" : (root.preview ? "21°  Overcast" : (Weather.ready ? `${Weather.short}  ${Weather.description}` : ""))

    // The clock's colour and typeface: the look's own, or the user's
    // (LOCK SCREEN → VIBE FACES → CLOCK COLOUR / CLOCK FONT).
    function tint(own: color): color {
        switch (Config.lock.vClockColour) {
        case "accent":
            return Colours.accent;
        case "ink":
            return Colours.ink;
        case "white":
            return "#ffffff";
        case "black":
            return "#101010";
        case "alt":
            return Colours.accentAlt;
        default:
            return own;
        }
    }
    function typeface(own: string): string {
        return Config.lock.vClockFont !== "" ? Config.lock.vClockFont : own;
    }

    // How blurred and how dark the wallpaper is: the user's number, or the face's own.
    function blurOr(own: real): real {
        const v = parseFloat(Config.lock.vBlur);
        return isNaN(v) ? own : Math.max(0, Math.min(1, v));
    }
    function dimOr(own: real): real {
        const v = parseFloat(Config.lock.vDim);
        return isNaN(v) ? own : Math.max(0, Math.min(0.97, v));
    }

    // the shake of a rejection, in px, and the recoil of whatever holds the field
    property real shake: 0
    property real recoil: 1

    // the picture of the user: ~/.face when it exists
    readonly property string faceUrl: `file://${Quickshell.env("HOME") ?? ""}/.face`
    property bool hasFace: false

    function focusInput(): void {
        input.forceActiveFocus();
    }
    function clear(): void {
        input.text = "";
    }
    function submit(): void {
        if (root.preview)
            return;
        Locker.submit(input.text, "");
        input.text = "";
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    FileView {
        path: root.faceUrl.replace("file://", "")
        printErrors: false
        onLoaded: root.hasFace = true
        onLoadFailed: root.hasFace = false
    }

    // The invisible field every face types into. Esc empties it.
    TextInput {
        id: input

        width: 1
        height: 1
        opacity: 0
        focus: !root.preview
        enabled: !Locker.busy && !root.preview
        echoMode: TextInput.Password
        maximumLength: 128

        onAccepted: root.submit()
        Keys.onEscapePressed: input.text = ""

        Component.onCompleted: {
            if (!root.preview)
                input.forceActiveFocus();
        }
    }

    // A wrong password shakes whatever the face attaches `shake` to, and
    // gives the field a little punch.
    SequentialAnimation {
        id: shakeAnim

        NumberAnimation { target: root; property: "shake"; to: -20; duration: 45 }
        NumberAnimation { target: root; property: "shake"; to: 16; duration: 55 }
        NumberAnimation { target: root; property: "shake"; to: -8; duration: 45 }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: 60 }
    }
    SequentialAnimation {
        id: punch

        NumberAnimation { target: root; property: "recoil"; to: 0.965; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "recoil"; to: 1; duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }

    // a signal faces can connect to for their own flash
    signal rejected

    // The field is disabled while PAM thinks, and a disabled item loses the
    // keyboard: take it back the moment PAM has answered.
    Connections {
        target: Locker
        enabled: !root.preview

        function onBusyChanged(): void {
            if (!Locker.busy)
                input.forceActiveFocus();
        }
    }

    Connections {
        target: Locker
        enabled: !root.preview

        function onShake(): void {
            shakeAnim.restart();
            punch.restart();
            Sfx.back();
            root.rejected();
        }
    }
}
