//  VELVET  ·  services/Locker.qml
//  Lock state and policy. The PAM half lives in LockAuth.qml and is created
//  dynamically, so a Quickshell built without PAM support gives us an error
//  string to show rather than a service that silently fails to exist.
//
//  The rules, in order of how badly breaking them would hurt:
//
//    1. Never enter the locked state until PAM has answered a prompt here.
//    2. Never hand over to a locker that is not installed. `loginctl
//       lock-session` with no locker running locks the session and draws
//       nothing — a black screen with no way back in.
//    3. Never fail silently. If locking cannot happen, say so on screen.
//    4. TEST LOCK releases itself after twenty seconds, whatever happens.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool locked: false
    // The look is latched when the lock starts: changing it while locked must
    // not destroy the live session lock (that would leave the compositor
    // locked with nothing to unlock it).
    property string lockLook: root.resolve(Config.lock.look)

    // "vibe" is the lock of whatever vibe is on; the house look (persona) has
    // none of its own, so it wears the SOFT one.
    function resolve(look: string): string {
        if (look === "vibe")
            return Config.appearance.skin === "persona" ? "soft" : "vibe";
        return look;
    }
    // the face that is up, or the one that will be
    readonly property string face: root.locked ? root.lockLook : root.resolve(Config.lock.look)
    property bool testing: false
    // True for the beat between a correct password and the screen letting
    // go — the lock plays its morph-back during this window.
    property bool releasing: false
    property bool busy: false
    // What a correct password does besides unlocking: "" (just unlock),
    // or "poweroff" / "reboot" / "logout" — the lock's power buttons. The
    // action runs only after PAM has accepted the password, and the screen
    // stays locked while it does (a test lock only says what it would do).
    property string then: ""
    property bool failed: false
    property int attempts: 0
    property int pamErrors: 0
    property string message: ""

    // 0 = untested, 1 = working, -1 = unavailable
    property int pamState: 0
    property string pamConfig: ""
    property string pamError: ""
    property string externalLocker: ""

    // Every PAM service on this machine that could plausibly authenticate you,
    // best first. The old code picked the first one that existed and gave up if
    // it did not answer — which is exactly what happens when install.sh could
    // not write /etc/pam.d/velvet, or wrote one that includes a stack this
    // distro does not have. Now a refusal just moves to the next candidate, so
    // "nothing happened" turns into "it used hyprlock's stack instead".
    property var candidates: []
    property int candidate: 0
    property var rejected: []

    // Set once LockAuth.qml has been created successfully.
    property var authObj: null
    readonly property bool authLoaded: authObj !== null

    readonly property bool pamReady: pamState === 1 && authLoaded
    readonly property bool hasExternal: externalLocker !== ""
    readonly property bool builtinWanted: Config.lock.useBuiltin
    readonly property bool canLock: (builtinWanted && pamReady) || hasExternal

    readonly property string user: Quickshell.env("USER") ?? ""

    readonly property string status: {
        if (!root.authLoaded && root.pamError !== "")
            return `PAM UNAVAILABLE IN THIS QUICKSHELL BUILD${root.hasExternal ? " — WILL USE " + root.externalLocker.toUpperCase() : " AND NO EXTERNAL LOCKER"}`;
        if (!root.builtinWanted)
            return root.hasExternal ? `EXTERNAL — ${root.externalLocker.toUpperCase()}` : "NO LOCKER — LOCKING IS DISABLED";
        if (root.pamState === 0)
            return "CHECKING PAM…";
        if (root.pamState === 1)
            return `READY — VELVET'S LOCK, PAM SERVICE "${root.pamConfig}"`;
        const tried = root.rejected.length > 0 ? `  ·  TRIED ${root.rejected.join(", ")}` : "";
        return (root.hasExternal ? `PAM REFUSED — WILL USE ${root.externalLocker.toUpperCase()}` : "PAM REFUSED AND NO EXTERNAL LOCKER") + tried;
    }

    signal shake

    // ------------------------------------------------------------------ lock
    function lock(): void {
        if (root.locked) {
            // A real lock arriving during TEST LOCK must not be released by
            // the test's 20 s timer.
            if (root.testing) {
                root.testing = false;
                testTimeout.stop();
            }
            return;
        }

        if (root.builtinWanted && root.pamReady) {
            root.beginLock(false);
            return;
        }

        if (root.hasExternal) {
            Toast.show(`Locking with ${root.externalLocker.split(" ")[0]}`, "info");
            external.running = false;
            external.running = true;
            return;
        }

        // Refusing loudly beats blanking the screen.
        Toast.show(root.authLoaded ? "Nothing can lock this session — see SHELL → LOCK SCREEN" : "PAM is not available in this Quickshell build — install hyprlock", "error", 7000);
    }

    // Locks, then lets go by itself. The safe way to find out whether this
    // machine can do it at all.
    function testLock(): void {
        if (root.locked)
            return;
        if (!root.pamReady) {
            Toast.show(root.status, "error", 7000);
            return;
        }
        if (!root.builtinWanted) {
            Toast.show("TURN ON USE VELVET'S LOCK FIRST — NOTHING WOULD BE DRAWN", "error", 7000);
            return;
        }
        root.beginLock(true);
    }

    function beginLock(isTest: bool): void {
        root.message = "";
        root.failed = false;
        root.attempts = 0;
        root.pamErrors = 0;
        root.testing = isTest;
        root.lockLook = root.resolve(Config.lock.look);
        // Velly's ears and hands must not stay live behind the lock.
        if (Velly.active)
            Velly.sleep();
        root.locked = true;
        if (isTest)
            testTimeout.restart();
    }

    // The graceful exit: the password was right, so the lock gets the time
    // its choreography needs — the fluid lock's card shrinks back to the lock
    // mark, the icon returns and the background fades — before the screen
    // lets go.
    function release(): void {
        root.releasing = true;
        // While the lock still covers the screen, drop the open windows to
        // full transparency — the reveal will fade them back up to the
        // configured opacity instead of letting them pop in.
        root.fadeWindowsOut();
        releaseTimer.restart();
    }

    // The desktop's fade-in: windows ride the lock's exit at opacity 0 and
    // rise back to their configured values on the beat the screen lets go.
    function fadeWindowsOut(): void {
        if (!Config.hypr.unlockFade || !Config.hypr.animations)
            return;
        // This Hyprland speaks Lua: `hyprctl eval` + hl.config applies
        // live and is animated by the fade leaf. The keyword fallback
        // covers builds where eval is unavailable.
        fadeDrop.command = ["bash", "-c", `hyprctl eval 'hl.config({ decoration = { active_opacity = 0, inactive_opacity = 0 } })' >/dev/null 2>&1 || { hyprctl keyword decoration:active_opacity 0 >/dev/null 2>&1; hyprctl keyword decoration:inactive_opacity 0 >/dev/null 2>&1; }`];
        fadeDrop.running = false;
        fadeDrop.running = true;
    }

    function fadeWindowsBack(): void {
        if (!Config.hypr.unlockFade || !Config.hypr.animations)
            return;
        const ao = Config.hypr.activeOpacity;
        const io = Config.hypr.inactiveOpacity;
        // The windows climb back in steps instead of one jump: every beat
        // sets an eased value and Hyprland's fade leaf smooths the steps
        // into one slow rise — about 1 s from 0 up to the configured
        // opacity. The trailing re-applies are the rescue lines.
        let cmd = "";
        const steps = 14;
        for (let i = 1; i <= steps; i++) {
            const t = i / steps;
            const e = 1 - Math.pow(1 - t, 2.2);
            cmd += `hyprctl eval 'hl.config({ decoration = { active_opacity = ${(e * ao).toFixed(2)}, inactive_opacity = ${(e * io).toFixed(2)} } })' >/dev/null 2>&1; sleep 0.06; `;
        }
        cmd += `hyprctl eval 'hl.config({ decoration = { active_opacity = ${ao.toFixed(2)}, inactive_opacity = ${io.toFixed(2)} } })' >/dev/null 2>&1 || { hyprctl keyword decoration:active_opacity ${ao.toFixed(2)} >/dev/null 2>&1; hyprctl keyword decoration:inactive_opacity ${io.toFixed(2)} >/dev/null 2>&1; }; sleep 2.5; hyprctl eval 'hl.config({ decoration = { active_opacity = ${ao.toFixed(2)}, inactive_opacity = ${io.toFixed(2)} } })' >/dev/null 2>&1 || { hyprctl keyword decoration:active_opacity ${ao.toFixed(2)} >/dev/null 2>&1; hyprctl keyword decoration:inactive_opacity ${io.toFixed(2)} >/dev/null 2>&1; }`;
        fadeRestore.command = ["bash", "-c", cmd];
        fadeRestore.running = false;
        fadeRestore.running = true;
    }

    Process {
        id: fadeDrop
        command: ["true"]
    }

    Process {
        id: fadeRestore
        command: ["true"]
    }

    Timer {
        id: fadeRestoreTimer

        // The surface needs a beat to actually let go after unlock(); the
        // windows rise as the desktop appears.
        interval: 180
        onTriggered: root.fadeWindowsBack()
    }

    // The exit choreography IS the unlock: when the lock's surface has
    // played its animation out, it calls this and the screen lets go on
    // the beat — no dead frame, no grey pause between animation and
    // desktop. The timer below is only the rescue line if that signal
    // never comes.
    function exitDone(): void {
        if (root.releasing)
            root.unlock();
    }

    Timer {
        id: releaseTimer

        // The fallback window: generous enough for the longest exit
        // (the vortex at double speed), and normally never reached —
        // the surface's onFinished signal unlocks first.
        interval: {
            const ms = Config.lock.animation === "morph" ? 1 : Math.max(0.25, Math.min(2, Config.lock.animationScale));
            return 1500 * ms;
        }
        onTriggered: root.unlock()
    }

    function unlock(): void {
        if (root.authObj)
            root.authObj.abort();
        testTimeout.stop();
        authTimeout.stop();
        releaseTimer.stop();
        bail.stop();
        fadeRestoreTimer.restart();
        root.releasing = false;
        root.locked = false;
        root.testing = false;
        root.busy = false;
        root.failed = false;
        root.message = "";
    }

    function submit(password: string, then: string): void {
        if (root.busy || !root.locked || !root.authObj)
            return;
        if (password.length === 0) {
            root.shake();
            return;
        }
        root.then = then ?? "";

        root.busy = true;
        root.failed = false;
        root.message = "CHECKING";

        if (!root.authObj.authenticate(password)) {
            root.busy = false;
            root.giveUp("PAM WOULD NOT START");
            return;
        }
        authTimeout.restart();
    }

    function giveUp(reason: string): void {
        root.message = reason;
        bail.restart();
    }

    // --------------------------------------------------------- auth reactions
    Connections {
        target: root.authObj
        enabled: root.authObj !== null

        function onSucceeded(): void {
            authTimeout.stop();
            root.busy = false;
            root.failed = false;
            root.message = "";
            const act = root.then;
            root.then = "";
            // A guarded power button: the password was right, so do what
            // it asked — without unlocking first.
            if (act === "poweroff" || act === "reboot" || act === "logout") {
                const say = act === "poweroff" ? "POWERING OFF" : (act === "reboot" ? "RESTARTING" : "LOGGING OUT");
                if (root.testing) {
                    root.message = `TEST  ·  WOULD BE ${say}`;
                    root.release();
                    return;
                }
                root.message = say;
                if (act === "poweroff")
                    Actions.shutdown();
                else if (act === "reboot")
                    Actions.reboot();
                else
                    Actions.logout();
                return;
            }
            root.release();
        }

        function onRejected(): void {
            authTimeout.stop();
            root.busy = false;
            root.attempts++;
            root.failed = true;
            root.message = root.attempts === 1 ? "WRONG PASSWORD" : `WRONG PASSWORD  ·  ${root.attempts}`;
            root.shake();
            clearFail.restart();
        }

        function onErrored(reason: string): void {
            authTimeout.stop();
            root.busy = false;

            if (!root.locked) {
                // Came from the probe: this service exists but will not talk
                // to us. Move down the list rather than giving up on PAM.
                root.rejectCandidate(reason);
                return;
            }

            root.failed = true;
            root.pamErrors++;
            root.message = reason;
            root.shake();
            clearFail.restart();

            // Repeated *errors* are a broken setup, not a wrong password — an
            // attacker cannot produce these by guessing.
            if (root.pamErrors >= 4)
                root.giveUp("PAM KEEPS FAILING — HANDING OVER");
        }

        function onPrompted(): void {
            if (!root.locked) {
                root.pamState = 1;
                probeTimeout.stop();
                if (root.authObj)
                    root.authObj.abortProbe();
            }
        }

        function onNote(text: string): void {
            if (root.locked)
                root.message = text;
        }
    }

    Timer {
        id: clearFail
        interval: 1600
        onTriggered: root.failed = false
    }

    Timer {
        id: authTimeout
        interval: 12000
        onTriggered: {
            if (root.authObj)
                root.authObj.abort();
            root.busy = false;
            root.failed = true;
            root.pamErrors++;
            root.message = "PAM TIMED OUT";
            root.shake();
            if (root.pamErrors >= 3)
                root.giveUp("PAM IS NOT ANSWERING — HANDING OVER");
        }
    }

    Timer {
        id: testTimeout
        interval: 20000
        onTriggered: {
            if (root.testing)
                root.unlock();
        }
    }

    Timer {
        id: bail
        interval: 1200
        onTriggered: {
            root.unlock();
            if (root.hasExternal) {
                external.running = false;
                external.running = true;
            } else {
                Toast.show("Could not authenticate and no external locker is installed", "error", 8000);
            }
        }
    }

    Process {
        id: external
        command: ["bash", "-c", root.externalLocker]
    }

    // ------------------------------------------------------------- detection
    Process {
        id: detect

        running: true
        command: ["bash", "-c", `
            if [ "${Config.lock.pamConfig}" != "auto" ]; then
                echo "PAM ${Config.lock.pamConfig}"
            else
                for s in velvet hyprlock swaylock system-auth system-local-login login su; do
                    [ -f "/etc/pam.d/$s" ] && echo "PAM $s"
                done
            fi
            for l in hyprlock swaylock waylock gtklock; do
                command -v $l >/dev/null 2>&1 && { echo "LOCK $l"; break; }
            done
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split(String.fromCharCode(10));
                const found = [];
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].trim().split(" ");
                    if (parts[0] === "PAM" && parts[1])
                        found.push(parts[1]);
                    else if (parts[0] === "LOCK" && parts[1])
                        root.externalLocker = parts[1] === "swaylock" ? "swaylock -f" : parts[1];
                }
                root.candidates = found;
                root.candidate = 0;
                root.rejected = [];
                root.pamConfig = found.length > 0 ? found[0] : "";
                if (found.length === 0) {
                    root.pamState = -1;
                    root.pamError = "no PAM service found in /etc/pam.d";
                    return;
                }
                root.createAuth();
            }
        }
    }

    // ------------------------------------------------------- dynamic PAM load
    function createAuth(): void {
        if (root.authObj !== null || root.pamConfig === "")
            return;
        if (root.pamState === 1)
            return;

        const comp = Qt.createComponent(Qt.resolvedUrl("LockAuth.qml"), Component.PreferSynchronous);
        if (comp.status === Component.Error) {
            root.pamError = comp.errorString().trim();
            root.pamState = -1;
            console.warn("Velvet: PAM unavailable —", root.pamError);
            return;
        }

        const obj = comp.createObject(root, {
            service: root.pamConfig,
            username: root.user
        });
        if (!obj) {
            root.pamError = "LockAuth.qml could not be created";
            root.pamState = -1;
            return;
        }

        root.authObj = obj;
        root.selfTest();
    }

    function selfTest(): void {
        if (root.pamState === 1 || !root.authObj)
            return;
        root.pamState = 0;
        if (!root.authObj.probe()) {
            root.rejectCandidate("pam_start() refused");
            return;
        }
        probeTimeout.restart();
    }

    // This candidate cannot authenticate. Try the next one; only when the list
    // runs out is PAM genuinely unavailable.
    function rejectCandidate(why: string): void {
        probeTimeout.stop();
        const name = root.pamConfig;
        if (name && root.rejected.indexOf(name) === -1)
            root.rejected = root.rejected.concat([name]);

        if (root.authObj) {
            root.authObj.abortProbe();
            root.authObj.destroy();
            root.authObj = null;
        }

        if (root.candidate + 1 < root.candidates.length && Config.lock.pamConfig === "auto") {
            root.candidate = root.candidate + 1;
            root.pamConfig = root.candidates[root.candidate];
            root.pamState = 0;
            root.pamError = "";
            nextCandidate.restart();
            return;
        }

        root.pamState = -1;
        root.pamError = why;
    }

    // A beat between attempts, so a stack that refuses instantly cannot spin
    // through the whole list inside one frame.
    Timer {
        id: nextCandidate
        interval: 120
        onTriggered: root.createAuth()
    }

    Timer {
        id: probeTimeout
        interval: 3500
        onTriggered: {
            if (root.pamState === 0)
                root.rejectCandidate("PAM never reached a prompt");
        }
    }

    Connections {
        target: Config.lock

        function onPamConfigChanged(): void {
            // Rebuild against the new service.
            if (root.authObj) {
                root.authObj.destroy();
                root.authObj = null;
            }
            root.pamState = 0;
            root.pamError = "";
            detect.running = false;
            detect.running = true;
        }
    }

    // ------------------------------------------------------------- logind
    //  Suspend (lid, menu, idle daemon) arrives as logind's PrepareForSleep
    //  with `boolean true` on the next line — lock BEFORE the machine sleeps,
    //  so it wakes up locked. Stays listening while locked, so the printed
    //  escape (loginctl unlock-session) keeps working.
    property bool sleepHeader: false

    Process {
        running: Config.lock.listenToLogind && ((Config.lock.useBuiltin && root.pamReady) || root.locked)
        command: ["bash", "-c", "dbus-monitor --system \"type='signal',interface='org.freedesktop.login1.Session',member='Lock'\" \"type='signal',interface='org.freedesktop.login1.Session',member='Unlock'\" \"type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'\" 2>/dev/null"]

        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("member=PrepareForSleep") !== -1) {
                    root.sleepHeader = true;
                    return;
                }
                if (root.sleepHeader && line.indexOf("boolean") !== -1) {
                    root.sleepHeader = false;
                    if (line.indexOf("true") !== -1)
                        root.lock();
                    return;
                }
                if (line.indexOf("member=Lock") !== -1)
                    root.lock();
                else if (line.indexOf("member=Unlock") !== -1)
                    root.unlock();
            }
        }
    }

    // ------------------------------------------------------- lock on start
    // With SDDM auto-login the lock IS the login screen: lock the moment
    // PAM has proven itself, before the desktop has a chance to show.
    // The boot guard (uptime under two minutes) keeps a mid-session shell
    // restart from locking the screen out of the blue; startLocked stays
    // true so an unlock is never re-locked by this.
    property bool startLocked: false

    function tryStartLock(): void {
        if (!root.startLocked && root.pamReady) {
            root.startLocked = true;
            bootCheck.running = false;
            bootCheck.running = true;
        }
    }

    Connections {
        target: root

        function onPamReadyChanged(): void {
            if (Config.lock.lockOnStart && !root.locked)
                startLock.restart();
            if (root.pamReady && !root.locked) {
                relockCheck.running = false;
                relockCheck.running = true;
            }
        }
    }

    // ------------------------------------------------- back after a crash
    // While a real lock is up, a marker sits in the runtime folder. If the
    // shell dies under the lock, Hyprland keeps the screen locked
    // (misc:allow_session_lock_restore lets a new lock take over), and the
    // shell that velvet-session starts again finds the marker and puts the
    // lock straight back — instead of leaving a red "lock died" screen.
    readonly property string lockMarker: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/velvet-locked`
    readonly property bool realLock: root.locked && !root.testing

    onRealLockChanged: {
        if (root.realLock)
            Quickshell.execDetached(["touch", root.lockMarker]);
        else
            Quickshell.execDetached(["rm", "-f", root.lockMarker]);
    }

    Process {
        id: relockCheck

        command: ["test", "-e", root.lockMarker]
        onExited: code => {
            if (code === 0 && root.pamReady && !root.locked) {
                console.warn("Locker: the shell went down under the lock — locking again");
                root.lock();
            }
        }
    }

    Connections {
        target: root

        function onPamStateChanged(): void {
            if (Config.lock.lockOnStart && !root.locked && !root.startLocked && root.pamState === -1)
                Toast.show(`LOCK AT BOOT could not arm — ${root.pamError || "PAM unavailable"}`, "error", 9000);
        }
    }

    Connections {
        target: Config.lock

        function onLockOnStartChanged(): void {
            if (Config.lock.lockOnStart && !root.locked)
                startLock.restart();
        }
    }

    Timer {
        id: startLock
        interval: 600
        onTriggered: root.tryStartLock()
    }

    Process {
        id: bootCheck

        command: ["bash", "-c", "awk '$1 < 120 { print \"boot\"; exit } { print \"later\" }' /proc/uptime"]

        stdout: SplitParser {
            onRead: line => {
                if (line === "boot" && root.pamReady && !root.locked)
                    root.lock();
                else if (line === "later")
                    Toast.show("LOCK AT BOOT skipped — the machine did not just boot", "info", 6000);
            }
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
        function test(): void {
            root.testLock();
        }
        function unlock(): void {
            root.unlock();
        }
        function status(): string {
            return root.status + (root.pamError ? `  ·  ${root.pamError}` : "");
        }
        // For velvet-session's boot guard: is anything holding the screen?
        function state(): string {
            return root.locked || external.running ? "locked" : "open";
        }
    }
}
