//  VELVET  ·  modules/lock/SoftLock.qml
//  The SOFT lock on every screen — the session lock and its surfaces; the
//  face itself (and all of its notes) lives in SoftFace.qml, which the
//  settings also show as the live preview.
import qs.config
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

WlSessionLock {
    id: lock

    locked: Locker.locked

    WlSessionLockSurface {
        // Never transparent: something is painted even if the face fails.
        color: Colours.paper

        SoftFace {
            anchors.fill: parent
        }
    }
}
