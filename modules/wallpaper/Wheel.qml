//  VELVET  ·  modules/wallpaper/Wheel.qml
//  The wallpaper carousel — the full-screen coverflow.
//
//  One row of cards on a slow tilt: the picture in hand sits full size in
//  the middle with a mirror reflection under it, its neighbours step back,
//  shrink and lean away. The centre card breathes with a Ken Burns drift,
//  Enter flexes it and applies, and the row bumps softly at either end
//  instead of stopping dead. A HUD plate names the picture, its pixel
//  size and its state; the ghost wallpaper behind parallaxes against the
//  motion. F stars, Tab filters to favourites, R rolls the dice.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    readonly property bool open: Panels.wheel

    property bool entered: false
    property bool rendered: false

    readonly property var list: Wallpapers.shown
    readonly property int count: root.list.length
    readonly property string current: view.currentIndex >= 0 && view.currentIndex < root.count ? root.list[view.currentIndex] : ""

    // The ghost wallpaper drifts against the coverflow's motion — a cheap
    // parallax that keeps the background feeling like a room, not a photo.
    property real drift: 0
    property int baseIdx: 0
    property real lastMove: 0

    function applyCurrent(): void {
        if (!root.current)
            return;
        Sfx.select();
        Wallpapers.apply(root.current);
        applyFlash.restart();
    }

    function syncToCurrent(): void {
        const i = root.list.indexOf(Config.wallpaper.current);
        view.currentIndex = i >= 0 ? i : 0;
    }

    // The shared move: whooshes, drifts the ghost, bumps at the ends.
    function move(delta: int): void {
        if (root.count === 0)
            return;
        const next = view.currentIndex + delta;
        if (next < 0 || next >= root.count) {
            endBump.restart();
            Sfx.back();
            return;
        }
        view.currentIndex = next;
        root.drift = Math.max(-80, Math.min(80, (root.baseIdx - view.currentIndex) * 26));
    }

    screen: Hypr.focusedScreen
    visible: root.rendered
    color: "transparent"

    WlrLayershell.namespace: "velvet-wheel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: -1

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    onOpenChanged: {
        if (root.open) {
            root.rendered = true;
            root.syncToCurrent();
            Wallpapers.scan();
            openTimer.restart();
        } else {
            root.entered = false;
            exitTimer.restart();
        }
    }

    // The scan may still be walking the disk when the wheel opens (first
    // boot, fresh directory) — when the list lands, jump onto the current
    // wallpaper instead of leaving the row wherever it started.
    Connections {
        target: Wallpapers

        function onListChanged(): void {
            if (root.open)
                root.syncToCurrent();
        }
    }

    Timer {
        id: openTimer
        interval: 16
        onTriggered: {
            root.entered = true;
            root.baseIdx = view.currentIndex;
            root.drift = 0;
            scope.forceActiveFocus();
        }
    }

    Timer {
        id: exitTimer
        interval: Appearance.anim.normal + 40
        onTriggered: root.rendered = false
    }

    // The apply pulse: the frame flashes and the card in hand flexes, so
    // Enter has visible feedback even though the wallpaper behind changes.
    SequentialAnimation {
        id: applyFlash

        property real flash: 0

        NumberAnimation {
            target: applyFlash
            property: "flash"
            to: 1
            duration: 180
        }
        NumberAnimation {
            target: applyFlash
            property: "flash"
            to: 0
            duration: 380
            easing.type: Easing.OutQuad
        }
    }

    // The end-of-row bump — the whole row dips and springs back.
    property real bumpY: 0

    SequentialAnimation {
        id: endBump

        NumberAnimation {
            target: root
            property: "bumpY"
            to: 12
            duration: 90
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "bumpY"
            to: 0
            duration: 280
            easing.type: Easing.OutBack
        }
    }

    // ------------------------------------------------------------ the ground
    Rectangle {
        anchors.fill: parent
        color: Colours.alpha(Colours.paper, 0.94)
        opacity: root.entered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }

        // The wallpaper you are choosing between, ghosted behind the row —
        // and parallaxing against the coverflow's motion. Bleeds on every
        // side so the drift never drags an edge into view.
        Image {
            width: parent.width + 160
            height: parent.height + 160
            x: root.drift - 80
            y: -80
            source: Config.wallpaper.current ? "file://" + Config.wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            opacity: 0.12
            asynchronous: true
            cache: true
            // A 12 % ghost: decoding the full-size photo here cost ~100 MB
            // for a picture nobody can see sharply.
            sourceSize.width: 960
            sourceSize.height: 960

            Behavior on x {
                NumberAnimation {
                    duration: Appearance.anim.slow
                    easing.type: Easing.OutCubic
                }
            }
        }

        // A quiet gradient keeps the bottom line readable on any picture.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: Colours.alpha(Colours.paper, 0.35)
                }
            }
        }

        // The room itself: speed lines raking out from the centre, the
        // halftone grain, and the ghost word behind the coverflow.
        SpeedLines {
            anchors.fill: parent
            color: Colours.accent
            strength: 0.05
            originX: 0.5
            originY: 0.52
            count: 14

            NumberAnimation on spin {
                running: root.entered
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 300000
            }
        }

        Halftone {
            anchors.fill: parent
            strength: 0.045
            angle: -14
        }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: "WALLPAPERS"
            color: Colours.ink
            opacity: 0.04
            font.pixelSize: Math.min(parent.height * 0.4, 380)
            tracking: -6
            rotation: -4
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                Sfx.close();
                Panels.wheel = false;
            }
        }
    }

    FocusScope {
        id: scope

        anchors.fill: parent
        focus: true

        Keys.onLeftPressed: root.move(-1)
        Keys.onRightPressed: root.move(1)
        Keys.onReturnPressed: root.applyCurrent()
        Keys.onEnterPressed: root.applyCurrent()
        Keys.onEscapePressed: Panels.wheel = false

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_F:
                if (root.current) {
                    Wallpapers.toggleFavourite(root.current);
                    Sfx.toggle();
                }
                event.accepted = true;
                return;
            case Qt.Key_Tab:
                Wallpapers.showFavouritesOnly = !Wallpapers.showFavouritesOnly;
                Sfx.toggle();
                event.accepted = true;
                return;
            case Qt.Key_S:
                // S saves the look for the wallpaper that is up (README, F1).
                Looks.save();
                Sfx.select();
                event.accepted = true;
                return;
            case Qt.Key_R:
                Wallpapers.random();
                Sfx.select();
                event.accepted = true;
                return;
            case Qt.Key_PageUp:
                view.currentIndex = Math.max(0, view.currentIndex - 10);
                event.accepted = true;
                return;
            case Qt.Key_PageDown:
                view.currentIndex = Math.min(root.count - 1, view.currentIndex + 10);
                event.accepted = true;
                return;
            case Qt.Key_Home:
                view.currentIndex = 0;
                event.accepted = true;
                return;
            case Qt.Key_End:
                view.currentIndex = Math.max(0, root.count - 1);
                event.accepted = true;
                return;
            }
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (event.angleDelta.y > 0)
                    root.move(-1);
                else
                    root.move(1);
            }
        }

        // --------------------------------------------------------- the stage
        Item {
            id: stage

            anchors.fill: parent
            opacity: root.entered ? 1 : 0
            scale: root.entered ? 1 : 0.985

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.entrance
                    easing.type: Easing.OutExpo
                }
            }

            // Swallows stray clicks on the empty middle ground so they never
            // fall through to the backdrop and close the carousel.
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton | Qt.RightButton
            }

            // ── the one quiet line on top
            Row {
                anchors.top: parent.top
                anchors.topMargin: parent.height * 0.07
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WALLPAPERS"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.normal
                    tracking: 6
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.count > 0
                    text: `${((view.currentIndex % Math.max(1, root.count)) + Math.max(1, root.count)) % Math.max(1, root.count) + 1} / ${root.count}`
                    color: Colours.alpha(Colours.inkDim, 0.9)
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: Appearance.font.size.small
                    tracking: 1
                }
            }

            // ── the coverflow itself
            PathView {
                id: view

                anchors.fill: parent
                visible: root.count > 0
                model: root.list
                pathItemCount: 7
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: Appearance.anim.normal
                clip: true
                // The row is alive: drag it and it carries momentum, then
                // StrictlyEnforceRange snaps the nearest card into place.
                interactive: true
                flickDeceleration: 4200

                readonly property real cardW: Math.min(parent.width * 0.4, 840)
                readonly property real cardH: cardW * 0.5625
                property string curInfo: ""

                transform: Translate {
                    y: root.bumpY
                }

                onCurrentIndexChanged: {
                    view.curInfo = "";
                    if (root.entered) {
                        const t = Date.now();
                        if (t - root.lastMove > 80) {
                            root.lastMove = t;
                            Sfx.whoosh();
                        }
                    }
                }

                path: Path {
                    startX: -view.cardW
                    startY: view.height * 0.5

                    PathAttribute { name: "pvScale"; value: 0.5 }
                    PathAttribute { name: "pvAlpha"; value: 0.0 }
                    PathAttribute { name: "pvRot"; value: -18 }

                    PathLine { x: view.width * 0.18; y: view.height * 0.5 }
                    PathAttribute { name: "pvScale"; value: 0.62 }
                    PathAttribute { name: "pvAlpha"; value: 0.45 }
                    PathAttribute { name: "pvRot"; value: -9 }

                    PathLine { x: view.width * 0.5; y: view.height * 0.565 }
                    PathAttribute { name: "pvScale"; value: 1.0 }
                    PathAttribute { name: "pvAlpha"; value: 1.0 }
                    PathAttribute { name: "pvRot"; value: 0 }

                    PathLine { x: view.width * 0.82; y: view.height * 0.5 }
                    PathAttribute { name: "pvScale"; value: 0.62 }
                    PathAttribute { name: "pvAlpha"; value: 0.45 }
                    PathAttribute { name: "pvRot"; value: 9 }

                    PathLine { x: view.width + view.cardW; y: view.height * 0.5 }
                    PathAttribute { name: "pvScale"; value: 0.5 }
                    PathAttribute { name: "pvAlpha"; value: 0.0 }
                    PathAttribute { name: "pvRot"; value: 18 }
                }

                delegate: Item {
                    id: card

                    required property string modelData
                    required property int index

                    readonly property bool isCurrent: PathView.isCurrentItem
                    readonly property bool fav: Wallpapers.isFavourite(card.modelData)
                    readonly property bool inUse: Config.wallpaper.current === card.modelData

                    width: view.cardW
                    height: view.cardH
                    scale: PathView.pvScale ?? 1
                    opacity: PathView.pvAlpha ?? 1
                    rotation: PathView.pvRot ?? 0

                    onIsCurrentChanged: {
                        if (card.isCurrent && img.status === Image.Ready)
                            view.curInfo = `${img.sourceSize.width} × ${img.sourceSize.height}`;
                    }

                    // -------------------------------------------- the card
                    //  Everything visual lives in `content`, so the apply
                    //  flex never fights PathView's own scale.
                    Item {
                        id: content

                        anchors.fill: parent
                        scale: card.isCurrent ? 1 + applyFlash.flash * 0.05 : 1

                        // Accent frame behind the image, offset like a print
                        // registration — the selected card wears a crown.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -9
                            anchors.leftMargin: -16
                            anchors.topMargin: -16
                            color: "transparent"
                            border.width: card.isCurrent ? 5 : 0
                            border.color: Colours.accent
                            antialiasing: true
                        }

                        Plate {
                            anchors.fill: parent
                            color: Colours.paper
                            radius: Appearance.rounding.normal
                            border.width: card.isCurrent ? 3 : 1
                            border.color: card.isCurrent
                                ? (applyFlash.flash > 0 ? Colours.accent : Colours.alpha(Colours.accent, 0.85))
                                : Colours.alpha(Colours.ink, 0.14)
                            clip: true
                            antialiasing: true
                        }

                        // The centre card breathes — the Ken Burns drift,
                        // previewing what the desktop will do with it.
                        Item {
                            id: kb

                            anchors.fill: parent

                            SequentialAnimation on scale {
                                running: card.isCurrent && Config.wallpaper.kenBurns && root.entered   // not while the wheel is closed
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 1
                                    to: 1.05
                                    duration: 16000
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    from: 1.05
                                    to: 1
                                    duration: 16000
                                    easing.type: Easing.InOutSine
                                }
                            }

                            Image {
                                id: img

                                anchors.fill: parent
                                source: "file://" + card.modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                sourceSize.width: 1280
                                sourceSize.height: 1280

                                onStatusChanged: {
                                    if (status === Image.Ready && card.isCurrent)
                                        view.curInfo = `${sourceSize.width} × ${sourceSize.height}`;
                                }
                            }
                        }

                        // Scanlines — three whisper-thin rulings, so the
                        // coverflow reads as a monitor, not a photo album.
                        Repeater {
                            model: 3

                            Rectangle {
                                required property int index

                                anchors.left: parent.left
                                anchors.right: parent.right
                                y: (index + 1) * parent.height / 4
                                height: 1
                                color: Colours.alpha(Colours.ink, 0.05)
                            }
                        }

                        // The name rides on a quiet gradient along the bottom.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 46
                            visible: card.isCurrent
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: Colours.alpha(Colours.paper, 0)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Colours.alpha(Colours.paper, 0.9)
                                }
                            }

                            P5Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 16
                                anchors.right: parent.right
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: Wallpapers.basename(card.modelData)
                                color: Colours.ink
                                font.pixelSize: Appearance.font.size.normal
                                elide: Text.ElideRight
                            }
                        }

                        // ACTIVE badge on whatever is on the desktop right now.
                        Plate {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 12
                            width: 82
                            height: 24
                            radius: Appearance.r(12)
                            visible: card.inUse
                            color: Colours.accent
                            antialiasing: true

                            P5Text {
                                anchors.centerIn: parent
                                text: "ACTIVE"
                                color: Colours.on(Colours.accent)
                                font.pixelSize: Appearance.font.size.tiny
                                tracking: 2
                            }
                        }

                        // The star, only on the card in hand.
                        Plate {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            width: 36
                            height: 36
                            radius: Appearance.r(18)
                            visible: card.isCurrent
                            color: Colours.alpha(Colours.paper, 0.75)
                            border.width: 1
                            border.color: Colours.alpha(Colours.ink, 0.12)
                            antialiasing: true

                            Icon {
                                anchors.centerIn: parent
                                name: card.fav ? "star" : "star_border"
                                color: card.fav ? Colours.accent : Colours.alpha(Colours.ink, 0.7)
                                font.pixelSize: 18
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Wallpapers.toggleFavourite(card.modelData);
                                    Sfx.toggle();
                                }
                            }
                        }

                        Ripple {
                            id: rip

                            anchors.fill: parent
                            color: Colours.accent
                            maxOpacity: 0.3
                        }
                    }

                    // ----------------------------------------- reflection
                    //  A soft mirror under every visible card — the coverflow's
                    //  signature depth cue.
                    Item {
                        y: card.height + 8
                        width: card.width
                        height: card.height * 0.3
                        visible: (PathView.pvAlpha ?? 0) > 0.45
                        opacity: (PathView.pvAlpha ?? 0) * 0.42
                        clip: true

                        transform: Scale {
                            origin.y: 0
                            yScale: -1
                        }

                        Image {
                            anchors.fill: parent
                            source: "file://" + card.modelData
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            sourceSize.width: 640
                            sourceSize.height: 640
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: Colours.alpha(Colours.paper, 0.92)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: Colours.alpha(Colours.paper, 1.0)
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: event => {
                            rip.pop(event.x, event.y);
                            if (card.isCurrent)
                                root.applyCurrent();
                            else
                                view.currentIndex = card.index;
                        }
                    }
                }
            }

            // ── nothing to choose from
            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: root.count === 0

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NO WALLPAPERS FOUND"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.title
                }

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Config.wallpaper.directory
                    color: Colours.alpha(Colours.inkDim, 0.85)
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: Appearance.font.size.small
                }
            }

            // ── the HUD plate: the picture in hand, named and measured
            Slash {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.105
                anchors.horizontalCenter: parent.horizontalCenter
                width: hudRow.implicitWidth + 44
                height: 44
                shear: Appearance.skew
                color: Colours.alpha(Colours.ink, 0.07)
                borderColor: Colours.alpha(Colours.ink, 0.22)
                borderWidth: 1
                visible: root.count > 0 && root.current !== ""

                Row {
                    id: hudRow

                    anchors.centerIn: parent
                    spacing: 12

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: Wallpapers.basename(root.current)
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.normal
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: view.curInfo !== ""
                        text: view.curInfo
                        color: Colours.inkDim
                        font.family: Appearance.fontFamily.mono
                        font.pixelSize: Appearance.font.size.tiny
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Wallpapers.isFavourite(root.current)
                        text: "★"
                        color: Colours.accent
                        font.pixelSize: Appearance.font.size.normal
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Config.wallpaper.current === root.current
                        text: "ACTIVE"
                        color: Colours.accent
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 2
                    }
                }
            }

            // ── one quiet line at the bottom
            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.06
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                visible: root.count > 0

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "← → BROWSE   ·   ENTER APPLY   ·   F STAR   ·   TAB FILTER   ·   ESC CLOSE"
                    color: Colours.alpha(Colours.inkDim, 0.85)
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }

                Plate {
                    id: favPill

                    anchors.verticalCenter: parent.verticalCenter
                    height: 24
                    width: favLabel.implicitWidth + 28
                    radius: Appearance.r(12)
                    color: Wallpapers.showFavouritesOnly ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, 0.1)
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    P5Text {
                        id: favLabel

                        anchors.centerIn: parent
                        text: "★ FAVOURITES"
                        color: Wallpapers.showFavouritesOnly ? Colours.on(Colours.accent) : Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Wallpapers.showFavouritesOnly = !Wallpapers.showFavouritesOnly;
                            Sfx.toggle();
                        }
                    }
                }
            }
        }
    }

    // Panels are loaded on demand (shell.qml, Parked): when this window is created by
    // its own flag the change signal has already gone by, so say it once more.
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (root.open)
                root.openChanged();
        }
    }
}
