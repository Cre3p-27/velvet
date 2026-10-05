//  VELVET  ·  modules/settings/Carousel.qml
//  Wallpaper browser. Applying one re-derives the accent, so the whole shell
//  changes colour the moment you press Enter. The row tilts like the big
//  wheel, every card casts a reflection, the picture in hand is named and
//  measured in a HUD plate, and the row bumps softly at either end.
import qs.config
import qs.services
import qs.components
import QtQuick

FocusScope {
    id: root

    signal closed

    focus: true

    readonly property var list: Wallpapers.shown
    readonly property string currentPath: view.currentIndex >= 0 && view.currentIndex < list.length ? list[view.currentIndex] : ""

    property real bumpY: 0
    property real lastMove: 0

    function move(delta: int): void {
        const n = root.list.length;
        if (n === 0)
            return;
        const next = view.currentIndex + delta;
        if (next < 0 || next >= n) {
            endBump.restart();
            Sfx.back();
            return;
        }
        view.currentIndex = next;
        const t = Date.now();
        if (t - root.lastMove > 80) {
            root.lastMove = t;
            Sfx.whoosh();
        }
    }

    // The apply pulse — the card in hand flexes the moment the wallpaper
    // behind it changes.
    SequentialAnimation {
        id: applyFlash

        property real flash: 0

        NumberAnimation {
            target: applyFlash
            property: "flash"
            to: 1
            duration: 160
        }
        NumberAnimation {
            target: applyFlash
            property: "flash"
            to: 0
            duration: 360
            easing.type: Easing.OutQuad
        }
    }

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

    Component.onCompleted: {
        const i = list.indexOf(Config.wallpaper.current);
        if (i >= 0)
            view.currentIndex = i;
        root.forceActiveFocus();
    }

    // ------------------------------------------------------------------ ground
    Rectangle {
        anchors.fill: parent
        color: Colours.alpha(Colours.paper, 0.42)
    }

    // ------------------------------------------------------------------ header
    Row {
        id: modes

        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.09
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 16

        Slash {
            width: 220
            height: 44
            shear: Appearance.skew
            color: Wallpapers.showFavouritesOnly ? "transparent" : Colours.accent
            borderColor: Colours.accent
            borderWidth: 3

            P5Text {
                anchors.centerIn: parent
                display: true
                text: `ALL  ·  ${Wallpapers.list.length}`
                color: Wallpapers.showFavouritesOnly ? Colours.accentInk : Colours.on(Colours.accent)
                font.pixelSize: Appearance.font.size.normal
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Wallpapers.showFavouritesOnly = false;
                    Sfx.cursor();
                }
            }
        }

        Slash {
            width: 220
            height: 44
            shear: Appearance.skew
            color: Wallpapers.showFavouritesOnly ? Colours.accent : "transparent"
            borderColor: Colours.accent
            borderWidth: 3

            P5Text {
                anchors.centerIn: parent
                display: true
                text: `FAVOURITES  ·  ${Wallpapers.favourites.length}`
                color: Wallpapers.showFavouritesOnly ? Colours.on(Colours.accent) : Colours.accentInk
                font.pixelSize: Appearance.font.size.normal
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Wallpapers.showFavouritesOnly = true;
                    Sfx.cursor();
                }
            }
        }
    }

    // ---------------------------------------------------------------- empty
    Column {
        anchors.centerIn: parent
        visible: root.list.length === 0
        spacing: 8

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            display: true
            text: "NO WALLPAPERS FOUND"
            color: Colours.ink
            font.pixelSize: Appearance.font.size.title
        }

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Config.wallpaper.directory
            color: Colours.inkDim
            font.family: Appearance.fontFamily.mono
            font.pixelSize: Appearance.font.size.small
        }
    }

    // -------------------------------------------------------------- carousel
    PathView {
        id: view

        anchors.fill: parent
        visible: root.list.length > 0
        model: root.list
        pathItemCount: 7
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: Appearance.anim.normal
        clip: true
        interactive: true

        readonly property real cardW: Math.min(width * 0.46, 900)
        readonly property real cardH: cardW * 0.5625
        property string curInfo: ""

        transform: Translate {
            y: root.bumpY
        }

        onCurrentIndexChanged: {
            view.curInfo = "";
            const t = Date.now();
            if (t - root.lastMove > 80) {
                root.lastMove = t;
                Sfx.whoosh();
            }
        }

        path: Path {
            startX: -view.width * 0.25
            startY: view.height * 0.53

            PathAttribute { name: "pvZ"; value: 0 }
            PathAttribute { name: "pvScale"; value: 0.42 }
            PathAttribute { name: "pvAlpha"; value: 0.0 }
            PathAttribute { name: "pvRot"; value: -14 }

            PathLine { x: view.width * 0.16; y: view.height * 0.53 }
            PathAttribute { name: "pvZ"; value: 10 }
            PathAttribute { name: "pvScale"; value: 0.62 }
            PathAttribute { name: "pvAlpha"; value: 0.5 }
            PathAttribute { name: "pvRot"; value: -7 }

            PathLine { x: view.width * 0.5; y: view.height * 0.53 }
            PathAttribute { name: "pvZ"; value: 60 }
            PathAttribute { name: "pvScale"; value: 1.0 }
            PathAttribute { name: "pvAlpha"; value: 1.0 }
            PathAttribute { name: "pvRot"; value: 0 }

            PathLine { x: view.width * 0.84; y: view.height * 0.53 }
            PathAttribute { name: "pvZ"; value: 10 }
            PathAttribute { name: "pvScale"; value: 0.62 }
            PathAttribute { name: "pvAlpha"; value: 0.5 }
            PathAttribute { name: "pvRot"; value: 7 }

            PathLine { x: view.width * 1.25; y: view.height * 0.53 }
            PathAttribute { name: "pvZ"; value: 0 }
            PathAttribute { name: "pvScale"; value: 0.42 }
            PathAttribute { name: "pvAlpha"; value: 0.0 }
            PathAttribute { name: "pvRot"; value: 14 }
        }

        delegate: Item {
            id: card

            required property string modelData
            required property int index

            readonly property bool isCurrent: PathView.isCurrentItem
            readonly property bool fav: Wallpapers.isFavourite(modelData)

            width: view.cardW
            height: view.cardH
            z: PathView.pvZ ?? 0
            scale: PathView.pvScale ?? 1
            opacity: PathView.pvAlpha ?? 1
            rotation: PathView.pvRot ?? 0

            onIsCurrentChanged: {
                if (card.isCurrent && img.status === Image.Ready)
                    view.curInfo = `${img.sourceSize.width} × ${img.sourceSize.height}`;
            }

            // Everything visual lives in `content`, so the apply flex never
            // fights PathView's own scale.
            Item {
                id: content

                anchors.fill: parent
                scale: card.isCurrent ? 1 + applyFlash.flash * 0.04 : 1

                // Accent frame behind the image, offset like a print registration.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -10
                    anchors.leftMargin: -18
                    anchors.topMargin: -18
                    color: "transparent"
                    border.width: card.isCurrent ? 5 : 0
                    border.color: Colours.accent
                    antialiasing: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Colours.paper
                    clip: true

                    Image {
                        id: img

                        anchors.fill: parent
                        source: "file://" + card.modelData
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 1280
                        asynchronous: true
                        cache: true

                        onStatusChanged: {
                            if (status === Image.Ready && card.isCurrent)
                                view.curInfo = `${sourceSize.width} × ${sourceSize.height}`;
                        }
                    }

                    // Bottom scrim so the filename stays readable.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * 0.36
                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: "transparent"
                            }
                            GradientStop {
                                position: 1
                                color: Colours.alpha(Colours.paper, 0.82)
                            }
                        }
                    }
                }

                P5Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 18
                    visible: card.isCurrent
                    display: true
                    text: Wallpapers.basename(card.modelData)
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.large
                    elide: Text.ElideRight
                    width: parent.width - 90
                }

                // Favourite star, top-right corner of the current card.
                Slash {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    visible: card.isCurrent || card.fav
                    width: 42
                    height: 42
                    shear: Appearance.skew
                    color: card.fav ? Colours.accent : Colours.alpha(Colours.paper, 0.7)

                    Icon {
                        anchors.centerIn: parent
                        name: card.fav ? "star" : "star_border"
                        color: card.fav ? Colours.on(Colours.accent) : Colours.ink
                        font.pixelSize: Appearance.font.size.large
                    }
                }

                // Marker on whatever is currently applied.
                Slash {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 12
                    visible: Config.wallpaper.current === card.modelData
                    width: 108
                    height: 30
                    shear: Appearance.skew
                    color: Colours.accent

                    P5Text {
                        anchors.centerIn: parent
                        display: true
                        text: "ACTIVE"
                        color: Colours.on(Colours.accent)
                        font.pixelSize: Appearance.font.size.tiny
                    }
                }
            }

            // The mirror under the card — the coverflow's depth cue.
            Item {
                y: card.height + 8
                width: card.width
                height: card.height * 0.28
                visible: (PathView.pvAlpha ?? 0) > 0.4
                opacity: (PathView.pvAlpha ?? 0) * 0.4
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
                    sourceSize.width: 640
                    sourceSize.height: 640
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Colours.alpha(Colours.paper, 0.9)
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
                onClicked: {
                    if (card.isCurrent) {
                        Wallpapers.apply(card.modelData);
                        Sfx.select();
                        applyFlash.restart();
                    } else {
                        view.currentIndex = card.index;
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- HUD plate
    //  The picture in hand, named and measured.
    Slash {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.19
        anchors.horizontalCenter: parent.horizontalCenter
        width: hudRow.implicitWidth + 44
        height: 44
        shear: Appearance.skew
        color: Colours.alpha(Colours.ink, 0.07)
        borderColor: Colours.alpha(Colours.ink, 0.22)
        borderWidth: 1
        visible: root.list.length > 0 && root.currentPath !== ""

        Row {
            id: hudRow

            anchors.centerIn: parent
            spacing: 12

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: Wallpapers.basename(root.currentPath)
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
                visible: Wallpapers.isFavourite(root.currentPath)
                text: "★"
                color: Colours.accent
                font.pixelSize: Appearance.font.size.normal
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.wallpaper.current === root.currentPath
                text: "ACTIVE"
                color: Colours.accent
                font.pixelSize: Appearance.font.size.tiny
                tracking: 2
            }
        }
    }

    // ------------------------------------------------------------------ toast
    Slash {
        id: toast

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.14
        width: 340
        height: 48
        shear: Appearance.skew
        color: Colours.accent
        opacity: 0

        P5Text {
            id: toastText

            anchors.centerIn: parent
            display: true
            text: ""
            color: Colours.on(Colours.accent)
            font.pixelSize: Appearance.font.size.normal
        }

        SequentialAnimation {
            id: toastAnim

            NumberAnimation {
                target: toast
                property: "opacity"
                to: 1
                duration: Appearance.anim.fast
            }
            PauseAnimation {
                duration: 900
            }
            NumberAnimation {
                target: toast
                property: "opacity"
                to: 0
                duration: Appearance.anim.normal
            }
        }
    }

    function flash(message: string): void {
        toastText.text = message;
        toastAnim.restart();
    }

    // --------------------------------------------------------------- keyboard
    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Escape:
        case Qt.Key_Backspace:
            root.closed();
            event.accepted = true;
            return;
        case Qt.Key_Left:
            root.move(-1);
            event.accepted = true;
            return;
        case Qt.Key_Right:
            root.move(1);
            event.accepted = true;
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (root.currentPath) {
                Wallpapers.apply(root.currentPath);
                Sfx.select();
                applyFlash.restart();
                root.flash("WALLPAPER APPLIED");
            }
            event.accepted = true;
            return;
        case Qt.Key_F:
            if (root.currentPath) {
                Wallpapers.toggleFavourite(root.currentPath);
                Sfx.toggle();
                root.flash(Wallpapers.isFavourite(root.currentPath) ? "ADDED TO FAVOURITES" : "REMOVED FROM FAVOURITES");
            }
            event.accepted = true;
            return;
        case Qt.Key_Tab:
            Wallpapers.showFavouritesOnly = !Wallpapers.showFavouritesOnly;
            Sfx.cursor();
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
            view.currentIndex = Math.min(root.list.length - 1, view.currentIndex + 10);
            event.accepted = true;
            return;
        case Qt.Key_Home:
            view.currentIndex = 0;
            event.accepted = true;
            return;
        case Qt.Key_End:
            view.currentIndex = Math.max(0, root.list.length - 1);
            event.accepted = true;
            return;
        }
    }
}
