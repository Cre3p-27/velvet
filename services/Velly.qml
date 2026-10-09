//  VELVET  ·  services/Velly.qml
//  The assistant in the Dynamic Island: her session, her senses, her hands.
//
//  Everything about Velly starts and ends with one gesture — holding the pill
//  at the top edge. That press opens a SESSION, and a session is a real thing
//  with a real lifetime:
//
//    · the shell writes ~/.config/velvet/ai-session.json and keeps its `until`
//      stamp moving while she is awake. bin/velvet-ai checks that file before
//      EVERY tool call, so a brain that somehow outlives its island can still
//      talk but cannot touch anything.
//    · the microphone (bin/velvet-ears) and the brain (bin/velvet-ai) are
//      child processes of this shell: they start with the session and are
//      killed with it. Nothing listens while she is asleep.
//    · closing the island, pressing Escape, or three quiet minutes ends it —
//      including "sleep" to the brain, which distils the session into memory
//      on the way out.
//
//  The shell never talks to a model directly. It writes a request file, reads
//  a state file and watches the levels, which means the whole conversation
//  survives a slow provider without a single blocking call in the UI.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // ──────────────────────────────────────────────────────────── the files
    readonly property string dir: `${Quickshell.env("HOME")}/.config/velvet`
    readonly property string statePath: `${root.dir}/ai-state.json`
    readonly property string reqPath: `${root.dir}/ai-req.json`
    readonly property string sessionPath: `${root.dir}/ai-session.json`
    readonly property string earsPath: `${root.dir}/ai-voice.json`
    readonly property string speechPath: `${root.dir}/ai-speech.json`
    readonly property string ctlPath: `${root.dir}/ai-ears.ctl`
    readonly property string hearPath: `${root.dir}/ai-hear.wav`
    readonly property string memoryPath: `${root.dir}/ai-memory.json`
    readonly property string aiPath: `${root.dir}/ai.json`
    readonly property string installPath: `${root.dir}/ai-install.json`
    readonly property string localPath: `${root.dir}/ai-local.json`
    readonly property string localScript: `${Qt.resolvedUrl("../bin/velvet-local")}`.replace(/^file:\/\//, "")
    readonly property string brainScript: `${Qt.resolvedUrl("../bin/velvet-ai")}`.replace(/^file:\/\//, "")
    readonly property string earsScript: `${Qt.resolvedUrl("../bin/velvet-ears")}`.replace(/^file:\/\//, "")
    readonly property string voiceScript: `${Qt.resolvedUrl("../bin/velvet-voice")}`.replace(/^file:\/\//, "")

    // ──────────────────────────────────────────────────────────── the session
    property bool active: false
    // The brain is allowed to outlive the island for one last thing: it
    // distils the conversation into memory after the session closes.
    property bool lingering: false
    // Long-press charge, owned by the island's gesture — 0…1.
    property real arm: 0

    // ─────────────────────────────────────────────── the music, turned down
    // VELLY → MUSIK LEISER: while she is awake a playing player drops to a
    // quarter of its volume (or pauses, when it has no volume of its own) and
    // comes back exactly as it was when she sleeps. The microphone hears you,
    // not the song — whisper had turned sung lines into questions (measured:
    // "Vertraue und glaube, es heilt die göttliche Kraft!").
    readonly property bool duckWanted: Config.velly.enabled && Config.velly.duckMedia && root.active
    property var duckedPlayer: null
    property real duckedVolume: -1
    property bool duckedPaused: false

    onDuckWantedChanged: {
        if (root.duckWanted)
            root.duck();
        else
            root.unduck();
    }

    function duck(): void {
        const p = Lyrics.bridge?.player ?? null;
        if (!p || !p.isPlaying || root.duckedPlayer !== null)
            return;
        if (p.volumeSupported && p.canControl && p.volume > 0.05) {
            root.duckedVolume = p.volume;
            p.volume = Math.max(0.04, p.volume * 0.25);
            root.duckedPlayer = p;
        } else if (p.canPause) {
            p.pause();
            root.duckedPaused = true;
            root.duckedPlayer = p;
        }
    }

    function unduck(): void {
        const p = root.duckedPlayer;
        root.duckedPlayer = null;
        if (p) {
            // Only put back what she changed: a volume the user moved in
            // the meantime, or a song they paused themselves, stays theirs.
            if (root.duckedVolume >= 0 && p.volumeSupported && Math.abs(p.volume - Math.max(0.04, root.duckedVolume * 0.25)) < 0.06)
                p.volume = root.duckedVolume;
            else if (root.duckedPaused && p.canPlay && !p.isPlaying)
                p.play();
        }
        root.duckedVolume = -1;
        root.duckedPaused = false;
    }

    // ───────────────────────────────────────────────────────────── the senses
    // Read straight out of the sidecars' state files.
    property var state: ({})
    property var ears: ({})
    property var speech: ({})
    property var memory: ({})

    // Listening in a session (EARS), or all the time for "Hey Velly"
    // (WAKE WORD) — never on the lock screen.
    readonly property bool earsWanted: Config.velly.enabled && !Locker.locked && ((root.active && (Config.velly.ears || Config.velly.wakeWord)) || (!root.active && Config.velly.wakeWord))
    readonly property bool earsAvailable: (root.ears.available ?? 0) === 1
    readonly property bool listening: root.earsWanted && (root.ears.listening ?? 0) === 1
    readonly property bool hearing: root.listening && (root.ears.live ?? 0) === 1
    readonly property bool talking: root.listening && (root.ears.talking ?? root.ears.speaking ?? 0) === 1
    readonly property real level: Number(root.ears.level ?? 0)
    readonly property var bands: root.ears.bands ?? []
    readonly property string micSource: `${root.ears.source ?? ""}`

    readonly property bool speaking: (root.speech.speaking ?? 0) === 1
    readonly property real speakProgress: Number(root.speech.progress ?? 0)
    readonly property var mouth: root.speech.envelope ?? []
    readonly property bool voiceAvailable: (root.speech.engine ?? "") !== "" && root.speech.ok !== false
    readonly property string voiceEngine: `${root.speech.engine ?? ""}`

    // How alive the orb should be, in one number: your voice while she hears
    // you, her own voice while she speaks, a slow breath in between.
    function listenEnergy(): real {
        if (root.listening)
            return Math.max(0.05, root.level);
        if (root.speaking)
            return Math.max(0.05, root.mouthAt(Math.floor(root.speakProgress * 28), 28));
        return 0.08;
    }

    function band(i: int, of: int): real {
        const list = root.bands;
        if (of <= 0 || list.length === 0)
            return 0;
        const from = Math.floor(i * list.length / of);
        const to = Math.max(from + 1, Math.floor((i + 1) * list.length / of));
        let sum = 0;
        let n = 0;
        for (let b = from; b < to && b < list.length; b++) {
            sum += Number(list[b]) || 0;
            n++;
        }
        return n > 0 ? sum / n : 0;
    }

    // The mouth, sampled the same way — the island draws both through one row
    // of bars, so the orb and the lips are the same instrument.
    function mouthAt(i: int, of: int): real {
        const list = root.mouth;
        if (of <= 0 || list.length === 0)
            return 0;
        const idx = Math.min(list.length - 1, Math.floor((i + 0.5) * list.length / of));
        return Number(list[idx]) || 0;
    }

    // ───────────────────────────────────────────────────────────── the brain
    // The state file starts every daemon with `brain: none`, because a fresh
    // process does not know yet what it will be. So the last answer that was
    // not "none" is kept here: an asleep Velly still says what she was, instead
    // of claiming she has no brain until you wake her to check.
    property string lastBrain: ""
    readonly property string brain: {
        const now = `${root.state.brain ?? "none"}`;
        return now === "none" ? (root.lastBrain || "none") : now;
    }
    // What brain she HAS — never a verdict on the last turn. A failed turn, a
    // probe that timed out while the model was still loading: none of that
    // makes her brainless, and pretending otherwise put "GEHIRN LADEN" on the
    // chip for as long as the state file kept the word "error".
    readonly property bool brainOk: {
        if (root.state.brainReady === true)
            return true;
        const kind = root.brain;
        if (kind === "openai" || kind === "deepseek" || kind === "anthropic" || kind === "ollama" || kind === "local")
            return true;
        // The engine room knows a model and the provider is the local one:
        // the state file is stale, not the truth.
        const provider = `${Config.velly.provider ?? "auto"}`;
        return (provider === "local" || provider === "auto") && `${root.local.model ?? ""}`.length > 0;
    }
    readonly property bool brainSkills: root.brain === "skills"
    readonly property string model: `${root.state.model ?? ""}`
    readonly property string provider: `${root.state.provider ?? ""}`
    readonly property string errorText: `${root.state.error ?? ""}`
    // The same failure, said so a person knows what to do about it. The raw
    // text stays available (errorText) for the details line.
    readonly property string friendlyError: {
        const e = root.errorText;
        if (!e)
            return "";
        if (/did not come up|not come up|connection refused|urlopen error|server .*down|timed out|timeout/i.test(e))
            return "Mein lokales Gehirn ist nicht hochgekommen — vielleicht ist die Grafikkarte gerade voll (ein Spiel?). Im SETUP kann ich eine kleinere Größe nehmen.";
        if (/out of memory|vram|oom|cudaMalloc|vk.*alloc/i.test(e))
            return "Zu wenig Grafikspeicher für dieses Modell — im SETUP eine kleinere Größe wählen.";
        if (/401|403|unauthori|invalid.*key|api key/i.test(e))
            return "Der API-Schlüssel wird abgelehnt — im SETUP prüfen.";
        if (/429|rate limit|quota/i.test(e))
            return "Der Anbieter bremst gerade — gleich noch einmal versuchen.";
        if (/session closed/i.test(e))
            return "Die Sitzung ist zu — halt die Insel gedrückt, dann bin ich wieder da.";
        if (/no provider/i.test(e))
            return "Noch kein Gehirn geladen — im SETUP einmal LOKAL laden.";
        return e;
    }
    readonly property string errorShort: {
        const e = root.errorText;
        if (/did not come up|not come up|connection refused|urlopen error|timed out|timeout/i.test(e))
            return "GEHIRN KOMMT NICHT HOCH";
        if (/out of memory|vram|oom/i.test(e))
            return "ZU WENIG GRAFIKSPEICHER";
        if (/401|403|unauthori|key/i.test(e))
            return "SCHLÜSSEL ABGELEHNT";
        if (/429|rate limit|quota/i.test(e))
            return "ANBIETER BREMST";
        return (e || "FEHLER").toUpperCase().slice(0, 40);
    }
    readonly property string answer: `${root.state.answer ?? ""}`
    readonly property string askLine: `${root.state.user ?? ""}`
    readonly property var tools: root.state.tools ?? []
    readonly property int turns: Number(root.state.turn ?? 0)

    // The one word the island draws everywhere: what she is doing right now.
    readonly property string phase: {
        if (!root.active)
            return "off";
        if (root.speaking)
            return "speaking";
        const s = `${root.state.state ?? ""}`;
        // The state file is rewritten many times a second while a turn really
        // runs, so an old stamp means its writer is gone: a brain killed
        // mid-thought used to leave "THINKING" (and a stale "ERROR") on screen
        // for as long as the file kept the word.
        const stamp = Number(root.state.at ?? 0);
        const dead = stamp > 0 && Date.now() - stamp > 20000;
        if ((s === "thinking" || s === "acting") && !dead)
            return "thinking";
        if (!dead && (s === "error" || (root.errorText.length > 0 && s !== "answer")))
            return "error";
        if (root.listening)
            return root.talking ? "hearing" : "listening";
        return "ready";
    }

    readonly property string phaseLabel: {
        // She speaks German; so does her one-word status.
        switch (root.phase) {
        case "speaking":
            return "SPRICHT";
        case "thinking":
            return root.state.state === "acting" ? "HANDELT" : "DENKT NACH";
        case "error":
            return "FEHLER";
        case "listening":
            return "HÖRT ZU";
        case "hearing":
            return "HÖRT DICH";
        case "ready":
            return root.brainOk ? "BEREIT" : (root.brainSkills ? "NUR SKILLS" : "KEIN GEHIRN");
        default:
            return "SCHLÄFT";
        }
    }

    // The island pill's one-glance line.
    readonly property string pill: {
        if (root.installing)
            return `VELLY  ·  LÄDT ${root.installPct}%  ·  ${root.installLabel}`;
        if (root.phase === "off")
            return root.brainOk ? `VELLY  ·  ${root.nextLabel || root.model || "BEREIT"}` : "VELLY  ·  HALTEN ZUM WECKEN";
        if (root.phase === "error")
            return "VELLY  ·  " + root.errorShort;
        return `VELLY  ·  ${root.phaseLabel}`;
    }

    readonly property string glyph: {
        switch (root.phase) {
        case "speaking":
            return "volume_up";
        case "thinking":
            return "bolt";
        case "error":
            return "warning";
        case "listening":
        case "hearing":
            return "graphic_eq";
        default:
            return "auto_awesome";
        }
    }

    readonly property int facts: (root.memory.facts ?? []).length
    readonly property int sessions: Number((root.memory.stats ?? {}).sessions ?? 0)

    // ─────────────────────────────────────────────────────────── the session
    function wake(): void {
        if (!Config.velly.enabled || Locker.locked)
            return;
        if (root.active)
            return;
        root.active = true;
        root.wokeAt = Date.now();
        root.liveText = "";
        root.liveOff = false;
        root.errorTextSeen = "";
        root.earsFloor = Date.now();
        root.writeSession(true);
        heartbeat.restart();
        // The natural voice takes a few seconds to load: start it now, not
        // with her first sentence.
        if (Config.velly.voice) {
            voiceWarm.running = false;
            voiceWarm.running = true;
        }
        if (Config.velly.voice && Config.velly.greet)
            root.say(root.greetings[Math.floor(Math.random() * root.greetings.length)]);
        if (Config.velly.ears && Config.velly.autoListen)
            earsCtl("listen");
    }

    // What she says when she wakes — warm, short, and aware of the hour
    // ("Ja?" and "Sag an." read as curt when they are the first thing you hear).
    // The name she was told ("Heißt Max" in her memory), for a warmer hello.
    // prefs.name is where the brain keeps it since v8.25; older memories only
    // said it in a fact ("Heißt Max", "Name: Creep", "Nutzername: Creep").
    readonly property string userName: {
        const pref = `${root.memory.prefs?.name ?? ""}`.trim();
        if (pref.length > 0)
            return pref;
        const list = root.memory.facts ?? [];
        const patterns = [/(?:^\W*|\b(?:der nutzer|der user|user|nutzer|er|sie|ich)\s+)hei(?:ß|ss)(?:t|e)\s+([A-ZÄÖÜ][\wäöüß-]{1,30})/i, /\b(?:nutzer|user|benutzer|mein|sein)?name(?:\s+ist|\s+is|\s*:)\s+([A-ZÄÖÜ][\wäöüß-]{1,30})/i, /\b(?:called|call me)\s+([A-ZÄÖÜ][\wäöüß-]{1,30})/i, /([A-ZÄÖÜ][\wäöüß-]{1,30})\s+genannt\s+werden/i];
        for (let i = list.length - 1; i >= 0; i--) {
            const text = `${list[i].text ?? ""}`;
            for (let p = 0; p < patterns.length; p++) {
                const m = text.match(patterns[p]);
                if (m && !/^(nicht|noch|unbekannt|der|die|das|the|not|user|nutzer)$/i.test(m[1]))
                    return m[1].charAt(0).toUpperCase() + m[1].slice(1);
            }
        }
        return "";
    }

    readonly property var greetings: {
        const h = new Date().getHours();
        const n = root.userName;
        const any = n ? [`Hey ${n}! Was kann ich für dich tun?`, `Hi ${n}, bin da — was gibt's?`, "Ich höre dir zu.", `Na, ${n}? Womit fangen wir an?`] : ["Hey! Was kann ich für dich tun?", "Bin da — was gibt's?", "Ich höre dir zu.", "Hallo! Womit fangen wir an?"];
        if (h >= 5 && h < 11)
            return any.concat(["Guten Morgen! Was steht an?", "Morgen! Wie kann ich helfen?"]);
        if (h >= 22 || h < 5)
            return any.concat(["Noch wach? Was brauchst du?", "Hey, Nachteule — was gibt's?"]);
        return any;
    }

    // A one-shot request from anywhere in the shell: "show her module". The
    // island picks it up and clears it, whether it was already up or is only
    // coming up now — a settings row must not have to know module indices.
    property bool wantIsland: false

    function forgetAll(): void {
        forgetProc.running = false;
        forgetProc.running = true;
        root.toast("GEDÄCHTNIS GELEERT", "warn");
    }

    Process {
        id: forgetProc

        command: ["python3", root.brainScript, "--forget-all"]
    }

    // The last error the shell showed, so the same failure is not reported twice.
    property string errorTextSeen: ""

    function sleep(): void {
        if (!root.active && !root.lingering)
            return;
        root.stopVoice();
        root.heardHead = "";
        root.liveText = "";
        holdTimer.stop();
        // With "Hey Velly" the ears stay: they only forget what they heard.
        earsCtl(Config.velly.wakeWord ? "reset" : "stop");
        root.writeSession(false);
        root.active = false;
        heartbeat.stop();
        root.arm = 0;
        // One last errand: the brain writes the session into memory, then
        // leaves on its own. The linger is only a safety net.
        root.request("sleep", "");
        root.lingering = true;
        linger.stop();
        linger.restart();
    }

    function toggle(): void {
        if (root.active)
            root.sleep();
        else
            root.wake();
    }

    // SUPER+A (Binds "velly"): wake her AND show her — the island comes down
    // on the screen you are looking at, already listening. Pressed again
    // while she is up: she goes back to sleep and the island folds away.
    function summon(): void {
        if (!Config.velly.enabled || Locker.locked)
            return;
        if (root.active && Panels.islandScreen !== "") {
            root.sleep();
            Panels.islandScreen = "";
            Sfx.close();
            return;
        }
        root.wake();
        root.wantIsland = true;
        const scr = Hypr.focusedScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
        if (scr)
            Panels.islandScreen = scr.name;
        // the island may already be up on that screen: then nothing changes
        // there, so say it once more
        root.wantIslandChanged();
    }

    // The question she asked before a dangerous action (lock, reboot, a
    // command): what it is, and two ways to answer — the buttons in the
    // island, or simply saying "ja" / "nein".
    readonly property var confirm: {
        const c = root.state.confirm;
        if (!c || !c.tool)
            return null;
        return Number(c.until ?? 0) > Date.now() - 1000 ? c : null;
    }
    function confirmAnswer(yes: bool): void {
        root.ask(yes ? "Ja." : "Nein.");
    }

    function ask(text: string): void {
        const line = `${text ?? ""}`.trim();
        if (line.length === 0)
            return;
        if (!root.active)
            root.wake();
        root.stopVoice();
        root.writeSession(true);
        root.barged = false;
        root.lastAsk = line;
        root.lastAskAt = Date.now();
        root.request("ask", line);
        Sfx.cursor();
    }

    // ─────────────────────────────────────────── one sentence, two breaths
    //  The ears cut at a pause, and people pause mid-sentence: "…und
    //  vielleicht kannst du mir" went out on its own (measured) and got an
    //  answer to half a question. A piece that clearly stops mid-sentence
    //  waits a moment for the rest, and both halves are asked as one. A
    //  second half that arrives while she is still thinking about the first
    //  (no word said, no tool run yet) replaces it — the brain drops the old
    //  turn when a newer request lands.
    property string lastAsk: ""
    property real lastAskAt: 0
    property string heardHead: ""
    property real heardAt: 0

    function unfinished(line: string): bool {
        const s = `${line ?? ""}`.trim();
        if (/(\.\.\.|…|,|-|–)$/.test(s))
            return true;
        const t = s.replace(/[.!?;:]+$/, "").trim().toLowerCase();
        if (t.split(/\s+/).length < 2)
            return false;
        if (/\b(und|oder|aber|weil|dass|daß|ob|wenn|falls|sondern|sowie|damit|bzw|den|dem|des|einen|einem|einer|eine|ein|meine|meinen|meinem|meiner|deine|deinen|deinem|zum|zur|für|fuer|von|vom|bei|beim|im|am)$/.test(t))
            return true;
        if (/\b(kannst|könntest|koenntest|würdest|wuerdest|willst|magst|sollst)\s+du(\s+(mir|mich|uns|bitte|mal|vielleicht|noch))*$/.test(t))
            return true;
        return /\bich\s+(möchte|moechte|will|würde|wuerde|hätte|haette|brauche)(\s+(gern|gerne|bitte|mal|noch|heute|jetzt|auch))*$/.test(t);
    }

    function heard(text: string): void {
        let line = `${text ?? ""}`.trim();
        if (line.length === 0)
            return;
        if (root.heardHead.length > 0) {
            line = `${root.heardHead} ${line}`;
            root.heardHead = "";
            holdTimer.stop();
        } else if (root.phase === "thinking" && root.answer.length === 0 && root.tools.length === 0 && root.lastAsk.length > 0 && Date.now() - root.lastAskAt < 9000) {
            line = `${root.lastAsk} ${line}`;
        }
        if (root.unfinished(line) && line.split(/\s+/).length < 40) {
            root.heardHead = line;
            root.heardAt = Date.now();
            holdTimer.restart();
            return;
        }
        root.ask(line);
    }

    Timer {
        id: holdTimer

        interval: 2600
        onTriggered: {
            if (root.heardHead.length === 0)
                return;
            // Still talking, or the rest is being recognised right now: the
            // other half is on its way — up to nine seconds in all.
            if ((root.talking || root.sttBusy) && Date.now() - root.heardAt < 9000) {
                holdTimer.restart();
                return;
            }
            const line = root.heardHead;
            root.heardHead = "";
            root.ask(line);
        }
    }

    function cancel(): void {
        root.request("cancel", "");
    }

    function request(kind: string, text: string, fields: var): void {
        root.reqId++;
        const payload = {
            id: root.reqId,
            kind: kind,
            text: text,
            at: Date.now()
        };
        if (fields)
            payload.fields = fields;
        reqFile.setText(JSON.stringify(payload));
    }

    property int reqId: 0

    function writeSession(open: bool): void {
        const until = Date.now() + (open ? 300000 : 0);
        sessionFile.setText(JSON.stringify({
            active: open,
            until: until,
            at: Date.now(),
            pid: open ? 1 : 0
        }));
    }

    function earsCtl(word: string): void {
        ctlFile.setText(word);
    }

    // ─────────────────────────────────────────────────────────── the senses
    function transcribe(path: string): void {
        if (!path)
            return;
        stt.target = path;
        root.sttBusy = true;
        stt.command = ["python3", root.brainScript, "--stt", path];
        stt.running = true;
    }

    property bool sttBusy: false
    property string sttError: ""
    // ── live captions: the sentence so far, while you are still saying it
    //  (velvet-ears writes a snapshot every ~1 s, `velvet-ai --stt-live`
    //  reads it on the graphics card). Off for the rest of a session when the
    //  card cannot do it (no Vulkan build, or a game holds it).
    property string liveText: ""
    property int liveSeq: 0
    property bool liveOff: false
    // When this session began: the island shows this conversation, not last
    // week's (the brain sees the same twenty minutes).
    property real wokeAt: 0
    // Set when you talked over her and the recording was her own voice coming
    // back: the island says so, so the silence has an explanation.
    property bool barged: false

    function ingestStt(raw: string): void {
        root.sttBusy = false;
        root.liveText = "";
        let data = null;
        try {
            data = JSON.parse(`${raw ?? ""}`.trim() || "{}");
        } catch (e) {
            root.sttError = "die Erkennung hat nichts Lesbares geantwortet";
            return;
        }
        if (data.ok && `${data.text ?? ""}`.trim().length > 0) {
            root.sttError = "";
            root.heard(data.text);
        } else {
            const why = `${data.error ?? "heard nothing"}`;
            root.sttError = why === "no ears" ? "keine Spracherkennung — tippe stattdessen" : why;
        }
    }

    function say(text: string): void {
        const line = `${text ?? ""}`.trim();
        if (!Config.velly.voice || line.length === 0)
            return;
        voice.command = ["python3", root.voiceScript, "--say", line.slice(0, 600)];
        voice.running = true;
    }

    function stopVoice(): void {
        voiceStop.running = false;
        voiceStop.running = true;
    }

    // ──────────────────────────────────────────────────────────── the hands
    //  By the time anything here runs, ai-session.json is open — the Python
    //  side checks it again per tool call, so these are conveniences, not the
    //  gate.
    // Due reminders: a chime, a long toast, and her voice — the notification
    // itself comes from the sleeper (notify-send), so it also lands in the
    // notification history.
    function remind(text: string): void {
        const line = `${text ?? ""}`.trim();
        if (line.length === 0)
            return;
        Sfx.open();
        Toast.show(line.toUpperCase(), "warn", 9000);
        if (Config.velly.voice)
            root.say(line);
    }

    function toast(text: string, kind: string): void {
        const k = kind === "ok" || kind === "warn" || kind === "error" ? kind : "info";
        Toast.show(text, k, k === "error" ? 5000 : 3000);
    }

    function mediaInfo(): string {
        if (!root.mpris)
            return "nothing";
        if (!(root.mpris.has ?? false))
            return "nothing";
        return `${root.mpris.title}${root.mpris.artist ? " — " + root.mpris.artist : ""}${root.mpris.playing ? " (playing)" : " (paused)"}`;
    }

    // Newest first, plain data only — the history holds records, never live
    // notification objects (see Notifs.qml).
    function notifsJson(): string {
        const list = Notifs.history ?? [];
        const out = [];
        for (let i = 0; i < Math.min(8, list.length); i++) {
            const n = list[i];
            out.push({
                app: `${n.appName ?? ""}`,
                summary: `${n.summary ?? ""}`,
                body: `${n.body ?? ""}`.slice(0, 200),
                time: Number(n.time ?? 0),
                seen: n.seen === true
            });
        }
        return JSON.stringify(out);
    }

    function media(action: string): string {
        if (!root.mpris)
            return "no MPRIS here";
        if (!(root.mpris.has ?? false))
            return "nothing playing";
        switch (action) {
        case "play":
            if (!root.mpris.playing)
                root.mpris.toggle();
            break;
        case "pause":
            if (root.mpris.playing)
                root.mpris.toggle();
            break;
        case "next":
            root.mpris.next();
            break;
        case "previous":
            root.mpris.prev();
            break;
        default:
            return `unknown action ${action}`;
        }
        return "ok";
    }

    // The MPRIS bridge is created on demand and exactly once — the same
    // quarantine trick the island's own module uses, so a build without the
    // service loses this one function rather than the shell.
    property var mpris: null
    property bool mprisTried: false

    function makeMpris(): void {
        if (root.mpris !== null || root.mprisTried)
            return;
        root.mprisTried = true;
        const comp = Qt.createComponent(Qt.resolvedUrl("MprisBridge.qml"), Component.PreferSynchronous);
        if (comp.status === Component.Error) {
            console.warn("Velvet: velly — MPRIS unavailable:", comp.errorString());
            return;
        }
        const obj = comp.createObject(root);
        if (obj)
            root.mpris = obj;
    }

    function wallpaper(action: string): void {
        if (action === "next")
            Wallpapers.next();
        else
            Wallpapers.random();
    }

    function setting(key: string): void {
        Panels.openSettingsKey(key);
    }

    // ── her hands on the shell itself (velvet-ai settings.find / settings.set)
    //  The same rows the settings window shows (Schema.flat), searched by
    //  words, and set through the same door the window uses (Bridge.set), so
    //  a look change or a live value behaves exactly as if clicked. A few
    //  switches stay the user's: her own safety catch, her brain, and the
    //  locks that could shut the user out.
    readonly property var settingsDenied: ["velly.confirmDanger", "velly.enabled", "velly.provider", "velly.model", "lock.useBuiltin", "lock.lockOnStart", "lock.listenToLogind", "lock.pamConfig"]

    // The settings' one-click rows she may press herself: they show, tidy or
    // reset a look — nothing here deletes, uninstalls, powers off or touches
    // her own setup (those have their own tools with a yes, or stay yours).
    readonly property var actionsAllowed: ["islandJoinFrame", "resetLauncherLook", "resetThisLook", "resetSoftArrangement", "randomWallpaper", "rescanWallpapers", "refetchLyrics", "saveLook", "openMap", "openWheel", "openLauncher", "openQuick", "openHome", "openWorkflow", "openDesktopTab", "openWallpaperTab", "openBluetooth", "openWelcome"]

    function settingId(item: var): string {
        if (item.kind === "action")
            return item.fn && !item.exec && root.actionsAllowed.indexOf(`${item.fn}`) >= 0 ? `action:${item.fn}` : "";
        return item.key ? `${item.key}` : (item.live ? `live:${item.live}` : "");
    }

    function settingInfo(entry: var): var {
        const it = entry.item;
        const out = {
            key: root.settingId(it),
            name: `${it.name ?? ""}`,
            where: `${entry.path ?? ""}`,
            kind: `${it.kind}`
        };
        if (it.kind === "action")
            out.does = "one click — settings.set runs it (no value)";
        else
            out.value = Bridge.get(it);
        const help = `${it.help ?? it.sub ?? ""}`;
        if (help.length > 0)
            out.help = help.length > 240 ? help.slice(0, 237) + "…" : help;
        if (it.kind === "choice")
            out.options = (it.options ?? []).map(o => ({ value: o.value, label: o.label }));
        if (it.kind === "slider") {
            out.min = it.min;
            out.max = it.max;
            if (it.unit)
                out.unit = it.unit;
            if (it.fmt === "percent")
                out.note = "a fraction: 1 = 100 %";
        }
        return out;
    }

    function findSettings(query: string): string {
        const words = `${query ?? ""}`.toLowerCase().split(/[^a-z0-9äöüß+]+/).filter(w => w.length > 1);
        if (words.length === 0)
            return JSON.stringify({ settings: [], shortcuts: [] });
        const flat = Schema.flat;
        const hits = [];
        for (let i = 0; i < flat.length; i++) {
            const it = flat[i].item;
            if (["toggle", "slider", "choice", "colour", "action"].indexOf(it.kind) < 0 || root.settingId(it) === "")
                continue;
            // `aka`: what people call a row besides its name ("island colour"
            // for ISLAND THEME)
            const name = `${it.name ?? ""} ${it.aka ?? ""}`.toLowerCase();
            const hay = `${name} ${it.sub ?? ""} ${it.help ?? ""} ${flat[i].path ?? ""} ${it.key ?? ""} ${(it.options ?? []).map(o => o.label).join(" ")}`.toLowerCase();
            let score = 0;
            // the key's own last word ("frame" in bar.frame) is the row's
            // name for that thing: "frame" must find SCREEN FRAME before
            // FRAME COLOUR and FRAME SHADOW
            const tail = `${it.key ?? it.fn ?? ""}`.split(".").pop().toLowerCase();
            for (let w = 0; w < words.length; w++) {
                if (name.indexOf(words[w]) >= 0)
                    score += 3;
                else if (hay.indexOf(words[w]) >= 0)
                    score += 1;
                if (tail === words[w])
                    score += 2;
            }
            if (name === words.join(" "))
                score += 4;
            if (score > 0)
                hits.push({ s: score, e: flat[i] });
        }
        hits.sort((a, b) => b.s - a.s);
        const best = hits.length > 0 ? hits[0].s : 0;
        const settings = hits.filter(h => h.s >= Math.max(1, best - 2)).slice(0, 7).map(h => root.settingInfo(h.e));
        const shortcuts = [];
        const sections = Shortcuts.sections;
        for (let i = 0; i < sections.length && shortcuts.length < 4; i++) {
            const keys = sections[i].keys ?? [];
            for (let k = 0; k < keys.length && shortcuts.length < 4; k++) {
                const what = `${keys[k].v ?? ""}`.toLowerCase();
                if (words.filter(w => what.indexOf(w) >= 0).length >= Math.min(2, words.length))
                    shortcuts.push({ keys: `${keys[k].k}`, does: `${keys[k].v}`, where: `${sections[i].name}` });
            }
        }
        return JSON.stringify({ settings: settings, shortcuts: shortcuts });
    }

    function applySetting(key: string, jsonValue: string): string {
        const flat = Schema.flat;
        let entry = null;
        if (`${key}`.startsWith("action:")) {
            for (let i = 0; i < flat.length; i++)
                if (flat[i].item.kind === "action" && root.settingId(flat[i].item) === key) {
                    entry = flat[i];
                    break;
                }
            if (entry === null)
                return JSON.stringify({ ok: false, error: `no action "${key}" she may press — look it up with settings.find` });
            Bridge.act(entry.item);
            return JSON.stringify({ ok: true, key: key, name: `${entry.item.name ?? ""}`, where: `${entry.path ?? ""}`, done: true });
        }
        for (let i = 0; i < flat.length; i++)
            if (root.settingId(flat[i].item) === key && ["toggle", "slider", "choice", "colour"].indexOf(flat[i].item.kind) >= 0) {
                entry = flat[i];
                break;
            }
        if (entry === null)
            return JSON.stringify({ ok: false, error: `no setting "${key}" right now — look it up with settings.find (some only appear once another one is set)` });
        if (root.settingsDenied.indexOf(key) >= 0)
            return JSON.stringify({ ok: false, error: "that switch stays with the user — tell them where it is instead" });
        const it = entry.item;
        let v;
        try {
            v = JSON.parse(jsonValue);
        } catch (e) {
            v = `${jsonValue ?? ""}`;
        }
        if (it.kind === "toggle") {
            if (typeof v === "string")
                v = /^(true|on|an|ein|ja|1|yes)$/i.test(v.trim()) ? true : (/^(false|off|aus|nein|0|no)$/i.test(v.trim()) ? false : null);
            if (typeof v === "number")
                v = v !== 0;
            if (typeof v !== "boolean")
                return JSON.stringify({ ok: false, error: "a switch takes true or false" });
        } else if (it.kind === "slider") {
            v = Number(v);
            if (!isFinite(v))
                return JSON.stringify({ ok: false, error: `a number between ${it.min} and ${it.max}` });
            v = Math.max(it.min ?? v, Math.min(it.max ?? v, v));
            if (it.step)
                v = Math.round(v / it.step) * it.step;
            if (it.fmt === "int")
                v = Math.round(v);
            v = Math.round(v * 10000) / 10000;
        } else if (it.kind === "choice") {
            const opts = it.options ?? [];
            const found = opts.find(o => `${o.value}` === `${v}`) ?? opts.find(o => `${o.label}`.toLowerCase() === `${v}`.toLowerCase());
            if (!found)
                return JSON.stringify({ ok: false, error: "one of: " + opts.map(o => `${o.value} (${o.label})`).join(", ") });
            v = found.value;
        } else if (it.kind === "colour") {
            if (!/^#[0-9a-fA-F]{6}$/.test(`${v}`))
                return JSON.stringify({ ok: false, error: "a colour as #rrggbb" });
        }
        const old = Bridge.get(it);
        Bridge.set(it, v);
        return JSON.stringify({ ok: true, key: key, name: `${it.name}`, where: `${entry.path}`, old: old, now: Bridge.get(it) });
    }

    function setKey(key: string, jsonValue: string): void {
        try {
            Config.set(key, JSON.parse(jsonValue));
        } catch (e) {
            console.warn("Velvet: velly — bad value for", key, jsonValue);
        }
    }

    // Only while she is awake (or finishing her last errand): the brain
    // checks its session before every tool, and the shell's own door now
    // checks too — nothing outside a session can run a line through her.
    function runCmd(command: string): string {
        if (!command || !(root.active || root.lingering))
            return "";
        Actions.run(command);
        return "ok";
    }

    function scene(action: string): void {
        if (action === "capture")
            Scenes.captureOpen();
        else if (action === "clear") {
            Scenes.clearScene();
            Toast.show("DESKTOP CLEARED FOR THIS WALLPAPER", "info", 2600);
        } else
            Scenes.launchAll(false);
    }

    // The whole desktop as one object — what the model is told about the
    // world before every answer, and what `ipc call velly state` prints.
    function snapshot(): string {
        const spaces = [];
        const list = Hypr.workspaces ?? [];
        for (let i = 0; i < list.length; i++)
            spaces.push({ id: list[i].id, windows: list[i].lastIpcObject?.windows ?? 0 });
        const open = [];
        for (let i = 0; i < Math.min(5, Tasks.open.length); i++)
            open.push(`${Tasks.open[i].id}: ${Tasks.open[i].text}`);
        return JSON.stringify({
            time: Qt.formatDateTime(new Date(), "HH:mm ddd"),
            workspace: Hypr.activeWsId,
            workspaces: spaces,
            activeWindow: `${Hypr.activeTitle}`.slice(0, 70),
            windows: Hypr.windowList(Hypr.activeWsId).length,
            volume: Audio.volumePercent,
            muted: Audio.muted,
            microphone: Audio.micMuted ? "muted" : "live",
            brightness: Math.round(Brightness.brightness * 100),
            focus: Focus.active,
            doNotDisturb: Notifs.dnd,
            notifs: Notifs.unread,
            tasks: {
                open: Tasks.openCount,
                done: Tasks.doneCount,
                next: open
            },
            weather: Weather.ready ? `${Math.round(Weather.temperature)}°C ${Weather.description}` : "",
            media: root.mediaInfo(),
            wallpaper: Wallpapers.basename(Config.wallpaper.current),
            phase: root.phase,
            facts: root.facts
        });
    }

    function status(): string {
        return JSON.stringify({
            active: root.active,
            phase: root.phase,
            brain: root.brain,
            brainOk: root.brainOk,
            brainReady: root.state.brainReady === true,
            brainError: `${root.state.brainError ?? ""}`,
            model: root.model,
            tier: root.activeTier,
            chosen: root.chosenTier,
            tierNote: root.tierNote,
            brainLine: root.brainLine,
            forceTier: root.forceTier,
            fits: root.tierFit(root.chosenTier),
            forced: root.local.forced === true,
            vramFreeMb: root.vramFreeMb,
            next: root.nextLabel,
            pill: root.pill,
            installing: root.installing,
            setupOpen: root.setupOpen,
            voice: root.voiceEngine,
            ears: root.earsAvailable,
            listening: root.listening,
            facts: root.facts,
            sessions: root.sessions,
            stt: root.sttError,
            error: root.errorText
        });
    }

    // ─────────────────────────────────────────────────────────── the engine room
    //  The local brain is a download, not a key. The island starts
    //  bin/velvet-local once and then reads its progress file — the percentage
    //  and the label on screen are the file's, never a guess made here. When
    //  it lands, the provider is written and probed like any other.
    property var install: ({})
    property var local: ({})
    property bool installSettled: false

    // The engine room's four sizes. velvet-local owns the files and the URLs;
    // this is the label and the bill the user sees while choosing.
    readonly property var brainTiers: [
        { key: "klein", label: "QWEN3-4B", mb: 2382, note: "SCHNELL UND GENÜGSAM · LÄUFT IMMER" },
        { key: "mittel", label: "QWEN3-8B", mb: 5000, note: "DEUTLICH KLÜGER · PASST NEBEN DEN DESKTOP" },
        { key: "gross", label: "QWEN3-14B", mb: 9000, note: "DIE KLÜGSTE OPTION HIER · WILL DIE GPU" },
        { key: "max", label: "GPT-OSS-20B", mb: 11600, note: "MoE · SEHR KLUG · TEILT DIE GPU MIT DIR" }
    ]

    readonly property string activeTier: `${root.local.tier ?? ""}`
    readonly property string chosenTier: `${root.local.chosen ?? root.local.tier ?? ""}`
    readonly property real vramFreeMb: Number(root.local.vram_free_mb ?? 0)
    readonly property bool forceTier: Config.velly.forceTier === true

    // What the engine room WILL put on the card at the next wake: the chosen
    // size when it fits, or when it is close (llama.cpp's fit then moves just
    // a few layers — for the MoE 20B only expert layers — into RAM), or when
    // the override is on; otherwise the biggest substitute. Mirrored from
    // velvet-local serve(), so the card and the log never disagree.
    function isClose(tier: var): bool {
        return root.vramFreeMb >= tier.mb * (tier.key === "max" ? 0.66 : 0.85);
    }

    readonly property var nextTier: {
        const byKey = k => root.brainTiers.find(t => t.key === k);
        const want = byKey(root.chosenTier);
        if (!want || root.forceTier || root.vramFreeMb <= 0)
            return want;
        if (want.mb + 1300 <= root.vramFreeMb || root.isClose(want))
            return want;
        const order = ["gross", "mittel", "klein"];
        for (let i = 0; i < order.length; i++) {
            const alt = byKey(order[i]);
            if (alt && alt.key !== want.key && alt.mb + 1300 <= root.vramFreeMb)
                return alt;
        }
        return want;
    }
    readonly property string nextLabel: root.nextTier ? root.nextTier.label : (root.activeTier.length > 0 ? root.localTierLabel : "")

    // How a size would land right now: 0 unknown, 1 fits, 2 tight, 3 too big.
    // The card reads this, and the engine room makes the same call with the
    // same 1400 MB reserve for the context — one number, two places.
    function tierFit(key: string): int {
        const tier = root.brainTiers.find(t => t.key === key);
        const free = root.vramFreeMb;
        if (!tier || free <= 0)
            return 0;
        if (tier.mb + 1300 <= free)
            return 1;
        if (root.isClose(tier))
            return 2;
        return 3;
    }

    // The override a game would call "apply anyway". Her own size then runs
    // even when it is far from fitting (much of it in RAM) — and the engine
    // room says plain how much landed where.
    function setForce(on: bool): void {
        root.setKey("velly.forceTier", on ? "true" : "false");
        root.setupNote = on ? "TROTZDEM  ·  DEINE GRÖSSE LÄUFT, AUCH WENN SIE LANGSAM IST" : "AUTOMATIK  ·  DIE GRÖSSTE GRÖSSE, DIE PASST";
        // A server that is already up was started by the old rule: take it
        // down, and the next wake brings it back under the new one.
        root.runLocal(["stop"]);
        root.toast(on ? "TROTZDEM-MODUS AN" : "AUTOMATIK AN", "ok");
    }

    // The note under the size buttons: the running tier's own line — or, when
    // the chosen one does not fit right now, both truths in one row. The engine
    // room refuses to run a 20B on 4 GB of free VRAM, and this says so.
    readonly property string forcedNote: {
        // The engine room's own words, upper-cased: "ein paar experten im
        // ram", "20 von 24 schichten auf der gpu", "viel im ram (langsam)" …
        const note = `${root.local.note ?? ""}`.trim();
        return note.length > 0 ? note.toUpperCase() : "";
    }

    readonly property string tierNote: {
        const run = root.brainTiers.find(t => t.key === root.activeTier);
        const want = root.brainTiers.find(t => t.key === root.chosenTier);
        const free = root.vramFreeMb > 0 ? `${Math.round(root.vramFreeMb / 1024)}G FREI` : "";
        const up = `${root.local.state ?? ""}` === "up";
        const note = root.forcedNote;
        // What is running right now, with the engine room's own words for it.
        if (want && up && note.length > 0 && `${root.local.tier ?? ""}` === want.key)
            return `${want.label} LÄUFT  ·  ${note}`;
        if (want && root.forceTier)
            return `${want.label}  ·  TROTZDEM-MODUS AN  ·  DEINE GRÖSSE LÄUFT BEIM WECKEN`;
        if (want && root.nextTier && root.nextTier.key !== want.key)
            return `${want.label} IST FERTIG  ·  BRAUCHT ~${Math.round(want.mb / 1024 + 1.4)}G VRAM${free ? `  ·  ${free}` : ""}  ·  BEIM WECKEN: ${root.nextTier.label}`;
        if (run && want && run.key !== want.key)
            return `${want.label} IST FERTIG  ·  BRAUCHT ~${Math.round(want.mb / 1024 + 1.4)}G VRAM${free ? `  ·  ${free}` : ""}  ·  BEIM WECKEN: ${root.nextLabel}`;
        return run ? run.note : "";
    }

    readonly property string localTierLabel: {
        const tier = root.brainTiers.find(t => t.key === root.activeTier);
        return tier ? tier.label : `${root.local.model ?? "—"}`;
    }

    // One honest line about what is thinking: provider, size, context, speed.
    readonly property string brainLine: {
        if (root.installing)
            return `${root.installLabel || "LADEN"}  ${root.installPct}%`;
        const bits = [];
        if (root.brain === "local" || root.activeTier.length > 0) {
            bits.push("LOKAL", root.localTierLabel);
            if (root.local.ctx)
                bits.push(`${root.local.ctx} KONTEXT`);
            if (root.local.ngl === 0)
                bits.push("CPU");
            else if (root.local.ngl)
                bits.push(`GPU ${root.local.ngl} LAYER`);
            else if (`${root.local.state ?? ""}` === "up")
                bits.push(root.forcedNote.length > 0 ? root.forcedNote : "GANZ AUF DER GPU");
            if (root.local.vram_free_mb)
                bits.push(`${Math.round(root.local.vram_free_mb / 1024)}G VRAM FREI`);
            return bits.join("  ·  ");
        }
        if (root.brainOk)
            return `${(root.provider || "").toUpperCase()}  ·  ${(root.model || "STANDARD").toUpperCase()}`;
        if (root.brainSkills)
            return "NOCH KEIN GEHIRN  ·  LOKAL LADEN ODER EIN SCHLÜSSEL";
        return "KEIN GEHIRN";
    }
    readonly property bool installing: {
        if ((root.install.running ?? false) !== true)
            return false;
        // The writer of that file can die without a last word — a shell restart
        // mid-download leaves `running: true` behind for good. The file is
        // rewritten several times a second while anything really runs, so a
        // silence of ninety seconds is not a download, it is a corpse.
        const at = Number(root.install.at ?? 0);
        return at <= 0 || Date.now() - at < 90000;
    }
    readonly property int installPct: Number(root.install.pct ?? 0)
    readonly property string installLabel: `${root.install.label ?? ""}`
    readonly property string installDetail: `${root.install.detail ?? ""}`
    readonly property string installError: `${root.install.error ?? ""}`

    function runLocal(args: var): void {
        if (localInstall.running)
            return;
        root.installSettled = false;
        root.install = ({});
        installFile.reload();
        localInstall.command = ["python3", root.localScript].concat(args);
        localInstall.running = true;
    }

    function installLocal(): void {
        root.setupNote = "ENGINE WIRD GELADEN — EINMALIG EIN PAAR MINUTEN, DANN FÜR IMMER LOKAL";
        root.runLocal(["ensure"]);
    }

    function brainTier(name: string): void {
        const tier = root.brainTiers.find(t => t.key === name);
        root.setupNote = `MODELL-GRÖSSE  ·  ${tier ? tier.label : name}  ·  ${tier ? tier.mb / 1024 + " GB" : ""}`;
        root.runLocal(["brain", name]);
    }

    // A provider chip is a decision, so it acts: keyless providers are written
    // and probed right away — no silent fields, no "press Enter after choosing".
    // It writes BOTH stores on purpose: the island's SETUP keeps ai.json, the
    // settings page keeps config.json, and while they disagreed the settings
    // page won — which is how "I picked LOCAL" ended up talking to DeepSeek.
    function setProvider(name: string): void {
        const keyless = name === "local" || name === "auto";
        root.setupProvider = name;
        root.setKey("velly.provider", JSON.stringify(name));
        if (keyless)
            root.setKey("velly.model", JSON.stringify(""));
        root.writeAi({ provider: name });
        if (keyless) {
            root.setupNote = `${name.toUpperCase()} GESPEICHERT  ·  TESTE…`;
            root.probe();
        } else {
            root.setupNote = `${name.toUpperCase()} BRAUCHT EINEN SCHLÜSSEL — FELD UNTEN, DANN ENTER`;
        }
    }

    function settleInstall(): void {
        if (root.installSettled)
            return;
        root.installSettled = true;
        if (root.install.ok ?? false) {
            root.setupNote = "LOKAL BEREIT  ·  OHNE SCHLÜSSEL";
            root.toast("LOKALES GEHIRN BEREIT", "ok");
            root.writeAi({
                provider: "local"
            });
            root.probe();
        } else {
            root.setupNote = `FEHLER  ·  ${root.installError || "DOWNLOAD ABGEBROCHEN"}`;
            root.toast("DOWNLOAD FEHLGESCHLAGEN", "error");
        }
    }

    Process {
        id: localInstall

        command: ["python3", root.localScript, "ensure"]
    }

    FileView {
        id: localFile

        path: root.localPath
        printErrors: false
        preload: true
        watchChanges: true
        onTextChanged: {
            const data = root.parseJson(text());
            if (data !== null)
                root.local = data;
        }
    }

    FileView {
        id: installFile

        path: root.installPath
        printErrors: false
        preload: true
        watchChanges: true
        onTextChanged: {
            const data = root.parseJson(text());
            if (data === null)
                return;
            root.install = data;
            // Only a run that JUST finished is an event. A file that says
            // "done" from hours ago is history — and reacting to it started a
            // 5 GB model (and its VRAM) on every single shell start.
            if ((data.done ?? false) && Date.now() - Number(data.at ?? 0) < 300000)
                root.settleInstall();
        }
    }

    // ───────────────────────────────────────────────────────────── the voice
    //  Piper's German shelf. The empty first entry means "whatever is
    //  installed"; picking anything else is a name, and the engine fetches a
    //  missing voice once by itself. Two arrows and a sentence to hear it —
    //  that is the whole voice setting.
    //  The natural voices first — real speakers, Kartoffel-Orpheus on the
    //  graphics card — then Piper's German shelf as the light fallback.
    readonly property var voiceNames: ["natural:Sophie", "natural:Marie", "natural:Mia", "natural:Maria",
                                       "natural:Sophia", "natural:Lina", "natural:Lea", "natural:Julian",
                                       "natural:Jakob", "natural:Felix", "natural:Jonas", "natural:Noah",
                                       "piper:", "piper:de_DE-thorsten-high", "piper:de_DE-thorsten-medium",
                                       "piper:de_DE-thorsten_emotional-medium", "piper:de_DE-kerstin-low",
                                       "piper:de_DE-eva_k-x_low", "piper:de_DE-ramona-low", "piper:de_DE-mls-medium",
                                       "piper:de_DE-karlsson-low", "piper:de_DE-pavoque-low"]

    readonly property string voiceCurrent: {
        const engine = `${Config.velly.voiceEngine ?? "auto"}`;
        if (engine === "natural" || engine === "orpheus")
            return `natural:${Config.velly.naturalVoice || "Sophie"}`;
        return `piper:${Config.velly.voiceName ?? ""}`;
    }

    readonly property string voiceLabel: {
        const cur = root.voiceCurrent;
        if (cur.startsWith("natural:"))
            return `NATÜRLICH · ${cur.slice(8).toUpperCase()}`;
        const name = cur.slice(6);
        return name.length === 0 ? "PIPER · AUTO" : "PIPER · " + name.replace(/^de_DE-/, "").toUpperCase();
    }

    function voiceStep(step: int): void {
        const list = root.voiceNames;
        let at = list.indexOf(root.voiceCurrent);
        if (at < 0)
            at = 0;
        at = (at + step + list.length) % list.length;
        const pick = `${list[at] ?? ""}`;
        if (pick.startsWith("natural:")) {
            root.setKey("velly.voiceEngine", JSON.stringify("natural"));
            root.setKey("velly.naturalVoice", JSON.stringify(pick.slice(8)));
        } else {
            root.setKey("velly.voiceEngine", JSON.stringify("piper"));
            root.setKey("velly.voiceName", JSON.stringify(pick.slice(6)));
        }
        // A beat later, so the sentence is spoken by the voice just picked.
        voicePreviewLater.restart();
    }

    Timer {
        id: voicePreviewLater

        interval: 350
        onTriggered: root.say(root.voiceCurrent.startsWith("natural:") ? `Hi, ich bin ${root.voiceCurrent.slice(8)}. Gefällt dir meine Stimme?` : "So klinge ich. Passt das?")
    }

    function voicePreview(): void {
        root.say("So klinge ich. Passt das?");
    }

    // ─────────────────────────────────────────────────────── the setup wizard
    //  The island draws it; the service holds it, so a settings row or an IPC
    //  call can open the same wizard from anywhere.
    property bool setupOpen: false
    property string setupProvider: ""
    property string setupField: "key"
    property string setupNote: ""

    // Enter in the wizard: write the field, then prove it works. The write
    // goes through bin/velvet-ai --set-fields (0600), and the probe is a real
    // round trip to the provider — no "looks fine to me".
    function setupCommit(text: string): void {
        const value = `${text ?? ""}`.trim();
        if (value.length === 0) {
            root.setupNote = "NICHTS EINGETIPPT";
            return;
        }
        if (root.setupField === "key") {
            const provider = `${root.setupProvider || ""}`;
            if (provider.length > 0) {
                root.setKey("velly.provider", JSON.stringify(provider));
                if (provider === "local" || provider === "auto")
                    root.setKey("velly.model", JSON.stringify(""));
            }
            root.writeAi({
                provider: provider,
                apiKey: value
            });
            root.setupNote = "SCHLÜSSEL GESPEICHERT  ·  RECHTE 600";
        } else {
            root.writeAi({
                model: value
            });
            root.setupNote = `MODELL  ·  ${value.toUpperCase()}`;
        }
        root.probe();
    }

    // Writing ai.json needs 0600 (it holds the key), so the fields go to the
    // brain as a request and Python decides the permissions. The shell never
    // writes that file itself — and never through argv, which the whole
    // machine can read.
    function writeAi(fields: var): void {
        root.request("setup", "", fields);
    }

    function probe(): void {
        aiProbe.running = false;
        aiProbe.running = true;
        root.probing = true;
    }

    property bool probing: false

    // ─────────────────────────────────────────────────────────── the process
    //  Both sidecars are children of this shell: they live exactly as long as
    //  the session does. A keeper timer starts them when the session wants
    //  them and stops them when it does not — and restarts them if one dies,
    //  which a plain `running:` binding cannot do (the process ending writes
    //  to that property and eats the binding).
    Process {
        id: brain

        command: ["python3", root.brainScript, "--daemon"]
        // Her log went nowhere: when a turn died (a NameError did exactly that
        // for a whole afternoon) the shell showed THINKING and the cause was
        // invisible. The collector keeps the last lines and hands them to the
        // journal when the brain leaves.
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = `${text ?? ""}`.trim();
                if (msg.length > 0)
                    console.warn("Velvet: velly — brain:", msg.split("\n").slice(-6).join(" | "));
            }
        }
    }

    Process {
        id: earsProc

        // The sensitivity dial is the user's, and it has to reach the ears
        // themselves — a slider that changes nothing is a lie.
        command: ["python3", root.earsScript, "--sensitivity", Number(Config.velly.earsSensitivity ?? 1).toFixed(2)]
    }

    Timer {
        interval: 700
        repeat: true
        running: true
        onTriggered: {
            // A brain in the middle of a turn is working, not idle: stopping it
            // there is how the island ended up stuck on THINKING. The stale
            // guard in `phase` keeps a dead one from holding this true.
            const wantBrain = root.active || root.lingering || root.phase === "thinking";
            if (wantBrain && !brain.running)
                brain.running = true;
            else if (!wantBrain && brain.running)
                brain.running = false;
            const wantEars = root.earsWanted;
            if (wantEars && !earsProc.running)
                earsProc.running = true;
            else if (!wantEars && earsProc.running)
                earsProc.running = false;
        }
    }

    Process {
        id: stt

        property string target: ""

        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: root.ingestStt(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = `${text ?? ""}`.trim();
                if (msg.length > 0)
                    console.warn("Velvet: velly — ears:", msg.split("\n")[0]);
            }
        }
    }

    Process {
        id: sttLive

        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data = null;
                try {
                    data = JSON.parse(`${text ?? ""}`.trim() || "{}");
                } catch (e) {
                    return;
                }
                if (data.ok && `${data.text ?? ""}`.trim().length > 0) {
                    // only while that sentence is still open or being read
                    if (root.talking || root.sttBusy || (root.ears.speaking ?? 0) === 1)
                        root.liveText = `${data.text}`.trim();
                } else if (`${data.error ?? ""}`.indexOf("gpu") >= 0 || `${data.error ?? ""}`.indexOf("card") >= 0) {
                    root.liveOff = true;
                }
            }
        }
    }

    Process {
        id: voice

        command: ["true"]
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = `${text ?? ""}`.trim();
                if (msg.length > 0)
                    console.warn("Velvet: velly — voice:", msg.split("\n")[0]);
            }
        }
    }

    // Speaks an answer while it is still being written (--follow): its own
    // process, so a dying `voice` from the last answer can never swallow it.
    Process {
        id: follower

        command: ["true"]
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = `${text ?? ""}`.trim();
                if (msg.length > 0)
                    console.warn("Velvet: velly — voice:", msg.split("\n").slice(-1)[0]);
            }
        }
    }

    Process {
        id: voiceWarm

        command: ["python3", root.voiceScript, "--warm"]
    }

    Process {
        id: filler

        command: ["python3", root.voiceScript, "--filler"]
    }

    // Thinking out loud: when a real question takes her longer than a beat,
    // she says so ("Hm, Moment.") — a cached clip, instant, like a person.
    Timer {
        id: fillerTimer

        interval: 1100
        onTriggered: {
            if (root.phase === "thinking" && root.answer.length === 0 && !root.speaking && Config.velly.voice && Config.velly.fillers) {
                filler.running = false;
                filler.running = true;
            }
        }
    }

    onPhaseChanged: {
        if (root.phase === "thinking")
            fillerTimer.restart();
        else
            fillerTimer.stop();
    }

    // "Hey Velly": while she sleeps, every utterance goes through the quick
    // recogniser; only one that names her wakes her — and whatever came
    // after her name is the question.
    Process {
        id: wakeStt

        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: root.ingestWake(text)
        }
    }

    function wakeCheck(path: string): void {
        if (wakeStt.running)
            return;
        wakeStt.command = ["python3", root.brainScript, "--stt-quick", path];
        wakeStt.running = true;
    }

    function ingestWake(raw: string): void {
        let data = null;
        try {
            data = JSON.parse(`${raw ?? ""}`.trim() || "{}");
        } catch (e) {
            return;
        }
        if (!data.wake || root.active || Locker.locked)
            return;
        const rest = `${data.rest ?? ""}`.trim();
        root.wake();
        if (rest.split(/\s+/).filter(w => w.length > 0).length >= 2)
            root.ask(rest);
        else
            Sfx.open();
    }

    Process {
        id: voiceStop

        command: ["python3", root.voiceScript, "--stop"]
    }

    Process {
        id: aiProbe

        command: ["python3", root.brainScript, "--probe"]
        stdout: StdioCollector {
            onStreamFinished: root.ingestProbe(text)
        }
    }

    function ingestProbe(raw: string): void {
        root.probing = false;
        let data = null;
        try {
            data = JSON.parse(`${raw ?? ""}`.trim() || "{}");
        } catch (e) {
            root.toast("BROKE: NO ANSWER", "error");
            return;
        }
        if (data.ok) {
            root.toast(`${(data.provider ?? "").toUpperCase()}  ·  ${data.model ?? ""} ANTWORTET`, "ok");
        } else {
            root.toast(`KEINE ANTWORT  ·  ${`${data.error ?? "?"}`.toUpperCase().slice(0, 80)}`, "error");
        }
    }

    // The conversation the island shows: the last few turns, newest last.
    readonly property var history: {
        const all = root.memory.history ?? [];
        // this conversation (and what came just before it), not last week's
        const since = root.wokeAt - 20 * 60 * 1000;
        const list = [];
        for (let i = 0; i < all.length; i++)
            if (Number(all[i].t ?? 0) >= since)
                list.push(all[i]);
        const out = [];
        for (let i = Math.max(0, list.length - 8); i < list.length; i++)
            out.push({
                role: list[i].role === "velly" ? "velly" : "user",
                text: `${list[i].text ?? ""}`
            });
        return out;
    }

    readonly property var factsList: {
        const out = [];
        const list = root.memory.facts ?? [];
        for (let i = Math.max(0, list.length - 6); i < list.length; i++)
            out.push(`${list[i].text ?? ""}`);
        return out;
    }

    // ──────────────────────────────────────────────────────────── the files
    Timer {
        id: heartbeat

        interval: 45000
        repeat: true
        onTriggered: {
            if (root.active)
                root.writeSession(true);
        }
    }

    Timer {
        id: linger

        interval: 40000
        repeat: false
        onTriggered: root.lingering = false
    }

    // The brain writes at up to 15 Hz while it streams; the ears at 30 Hz
    // while you are talking. Polling follows those rates instead of a fixed
    // one, so an asleep Velly costs nothing.
    readonly property bool busy: root.phase === "thinking" || root.phase === "speaking"

    Timer {
        running: root.active
        interval: root.busy ? 60 : 200
        repeat: true
        onTriggered: stateFile.reload()
    }

    Timer {
        // Also asleep, while "Hey Velly" listens.
        running: root.active || root.earsWanted
        interval: root.hearing || root.talking ? 33 : (root.active ? 160 : 250)
        repeat: true
        onTriggered: earsFile.reload()
    }

    // The engine room's two files, polled like the rest. `watchChanges` alone
    // did NOT do it: measured — ai-local.json was rewritten with tier "max"
    // and a fresh forced flag, and the island kept serving the value it had
    // read at shell start for a whole session (the card and the brain line
    // were frozen). Two small reads a second fix that for good.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: localFile.reload()
    }

    Timer {
        running: Velly.installing || localInstall.running
        interval: 500
        repeat: true
        onTriggered: installFile.reload()
    }

    Timer {
        running: root.active
        interval: root.speaking ? 50 : 500
        repeat: true
        onTriggered: speechFile.reload()
    }

    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false
        preload: true
        onTextChanged: root.ingestState(text())
    }

    FileView {
        id: earsFile

        path: root.earsPath
        printErrors: false
        preload: true
        onTextChanged: root.ingestEars(text())
    }

    FileView {
        id: speechFile

        path: root.speechPath
        printErrors: false
        preload: true
        onTextChanged: root.ingestSpeech(text())
    }

    FileView {
        id: memoryFile

        path: root.memoryPath
        printErrors: false
        preload: true
        watchChanges: true
        onLoaded: root.ingestMemory(text())
        onTextChanged: root.ingestMemory(text())
    }

    FileView {
        id: reqFile

        path: root.reqPath
        printErrors: false
    }

    FileView {
        id: sessionFile

        path: root.sessionPath
        printErrors: false
    }

    FileView {
        id: ctlFile

        path: root.ctlPath
        printErrors: false
    }

    function ingestState(raw: string): void {
        const data = parseJson(raw);
        if (data === null)
            return;
        root.state = data;
        // The brain writes "off" on its way out, after its last errand (the
        // learning pass). That is the signal the linger is over — without it
        // the keeper would faithfully restart a brain that just left.
        if (`${data.state ?? ""}` === "off") {
            root.lingering = false;
            linger.stop();
            // And make sure no second brain is started behind the first one's
            // back: the keeper only restarts what the session still wants.
            brain.running = false;
            earsProc.running = false;
        }
        if (`${data.brain ?? ""}`.length > 0 && `${data.brain}` !== "none")
            root.lastBrain = `${data.brain}`;
        // A finished answer is spoken, once — not on every poll. A longer one
        // starts with its first finished sentence while she is still writing
        // the rest: the voice follows the state file (velvet-voice --follow)
        // and says the remainder itself, so it is not started twice.
        const answer = `${data.answer ?? ""}`;
        const stage = `${data.state ?? ""}`;
        if (stage === "thinking" && data.turn !== root.spokenTurn && Config.velly.voice && /[.!?…]\s/.test(answer)) {
            root.spokenTurn = data.turn;
            filler.running = false;
            follower.command = ["python3", root.voiceScript, "--follow", `${data.turn}`];
            follower.running = false;
            follower.running = true;
        }
        if (stage === "answer" && answer.length > 0 && data.turn !== root.spokenTurn) {
            root.spokenTurn = data.turn;
            if (Config.velly.voice)
                root.say(answer);
        }
    }

    property int spokenTurn: -1
    property int consumedUtt: -1
    // Anything the ears wrote before this session opened is history: a WAV that
    // was still pending when the island closed used to be transcribed at the
    // next wake, so she answered a sentence from minutes ago.
    property real earsFloor: 0

    function ingestEars(raw: string): void {
        const data = parseJson(raw);
        if (data === null)
            return;
        // Old news — written by an ears process from a session that is over.
        if (Number(data.at ?? 0) < root.earsFloor)
            return;
        root.ears = data;
        const part = Number(data.partial ?? 0);
        if (root.active && !root.liveOff && part > 0 && part !== root.liveSeq && !sttLive.running && !root.sttBusy && !root.speaking && `${data.partialWav ?? ""}`.length > 0) {
            root.liveSeq = part;
            sttLive.command = ["python3", root.brainScript, "--stt-live", `${data.partialWav}`];
            sttLive.running = true;
        }
        // A finished utterance: hand it to the recogniser, then tell the ears
        // to forget it. Speaking over her cuts her off — that is what a
        // person does, and it is the fastest way to stop a long answer.
        const utt = Number(data.utterance ?? 0);
        if ((data.canSend ?? 0) === 1 && utt !== root.consumedUtt && `${data.wav ?? ""}`.length > 0) {
            root.consumedUtt = utt;
            const path = `${data.wav}`;
            if (!root.active) {
                // Asleep with "Hey Velly" on: this is only a wake check.
                root.earsCtl("reset");
                if (Config.velly.wakeWord)
                    root.wakeCheck(path);
                return;
            }
            const ms = Number(data.speechMs ?? 0);
            if (root.speaking) {
                // Barge-in. She stops — that is what a person does when you
                // talk over them — but the recording now holds her own voice
                // as well, so only a short one (a "stopp", a "warte") is
                // worth transcribing. A long one is her own tail coming back
                // through the microphone, and it is dropped.
                root.stopVoice();
                root.earsCtl("reset");
                if (ms < 900) {
                    root.transcribe(path);
                } else {
                    root.barged = true;
                    Sfx.back();
                }
                return;
            }
            root.earsCtl("reset");
            root.transcribe(path);
        }
    }

    function ingestSpeech(raw: string): void {
        const data = parseJson(raw);
        if (data === null)
            return;
        root.speech = data;
    }

    function ingestMemory(raw: string): void {
        const data = parseJson(raw);
        if (data === null)
            return;
        root.memory = data;
    }

    function parseJson(raw: string): var {
        const s = `${raw ?? ""}`.trim();
        if (s.length < 2)
            return null;
        try {
            const data = JSON.parse(s);
            return data && typeof data === "object" ? data : null;
        } catch (e) {
            // A half-written frame must not blank the island — keep the last
            // good one and wait for the next poll, exactly like Spectrum.
            return null;
        }
    }

    onActiveChanged: {
        if (root.active) {
            root.makeMpris();
            memoryFile.reload();
            stateFile.reload();
        } else {
            root.consumedUtt = -1;
            root.spokenTurn = -1;
        }
    }

    // A session that is somehow left behind (a crash, a kill) must not stay
    // open: the shell closes it on the way in, and the brain reads that file
    // before every single tool call.
    Timer {
        running: true
        interval: 1
        onTriggered: {
            root.makeMpris();
            if (!root.active)
                root.writeSession(false);
        }
    }

    Connections {
        target: Config

        function onLoadedChanged(): void {
            if (!root.active)
                root.writeSession(false);
        }
    }

    // ------------------------------------------------------------------- ipc
    //   qs -c velvet ipc call velly wake|sleep|toggle|ask|status|state|toast
    IpcHandler {
        target: "velly"

        // SUPER+A: wake her and show her, or put her back to sleep
        function summon(): void {
            root.summon();
        }
        // velvet-ai settings.find / settings.set
        function settingsFind(query: string): string {
            return root.findSettings(query);
        }
        function settingApply(key: string, value: string): string {
            return root.applySetting(key, value);
        }
        function wake(): void {
            root.wake();
        }
        function sleep(): void {
            root.sleep();
        }
        function toggle(): void {
            root.toggle();
        }
        function ask(text: string): void {
            root.ask(text);
        }
        function status(): string {
            return root.status();
        }
        function state(): string {
            return root.snapshot();
        }
        function toast(text: string, kind: string): void {
            root.toast(text, kind);
        }
        // A reminder she set earlier (timer.set) is due — asleep or awake.
        function remind(text: string): void {
            root.remind(text);
        }
        // Returns what happened, so the brain can tell the user the truth
        // (void handlers printed nothing and every call read as a failure).
        function media(action: string): string {
            return root.media(action);
        }
        function mediaInfo(): string {
            return root.mediaInfo();
        }
        // The latest notifications as data — her notifs.list tool.
        function notifs(): string {
            return root.notifsJson();
        }
        function wallpaper(action: string): void {
            root.wallpaper(action);
        }
        function setting(key: string): void {
            root.setting(key);
        }
        function set(key: string, value: string): void {
            root.setKey(key, value);
        }
        function force(on: string): void {
            root.setForce(`${on ?? ""}` === "true" || `${on ?? ""}` === "1");
        }
        function run(command: string): string {
            return root.runCmd(command);
        }
        function scene(action: string): void {
            root.scene(action);
        }
        function say(text: string): void {
            root.say(text);
        }
        function stop(): void {
            root.stopVoice();
        }
        function probe(): void {
            root.probe();
        }
        // The same thing the SETUP chip does, from outside: open her, open the
        // card. Useful for a keybind, and for checking the card without a mouse.
        function setup(): void {
            root.setupOpen = true;
            root.wantIsland = true;
            root.wake();
        }
    }
}
