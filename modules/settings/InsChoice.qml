//  VELVET  ·  modules/settings/InsChoice.qml
//  Every value of an option visible at once; the one in use is lit.
//  model: [{ v: value, t: "LABEL" }] · current · chosen(value)
import qs.config
import qs.services
import qs.components
import QtQuick

Flow {
    id: ch

    property var model: []
    property var current: null

    signal chosen(var value)

    spacing: 6

    Repeater {
        model: ch.model

        InsChip {
            required property var modelData

            text: modelData.t
            lit: ch.current === modelData.v
            onClicked: {
                if (ch.current !== modelData.v)
                    ch.chosen(modelData.v);
            }
        }
    }
}
