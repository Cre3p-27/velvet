//  VELVET  ·  modules/settings/StudioPane.qml
//  The WIDGET STUDIO (SUPER+TAB → SETTINGS → WIDGET STUDIO): make a desktop
//  widget without knowing where anything lives.
//
//    left    your widgets, and IDEAS — click one and it is yours to use or
//            change
//    middle  the widget, live and big, as it will sit on your desktop
//    right   three ways to make it: DESCRIBE it (Velly builds it, or copy
//            the request for ChatGPT / Claude and paste the answer back), or
//            WRITE it right here — the preview follows every key, and it
//            saves itself
//
//  The widgets themselves: services/CodeWidgets.qml, components/CodeWidget.qml.
pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    anchors.fill: parent

    // the widget open in the studio ("" = none yet) and its text as edited
    property string selected: ""
    property string draft: ""
    property bool dirty: false

    function open(name: string): void {
        if (root.dirty)
            saveNow.trigger();
        root.selected = name;
        root.dirty = false;
        Sfx.select();
    }

    // a widget made elsewhere (pasted, Velly's, a new one) opens here
    Connections {
        target: CodeWidgets

        function onLastMadeChanged(): void {
            if (CodeWidgets.lastMade !== "")
                root.open(CodeWidgets.lastMade);
        }
    }

    FileView {
        id: file

        path: root.selected !== "" ? CodeWidgets.fileOf(root.selected) : ""
        watchChanges: true
        printErrors: false
        onLoaded: {
            if (!root.dirty) {
                root.draft = file.text();
                editor.text = root.draft;
            }
        }
        onFileChanged: file.reload()
    }

    // typing saves itself, a moment after the last key
    Timer {
        id: saveNow

        interval: 700
        function trigger(): void {
            saveNow.stop();
            if (root.selected !== "" && root.dirty) {
                CodeWidgets.save(root.selected, root.draft);
                root.dirty = false;
            }
        }
        onTriggered: saveNow.trigger()
    }

    readonly property real gap: 18
    readonly property real leftW: Math.min(300, root.width * 0.24)
    readonly property real rightW: Math.min(460, root.width * 0.36)

    // ══════════════════════════════════════════════════════════════ head
    P5Text {
        id: title

        x: 4
        y: 2
        display: true
        text: "WIDGET STUDIO"
        color: Colours.ink
        font.pixelSize: Appearance.font.size.large
        tracking: 2
    }

    P5Text {
        anchors.left: title.right
        anchors.leftMargin: 16
        anchors.baseline: title.baseline
        text: "A WIDGET FOR YOUR DESKTOP — PICK AN IDEA, DESCRIBE ONE, OR WRITE IT"
        color: Colours.inkDim
        font.pixelSize: Appearance.font.size.tiny
        tracking: 1.4
    }

    // ══════════════════════════════════════════════════════════════ left
    Flickable {
        id: left

        y: 44
        width: root.leftW
        height: root.height - y
        contentHeight: leftCol.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: leftCol

            width: left.width
            spacing: 8

            Label {
                text: "YOUR WIDGETS"
            }

            Repeater {
                model: CodeWidgets.names

                Card {
                    required property string modelData

                    name: modelData
                    on: root.selected === modelData
                    onPicked: root.open(modelData)
                }
            }

            Btn {
                width: parent.width
                glyph: "add"
                label: "NEW, BLANK"
                onClicked: CodeWidgets.blank()
            }

            Item {
                width: 1
                height: 8
            }

            Label {
                text: "IDEAS · CLICK ONE TO MAKE IT YOURS"
            }

            Repeater {
                model: CodeWidgets.gallery

                Card {
                    required property var modelData

                    idea: modelData
                    onPicked: CodeWidgets.fromIdea(modelData)
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ middle
    Item {
        id: middle

        x: root.leftW + root.gap
        y: 44
        width: root.width - root.leftW - root.rightW - root.gap * 2
        height: root.height - y

        Plate {
            id: stage

            width: parent.width
            height: parent.height - 64
            radius: Appearance.r(22)
            color: Colours.alpha(Colours.ink0, 0.55)
            border.width: 1
            border.color: Colours.alpha(Colours.ink, 0.12)
            clip: true

            // a hint of the desktop behind it
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Colours.alpha(Colours.accent, 0.10)
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }
            }

            CodeWidget {
                id: preview

                anchors.centerIn: parent
                visible: root.selected !== ""
                name: root.selected
                code: root.draft
                scale: Math.min(1.6, Math.min((stage.width - 60) / Math.max(1, implicitWidth), (stage.height - 60) / Math.max(1, implicitHeight)))
                width: implicitWidth
                height: implicitHeight
            }

            Column {
                anchors.centerIn: parent
                visible: root.selected === ""
                spacing: 10

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "widgets"
                    font.pixelSize: 54
                    color: Colours.alpha(Colours.accent, 0.8)
                }

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "PICK AN IDEA ON THE LEFT, OR DESCRIBE ONE ON THE RIGHT"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.small
                    tracking: 1.2
                }
            }
        }

        Row {
            anchors.bottom: parent.bottom
            spacing: 10
            visible: root.selected !== ""

            Btn {
                width: 200
                glyph: "add_to_queue"
                label: "PUT IT ON THE DESKTOP"
                accent: true
                onClicked: {
                    saveNow.trigger();
                    CodeWidgets.place(root.selected, true);
                    Toast.show(`${preview.title.toUpperCase()} IS ON YOUR DESKTOP`, "ok", 2600);
                }
            }

            Btn {
                id: deleteBtn

                property bool armed: false

                width: 130
                glyph: "delete"
                label: armed ? "SURE? CLICK" : "DELETE"
                danger: armed
                onClicked: {
                    if (!armed) {
                        armed = true;
                        disarm.restart();
                        return;
                    }
                    armed = false;
                    CodeWidgets.remove(root.selected);
                    root.selected = "";
                    root.draft = "";
                }

                Timer {
                    id: disarm

                    interval: 2500
                    onTriggered: deleteBtn.armed = false
                }
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${preview.implicitWidth} × ${preview.implicitHeight}  ·  ${preview.fps} FPS${root.dirty ? "  ·  SAVING…" : "  ·  SAVED"}`
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
            }
        }
    }

    // ══════════════════════════════════════════════════════════════ right
    Column {
        id: right

        x: root.width - root.rightW
        y: 44
        width: root.rightW
        spacing: 10

        Label {
            text: "1 · DESCRIBE IT"
        }

        Rectangle {
            width: parent.width
            height: 76
            radius: 14
            color: Colours.alpha(Colours.ink, 0.06)
            border.width: 1
            border.color: idea.activeFocus ? Colours.alpha(Colours.accent, 0.7) : Colours.alpha(Colours.ink, 0.14)

            TextEdit {
                id: idea

                anchors.fill: parent
                anchors.margins: 12
                color: Colours.ink
                wrapMode: TextEdit.Wrap
                font.family: Appearance.fontFamily.body
                font.pixelSize: Appearance.font.size.normal
                selectByMouse: true
            }

            P5Text {
                x: 12
                y: 12
                visible: idea.text === "" && !idea.activeFocus
                text: "e.g. a moon that shows today's phase, or my CPU as a little flame"
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: Appearance.font.size.small
            }
        }

        Row {
            width: parent.width
            spacing: 8

            Btn {
                width: (parent.width - 8) / 2
                glyph: "auto_awesome"
                label: "VELLY BUILDS IT"
                accent: true
                visible: Config.velly.enabled
                onClicked: {
                    const want = idea.text.trim();
                    Velly.ask(want !== "" ? `Bau mir ein Desktop-Widget: ${want}. Lies zuerst widget.api, dann widget.make.` : "Ich möchte ein neues Desktop-Widget. Frag mich kurz, was es zeigen soll, dann bau es mit widget.api und widget.make.", "text");
                }
            }

            Btn {
                width: Config.velly.enabled ? (parent.width - 8) / 2 : parent.width
                glyph: "content_copy"
                label: "COPY FOR CHATGPT · CLAUDE"
                onClicked: CodeWidgets.copyForAi(idea.text)
            }
        }

        Btn {
            width: parent.width
            glyph: "content_paste"
            label: "PASTE THE AI'S ANSWER — IT BECOMES A WIDGET"
            onClicked: CodeWidgets.pasteCode()
        }

        Item {
            width: 1
            height: 6
        }

        Label {
            text: root.selected !== "" ? `2 · OR WRITE IT — ${root.selected.toUpperCase()}.JS` : "2 · OR WRITE IT (PICK OR MAKE A WIDGET FIRST)"
        }

        Rectangle {
            width: parent.width
            height: root.height - y - 50 - 44
            radius: 14
            color: Colours.alpha(Colours.ink0, 0.6)
            border.width: 1
            border.color: editor.activeFocus ? Colours.alpha(Colours.accent, 0.7) : Colours.alpha(Colours.ink, 0.14)
            opacity: root.selected !== "" ? 1 : 0.4

            Flickable {
                id: codeView

                anchors.fill: parent
                anchors.margins: 12
                contentWidth: editor.paintedWidth
                contentHeight: editor.paintedHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                function follow(r: rect): void {
                    if (contentY >= r.y)
                        contentY = r.y;
                    else if (contentY + height <= r.y + r.height)
                        contentY = r.y + r.height - height;
                }

                TextEdit {
                    id: editor

                    width: codeView.width
                    readOnly: root.selected === ""
                    color: Colours.ink
                    selectionColor: Colours.alpha(Colours.accent, 0.4)
                    font.family: "monospace"
                    font.pixelSize: 13
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    tabStopDistance: 28
                    onCursorRectangleChanged: codeView.follow(cursorRectangle)
                    onTextChanged: {
                        if (!editor.activeFocus || editor.text === root.draft)
                            return;
                        root.draft = editor.text;
                        root.dirty = true;
                        saveNow.restart();
                    }
                }
            }
        }

        P5Text {
            width: parent.width
            text: preview.error !== "" ? `⚠ ${preview.error}` : "THE PREVIEW FOLLOWS EVERY KEY · IT SAVES ITSELF · F1 LISTS WHAT f HOLDS"
            color: preview.error !== "" ? Colours.danger : Colours.alpha(Colours.inkDim, 0.75)
            font.pixelSize: Appearance.font.size.tiny
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    // F1: the API, over the studio
    Keys.onPressed: event => {
        if (event.key === Qt.Key_F1) {
            help.visible = !help.visible;
            event.accepted = true;
        }
    }

    Rectangle {
        id: help

        visible: false
        anchors.fill: parent
        color: Colours.alpha(Colours.ink0, 0.92)
        radius: 18
        z: 10

        Text {
            anchors.fill: parent
            anchors.margins: 28
            text: CodeWidgets.api
            color: Colours.ink
            font.family: "monospace"
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }

        MouseArea {
            anchors.fill: parent
            onClicked: help.visible = false
        }
    }

    // ══════════════════════════════════════════════════════════════ parts
    component Label: P5Text {
        color: Colours.alpha(Colours.accent, 0.9)
        font.pixelSize: Appearance.font.size.tiny
        tracking: 3
    }

    // a widget (yours, or an idea): its picture, its name, what it does
    component Card: Rectangle {
        id: card

        property string name: ""
        property var idea: null
        property bool on: false
        signal picked

        width: parent ? parent.width : 200
        height: 74
        radius: 16
        color: card.on ? Colours.alpha(Colours.accent, 0.18) : (cardHover.hovered ? Colours.alpha(Colours.ink, 0.08) : Colours.alpha(Colours.ink, 0.04))
        border.width: 1
        border.color: card.on ? Colours.alpha(Colours.accent, 0.7) : Colours.alpha(Colours.ink, 0.1)
        scale: cardTap.pressed ? 0.97 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutBack
            }
        }

        // a live thumbnail
        Item {
            x: 8
            y: 8
            width: 58
            height: 58
            clip: true

            CodeWidget {
                anchors.centerIn: parent
                name: card.idea ? "" : card.name
                code: card.idea ? card.idea.code : ""
                live: cardHover.hovered || card.on
                width: implicitWidth
                height: implicitHeight
                scale: 58 / Math.max(implicitWidth, implicitHeight)
            }
        }

        Column {
            x: 76
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 86
            spacing: 2

            P5Text {
                width: parent.width
                text: (card.idea ? card.idea.name : card.name).toUpperCase()
                color: Colours.ink
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            P5Text {
                width: parent.width
                visible: !!card.idea
                text: card.idea ? card.idea.about : ""
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        HoverHandler {
            id: cardHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: cardTap

            onTapped: card.picked()
        }
    }

    // a friendly button: an icon and a word, it lifts and squishes
    component Btn: Rectangle {
        id: btn

        property string glyph: ""
        property string label: ""
        property bool accent: false
        property bool danger: false
        signal clicked

        height: 40
        radius: 20
        color: btn.danger ? Colours.alpha(Colours.danger, 0.25) : (btn.accent ? Colours.alpha(Colours.accent, btnHover.hovered ? 0.95 : 0.8) : Colours.alpha(Colours.ink, btnHover.hovered ? 0.12 : 0.06))
        border.width: btn.accent ? 0 : 1
        border.color: Colours.alpha(Colours.ink, 0.16)
        scale: btnTap.pressed ? 0.95 : (btnHover.hovered ? 1.02 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutBack
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: btn.glyph
                font.pixelSize: 18
                color: btn.accent ? Colours.on(Colours.accent) : Colours.ink
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                color: btn.accent ? Colours.on(Colours.accent) : Colours.ink
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }
        }

        HoverHandler {
            id: btnHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: btnTap

            onTapped: {
                Sfx.select();
                btn.clicked();
            }
        }
    }
}
