//  VELVET  ·  components/ShellClock.qml
//  Quickshell's SystemClock, telling the shell's own time (SHELL → TIME: the
//  computer's clock, another time zone, or a time set by hand — services/
//  Time.qml). The same date / hours / minutes / seconds and precision, so a
//  clock switches over by its type name alone.
import qs.services
import Quickshell
import QtQuick

QtObject {
    property int precision: SystemClock.Seconds

    readonly property date date: precision === SystemClock.Hours ? Time.hourly : (precision === SystemClock.Minutes ? Time.minute : Time.now)
    readonly property int hours: date.getHours()
    readonly property int minutes: date.getMinutes()
    readonly property int seconds: date.getSeconds()
}
