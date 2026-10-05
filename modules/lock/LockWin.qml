//  VELVET  ·  modules/lock/LockWin.qml
//  The lock of the WINDOWS look, as the logon screen of the edition you chose:
//  95's grey password box on the teal desktop, XP's blue welcome screen with the
//  green arrow, 7's glass avatar and white field, 10's big clock and flat box,
//  11's centred circle and rounded field. Same input underneath; only the
//  drawing is theirs. (Written from memory of how they looked, not from any
//  Microsoft artwork.)
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var kit: null

    readonly property real u: Math.max(0.55, Math.min(root.width / 1920, root.height / 1080))
    readonly property string face: Appearance.fontFamily.win

    Loader {
        anchors.fill: parent
        sourceComponent: ({
                "95": e95,
                "xp": eXp,
                "7": e7,
                "10": e10,
                "11": e11
            })[Appearance.winVer] ?? e11
    }

    // the picture of the user, in a frame of the edition's shape
    component Pic: Item {
        id: pic

        property real radius: width / 2
        property color back: Qt.rgba(1, 1, 1, 0.25)
        property color ink: "#ffffff"

        Rectangle {
            anchors.fill: parent
            radius: pic.radius
            color: pic.back
        }
        Image {
            id: img

            anchors.fill: parent
            source: root.kit.hasFace ? root.kit.faceUrl : ""
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
        }
        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: img
            visible: root.kit.hasFace && img.status === Image.Ready
            live: false
        }
        P5Text {
            anchors.centerIn: parent
            visible: !(root.kit.hasFace && img.status === Image.Ready)
            text: (root.kit.user.charAt(0) || "?").toUpperCase()
            color: pic.ink
            font.pixelSize: pic.width * 0.46
            font.weight: Font.Light
        }
    }

    // a field's dots or asterisks
    component Dots: Row {
        id: dots

        property color ink: "#000000"
        property real size: 8
        property string glyph: "dot"

        spacing: glyph === "star" ? 1 : size * 0.6

        // LOCK SCREEN → TYPING: stars, a bar, a count or nothing replace the
        // edition's own dots
        PassMask {
            anchors.verticalCenter: parent.verticalCenter
            centered: false
            kit: root.kit
            colour: dots.ink
            track: Qt.rgba(dots.ink.r, dots.ink.g, dots.ink.b, 0.2)
            size: dots.size * 1.5
            family: root.face
        }
        Repeater {
            model: 24

            Item {
                required property int index

                visible: index < root.kit.length && root.kit.mask === "dots"
                width: glyph === "star" ? size * 1.1 : size
                height: size * 1.4

                Rectangle {
                    visible: glyph === "dot"
                    anchors.centerIn: parent
                    width: size
                    height: size
                    radius: size / 2
                    color: ink
                }
                P5Text {
                    visible: glyph === "star"
                    anchors.centerIn: parent
                    text: "*"
                    color: ink
                    font.family: Appearance.fontFamily.mono
                    font.pixelSize: size * 1.7
                    font.weight: Font.Bold
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ 95
    Component {
        id: e95

        Item {
            Rectangle {
                anchors.fill: parent
                color: "#008080"
            }

            Item {
                id: dlg

                anchors.centerIn: parent
                width: 440 * root.u * 1.1
                height: 238 * root.u * 1.1
                transform: Translate { x: root.kit.shake }

                // the shadow, then the box
                Rectangle { x: 4; y: 4; width: parent.width; height: parent.height; color: "#000000"; opacity: 0.35 }
                WinBox {
                    anchors.fill: parent
                    kind: "panel"
                }
                // the title bar
                Rectangle {
                    x: 4
                    y: 4
                    width: parent.width - 8
                    height: 22 * root.u * 1.1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0.0; color: "#000080" }
                        GradientStop { position: 1.0; color: "#1084d0" }
                    }

                    P5Text {
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Welcome to Windows"
                        color: "#ffffff"
                        font.family: root.face
                        font.pixelSize: 13 * root.u * 1.1
                        font.weight: Font.Bold
                    }
                }

                WinLogo {
                    x: 20
                    y: 52 * root.u * 1.1
                    width: 44 * root.u * 1.1
                    height: width
                }
                P5Text {
                    x: 84 * root.u * 1.1
                    y: 50 * root.u * 1.1
                    width: parent.width - 100 * root.u * 1.1
                    wrapMode: Text.WordWrap
                    text: "Type a user name and password to log on to Windows."
                    color: "#000000"
                    font.family: root.face
                    font.pixelSize: 13 * root.u * 1.1
                }
                P5Text {
                    x: 84 * root.u * 1.1
                    y: 98 * root.u * 1.1
                    text: "User name:"
                    color: "#000000"
                    font.family: root.face
                    font.pixelSize: 13 * root.u * 1.1
                }
                WinBox {
                    x: 170 * root.u * 1.1
                    y: 92 * root.u * 1.1
                    width: 200 * root.u * 1.1
                    height: 24 * root.u * 1.1
                    kind: "field"

                    P5Text {
                        x: 5
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.kit.user
                        color: "#000000"
                        font.family: root.face
                        font.pixelSize: 13 * root.u * 1.1
                    }
                }
                P5Text {
                    x: 84 * root.u * 1.1
                    y: 132 * root.u * 1.1
                    text: "Password:"
                    color: "#000000"
                    font.family: root.face
                    font.pixelSize: 13 * root.u * 1.1
                }
                WinBox {
                    x: 170 * root.u * 1.1
                    y: 126 * root.u * 1.1
                    width: 200 * root.u * 1.1
                    height: 24 * root.u * 1.1
                    kind: "field"

                    Dots {
                        x: 5
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "star"
                        size: 8 * root.u * 1.1
                    }
                    Rectangle {
                        visible: !root.kit.busy && root.kit.mask === "dots"
                        x: 6 + root.kit.length * 9 * root.u * 1.1
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: parent.height - 8
                        color: "#000000"

                        SequentialAnimation on opacity {
                            running: true
                            loops: Animation.Infinite
                            NumberAnimation { to: 0; duration: 500 }
                            NumberAnimation { to: 1; duration: 500 }
                        }
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: parent.height - 52 * root.u * 1.1
                    spacing: 10

                    WinBox {
                        width: 84 * root.u * 1.1
                        height: 26 * root.u * 1.1
                        kind: "button"
                        primary: true
                        pressed: root.kit.busy

                        P5Text {
                            anchors.centerIn: parent
                            text: "OK"
                            color: "#000000"
                            font.family: root.face
                            font.pixelSize: 13 * root.u * 1.1
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.kit.submit()
                        }
                    }
                    WinBox {
                        width: 84 * root.u * 1.1
                        height: 26 * root.u * 1.1
                        kind: "button"

                        P5Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: "#000000"
                            font.family: root.face
                            font.pixelSize: 13 * root.u * 1.1
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.kit.clear()
                        }
                    }
                }
            }

            // the verdict, as a message box on top
            Item {
                visible: root.kit.failed
                anchors.centerIn: parent
                width: 360 * root.u * 1.1
                height: 130 * root.u * 1.1
                anchors.verticalCenterOffset: 50 * root.u

                Rectangle { x: 4; y: 4; width: parent.width; height: parent.height; color: "#000000"; opacity: 0.35 }
                WinBox { anchors.fill: parent; kind: "panel" }
                Rectangle {
                    x: 4
                    y: 4
                    width: parent.width - 8
                    height: 20 * root.u * 1.1
                    color: "#000080"

                    P5Text {
                        x: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Logon Message"
                        color: "#ffffff"
                        font.family: root.face
                        font.pixelSize: 12 * root.u * 1.1
                        font.weight: Font.Bold
                    }
                }
                P5Text {
                    x: 20
                    y: 40 * root.u * 1.1
                    width: parent.width - 40
                    wrapMode: Text.WordWrap
                    text: root.kit.message && root.kit.message.indexOf("WRONG PASSWORD") < 0 ? root.kit.message : "The password you typed is incorrect. Please try again."
                    color: "#000000"
                    font.family: root.face
                    font.pixelSize: 13 * root.u * 1.1
                }
                WinBox {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height - 38 * root.u * 1.1
                    width: 80 * root.u * 1.1
                    height: 24 * root.u * 1.1
                    kind: "button"
                    primary: true

                    P5Text {
                        anchors.centerIn: parent
                        text: "OK"
                        color: "#000000"
                        font.family: root.face
                        font.pixelSize: 13 * root.u * 1.1
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ XP
    Component {
        id: eXp

        Item {
            Rectangle {
                anchors.fill: parent
                color: "#5a7edc"
            }
            // top and bottom bands
            Rectangle {
                width: parent.width
                height: parent.height * 0.1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00309c" }
                    GradientStop { position: 1.0; color: "#00309c" }
                }

                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 3 * root.u; color: "#f4a73c" }
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * 0.11
                color: "#00309c"

                Rectangle { width: parent.width; height: 3 * root.u; color: "#f4a73c" }
                P5Text {
                    anchors.right: parent.right
                    anchors.rightMargin: root.width * 0.06
                    anchors.verticalCenter: parent.verticalCenter
                    text: "After you log on, you can add or change accounts.\nJust go to Control Panel and click User Accounts."
                    color: "#ffffff"
                    font.family: root.face
                    font.pixelSize: 15 * root.u
                    horizontalAlignment: Text.AlignRight
                }
            }

            // left: the name of the system
            Item {
                x: root.width * 0.1
                anchors.verticalCenter: parent.verticalCenter
                width: root.width * 0.34
                height: 200 * root.u

                WinLogo {
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120 * root.u
                    height: width
                }
                Column {
                    x: 140 * root.u
                    anchors.verticalCenter: parent.verticalCenter

                    P5Text {
                        text: "Microsoft"
                        color: "#ffffff"
                        font.family: root.face
                        font.pixelSize: 24 * root.u
                    }
                    Row {
                        spacing: 8 * root.u

                        P5Text {
                            text: "Windows"
                            color: "#ffffff"
                            font.family: root.face
                            font.pixelSize: 58 * root.u
                            font.weight: Font.Bold
                            font.italic: true
                        }
                        P5Text {
                            y: 4 * root.u
                            text: "xp"
                            color: "#ff8a1f"
                            font.family: root.face
                            font.pixelSize: 36 * root.u
                            font.weight: Font.Bold
                            font.italic: true
                        }
                    }
                }
            }
            // the divider
            Rectangle {
                x: root.width * 0.5
                y: root.height * 0.18
                width: 2 * root.u
                height: root.height * 0.64
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: "#ffffff" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // right: the user
            Item {
                x: root.width * 0.54
                anchors.verticalCenter: parent.verticalCenter
                width: root.width * 0.38
                height: 200 * root.u
                transform: Translate { x: root.kit.shake }

                Pic {
                    id: xpPic

                    x: 0
                    y: 0
                    width: 90 * root.u
                    height: width
                    radius: 6
                    back: "#d7e4fb"
                    ink: "#3a68d4"

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: "transparent"
                        border.width: 3 * root.u
                        border.color: "#ffffff"
                    }
                }
                Column {
                    x: 112 * root.u
                    y: 2 * root.u
                    spacing: 8 * root.u

                    P5Text {
                        visible: root.kit.showUser
                        text: root.kit.name
                        color: "#ffffff"
                        font.family: root.face
                        font.pixelSize: 32 * root.u
                        font.weight: Font.Bold
                    }
                    P5Text {
                        text: "Type your password"
                        color: "#ffffff"
                        font.family: root.face
                        font.pixelSize: 16 * root.u
                    }
                    Row {
                        spacing: 8 * root.u

                        Rectangle {
                            width: 280 * root.u
                            height: 34 * root.u
                            radius: 4
                            color: "#ffffff"
                            border.width: 1
                            border.color: root.kit.failed ? "#cc2200" : "#7f9db9"

                            Dots {
                                x: 8 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                glyph: "dot"
                                size: 9 * root.u
                            }
                            Rectangle {
                                visible: !root.kit.busy && root.kit.mask === "dots"
                                x: 9 * root.u + root.kit.length * 14.4 * root.u
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1
                                height: parent.height - 10
                                color: "#000000"

                                SequentialAnimation on opacity {
                                    running: true
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0; duration: 500 }
                                    NumberAnimation { to: 1; duration: 500 }
                                }
                            }
                        }
                        // the green arrow
                        Rectangle {
                            width: 34 * root.u
                            height: width
                            radius: 6
                            border.width: 2
                            border.color: "#ffffff"
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#5fd05a" }
                                GradientStop { position: 1.0; color: "#2a9a2a" }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: "arrow_forward"
                                color: "#ffffff"
                                font.pixelSize: 22 * root.u
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.kit.submit()
                            }
                        }
                    }
                    P5Text {
                        text: root.kit.busy ? "Logging on…" : "To begin, type your password and press Enter."
                        color: "#d7e4fb"
                        font.family: root.face
                        font.pixelSize: 14 * root.u
                    }
                }

                // the balloon
                Rectangle {
                    visible: root.kit.failed
                    x: 112 * root.u
                    y: 150 * root.u
                    width: 330 * root.u
                    height: 44 * root.u
                    radius: 6
                    color: "#ffffe1"
                    border.width: 1
                    border.color: "#000000"

                    P5Text {
                        anchors.centerIn: parent
                        text: "The password is incorrect. Please try again."
                        color: "#000000"
                        font.family: root.face
                        font.pixelSize: 14 * root.u
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ 7
    Component {
        id: e7

        Item {
            // the aero blue, under the wallpaper when there is one
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#2f7bc0" }
                    GradientStop { position: 0.6; color: "#144f8e" }
                    GradientStop { position: 1.0; color: "#0b2f5c" }
                }
            }
            LockWall {
                anchors.fill: parent
                ground: "#144f8e"
                blur: 0.5
                dim: 0.1
            }
            // a glass sheet behind the person
            Rectangle {
                anchors.centerIn: parent
                width: 520 * root.u
                height: 480 * root.u
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.45)
            }

            Column {
                anchors.centerIn: parent
                spacing: 16 * root.u
                transform: Translate { x: root.kit.shake }

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 152 * root.u
                    height: width

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Qt.rgba(1, 1, 1, 0.55)
                        border.width: 1
                        border.color: "#ffffff"
                    }
                    Pic {
                        anchors.fill: parent
                        anchors.margins: 5 * root.u
                        radius: 4
                        back: "#6aa6e6"
                        ink: "#ffffff"
                    }
                }
                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.kit.showUser
                    text: root.kit.name
                    color: "#ffffff"
                    font.family: root.face
                    font.pixelSize: 30 * root.u
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6 * root.u

                    Rectangle {
                        width: 300 * root.u
                        height: 32 * root.u
                        radius: 3
                        color: "#ffffff"
                        border.width: 1
                        border.color: root.kit.failed ? "#cc2200" : "#6b8db5"

                        P5Text {
                            x: 8 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.kit.length === 0
                            text: root.kit.busy ? "Welcome" : (root.kit.hello !== "" ? root.kit.hello : "Password")
                            color: "#8a8a8a"
                            font.family: root.face
                            font.pixelSize: 17 * root.u
                        }
                        Dots {
                            x: 8 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "dot"
                            size: 8 * root.u
                        }
                    }
                    Rectangle {
                        width: 32 * root.u
                        height: width
                        radius: 3
                        border.width: 1
                        border.color: "#ffffff"
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#6db3f0" }
                            GradientStop { position: 0.5; color: "#2f7bc0" }
                            GradientStop { position: 0.51; color: "#1e63ab" }
                            GradientStop { position: 1.0; color: "#3b8fd8" }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: "arrow_forward"
                            color: "#ffffff"
                            font.pixelSize: 20 * root.u
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.kit.submit()
                        }
                    }
                }
                Rectangle {
                    visible: root.kit.failed
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 340 * root.u
                    height: 40 * root.u
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.9)
                    border.width: 1
                    border.color: "#cc2200"

                    P5Text {
                        anchors.centerIn: parent
                        text: "The password is incorrect. Try again."
                        color: "#222222"
                        font.family: root.face
                        font.pixelSize: 15 * root.u
                    }
                }
            }
            // the shut down button
            Rectangle {
                x: 40 * root.u
                y: root.height - 80 * root.u
                width: 150 * root.u
                height: 36 * root.u
                radius: 4
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.7)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.35) }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.12) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.22) }
                }

                P5Text {
                    anchors.centerIn: parent
                    text: root.kit.clockPadded + "  ·  " + root.kit.date(root.kit.stamp("ddd d MMM"))
                    color: "#ffffff"
                    font.family: root.face
                    font.pixelSize: 15 * root.u
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ 10
    Component {
        id: e10

        Item {
            Rectangle {
                anchors.fill: parent
                color: "#10243b"
            }
            LockWall {
                anchors.fill: parent
                ground: "#10243b"
                blur: root.kit.blurOr(1)
                dim: root.kit.dimOr(0.45)
            }

            // the time, low on the left
            Column {
                x: 70 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 70 * root.u
                spacing: 0

                FitClock {
                    text: root.kit.clockText
                    color: root.kit.tint("#ffffff")
                    font.family: root.kit.typeface(root.face)
                    want: 150 * root.u * Math.min(root.kit.clockScale, 1.3)
                    maxWidth: root.width * 0.86
                    font.weight: Font.Light
                }
                P5Text {
                    visible: text !== ""
                    text: root.kit.date(root.kit.stamp("dddd, MMMM d"))
                    color: "#ffffff"
                    font.family: root.face
                    font.pixelSize: 44 * root.u
                    font.weight: Font.Light
                }
            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 40 * root.u
                spacing: 20 * root.u
                transform: Translate { x: root.kit.shake }

                Pic {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 200 * root.u
                    height: width
                    back: Qt.rgba(1, 1, 1, 0.25)
                }
                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.kit.showUser
                    text: root.kit.name
                    color: "#ffffff"
                    font.family: root.face
                    font.pixelSize: 36 * root.u
                    font.weight: Font.Light
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter

                    Rectangle {
                        width: 300 * root.u
                        height: 40 * root.u
                        color: "#ffffff"
                        border.width: 2
                        border.color: root.kit.failed ? "#e81123" : (root.kit.length > 0 ? Colours.accent : "#999999")

                        P5Text {
                            x: 10 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.kit.length === 0
                            text: root.kit.busy ? "Welcome" : (root.kit.hello !== "" ? root.kit.hello : "Password")
                            color: "#666666"
                            font.family: root.face
                            font.pixelSize: 18 * root.u
                        }
                        Dots {
                            x: 10 * root.u
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "dot"
                            size: 8 * root.u
                        }
                    }
                    Rectangle {
                        width: 40 * root.u
                        height: width
                        color: Colours.accent

                        Icon {
                            anchors.centerIn: parent
                            name: "arrow_forward"
                            color: Colours.on(Colours.accent)
                            font.pixelSize: 24 * root.u
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.kit.submit()
                        }
                    }
                }
                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.kit.failed || root.kit.hints
                    text: root.kit.failed ? "The password is incorrect. Make sure you're using the password for your account." : "Sign-in options"
                    width: 340 * root.u
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: "#ffffff"
                    font.family: root.face
                    font.pixelSize: 15 * root.u
                }
            }
            P5Text {
                anchors.right: parent.right
                anchors.rightMargin: 56 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 50 * root.u
                visible: root.kit.showInfo
                text: `${Net.label || "Offline"}${Battery.available ? "   ·   " + Battery.percent + "%" : ""}`
                color: "#ffffff"
                font.family: root.face
                font.pixelSize: 17 * root.u
            }
            LockExtras {
                anchors.right: parent.right
                anchors.rightMargin: 56 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 84 * root.u
                width: root.width * 0.4
                kit: root.kit
                info: false
                colour: "#ffffff"
                family: root.face
                size: 17 * root.u
                align: Text.AlignRight
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ 11
    Component {
        id: e11

        Item {
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#c5d2ea" }
                    GradientStop { position: 1.0; color: "#7f95c4" }
                }
            }
            LockWall {
                anchors.fill: parent
                ground: "#7f95c4"
                blur: root.kit.blurOr(1)
                dim: root.kit.dimOr(0.18)
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.height * 0.1
                spacing: 4 * root.u

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: text !== ""
                    text: root.kit.date(root.kit.stamp("dddd, MMMM d"))
                    color: "#ffffff"
                    font.family: root.face
                    font.pixelSize: 26 * root.u
                    font.weight: Font.DemiBold
                }
                FitClock {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.kit.clockText
                    color: root.kit.tint("#ffffff")
                    font.family: root.kit.typeface(root.face)
                    want: 150 * root.u * Math.min(root.kit.clockScale, 1.3)
                    maxWidth: root.width * 0.86
                    font.weight: Font.DemiBold
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.height * 0.52
                spacing: 18 * root.u
                transform: Translate { x: root.kit.shake }

                Pic {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 136 * root.u
                    height: width
                    back: Qt.rgba(1, 1, 1, 0.35)
                    ink: "#ffffff"
                }
                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.kit.showUser
                    text: root.kit.name
                    color: "#ffffff"
                    font.family: root.face
                    font.pixelSize: 28 * root.u
                    font.weight: Font.DemiBold
                }
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 330 * root.u
                    height: 46 * root.u

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Qt.rgba(1, 1, 1, 0.78)
                        border.width: 1
                        border.color: root.kit.failed ? "#c42b1c" : Qt.rgba(0, 0, 0, 0.12)
                    }
                    // the accent line under a field that has focus
                    Rectangle {
                        anchors.bottom: parent.bottom
                        x: 4
                        width: parent.width - 8
                        height: 2.5
                        radius: 1
                        color: root.kit.failed ? "#c42b1c" : Colours.accent
                    }
                    P5Text {
                        x: 14 * root.u
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.kit.length === 0
                        text: root.kit.busy ? "Welcome" : (root.kit.hello !== "" ? root.kit.hello : "Password")
                        color: Qt.rgba(0, 0, 0, 0.55)
                        font.family: root.face
                        font.pixelSize: 18 * root.u
                    }
                    Dots {
                        x: 14 * root.u
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "dot"
                        size: 9 * root.u
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 6 * root.u
                        anchors.verticalCenter: parent.verticalCenter
                        width: 34 * root.u
                        height: width
                        radius: 5
                        color: Colours.accent
                        opacity: root.kit.length > 0 ? 1 : 0.0

                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Icon {
                            anchors.centerIn: parent
                            name: "arrow_forward"
                            color: Colours.on(Colours.accent)
                            font.pixelSize: 20 * root.u
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.kit.submit()
                        }
                    }
                }
                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.kit.failed || root.kit.hints
                    text: root.kit.failed ? "That password is incorrect. Try again." : "Sign-in options"
                    color: "#ffffff"
                    font.family: root.face
                    font.pixelSize: 16 * root.u
                }
            }
            P5Text {
                anchors.right: parent.right
                anchors.rightMargin: 56 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 44 * root.u
                visible: root.kit.showInfo
                text: `${Net.label || "Offline"}${Battery.available ? "   ·   " + Battery.percent + "%" : ""}`
                color: "#ffffff"
                font.family: root.face
                font.pixelSize: 17 * root.u
            }
            LockExtras {
                anchors.right: parent.right
                anchors.rightMargin: 56 * root.u
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 84 * root.u
                width: root.width * 0.4
                kit: root.kit
                info: false
                colour: "#ffffff"
                family: root.face
                size: 17 * root.u
                align: Text.AlignRight
            }
        }
    }
}
