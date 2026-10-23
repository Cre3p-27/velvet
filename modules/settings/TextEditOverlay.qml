//  VELVET  ·  modules/settings/TextEditOverlay.qml
//  A setting you write in your own words (a row of kind "text"): a card in the
//  middle of the settings with the text, examples to start from, and — when the
//  row asks for it (`understand: "livewall"`) — what Velly reads in it, live,
//  while you type. Enter saves, Ctrl+Enter saves and runs the row's `then`
//  action (MAKE IT LIKE THIS), Esc leaves it as it was.
import qs.config
import qs.services
import qs.components
import QtQuick

FocusScope {
    id: root

    required property var item

    signal closed

    focus: true

    function save(andRun: bool): void {
        Bridge.set(root.item, input.text.trim());
        if (andRun && root.item.then)
            Bridge.act({ fn: root.item.then });
        Sfx.select();
        root.closed();
    }

    Component.onCompleted: {
        input.text = String(Bridge.raw(root.item) ?? "");
        input.cursorPosition = input.text.length;
        input.forceActiveFocus();
        if (root.item.understand === "livewall")
            LiveWalls.preview(input.text);
    }

    Rectangle {
        anchors.fill: parent
        color: Colours.alpha(Colours.paper, 0.9)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closed()
        }
    }

    Slash {
        id: card

        anchors.centerIn: parent
        width: Math.min(parent.width * 0.78, 1180)
        height: body.implicitHeight + 64
        shear: Appearance.skew * 0.5
        color: Colours.alpha(Colours.ink, 0.06)
        borderColor: Colours.alpha(Colours.accent, 0.7)
        borderWidth: 1

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: body

            x: 40
            y: 32
            width: card.width - 80
            spacing: 18

            P5Text {
                display: true
                text: root.item.name ?? ""
                color: Colours.ink
                font.pixelSize: Appearance.font.size.hero * 0.42
            }

            P5Text {
                width: parent.width
                text: root.item.help ?? ""
                color: Colours.alpha(Colours.ink, 0.72)
                font.pixelSize: Appearance.font.size.small
                wrapMode: Text.WordWrap
            }

            // the text itself
            Rectangle {
                width: parent.width
                height: Math.max(96, input.contentHeight + 36)
                radius: Appearance.r(10)
                color: Colours.alpha(Colours.ink, 0.07)
                border.width: input.activeFocus ? 2 : 1
                border.color: input.activeFocus ? Colours.accent : Colours.alpha(Colours.ink, 0.25)

                TextEdit {
                    id: input

                    x: 18
                    y: 18
                    width: parent.width - 36
                    color: Colours.ink
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: Appearance.font.size.normal
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    focus: true
                    cursorDelegate: Rectangle {
                        width: 2
                        color: Colours.accent
                    }

                    onTextChanged: {
                        if (root.item.understand === "livewall")
                            LiveWalls.preview(input.text);
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            root.closed();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            // Shift+Enter: a new line; Ctrl+Enter: save and make it
                            if (event.modifiers & Qt.ShiftModifier)
                                return;
                            root.save((event.modifiers & Qt.ControlModifier) !== 0);
                            event.accepted = true;
                        }
                    }

                    P5Text {
                        visible: input.text.length === 0
                        width: input.width
                        text: root.item.placeholder ?? ""
                        color: Colours.alpha(Colours.ink, 0.38)
                        font.pixelSize: Appearance.font.size.normal
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // what Velly reads in it, while you type
            P5Text {
                visible: root.item.understand === "livewall"
                width: parent.width
                text: LiveWalls.previewLine
                color: Colours.accentInk
                font.family: Appearance.fontFamily.mono
                font.pixelSize: Appearance.font.size.small
                wrapMode: Text.WordWrap
            }

            // examples to start from: a click puts one in
            Flow {
                visible: (root.item.examples ?? []).length > 0
                width: parent.width
                spacing: 10

                Repeater {
                    model: root.item.examples ?? []

                    Rectangle {
                        id: chip

                        required property string modelData

                        width: chipText.implicitWidth + 28
                        height: 34
                        radius: Appearance.pill(34)
                        color: chipArea.containsMouse ? Colours.alpha(Colours.accent, 0.22) : Colours.alpha(Colours.ink, 0.07)
                        border.width: 1
                        border.color: Colours.alpha(Colours.accent, chipArea.containsMouse ? 0.8 : 0.35)

                        P5Text {
                            id: chipText

                            anchors.centerIn: parent
                            text: chip.modelData
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.small
                        }

                        MouseArea {
                            id: chipArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                input.text = chip.modelData;
                                input.cursorPosition = input.text.length;
                                input.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            Row {
                spacing: 14

                Repeater {
                    model: [
                        { label: root.item.thenLabel ?? "SAVE AND MAKE IT", run: true, show: !!root.item.then, hint: "CTRL+ENTER" },
                        { label: "SAVE", run: false, show: true, hint: "ENTER" },
                        { label: "CLEAR", run: false, show: true, clear: true, hint: "" },
                        { label: "CANCEL", run: false, show: true, cancel: true, hint: "ESC" }
                    ]

                    Rectangle {
                        id: btn

                        required property var modelData

                        visible: btn.modelData.show
                        width: btnText.implicitWidth + 40
                        height: 44
                        radius: Appearance.r(8)
                        color: btn.modelData.run ? (btnArea.containsMouse ? Colours.accentHot : Colours.accent) : (btnArea.containsMouse ? Colours.alpha(Colours.ink, 0.14) : "transparent")
                        border.width: btn.modelData.run ? 0 : 1
                        border.color: Colours.alpha(Colours.ink, 0.4)

                        P5Text {
                            id: btnText

                            anchors.centerIn: parent
                            display: true
                            text: btn.modelData.hint ? `${btn.modelData.label} · ${btn.modelData.hint}` : btn.modelData.label
                            color: btn.modelData.run ? Colours.on(Colours.accent) : Colours.ink
                            font.pixelSize: Appearance.font.size.small
                        }

                        MouseArea {
                            id: btnArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (btn.modelData.cancel) {
                                    root.closed();
                                } else if (btn.modelData.clear) {
                                    input.text = "";
                                    input.forceActiveFocus();
                                } else {
                                    root.save(btn.modelData.run);
                                }
                            }
                        }
                    }
                }
            }

            P5Text {
                text: "SHIFT+ENTER A NEW LINE"
                color: Colours.alpha(Colours.ink, 0.45)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 2
            }
        }
    }
}
