//  VELVET  ·  modules/settings/WorkflowPane.qml
//  The WORKFLOW room of Super+Tab: the task list, its knobs, and a live
//  preview of how the Dynamic Island will show it. Tasks live in
//  services/Tasks.qml; this pane is only their editor.
//
//  Keyboard: ↑ ↓ move · ENTER/SPACE toggles · N new task · DEL removes ·
//  P pins · ESC back to SETTINGS. Mouse: click a circle to check off,
//  double-click the text to edit it, the pin and the ✕ appear on hover.
import qs.config
import qs.services
import qs.components
import Quickshell.Services.Mpris
import QtQuick

FocusScope {
    id: root
    focus: true

    // The session stats live in the settings window — the zone Loader
    // destroys this pane on every room switch, but the Deep Work countdown
    // must keep ticking.
    required property QtObject stats

    // The combined keyboard list: open tasks first, then done.
    readonly property var rowList: {
        const out = [];
        const open = Tasks.open;
        const finished = Tasks.finished;
        for (let i = 0; i < open.length; i++)
            out.push(open[i]);
        for (let i = 0; i < finished.length; i++)
            out.push(finished[i]);
        return out;
    }

    property int rowIdx: 0

    // ------------------------------------------------------------ entrance
    //  The room assembles itself on every visit: the quest column lands
    //  first, then the right column walks in behind it.
    property int stage: 0

    Timer {
        id: wf1
        interval: 30
        onTriggered: root.stage = 1
    }
    Timer {
        id: wf2
        interval: 120
        onTriggered: root.stage = 2
    }

    Component.onCompleted: {
        wf1.start();
        wf2.start();
    }

    onRowListChanged: {
        // A toggle moves a task between the lists; the cursor must not be
        // left pointing past the end of the shorter one.
        root.rowIdx = Math.min(root.rowIdx, Math.max(0, root.rowList.length - 1));
    }

    readonly property real leftW: Math.min(parent.width * 0.46, 560)
    readonly property real rightX: root.leftW + Appearance.padding.large * 2

    function currentTask(): var {
        return root.rowList[root.rowIdx] ?? null;
    }

    function moveRow(delta: int): void {
        const n = root.rowList.length;
        if (n === 0) {
            root.rowIdx = 0;
            return;
        }
        root.rowIdx = Math.max(0, Math.min(n - 1, root.rowIdx + delta));
        Sfx.cursor();
        list.positionViewAtIndex(root.rowIdx, ListView.Contain);
    }

    function toggleCurrent(): void {
        const t = root.currentTask();
        if (t)
            Tasks.toggle(t.id);
    }

    function removeCurrent(): void {
        const t = root.currentTask();
        if (t)
            Tasks.remove(t.id);
    }

    function pinCurrent(): void {
        const t = root.currentTask();
        if (t)
            Tasks.togglePin(t.id);
    }

    function startAdd(): void {
        addInput.forceActiveFocus();
        addInput.cursorPosition = addInput.text.length;
    }

    // --------------------------------------------------------- the quest timer
    //  Session-only on purpose: a focus timer that survives restarts would
    //  lie about its countdown. It DOES survive room switches though — it
    //  lives in the settings window (stats) and keeps ticking while you
    //  walk to another room.
    readonly property int focusTotal: root.stats.focusTotal
    readonly property int focusLeft: root.stats.focusLeft
    readonly property bool focusRunning: root.stats.focusRunning

    readonly property int sessionDone: Math.max(0, Tasks.doneCount - root.stats.doneBase)

    function fmtFocus(seconds: int): string {
        const m = Math.floor(Math.max(0, seconds) / 60);
        const s = Math.max(0, seconds) % 60;
        return `${m}:${s < 10 ? "0" + s : s}`;
    }

    function focusToggle(): void {
        if (root.stats.focusLeft <= 0)
            root.stats.focusLeft = root.stats.focusTotal;
        root.stats.focusRunning = !root.stats.focusRunning;
        Sfx.toggle();
    }

    function focusReset(): void {
        root.stats.focusRunning = false;
        root.stats.focusLeft = root.stats.focusTotal;
        Sfx.back();
    }

    function focusPreset(minutes: int): void {
        root.stats.focusRunning = false;
        root.stats.focusTotal = minutes * 60;
        root.stats.focusLeft = root.stats.focusTotal;
        Sfx.cursor();
    }

    function jumpSector(ws: int): void {
        Hypr.focusWorkspace(ws);
        Sfx.select();
        Panels.closeAll();
    }

    // ---------------------------------------------------------- now playing
    //  What is playing — the same MPRIS source the island and the lock use.
    readonly property var player: {
        // One choice for the whole shell (services/MprisBridge.qml): it
        // remembers the last player that played, so a pause never hands
        // the controls to a browser tab. The scan below is the fallback.
        if (Lyrics.bridge)
            return Lyrics.bridge.player;
        const list = Mpris.players?.values ?? [];
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        return list.length > 0 ? list[0] : null;
    }
    readonly property bool hasPlayer: root.player !== null && (root.player.trackTitle ?? "") !== ""

    // MPRIS position only moves when asked — poll while playing.
    property int tick: 0

    Timer {
        id: posPoll

        interval: 1000
        repeat: true
        running: root.hasPlayer && (root.player?.isPlaying ?? false)
        onTriggered: root.tick++
    }

    // ------------------------------------------------------------ left column
    Column {
        id: leftCol

        width: root.leftW
        spacing: Appearance.spacing.normal
        opacity: root.stage >= 1 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }

        transform: Translate {
            y: root.stage >= 1 ? 0 : 24

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
        }

        // header: title, counts, score ring
        Row {
            width: parent.width
            spacing: Appearance.spacing.large

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 110 - Appearance.spacing.large
                spacing: 2

                Row {
                    spacing: 12

                    Slash {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 44
                        height: 22
                        shear: Appearance.skew
                        color: Colours.accent
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: "WORKFLOW"
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.title
                        tracking: 1
                    }
                }

                P5Text {
                    width: parent.width
                    text: `${Tasks.openCount} OPEN  ·  ${Tasks.doneCount} DONE  ·  THE ISLAND SHOWS THEM TOO`
                    color: Colours.accentInk
                    font.pixelSize: Appearance.font.size.small
                    tracking: 1.6
                    elide: Text.ElideRight
                }
            }

            CircularProgress {
                id: ring

                anchors.verticalCenter: parent.verticalCenter
                width: 84
                height: 84
                thickness: 5
                value: Tasks.progress
                color: Tasks.openCount === 0 ? Colours.accentAlt : Colours.accent
                text: `${Tasks.doneCount}/${Tasks.openCount + Tasks.doneCount}`
                textSize: Appearance.font.size.normal
            }
        }

        // the add row
        Plate {
            width: parent.width
            height: 56
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.ink, addInput.activeFocus ? 0.1 : 0.05)
            border.width: 1
            border.color: addInput.activeFocus ? Colours.accent : Colours.alpha(Colours.ink, 0.16)
            clip: true

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                x: 18
                width: 20
                name: "add_task"
                color: addInput.activeFocus ? Colours.accent : Colours.inkDim
                font.pixelSize: 20
            }

            TextInput {
                id: addInput

                anchors.left: parent.left
                anchors.leftMargin: 48
                anchors.right: parent.right
                anchors.rightMargin: 54
                anchors.verticalCenter: parent.verticalCenter
                color: Colours.ink
                font.family: Appearance.fontFamily.body
                font.pixelSize: Appearance.font.size.normal
                selectByMouse: true
                cursorDelegate: Rectangle {
                    width: 2
                    color: Colours.accent
                }

                onAccepted: {
                    if (Tasks.add(text) >= 0) {
                        text = "";
                        addInput.forceActiveFocus();
                    }
                }

                Keys.onEscapePressed: event => {
                    focus = false;
                    root.forceActiveFocus();
                    event.accepted = true;
                }
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 14
                width: 24
                name: "arrow_forward"
                color: addInput.activeFocus ? Colours.accent : Colours.alpha(Colours.ink, 0.4)
                font.pixelSize: 22

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Tasks.add(addInput.text) >= 0) {
                            addInput.text = "";
                            addInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // the list
        ListView {
            id: list

            width: parent.width
            height: Math.max(180, root.height - 270)
            clip: true
            model: root.rowList
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 2600
            currentIndex: root.rowIdx

            delegate: TaskRow {
                // Inline components do not see view roles directly — the
                // roles must be captured as required properties first.
                required property var modelData
                required property int index

                width: list.width
                height: 56
                task: modelData
                sel: index === root.rowIdx && !addInput.activeFocus

                onEdited: (id, text) => Tasks.rename(id, text)
            }

            SmoothScroll {
                view: list
            }
        }

        // The session strip: what this visit has accomplished.
        Row {
            width: parent.width
            spacing: Appearance.spacing.small

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "THIS SESSION"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.4
            }

            SessionChip {
                icon: "check"
                text: `${root.sessionDone} DONE`
                tint: Colours.accent
            }

            SessionChip {
                icon: "timer"
                text: `${root.fmtFocus(root.stats.focusSeconds)} FOCUS`
                tint: Colours.accentAlt
            }
        }

        component SessionChip: Row {
            id: sc

            required property string icon
            required property string text
            required property color tint

            height: 30
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 13
                name: sc.icon
                color: sc.tint
                font.pixelSize: 13
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: sc.text
                color: Colours.ink
                font.family: Appearance.fontFamily.mono
                font.pixelSize: Appearance.font.size.small
                tracking: 0.4
            }
        }

        // footer: clear done + the promise
        Row {
            width: parent.width
            spacing: Appearance.spacing.small

            Item {
                width: clearBtn.width + 6
                height: 40

                Slash {
                    anchors.fill: parent
                    shear: Appearance.skew
                    color: clearArea.containsMouse ? Colours.alpha(Colours.danger, 0.18) : Colours.alpha(Colours.ink, 0.06)
                    borderColor: Colours.alpha(Colours.danger, clearArea.containsMouse ? 0.9 : 0.35)
                    borderWidth: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                Row {
                    id: clearBtn

                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "delete_forever"
                        color: Tasks.doneCount > 0 ? Colours.danger : Colours.inkDim
                        font.pixelSize: Appearance.font.size.normal
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: "CLEAR DONE"
                        color: Tasks.doneCount > 0 ? Colours.danger : Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.2
                    }
                }

                MouseArea {
                    id: clearArea
                    hoverEnabled: true

                    anchors.fill: parent
                    enabled: Tasks.doneCount > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Tasks.clearDone()
                }
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "N NEW  ·  DEL REMOVE  ·  P PIN  ·  F FOCUS  ·  1–0 SECTOR  ·  DBL-CLICK EDIT"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }
        }
    }

    // The quest log's empty state — a direct child of the pane, because the
    // Column would lay it out like a row and break its geometry. Without it
    // the list is a silent void when nothing is tracked.
    Item {
        id: emptyState

        x: list.x
        y: list.y
        width: list.width
        height: list.height
        visible: root.rowList.length === 0 && !addInput.activeFocus

        Column {
            anchors.centerIn: parent
            spacing: 8

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 30
                name: "checklist"
                color: Colours.alpha(Colours.accent, 0.55)
                font.pixelSize: 28
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: "NO ACTIVE QUESTS"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.large
                tracking: 2
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "TYPE ONE ABOVE — OR PRESS N — AND IT SHOWS UP HERE AND IN THE ISLAND"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
            }
        }
    }

    // ----------------------------------------------------------- right column
    //  Scrolls when the screen is short; on a tall screen everything sits
    //  stacked and breathes. The Flickable is the room's only scrolling
    //  surface, so the wheel never fights the task list.
    Flickable {
        id: rightScroll

        x: root.rightX
        width: parent.width - root.rightX
        height: parent.height
        clip: true
        contentHeight: rightCol.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2600
        opacity: root.stage >= 2 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }

        transform: Translate {
            y: root.stage >= 2 ? 0 : 28

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
        }

        Column {
            id: rightCol

            width: parent.width
            spacing: Appearance.spacing.normal

        // ------------------------------------------------------- momentum
        //  Quests are XP: every finished task levels the player up. The
        //  bar counts to the next level, session progress included.
        Plate {
            id: momentum

            width: parent.width
            height: 78
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.ink, 0.05)
            border.width: 1
            border.color: moHover.hovered ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.14)
            scale: moHover.hovered ? 1.012 : 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: moHover
            }

            readonly property int totalDone: Tasks.doneCount + root.sessionDone
            readonly property int level: Math.floor(totalDone / 10) + 1
            readonly property int intoLevel: totalDone % 10

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 14
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    name: "emoji_events"
                    color: Colours.accent
                    font.pixelSize: 15
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: `MOMENTUM  ·  LEVEL ${momentum.level}`
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.normal
                    tracking: 2
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${10 - momentum.intoLevel} QUESTS TO LEVEL ${momentum.level + 1}`
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }
            }

            // The XP bar — fills as you finish tasks, resets each level.
            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                height: 8
                radius: 4
                color: Colours.alpha(Colours.ink, 0.1)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.max(0.04, momentum.intoLevel / 10)
                    radius: 4
                    color: Colours.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: Appearance.anim.slow
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        // ----------------------------------------------------- island preview
        Column {
            width: parent.width
            spacing: Appearance.spacing.small

            P5Text {
                display: true
                text: "HOW IT LOOKS IN THE ISLAND"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 2
            }

            // A faithful miniature of the island's TASKS module — same black
            // surface, same layout, live data.
            Plate {
                id: preview

                width: Math.min(parent.width, 400)
                height: 240
                radius: Appearance.r(26)
                color: "#050505"
                border.width: 1
                border.color: previewHover.hovered ? Colours.alpha(Colours.accent, 0.55) : Colours.alpha(Colours.ink, 0.18)
                clip: true
                scale: previewHover.hovered ? 1.012 : 1

                Behavior on border.color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutCubic
                    }
                }

                HoverHandler {
                    id: previewHover
                }

                Halftone {
                    anchors.fill: parent
                    strength: 0.045
                    density: 1.6
                }

                // the pill row
                Row {
                    anchors.top: parent.top
                    anchors.topMargin: 16
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    spacing: 8

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        name: "checklist"
                        color: Colours.accent
                        font.pixelSize: 15
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: `TASKS  ·  ${Tasks.pill}`
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.small
                    }
                }

                Row {
                    anchors.top: parent.top
                    anchors.topMargin: 18
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    spacing: 6

                    Repeater {
                        model: 5

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: index === 2 ? Colours.accent : Colours.alpha(Colours.ink, 0.28)
                        }
                    }
                }

                // three live rows, mini scale
                Column {
                    anchors.top: parent.top
                    anchors.topMargin: 54
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    spacing: 12

                    Repeater {
                        model: Math.min(3, Tasks.open.length)

                        Row {
                            required property int index

                            width: preview.width - 40
                            spacing: 10

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                radius: Appearance.r(8)
                                color: "transparent"
                                border.width: 1.5
                                border.color: Colours.alpha(Colours.ink, 0.35)
                            }

                            P5Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: preview.width - 40 - 26
                                text: Tasks.open[index]?.text ?? ""
                                color: Colours.ink
                                font.pixelSize: Appearance.font.size.small
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // empty state at mini scale
                    Item {
                        width: parent.width
                        height: 60
                        visible: Tasks.open.length === 0

                        P5Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 12
                            display: true
                            text: "ALL CLEAR"
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.normal
                            tracking: 1.6
                        }

                        P5Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 38
                            text: "ADD A TASK AND WATCH IT APPEAR HERE"
                            color: Colours.inkDim
                            font.pixelSize: Appearance.font.size.tiny
                        }
                    }
                }

                // the add row, mini scale
                Plate {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    height: 30
                    radius: Appearance.r(15)
                    color: Colours.alpha(Colours.ink, 0.07)
                    border.width: 1
                    border.color: Colours.alpha(Colours.ink, 0.16)

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        width: 13
                        name: "add"
                        color: Colours.inkDim
                        font.pixelSize: 13
                    }
                }
            }

            P5Text {
                width: parent.width
                text: "THE TASKS MODULE SITS BETWEEN THE MAP AND THE WEATHER — SWIPE RIGHT FROM THE MAP, OR SET THE ISLAND TO IT."
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
                wrapMode: Text.WordWrap
            }
        }

        // ------------------------------------------------------ the switch
        Plate {
            id: taskSwitch

            width: parent.width
            height: 64
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.ink, 0.05)
            border.width: 1
            border.color: switchHover.hovered ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.14)
            scale: switchHover.hovered ? 1.012 : 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: switchHover
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "checklist"
                    color: Config.map.islandTasks ? Colours.accent : Colours.inkDim
                    font.pixelSize: Appearance.font.size.large
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    P5Text {
                        display: true
                        text: "TASKS IN THE DYNAMIC ISLAND"
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.small
                        tracking: 1.2
                    }

                    P5Text {
                        text: "OFF REMOVES THE MODULE FROM THE SWIPE CYCLE"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                    }
                }
            }

            // the switch
            Plate {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                height: 28
                radius: Appearance.r(14)
                color: Config.map.islandTasks ? Colours.accent : Colours.alpha(Colours.ink, 0.16)
                border.width: 1
                border.color: Config.map.islandTasks ? "transparent" : Colours.alpha(Colours.ink, 0.3)

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.normal
                    }
                }

                Plate {
                    id: knob

                    width: 20
                    height: 20
                    radius: Appearance.r(10)
                    anchors.verticalCenter: parent.verticalCenter
                    x: Config.map.islandTasks ? parent.width - width - 3 : 3
                    color: "#050505"

                    Behavior on x {
                        SpringAnimation {
                            spring: 3.4
                            damping: 0.66
                            epsilon: 0.01
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Config.toggle("map.islandTasks");
                        Sfx.toggle();
                    }
                }
            }
        }

        // ------------------------------------------------------ deep work
        //  A quest timer, session-only: start it, and the ring counts the
        //  minutes down. When it hits zero the shell says so — no popup,
        //  no nags, just the reward sound and a toast.
        Plate {
            id: deepWork

            width: parent.width
            height: 196
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.ink, 0.05)
            border.width: 1
            border.color: dwHover.hovered ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.14)
            scale: dwHover.hovered ? 1.012 : 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: dwHover
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 16
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    name: "timer"
                    color: Colours.accent
                    font.pixelSize: 15
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: "DEEP WORK"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.normal
                    tracking: 2
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.focusRunning ? "RUNNING — THE SHELL WILL TELL YOU WHEN" : "A COUNTDOWN FOR ONE TASK, NO DISTRACTIONS"
                    color: root.focusRunning ? Colours.accentInk : Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }
            }

            CircularProgress {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 54
                width: 84
                height: 84
                thickness: 5
                value: root.focusLeft / Math.max(1, root.focusTotal)
                color: root.focusRunning ? Colours.accent : (root.focusLeft <= 0 ? Colours.accentAlt : Colours.accent)
                text: root.fmtFocus(root.focusLeft)
                textSize: Appearance.font.size.large - 3
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 126
                anchors.top: parent.top
                anchors.topMargin: 60
                spacing: 8

                Row {
                    spacing: 6

                    FocusPreset {
                        label: "25"
                        minutes: 25
                    }

                    FocusPreset {
                        label: "45"
                        minutes: 45
                    }

                    FocusPreset {
                        label: "90"
                        minutes: 90
                    }
                }

                Row {
                    spacing: 8

                    Item {
                        width: 110
                        height: 38

                        Slash {
                            anchors.fill: parent
                            shear: Appearance.skew
                            color: root.focusRunning ? Colours.accent : Colours.alpha(Colours.ink, focusStartArea.containsMouse ? 0.16 : 0.07)
                            borderColor: root.focusRunning ? "transparent" : Colours.alpha(Colours.ink, 0.3)
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
                            text: root.focusRunning ? "PAUSE" : (root.focusLeft < root.focusTotal ? "RESUME" : "START")
                            color: root.focusRunning ? Colours.on(Colours.accent) : Colours.ink
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1.4
                        }

                        MouseArea {
                            id: focusStartArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.focusToggle()
                        }
                    }

                    Item {
                        width: 90
                        height: 38

                        Slash {
                            anchors.fill: parent
                            shear: Appearance.skew
                            color: Colours.alpha(Colours.ink, focusResetArea.containsMouse ? 0.16 : 0.07)
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
                            text: "RESET"
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1.4
                        }

                        MouseArea {
                            id: focusResetArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.focusReset()
                        }
                    }
                }
            }
        }

        component FocusPreset: Item {
            id: focusPresetRoot
            required property string label
            required property int minutes

            width: 44
            height: 30

            Slash {
                anchors.fill: parent
                shear: Appearance.skew
                color: root.focusTotal === focusPresetRoot.minutes * 60 ? Colours.accent : Colours.alpha(Colours.ink, presetArea.containsMouse ? 0.16 : 0.06)
                borderColor: root.focusTotal === focusPresetRoot.minutes * 60 ? "transparent" : Colours.alpha(Colours.ink, 0.3)
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
                text: focusPresetRoot.label
                color: root.focusTotal === focusPresetRoot.minutes * 60 ? Colours.on(Colours.accent) : Colours.ink
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
            }

            MouseArea {
                id: presetArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.focusPreset(focusPresetRoot.minutes)
            }
        }

        // ------------------------------------------------------- now playing
        //  What is playing — the same MPRIS source the island and the lock
        //  use. A live card: the cover wears a progress ring, the title
        //  speaks in the accent, and three quiet round buttons run it.
        Plate {
            id: nowPlaying

            width: parent.width
            height: 132
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.ink, 0.05)
            border.width: 1
            border.color: npHover.hovered ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.14)
            scale: npHover.hovered ? 1.012 : 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: npHover
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 14
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    name: "music_note"
                    color: Colours.accent
                    font.pixelSize: 15
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: "NOW PLAYING"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.normal
                    tracking: 2
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.hasPlayer ? (root.player.isPlaying ? "LIVE  ·  PLAYING" : "ON DECK  ·  PAUSED") : "SILENCE  ·  NOTHING PLAYING"
                    color: root.hasPlayer && root.player.isPlaying ? Colours.accentInk : Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.2
                }
            }

            // the cover, wearing its progress ring
            Item {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 46
                width: 64
                height: 64

                CircularProgress {
                    anchors.fill: parent
                    thickness: 3
                    color: Colours.accent
                    value: {
                        root.tick;
                        return root.hasPlayer && root.player.length > 0 ? root.player.position / root.player.length : 0;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 7
                    radius: width / 2
                    color: Colours.alpha(Colours.ink, 0.08)
                    clip: true

                    Image {
                        anchors.fill: parent
                        visible: root.hasPlayer && (root.player.trackArtUrl ?? "") !== ""
                        source: root.hasPlayer ? root.player.trackArtUrl ?? "" : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }

                    Icon {
                        anchors.centerIn: parent
                        visible: !(root.hasPlayer && (root.player.trackArtUrl ?? "") !== "")
                        name: "music_note"
                        color: Colours.alpha(Colours.ink, 0.6)
                        font.pixelSize: 22
                    }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 100
                anchors.right: parent.right
                anchors.rightMargin: 190
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 8
                spacing: 2

                P5Text {
                    width: parent.width
                    display: true
                    text: root.hasPlayer ? (root.player.trackTitle ?? "") : "NOTHING IN THE QUEUE"
                    color: root.hasPlayer ? Colours.ink : Colours.inkDim
                    font.pixelSize: Appearance.font.size.large
                    tracking: 0.4
                    elide: Text.ElideRight
                }

                P5Text {
                    width: parent.width
                    text: root.hasPlayer ? `${root.player.trackArtist ?? "UNKNOWN ARTIST"}   ·   ${root.player.trackAlbum ?? ""}` : "PUT SOMETHING ON AND IT LANDS HERE — ALSO IN THE ISLAND"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                    elide: Text.ElideRight
                }
            }

            // previous · play/pause · next
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 8
                spacing: 10

                MediaButton {
                    icon: "skip_previous"
                    live: root.hasPlayer
                    onTap: root.player.previous()
                }

                MediaButton {
                    icon: root.hasPlayer && root.player.isPlaying ? "pause" : "play_arrow"
                    big: true
                    live: root.hasPlayer
                    onTap: root.player.togglePlaying()
                }

                MediaButton {
                    icon: "skip_next"
                    live: root.hasPlayer
                    onTap: root.player.next()
                }
            }

            // The little equalizer — five bars dancing while something plays.
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                spacing: 4

                Repeater {
                    model: 5

                    Rectangle {
                        required property int index

                        width: 5
                        height: 6
                        radius: 2.5
                        anchors.bottom: parent.bottom
                        color: Colours.alpha(Colours.accent, 0.7)

                        SequentialAnimation on height {
                            running: root.hasPlayer && (root.player?.isPlaying ?? false)
                            loops: Animation.Infinite
                            NumberAnimation {
                                from: 6
                                to: 20 + index * 4
                                duration: 300 + index * 70
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                to: 6
                                duration: 320 + index * 60
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }
            }

            component MediaButton: Item {
                id: mb

                required property string icon
                property bool big: false
                property bool live: true
                signal tap

                width: mb.big ? 48 : 40
                height: mb.big ? 48 : 40
                scale: mbArea.pressed ? 0.9 : (mbArea.containsMouse ? 1.08 : 1)
                opacity: mb.live ? 1 : 0.4

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.6
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: mbArea.containsMouse && mb.live ? Colours.alpha(Colours.ink, 0.1) : "transparent"
                    border.width: 1
                    border.color: Colours.alpha(Colours.ink, mb.big ? 0.45 : 0.3)

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: mb.icon
                    color: Colours.ink
                    font.pixelSize: mb.big ? 22 : 18
                }

                MouseArea {
                    id: mbArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!mb.live)
                            return;
                        Sfx.cursor();
                        mb.tap();
                    }
                }
            }
        }

        // --------------------------------------------------------- sectors
        //  The workspaces as a mission map: occupied sectors glow, the one
        //  you are in is filled. Click a sector — or press its number — and
        //  the whole shell jumps there.
        Plate {
            id: sectorsCard

            width: parent.width
            height: 168
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.ink, 0.05)
            border.width: 1
            border.color: sectorsHover.hovered ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.14)
            scale: sectorsHover.hovered ? 1.012 : 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: sectorsHover
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 14
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    name: "grid_view"
                    color: Colours.accent
                    font.pixelSize: 15
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: "SECTORS"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.normal
                    tracking: 2
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CLICK ONE — OR PRESS ITS NUMBER"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }
            }

            Grid {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 48
                columns: 5
                spacing: 8

                Repeater {
                    model: 10

                    Item {
                        required property int index

                        readonly property int ws: index + 1
                        readonly property bool occ: Hypr.workspaceOccupied(ws)
                        readonly property bool here: Hypr.activeWsId === ws

                        width: (parent.width - parent.spacing * 4) / 5
                        height: 44

                        Slash {
                            anchors.fill: parent
                            shear: Appearance.skew
                            color: here ? Colours.accent : (occ ? Colours.alpha(Colours.accent, 0.1) : Colours.alpha(Colours.ink, 0.04))
                            borderColor: here ? "transparent" : (occ ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.2))
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
                            text: `${ws}`
                            color: here ? Colours.on(Colours.accent) : (occ ? Colours.accentInk : Colours.inkDim)
                            font.pixelSize: Appearance.font.size.normal
                            tracking: 0
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.jumpSector(ws)
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------- warp
        //  Jump between rooms and overlays without leaving the flow.
        Plate {
            id: warpCard

            width: parent.width
            height: 96
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.ink, 0.05)
            border.width: 1
            border.color: warpHover.hovered ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.14)
            scale: warpHover.hovered ? 1.012 : 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: warpHover
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.top: parent.top
                anchors.topMargin: 12
                spacing: 10

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    name: "bolt"
                    color: Colours.accent
                    font.pixelSize: 15
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: "WARP"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.normal
                    tracking: 2
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "JUMP TO ANOTHER ROOM — ESC GOES HOME TOO"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 14
                spacing: 10

                WarpButton {
                    label: "SETTINGS"
                    icon: "tune"
                    fn: () => Panels.openSettingsZoneNamed("SETTINGS")
                }

                WarpButton {
                    label: "QUICK SETTINGS"
                    icon: "bolt"
                    fn: () => Panels.openSettingsZoneNamed("QUICK")
                }

                WarpButton {
                    label: "DESKTOP MAP"
                    icon: "map"
                    fn: () => {
                        Panels.closeAll();
                        Panels.toggleWindowMap();
                    }
                }

                WarpButton {
                    label: "LAUNCHER"
                    icon: "rocket_launch"
                    fn: () => {
                        Panels.closeAll();
                        Panels.toggleLauncher();
                    }
                }

                WarpButton {
                    label: "HOME"
                    icon: "home"
                    fn: () => Panels.openSettingsZoneNamed("HOME")
                }
            }

            component WarpButton: Item {
                id: wb

                required property string label
                required property string icon
                required property var fn

                width: (parent.width - parent.spacing * 4) / 5
                height: 38
                scale: wbArea.containsMouse ? 1.05 : 1

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
                    color: wbArea.containsMouse ? Colours.alpha(Colours.ink, 0.14) : Colours.alpha(Colours.ink, 0.06)
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
                        width: 15
                        name: wb.icon
                        color: Colours.accent
                        font.pixelSize: 14
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: wb.label
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1
                    }
                }

                MouseArea {
                    id: wbArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sfx.select();
                        wb.fn();
                    }
                }
            }
        }

        // ------------------------------------------------------------- tips
        Plate {
            id: tipsCard

            width: parent.width
            height: 96
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.ink, 0.05)
            border.width: 1
            border.color: tipsHover.hovered ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.14)
            scale: tipsHover.hovered ? 1.012 : 1

            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: tipsHover
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Row {
                    spacing: 10

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        name: "bolt"
                        color: Colours.accent
                        font.pixelSize: 14
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "PIN KEEPS A TASK ON TOP OF THE LIST"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.small
                    }
                }

                Row {
                    spacing: 10

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        name: "bolt"
                        color: Colours.accent
                        font.pixelSize: 14
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CHECK OFF FROM THE ISLAND ITSELF — TAP THE CIRCLE"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.small
                    }
                }

                Row {
                    spacing: 10

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        name: "bolt"
                        color: Colours.accent
                        font.pixelSize: 14
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TASKS SURVIVE RESTARTS — THEY LIVE IN ~/.CONFIG/VELVET/TASKS.JSON"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
        }

        SmoothScroll {
            view: rightScroll
        }
    }

    // --------------------------------------------------------------- keyboard
    Keys.onPressed: event => {
        if (addInput.activeFocus)
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
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            root.toggleCurrent();
            event.accepted = true;
            return;
        case Qt.Key_Delete:
        case Qt.Key_Backspace:
            root.removeCurrent();
            event.accepted = true;
            return;
        case Qt.Key_P:
            root.pinCurrent();
            event.accepted = true;
            return;
        case Qt.Key_N:
            root.startAdd();
            event.accepted = true;
            return;
        case Qt.Key_F:
            root.focusToggle();
            event.accepted = true;
            return;
        case Qt.Key_R:
            root.focusReset();
            event.accepted = true;
            return;
        case Qt.Key_1:
        case Qt.Key_2:
        case Qt.Key_3:
        case Qt.Key_4:
        case Qt.Key_5:
        case Qt.Key_6:
        case Qt.Key_7:
        case Qt.Key_8:
        case Qt.Key_9:
            root.jumpSector(event.key - Qt.Key_1 + 1);
            event.accepted = true;
            return;
        case Qt.Key_0:
            root.jumpSector(10);
            event.accepted = true;
            return;
        case Qt.Key_Home:
            root.rowIdx = 0;
            list.positionViewAtIndex(0, ListView.Contain);
            event.accepted = true;
            return;
        case Qt.Key_End:
            root.rowIdx = Math.max(0, root.rowList.length - 1);
            list.positionViewAtIndex(root.rowIdx, ListView.Contain);
            event.accepted = true;
            return;
        }
        // Everything else (Escape above all) bubbles to the settings'
        // key brain through Keys.forwardTo set on the instance.
    }

    // ------------------------------------------------------------ task row
    component TaskRow: Item {
        id: row

        required property var task
        required property bool sel
        property bool hovered: false
        property bool editing: false

        signal edited(int id, string text)

        readonly property bool done: row.task?.done ?? false

        Plate {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            radius: Appearance.rounding.normal
            color: row.sel ? Colours.alpha(Colours.accent, 0.12) : (row.hovered ? Colours.alpha(Colours.ink, 0.05) : "transparent")
            border.width: 1
            border.color: row.sel ? Colours.alpha(Colours.accent, 0.55) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        // the check circle
        Plate {
            anchors.verticalCenter: parent.verticalCenter
            x: 20
            width: 24
            height: 24
            radius: Appearance.r(12)
            color: row.done ? Colours.accent : "transparent"
            border.width: 1.5
            border.color: row.done ? Colours.accent : Colours.alpha(Colours.ink, 0.4)
            scale: checkArea.pressed ? 0.85 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }

            Icon {
                anchors.centerIn: parent
                width: 14
                visible: row.done
                name: "check"
                color: "#050505"
                font.pixelSize: 14
            }
        }

        // the text — or the editor while double-clicked
        P5Text {
            anchors.left: parent.left
            anchors.leftMargin: 58
            anchors.right: parent.right
            anchors.rightMargin: row.hovered ? 92 : 20
            anchors.verticalCenter: parent.verticalCenter
            visible: !row.editing
            text: row.task?.text ?? ""
            color: row.done ? Colours.alpha(Colours.inkDim, 0.75) : Colours.ink
            font.pixelSize: row.done ? Appearance.font.size.small : Appearance.font.size.normal
            elide: Text.ElideRight
            font.strikeout: row.done

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Plate {
            z: 1
            anchors.left: parent.left
            anchors.leftMargin: 56
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            height: 34
            radius: Appearance.r(6)
            visible: row.editing
            color: Colours.alpha(Colours.ink, 0.07)
            border.width: 1
            border.color: Colours.accent
            clip: true

            TextInput {
                id: editInput

                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Colours.ink
                font.family: Appearance.fontFamily.body
                font.pixelSize: Appearance.font.size.normal
                selectByMouse: true
                cursorDelegate: Rectangle {
                    width: 2
                    color: Colours.accent
                }

                onAccepted: {
                    row.edited(row.task.id, text);
                    row.editing = false;
                    root.forceActiveFocus();
                }

                Keys.onEscapePressed: event => {
                    row.editing = false;
                    root.forceActiveFocus();
                    event.accepted = true;
                }
            }
        }

        // pin + remove, on hover
        Icon {
            z: 1
            anchors.right: parent.right
            anchors.rightMargin: 52
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            visible: row.hovered && !row.done
            name: "push_pin"
            color: (row.task?.pinned ?? false) ? Colours.accent : Colours.alpha(Colours.ink, 0.45)
            font.pixelSize: 15

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: Tasks.togglePin(row.task.id)
            }
        }

        Icon {
            z: 1
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            visible: row.hovered
            name: "close"
            color: Colours.alpha(Colours.ink, 0.5)
            font.pixelSize: 16

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: Tasks.remove(row.task.id)
            }
        }

        MouseArea {
            id: checkArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: row.hovered = true
            onExited: row.hovered = false
            enabled: !row.editing
            // Only the circle checks a task off — a click on the text is the
            // first half of the double-click that renames it.
            onClicked: mouse => {
                if (mouse.x < 56)
                    Tasks.toggle(row.task.id);
            }
            onDoubleClicked: {
                row.editing = true;
                editInput.text = row.task?.text ?? "";
                editInput.forceActiveFocus();
                editInput.cursorPosition = editInput.text.length;
            }
        }
    }
}
