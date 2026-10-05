//  VELVET  ·  modules/settings/FacePicker.qml
//  Choosing your profile photo. A portrait coverflow over the pictures on
//  your machine — ~/Pictures, ~/Downloads and the wallpaper directory —
//  plus two special cards: NO PHOTO (back to the initial glyph) and the
//  CURRENT FACE. Enter copies the pick to ~/.face and the photo follows
//  you everywhere: the title screen and the lock screen wear it at once.
//
//  Keyboard: ← → browse · ENTER apply · ESC back · R rescan. Mouse: drag
//  the row, click the card in hand to apply, click a neighbour to pull it
//  into the middle.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Io
import QtQuick

FocusScope {
    id: root

    signal closed
    signal faceApplied

    focus: true

    readonly property string homeDir: Quickshell.env("HOME") ?? ""
    readonly property string facePath: `${root.homeDir}/.face`

    property bool faceExists: false

    FileView {
        id: faceProbe

        path: root.facePath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: root.faceExists = true
        onLoadFailed: root.faceExists = false
    }

    // The card row: NO PHOTO, then the current ~/.face (when there is
    // one), then everything the scan found.
    property var scanned: []

    readonly property var list: {
        const out = [""];
        if (root.faceExists)
            out.push(root.facePath);
        for (let i = 0; i < root.scanned.length; i++) {
            if (root.scanned[i] !== "" && root.scanned[i] !== root.facePath)
                out.push(root.scanned[i]);
        }
        return out;
    }

    readonly property string currentPath: view.currentIndex >= 0 && view.currentIndex < root.list.length ? root.list[view.currentIndex] : ""

    function basename(path: string): string {
        const f = path.split("/").pop();
        return f.replace(/\.[^.]+$/, "");
    }

    function labelOf(path: string): string {
        if (path === "")
            return "NO PHOTO";
        if (path === root.facePath)
            return "CURRENT FACE";
        return root.basename(path);
    }

    function scan(): void {
        scanner.running = false;
        scanner.running = true;
    }

    // Throttled whoosh, so key repeat and dragging never machine-gun audio.
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

    function applyCurrent(): void {
        const p = root.currentPath;
        if (p === undefined)
            return;

        // NO PHOTO — the glyph takes the ring back.
        if (p === "") {
            Config.set("home.avatarFace", false);
            Config.set("lock.avatarFace", false);
            Sfx.toggle();
            root.flash("FACE OFF — YOUR INITIAL IS THE FACE");
            Toast.show("PROFILE PHOTO OFF  ·  THE GLYPH WEARS THE RING AGAIN", "info", 3200);
            return;
        }

        // The card that already is ~/.face — nothing to copy.
        if (p === root.facePath) {
            Config.set("home.avatarFace", true);
            Config.set("lock.avatarFace", true);
            Sfx.select();
            root.flash("CURRENT FACE KEPT");
            return;
        }

        // A fresh pick: copy it home and wear it everywhere at once.
        copier.command = ["cp", "--", p, root.facePath];
        copier.running = false;
        copier.running = true;
        Config.set("home.avatarFace", true);
        Config.set("lock.avatarFace", true);
        Sfx.select();
        root.flash("FACE UPDATED");
        Toast.show("PROFILE PHOTO UPDATED  ·  IT FOLLOWS YOU TO THE LOCK SCREEN TOO", "ok", 3400);
        root.faceApplied();
    }

    Component.onCompleted: {
        root.scan();
        root.forceActiveFocus();
    }

    Process {
        id: scanner

        command: ["bash", "-c", `find "${root.homeDir}/Pictures" "${root.homeDir}/Downloads" "${Config.wallpaper.directory}" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.bmp' \\) 2>/dev/null | sort -u | head -n 240`]

        stdout: StdioCollector {
            onStreamFinished: {
                root.scanned = text.trim().split("\n").filter(l => l.length > 0);
                // Land where the user already is: on the current face, or
                // on NO PHOTO when the glyph is what they wear.
                if (Config.home.avatarFace && root.faceExists) {
                    const i = root.list.indexOf(root.facePath);
                    view.currentIndex = i >= 0 ? i : 0;
                } else {
                    view.currentIndex = 0;
                }
            }
        }
    }

    Process {
        id: copier
        command: ["true"]
    }

    // ---------------------------------------------------------------- ground
    Rectangle {
        anchors.fill: parent
        color: Colours.alpha(Colours.paper, 0.86)
    }

    // ----------------------------------------------------------------- stage
    Item {
        id: stage

        anchors.fill: parent

        // ---------------------------------------------------------- header
        Column {
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.07
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: "YOUR FACE"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.title
                    tracking: 4
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.list.length > 0
                    text: `${((view.currentIndex % Math.max(1, root.list.length)) + Math.max(1, root.list.length)) % Math.max(1, root.list.length) + 1} / ${root.list.length}`
                    color: Colours.alpha(Colours.inkDim, 0.9)
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: Appearance.font.size.small
                    tracking: 1
                }
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "PICK A PHOTO — IT BECOMES YOUR FACE ON THE TITLE SCREEN AND THE LOCK"
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.small
                tracking: 2
            }
        }

        // -------------------------------------------------------- coverflow
        PathView {
            id: view

            anchors.fill: parent
            visible: root.list.length > 1
            model: root.list
            pathItemCount: 7
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: Appearance.anim.normal
            clip: true

            readonly property real cardW: Math.min(width * 0.26, 420)
            readonly property real cardH: cardW
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
                startY: view.height * 0.56

                PathAttribute { name: "pvZ"; value: 0 }
                PathAttribute { name: "pvScale"; value: 0.5 }
                PathAttribute { name: "pvAlpha"; value: 0.0 }
                PathAttribute { name: "pvRot"; value: -14 }

                PathLine { x: view.width * 0.2; y: view.height * 0.56 }
                PathAttribute { name: "pvZ"; value: 10 }
                PathAttribute { name: "pvScale"; value: 0.68 }
                PathAttribute { name: "pvAlpha"; value: 0.55 }
                PathAttribute { name: "pvRot"; value: -7 }

                PathLine { x: view.width * 0.5; y: view.height * 0.56 }
                PathAttribute { name: "pvZ"; value: 60 }
                PathAttribute { name: "pvScale"; value: 1.0 }
                PathAttribute { name: "pvAlpha"; value: 1.0 }
                PathAttribute { name: "pvRot"; value: 0 }

                PathLine { x: view.width * 0.8; y: view.height * 0.56 }
                PathAttribute { name: "pvZ"; value: 10 }
                PathAttribute { name: "pvScale"; value: 0.68 }
                PathAttribute { name: "pvAlpha"; value: 0.55 }
                PathAttribute { name: "pvRot"; value: 7 }

                PathLine { x: view.width * 1.25; y: view.height * 0.56 }
                PathAttribute { name: "pvZ"; value: 0 }
                PathAttribute { name: "pvScale"; value: 0.5 }
                PathAttribute { name: "pvAlpha"; value: 0.0 }
                PathAttribute { name: "pvRot"; value: 14 }
            }

            delegate: Item {
                id: card

                required property string modelData
                required property int index

                readonly property bool isCurrent: PathView.isCurrentItem
                readonly property bool isFace: card.modelData === root.facePath
                readonly property bool faceOn: Config.home.avatarFace && root.faceExists
                readonly property bool badgeCurrent: (card.modelData === "" && !root.faceExists) || (card.modelData === "" && !Config.home.avatarFace) || (card.isFace && card.faceOn)

                width: view.cardW
                    height: view.cardH
                    z: PathView.pvZ ?? 0
                    scale: PathView.pvScale ?? 1
                    opacity: PathView.pvAlpha ?? 1
                    rotation: PathView.pvRot ?? 0

                    onIsCurrentChanged: {
                        if (card.isCurrent && faceImg.status === Image.Ready && card.modelData !== "")
                            view.curInfo = `${faceImg.sourceSize.width} × ${faceImg.sourceSize.height}`;
                    }

                // ------------------------------------------------ the card
                Item {
                    id: content

                    anchors.fill: parent
                    scale: card.isCurrent ? 1 + applyFlash.flash * 0.04 : 1

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -10
                        color: "transparent"
                        border.width: card.isCurrent ? 5 : 0
                        border.color: Colours.accent
                        radius: (content.width + 20) / 2
                        antialiasing: true
                    }

                    // The card IS the avatar: a circle, exactly like the
                    // ring the photo will wear on the title screen.
                    Rectangle {
                        anchors.fill: parent
                        color: Colours.paper
                        radius: width / 2
                        border.width: 1
                        border.color: Colours.alpha(Colours.ink, 0.14)
                        clip: true
                        antialiasing: true

                        Image {
                            id: faceImg

                            anchors.fill: parent
                            visible: card.modelData !== ""
                            source: card.modelData !== "" ? "file://" + card.modelData : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            smooth: true
                            sourceSize.width: 900
                            sourceSize.height: 900

                            onStatusChanged: {
                                if (status === Image.Ready && card.isCurrent)
                                    view.curInfo = `${sourceSize.width} × ${sourceSize.height}`;
                            }
                        }

                        // The two special cards: the glyph and the current face.
                        Rectangle {
                            anchors.fill: parent
                            visible: card.modelData === ""
                            color: Colours.alpha(Colours.ink, 0.06)
                            radius: width / 2

                            P5Text {
                                anchors.centerIn: parent
                                display: true
                                text: Locker.user.length > 0 ? Locker.user[0].toUpperCase() : "?"
                                color: Colours.on(Colours.accent)
                                font.pixelSize: view.cardW * 0.34
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: card.modelData === ""
                                color: Colours.alpha(Colours.accent, 0.85)
                                radius: width / 2
                                z: -1
                            }
                        }

                        // The inner ring — the avatar's own accent rim.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 8
                            color: "transparent"
                            radius: width / 2
                            border.width: 1
                            border.color: Colours.alpha(Colours.ink, 0.22)
                            antialiasing: true
                        }

                        // Name strip along the bottom.
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 44
                            visible: card.isCurrent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Colours.alpha(Colours.paper, 0) }
                                GradientStop { position: 1.0; color: Colours.alpha(Colours.paper, 0.92) }
                            }

                            P5Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 14
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                display: true
                                text: root.labelOf(card.modelData)
                                color: Colours.ink
                                font.pixelSize: Appearance.font.size.small
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // CURRENT badge — on the photo you are wearing.
                    Slash {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 10
                        visible: card.badgeCurrent
                        width: 96
                        height: 28
                        shear: Appearance.skew
                        color: Colours.accent

                        P5Text {
                            anchors.centerIn: parent
                            display: true
                            text: "CURRENT"
                            color: Colours.on(Colours.accent)
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1.6
                        }
                    }

                    Ripple {
                        id: rip

                        anchors.fill: parent
                        color: Colours.accent
                        maxOpacity: 0.3
                    }
                }

                // --------------------------------------------- reflection
                //  A soft mirror under the card — the coverflow's depth cue.
                Rectangle {
                    y: card.height + 8
                    width: card.width
                    height: card.height * 0.3
                    visible: (PathView.pvAlpha ?? 0) > 0.45
                    opacity: (PathView.pvAlpha ?? 0) * 0.4
                    clip: true
                    radius: width / 2
                    color: "transparent"
                    transform: Scale {
                        origin.y: 0
                        yScale: -1
                    }

                    Image {
                        anchors.fill: parent
                        visible: card.modelData !== ""
                        source: card.modelData !== "" ? "file://" + card.modelData : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                        sourceSize.width: 600
                        sourceSize.height: 600
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Colours.alpha(Colours.paper, 0.9) }
                            GradientStop { position: 1.0; color: Colours.alpha(Colours.paper, 1.0) }
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

        // ------------------------------------------------------- empty state
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: root.list.length <= 1

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 30
                name: "portrait"
                color: Colours.alpha(Colours.accent, 0.6)
                font.pixelSize: 28
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: "NO PICTURES FOUND"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.title
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "DROP SOME INTO ~/PICTURES OR ~/DOWNLOADS, THEN PRESS R"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.small
                tracking: 1
            }
        }

        // -------------------------------------------------------- HUD plate
        Slash {
            id: hud

            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.09
            anchors.horizontalCenter: parent.horizontalCenter
            width: hudRow.implicitWidth + 44
            height: 46
            shear: Appearance.skew
            color: Colours.alpha(Colours.ink, 0.07)
            borderColor: Colours.alpha(Colours.ink, 0.22)
            borderWidth: 1
            visible: root.list.length > 1 && root.currentPath !== undefined

            Row {
                id: hudRow

                anchors.centerIn: parent
                spacing: 12

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    display: true
                    text: root.labelOf(root.currentPath)
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
                    visible: view.curInfo === "" && root.currentPath !== ""
                    text: "PHOTO"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                }
            }
        }

        // ------------------------------------------------------------- hints
        P5Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.045
            anchors.horizontalCenter: parent.horizontalCenter
            text: "← → BROWSE   ·   ENTER APPLY   ·   ESC BACK   ·   R RESCAN"
            color: Colours.alpha(Colours.inkDim, 0.85)
            font.family: Appearance.fontFamily.mono
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1
        }

        // ------------------------------------------------------------- toast
        Slash {
            id: toast

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: view.cardH / 2 + 40
            width: 380
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

                NumberAnimation { target: toast; property: "opacity"; to: 1; duration: Appearance.anim.fast }
                PauseAnimation { duration: 1000 }
                NumberAnimation { target: toast; property: "opacity"; to: 0; duration: Appearance.anim.normal }
            }
        }
    }

    function flash(message: string): void {
        toastText.text = message;
        toastAnim.restart();
    }

    // The apply pulse — the card in hand flexes the moment you commit.
    SequentialAnimation {
        id: applyFlash

        property real flash: 0

        NumberAnimation { target: applyFlash; property: "flash"; to: 1; duration: 160 }
        NumberAnimation { target: applyFlash; property: "flash"; to: 0; duration: 360; easing.type: Easing.OutQuad }
    }

    // The end-of-row bump — reaching the edge nudges the whole row back.
    property real bumpY: 0

    SequentialAnimation {
        id: endBump

        NumberAnimation { target: root; property: "bumpY"; to: 12; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "bumpY"; to: 0; duration: 280; easing.type: Easing.OutBack }
    }

    // ------------------------------------------------------------- keyboard
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
            root.applyCurrent();
            event.accepted = true;
            return;
        case Qt.Key_R:
            root.scan();
            Sfx.cursor();
            event.accepted = true;
            return;
        }
    }
}
