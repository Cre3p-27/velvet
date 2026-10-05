//  VELVET  ·  modules/settings/QuickPane.qml
//  The QUICK SETTINGS room of Super+Tab. Everything you reach for ten times
//  a day, in one view: volume and brightness, the toggle wall, the whole
//  bluetooth manager (pair, connect, trust, remove — no blueman), the
//  nearby Wi-Fi networks, and the power row.
//
//  Keyboard: ← → switches panel (← → on a slider adjusts it), ↑ ↓ moves,
//  ENTER selects, ESC back to SETTINGS. The bluetooth and Wi-Fi lists scroll
//  themselves to keep the selection in sight.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

FocusScope {
    id: root
    focus: true

    // ------------------------------------------------------------- geometry
    readonly property real gap: Appearance.padding.large * 1.5
    readonly property real lw: Math.max(252, (root.width - root.gap * 2) * 0.24)
    readonly property real mw: Math.max(330, (root.width - root.gap * 2) * 0.42)
    readonly property real rw: root.width - root.gap * 2 - root.lw - root.mw
    readonly property real stripH: 52
    // The status strip across the top of the room — date, connectivity,
    // battery, tasks. The three columns start below it.
    readonly property real topH: 56
    readonly property real colH: root.height - root.stripH - Appearance.spacing.large - root.topH


    // The strip's date — refreshed in minutes, not seconds.
    property var now: new Date()
    readonly property string dateLine: Qt.formatDate(root.now, "ddd d MMM").toUpperCase()

    Timer {
        running: true
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // ---------------------------------------------------------- keyboard model
    property int col: 0
    property int sel: 0
    property string pwFor: ""          // ssid awaiting a password
    property string pwCandidate: ""    // ssid the last connect tried

    // ------------------------------------------------------------ entrance
    //  The room assembles itself on every visit: the strip lands, then the
    //  columns one after another, then the power row.
    property int stage: 0

    Timer {
        id: qp1
        interval: 30
        onTriggered: root.stage = 1
    }
    Timer {
        id: qp2
        interval: 110
        onTriggered: root.stage = 2
    }
    Timer {
        id: qp3
        interval: 190
        onTriggered: root.stage = 3
    }
    Timer {
        id: qp4
        interval: 270
        onTriggered: root.stage = 4
    }
    Timer {
        id: qp5
        interval: 350
        onTriggered: root.stage = 5
    }

    // --------------------------------------------------------- power engine
    //  powerprofilesctl's gears: PERFORMANCE · BALANCED · POWER SAVER.
    //  One chip in THE MACHINE card; ENTER cycles, the probe keeps it in
    //  sync with whatever else touches the profile.
    property var profiles: []
    property string activeProfile: ""
    readonly property bool profileReady: root.profiles.length > 0

    function hasProfile(name: string): bool {
        for (let i = 0; i < root.profiles.length; i++)
            if (root.profiles[i].name === name)
                return true;
        return false;
    }

    function setProfile(name: string): void {
        if (!root.hasProfile(name))
            return;
        profileSet.command = ["powerprofilesctl", "set", name];
        profileSet.running = false;
        profileSet.running = true;
        root.activeProfile = name;
        Sfx.toggle();
        Toast.show(`ENGINE → ${name.toUpperCase()}`, "info", 2000);
    }

    function cycleEngine(): void {
        const names = ["performance", "balanced", "power-saver"];
        let i = names.indexOf(root.activeProfile);
        if (i === -1)
            i = 1;
        for (let k = 1; k <= names.length; k++) {
            const n = names[(i + k) % names.length];
            if (root.hasProfile(n)) {
                root.setProfile(n);
                return;
            }
        }
    }

    Process {
        id: profileProbe

        command: ["bash", "-c", "powerprofilesctl list 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const m = lines[i].match(/^ {0,2}(\*)?\s*([A-Za-z0-9-]+):\s*$/);
                    if (m)
                        out.push({ name: m[2], active: m[1] === "*" });
                }
                if (out.length > 0) {
                    root.profiles = out;
                    for (let k = 0; k < out.length; k++)
                        if (out[k].active)
                            root.activeProfile = out[k].name;
                }
            }
        }
    }

    Process {
        id: profileSet
        command: ["true"]
    }

    Timer {
        running: root.profileReady
        interval: 4000
        repeat: true
        onTriggered: {
            profileProbe.running = false;
            profileProbe.running = true;
        }
    }

    readonly property var col0: [volRow, micRow, briRow, sfxRow, chipWifi, chipBt, chipNight, chipAwake, chipDnd, chipFocus, chipPad, chipPadSteam, chipPadOption, chipVibe, chipAir, actShot, actRec, actKeys, actNotif, engRow]

    // Only the controls that are actually there count — a machine without
    // a mic or a bluetooth adapter leaves gaps the cursor must skip.
    function col0Visible(): var {
        const out = [];
        for (let i = 0; i < root.col0.length; i++)
            if (root.col0[i].visible)
                out.push(root.col0[i]);
        return out;
    }

    function colMax(): int {
        if (root.col === 0)
            return root.col0Visible().length;
        if (root.col === 1)
            return 2 + Bluetooth.devices.length;
        return 2 + Net.networks.length + (root.outputs.length > 0 ? root.outputs.length : 0);
    }

    function moveRow(d: int): void {
        const max = root.colMax();
        if (max === 0)
            return;
        root.sel = (root.sel + d + max) % max;
        Sfx.cursor();
        root.boxFor();
    }

    function moveCol(d: int): void {
        // On a slider, ← → adjusts the value — the settings menu's own
        // convention. From any other control it switches the panel.
        if (root.col === 0) {
            const it = root.col0Visible()[root.sel];
            if (it && it.kind === "slider") {
                it.nudge(d);
                return;
            }
        }
        root.col = (root.col + d + 3) % 3;
        root.sel = Math.min(root.sel, Math.max(0, root.colMax() - 1));
        Sfx.cursor();
        root.boxFor();
    }

    function activate(): void {
        if (root.col === 0) {
            const it = root.col0Visible()[root.sel];
            if (it && it.kind === "chip")
                it.keyTap();
            else if (it && it.kind === "engine")
                root.cycleEngine();
            else if (it && it.kind === "action")
                it.fire();
            return;
        }
        if (root.col === 1) {
            if (root.sel === 0) {
                Bluetooth.togglePower();
            } else if (root.sel === 1) {
                root.toggleScan();
            } else {
                const d = Bluetooth.devices[root.sel - 2];
                if (!d)
                    return;
                if (d.connected)
                    Bluetooth.disconnect(d.mac);
                else if (d.paired)
                    Bluetooth.connect(d.mac);
                else
                    Bluetooth.pair(d.mac);
            }
            return;
        }
        if (root.sel === 0) {
            Net.toggleWifi();
        } else if (root.sel === 1) {
            Net.refreshNetworks();
        } else if (root.sel < 2 + Net.networks.length) {
            const n = Net.networks[root.sel - 2];
            if (n)
                root.requestConnect(n);
        } else {
            const out = root.outputs[root.sel - 2 - Net.networks.length];
            if (out)
                root.pickOutput(out);
        }
    }

    function toggleScan(): void {
        if (Bluetooth.scanning)
            Bluetooth.stopScan();
        else
            Bluetooth.startScan();
    }

    function requestConnect(n: var): void {
        if (!n)
            return;
        if (n.active) {
            Net.disconnectWifi();
            return;
        }
        root.pwCandidate = n.ssid;
        root.pwFor = "";
        Net.connectWifi(n.ssid, "");
    }

    // The audio outputs, straight from Pipewire — sinks only.
    readonly property var outputs: {
        const out = [];
        const vs = Pipewire.nodes?.values ?? [];
        for (let i = 0; i < vs.length; i++) {
            const n = vs[i];
            if (n && n.isSink && n.audio)
                out.push(n);
        }
        return out;
    }

    function pickOutput(out: var): void {
        if (!out)
            return;
        if (out === Pipewire.defaultAudioSink) {
            Sfx.cursor();
            return;
        }
        Pipewire.preferredDefaultAudioSink = out;
        Sfx.select();
        Toast.show(`SOUND OUT → ${out.description ?? out.nickname ?? out.name ?? ""}`, "info", 3000);
    }

    Connections {
        target: Pipewire.nodes

        function onValuesChanged(): void {
            root.boxFor();
        }
    }

    // The selection ring follows whichever control is current; list items
    // are computed from their row geometry so they scroll with the list.
    function boxFor(): void {
        const ring = focusRing;
        if (root.col === 0) {
            const it = root.col0Visible()[root.sel];
            if (!it) {
                ring.visible = false;
                return;
            }
            const p = it.mapToItem(root, 0, 0);
            ring.x = p.x - 6;
            ring.y = p.y - 5;
            ring.width = it.width + 12;
            ring.height = it.height + 10;
            ring.visible = true;
            return;
        }
        const rowH = root.col === 1 ? 54 : 44;
        const fl = root.col === 1 ? devList : netList;
        const fixed = root.col === 1 ? [btPower, btScan] : [wifiRow, wifiRefresh];
        if (root.sel < fixed.length) {
            const it = fixed[root.sel];
            const p = it.mapToItem(root, 0, 0);
            ring.x = p.x - 6;
            ring.y = p.y - 5;
            ring.width = it.width + 12;
            ring.height = it.height + 10;
            ring.visible = true;
            return;
        }
        // The SOUND OUT list lives in its own scroller below the networks;
        // its rows are computed from its own geometry.
        if (root.col === 2 && root.sel >= 2 + Net.networks.length) {
            const k = root.sel - 2 - Net.networks.length;
            const y2 = k * 50;
            ring.x = outList.x - 5;
            ring.y = outList.y + y2 - outList.contentY - 2;
            ring.width = outList.width + 10;
            ring.height = 48;
            ring.visible = true;
            if (y2 < outList.contentY)
                outList.contentY = y2;
            else if (y2 + 44 > outList.contentY + outList.height)
                outList.contentY = y2 + 44 - outList.height;
            return;
        }
        const y = (root.sel - fixed.length) * rowH;
        ring.x = fl.x - 5;
        ring.y = fl.y + y - fl.contentY - 2;
        ring.width = fl.width + 10;
        ring.height = rowH + 4;
        ring.visible = true;
        // Keep the selection in sight.
        if (y < fl.contentY)
            fl.contentY = y;
        else if (y + rowH > fl.contentY + fl.height)
            fl.contentY = y + rowH - fl.height;
    }

    Connections {
        target: Bluetooth

        function onDevicesChanged(): void {
            root.boxFor();
        }
    }

    Connections {
        target: Net

        function onNetworksChanged(): void {
            root.boxFor();
        }

        function onLastWifiErrorChanged(): void {
            // A network that needs a password refuses politely — answer with
            // the prompt instead of leaving the user to guess.
            if (Net.lastWifiError === "" || Net.lastWifiAsk !== root.pwCandidate)
                return;
            const nets = Net.networks;
            for (let i = 0; i < nets.length; i++) {
                if (nets[i].ssid === Net.lastWifiAsk && nets[i].security !== "") {
                    root.pwFor = Net.lastWifiAsk;
                    break;
                }
            }
        }
    }

    Component.onCompleted: {
        // A deep link (BLUETOOTH row in AUDIO) may ask to start here.
        if (Panels.pendingQuickSection === "bluetooth") {
            root.col = 1;
            root.sel = 0;
            Panels.pendingQuickSection = "";
        }
        root.boxFor();
        qp1.start();
        qp2.start();
        qp3.start();
        qp4.start();
        qp5.start();
        profileProbe.running = false;
        profileProbe.running = true;
    }

    onPwForChanged: {
        if (root.pwFor !== "")
            pwFocus.restart();
    }

    Timer {
        id: pwFocus

        interval: 40
        onTriggered: {
            if (root.pwFor !== "")
                pwInput.forceActiveFocus();
        }
    }

    // ------------------------------------------------------------ the ring
    Rectangle {
        id: focusRing

        radius: Appearance.rounding.normal
        color: "transparent"
        border.width: 2
        border.color: Colours.accent
        visible: false
        z: 5
    }

    // ------------------------------------------------------------ keyboard
    Keys.onPressed: event => {
        if (pwInput.activeFocus)
            return;

        switch (event.key) {
        case Qt.Key_Up:
            root.moveRow(-1);
            event.accepted = true;
            return;
        case Qt.Key_Down:
            root.moveRow(1);
            event.accepted = true;
            return;
        case Qt.Key_Left:
            root.moveCol(-1);
            event.accepted = true;
            return;
        case Qt.Key_Right:
            root.moveCol(1);
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.activate();
            event.accepted = true;
            return;
        }
        // Escape and the room keys bubble to the settings' key brain via
        // Keys.forwardTo set on the instance.
    }

    // ------------------------------------------------------ the status strip
    //  The room's headline: where you are in the day and what the machine
    //  is wearing. Live chips, one glance — the rest of the room is details.
    Item {
        id: statusStrip

        x: 0
        y: 0
        width: parent.width
        height: root.topH - 8
        opacity: root.stage >= 1 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }

        transform: Translate {
            y: root.stage >= 1 ? 0 : 18

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.spacing.small

            StripChip {
                label: `${root.dateLine}`
                icon: "calendar_today"
                tint: Colours.accent
            }

            StripChip {
                label: Net.type === "ethernet" && Net.connected ? "WIRED" : (Net.connected ? Net.label : "OFFLINE")
                icon: Net.connected ? "wifi" : "signal_wifi_off"
                tint: Net.connected ? Colours.accentInk : Colours.danger
            }

            StripChip {
                label: Bluetooth.available ? (Bluetooth.powered ? `${Bluetooth.connectedCount} BT DEVICES` : "BT OFF") : "NO BT"
                icon: "bluetooth"
                tint: Bluetooth.powered ? Colours.accentInk : Colours.inkDim
            }

            StripChip {
                label: Battery.available ? `BAT ${Battery.percent}%${Battery.charging ? " ↑" : ""}` : "NO BAT"
                icon: Battery.charging ? "bolt" : "battery_full"
                tint: Battery.percent < 20 ? Colours.danger : Colours.accentInk
            }

            StripChip {
                label: `${Tasks.openCount} OPEN TASKS`
                icon: "checklist"
                tint: Colours.accentInk
            }

            StripChip {
                label: `${Notifs.unread} UNREAD`
                icon: "notifications"
                tint: Notifs.unread > 0 ? Colours.warning : Colours.inkDim
            }

            StripChip {
                label: Kbd.capsLock ? `${Kbd.layoutShort.toUpperCase()} + CAPS` : `${Kbd.layoutShort}`.toUpperCase()
                icon: "keyboard"
                tint: Kbd.capsLock ? Colours.warning : Colours.accentInk
                visible: Kbd.layoutShort !== ""
            }
        }

        P5Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "SUPER+TAB HOME   ·   CTRL+TAB ROOMS"
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.4
        }
    }

    component StripChip: Item {
        id: stripChipRoot
        required property string label
        required property string icon
        required property color tint

        width: 44 + textLabel.implicitWidth
        height: 30

        Slash {
            anchors.fill: parent
            shear: Appearance.skew
            color: Colours.alpha(Colours.ink, 0.05)
            borderColor: Colours.alpha(Colours.ink, 0.16)
            borderWidth: 1
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            width: 13
            name: stripChipRoot.icon
            color: stripChipRoot.tint
            font.pixelSize: 13
        }

        P5Text {
            id: textLabel

            anchors.verticalCenter: parent.verticalCenter
            x: 32
            text: stripChipRoot.label
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.2
        }
    }

    // --------------------------------------------------------- LEFT · toggles
    Item {
        id: leftCol

        x: 0
        y: root.topH
        width: root.lw
        height: root.colH
        opacity: root.stage >= 2 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }

        transform: Translate {
            y: root.stage >= 2 ? 0 : 24

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
        }

        P5Text {
            display: true
            text: "TOGGLES"
            color: Colours.ink
            font.pixelSize: Appearance.font.size.large
            tracking: 2
        }

        // What is left under the toggles for the two cards pinned to the foot
        // of the column. A short window (a big header, a small screen) used to
        // slide them over the chips; now they step aside instead.
        readonly property real roomLeft: leftCol.height - (chipsCol.y + chipsCol.implicitHeight) - Appearance.spacing.normal

        Column {
            id: chipsCol

            anchors.top: parent.top
            anchors.topMargin: 44
            width: parent.width
            spacing: Appearance.spacing.small

            // volume
            Row {
                id: volRow

                property string kind: "slider"

                width: parent.width
                height: 40
                spacing: Appearance.spacing.small

                function nudge(d: int): void {
                    Audio.setVolume(Math.max(0, Math.min(1, Audio.volume + d * 0.05)));
                    Sfx.cursor();
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Audio.muted ? "volume_off" : "volume_up"
                    color: Audio.muted ? Colours.danger : Colours.ink
                    font.pixelSize: Appearance.font.size.large
                    width: 24

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMute()
                    }
                }

                SlashSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24 - 46 - Appearance.spacing.small * 2
                    value: Audio.volume
                    tint: Audio.muted ? Colours.alpha(Colours.ink, 0.3) : Colours.accent
                    onMoved: v => Audio.setVolume(v)
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    horizontalAlignment: Text.AlignRight
                    display: true
                    text: `${Math.round(Audio.volume * 100)}`
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.normal
                }
            }

            // microphone
            Row {
                id: micRow

                property string kind: "slider"

                width: parent.width
                height: 40
                spacing: Appearance.spacing.small
                visible: Audio.source !== null

                function nudge(d: int): void {
                    Audio.setMicVolume(Math.max(0, Math.min(1, Audio.micVolume + d * 0.05)));
                    Sfx.cursor();
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Audio.micMuted ? "mic_off" : "mic"
                    color: Audio.micMuted ? Colours.danger : Colours.ink
                    font.pixelSize: Appearance.font.size.large
                    width: 24

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMicMute()
                    }
                }

                SlashSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24 - 46 - Appearance.spacing.small * 2
                    value: Audio.micVolume
                    tint: Audio.micMuted ? Colours.alpha(Colours.ink, 0.3) : Colours.accentAlt
                    onMoved: v => Audio.setMicVolume(v)
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    horizontalAlignment: Text.AlignRight
                    display: true
                    text: `${Math.round(Audio.micVolume * 100)}`
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.normal
                }
            }

            // brightness
            Row {
                id: briRow

                property string kind: "slider"

                width: parent.width
                height: 40
                spacing: Appearance.spacing.small
                visible: Brightness.available

                function nudge(d: int): void {
                    Brightness.setBrightness(Math.max(0.01, Math.min(1, Brightness.brightness + d * 0.05)));
                    Sfx.cursor();
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "light_mode"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.large
                    width: 24
                }

                SlashSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24 - 46 - Appearance.spacing.small * 2
                    value: Brightness.brightness
                    tint: Colours.warning
                    onMoved: v => Brightness.setBrightness(v)
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    horizontalAlignment: Text.AlignRight
                    display: true
                    text: `${Math.round(Brightness.brightness * 100)}`
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.normal
                }
            }

            // the shell's own voice — its fader lives here too, so the menu
            // clicks can be tuned from the same place as everything else.
            // The icon is the master switch, the fader is the level.
            Row {
                id: sfxRow

                property string kind: "slider"

                width: parent.width
                height: 40
                spacing: Appearance.spacing.small

                function nudge(d: int): void {
                    Config.set("sfx.volume", Math.max(0, Math.min(1, Config.sfx.volume + d * 0.05)));
                    Sfx.cursor();
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Config.sfx.enabled ? "graphic_eq" : "volume_off"
                    color: Config.sfx.enabled ? Colours.ink : Colours.danger
                    font.pixelSize: Appearance.font.size.large
                    width: 24

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Play on the right side of the toggle: the last
                            // click you hear going off, the first coming back.
                            const goingOff = Config.sfx.enabled;
                            if (goingOff)
                                Sfx.toggle();
                            Config.toggle("sfx.enabled");
                            if (!goingOff)
                                Sfx.toggle();
                        }
                    }
                }

                SlashSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 24 - 46 - Appearance.spacing.small * 2
                    value: Config.sfx.volume
                    tint: Config.sfx.enabled ? Colours.accentAlt : Colours.alpha(Colours.ink, 0.3)
                    onMoved: v => Config.set("sfx.volume", v)
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    horizontalAlignment: Text.AlignRight
                    display: true
                    text: `${Math.round(Config.sfx.volume * 100)}`
                    color: Config.sfx.enabled ? Colours.ink : Colours.inkDim
                    font.pixelSize: Appearance.font.size.normal
                }
            }
            // the chip wall
            Flow {
                width: parent.width
                spacing: Appearance.spacing.small
                clip: true

                Chip {
                    id: chipWifi

                    width: (parent.width - Appearance.spacing.small) / 2
                    label: "WI-FI"
                    icon: "wifi"
                    on: Net.wifiEnabled
                    onToggled: Net.toggleWifi()
                }

                Chip {
                    id: chipBt

                    width: (parent.width - Appearance.spacing.small) / 2
                    label: "BLUETOOTH"
                    icon: "bluetooth"
                    on: Bluetooth.powered
                    visible: Bluetooth.available
                    onToggled: Bluetooth.togglePower()
                }

                Chip {
                    id: chipAir

                    width: (parent.width - Appearance.spacing.small) / 2
                    label: "AIRPLANE"
                    icon: "airplane"
                    on: !Net.wifiEnabled && !Bluetooth.powered
                    onToggled: {
                        if (!Net.wifiEnabled || !Bluetooth.powered) {
                            if (!Net.wifiEnabled)
                                Net.toggleWifi();
                            if (!Bluetooth.powered && Bluetooth.available)
                                Bluetooth.togglePower();
                        } else {
                            Net.toggleWifi();
                            if (Bluetooth.powered)
                                Bluetooth.togglePower();
                        }
                    }
                }

                Chip {
                    id: chipNight

                    width: (parent.width - Appearance.spacing.small) / 2
                    label: "NIGHT LIGHT"
                    icon: "dark_mode"
                    on: Config.services.nightLight
                    onToggled: Config.toggle("services.nightLight")
                }

                Chip {
                    id: chipAwake

                    width: (parent.width - Appearance.spacing.small) / 2
                    label: "KEEP AWAKE"
                    icon: "bedtime"
                    on: Config.services.idleInhibit
                    onToggled: Config.toggle("services.idleInhibit")
                }

                Chip {
                    id: chipDnd

                    width: (parent.width - Appearance.spacing.small) / 2
                    label: "SILENT"
                    icon: "notifications_off"
                    on: Config.notifs.doNotDisturb
                    onToggled: Config.toggle("notifs.doNotDisturb")
                }

                Chip {
                    id: chipFocus

                    width: (parent.width - Appearance.spacing.small) / 2
                    label: "FOCUS"
                    icon: "do_not_disturb_on"
                    on: Focus.active
                    onToggled: Focus.toggle()
                }

                // Which player the game controller is — Bluetooth or cable.
                Chip {
                    id: chipPad

                    width: (parent.width - Appearance.spacing.small) / 2
                    label: `CONTROLLER · P${Pad.player}`
                    icon: "sports_esports"
                    on: Pad.player === 2
                    onToggled: Pad.toggle()
                }

                // Steam numbers pads in its own order and hands games a virtual
                // pad: this asks Steam itself to put yours on slot 2.
                Chip {
                    id: chipPadSteam

                    visible: Pad.player === 2 && Pad.steamVisible
                    width: (parent.width - Appearance.spacing.small) / 2
                    label: Pad.steamLabel
                    icon: "sports_esports"
                    on: Pad.steamState === "applied"
                    onToggled: Pad.steamTap()
                }

                // The whole shell's vibe, one tap to the next: arcade, cyber,
                // terminal, paper, glass, rpg, brutal, clean, windows.
                Chip {
                    id: chipVibe

                    width: (parent.width - Appearance.spacing.small) / 2
                    label: Config.appearance.vibe === "windows" ? `VIBE · WINDOWS ${String(Config.appearance.winVersion).toUpperCase()}` : (Config.appearance.vibe !== "" ? `VIBE · ${String(Config.appearance.vibe).toUpperCase()}` : "VIBE · TRY ONE")
                    icon: "deployed_code"
                    on: Config.appearance.vibe !== ""
                    onToggled: Presets.cycleVibe(1)
                }

                // Games that run without Steam Input read the pad straight from
                // hidraw; this launch option puts them on the same footing.
                Chip {
                    id: chipPadOption

                    visible: Pad.player === 2
                    width: (parent.width - Appearance.spacing.small) / 2
                    label: "COPY LAUNCH OPTION"
                    icon: "content_copy"
                    on: false
                    onToggled: Pad.copyLaunchOption()
                }
            }

            Item {
                width: parent.width
                height: 8
            }

            P5Text {
                display: true
                text: "QUICK ACTIONS"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 2
            }

            // One press, get out of the way: screenshot, recording, the
            // key map and the notification centre — all at thumb distance.
            Flow {
                width: parent.width
                spacing: Appearance.spacing.small
                clip: true

                QuickAction {
                    id: actShot

                    label: "SCREENSHOT"
                    icon: "photo_camera"
                    fn: () => {
                        Panels.closeAll();
                        Actions.run(Config.services.screenshotCommand);
                    }
                }

                QuickAction {
                    id: actRec

                    label: "RECORD"
                    icon: "fiber_manual_record"
                    fn: () => {
                        Panels.closeAll();
                        // Binds owns the (correctly resolved) path; Hyprland owns the process.
                        Hypr.exec(`bash "${Binds.recordScript}"`);
                    }
                }

                QuickAction {
                    id: actKeys

                    label: "KEY MAP"
                    icon: "keyboard"
                    fn: () => {
                        Panels.closeAll();
                        Panels.toggleKeys();
                    }
                }

                QuickAction {
                    id: actNotif

                    label: "NOTIFS"
                    icon: "notifications"
                    fn: () => {
                        Panels.closeAll();
                        Panels.toggleNotifCentre();
                    }
                }
            }
        }

        // the weather, live — pinned above the machine card so the gap
        // between the chips and the cards is the part that breathes.
        Item {
            id: weatherCard

            anchors.bottom: machineCard.top
            anchors.bottomMargin: Appearance.spacing.normal
            width: parent.width
            height: 108
            visible: Config.services.weather && Weather.ready && leftCol.roomLeft >= machineCard.height + weatherCard.height + Appearance.spacing.normal
            scale: weatherHover.hovered ? 1.015 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: weatherHover
            }

            Slash {
                anchors.fill: parent
                shear: Appearance.skew
                color: Colours.alpha(Colours.ink, 0.05)
                borderColor: weatherHover.hovered ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.18)
                borderWidth: 1

                Behavior on borderColor {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                x: 18
                width: 46
                name: Weather.icon
                color: Colours.warning
                font.pixelSize: 44
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 78
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                P5Text {
                    display: true
                    text: `${Math.round(Weather.temperature)}°   ${Weather.description.toUpperCase()}`
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.large
                    tracking: 1
                    elide: Text.ElideRight
                    width: parent.width
                }

                P5Text {
                    text: `H ${Math.round(Weather.maxTempC)}°  L ${Math.round(Weather.minTempC)}°   ·   ${Weather.humidity}% HUM   ·   ${Weather.place.toUpperCase()}`
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.1
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        // the machine, loud — a proper card with the CPU spark instead of
        // two whispered lines. This is the game HUD corner of the room.
        Item {
            id: machineCard

            anchors.bottom: parent.bottom
            width: parent.width
            height: root.profileReady ? 234 : 186
            visible: leftCol.roomLeft >= machineCard.height * 0.85
            scale: machineHover.hovered ? 1.012 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: machineHover
            }

            Slash {
                anchors.fill: parent
                shear: Appearance.skew
                color: Colours.alpha(Colours.ink, 0.05)
                borderColor: machineHover.hovered ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.18)
                borderWidth: 1

                Behavior on borderColor {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Row {
                id: machineHead

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.top: parent.top
                anchors.topMargin: 14
                width: parent.width - 32 - (Battery.available ? 52 : 0)
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    name: "monitor_heart"
                    color: Colours.accent
                    font.pixelSize: 14
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: "THE MACHINE"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.small
                    tracking: 2
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `CPU ${Math.round(SysInfo.cpuPercent)}%   ·   ${Math.round(SysInfo.temperature)}°`
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.2
                }
            }

            CircularProgress {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.top: parent.top
                anchors.topMargin: 12
                width: 36
                height: 36
                thickness: 3
                visible: Battery.available
                value: Battery.percent / 100
                color: Battery.charging ? Colours.accentAlt : (Battery.percent < 20 ? Colours.danger : Colours.accent)
                text: `${Battery.percent}`
                textSize: Appearance.font.size.tiny - 2
            }

            // The last ~80 seconds of CPU, as a bar spark.
            Item {
                id: cpuSpark

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.top: machineHead.bottom
                anchors.topMargin: 10
                height: 54
                clip: true

                // A fixed row of 40 bars reading the tail of the history:
                // the delegates stay put and only re-evaluate their height,
                // instead of the whole spark being rebuilt every sample.
                Repeater {
                    model: 40

                    Rectangle {
                        required property int index

                        readonly property real v: {
                            const h = SysInfo.cpuHistory;
                            const i = h.length - 40 + index;
                            return i >= 0 ? h[i] : 0;
                        }

                        x: index * (cpuSpark.width / 40)
                        y: cpuSpark.height - Math.max(2, v * (cpuSpark.height / 100))
                        width: Math.max(1.5, cpuSpark.width / 40 - 1.4)
                        height: Math.max(2, v * (cpuSpark.height / 100))
                        radius: 1
                        color: Colours.alpha(Colours.accent, 0.75)
                    }
                }
            }

            // The engine gear — powerprofilesctl's PERFORMANCE / BALANCED
            // / POWER SAVER in one chip. ENTER cycles it.
            Item {
                id: engRow

                property string kind: "engine"

                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 64
                height: 30
                visible: root.profileReady
                width: engLabel.implicitWidth + 58
                scale: engArea.containsMouse ? 1.05 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.6
                    }
                }

                readonly property color engTint: root.activeProfile === "performance"
                    ? Colours.accent
                    : (root.activeProfile === "power-saver" ? Colours.warning : Colours.alpha(Colours.ink, 0))

                Slash {
                    anchors.fill: parent
                    shear: Appearance.skew
                    color: root.activeProfile === "balanced"
                        ? (engArea.containsMouse ? Colours.alpha(Colours.ink, 0.14) : Colours.alpha(Colours.ink, 0.06))
                        : Colours.alpha(engRow.engTint, 0.2)
                    borderColor: root.activeProfile === "balanced" ? Colours.alpha(Colours.ink, 0.3) : engRow.engTint
                    borderWidth: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13
                        name: "bolt"
                        color: root.activeProfile === "balanced" ? Colours.accent : engRow.engTint
                        font.pixelSize: 13
                    }

                    P5Text {
                        id: engLabel

                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: `ENGINE · ${root.activeProfile.toUpperCase()}`
                        color: root.activeProfile === "balanced" ? Colours.ink : engRow.engTint
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.2
                    }
                }

                MouseArea {
                    id: engArea
                    hoverEnabled: true

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cycleEngine()
                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                spacing: 10

                MachineStat {
                    label: "RAM"
                    value: `${SysInfo.memoryUsedGb.toFixed(1)}/${SysInfo.memoryTotalGb.toFixed(0)}G`
                    frac: SysInfo.memoryPercent / 100
                    tint: Colours.accentAlt
                }

                MachineStat {
                    label: "DISK"
                    value: `${SysInfo.storageUsedGb.toFixed(0)}/${SysInfo.storageTotalGb.toFixed(0)}G`
                    frac: SysInfo.storagePercent / 100
                    tint: Colours.accent
                }

                MachineStat {
                    label: "TEMP"
                    value: `${Math.round(SysInfo.temperature)}°`
                    frac: Math.min(1, SysInfo.temperature / 100)
                    tint: Colours.warning
                }

                MachineStat {
                    label: "UP"
                    value: `${SysInfo.uptimeText}`
                    frac: 0
                    tint: Colours.inkDim
                }
            }

            component MachineStat: Column {
                id: machineStatRoot
                required property string label
                required property string value
                required property real frac
                required property color tint

                width: (parent.width - parent.spacing * 3) / 4
                spacing: 3

                P5Text {
                    display: true
                    text: machineStatRoot.label
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny - 1
                    tracking: 1.4
                }

                P5Text {
                    text: machineStatRoot.value
                    color: Colours.ink
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: Appearance.font.size.small
                }

                Rectangle {
                    width: parent.width
                    height: 3
                    radius: 1.5
                    color: Colours.alpha(Colours.ink, 0.12)
                    visible: machineStatRoot.frac > 0

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, machineStatRoot.frac))
                        height: parent.height
                        radius: 1.5
                        color: machineStatRoot.tint
                    }
                }
            }
        }
    }

    // ------------------------------------------------------ MIDDLE · bluetooth
    Item {
        id: midCol

        x: root.lw + root.gap
        y: root.topH
        width: root.mw
        height: root.colH
        opacity: root.stage >= 3 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }

        transform: Translate {
            y: root.stage >= 3 ? 0 : 24

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
        }

        P5Text {
            display: true
            text: "BLUETOOTH"
            color: Colours.ink
            font.pixelSize: Appearance.font.size.large
            tracking: 2
        }

        P5Text {
            x: 0
            y: 26
            text: Bluetooth.available
                ? (Bluetooth.powered
                    ? `${Bluetooth.adapterName !== "" ? Bluetooth.adapterName.toUpperCase() : "ADAPTER"}  ·  ${Bluetooth.connectedCount} CONNECTED`
                    : "ADAPTER OFF")
                : "NO BLUETOOTH ADAPTER — NOTHING TO MANAGE"
            color: Bluetooth.available && !Bluetooth.powered ? Colours.warning : Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.2
        }

        // power + search
        Row {
            id: btPower

            y: 48
            spacing: Appearance.spacing.small

            Chip {
                width: 130
                label: Bluetooth.powered ? "ON" : "OFF"
                icon: Bluetooth.powered ? "bluetooth" : "bluetooth_disabled"
                on: Bluetooth.powered
                onToggled: Bluetooth.togglePower()
            }

            Item {
                id: btScan

                width: 150
                height: 40

                Slash {
                    anchors.fill: parent
                    shear: Appearance.skew
                    color: Bluetooth.scanning ? Colours.accent : Colours.alpha(Colours.ink, btScanArea.containsMouse ? 0.14 : 0.06)
                    borderColor: Bluetooth.scanning ? "transparent" : Colours.alpha(Colours.ink, 0.3)
                    borderWidth: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    Icon {
                        id: scanGlyph

                        anchors.verticalCenter: parent.verticalCenter
                        name: "bluetooth_searching"
                        color: Bluetooth.scanning ? Colours.on(Colours.accent) : Colours.accent
                        font.pixelSize: Appearance.font.size.normal

                        SequentialAnimation on opacity {
                            running: Bluetooth.scanning
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 1
                                to: 0.35
                                duration: 420
                                easing.type: Easing.InOutQuad
                            }
                            NumberAnimation {
                                from: 0.35
                                to: 1
                                duration: 420
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: Bluetooth.scanning ? "SEARCHING…" : "SEARCH"
                        color: Bluetooth.scanning ? Colours.on(Colours.accent) : Colours.ink
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.2
                    }
                }

                MouseArea {
                    id: btScanArea
                    hoverEnabled: true

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleScan()
                }
            }
        }

        // the device list
        Flickable {
            id: devList

            y: 104
            width: parent.width
            height: parent.height - 104 - 34 - 96
            clip: true
            contentHeight: devColumn.height
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 2600

            Column {
                id: devColumn

                width: parent.width
                spacing: 6

                Repeater {
                    model: Bluetooth.devices.length

                    Plate {
                        required property int index

                        readonly property var dev: Bluetooth.devices[index] ?? null
                        readonly property bool busy: Bluetooth.busyMac !== "" && Bluetooth.busyMac === (dev?.mac ?? "")

                        width: devColumn.width
                        height: 54
                        radius: Appearance.rounding.normal
                        color: Colours.alpha(Colours.ink, 0.05)
                        border.width: 1
                        border.color: Colours.alpha(Colours.ink, 0.12)
                        opacity: busy ? 0.65 : 1

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }

                        // device icon plate
                        Plate {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 12
                            width: 32
                            height: 32
                            radius: Appearance.r(8)
                            color: dev?.connected ?? false ? Colours.accent : Colours.alpha(Colours.ink, 0.08)

                            Icon {
                                anchors.centerIn: parent
                                width: 18
                                name: dev?.icon ?? "bluetooth"
                                color: dev?.connected ?? false ? Colours.on(Colours.accent) : Colours.ink
                                font.pixelSize: 18
                            }
                        }

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 56
                            anchors.right: parent.right
                            anchors.rightMargin: 74
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            P5Text {
                                width: parent.width
                                text: dev?.name ?? ""
                                color: Colours.ink
                                font.pixelSize: Appearance.font.size.small
                                elide: Text.ElideRight
                            }

                            P5Text {
                                text: busy ? "WORKING…"
                                    : (dev?.connected ?? false) ? "CONNECTED  ·  TAP TO DISCONNECT"
                                    : (dev?.paired ?? false) ? "PAIRED  ·  TAP TO CONNECT"
                                    : "NEW  ·  TAP TO PAIR"
                                color: (dev?.connected ?? false) ? Colours.accentInk : (dev?.paired ?? false ? Colours.inkDim : Colours.warning)
                                font.pixelSize: Appearance.font.size.tiny
                                tracking: 1
                            }
                        }

                        // trust star
                        Icon {
                            z: 1
                            anchors.right: parent.right
                            anchors.rightMargin: 44
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            visible: (dev?.paired ?? false) && !busy
                            name: (dev?.trusted ?? false) ? "star" : "star_border"
                            color: (dev?.trusted ?? false) ? Colours.accent : Colours.alpha(Colours.ink, 0.4)
                            font.pixelSize: 16

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Bluetooth.toggleTrust(dev.mac)
                            }
                        }

                        // remove
                        Icon {
                            z: 1 // above the row-wide devArea, or ✕ connects instead of forgetting
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            visible: devArea.containsMouse && !busy
                            name: "close"
                            color: Colours.danger
                            font.pixelSize: 16

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Bluetooth.remove(dev.mac)
                            }
                        }

                        MouseArea {
                            id: devArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (busy)
                                    return;
                                const d = dev;
                                if (d.connected)
                                    Bluetooth.disconnect(d.mac);
                                else if (d.paired)
                                    Bluetooth.connect(d.mac);
                                else
                                    Bluetooth.pair(d.mac);
                            }
                        }
                    }
                }

                // empty state
                Item {
                    width: parent.width
                    height: 150
                    visible: Bluetooth.devices.length === 0

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 18
                        width: 30
                        name: "bluetooth_searching"
                        color: Colours.alpha(Colours.ink, 0.35)
                        font.pixelSize: 28
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 58
                        display: true
                        text: Bluetooth.available ? "NO DEVICES YET" : "NO ADAPTER"
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.normal
                        tracking: 1.4
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 88
                        text: Bluetooth.available ? "SEARCH FINDS THEM · PAIRING HAPPENS IN THE SHELL" : "INSTALL BLUEZ AND BLUETOOTHCTL"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                    }
                }
            }

            SmoothScroll {
                view: devList
            }
        }

        // The quiet handbook under the list — same card language as the
        // WORKFLOW room's tips, so the rooms read as one family.
        Plate {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 88
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.ink, 0.05)
            border.width: 1
            border.color: Colours.alpha(Colours.ink, 0.14)

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Row {
                    spacing: 9

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13
                        name: "bolt"
                        color: Colours.accent
                        font.pixelSize: 12
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TAP A DEVICE TO CONNECT · TAP AGAIN TO DISCONNECT"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 0.6
                    }
                }

                Row {
                    spacing: 9

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13
                        name: "bolt"
                        color: Colours.accent
                        font.pixelSize: 12
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "THE STAR KEEPS A DEVICE TRUSTED · ✕ FORGETS IT"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 0.6
                    }
                }
            }
        }
    }

    // ----------------------------------------------------------- RIGHT · wifi
    Item {
        id: rightCol

        x: root.lw + root.gap + root.mw + root.gap
        y: root.topH
        width: root.rw
        height: root.colH
        opacity: root.stage >= 4 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }

        transform: Translate {
            y: root.stage >= 4 ? 0 : 24

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
        }

        P5Text {
            display: true
            text: "WI-FI"
            color: Colours.ink
            font.pixelSize: Appearance.font.size.large
            tracking: 2
        }

        P5Text {
            x: 0
            y: 26
            text: Net.type === "ethernet" && Net.connected ? `WIRED  ·  ${Net.label}` : (Net.connected ? `${Net.label}  ·  ${Net.strength}%` : "OFFLINE")
            color: Net.connected ? Colours.inkDim : Colours.warning
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.2
        }

        // wifi + refresh
        Row {
            id: wifiRow

            y: 48
            spacing: Appearance.spacing.small

            Chip {
                width: 120
                label: Net.wifiEnabled ? "ON" : "OFF"
                icon: Net.wifiEnabled ? "wifi" : "signal_wifi_off"
                on: Net.wifiEnabled
                onToggled: Net.toggleWifi()
            }

            Item {
                id: wifiRefresh

                width: 130
                height: 40

                Slash {
                    anchors.fill: parent
                    shear: Appearance.skew
                    color: Colours.alpha(Colours.ink, refreshArea.containsMouse ? 0.14 : 0.06)
                    borderColor: Colours.alpha(Colours.ink, 0.3)
                    borderWidth: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 7

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "refresh"
                        color: Colours.accent
                        font.pixelSize: Appearance.font.size.normal
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: "RESCAN"
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.2
                    }
                }

                MouseArea {
                    id: refreshArea
                    hoverEnabled: true

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Net.refreshNetworks()
                }
            }
        }

        // password prompt
        Plate {
            id: pwPrompt

            y: 100
            width: parent.width
            height: 40
            radius: Appearance.rounding.normal
            visible: root.pwFor !== ""
            color: Colours.alpha(Colours.accent, 0.1)
            border.width: 1
            border.color: Colours.accent
            clip: true

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                width: 16
                name: "lock"
                color: Colours.accent
                font.pixelSize: 16
            }

            TextInput {
                id: pwInput

                anchors.left: parent.left
                anchors.leftMargin: 36
                anchors.right: parent.right
                anchors.rightMargin: 64
                anchors.verticalCenter: parent.verticalCenter
                color: Colours.ink
                font.family: Appearance.fontFamily.body
                font.pixelSize: Appearance.font.size.small
                echoMode: TextInput.Password
                selectByMouse: true
                cursorDelegate: Rectangle {
                    width: 2
                    color: Colours.accent
                }

                onAccepted: {
                    const ssid = root.pwFor;
                    root.pwFor = "";
                    Net.connectWifi(ssid, text);
                }

                Keys.onEscapePressed: event => {
                    root.pwFor = "";
                    root.forceActiveFocus();
                    event.accepted = true;
                }
            }

            P5Text {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: `${root.pwFor}`.toUpperCase()
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                width: 44
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }

            MouseArea {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 30
                cursorShape: Qt.PointingHandCursor
                onClicked: root.pwFor = ""
            }
        }

        // the network list
        Flickable {
            id: netList

            y: root.pwFor !== "" ? 152 : 104
            width: parent.width
            height: parent.height - y - 34 - (outSection.visible ? outSection.height + 10 : 0)
            clip: true
            contentHeight: netColumn.height
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 2600

            Column {
                id: netColumn

                width: parent.width
                spacing: 6

                Repeater {
                    model: Net.networks.length

                    Plate {
                        required property int index

                        readonly property var net: Net.networks[index] ?? null

                        width: netColumn.width
                        height: 44
                        radius: Appearance.rounding.normal
                        color: (net?.active ?? false) ? Colours.alpha(Colours.accent, 0.14) : Colours.alpha(Colours.ink, 0.05)
                        border.width: 1
                        border.color: (net?.active ?? false) ? Colours.alpha(Colours.accent, 0.6) : Colours.alpha(Colours.ink, 0.12)

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 14
                            width: 18
                            name: (net?.signal ?? 0) >= 75 ? "network_wifi" : ((net?.signal ?? 0) >= 50 ? "network_wifi_3_bar" : ((net?.signal ?? 0) >= 25 ? "network_wifi_2_bar" : "network_wifi_1_bar"))
                            color: (net?.active ?? false) ? Colours.accent : Colours.ink
                            font.pixelSize: 18
                        }

                        P5Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 42
                            anchors.right: parent.right
                            anchors.rightMargin: (net?.active ?? false) ? 78 : 46
                            anchors.verticalCenter: parent.verticalCenter
                            text: net?.ssid ?? ""
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.small
                            elide: Text.ElideRight
                        }

                        Icon {
                            anchors.right: parent.right
                            anchors.rightMargin: 22
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            visible: (net?.security ?? "") !== ""
                            name: "lock"
                            color: Colours.alpha(Colours.ink, 0.5)
                            font.pixelSize: 13
                        }

                        P5Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            visible: net?.active ?? false
                            text: "ON"
                            color: Colours.accentInk
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1.4
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.requestConnect(net)
                        }
                    }
                }

                // empty state
                Item {
                    width: parent.width
                    height: 130
                    visible: Net.networks.length === 0

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 16
                        width: 30
                        name: "signal_wifi_off"
                        color: Colours.alpha(Colours.ink, 0.35)
                        font.pixelSize: 28
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 56
                        display: true
                        text: Net.wifiEnabled ? "NOTHING IN RANGE" : "WI-FI IS OFF"
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.normal
                        tracking: 1.4
                    }

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 86
                        text: Net.wifiEnabled ? "RESCAN TO TRY AGAIN" : "TURN IT ON AND THE NETWORKS APPEAR"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                    }
                }
            }

            SmoothScroll {
                view: netList
            }
        }

        // --------------------------------------------------- sound out
        //  Pick where the sound goes — one click, no pavucontrol.
        Item {
            id: outSection

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 250
            visible: root.outputs.length > 0

            P5Text {
                display: true
                text: "SOUND OUT"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.large
                tracking: 2
            }

            P5Text {
                x: 0
                y: 24
                width: parent.width
                text: `${Audio.sinkName}   ·   NEW NETWORKS ASK FOR A PASSWORD RIGHT HERE`
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.1
                elide: Text.ElideRight
            }

            Flickable {
                id: outList

                y: 52
                width: parent.width
                height: parent.height - 52
                clip: true
                contentHeight: outColumn.height
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 2600

                Column {
                    id: outColumn

                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.outputs

                        Plate {
                            id: out

                            required property var modelData

                            readonly property bool def: out.modelData === Pipewire.defaultAudioSink
                            readonly property string icon: {
                                const n = (out.modelData.name ?? "").toLowerCase();
                                if (n.indexOf("hdmi") !== -1 || n.indexOf("display") !== -1 || n.indexOf("dp") !== -1)
                                    return "tv";
                                if (n.indexOf("head") !== -1 || n.indexOf("ear") !== -1)
                                    return "headset";
                                return "speaker";
                            }

                            width: outColumn.width
                            height: 44
                            radius: Appearance.rounding.normal
                            color: out.def ? Colours.alpha(Colours.accent, 0.14) : Colours.alpha(Colours.ink, 0.05)
                            border.width: 1
                            border.color: out.def ? Colours.alpha(Colours.accent, 0.6) : Colours.alpha(Colours.ink, 0.12)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 14
                                width: 18
                                name: out.icon
                                color: out.def ? Colours.accent : Colours.ink
                                font.pixelSize: 18
                            }

                            P5Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 42
                                anchors.right: parent.right
                                anchors.rightMargin: out.def ? 86 : 46
                                anchors.verticalCenter: parent.verticalCenter
                                text: out.modelData.description ?? out.modelData.nickname ?? out.modelData.name ?? "?"
                                color: Colours.ink
                                font.pixelSize: Appearance.font.size.small
                                elide: Text.ElideRight
                            }

                            P5Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                visible: out.def
                                text: "ON"
                                color: Colours.accentInk
                                font.pixelSize: Appearance.font.size.tiny
                                tracking: 1.4
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pickOutput(out.modelData)
                            }
                        }
                    }
                }

                SmoothScroll {
                    view: outList
                }
            }
        }
    }

    // ---------------------------------------------------------- bottom · power
    Row {
        id: powerRow

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.stripH
        spacing: Appearance.spacing.small
        opacity: root.stage >= 5 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }

        transform: Translate {
            y: root.stage >= 5 ? 0 : 16

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
        }

        PowerButton {
            label: "LOCK"
            icon: "lock"
            fn: () => {
                Panels.closeAll();
                Actions.lock();
            }
        }

        PowerButton {
            label: "SLEEP"
            icon: "bedtime"
            fn: () => {
                Panels.closeAll();
                Actions.suspend();
            }
        }

        PowerButton {
            label: "RESTART"
            icon: "restart_alt"
            danger: true
            fn: () => {
                Panels.closeAll();
                Actions.reboot();
            }
        }

        PowerButton {
            label: "SHUT DOWN"
            icon: "power_settings_new"
            danger: true
            fn: () => {
                Panels.closeAll();
                Actions.shutdown();
            }
        }

        PowerButton {
            label: "LOG OUT"
            icon: "logout"
            danger: true
            fn: () => {
                Panels.closeAll();
                Actions.logout();
            }
        }

        Item {
            width: Math.max(10, root.width - 5 * 150 - 4 * Appearance.spacing.small - 330)
            height: 1
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "WALLPAPER"
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.6
        }

        Item {
            id: wpNext

            width: 74
            height: 40

            Slash {
                anchors.fill: parent
                shear: Appearance.skew
                color: Colours.alpha(Colours.ink, wpNextArea.containsMouse ? 0.14 : 0.06)
                borderColor: Colours.alpha(Colours.ink, 0.3)
                borderWidth: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            P5Text {
                anchors.centerIn: parent
                display: true
                text: "NEXT"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }

            MouseArea {
                id: wpNextArea
                hoverEnabled: true

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpapers.next()
            }
        }

        Item {
            id: wpRandom

            width: 86
            height: 40

            Slash {
                anchors.fill: parent
                shear: Appearance.skew
                color: Colours.alpha(Colours.ink, wpRandomArea.containsMouse ? 0.14 : 0.06)
                borderColor: Colours.alpha(Colours.ink, 0.3)
                borderWidth: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            P5Text {
                anchors.centerIn: parent
                display: true
                text: "RANDOM"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }

            MouseArea {
                id: wpRandomArea
                hoverEnabled: true

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpapers.random()
            }
        }

        Item {
            id: wpWheel

            width: 80
            height: 40

            Slash {
                anchors.fill: parent
                shear: Appearance.skew
                color: Colours.alpha(Colours.ink, wpWheelArea.containsMouse ? 0.14 : 0.06)
                borderColor: Colours.alpha(Colours.ink, 0.3)
                borderWidth: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            P5Text {
                anchors.centerIn: parent
                display: true
                text: "WHEEL"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }

            MouseArea {
                id: wpWheelArea
                hoverEnabled: true

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggleWheel()
            }
        }
    }

    // ----------------------------------------------------------- power button
    component PowerButton: Item {
        id: pb

        property string label: ""
        property string icon: ""
        property bool danger: false
        property var fn: null

        width: 150
        height: 40

        scale: pbArea.pressed ? 0.94 : (pbArea.containsMouse ? 1.05 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
                easing.overshoot: 2.4
            }
        }

        Slash {
            anchors.fill: parent
            shear: Appearance.skew
            color: pb.danger ? Colours.alpha(Colours.danger, pbArea.containsMouse ? 0.2 : 0.08) : Colours.alpha(Colours.ink, pbArea.containsMouse ? 0.14 : 0.06)
            borderColor: pb.danger ? Colours.alpha(Colours.danger, pbArea.containsMouse ? 1 : 0.45) : Colours.alpha(Colours.ink, 0.3)
            borderWidth: 1

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: pb.icon
                color: pb.danger ? Colours.danger : Colours.ink
                font.pixelSize: Appearance.font.size.normal
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: pb.label
                color: pb.danger ? Colours.danger : Colours.ink
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.4
            }
        }

        MouseArea {
            id: pbArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sfx.select();
                if (pb.fn)
                    pb.fn();
            }
        }
    }

    // ------------------------------------------------------------------- chip
    component Chip: Item {
        id: chip

        property string label: ""
        property string icon: ""
        property bool on: false
        property string kind: "chip"

        signal toggled

        height: 40

        function keyTap(): void {
            Sfx.toggle();
            chip.toggled();
        }

        scale: chipArea.pressed ? 0.93 : (chipArea.containsMouse ? 1.05 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
                easing.overshoot: 2.6
            }
        }

        Slash {
            anchors.fill: parent
            shear: Appearance.skew
            color: chip.on ? Colours.accent : Colours.alpha(Colours.ink, chipArea.containsMouse ? 0.16 : 0.08)
            borderColor: chip.on ? "transparent" : Colours.alpha(Colours.ink, 0.16)
            borderWidth: 1

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 5

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.icon
                color: chip.on ? Colours.on(Colours.accent) : Colours.inkDim
                font.pixelSize: Appearance.font.size.normal
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: chip.label
                color: chip.on ? Colours.on(Colours.accent) : Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
            }
        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.keyTap()
        }
    }

    // A one-shot row button: press, it fires, the shell gets out of the way.
    component QuickAction: Item {
        id: qa

        required property string label
        required property string icon
        required property var fn

        property string kind: "action"

        width: (parent.width - Appearance.spacing.small) / 2
        height: 40
        scale: qaArea.containsMouse ? 1.05 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
                easing.overshoot: 2.6
            }
        }

        function fire(): void {
            Sfx.select();
            qa.fn();
        }

        Slash {
            anchors.fill: parent
            shear: Appearance.skew
            color: qaArea.containsMouse ? Colours.alpha(Colours.ink, 0.14) : Colours.alpha(Colours.ink, 0.06)
            borderColor: Colours.alpha(Colours.ink, 0.3)
            borderWidth: 1

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 7

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                name: qa.icon
                color: Colours.accent
                font.pixelSize: 14
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: qa.label
                color: Colours.ink
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }
        }

        MouseArea {
            id: qaArea
            hoverEnabled: true

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: qa.fire()
        }
    }
}
