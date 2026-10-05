//  VELVET  ·  modules/settings/SettingRowAny.qml
//  The row the lists use: the house SettingRow in the Persona skin, SkinRow
//  in every other. Same contract, so SettingsList and the module inspector
//  do not care which one they got.
import qs.config
import QtQuick

Item {
    id: root

    required property var item
    required property int index
    required property bool selected

    property bool hot: false
    property bool open: false
    property bool armed: false

    property int depth: 0
    property bool expandable: false
    property bool expanded: false
    property int childCount: 0

    signal activate
    signal hovered
    signal unhovered
    signal touched

    implicitHeight: body.item ? body.item.implicitHeight : 0
    height: root.implicitHeight

    Loader {
        id: body

        width: root.width
        sourceComponent: Appearance.skin === "clean" ? cleanRow : (Appearance.skin === "win" ? winRow : (Appearance.skinned ? skinned : house))
    }

    Component {
        id: house

        SettingRow {
            item: root.item
            index: root.index
            selected: root.selected
            hot: root.hot
            open: root.open
            armed: root.armed
            depth: root.depth
            expandable: root.expandable
            expanded: root.expanded
            childCount: root.childCount
            onActivate: root.activate()
            onHovered: root.hovered()
            onUnhovered: root.unhovered()
            onTouched: root.touched()
        }
    }

    Component {
        id: skinned

        SkinRow {
            item: root.item
            index: root.index
            selected: root.selected
            hot: root.hot
            open: root.open
            armed: root.armed
            depth: root.depth
            expandable: root.expandable
            expanded: root.expanded
            childCount: root.childCount
            onActivate: root.activate()
            onHovered: root.hovered()
            onUnhovered: root.unhovered()
            onTouched: root.touched()
        }
    }

    Component {
        id: cleanRow

        SkinRowClean {
            item: root.item
            index: root.index
            selected: root.selected
            hot: root.hot
            open: root.open
            armed: root.armed
            depth: root.depth
            expandable: root.expandable
            expanded: root.expanded
            childCount: root.childCount
            onActivate: root.activate()
            onHovered: root.hovered()
            onUnhovered: root.unhovered()
            onTouched: root.touched()
        }
    }

    Component {
        id: winRow

        SkinRowWin {
            item: root.item
            index: root.index
            selected: root.selected
            hot: root.hot
            open: root.open
            armed: root.armed
            depth: root.depth
            expandable: root.expandable
            expanded: root.expanded
            childCount: root.childCount
            onActivate: root.activate()
            onHovered: root.hovered()
            onUnhovered: root.unhovered()
            onTouched: root.touched()
        }
    }
}
