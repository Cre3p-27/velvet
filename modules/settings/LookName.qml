//  VELVET  ·  modules/settings/LookName.qml
//  A look's name on its LOOKS card — yours to change. A pencil shows when
//  the pointer is on the name; a click (or the pencil) turns the name into a
//  field: ENTER keeps it, ESC leaves it as it was, an empty name brings the
//  look's own back. Presets.rename keeps it (looks.json / looks-custom.json).
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    required property var look
    property real size: Appearance.font.size.huge
    property bool editing: false

    readonly property string shown: Presets.nameOf(root.look)

    implicitWidth: root.editing ? Math.max(220, field.contentWidth + 40) : nameText.implicitWidth + (hover.hovered ? pencil.width + 10 : 0)
    implicitHeight: Math.max(nameText.implicitHeight, root.size * 1.3)

    function begin(): void {
        field.text = root.shown;
        root.editing = true;
        field.forceActiveFocus();
        field.selectAll();
    }
    function commit(): void {
        if (!root.editing)
            return;
        root.editing = false;
        const t = field.text.trim();
        if (t !== root.shown) {
            Presets.rename(root.look.id, t);
            Toast.ok(t === "" ? "THE LOOK HAS ITS OWN NAME AGAIN" : `RENAMED · ${t.toUpperCase()}`);
        }
    }

    HoverHandler {
        id: hover

        cursorShape: root.editing ? Qt.IBeamCursor : Qt.PointingHandCursor
    }

    P5Text {
        id: nameText

        anchors.verticalCenter: parent.verticalCenter
        visible: !root.editing
        display: true
        text: root.shown
        color: Colours.ink
        font.pixelSize: root.size
    }
    Icon {
        id: pencil

        anchors.left: nameText.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.editing && hover.hovered
        name: "edit"
        color: Colours.accentInk
        font.pixelSize: root.size * 0.55
    }
    TapHandler {
        enabled: !root.editing
        onTapped: root.begin()
    }

    Rectangle {
        anchors.fill: parent
        visible: root.editing
        radius: Appearance.r(6)
        color: Colours.alpha(Colours.ink, 0.08)
        border.width: 1
        border.color: Colours.accent

        TextInput {
            id: field

            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Colours.ink
            selectionColor: Colours.alpha(Colours.accent, 0.5)
            font.family: Appearance.fontFamily.display
            font.pixelSize: root.size * 0.8
            maximumLength: 32
            clip: true
            onAccepted: root.commit()
            onActiveFocusChanged: if (!activeFocus)
                root.commit()
            Keys.onEscapePressed: event => {
                root.editing = false;
                event.accepted = true;
            }
        }
    }
}
