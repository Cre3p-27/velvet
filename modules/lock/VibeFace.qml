//  VELVET  ·  modules/lock/VibeFace.qml
//  The lock of the VIBES: one face per settings skin (a terminal login, a game's
//  PRESS START, a HUD, a newspaper front page, frosted glass, a tome, a poster,
//  a quiet clock, the logon screens of Windows 95 to 11, a painted wall).
//  The password half is LockKit (the same proven input every lock uses); each
//  face is only a different way to draw it. A face that fails to load leaves the
//  plain one below — you can always get back in.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: face

    property bool preview: false
    property alias core: kit

    readonly property string skin: Appearance.skin
    readonly property string file: ({
            console: "LockConsole.qml",
            arcade: "LockArcade.qml",
            hud: "LockHud.qml",
            ledger: "LockLedger.qml",
            glass: "LockGlass.qml",
            tome: "LockTome.qml",
            poster: "LockPoster.qml",
            clean: "LockClean.qml",
            win: "LockWin.qml"
        })[face.skin] ?? "LockGlass.qml"

    // the whole face arrives and leaves as one
    property real reveal: face.preview ? 1 : 0

    // LOCK SCREEN → ENTRANCE: fade | rise | zoom | drop | slam | glitch | none
    readonly property string entrance: Config.lock.vEntrance

    opacity: face.entrance === "glitch" ? (face.reveal < 1 ? (Math.floor(face.reveal * 14) % 3 === 1 ? 0.15 : face.reveal) : 1) : face.reveal
    scale: face.entrance === "zoom" ? 0.93 + 0.07 * face.reveal : (face.entrance === "slam" ? 1.18 - 0.18 * face.reveal : 1)
    transformOrigin: Item.Center
    transform: Translate {
        x: face.entrance === "glitch" && face.reveal < 1 ? (Math.floor(face.reveal * 23) % 2 === 0 ? 1 : -1) * (1 - face.reveal) * 26 : 0
        y: face.entrance === "rise" ? (1 - face.reveal) * face.height * 0.045 : (face.entrance === "drop" ? -(1 - face.reveal) * face.height * 0.12 : 0)
    }

    NumberAnimation {
        id: arrive

        target: face
        property: "reveal"
        to: 1
        duration: face.entrance === "none" ? 0 : (face.entrance === "fade" ? 420 : (face.entrance === "slam" ? 300 : (face.entrance === "glitch" ? 520 : 600)))
        easing.type: face.entrance === "drop" ? Easing.OutBack : (face.entrance === "slam" ? Easing.OutQuart : (face.entrance === "glitch" ? Easing.Linear : Easing.OutCubic))
        easing.overshoot: 1.6
    }
    NumberAnimation {
        id: leave

        target: face
        property: "reveal"
        to: 0
        duration: face.entrance === "none" ? 90 : 170
        easing.type: Easing.InQuad
        onFinished: Locker.exitDone()
    }

    // the settings' "play the entrance"
    function restartEntrance(): void {
        arrive.stop();
        leave.stop();
        face.reveal = 0;
        arrive.start();
    }

    Component.onCompleted: {
        if (!face.preview)
            arrive.start();
        else
            Spectrum.lockPreview = true;
    }
    Component.onDestruction: {
        if (face.preview)
            Spectrum.lockPreview = false;
    }

    // the settings' picture plays a newly picked entrance by itself
    Connections {
        target: Config.lock
        enabled: face.preview

        function onVEntranceChanged(): void {
            face.restartEntrance();
        }
    }
    Connections {
        target: Locker
        enabled: !face.preview

        function onReleasingChanged(): void {
            if (Locker.releasing) {
                arrive.stop();
                leave.start();
            }
        }
    }

    LockKit {
        id: kit

        preview: face.preview
    }

    Loader {
        id: ld

        anchors.fill: parent
        asynchronous: false

        function load(): void {
            ld.setSource(face.file, { kit: kit });
        }
        Component.onCompleted: ld.load()
    }
    Connections {
        target: face

        function onFileChanged(): void {
            ld.load();
        }
    }

    // ── the look's atmosphere and its music (LOCK SCREEN → VIBE FACES)
    SpectrumEdge {
        anchors.fill: parent
        z: 5
        running: Config.lock.vViz && (face.preview || Locker.locked)
        edge: Config.lock.vVizEdge
        style: Config.lock.vVizStyle
        reach: (edge === "left" || edge === "right" ? face.width : face.height) * Math.max(0.04, Config.lock.vVizReach)
        // under the words in weight: the face stays readable over it
        strength: 0.55
        demo: face.preview
        barPitch: 14 * Math.max(0.5, Math.min(face.width / 1920, face.height / 1080))
        barFill: 0.6
    }
    LockFx {
        anchors.fill: parent
        z: 6
        kind: Config.lock.vFx
        glow: Config.lock.vGlow
        strength: Math.max(0.2, Config.lock.vFxStrength)
        running: face.visible && face.reveal > 0
    }

    // ── the plain face under everything: it only shows when a face did not load
    Item {
        anchors.fill: parent
        visible: ld.status !== Loader.Ready

        Rectangle {
            anchors.fill: parent
            color: Colours.paper
        }
        Column {
            anchors.centerIn: parent
            spacing: 18

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: `${kit.hh}:${kit.mm}`
                color: Colours.ink
                font.pixelSize: 120
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: kit.failed ? (kit.message || "WRONG PASSWORD") : (kit.busy ? "CHECKING…" : `${kit.name.toUpperCase()} — ENTER PASSWORD`)
                color: kit.failed ? Colours.danger : Colours.inkDim
                font.pixelSize: 18
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                x: kit.shake

                Repeater {
                    model: Math.min(kit.length, 24)

                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: Colours.accent
                    }
                }
            }
        }
    }

    // ── what every face shares
    // a click anywhere puts the cursor back in the field
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !face.preview
        onClicked: kit.focusInput()
    }

    Rectangle {
        visible: kit.testing
        anchors.horizontalCenter: parent.horizontalCenter
        y: face.height * 0.04
        width: testText.implicitWidth + 40
        height: 40
        radius: 20
        color: Colours.warning
        z: 20

        P5Text {
            id: testText

            anchors.centerIn: parent
            text: "TEST — RELEASES ITSELF IN 20 SECONDS"
            color: "#10131a"
            font.pixelSize: 13
            font.weight: Font.Bold
            tracking: 1.4
        }
    }

    // the way out, spelled once you have got stuck
    P5Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        z: 20
        visible: !face.preview && (Locker.attempts >= 3 || Locker.pamErrors > 0)
        text: `${Locker.pamConfig ? "PAM: " + Locker.pamConfig + "   ·   " : ""}STUCK?  CTRL+ALT+F2  ·  LOG IN  ·  loginctl unlock-session`
        color: Colours.alpha(Colours.inkDim, 0.8)
        font.family: Appearance.fontFamily.mono
        font.pixelSize: 12
    }
}
