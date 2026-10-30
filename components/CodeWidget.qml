//  VELVET  ·  components/CodeWidget.qml
//  Runs one CODE WIDGET (services/CodeWidgets.qml): reads its file, turns it
//  into a `render(ctx, f)` (and an optional `click(x, y, f)`), and draws it on
//  a canvas as often as its `// fps:` says. Saved again, it reloads at once.
//  A mistake in the code shows on the widget itself (what went wrong) — the
//  shell around it never notices.
import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    required property string name
    property bool live: true
    // the WIDGET STUDIO's preview: draw this text instead of the file (as you type)
    property string code: ""
    onCodeChanged: {
        if (root.code !== "")
            root.compile(root.code);
    }
    Component.onCompleted: {
        if (root.code !== "")
            root.compile(root.code);
    }

    // what the header says: // name: … · // size: WxH · // fps: N
    property string title: root.name
    property int fps: 30
    implicitWidth: 220
    implicitHeight: 220

    property var render: null
    property var clicked: null
    property string error: ""
    property var store: ({})
    property real t: 0
    property real dt: 0
    property point pointer: Qt.point(-1, -1)

    function compile(code: string): void {
        const head = (re, fall) => {
            const m = code.match(re);
            return m ? m[1].trim() : fall;
        };
        root.title = head(/^\/\/\s*name:\s*(.+)$/m, root.name);
        const sm = code.match(/^\/\/\s*size:\s*(\d+)\s*[x×]\s*(\d+)/m);
        root.implicitWidth = sm ? Math.max(40, Math.min(1200, Number(sm[1]))) : 220;
        root.implicitHeight = sm ? Math.max(40, Math.min(1200, Number(sm[2]))) : 220;
        root.fps = Math.max(1, Math.min(60, Number(head(/^\/\/\s*fps:\s*(\d+)/m, "30")) || 30));
        try {
            const made = new Function(`${code}
return { render: typeof render === "function" ? render : null, click: typeof click === "function" ? click : null };`)();
            root.render = made.render;
            root.clicked = made.click;
            root.error = made.render ? "" : "NO function render(ctx, f) IN THE FILE";
            root.store = ({});
        } catch (e) {
            root.render = null;
            root.error = `${e}`;
        }
        canvas.requestPaint();
    }

    FileView {
        id: file

        path: root.code === "" && root.name !== "" ? CodeWidgets.fileOf(root.name) : ""
        watchChanges: true
        printErrors: false
        onFileChanged: file.reload()
        onLoaded: {
            if (root.code === "")
                root.compile(file.text());
        }
        onLoadFailed: root.error = "THE FILE IS GONE"
    }

    function frame(): var {
        const bands = Spectrum.bands ?? [];
        const m = Lyrics.bridge;
        return {
            w: canvas.width,
            h: canvas.height,
            t: root.t,
            dt: root.dt,
            now: new Date(),
            accent: `${Colours.accent}`,
            ink: `${Colours.ink}`,
            dim: `${Colours.inkDim}`,
            surface: `${Colours.surface}`,
            audio: Array.from(bands),
            level: Spectrum.level ?? 0,
            music: {
                title: m?.title ?? "",
                artist: m?.artist ?? "",
                playing: m?.playing ?? false,
                length: m?.length ?? 0
            },
            cpu: SysInfo.cpuPercent,
            ram: SysInfo.memoryPercent,
            battery: {
                percent: Battery.device ? Battery.percent : -1,
                charging: Battery.charging
            },
            mouse: root.pointer.x >= 0 ? {
                x: root.pointer.x,
                y: root.pointer.y
            } : null,
            store: root.store
        };
    }

    Canvas {
        id: canvas

        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = canvas.getContext("2d");
            ctx.reset();
            if (!root.render)
                return;
            try {
                root.render(ctx, root.frame());
            } catch (e) {
                root.error = `${e}`;
                root.render = null;
            }
        }
    }

    // the clock: as often as it asked for, only while it can be seen
    FrameAnimation {
        running: root.live && root.render !== null && root.visible
        property real since: 0

        onTriggered: {
            root.t += frameTime;
            since += frameTime;
            if (since < 1 / root.fps)
                return;
            root.dt = since;
            since = 0;
            canvas.requestPaint();
        }
    }

    // a mistake: what and where, on the widget itself
    Rectangle {
        visible: root.error !== ""
        anchors.fill: parent
        radius: 14
        color: Colours.alpha(Colours.danger, 0.16)
        border.width: 1
        border.color: Colours.alpha(Colours.danger, 0.6)

        Text {
            anchors.fill: parent
            anchors.margins: 12
            text: `${root.title.toUpperCase()}\n${root.error}`
            color: Colours.ink
            font.pixelSize: 12
            wrapMode: Text.Wrap
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.clicked ? Qt.LeftButton : Qt.NoButton
        onPositionChanged: e => root.pointer = Qt.point(e.x, e.y)
        onExited: root.pointer = Qt.point(-1, -1)
        onClicked: e => {
            try {
                root.clicked(e.x, e.y, root.frame());
            } catch (err) {
                root.error = `${err}`;
            }
            canvas.requestPaint();
        }
    }
}
