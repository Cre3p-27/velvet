//  VELVET  ·  modules/island/IslandVelly.qml
//  Velly's body: the assistant as she looks inside the capsule.
//
//  Four states, four instruments — and the whole module is built so that one
//  glance tells you which one you are looking at:
//
//    READY      the orb breathes, the ring walks its slow lap.
//    LISTENING  twenty-eight radial bars ride your voice (bin/velvet-ears),
//               the core swells with every syllable, the header says so.
//    THINKING   the bars become a radar sweep, three motes orbit the core,
//               HUD brackets bite into the corners of the orb.
//    SPEAKING   the bars become lips: thirty-two buckets measured from the
//               audio she is actually playing, not guessed from the text.
//
//  Under the orb: the answer, typed at the speed it arrives. Under that:
//  the tools she used, as chips — the plain, visible answer to "what did she
//  just do". At the bottom: the input, exactly the pattern IslandTasks uses,
//  plus a mic chip that shows whether anyone is listening and lets you stop it
//  with one click.
//
//  Everything here reads services/Velly.qml and nothing else; the service owns
//  the processes, the session and the files.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    anchors.fill: parent

    readonly property int pad: 24
    readonly property string phase: Velly.phase
    readonly property bool livePhase: phase === "listening" || phase === "hearing" || phase === "thinking" || phase === "speaking"

    // The conversation as the answer area draws it: everything from memory,
    // minus the answer that is currently streaming in (it is drawn live).
    readonly property var log: {
        const out = [];
        const hist = Velly.history;
        const live = Velly.answer;
        const streaming = phase === "thinking" || phase === "speaking";
        for (let i = 0; i < hist.length - 1; i++)
            out.push(hist[i]);
        const last = hist.length > 0 ? hist[hist.length - 1] : null;
        if (last && !(streaming && last.role === "velly" && last.text === live))
            out.push(last);
        return out;
    }

    // ──────────────────────────────────────────────────────────────── header
    P5Text {
        id: wordmark

        x: root.pad
        y: 12
        display: true
        text: "VELLY"
        color: Colours.accent
        font.pixelSize: Appearance.font.size.title
        tracking: 2.4

        SequentialAnimation on opacity {
            running: root.livePhase
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.72
                duration: 900
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1.0
                duration: 900
                easing.type: Easing.InOutSine
            }
        }
    }

    // The state chip — the one word that says what she is doing.
    Plate {
        id: chip

        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.top: wordmark.top
        anchors.topMargin: 6
        width: chipText.implicitWidth + 26
        height: 24
        radius: Appearance.r(12)
        color: {
            if (root.phase === "error")
                return Colours.alpha(Colours.danger, 0.16);
            if (root.phase === "off")
                return Colours.alpha(Colours.ink, 0.08);
            return Colours.alpha(Colours.accent, root.livePhase ? 0.24 : 0.13);
        }
        border.width: 1
        border.color: {
            if (root.phase === "error")
                return Colours.alpha(Colours.danger, 0.7);
            if (root.phase === "off")
                return Colours.alpha(Colours.ink, 0.2);
            return Colours.alpha(Colours.accent, root.livePhase ? 0.85 : 0.45);
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        P5Text {
            id: chipText

            anchors.centerIn: parent
            display: true
            text: Velly.phaseLabel
            color: root.phase === "error" ? Colours.danger : Colours.accentInk
            font.pixelSize: Appearance.font.size.small
            tracking: 1.2
        }
    }

    // One quiet line about the machinery: what is thinking, what is listening.
    P5Text {
        x: root.pad
        y: 50
        width: parent.width - root.pad * 2
        text: {
            if (!Velly.brainOk)
                return Velly.brainSkills ? "SKILLS  ·  LOKALES GEHIRN FEHLT  ·  HALTEN → SETUP" : "KEIN GEHIRN  ·  HALTEN → SETUP";
            const ears = Velly.listening ? (Velly.micSource ? `MIC ${Velly.micSource.toUpperCase()}` : "MIC AN") : "MIC AUS";
            const voice = !Config.velly.voice ? "STIMME AUS" : (Velly.voiceAvailable && Velly.voiceEngine.length > 0 ? Velly.voiceEngine.toUpperCase() : "KEINE STIMME");
            // The local server calls every model "velvet" — the size is what
            // tells you which brain is thinking.
            const brain = Velly.provider === "local" ? ((Velly.localTierLabel && Velly.localTierLabel !== "—") ? Velly.localTierLabel : "LOKAL") : (Velly.model || Velly.provider || "").toUpperCase();
            const mem = Velly.facts === 1 ? "1 ERINNERUNG" : `${Velly.facts} ERINNERUNGEN`;
            return `${brain}  ·  ${voice}  ·  ${ears}  ·  ${mem}`;
        }
        color: Colours.inkDim
        font.family: Appearance.fontFamily.mono
        font.pixelSize: Appearance.font.size.tiny
        elide: Text.ElideRight
    }

    // ────────────────────────────────────────────────────────────────── orb
    Item {
        id: orb

        anchors.horizontalCenter: parent.horizontalCenter
        y: 68
        width: 172
        height: 172

        readonly property int bars: 28
        readonly property bool listening: root.phase === "listening" || root.phase === "hearing"
        readonly property bool thinking: root.phase === "thinking"
        readonly property bool speaking: root.phase === "speaking"
        readonly property real energy: Velly.listenEnergy()

        function barLength(i: int): real {
            if (orb.listening)
                return 4 + Velly.band(i, orb.bars) * 40;
            if (orb.speaking)
                return 4 + Velly.mouthAt(i, orb.bars) * 34;
            if (orb.thinking) {
                // A radar sweep: the bar nearest the head of the sweep is tall.
                const here = i / orb.bars;
                const head = orb.sweep;
                let d = Math.abs(here - head);
                if (d > 0.5)
                    d = 1 - d;
                return 4 + Math.max(0, 1 - d * 6) * 30;
            }
            return 4 + 2.5 * (0.5 + 0.5 * Math.sin(orb.pulse * 2 + i * 0.5));
        }

        property real sweep: 0
        property real pulse: 0

        // Two clocks, one for each kind of motion; both stop when she sleeps.
        NumberAnimation on sweep {
            running: orb.thinking
            loops: Animation.Infinite
            from: 0
            to: 1
            duration: 1400
            easing.type: Easing.Linear
        }
        NumberAnimation on pulse {
            running: !orb.thinking
            loops: Animation.Infinite
            from: 0
            to: Math.PI * 2
            duration: 2600
            easing.type: Easing.Linear
        }

        // ── the breathing rings
        Repeater {
            model: 3

            Rectangle {
                required property int index

                readonly property real k: index + 1

                anchors.centerIn: parent
                width: 78 + k * 26
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Colours.alpha(Colours.accent, (orb.listening || orb.speaking ? 0.34 : 0.16) / k)
                scale: 1 + (orb.energy * 0.06 + 0.02 * Math.sin(orb.pulse + index)) * (1 - index * 0.2)

                Behavior on border.color {
                    ColorAnimation {
                        duration: Appearance.anim.normal
                    }
                }
            }
        }

        // ── the radial bars: voice in, mouth out, radar while thinking
        Repeater {
            model: orb.bars

            Item {
                required property int index

                anchors.fill: parent
                rotation: index * (360 / orb.bars)

                Rectangle {
                    x: orb.width / 2 - 1.5
                    y: orb.height / 2 - 46 - height
                    width: 3
                    height: orb.barLength(index)
                    radius: 1.5
                    color: Colours.alpha(Colours.accent, 0.35 + Math.min(1, height / 44) * 0.6)
                    antialiasing: true

                    Behavior on height {
                        NumberAnimation {
                            duration: orb.listening ? 60 : 130
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        // ── the core: a soft stack of circles, never a hard disc
        Repeater {
            model: 4

            Rectangle {
                required property int index

                anchors.centerIn: parent
                width: 62 - index * 11
                height: width
                radius: width / 2
                color: Colours.alpha(Colours.accent, 0.05 + index * 0.05)
                scale: 1 + orb.energy * (0.16 - index * 0.03) + 0.015 * Math.sin(orb.pulse * 1.4)
            }
        }

        // The pupil — the one solid thing in the whole module.
        Plate {
            anchors.centerIn: parent
            width: 15
            height: 15
            radius: Appearance.r(8)
            color: root.phase === "error" ? Colours.danger : Colours.accent
            scale: 1 + orb.energy * 0.5

            Behavior on scale {
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }
            }
        }

        // ── three motes on a slow orbit: the "working on it" tell
        Item {
            anchors.fill: parent
            visible: orb.thinking
            opacity: orb.thinking ? 1 : 0

            RotationAnimation on rotation {
                running: true
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1700
            }

            Repeater {
                model: 3

                Rectangle {
                    required property int index

                    x: orb.width / 2 + Math.cos(index * 2.1) * (44 + index * 7) - 2
                    y: orb.height / 2 + Math.sin(index * 2.1) * (44 + index * 7) - 2
                    width: 4
                    height: 4
                    radius: 2
                    color: Colours.accentHot
                    opacity: 0.5 + 0.5 * Math.sin(orb.pulse * 3 + index)
                }
            }
        }

        // ── HUD brackets: the corners of a target that has locked on
        Repeater {
            model: 4

            Item {
                required property int index

                readonly property real sx: index % 2 === 0 ? -1 : 1
                readonly property real sy: index < 2 ? -1 : 1
                readonly property real reach: 22

                x: orb.width / 2 + sx * 74
                y: orb.height / 2 + sy * 74
                width: 1
                height: 1
                opacity: orb.thinking ? 0.9 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                    }
                }

                Rectangle {
                    x: parent.sx > 0 ? -parent.reach : 0
                    y: 0
                    width: parent.reach
                    height: 1.5
                    color: Colours.accent
                }

                Rectangle {
                    x: 0
                    y: parent.sy > 0 ? -parent.reach : 0
                    width: 1.5
                    height: parent.reach
                    color: Colours.accent
                }
            }
        }
    }

    // The scanline that crosses the capsule whenever the state changes — the
    // cheapest piece of game feel in the whole file, and the reason the
    // transitions read as one system instead of four animations.
    Rectangle {
        id: sweepLine

        x: 0
        width: parent.width
        height: 46
        visible: false
        opacity: 0.0
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "transparent"
            }
            GradientStop {
                position: 0.5
                color: Colours.alpha(Colours.accent, 0.5)
            }
            GradientStop {
                position: 1.0
                color: "transparent"
            }
        }

        SequentialAnimation {
            id: sweepAnim

            NumberAnimation {
                target: sweepLine
                property: "y"
                from: 40
                to: 396
                duration: 420
                easing.type: Easing.OutCubic
            }
            PropertyAction {
                target: sweepLine
                property: "visible"
                value: false
            }
        }

        function fire(): void {
            sweepLine.visible = true;
            sweepLine.y = 40;
            sweepAnim.restart();
        }
    }

    Connections {
        target: Velly

        function onPhaseChanged(): void {
            sweepLine.fire();
            if (Velly.phase === "thinking")
                Sfx.cursor();
        }
    }

    // ───────────────────────────────────────────────────────────── the answer
    Flickable {
        id: convo

        x: root.pad
        y: 248
        width: parent.width - root.pad * 2
        height: Math.max(40, (confirmBox.visible ? confirmBox.y : chips.y) - 12 - 248)
        clip: true
        contentHeight: convoColumn.height
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2600

        onContentHeightChanged: {
            const bottom = Math.max(0, contentHeight - height);
            if (contentY < bottom - 4 && contentY > bottom - 90)
                contentY = bottom;
        }
        Component.onCompleted: contentY = Math.max(0, contentHeight - height)

        Column {
            id: convoColumn

            width: convo.width
            spacing: 8

            Repeater {
                model: root.log

                P5Text {
                    required property var modelData

                    width: convoColumn.width
                    text: modelData.role === "user" ? `› ${modelData.text}` : modelData.text
                    color: modelData.role === "user" ? Colours.alpha(Colours.accentInk, 0.85) : Colours.alpha(Colours.ink, 0.92)
                    font.pixelSize: modelData.role === "user" ? Appearance.font.size.small : Appearance.font.size.normal
                    font.family: modelData.role === "user" ? Appearance.fontFamily.mono : Appearance.fontFamily.body
                    wrapMode: Text.Wrap
                    lineHeight: 1.06
                }
            }

            // Half a sentence waiting for its other half — she lets you
            // finish before she answers.
            P5Text {
                width: convoColumn.width
                visible: Velly.heardHead.length > 0
                text: `› ${Velly.heardHead} …`
                color: Colours.alpha(Colours.accentInk, 0.55)
                font.pixelSize: Appearance.font.size.small
                font.family: Appearance.fontFamily.mono
                wrapMode: Text.Wrap
                lineHeight: 1.06
            }

            // What she understood — shown the moment it goes out, not only
            // once the answer is there: one glance tells you she heard right.
            P5Text {
                readonly property string asked: Velly.askLine

                width: convoColumn.width
                visible: asked.length > 0 && root.phase === "thinking" && !root.log.some(e => e.role === "user" && e.text === asked)
                text: `› ${asked}`
                color: Colours.alpha(Colours.accentInk, 0.88)
                font.pixelSize: Appearance.font.size.small
                font.family: Appearance.fontFamily.mono
                wrapMode: Text.Wrap
                lineHeight: 1.06
            }

            // Live captions: your words while you are still saying them.
            Item {
                width: convoColumn.width
                height: liveLine.implicitHeight
                visible: Velly.liveText.length > 0

                Rectangle {
                    id: liveDot

                    y: 5
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Colours.accent

                    SequentialAnimation on opacity {
                        running: liveDot.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.25
                            duration: 480
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1
                            duration: 480
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                P5Text {
                    id: liveLine

                    x: 14
                    width: parent.width - 14
                    text: `${Velly.liveText} …`
                    color: Colours.alpha(Colours.accentInk, 0.62)
                    font.pixelSize: Appearance.font.size.small
                    font.family: Appearance.fontFamily.mono
                    font.italic: true
                    wrapMode: Text.Wrap
                    lineHeight: 1.06
                }
            }

            // The answer as it arrives. The caret is drawn rather than typed,
            // so it never lands in the middle of a word.
            Item {
                width: convoColumn.width
                height: Math.max(0, answerText.implicitHeight)
                visible: answerText.text.length > 0

                P5Text {
                    id: answerText

                    // While she speaks, the sentence she is saying right now
                    // lights up — what was said dims, what is coming waits.
                    readonly property var sentences: Velly.answer.match(/[^.!?…]+[.!?…]*\s*/g) ?? [Velly.answer]
                    readonly property bool karaoke: root.phase === "speaking" && answerText.sentences.length > 1

                    function esc(t: string): string {
                        return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                    }

                    width: parent.width
                    textFormat: answerText.karaoke ? Text.StyledText : Text.PlainText
                    text: {
                        if (!answerText.karaoke)
                            return Velly.answer;
                        const n = answerText.sentences.length;
                        const cur = Math.max(0, Math.min(n - 1, Math.floor(Velly.speakProgress * n)));
                        const said = `${Colours.alpha(Colours.ink, 0.5)}`;
                        const next = `${Colours.alpha(Colours.ink, 0.38)}`;
                        let out = "";
                        for (let i = 0; i < n; i++) {
                            const piece = answerText.esc(answerText.sentences[i]);
                            out += i === cur ? piece : `<font color="${i < cur ? said : next}">${piece}</font>`;
                        }
                        return out;
                    }
                    color: root.phase === "error" ? Colours.danger : Colours.ink
                    font.pixelSize: Appearance.font.size.large
                    wrapMode: Text.Wrap
                    lineHeight: 1.08
                }

                Rectangle {
                    id: caret

                    x: Math.min(parent.width - 8, answerText.contentWidth + 2)
                    y: Math.min(parent.height - 16, Math.floor(answerText.implicitHeight / Math.max(1, answerText.lineCount)) * (answerText.lineCount - 1) + 4)
                    width: 7
                    height: 14
                    color: Colours.accent
                    visible: root.phase === "thinking" || root.phase === "speaking"

                    SequentialAnimation on opacity {
                        running: caret.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.15
                            duration: 420
                        }
                        NumberAnimation {
                            to: 1.0
                            duration: 420
                        }
                    }
                }
            }

            // Nothing said yet: the invitation, in her own voice.
            Column {
                width: convoColumn.width
                spacing: 4
                visible: root.log.length === 0 && Velly.answer.length === 0 && Velly.liveText.length === 0 && root.phase !== "thinking"

                P5Text {
                    width: parent.width
                    text: root.phase === "off" ? "SCHLAFEND  ·  HALTEN ZUM WECKEN" : (Velly.brainOk ? "FRAG MICH  ·  ODER SPRICH" : "ERST DAS GEHIRN  ·  SETUP UNTEN")
                    color: Colours.alpha(Colours.ink, 0.75)
                    font.pixelSize: Appearance.font.size.large
                    wrapMode: Text.Wrap
                }

                P5Text {
                    width: parent.width
                    text: Velly.brainOk
                        ? `TIPPE ODER REDE — ${Binds.display("velly").toUpperCase()} RUFT MICH VON ÜBERALL. ICH HÖRE NUR, SOLANGE ICH WACH BIN.`
                        : "SETUP LÄDT GEHIRN, OHREN UND STIMME LOKAL — OHNE SCHLÜSSEL UND OHNE KOSTEN. EIN KEY IST NUR FÜR WOLKEN NÖTIG."
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.1
                    wrapMode: Text.Wrap
                }

                // A few things to try, one click each — what she can do,
                // shown instead of explained.
                Flow {
                    width: parent.width
                    spacing: 6
                    topPadding: 8
                    visible: Velly.brainOk && root.phase !== "off"

                    Repeater {
                        model: [
                            { t: "WIE WIRD DAS WETTER?", q: "Wie wird das Wetter heute?", i: "cloud" },
                            { t: "SPIEL MUSIK", q: "Spiel mir Musik, die gerade passt.", i: "music_note" },
                            { t: "IN 10 MIN ERINNERN", q: "Erinnere mich in zehn Minuten an eine Pause.", i: "alarm" },
                            { t: "SYSTEM-UPDATE", q: "Mach ein System-Update.", i: "system_update" },
                            { t: "WAS KANNST DU?", q: "Was kannst du alles für mich tun?", i: "auto_awesome" }
                        ]

                        Plate {
                            id: idea

                            required property var modelData

                            width: ideaLabel.implicitWidth + 36
                            height: 24
                            radius: Appearance.r(12)
                            color: ideaMouse.containsMouse ? Colours.alpha(Colours.accent, 0.22) : Colours.alpha(Colours.ink, 0.06)
                            border.width: 1
                            border.color: ideaMouse.containsMouse ? Colours.accent : Colours.alpha(Colours.ink, 0.16)
                            scale: ideaMouse.pressed ? 0.95 : (ideaMouse.containsMouse ? 1.04 : 1)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 140
                                    easing.type: Easing.OutBack
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 9
                                width: 12
                                name: idea.modelData.i
                                color: Colours.accent
                                font.pixelSize: 12
                            }

                            P5Text {
                                id: ideaLabel

                                anchors.verticalCenter: parent.verticalCenter
                                x: 26
                                text: idea.modelData.t
                                color: Colours.alpha(Colours.ink, 0.88)
                                font.pixelSize: Appearance.font.size.tiny
                                tracking: 1
                            }

                            MouseArea {
                                id: ideaMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Sfx.select();
                                    Velly.ask(idea.modelData.q);
                                }
                            }
                        }
                    }
                }
            }

            // An error is worth saying plainly, and worth saying once.
            P5Text {
                width: convoColumn.width
                visible: root.phase === "error" && Velly.errorText.length > 0
                text: Velly.friendlyError === Velly.errorText ? `FEHLER  ·  ${Velly.errorText}` : `${Velly.friendlyError}\n(${Velly.errorText})`
                color: Colours.danger
                font.family: Appearance.fontFamily.mono
                font.pixelSize: Appearance.font.size.tiny
                wrapMode: Text.Wrap
            }
        }

        SmoothScroll {
            view: convo
        }
    }

    // ──────────────────────────────────────────────────────── the question
    //  Before something that cannot be taken back (a command, a reboot) she
    //  asks — and here is the question with its two answers. Saying "ja" or
    //  "nein" does exactly the same.
    Plate {
        id: confirmBox

        readonly property var c: Velly.confirm

        anchors.left: parent.left
        anchors.leftMargin: root.pad
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.bottom: chips.top
        anchors.bottomMargin: 8
        height: 44
        visible: c !== null && Velly.active
        radius: Appearance.r(12)
        color: Colours.alpha(Colours.warning, 0.12)
        border.width: 1
        border.color: Colours.alpha(Colours.warning, 0.55)

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            width: 16
            name: "help"
            color: Colours.warning
            font.pixelSize: 16
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 36
            width: parent.width - 36 - noBtn.width - yesBtn.width - 28
            text: confirmBox.c ? `SOLL ICH ${`${confirmBox.c.what ?? ""}`.toUpperCase()}?` : ""
            color: Colours.ink
            font.pixelSize: Appearance.font.size.tiny
            tracking: 0.8
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }

        Plate {
            id: noBtn

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: yesBtn.left
            anchors.rightMargin: 6
            width: noLabel.implicitWidth + 22
            height: 28
            radius: Appearance.r(9)
            color: noMouse.containsMouse ? Colours.alpha(Colours.ink, 0.14) : "transparent"
            border.width: 1
            border.color: Colours.alpha(Colours.ink, 0.35)

            P5Text {
                id: noLabel

                anchors.centerIn: parent
                text: "NEIN"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }

            MouseArea {
                id: noMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Sfx.back();
                    Velly.confirmAnswer(false);
                }
            }
        }

        Plate {
            id: yesBtn

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
            width: yesLabel.implicitWidth + 26
            height: 28
            radius: Appearance.r(9)
            color: yesMouse.containsMouse ? Colours.lighten(Colours.accent, 0.08) : Colours.accent

            P5Text {
                id: yesLabel

                anchors.centerIn: parent
                text: "JA, MACH"
                color: Colours.on(Colours.accent)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }

            MouseArea {
                id: yesMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Sfx.select();
                    Velly.confirmAnswer(true);
                }
            }
        }
    }

    // ───────────────────────────────────────────────────────────── the chips
    Row {
        id: chips

        anchors.left: parent.left
        anchors.leftMargin: root.pad
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.bottom: inputRow.top
        anchors.bottomMargin: 10
        height: 22
        spacing: 6
        clip: true

        Repeater {
            model: Velly.tools.slice(-4)

            Plate {
                id: toolChip

                required property var modelData

                width: Math.min(150, chipLabel.implicitWidth + 34)
                height: 22
                radius: Appearance.r(11)
                color: Colours.alpha(modelData.ok ? Colours.accent : Colours.danger, 0.14)
                border.width: 1
                border.color: Colours.alpha(modelData.ok ? Colours.accent : Colours.danger, 0.5)
                scale: 1

                Component.onCompleted: pop.restart()

                SequentialAnimation {
                    id: pop

                    NumberAnimation {
                        target: toolChip
                        property: "scale"
                        from: 0.6
                        to: 1.12
                        duration: 130
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: toolChip
                        property: "scale"
                        from: 1.12
                        to: 1.0
                        duration: 110
                        easing.type: Easing.OutCubic
                    }
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 9
                    width: 11
                    name: modelData.ok ? "bolt" : "warning"
                    color: modelData.ok ? Colours.accent : Colours.danger
                    font.pixelSize: 11
                }

                P5Text {
                    id: chipLabel

                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${modelData.name ?? ""}`.toUpperCase() + (modelData.note ? `  ${modelData.note}` : "")
                    color: Colours.alpha(Colours.ink, 0.85)
                    font.pixelSize: Appearance.font.size.tiny
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ────────────────────────────────────────────────────────────── the input
    Plate {
        id: inputRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 34
        height: 38
        radius: Appearance.r(12)
        color: Colours.alpha(Colours.ink, 0.07)
        border.width: 1
        border.color: input.activeFocus ? Colours.accent : Colours.alpha(Colours.ink, 0.16)
        clip: true

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            width: 16
            name: "auto_awesome"
            color: root.phase === "off" ? Colours.inkDim : Colours.accent
            font.pixelSize: 15
        }

        TextInput {
            id: input

            anchors.left: parent.left
            anchors.leftMargin: 36
            anchors.right: micChip.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Colours.ink
            font.family: Appearance.fontFamily.body
            font.pixelSize: Appearance.font.size.small
            selectByMouse: true
            clip: true
            cursorDelegate: Rectangle {
                width: 2
                color: Colours.accent
            }

            onAccepted: {
                const line = `${text ?? ""}`.trim();
                if (line.length === 0)
                    return;
                text = "";
                Velly.ask(line);
            }

            // Escape puts her to sleep — it never closes the island under
            // your hands while you are talking to her.
            Keys.onEscapePressed: event => {
                text = "";
                Velly.sleep();
                event.accepted = true;
            }

            // The mic chip is hers to end: click it, or press the one key
            // that is not a character.
            Keys.onPressed: event => {
                if (event.key === Qt.Key_F4)
                    event.accepted = false;
            }
        }

        // The mic: whether anyone is listening, and a way to stop it now.
        Plate {
            id: micChip

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: micLabel.implicitWidth + 40
            height: 26
            radius: Appearance.r(13)
            color: Colours.alpha(Velly.listening ? Colours.accent : Colours.ink, Velly.listening ? 0.18 : 0.08)
            border.width: 1
            border.color: Colours.alpha(Velly.listening ? Colours.accent : Colours.ink, Velly.listening ? 0.6 : 0.2)

            Icon {
                id: micIcon

                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                name: Velly.listening ? (Velly.talking ? "graphic_eq" : "mic") : "mic_off"
                color: Velly.listening ? Colours.accent : Colours.inkDim
                font.pixelSize: 12
            }

            P5Text {
                id: micLabel

                anchors.left: micIcon.right
                anchors.leftMargin: 5
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: Velly.sttBusy ? "HÖRT ZU…" : (Velly.listening ? "MIC" : "STUMM")
                color: Velly.listening ? Colours.accentInk : Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.1
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Sfx.toggle();
                    Config.set("velly.ears", !Config.velly.ears);
                    if (Config.velly.ears)
                        Velly.earsCtl("listen");
                }
            }
        }

        // While she listens, the bottom of the field carries the level: a
        // hairline that fills with your voice, so you can see that she hears
        // you without a single bar of chrome moving.
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width * Math.min(1, Velly.level * 1.6)
            height: 2
            color: Colours.alpha(Colours.accent, 0.75)
            visible: Velly.listening
            Behavior on width {
                NumberAnimation {
                    duration: 70
                }
            }
        }
    }

    // The one-line hint row, and the only place the setup is offered.
    Row {
        anchors.left: parent.left
        anchors.leftMargin: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        spacing: 14

        P5Text {
            text: {
                if (Velly.sttError.length > 0)
                    return `OHREN  ·  ${Velly.sttError.toUpperCase().slice(0, 34)}`;
                if (Velly.barged)
                    return "ICH HÖRE  ·  SAG'S NOCHMAL";
                if (Velly.sttBusy)
                    return "VERSTEHE…";
                return Velly.earsAvailable || !Config.velly.ears ? "ENTER FRAGEN" : "KEIN MIKROFON GEFUNDEN";
            }
            color: Velly.sttError.length > 0 ? Colours.danger : (Velly.barged ? Colours.accent : Colours.inkDim)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.1
        }

        P5Text {
            text: "ESC SCHLAFEN"
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.1
        }
    }

    Plate {
        id: setupChip

        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: setupLabel.implicitWidth + 18
        height: 18
        radius: Appearance.r(9)
        color: Velly.brainOk ? "transparent" : Colours.alpha(Colours.accent, 0.16)
        border.width: Velly.brainOk ? 0 : 1
        border.color: Colours.alpha(Colours.accent, 0.5)

        P5Text {
            id: setupLabel

            anchors.centerIn: parent
            text: Velly.brainOk ? "SETUP" : (Velly.installing ? "LÄDT…" : "GEHIRN LADEN")
            color: Colours.accentInk
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.1
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sfx.toggle();
                Velly.setupOpen = !Velly.setupOpen;
            }
        }
    }

    // ──────────────────────────────────────────────────────── the setup card
    //  A first-run wizard in the capsule: provider, key, model, test. Nothing
    //  here is a placeholder — the fields write ~/.config/velvet/ai.json (0600)
    //  through bin/velvet-ai, and TEST does a real round trip.
    Plate {
        id: setup

        anchors.fill: parent
        anchors.margins: 10
        anchors.topMargin: 40
        visible: Velly.setupOpen
        color: Qt.rgba(0.02, 0.02, 0.024, 0.97)
        radius: Appearance.r(18)
        border.width: 1
        border.color: Colours.alpha(Colours.accent, 0.45)
        z: 30

        P5Text {
            x: 20
            y: 16
            display: true
            text: "SETUP"
            color: Colours.accent
            font.pixelSize: Appearance.font.size.huge
            tracking: 2
        }

        P5Text {
            x: 20
            y: 48
            width: parent.width - 100
            text: "LOKAL IST VOREINGESTELLT UND KOSTET NICHTS. EIN SCHLÜSSEL IST NUR FÜR WOLKEN NÖTIG — ER LANDET IN AI.JSON (0600)."
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.1
            wrapMode: Text.Wrap
        }

        Icon {
            anchors.right: parent.right
            anchors.rightMargin: 14
            y: 14
            width: 18
            name: "close"
            color: Colours.alpha(Colours.ink, 0.6)
            font.pixelSize: 16

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Sfx.back();
                    Velly.setupOpen = false;
                }
            }
        }

        // provider chips — a click IS the decision, not a selection to confirm
        P5Text {
            x: 20
            y: 92
            display: true
            text: "GEHIRN"
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.2
        }

        Row {
            id: providerRow

            x: 20
            y: 110
            spacing: 8

            Repeater {
                model: ["local", "auto", "openai", "deepseek", "anthropic", "ollama"]

                Plate {
                    required property string modelData

                    readonly property bool here: (Velly.setupProvider || "auto") === modelData

                    width: providerLabel.implicitWidth + 22
                    height: 26
                    radius: Appearance.r(13)
                    color: here ? Colours.alpha(Colours.accent, 0.28) : Colours.alpha(Colours.ink, 0.06)
                    border.width: 1
                    border.color: here ? Colours.accent : Colours.alpha(Colours.ink, 0.18)

                    P5Text {
                        id: providerLabel

                        anchors.centerIn: parent
                        display: true
                        text: modelData.toUpperCase()
                        color: here ? Colours.accentInk : Colours.alpha(Colours.ink, 0.8)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Sfx.select();
                            Velly.setProvider(parent.modelData);
                            if (parent.modelData !== "local" && parent.modelData !== "auto" && parent.modelData !== "ollama")
                                setupInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // What is thinking right now, in the machine's own words.
        P5Text {
            x: 20
            y: 146
            width: parent.width - 40
            display: true
            elide: Text.ElideRight
            text: Velly.brainLine
            color: Velly.brainOk || Velly.activeTier.length > 0 ? Colours.accentInk : Colours.inkDim
            font.family: Appearance.fontFamily.mono
            font.pixelSize: Appearance.font.size.tiny
        }

        // the field: key or model, one at a time
        Plate {
            id: setupField

            x: 20
            y: 168
            width: parent.width - 40
            height: 38
            radius: Appearance.r(12)
            color: Colours.alpha(Colours.ink, 0.07)
            border.width: 1
            border.color: setupInput.activeFocus ? Colours.accent : Colours.alpha(Colours.ink, 0.18)

            P5Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Velly.setupField === "key" ? "SCHLÜSSEL" : "MODELL"
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.1
            }

            TextInput {
                id: setupInput

                anchors.left: parent.left
                anchors.leftMargin: 86
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Colours.ink
                font.family: Appearance.fontFamily.mono
                font.pixelSize: Appearance.font.size.small
                selectByMouse: true
                clip: true
                echoMode: Velly.setupField === "key" ? TextInput.Password : TextInput.Normal
                passwordCharacter: "•"

                onAccepted: {
                    Velly.setupCommit(text);
                    text = "";
                }
            }
        }

        Row {
            x: 20
            y: 214
            spacing: 8

            Repeater {
                model: [
                    { label: "SCHLÜSSEL", field: "key" },
                    { label: "MODELL", field: "model" },
                    { label: "TEST", field: "test" },
                    { label: "GEDÄCHTNIS", field: "forget" }
                ]

                Plate {
                    required property var modelData

                    readonly property bool active: Velly.setupField === modelData.field

                    width: setupBtnLabel.implicitWidth + 24
                    height: 28
                    radius: Appearance.r(14)
                    color: modelData.field === "test" ? Colours.alpha(Colours.accent, Velly.probing ? 0.4 : 0.2) : (active ? Colours.alpha(Colours.accent, 0.3) : Colours.alpha(Colours.ink, 0.06))
                    border.width: 1
                    border.color: modelData.field === "test" || active ? Colours.alpha(Colours.accent, 0.7) : Colours.alpha(Colours.ink, 0.18)

                    P5Text {
                        id: setupBtnLabel

                        anchors.centerIn: parent
                        display: true
                        text: modelData.field === "test" && Velly.probing ? "TESTE…" : modelData.label
                        color: active || modelData.field === "test" ? Colours.accentInk : Colours.alpha(Colours.ink, 0.8)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.modelData.field === "test") {
                                Sfx.toggle();
                                Velly.probe();
                            } else if (parent.modelData.field === "forget") {
                                Sfx.back();
                                Velly.forgetAll();
                            } else {
                                Sfx.toggle();
                                Velly.setupField = parent.modelData.field;
                                setupInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        // How big should she think? One download per size; brain.gguf is a
        // symlink, so the way back to a smaller one costs nothing.
        P5Text {
            x: 20
            y: 252
            display: true
            text: "MODELL-GRÖSSE"
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.2
        }

        Row {
            id: tierRow

            x: 20
            y: 270
            spacing: 8

            Repeater {
                model: Velly.brainTiers

                Plate {
                    required property var modelData

                    readonly property bool here: Velly.activeTier === modelData.key

                    width: tierLabel.implicitWidth + 22
                    height: 28
                    radius: Appearance.r(14)
                    color: here ? Colours.alpha(Colours.accent, 0.3) : Colours.alpha(Colours.ink, 0.06)
                    border.width: 1
                    border.color: here ? Colours.accent : Colours.alpha(Colours.ink, 0.18)

                    P5Text {
                        id: tierLabel

                        anchors.centerIn: parent
                        display: true
                        text: `${modelData.label}`
                        color: here ? Colours.accentInk : Colours.alpha(Colours.ink, 0.8)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Sfx.select();
                            Velly.brainTier(parent.modelData.key);
                        }
                    }
                }
            }
        }

        P5Text {
            id: tierNoteText

            x: 20
            y: 304
            width: parent.width - 40 - (forceButton.visible ? forceButton.width + 10 : 0)
            display: true
            elide: Text.ElideRight
            text: {
                if (Velly.installing)
                    return Velly.installDetail.length > 0 ? `${Velly.installLabel}  ·  ${Velly.installDetail}` : `${Velly.installLabel}`;
                return Velly.tierNote;
            }
            color: Velly.forceTier ? Colours.accent : (Velly.tierFit(Velly.chosenTier) === 3 ? Colours.alpha(Colours.danger, 0.9) : Colours.inkDim)
            font.pixelSize: Appearance.font.size.tiny
        }

        // The override a game would call "apply anyway": her own size runs even
        // when it is far from fitting right now (much of it then lives in RAM
        // and it answers slowly), with the engine room's own words beside it.
        // AUTO is the way back to "the biggest that fits".
        Plate {
            id: forceButton

            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 299
            readonly property bool relevant: Velly.chosenTier.length > 0
                && (Velly.forceTier || (Velly.nextTier !== null && Velly.nextTier.key !== Velly.chosenTier))

            visible: relevant && !Velly.installing
            width: forceButtonLabel.implicitWidth + 16
            height: 20
            radius: Appearance.r(10)
            color: Velly.forceTier ? Colours.alpha(Colours.accent, 0.2) : Colours.alpha(Colours.ink, 0.08)
            border.width: 1
            border.color: Velly.forceTier ? Colours.alpha(Colours.accent, 0.65) : Colours.alpha(Colours.ink, 0.3)

            P5Text {
                id: forceButtonLabel

                anchors.centerIn: parent
                display: true
                text: Velly.forceTier ? "AUTO" : "TROTZDEM"
                color: Velly.forceTier ? Colours.accentInk : Colours.alpha(Colours.ink, 0.85)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.1
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Sfx.back();
                    Velly.setForce(!Velly.forceTier);
                }
            }
        }

        // The engine room in one row: one press, one honest bar. This is the
        // whole "no key" path — it fetches llama.cpp, a brain, whisper and the
        // voice once, and after that Velly is local for good.
        Plate {
            id: installBar

            x: 20
            y: 328
            width: parent.width - 40
            height: 40
            radius: Appearance.r(12)
            color: Colours.alpha(Colours.accent, installMouse.containsMouse ? 0.2 : 0.1)
            border.width: 1
            border.color: Colours.alpha(Colours.accent, 0.5)

            P5Text {
                id: installLabel

                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                display: true
                elide: Text.ElideRight
                text: Velly.installing ? `${Velly.installLabel || "ENGINE"}  ${Velly.installPct}%${Velly.installDetail.length > 0 ? "  ·  " + Velly.installDetail : ""}` : (Velly.brainOk ? "LOKALES GEHIRN AKTIV  ·  KLICK: PRÜFEN" : "LOKALES GEHIRN LADEN  ·  KOSTENLOS, OHNE SCHLÜSSEL")
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.1
            }

            // The bar is the file's own percentage, filling from the left.
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                height: 2
                visible: Velly.installing
                width: (parent.width - 16) * Math.max(0, Math.min(1, Velly.installPct / 100))
                color: Colours.accent
                antialiasing: true

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            MouseArea {
                id: installMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Sfx.select();
                    Velly.installLocal();
                }
            }
        }

        // The voice: two arrows to walk the German shelf, one button to hear it
        // before keeping it. A voice that is not downloaded yet fetches itself
        // on the next sentence — free, once.
        Plate {
            id: voiceRow

            x: 20
            y: 376
            width: parent.width - 40
            height: 32
            radius: Appearance.r(10)
            color: Colours.alpha(Colours.ink, 0.06)
            border.width: 1
            border.color: Colours.alpha(Colours.ink, 0.16)

            P5Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: "STIMME"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.1
            }

            P5Text {
                id: voiceNameLabel

                anchors.left: parent.left
                anchors.leftMargin: 62
                anchors.right: voiceControls.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                display: true
                elide: Text.ElideRight
                text: Velly.voiceLabel
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.1
            }

            Row {
                id: voiceControls

                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Repeater {
                    model: [
                        { action: "prev", label: "‹" },
                        { action: "say", label: "SAG" },
                        { action: "next", label: "›" }
                    ]

                    Plate {
                        required property var modelData

                        width: modelData.action === "say" ? voiceCtlLabel.implicitWidth + 18 : 22
                        height: 22
                        radius: Appearance.r(11)
                        color: modelData.action === "say" ? Colours.alpha(Colours.accent, Velly.speaking ? 0.4 : 0.22) : Colours.alpha(Colours.ink, 0.08)
                        border.width: 1
                        border.color: Colours.alpha(modelData.action === "say" ? Colours.accent : Colours.ink, 0.3)

                        P5Text {
                            id: voiceCtlLabel

                            anchors.centerIn: parent
                            display: true
                            text: modelData.label
                            color: modelData.action === "say" ? Colours.accentInk : Colours.alpha(Colours.ink, 0.85)
                            font.pixelSize: Appearance.font.size.tiny
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Sfx.cursor();
                                if (modelData.action === "prev")
                                    Velly.voiceStep(-1);
                                else if (modelData.action === "next")
                                    Velly.voiceStep(1);
                                else
                                    Velly.voicePreview();
                            }
                        }
                    }
                }
            }
        }

        P5Text {
            x: 20
            y: 418
            width: parent.width - 40
            text: {
                if (Velly.probing)
                    return "FRAGE DEN ANBIETER…";
                if (Velly.setupNote.length > 0)
                    return Velly.setupNote;
                return `AKTUELL  ·  ${(Velly.provider || "auto").toUpperCase()}  ·  ${Velly.model || "STANDARD-MODELL"}`;
            }
            color: Velly.setupNote.startsWith("FEHLER") ? Colours.danger : Colours.inkDim
            font.family: Appearance.fontFamily.mono
            font.pixelSize: Appearance.font.size.tiny
            wrapMode: Text.Wrap
        }

        P5Text {
            x: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: parent.width - 40
            text: Velly.factsList.length > 0 ? `GEMERKT  ·  ${Velly.factsList[Velly.factsList.length - 1]}` : "NOCH NICHTS GEMERKT"
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            elide: Text.ElideRight
        }

        Component.onCompleted: setupInput.forceActiveFocus()
    }

    // The input takes the keyboard the moment the module is on screen: you
    // long-pressed the island to talk, not to click a field. It never takes it
    // back from another overlay — a timer that re-grabs focus every 60 ms while
    // Super+Tab is open would make the settings menu unusable.
    Timer {
        interval: 260
        running: Velly.active && !Velly.setupOpen && !input.activeFocus && !panelBusy()
        onTriggered: input.forceActiveFocus()
    }

    function panelBusy(): bool {
        return Panels.settings || Panels.launcher || Panels.notifCentre || Panels.session || Panels.windowMap || Panels.wheel || Panels.keys;
    }

    Connections {
        target: Velly

        function onSetupOpenChanged(): void {
            if (Velly.setupOpen) {
                setupFieldTimer.restart();
                Velly.setupNote = "";
            } else {
                input.forceActiveFocus();
            }
        }
    }

    Timer {
        id: setupFieldTimer

        interval: 80
        onTriggered: setupInput.forceActiveFocus()
    }
}
