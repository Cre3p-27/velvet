//  VELVET  ·  config/Build.qml
//  Which build this is, read from the VERSION file that ships beside it.
//
//  It exists because "did the new tarball actually land?" turned out to be a
//  real question with a wrong answer, and the shell is the only thing that can
//  answer it about itself. One source of truth: the file on disk. install.sh
//  reads the same one.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string version: "unknown"
    property bool loaded: false

    readonly property string label: root.loaded ? `VELVET ${root.version}` : "VELVET"

    FileView {
        path: Qt.resolvedUrl("../VERSION").toString().replace(/^file:\/\//, "")
        printErrors: false

        onLoaded: {
            root.version = text().trim() || "unknown";
            root.loaded = true;
        }
        onLoadFailed: root.loaded = false
    }
}
