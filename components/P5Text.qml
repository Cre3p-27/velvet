//  VELVET  ·  components/P5Text.qml
//  The house typeface treatment: heavy, italic, tight. Set `display` for the
//  big shouty stuff, leave it off for anything you actually have to read.
//  VISUALS → TYPE STYLE re-sets it as soft, terminal, serif, poster, pixel
//  or HUD type — and CASE can make all of it lowercase.
import qs.config
import QtQuick

Text {
    id: root

    property bool display: false
    property real tracking: NaN

    font.family: display ? Appearance.fontFamily.display : Appearance.fontFamily.body
    font.pixelSize: Appearance.font.size.normal
    font.weight: display ? Appearance.type.displayWeight : Appearance.type.bodyWeight
    font.italic: display && Appearance.type.italic
    font.letterSpacing: isNaN(tracking) ? (display ? Appearance.type.displayTracking : Appearance.type.bodyTracking) : tracking
    font.capitalization: Appearance.type.capitalization
    textFormat: Text.PlainText
    antialiasing: true
    renderType: Appearance.mood === "arcade" ? Text.NativeRendering : Text.QtRendering
}
