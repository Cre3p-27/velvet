//  VELVET  ·  components/DotText.qml
//  Digits as a dot matrix — the clock face the lock offers as DOTS (LOCK
//  SCREEN → CLOCK & SOUND → CLOCK FACE). Drawn, not typeset: every glyph is
//  a 5 × 7 grid of round dots, so it looks the same on every machine,
//  whatever fonts are installed. Digits, a colon and a space; anything
//  else is left blank.
import QtQuick

Row {
    id: root

    property string text: ""
    property color color: "white"
    // The height of the whole line; dots and gaps follow from it.
    property real pixelSize: 96

    readonly property real pitch: root.pixelSize / 7
    readonly property real dot: root.pitch * 0.78

    readonly property var glyphs: ({
            "0": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
            "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
            "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
            "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
            "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
            "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
            "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
            "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
            "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
            "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
            ":": ["0", "0", "1", "0", "1", "0", "0"],
            " ": ["0", "0", "0", "0", "0", "0", "0"]
        })

    spacing: root.pitch

    Repeater {
        model: root.text.split("")

        Item {
            id: glyph

            required property string modelData

            readonly property var rows: root.glyphs[glyph.modelData] ?? root.glyphs[" "]
            readonly property int cols: glyph.rows[0].length

            width: glyph.cols * root.pitch - (root.pitch - root.dot)
            height: 7 * root.pitch - (root.pitch - root.dot)

            Repeater {
                model: 7 * glyph.cols

                Rectangle {
                    required property int index

                    readonly property int r: Math.floor(index / glyph.cols)
                    readonly property int c: index % glyph.cols

                    visible: glyph.rows[r].charAt(c) === "1"
                    x: c * root.pitch
                    y: r * root.pitch
                    width: root.dot
                    height: root.dot
                    radius: root.dot / 2
                    color: root.color
                    antialiasing: true
                }
            }
        }
    }
}
