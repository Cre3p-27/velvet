//  VELVET  ·  modules/settings/SettingsList.qml
//  The right-hand pane. Purely a view — Settings.qml owns every piece of state
//  it reads, including which sub-pages are open.
//
//  Rows arrive for one level at a time: the category, or the page you
//  opened — a page is a SUB-TAB of its own. The header walks back up (BACK,
//  or click any step of the breadcrumb), a banner on top says which page you
//  are in and what it is for, and the strip at the bottom explains the row
//  under the pointer (or, from the keyboard, under the cursor) in whole
//  sentences.
//
//  The pointer and the cursor are two things. Hovering lights a row up and
//  nothing else; the cursor moves by keyboard or by a click. So the wheel
//  scrolls the list and only the list — the rows passing under a resting
//  pointer no longer drag the cursor along (which used to make the list
//  scroll back against you and click-click the whole way down).
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    // [{ item, depth, path, open, count }]
    required property var rows
    required property int currentIndex
    required property bool focused
    required property string breadcrumb
    required property bool nested
    // The levels of the breadcrumb ([category, page, page …]), the page you
    // are in (null at the category's top) and which way the last step went.
    property var crumbs: []
    property var pageItem: null
    property int pageDir: 1
    // The row whose fold is open (a slider or a choice), -1 for none.
    property int openIndex: -1
    // The dangerous action waiting for its second click, -1 for none.
    property int armedIndex: -1

    // A click on a row.
    signal picked(int index)
    // A control inside a row was used: that row becomes the cursor.
    signal touched(int index)
    signal back
    signal crumb(int level)

    readonly property var currentItem: root.rows[root.currentIndex]?.item ?? null

    // CLEAN and WINDOWS head the list with a plain page title, not the big
    // tracked caps of the other skins.
    readonly property bool plainHead: Appearance.skin === "clean" || Appearance.skin === "win"
    readonly property string wv: Appearance.winVer
    readonly property bool win: Appearance.skin === "win"
    readonly property int headTitlePx: root.win ? ({ "95": 12, "xp": 13, "7": 17, "10": 28, "11": 26 })[root.wv] ?? 20 : 22
    readonly property int headCrumbPx: root.win ? ({ "95": 12, "xp": 12, "7": 13, "10": 16, "11": 15 })[root.wv] ?? 13 : 14
    readonly property int headH: root.win ? ({ "95": 30, "xp": 32, "7": 44, "10": 62, "11": 60 })[root.wv] ?? 50 : 56
    readonly property int headWeight: !root.win ? Font.DemiBold : ({ "95": Font.Bold, "xp": Font.Bold, "7": Font.Normal, "10": Font.Light, "11": Font.DemiBold })[root.wv] ?? Font.DemiBold
    readonly property var plainCrumbs: {
        const c = root.crumbs.length > 0 ? root.crumbs : [root.breadcrumb];
        const out = c.map((t, i) => ({
                    t: t,
                    level: i
                }));
        return out.length > 3 ? [out[0], {
                t: "…",
                level: out.length - 3
            }].concat(out.slice(-2)) : out;
    }
    readonly property color headInk: root.win && root.wv === "7" ? "#1e395b" : (root.win ? WinTheme.text : Colours.ink)

    // ── the pointer
    property int hoverIndex: -1
    // Which hand moved last: the help strip follows it.
    property bool mouseLast: false
    // When the list last scrolled. Rows sliding under a resting pointer
    // report a hover too; for a moment after a scroll those are not real.
    property real lastScroll: 0

    function hoverRow(i: int): void {
        if (Date.now() - root.lastScroll < 260)
            return;
        root.hoverIndex = i;
        root.mouseLast = true;
    }

    function unhoverRow(i: int): void {
        if (root.hoverIndex === i)
            root.hoverIndex = -1;
    }

    readonly property var helpItem: root.mouseLast && root.hoverIndex >= 0 ? (root.rows[root.hoverIndex]?.item ?? null) : root.currentItem

    // -------------------------------------------------------------- header
    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // The skins already say which category you are in; their list only
        // needs the way back when a page is open.
        height: root.plainHead ? root.headH : (Appearance.skinned ? (root.nested || Appearance.skin !== "poster" ? 44 : 0) : 56)
        visible: height > 0

        // Never wider than the list: a long trail used to run into the lock
        // preview beside it.
        clip: true

        // the plain page title of CLEAN and WINDOWS: a back arrow, the trail
        Row {
            visible: root.plainHead
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Item {
                id: plainBack

                anchors.verticalCenter: parent.verticalCenter
                visible: root.nested
                width: visible ? (root.win && (root.wv === "95" || root.wv === "xp" || root.wv === "7") ? 64 : 34) : 0
                height: root.win && (root.wv === "95" || root.wv === "xp" || root.wv === "7") ? 22 : 34

                WinBox {
                    anchors.fill: parent
                    visible: root.win && (root.wv === "95" || root.wv === "xp" || root.wv === "7")
                    hot: plainBackArea.containsMouse
                    pressed: plainBackArea.pressed

                    P5Text {
                        anchors.centerIn: parent
                        text: "← " + Appearance.tcase("BACK")
                        color: WinTheme.text
                        font.pixelSize: 11
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: !(root.win && (root.wv === "95" || root.wv === "xp" || root.wv === "7"))
                    radius: Appearance.pill(height)
                    color: plainBackArea.containsMouse ? Colours.alpha(root.win ? WinTheme.text : Colours.ink, 0.1) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "arrow_back"
                        color: root.win ? WinTheme.text : Colours.ink
                        font.pixelSize: 18
                    }
                }
                MouseArea {
                    id: plainBackArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Repeater {
                model: root.plainCrumbs

                Row {
                    id: pstep

                    required property var modelData
                    required property int index
                    readonly property bool last: pstep.index === root.plainCrumbs.length - 1

                    spacing: 10

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Appearance.tcase(pstep.modelData.t)
                        color: pstep.last ? root.headInk : (pstepArea.containsMouse ? Colours.accent : (root.win ? WinTheme.dim : Colours.inkDim))
                        font.pixelSize: pstep.last ? root.headTitlePx : root.headCrumbPx
                        font.weight: pstep.last ? root.headWeight : Font.Normal

                        MouseArea {
                            id: pstepArea

                            anchors.fill: parent
                            anchors.margins: -6
                            enabled: !pstep.last && root.crumbs.length > 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.crumb(pstep.modelData.level)
                        }
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !pstep.last
                        text: "›"
                        color: root.win ? WinTheme.dim : Colours.inkDim
                        font.pixelSize: root.headCrumbPx + 2
                    }
                }
            }
        }

        Row {
            visible: !root.plainHead
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Slash {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.nested
                width: 120
                height: 38
                shear: Appearance.skew
                color: backArea.containsMouse ? Colours.accent : "transparent"
                borderColor: Colours.alpha(Colours.ink, 0.55)
                borderWidth: 2

                Row {
                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "arrow_back"
                        color: backArea.containsMouse ? Colours.on(Colours.accent) : Colours.ink
                        font.pixelSize: Appearance.font.size.normal
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: "BACK"
                        color: backArea.containsMouse ? Colours.on(Colours.accent) : Colours.ink
                        font.pixelSize: Appearance.font.size.small
                    }
                }

                MouseArea {
                    id: backArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            // The breadcrumb: every level is a step you can click back to;
            // the last one is where you are.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                visible: root.crumbs.length > 0

                // A deep trail keeps its first and last two steps; the middle
                // folds into "…" (a click on it goes one level up).
                Repeater {
                    model: {
                        const c = root.crumbs;
                        const out = c.map((t, i) => ({
                                    t: t,
                                    level: i
                                }));
                        return out.length > 4 ? [out[0], {
                                t: "…",
                                level: out.length - 3
                            }].concat(out.slice(-2)) : out;
                    }

                    Row {
                        id: step

                        required property var modelData
                        required property int index
                        readonly property bool last: step.modelData.level === root.crumbs.length - 1

                        spacing: 10

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            display: true
                            text: step.modelData.t
                            color: step.last ? Colours.ink : (stepArea.containsMouse ? Colours.accent : Colours.alpha(Colours.ink, 0.55))
                            // The steps above you are smaller than where you are.
                            font.pixelSize: step.last ? Math.round(Appearance.row.title * (root.width < 900 ? 0.8 : 1)) : Math.round(Appearance.row.title * 0.62)
                            tracking: 2

                            MouseArea {
                                id: stepArea

                                anchors.fill: parent
                                anchors.margins: -6
                                enabled: !step.last
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.crumb(step.modelData.level)
                            }
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !step.last
                            display: true
                            text: "›"
                            color: Colours.alpha(Colours.accent, 0.8)
                            font.pixelSize: Math.round(Appearance.row.title * 0.62)
                        }
                    }
                }
            }

            // No levels (the rooms' own lists): the plain breadcrumb.
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.crumbs.length === 0
                display: true
                text: root.breadcrumb
                color: Colours.ink
                font.pixelSize: Appearance.row.title
                tracking: 2
                width: root.width - (root.nested ? 150 : 0) - 20
                elide: Text.ElideLeft
            }
        }

        Rectangle {
            visible: !Appearance.skinned
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: parent.width * 0.5
            height: 2
            color: Colours.alpha(Colours.accent, 0.5)
        }
    }

    // ---------------------------------------------------------------- list
    //  The rows are kept in a model of their own and CHANGED, not replaced:
    //  opening a page inserts its children right under it and closing one
    //  takes them out. Replacing the whole array rebuilt every row and threw
    //  the list back to the top — you lost your place every time you opened
    //  a sub-page (MODULES → TASKBAR). A new category still starts at the top.
    ListModel {
        id: rowModel
    }

    function keysOf(rows: var): var {
        const seen = {};
        const out = [];
        for (let i = 0; i < rows.length; i++) {
            const p = rows[i]?.path ?? `#${i}`;
            seen[p] = (seen[p] ?? 0) + 1;
            out.push(`${p}#${seen[p]}`);
        }
        return out;
    }

    function sync(): void {
        const next = root.keysOf(root.rows);
        const old = [];
        for (let i = 0; i < rowModel.count; i++)
            old.push(rowModel.get(i).key);
        let a = 0;
        while (a < old.length && a < next.length && old[a] === next[a])
            a++;
        let b = 0;
        while (b < old.length - a && b < next.length - a && old[old.length - 1 - b] === next[next.length - 1 - b])
            b++;
        const fresh = a === 0 && old.length > 0;
        if (old.length - a - b > 0)
            rowModel.remove(a, old.length - a - b);
        for (let i = a; i < next.length - b; i++)
            rowModel.insert(i, {
                key: next[i]
            });
        if (fresh) {
            list.positionViewAtBeginning();
            Qt.callLater(root.reveal);
        }
    }

    onRowsChanged: {
        root.hoverIndex = -1;
        root.sync();
    }
    Component.onCompleted: root.sync()

    // The cursor can land on a row that is out of view — an arrow key, BACK
    // onto the page you came from, a search jump, a deep link. Bring it into
    // view once the rows have settled. (Only the cursor does this; the
    // pointer never scrolls the list.)
    onCurrentIndexChanged: {
        root.mouseLast = false;
        Qt.callLater(root.reveal);
    }
    // An opened fold may reach below the view.
    onOpenIndexChanged: revealLater.restart()

    Timer {
        id: revealLater

        interval: Appearance.anim.normal + 20
        onTriggered: root.reveal()
    }

    function reveal(): void {
        if (root.currentIndex < 0 || root.currentIndex >= list.count)
            return;
        const it = list.itemAtIndex(root.currentIndex);
        if (!it) {
            list.positionViewAtIndex(root.currentIndex, ListView.Contain);
            return;
        }
        // Scroll only as far as needed, with a little air, and glide there.
        const air = Appearance.row.gap * 2;
        const top = it.y - air;
        const bottom = it.y + it.height + air - list.height;
        let to = list.contentY;
        if (top < list.contentY)
            to = top;
        else if (bottom > list.contentY)
            to = Math.min(bottom, top);
        to = Math.max(list.originY, Math.min(to, list.originY + Math.max(0, list.contentHeight - list.height)));
        if (Math.abs(to - list.contentY) < 1)
            return;
        scroller.glideTo(to);
    }

    // ── the sub-tab's banner: which page this is and what it is for
    Item {
        id: banner

        anchors.top: header.bottom
        anchors.topMargin: root.pageItem ? Appearance.spacing.large : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: 48
        height: root.pageItem ? bannerCol.implicitHeight + 28 : 0
        visible: root.pageItem !== null
        clip: true

        property bool full: false

        Behavior on height {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: banner.full = !banner.full
        }

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.accent, 0.1)
            border.width: 1
            border.color: Colours.alpha(Colours.accent, 0.35)
            antialiasing: true
        }

        Icon {
            id: bannerIcon

            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            name: root.pageItem?.icon ?? "tune"
            color: Colours.accent
            font.pixelSize: Appearance.row.title * 1.4
        }

        Column {
            id: bannerCol

            anchors.left: bannerIcon.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            P5Text {
                width: parent.width
                text: `${root.pageItem?.sub ?? ""}${(root.pageItem?.sub ?? "") !== "" ? "   ·   " : ""}${root.countIn(root.pageItem?.items ?? [])} SETTINGS`
                color: Colours.accentInk
                font.pixelSize: Appearance.row.sub
                tracking: 1.1
                elide: Text.ElideRight
            }
            // Three lines at most; a click on the banner shows the rest.
            Text {
                width: parent.width
                visible: text !== ""
                text: root.pageItem?.help ?? ""
                wrapMode: Text.WordWrap
                maximumLineCount: banner.full ? 40 : 2
                elide: Text.ElideRight
                color: Colours.alpha(Colours.ink, 0.85)
                font.family: Appearance.fontFamily.body
                font.pixelSize: Appearance.row.sub + 2
                lineHeight: 1.15
            }
        }
    }

    function countIn(items: var): int {
        let n = 0;
        for (let i = 0; i < items.length; i++) {
            if (!Schema.shown(items[i]))
                continue;
            if (items[i].kind === "page")
                n += root.countIn(items[i].items ?? []);
            else if (items[i].kind !== "info")
                n++;
        }
        return n;
    }

    // ── a step into a page (or back out) slides the list the way you went
    property real slide: 0

    onPageItemChanged: {
        banner.full = false;
        slideIn.stop();
        root.slide = root.pageDir * 70;
        slideIn.start();
    }

    NumberAnimation {
        id: slideIn

        target: root
        property: "slide"
        to: 0
        duration: Appearance.anim.normal
        easing.type: Easing.OutExpo
    }

    ListView {
        id: list

        anchors.top: banner.bottom
        anchors.topMargin: root.plainHead ? Appearance.spacing.small : Appearance.spacing.large
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: helpStrip.top
        anchors.bottomMargin: Appearance.spacing.normal
        opacity: 1 - Math.min(1, Math.abs(root.slide) / 90)
        transform: Translate {
            x: root.slide
        }

        model: rowModel
        spacing: Appearance.row.gap
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // The view never chases a "current item" of its own — reveal() moves
        // it for the cursor, the wheel and the drag move it for you.
        highlightFollowsCurrentItem: false
        currentIndex: -1
        cacheBuffer: 800

        onContentYChanged: root.lastScroll = Date.now()
        onMovementStarted: root.hoverIndex = -1

        // Staggered fly-in: rows arrive one after another, not as a block.
        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.anim.fast
            }
        }

        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Appearance.anim.normal
                easing.type: Easing.OutExpo
            }
        }

        delegate: SettingRowAny {
            // (SettingRow declares `index` itself — declaring it here again
            // would shadow it and no row could be built.)
            // The row's data by position — rowModel mirrors root.rows
            // entry for entry, it only carries the keys.
            readonly property var row: root.rows[index] ?? null

            width: list.width - 48
            item: row ? row.item : ({})
            expandable: !!row && row.item.kind === "page"
            childCount: row ? row.count : 0
            selected: root.focused && index === root.currentIndex
            hot: index === root.hoverIndex
            open: index === root.openIndex
            armed: index === root.armedIndex

            onHovered: root.hoverRow(index)
            onUnhovered: root.unhoverRow(index)
            onActivate: root.picked(index)
            onTouched: root.touched(index)
        }
    }

    // The wheel (components/SmoothScroll): quick notches add up instead of each
    // starting over, a touchpad follows the fingers. Rows sliding under a
    // resting pointer are not hovered while it moves.
    SmoothScroll {
        id: scroller

        view: list
        step: (Appearance.row.height + Appearance.row.gap) * 1.25
        onScrolled: {
            root.lastScroll = Date.now();
            root.hoverIndex = -1;
        }
    }

    // -------------------------------------------------------------- scrollbar
    Rectangle {
        anchors.right: parent.right
        anchors.top: list.top
        anchors.bottom: list.bottom
        width: root.plainHead ? 4 : 6
        radius: root.plainHead ? 2 : 0
        color: root.plainHead ? "transparent" : Colours.alpha(Colours.ink, 0.1)
        visible: list.contentHeight > list.height

        Rectangle {
            width: parent.width
            radius: root.plainHead ? 2 : 0
            color: root.plainHead ? Colours.alpha(root.win ? WinTheme.text : Colours.ink, 0.28) : Colours.accent
            y: list.visibleArea.yPosition * parent.height
            height: Math.max(30, list.visibleArea.heightRatio * parent.height)

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }
    }

    // ── what the row under the cursor does, in whole sentences
    Item {
        id: helpStrip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.plainHead ? 10 : 0
        readonly property string text: root.helpItem ? ((root.helpItem.help ?? "") !== "" ? root.helpItem.help : "") : ""
        // Three lines, so the list keeps its room; a click shows it all.
        property bool full: false
        onTextChanged: helpStrip.full = false
        height: helpStrip.text !== "" ? Math.max(helpIcon.height, helpText.implicitHeight) + 26 : 0
        visible: height > 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: helpText.truncated || helpStrip.full
            cursorShape: Qt.PointingHandCursor
            onClicked: helpStrip.full = !helpStrip.full
        }

        Plate {
            anchors.fill: parent
            vibe: !root.plainHead
            radius: root.plainHead ? Appearance.r(10) : Appearance.rounding.normal
            color: root.plainHead ? (root.win ? Colours.alpha(WinTheme.text, WinTheme.v === "95" ? 0 : 0.045) : Colours.alpha(Colours.accent, 0.06)) : Colours.alpha(Colours.paper, 0.85)
            border.width: 1
            border.color: root.plainHead ? (root.win ? WinTheme.rule : Colours.alpha(Colours.ink, 0.08)) : Colours.alpha(Colours.ink, 0.14)
            antialiasing: true
        }

        Icon {
            id: helpIcon

            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 14
            name: "info"
            color: root.win ? WinTheme.accent : Colours.accent
            font.pixelSize: root.plainHead ? Appearance.font.size.large : Appearance.font.size.huge
        }

        Text {
            id: helpText

            anchors.left: helpIcon.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.top: parent.top
            anchors.topMargin: 13
            text: helpStrip.text
            wrapMode: Text.WordWrap
            maximumLineCount: helpStrip.full ? 40 : 3
            elide: Text.ElideRight
            color: root.win ? WinTheme.text : Colours.alpha(Colours.ink, 0.9)
            font.family: Appearance.fontFamily.body
            font.pixelSize: root.plainHead ? Appearance.row.sub + 1 : Appearance.row.sub + 2
            lineHeight: 1.15
        }
    }
}
