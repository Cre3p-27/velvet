//  VELVET  ·  modules/lock/VibeLock.qml
//  The session lock of the VIBES on every screen: the lock and its surfaces
//  here, the face in VibeFace.qml (which the settings also draw as a preview).
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

        VibeFace {
            anchors.fill: parent
        }
    }
}
