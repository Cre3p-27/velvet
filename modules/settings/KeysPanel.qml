//  VELVET  ·  modules/settings/KeysPanel.qml
//  The key menu — Super+Shift+K, the bar module, or `qs -c velvet ipc call
//  keys toggle`. Two halves: YOUR GLOBAL KEYS on the left, live-editable
//  (pick a row, press Enter, hold your modifiers and hit the new key — it
//  applies instantly through hyprctl and is saved for the next boot), and
//  the context reference on the right, straight from Shortcuts.qml so it
//  can never drift from the truth.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: panel

    readonly property bool open: Panels.keys
    property bool entered: false
    property bool rendered: false

    // ---------------------------------------------------------- editor state
    property int cur: 0
    property bool capturing: false

    readonly property real padX: Math.max(36, panel.width * 0.04)
    readonly property real railY: panel.height * 0.145

    function keyName(key: int): string {
        if (key >= Qt.Key_A && key <= Qt.Key_Z)
            return String.fromCharCode(key);
        if (key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F12)
            return `F${key - Qt.Key_F1 + 1}`;
        switch (key) {
        case Qt.Key_Tab:
            return "Tab";
        case Qt.Key_Space:
            return "Space";
        case Qt.Key_Escape:
            return "Escape";
        case Qt.Key_Return:
        case Qt.Key_Enter:
            return "Return";
        case Qt.Key_Up:
            return "Up";
        case Qt.Key_Down:
            return "Down";
        case Qt.Key_Left:
            return "Left";
        case Qt.Key_Right:
            return "Right";
        case Qt.Key_Home:
            return "Home";
        case Qt.Key_End:
            return "End";
        case Qt.Key_PageUp:
            return "Page_Up";
        case Qt.Key_PageDown:
            return "Page_Down";
        }
        return "";
    }

    function tryCapture(event: var): void {
        const name = panel.keyName(event.key);
        if (name === "") {
            // A modifier press alone — it will ride the next real key.
            Sfx.cursor();
            return;
        }
        const mods = [];
        if (event.modifiers & Qt.MetaModifier)
            mods.push("SUPER");
        if (event.modifiers & Qt.ControlModifier)
            mods.push("CTRL");
        if (event.modifiers & Qt.AltModifier)
            mods.push("ALT");
        if (event.modifiers & Qt.ShiftModifier)
            mods.push("SHIFT");
        const order = ["SUPER", "SHIFT", "CTRL", "ALT"];
        const ordered = [];
        for (let i = 0; i < order.length; i++)
            if (mods.indexOf(order[i]) !== -1)
                ordered.push(order[i]);
        if (ordered.length === 0) {
            Toast.show("HOLD A MODIFIER WITH THE KEY  ·  SUPER / CTRL / ALT", "warn", 3200);
            Sfx.back();
            return;
        }
        const def = Binds.defs[Math.max(0, Math.min(Binds.defs.length - 1, panel.cur))];
        Binds.set(def.id, ordered, name);
        panel.capturing = false;
        event.accepted = true;
    }

    function moveCur(d: int): void {
        const n = Binds.defs.length;
        if (n === 0)
            return;
        panel.cur = (panel.cur + d + n) % n;
        Sfx.cursor();
        panel.boxFor();
    }

    function boxFor(): void {
        const it = rowRepeater.itemAt(panel.cur);
        if (!it) {
            ring.visible = false;
            return;
        }
        const p = it.mapToItem(rail, 0, 0);
        ring.x = p.x - 6;
        ring.y = p.y - 5;
        ring.width = it.width + 12;
        ring.height = it.height + 10;
        ring.visible = true;
    }

    screen: Hypr.focusedScreen
    visible: rendered
    color: "transparent"

    WlrLayershell.namespace: "velvet-keys"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    onOpenChanged: {
        if (panel.open) {
            panel.rendered = true;
            enterTimer.restart();
            Sfx.open();
        } else {
            panel.entered = false;
            exitTimer.restart();
            Sfx.close();
        }
    }

    onCurChanged: panel.boxFor()

    Timer {
        id: enterTimer
        interval: 16
        onTriggered: {
            panel.entered = true;
            panel.capturing = false;
            scope.forceActiveFocus();
            panel.boxFor();
        }
    }

    Timer {
        id: exitTimer
        interval: Appearance.anim.normal + 40
        onTriggered: panel.rendered = false
    }

    // --------------------------------------------------------------- visuals
    Item {
        id: stage

        anchors.fill: parent
        opacity: panel.entered ? 1 : 0
        scale: panel.entered ? 1 : 1.03

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.entrance
                easing.type: Easing.OutExpo
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Colours.alpha(Colours.paper, 0.93)
        }

        Halftone {
            anchors.fill: parent
            strength: 0.035
            density: 1.6
        }

        // ---------------------------------------------------------- header
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.05
            spacing: 0

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: "THE KEYBINDS"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.hero * 0.5
                tracking: -1
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "↑ ↓ PICK   ·   ENTER REBIND   ·   R RESET ONE   ·   BACKSPACE RESET ALL   ·   ESC CLOSE"
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.small
                tracking: 2.4
            }
        }

        // ------------------------------------------------------ editor rail
        Item {
            id: rail

            x: panel.padX
            y: panel.railY
            width: Math.min(560, parent.width * 0.34)
            height: parent.height - panel.railY - parent.height * 0.05

            Row {
                spacing: 10

                Slash {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: 20
                    color: Colours.accent
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: "GLOBAL KEYS"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.large
                }
            }

            P5Text {
                x: 15
                y: 28
                text: "YOURS TO CHANGE — APPLIED LIVE AND SAVED FOR THE NEXT BOOT"
                color: Colours.alpha(Colours.inkDim, 0.8)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 2
            }

            Column {
                id: rows

                anchors.top: parent.top
                anchors.topMargin: 52
                width: parent.width
                spacing: 6

                Repeater {
                    id: rowRepeater

                    model: Binds.defs

                    Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool chosen: row.index === panel.cur
                        readonly property bool listening: row.chosen && panel.capturing

                        width: rows.width
                        height: 58
                        scale: row.chosen ? 1.02 : 1

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
                            color: row.listening ? Colours.alpha(Colours.accent, 0.9) : (row.chosen ? Colours.alpha(Colours.accent, 0.16) : Colours.alpha(Colours.ink, 0.05))
                            borderColor: row.listening ? "transparent" : (row.chosen ? Colours.accent : Colours.alpha(Colours.ink, 0.14))
                            borderWidth: 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        P5Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 18
                            anchors.verticalCenter: parent.verticalCenter
                            display: true
                            text: row.modelData.label
                            color: row.listening ? Colours.on(Colours.accent) : Colours.ink
                            font.pixelSize: Appearance.font.size.small
                            tracking: 1.2
                        }

                        // The combo keycap — or LISTENING while it waits.
                        Slash {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(128, comboText.implicitWidth + 30)
                            height: 32
                            shear: Appearance.skew
                            color: row.listening ? Colours.accent : Colours.alpha(Colours.ink, 0.1)
                            borderColor: row.listening ? "transparent" : Colours.alpha(Colours.ink, 0.25)
                            borderWidth: 1

                            SequentialAnimation on opacity {
                                running: row.listening
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0.55
                                    duration: 380
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 380
                                    easing.type: Easing.InOutSine
                                }
                            }

                            P5Text {
                                id: comboText

                                anchors.centerIn: parent
                                display: true
                                text: row.listening ? "LISTENING…" : Binds.display(row.modelData.id)
                                color: row.listening ? Colours.on(Colours.accent) : Colours.ink
                                font.pixelSize: Appearance.font.size.tiny
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (row.chosen && !panel.capturing) {
                                    panel.capturing = true;
                                    Sfx.open();
                                } else {
                                    panel.cur = row.index;
                                    Sfx.cursor();
                                }
                            }
                        }
                    }
                }
            }

            // RESET ALL, at the rail's foot.
            Item {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                width: 150
                height: 40
                scale: resetArea.containsMouse ? 1.05 : 1

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
                    color: resetArea.containsMouse ? Colours.alpha(Colours.danger, 0.18) : Colours.alpha(Colours.ink, 0.06)
                    borderColor: Colours.alpha(Colours.danger, resetArea.containsMouse ? 0.9 : 0.35)
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
                        name: "restart_alt"
                        color: Colours.danger
                        font.pixelSize: Appearance.font.size.normal
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: "RESET ALL"
                        color: Colours.danger
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.2
                    }
                }

                MouseArea {
                    id: resetArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Binds.resetAll()
                }
            }
        }

        // ------------------------------------------------------ the cursor
        Rectangle {
            id: ring

            radius: Appearance.rounding.normal
            color: "transparent"
            border.width: 2
            border.color: Colours.accent
            visible: false
            z: 5
        }

        // ------------------------------------------------------- reference
        //  Everything else, straight from Shortcuts.qml — context keys the
        //  shell gives you, but that are not yours to move around here.
        Flickable {
            id: refScroll

            anchors.left: rail.right
            anchors.leftMargin: Appearance.spacing.huge
            anchors.right: parent.right
            anchors.rightMargin: panel.padX
            anchors.top: rail.top
            anchors.bottom: rail.bottom
            clip: true
            contentHeight: refFlow.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Flow {
                id: refFlow

                width: parent.width
                spacing: Appearance.spacing.large

                Repeater {
                    model: Shortcuts.sections.slice(1)

                    Column {
                        id: section

                        required property var modelData
                        required property int index

                        width: Math.floor((refFlow.width - Appearance.spacing.large * 2) / 3)
                        spacing: 6

                        opacity: 0

                        Component.onCompleted: enter.start()

                        SequentialAnimation {
                            id: enter

                            PauseAnimation {
                                duration: section.index * 55
                            }
                            NumberAnimation {
                                target: section
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: Appearance.anim.normal
                                easing.type: Easing.OutCubic
                            }
                        }

                        Row {
                            spacing: 10

                            Slash {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 5
                                height: 20
                                color: Colours.accent
                            }

                            P5Text {
                                anchors.verticalCenter: parent.verticalCenter
                                display: true
                                text: section.modelData.name
                                color: Colours.ink
                                font.pixelSize: Appearance.font.size.large
                            }
                        }

                        P5Text {
                            x: 15
                            text: section.modelData.sub
                            color: Colours.alpha(Colours.inkDim, 0.8)
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 2
                            bottomPadding: 6
                        }

                        Repeater {
                            model: section.modelData.keys

                            Row {
                                id: binding

                                required property var modelData

                                spacing: 10
                                height: 28

                                Slash {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(64, cap.implicitWidth + 20)
                                    height: 24
                                    shear: Appearance.skew
                                    color: Colours.alpha(Colours.ink, 0.1)
                                    borderColor: Colours.alpha(Colours.ink, 0.25)
                                    borderWidth: 1

                                    P5Text {
                                        id: cap

                                        anchors.centerIn: parent
                                        display: true
                                        text: binding.modelData.k
                                        color: Colours.ink
                                        font.pixelSize: Appearance.font.size.tiny
                                    }
                                }

                                P5Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: binding.modelData.v
                                    color: Colours.inkDim
                                    font.pixelSize: Appearance.font.size.small
                                }
                            }
                        }
                    }
                }
            }

            SmoothScroll {
                view: refScroll
            }
        }
    }

    // --------------------------------------------------------------- keys
    FocusScope {
        id: scope

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            // Capture owns the keyboard: the next real key press becomes
            // the new combo, Escape steps out of capture instead.
            if (panel.capturing) {
                if (event.key === Qt.Key_Escape) {
                    panel.capturing = false;
                    Sfx.back();
                    event.accepted = true;
                    return;
                }
                panel.tryCapture(event);
                event.accepted = true;
                return;
            }

            switch (event.key) {
            case Qt.Key_Escape:
                Panels.keys = false;
                event.accepted = true;
                return;
            case Qt.Key_Up:
                panel.moveCur(-1);
                event.accepted = true;
                return;
            case Qt.Key_Down:
                panel.moveCur(1);
                event.accepted = true;
                return;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                panel.capturing = true;
                Sfx.open();
                event.accepted = true;
                return;
            case Qt.Key_R:
                if (panel.cur >= 0 && panel.cur < Binds.defs.length)
                    Binds.reset(Binds.defs[panel.cur].id);
                event.accepted = true;
                return;
            case Qt.Key_Backspace:
                Binds.resetAll();
                event.accepted = true;
                return;
            }
        }
    }

    // Panels are loaded on demand (shell.qml, Parked): when this window is created by
    // its own flag the change signal has already gone by, so say it once more.
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (panel.open)
                panel.openChanged();
        }
    }
}
