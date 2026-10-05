//  VELVET  ·  modules/settings/ModuleInspector.qml
//  Everything a desktop MODULE can be — the Velvet programs in bin/ and the
//  terminal programs from MORE MODULES — on one scrollable card, built from
//  the catalogue (config/TermApps.qml) so a module gets its switches the
//  moment the catalogue lists them.
//
//    APPLY           restart it with what you just picked (or on every pick)
//    COLOUR          velvet modules: a palette colour or any colour
//    LAYOUT & MOTION velvet modules: upside down, mirror, where it sits,
//                    outline, tempo, frame rate
//    <MODULE>        its own switches (cava: direction, channels, colours …)
//    SWITCHES · EXTRA ARGUMENTS   the classic flags, and anything else
//    WINDOW          text size, background, padding
//    SIZE & PLACE    the snap presets
import qs.config
import qs.services
import qs.components
import QtQuick

Flickable {
    id: root

    required property var item       // the chosen scene entry (kind term / tui)
    required property int itemIndex  // its place in Scenes.editing
    property var snaps: []

    // A text field has the keyboard: the designer keeps its hands off.
    readonly property bool typing: argsField.activeFocus

    readonly property bool velvet: root.item?.kind === "term"
    readonly property string mid: Scenes.moduleOf(root.item)
    readonly property var opts: root.item?.opts ?? ({})
    readonly property var vals: root.opts.o ?? ({})
    readonly property var win: root.opts.win ?? ({})
    readonly property var own: TermApps.optionsOf(root.mid)
    readonly property var flags: TermApps.flagsOf(root.mid)
    readonly property bool running: Scenes.isRunning(root.item)
    // Velvet's programs and cava take their switches while they run; a plain
    // terminal program (cmatrix, btop …) only reads them when it starts.
    readonly property bool liveCapable: Scenes.liveCapable(root.item)
    // Its window was started by an older Velvet — no live channel, no
    // remote-control socket — so one restart is needed before live works.
    readonly property bool legacy: {
        const w = root.running ? Scenes.windowFor(root.item) : null;
        return w !== null && Scenes.norm(w.cls) !== Scenes.norm(Scenes.classFor(root.item));
    }

    // For programs that cannot take changes live: restart them on every
    // pick (on by default) or collect the changes for one RESTART NOW.
    property bool live: true
    property bool dirty: false

    contentWidth: width
    contentHeight: col.implicitHeight + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    onItemIndexChanged: root.dirty = false

    // what: "switch" (the program's own settings) or "window" (kitty's).
    function patchOpts(fields: var, what: string): void {
        Scenes.patchAt(root.itemIndex, {
            opts: Object.assign({}, root.opts, fields)
        });
        Sfx.toggle();
        root.changed(what);
    }

    // reopen: the switch changes the window itself (cava's DIRECTION moves
    // the edge kitty keeps its padding and spare pixels away from), so the
    // module restarts instead of redrawing.
    function setVal(key: string, value: var, reopen: bool): void {
        const next = Object.assign({}, root.vals);
        if (value === "" || value === undefined)
            delete next[key];
        else
            next[key] = value;
        root.patchOpts({
            o: next
        }, reopen ? "reopen" : "switch");
    }

    function setWin(key: string, value: var): void {
        const next = Object.assign({}, root.win);
        next[key] = value;
        const extra = {
            win: next
        };
        if (key === "bg")
            extra.transparent = false;   // the old SEE-THROUGH switch is now a BACKGROUND choice
        root.patchOpts(extra, "window");
    }

    // The chosen flags as a plain array — whatever list type they arrive as
    // (a QML model hands arrays over as sequences, not always as Array).
    readonly property var flagsOn: {
        const f = root.opts.flags;
        const out = [];
        if (f && f.length !== undefined)
            for (let i = 0; i < f.length; i++)
                out.push(String(f[i]));
        return out;
    }

    function toggleFlag(arg: string): void {
        const cur = root.flagsOn.slice();
        const i = cur.indexOf(arg);
        if (i === -1)
            cur.push(arg);
        else
            cur.splice(i, 1);
        root.patchOpts({
            flags: cur
        }, "switch");
    }

    function changed(what: string): void {
        if (!root.running)
            return;
        const fresh = Scenes.editing[root.itemIndex];
        if (!fresh)
            return;
        if (root.legacy) {
            root.dirty = true;
            return;
        }
        if (what === "window") {
            Scenes.applyWindow(fresh);          // instant: kitty remote control
            return;
        }
        if (what === "reopen") {
            applyTimer.restart();
            return;
        }
        if (root.liveCapable) {
            Scenes.writeLive(fresh);            // instant: the program redraws
            return;
        }
        if (root.live)
            applyTimer.restart();
        else
            root.dirty = true;
    }

    // A beat after the last pick, so clicking through five choices restarts
    // a plain terminal program once, not five times.
    Timer {
        id: applyTimer

        interval: 650
        onTriggered: root.apply()
    }

    function apply(): void {
        root.dirty = false;
        // The entry as it is saved NOW, not the one this card was built from.
        const fresh = Scenes.editing[root.itemIndex];
        if (fresh)
            Scenes.relaunch(fresh);
    }

    Column {
        id: col

        width: root.width
        spacing: 16

        // ════════════════════════════════════════════════ LIVE PREVIEW (cava)
        // The look, at the box's own proportions, with every pick below
        // showing at once — from the music playing now, or a demo swell.
        Item {
            id: cavaStage

            readonly property var mon: Desk.focusedMonitor
            readonly property real boxW: (root.item?.w ?? 0.3) * (cavaStage.mon?.w ?? 3200)
            readonly property real boxH: (root.item?.h ?? 0.2) * (cavaStage.mon?.h ?? 1800)
            readonly property real fontPx: 0.834 * (Number(root.item?.opts?.win?.size ?? 0) || 11)
            readonly property bool side: (root.vals.orient ?? "") === "left" || (root.vals.orient ?? "") === "right"

            visible: root.mid === "cava"
            width: parent.width
            height: visible ? previewBox.height + previewLabel.implicitHeight + 8 : 0

            P5Text {
                id: previewLabel

                display: true
                text: "LIVE PREVIEW"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.small
                tracking: 1.4
            }

            P5Text {
                anchors.right: parent.right
                anchors.baseline: previewLabel.baseline
                text: Spectrum.live ? "YOUR MUSIC, NOW" : "DEMO · PLAY SOMETHING"
                color: Spectrum.live ? Colours.accent : Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
            }

            Plate {
                id: previewBox

                y: previewLabel.implicitHeight + 8
                width: parent.width
                // The box's own shape, within reason.
                height: Math.round(Math.max(70, Math.min(260, parent.width * cavaStage.boxH / Math.max(1, cavaStage.boxW))))
                radius: Appearance.rounding.small
                color: Colours.alpha(Colours.paper, 0.9)
                border.width: 1
                border.color: Colours.alpha(Colours.ink, 0.12)
                clip: true
                antialiasing: true

                CavaPreview {
                    anchors.fill: parent
                    anchors.margins: 1
                    running: cavaStage.visible && root.visible
                    o: root.vals
                    columns: cavaStage.side ? cavaStage.boxH / (cavaStage.fontPx * 2) : cavaStage.boxW / cavaStage.fontPx
                }
            }
        }

        // ═══════════════════════════════════════════════════════════ APPLY
        Plate {
            width: parent.width
            height: applyRow.implicitHeight + 16
            radius: Appearance.rounding.small
            readonly property color tone: (root.dirty || root.legacy) ? Colours.warning : (root.running ? Colours.success : Colours.inkDim)
            color: Colours.alpha(tone, 0.1)
            border.width: 1
            border.color: Colours.alpha(tone, 0.4)
            antialiasing: true

            Column {
                id: applyRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8

                P5Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: {
                        if (!root.running)
                            return "NOT RUNNING  ·  YOUR PICKS APPLY WHEN IT OPENS";
                        if (root.legacy)
                            return "STARTED BY AN OLDER VELVET  ·  RESTART IT ONCE AND EVERY PICK SHOWS INSTANTLY";
                        if (root.liveCapable)
                            return "LIVE  ·  EVERY PICK SHOWS INSTANTLY, NO RESTART";
                        if (root.dirty)
                            return "RUNNING WITH THE OLD SETTINGS";
                        return root.live ? "THIS PROGRAM READS ITS SETTINGS AT START  ·  EACH PICK RESTARTS IT" : "THIS PROGRAM READS ITS SETTINGS AT START";
                    }
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.2
                }

                Row {
                    spacing: 6
                    visible: root.running

                    InsChip {
                        glyph: "refresh"
                        text: "RESTART NOW"
                        lit: root.dirty
                        onClicked: root.apply()
                    }
                    InsChip {
                        visible: !root.liveCapable
                        glyph: root.live ? "bolt" : "pause"
                        text: root.live ? "AUTO-RESTART ON" : "AUTO-RESTART OFF"
                        lit: root.live
                        onClicked: root.live = !root.live
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════ COLOUR (velvet)
        InsSection {
            visible: root.velvet
            title: "COLOUR"
            note: "AUTO FOLLOWS YOUR WALLPAPER"
        }

        InsOption {
            visible: root.velvet
            label: "FROM THE PALETTE"

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: "auto",
                        t: "AUTO"
                    },
                    {
                        v: "accent",
                        t: "ACCENT"
                    },
                    {
                        v: "alt",
                        t: "SECOND"
                    },
                    {
                        v: "ink",
                        t: "INK"
                    },
                    {
                        v: "paper",
                        t: "PAPER"
                    }
                ]
                current: root.opts.tint ?? "auto"
                onChosen: v => root.patchOpts({
                        tint: v
                    }, "switch")
            }
        }

        InsOption {
            visible: root.velvet
            label: "OR ANY COLOUR"

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: ["ff5566", "ff8a3d", "ffb300", "3ddc84", "26c6da", "4f8cff", "b388ff", "ff6ec7", "ffffff"]

                    Plate {
                        id: sw

                        required property string modelData
                        readonly property bool lit: String(root.opts.tint ?? "").replace("#", "").toLowerCase() === sw.modelData

                        width: 30
                        height: 30
                        radius: Appearance.rounding.small
                        color: "#" + sw.modelData
                        border.width: sw.lit ? 2 : 1
                        border.color: sw.lit ? Colours.ink : Colours.alpha(Colours.ink, swArea.containsMouse ? 0.5 : 0.15)
                        antialiasing: true

                        Icon {
                            anchors.centerIn: parent
                            visible: sw.lit
                            name: "check"
                            color: Colours.on(sw.color)
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: swArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.patchOpts({
                                tint: sw.modelData
                            }, "switch")
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════ LAYOUT & MOTION (velvet)
        InsSection {
            visible: root.velvet
            title: "LAYOUT & MOTION"
            note: "EVERY VELVET MODULE CAN DO THESE"
        }

        Repeater {
            model: root.velvet ? TermApps.shared : []

            InsOption {
                required property var modelData

                width: col.width
                label: modelData.label
                note: modelData.note ?? ""

                InsChoice {
                    width: parent.width
                    model: modelData.choices
                    current: root.vals[modelData.key] ?? ""
                    onChosen: v => root.setVal(modelData.key, v, modelData.relaunch === true)
                }
            }
        }

        // ══════════════════════════════════════════ what only this one has
        InsSection {
            visible: root.own.length > 0
            title: `${TermApps.nameOf(root.mid)} ONLY`
            note: root.mid === "cava" ? "BARS, A SMOOTH WAVE OR A LINE · IN YOUR WALLPAPER'S COLOURS" : "ITS OWN SWITCHES"
        }

        Repeater {
            model: root.own

            InsOption {
                required property var modelData

                width: col.width
                label: modelData.label
                note: modelData.note ?? ""

                InsChoice {
                    width: parent.width
                    model: modelData.choices
                    current: root.vals[modelData.key] ?? ""
                    onChosen: v => root.setVal(modelData.key, v, modelData.relaunch === true)
                }
            }
        }

        // ═══════════════════════════════════════════ SWITCHES · ARGUMENTS
        InsOption {
            visible: !root.velvet && root.flags.length > 0
            label: "SWITCHES"
            note: "PICK ANY"

            Flow {
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.flags

                    InsChip {
                        required property var modelData

                        text: modelData.label
                        glyph: root.flagsOn.indexOf(modelData.arg) !== -1 ? "check" : ""
                        lit: root.flagsOn.indexOf(modelData.arg) !== -1
                        onClicked: root.toggleFlag(modelData.arg)
                    }
                }
            }
        }

        InsOption {
            visible: !root.velvet
            label: "EXTRA ARGUMENTS"
            note: "ANYTHING THE PROGRAM TAKES"

            Plate {
                width: parent.width
                height: 32
                radius: Appearance.rounding.small
                color: Colours.alpha(Colours.ink, argsField.activeFocus ? 0.12 : 0.06)
                border.width: 1
                border.color: argsField.activeFocus ? Colours.accent : Colours.alpha(Colours.ink, 0.14)
                antialiasing: true

                TextInput {
                    id: argsField

                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    color: Colours.ink
                    selectionColor: Colours.alpha(Colours.accent, 0.5)
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: Appearance.font.size.small
                    clip: true

                    readonly property string saved: root.opts.args ?? ""
                    onSavedChanged: if (!argsField.activeFocus)
                        argsField.text = argsField.saved
                    Component.onCompleted: argsField.text = argsField.saved
                    onEditingFinished: {
                        if (argsField.text.trim() !== argsField.saved)
                            root.patchOpts({
                                args: argsField.text.trim()
                            }, "switch");
                    }
                    Keys.onEscapePressed: event => {
                        argsField.text = argsField.saved;
                        argsField.focus = false;
                        event.accepted = true;
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: argsField.text === "" && !argsField.activeFocus
                        text: "e.g. -s 2  ·  ENTER SAVES"
                        color: Colours.alpha(Colours.inkDim, 0.55)
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════ WINDOW
        InsSection {
            title: "WINDOW"
            note: Term.chosen === "kitty" ? "THE TERMINAL IT RUNS IN" : "TEXT SIZE · BACKGROUND · PADDING NEED KITTY"
        }

        InsOption {
            label: "TEXT SIZE"
            note: "BIGGER TEXT = A BIGGER MODULE IN THE SAME BOX"

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: 0,
                        t: "AUTO"
                    },
                    {
                        v: 7,
                        t: "7"
                    },
                    {
                        v: 9,
                        t: "9"
                    },
                    {
                        v: 11,
                        t: "11"
                    },
                    {
                        v: 14,
                        t: "14"
                    },
                    {
                        v: 18,
                        t: "18"
                    },
                    {
                        v: 24,
                        t: "24"
                    }
                ]
                current: Number(root.win.size ?? 0)
                onChosen: v => root.setWin("size", v)
            }
        }

        InsOption {
            label: "BACKGROUND"

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: -1,
                        t: "SOLID"
                    },
                    {
                        v: 0.85,
                        t: "85%"
                    },
                    {
                        v: 0.6,
                        t: "60%"
                    },
                    {
                        v: 0.3,
                        t: "30%"
                    },
                    {
                        v: 0,
                        t: "CLEAR"
                    }
                ]
                current: root.opts.transparent ? 0 : Number(root.win.bg ?? -1)
                onChosen: v => root.setWin("bg", v)
            }
        }

        InsOption {
            label: "PADDING"
            note: root.mid === "cava" ? "ONLY THE FAR SIDE · CAVA RUNS EDGE TO EDGE" : ""

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: -1,
                        t: "AUTO"
                    },
                    {
                        v: 0,
                        t: "NONE"
                    },
                    {
                        v: 8,
                        t: "8"
                    },
                    {
                        v: 16,
                        t: "16"
                    },
                    {
                        v: 32,
                        t: "32"
                    }
                ]
                current: Number(root.win.pad ?? -1)
                onChosen: v => root.setWin("pad", v)
            }
        }

        InsOption {
            label: "LOOK"
            note: "BARE: NO BORDER, SHADOW OR BLUR — PART OF THE WALLPAPER"

            InsChoice {
                width: parent.width
                model: [
                    {
                        v: "",
                        t: "WINDOW"
                    },
                    {
                        v: "bare",
                        t: "BARE"
                    }
                ]
                current: root.opts.look ?? ""
                onChosen: v => root.patchOpts({
                        look: v
                    }, "window")
            }
        }

        // ══════════════════════════════════════════════════════════ POINTER
        InsSection {
            title: "POINTER"
            note: (root.opts.pointer ?? "") === "through" ? "CLICKS GO STRAIGHT THROUGH TO WHATEVER IS UNDERNEATH · CHANGE IT HERE" : "IT TAKES CLICKS AND FOCUS LIKE ANY WINDOW"
        }

        InsChoice {
            width: parent.width
            model: [
                {
                    v: "",
                    t: "CLICKABLE"
                },
                {
                    v: "through",
                    t: "CLICK-THROUGH"
                }
            ]
            current: root.opts.pointer ?? ""
            onChosen: v => root.patchOpts({
                    pointer: v
                }, "window")
        }

        // ═══════════════════════════════════════════════════════════ DRAWN
        InsSection {
            visible: root.item?.kind === "tui" && Scenes.moduleOf(root.item) === "cava"
            title: "WHERE IT IS DRAWN"
            note: Scenes.drawnOf(root.item) ? "ON THE WALLPAPER: PART OF THE PICTURE, ON EVERY DESKTOP · ZOOM AND TILING LEAVE IT ALONE" : "IN A TERMINAL WINDOW (THE REAL CAVA)"
        }

        InsChoice {
            visible: root.item?.kind === "tui" && Scenes.moduleOf(root.item) === "cava"
            width: parent.width
            model: [
                {
                    v: "",
                    t: "WALLPAPER"
                },
                {
                    v: "window",
                    t: "TERMINAL WINDOW"
                }
            ]
            current: root.opts.draw ?? ""
            onChosen: v => {
                root.patchOpts({
                    draw: v
                }, "reopen");
                const fresh = Scenes.editing[root.itemIndex];
                if (fresh && Scenes.drawnOf(fresh))
                    Scenes.dropWindowOf(fresh);
            }
        }

        // ═══════════════════════════════════════════════════════════ DESKTOPS
        InsSection {
            visible: Scenes.pinnedOf(root.item) && root.item?.float !== false
            title: "DESKTOPS"
            note: Scenes.everyOf(root.item) ? "ON EVERY DESKTOP, LIKE YOUR WIDGETS · IT FOLLOWS YOU WHEN YOU SWITCH" : "ONLY ON THE DESKTOP IT WAS STARTED ON"
        }

        InsChoice {
            visible: Scenes.pinnedOf(root.item) && root.item?.float !== false
            width: parent.width
            model: [
                {
                    v: true,
                    t: "EVERY DESKTOP"
                },
                {
                    v: false,
                    t: "ONE DESKTOP"
                }
            ]
            current: Scenes.everyOf(root.item)
            onChosen: v => root.patchOpts({
                    every: v
                }, "window")
        }

        // ═════════════════════════════════════════════════════════════ CANVAS
        InsSection {
            title: "WHEN THE CANVAS MOVES"
            note: Scenes.pinnedOf(root.item) ? "IT STAYS EXACTLY WHERE IT IS, LIKE YOUR WIDGETS · PAN AND ZOOM LEAVE IT ALONE" : "IT TRAVELS WITH THE CANVAS, LIKE ANY WINDOW"
        }

        InsChoice {
            width: parent.width
            model: [
                {
                    v: "fixed",
                    t: "STAYS PUT"
                },
                {
                    v: "moves",
                    t: "MOVES WITH THE CANVAS"
                }
            ]
            current: Scenes.pinnedOf(root.item) ? "fixed" : "moves"
            onChosen: v => root.patchOpts({
                    canvas: v
                }, "canvas")
        }

        // ════════════════════════════════════════════════════ SIZE & PLACE
        InsSection {
            title: "SIZE & PLACE"
            note: root.item ? `${Math.round((root.item.x ?? 0) * 100)} , ${Math.round((root.item.y ?? 0) * 100)}  ·  ${Math.round((root.item.w ?? 0) * 100)} × ${Math.round((root.item.h ?? 0) * 100)}  PERCENT OF THE SCREEN` : ""
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: root.snaps

                InsChip {
                    required property var modelData

                    text: modelData.name
                    lit: root.item && Math.abs((root.item.x ?? 0) - modelData.x) < 0.005 && Math.abs((root.item.y ?? 0) - modelData.y) < 0.005 && Math.abs((root.item.w ?? 0) - modelData.w) < 0.005 && Math.abs((root.item.h ?? 0) - modelData.h) < 0.005
                    onClicked: {
                        Scenes.patchAt(root.itemIndex, {
                            x: modelData.x,
                            y: modelData.y,
                            w: modelData.w,
                            h: modelData.h
                        });
                        Sfx.toggle();
                    }
                }
            }
        }
    }

    SmoothScroll {
        view: root
    }
}
