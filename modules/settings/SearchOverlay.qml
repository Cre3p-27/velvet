//  VELVET  ·  modules/settings/SearchOverlay.qml
//  Type anything, anywhere in the menu, and land on the setting. This is what
//  makes "infinite settings" navigable instead of exhausting.
import qs.config
import qs.services
import qs.components
import QtQuick

FocusScope {
    id: root

    property string seed: ""

    signal dismissed
    signal chosen(var entry)

    focus: true

    property int index: 0
    // The pointer picks a hit, but not while the list scrolls under it.
    property real lastScroll: 0

    readonly property var results: {
        const q = input.text.trim().toLowerCase();
        const all = Schema.flat;
        if (!q)
            return all.slice(0, 40);

        const scored = [];
        for (let i = 0; i < all.length; i++) {
            const e = all[i];
            const name = (e.item.name ?? "").toLowerCase();
            const sub = (e.item.sub ?? "").toLowerCase();
            const path = e.path.toLowerCase();
            // The explanation too — "frost" finds BLUR, "seam" finds the frame.
            const help = (e.item.help ?? "").toLowerCase();

            let s = -1;
            if (name === q)
                s = 1000;
            else if (name.startsWith(q))
                s = 800 - name.length;
            else if (name.includes(q))
                s = 600;
            else if (sub.includes(q))
                s = 320;
            else if (path.includes(q))
                s = 200;
            else if (q.length >= 3 && help.includes(q))
                s = 150;
            else {
                // Loose subsequence over the name, so "wsp" finds "WORKSPACES".
                let hi = 0;
                let ok = true;
                for (let c = 0; c < q.length; c++) {
                    const at = name.indexOf(q[c], hi);
                    if (at === -1) {
                        ok = false;
                        break;
                    }
                    hi = at + 1;
                }
                if (ok)
                    s = 120 - name.length * 0.2;
            }

            if (s > 0)
                scored.push({
                    e: e,
                    s: s
                });
        }
        scored.sort((a, b) => b.s - a.s);
        return scored.slice(0, 40).map(x => x.e);
    }

    onResultsChanged: index = 0

    // Arrow keys: bring the pick into view.
    function reveal(): void {
        list.positionViewAtIndex(root.index, ListView.Contain);
    }

    Component.onCompleted: {
        input.text = seed;
        input.cursorPosition = input.text.length;
        input.forceActiveFocus();
    }

    // ------------------------------------------------------------------ scrim
    Rectangle {
        anchors.fill: parent
        color: Colours.alpha(Colours.paper, 0.86)

        MouseArea {
            anchors.fill: parent
            onClicked: root.dismissed()
        }
    }

    Halftone {
        anchors.fill: parent
        strength: 0.04
        density: 1.6
    }

    // ------------------------------------------------------------------ panel
    Item {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.12
        width: Math.min(1080, parent.width * 0.66)
        height: parent.height * 0.72

        // -------------------------------------------------------------- field
        Slash {
            id: field

            width: parent.width
            height: 86
            shear: Appearance.skew
            color: Colours.alpha(Colours.surfaceHigh, 0.96)
            borderColor: Colours.accent
            borderWidth: Appearance.skinned ? 1.5 : 3

            Row {
                anchors.fill: parent
                anchors.leftMargin: 34
                anchors.rightMargin: 28
                spacing: 18

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    color: Colours.accent
                    font.pixelSize: Appearance.font.size.title
                }

                TextInput {
                    id: input

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90
                    color: Colours.ink
                    font.family: Appearance.fontFamily.display
                    font.pixelSize: Appearance.font.size.huge * 1.2
                    font.weight: Appearance.type.displayWeight
                    font.italic: Appearance.type.italic
                    font.letterSpacing: 1
                    selectionColor: Colours.accent
                    selectedTextColor: Colours.on(Colours.accent)
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text.length === 0
                        text: "SEARCH EVERY SETTING…"
                        color: Colours.alpha(Colours.inkDim, 0.5)
                        font: input.font
                    }

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape:
                            root.dismissed();
                            event.accepted = true;
                            return;
                        case Qt.Key_Down:
                            root.index = Math.min(root.results.length - 1, root.index + 1);
                            root.reveal();
                            Sfx.cursor();
                            event.accepted = true;
                            return;
                        case Qt.Key_Up:
                            root.index = Math.max(0, root.index - 1);
                            root.reveal();
                            Sfx.cursor();
                            event.accepted = true;
                            return;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            if (root.results.length > 0)
                                root.chosen(root.results[root.index]);
                            event.accepted = true;
                            return;
                        }
                    }
                }
            }
        }

        P5Text {
            anchors.top: field.bottom
            anchors.topMargin: 10
            anchors.right: parent.right
            text: `${root.results.length} MATCHES`
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 2
        }

        // ------------------------------------------------------------ results
        ListView {
            id: list

            anchors.top: field.bottom
            anchors.topMargin: 38
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            model: root.results
            currentIndex: root.index
            spacing: 6
            clip: true
            // Only the keys scroll it to the pick (below); the pointer never.
            highlightFollowsCurrentItem: false
            boundsBehavior: Flickable.StopAtBounds

            onContentYChanged: root.lastScroll = Date.now()

            delegate: Item {
                id: hit

                required property var modelData
                required property int index

                readonly property bool selected: index === root.index

                width: list.width
                height: 66
                x: selected ? 16 : 0

                Behavior on x {
                    SpringAnimation {
                        spring: 4.5
                        damping: 0.35
                        epsilon: 0.4
                    }
                }

                Slash {
                    anchors.fill: parent
                    shear: Appearance.skew
                    color: hit.selected ? Colours.accent : Colours.alpha(Colours.surface, 0.6)
                    borderColor: hit.selected ? Colours.ink : "transparent"
                    borderWidth: hit.selected ? 2 : 0
                }

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 34
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    P5Text {
                        display: true
                        text: hit.modelData.item.name
                        color: hit.selected ? Colours.on(Colours.accent) : Colours.ink
                        font.pixelSize: Appearance.font.size.large
                    }

                    P5Text {
                        text: hit.modelData.path
                        color: hit.selected ? Colours.alpha(Colours.on(Colours.accent), 0.82) : Colours.accentInk
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.6
                    }
                }

                P5Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: hit.modelData.item.kind === "page" ? ((hit.modelData.item.pane ?? "") !== "" ? "EDITOR" : "PAGE") : (hit.modelData.item.kind ?? "").toUpperCase()
                    color: hit.selected ? Colours.alpha(Colours.on(Colours.accent), 0.6) : Colours.alpha(Colours.inkDim, 0.6)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 2
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: {
                        if (Date.now() - root.lastScroll > 260)
                            root.index = hit.index;
                    }
                    onClicked: root.chosen(hit.modelData)
                }
            }

            SmoothScroll {
                view: list
            }
        }
    }
}
