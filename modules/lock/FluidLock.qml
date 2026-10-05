//  VELVET  ·  modules/lock/FluidLock.qml
//  The fluid lock — the card with its side columns, and its own entrance
//  choreography beat for beat:
//
//    · the card starts as a small square (the lock icon plus its padding)
//      at rotation 180°, scale 0;
//    · on lock the blurred wallpaper fades in, the square snaps to scale
//      1 while turning 180°→360° (its FastSpatial + expressive curves);
//    · then the square GROWS to the full card (0.7 of the screen tall,
//      16:9) while the lock icon fades and the content settles in;
//    · on unlock everything runs back — the card shrinks to the lock
//      square, the icon returns, and the background hands over: blur and
//      dim lift, the glyph dissolves, and the bare wallpaper rises to
//      fill the screen exactly the way the desktop draws it, so the
//      handoff is seamless.
//
//  The centre is its fixed stage: the two-tone 224px clock, the date,
//  the profile picture in the big clam shell, the password pill with the
//  shapes that settle into circles, the state messages below. The side
//  columns carry weather · fetch · media (left) and resources · the
//  notification dock (right), on cards with its own corner radii. The
//  background is its blurred wallpaper. Switch back to the original
//  velvet lock any time: LOCK STYLE → VELVET.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "glyphpaths.js" as GP

WlSessionLock {
    id: lock

    locked: Locker.locked

    // One surface per screen, each wearing the whole face.
    WlSessionLockSurface {
        id: lockSurface

        // Never transparent: this colour is the guarantee that something is
        // painted even if the face fails to load.
        color: Colours.paper

        FluidFace {
            anchors.fill: parent
        }
    }
}
