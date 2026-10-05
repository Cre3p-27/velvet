#!/usr/bin/env python3
"""
VELVET · tools/qmlcheck.py

A standalone sanity check for the shell. No Qt required — it tokenises every
.qml file itself and then cross-references them, which catches the mistakes
that actually stop a Quickshell config from loading:

  · unbalanced braces / brackets / parens
  · unterminated strings, template literals and block comments
  · `import qs.foo` pointing at a directory that doesn't exist
  · a component used by name that no file, import or inline definition provides
  · a member read off one of our own singletons that the singleton never declares

Run it from the project root:  python3 tools/qmlcheck.py
Exit code is non-zero if anything is wrong.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Types that come from Qt or Quickshell rather than from a file in this repo.
KNOWN_TYPES = set("""
Keys Drag Screen Window Action Shortcut Package Accessible LayoutMirroring
ScreencopyView
RotationAnimation AnchorAnimation PathMultiline PathPolyline Grid
Item Rectangle Text TextInput TextEdit TextMetrics MouseArea Image AnimatedImage BorderImage
Row Column Grid Flow ListView GridView PathView Repeater Loader Component
Timer Connections Behavior State Transition PropertyChanges Binding
NumberAnimation ColorAnimation PropertyAnimation SequentialAnimation
ParallelAnimation PauseAnimation SpringAnimation SmoothedAnimation
AnchorAnimation ScriptAction PropertyAction Animator OpacityAnimator
ScaleAnimator RotationAnimator XAnimator YAnimator
QtObject Instantiator ObjectModel ListModel ListElement DelegateModel
Gradient GradientStop RadialGradient Shape ShapePath PathLine PathPolyline PathMove PathQuad PathArc MultiEffect
PathCubic PathArc PathAttribute PathPercent Path FocusScope Flickable PathAngleArc OpacityMask PathRectangle PathSvg LinearGradient FrameAnimation
ScrollView Canvas Shortcut Translate Rotation Scale Matrix4x4 Transform
RowLayout ColumnLayout GridLayout StackLayout Layout SystemPalette
FontLoader Drag DropArea WheelHandler HoverHandler TapHandler DragHandler
PinchHandler PointHandler MultiPointTouchArea ShaderEffect ShaderEffectSource
LayoutMirroring EnterKey Accessible Keys
WlSessionLock WlSessionLockSurface PamContext
ShellRoot PanelWindow FloatingWindow PopupWindow Variants Scope LazyLoader
Singleton PersistentProperties QuickshellSettings Region ExclusionMode
ColorQuantizer ElapsedTimer SystemClock TransformWatcher ObjectRepeater
ScriptModel DelegateChooser DelegateChoice
Process StdioCollector SplitParser FileView JsonAdapter JsonObject DataStream
IpcHandler Socket SocketServer
WlrLayershell WlSession ToplevelManager Toplevel ScreenCopy
HyprlandWorkspace HyprlandMonitor HyprlandToplevel HyprlandEvent GlobalShortcut
SystemTrayItem QsMenuOpener QsMenuAnchor QsMenuEntry
NotificationServer Notification NotificationAction
PwNode PwNodeAudio PwObjectTracker PwLink PwLinkGroup
UPowerDevice
IconImage WrapperItem WrapperRectangle WrapperMouseArea ClippingRectangle
ClippingWrapperRectangle MarginWrapperManager
ShellScreen DesktopEntry DesktopAction
""".split())

# Singletons that live outside this repo and can expose anything.
EXTERNAL_SINGLETONS = {
    "Quickshell", "Qt", "Hyprland", "Pipewire", "UPower", "SystemTray",
    "DesktopEntries", "ToplevelManager", "Math", "JSON", "Object", "Date",
    "Number", "String", "Array", "Function", "Easing", "Font", "Image",
    "Text", "ListView", "PathView", "GridView", "Flickable", "Animation",
    "WlrLayer", "WlrKeyboardFocus", "FileViewError", "SystemClock",
    "NotificationUrgency", "UPowerDeviceState", "Grid", "GridLayout",
    "Shape", "ShapePath", "Item", "MouseArea", "Component", "Layout",
    "Keys", "SystemTrayItem", "Edges", "QsWindow", "PointerDevice",
    "PamResult", "PamError", "WlSessionLock",
}


# ─────────────────────────────────────────────────────────────── tokenising
def strip_code(src, path, errors):
    """Return src with comments and string bodies blanked, preserving offsets.

    One loop, one state machine. Template literals used to be scanned by a
    little private loop that knew about nested strings but not about regex
    literals — so a `${p.replace(/"/g, ...)}` handed the rest of the FILE to
    the string scanner and every check downstream ran on garbage. Now a `${`
    simply suspends the template and hands control back here, which means the
    expression inside gets the regex rule, the escape rule and nesting for
    free.
    """
    out = []
    i = 0
    n = len(src)
    # Tracks whether a '/' would start a regex (expression position) or divide.
    prev_significant = ""

    # One entry per open template literal. None  = we are in that template's
    # text; an int = that template is suspended inside a ${…} which closes when
    # the brace depth comes back down to this number.
    tpl_stack = []
    tpl_lines = []
    in_tpl = False
    depth = 0

    def line_at(pos):
        return src.count("\n", 0, pos) + 1

    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""

        # ── inside the text of a template literal
        if in_tpl:
            if c == "\\":
                out.append("  ")
                i += 2
                continue
            if c == "`":
                out.append(" ")
                i += 1
                tpl_stack.pop()
                tpl_lines.pop()
                in_tpl = False
                prev_significant = "x"
                continue
            if c == "$" and nxt == "{":
                out.append("  ")
                i += 2
                depth += 1
                tpl_stack[-1] = depth
                in_tpl = False
                prev_significant = "{"
                continue
            out.append("\n" if c == "\n" else " ")
            i += 1
            continue

        # line comment
        if c == "/" and nxt == "/":
            while i < n and src[i] != "\n":
                out.append(" ")
                i += 1
            continue

        # block comment
        if c == "/" and nxt == "*":
            end = src.find("*/", i + 2)
            if end == -1:
                errors.append((path, line_at(i), "unterminated block comment"))
                return "".join(out) + " " * (n - i)
            for ch in src[i:end + 2]:
                out.append("\n" if ch == "\n" else " ")
            i = end + 2
            continue

        # quoted strings
        if c in "\"'":
            quote = c
            out.append(" ")
            i += 1
            closed = False
            while i < n:
                if src[i] == "\\":
                    out.append("  ")
                    i += 2
                    continue
                if src[i] == quote:
                    out.append(" ")
                    i += 1
                    closed = True
                    break
                if src[i] == "\n":
                    break
                out.append(" ")
                i += 1
            if not closed:
                errors.append((path, line_at(i), f"unterminated {quote}-string"))
            prev_significant = "x"
            continue

        # the start of a template literal
        if c == "`":
            out.append(" ")
            i += 1
            tpl_stack.append(None)
            tpl_lines.append(line_at(i))
            in_tpl = True
            continue

        # regex literal
        if c == "/" and prev_significant in "(,=:[!&|?{};+-*%~^" + "\n":
            j = i + 1
            in_class = False
            ok = False
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == "[":
                    in_class = True
                elif src[j] == "]":
                    in_class = False
                elif src[j] == "/" and not in_class:
                    ok = True
                    break
                elif src[j] == "\n":
                    break
                j += 1
            if ok:
                for _ in range(j - i + 1):
                    out.append(" ")
                i = j + 1
                while i < n and src[i].isalpha():
                    out.append(" ")
                    i += 1
                prev_significant = "x"
                continue

        # braces, which is where a suspended template literal comes back
        if c == "{":
            depth += 1
            out.append(c)
            prev_significant = c
            i += 1
            continue

        if c == "}":
            if tpl_stack and tpl_stack[-1] == depth:
                # This closes a ${…}; blank it, since its ${ was blanked too.
                depth -= 1
                tpl_stack[-1] = None
                in_tpl = True
                out.append(" ")
                i += 1
                continue
            depth -= 1
            out.append(c)
            prev_significant = c
            i += 1
            continue

        out.append(c)
        if not c.isspace():
            prev_significant = c
        elif c == "\n":
            prev_significant = "\n" if prev_significant in "(,=:[!&|?{};" else prev_significant
        i += 1

    if tpl_stack:
        errors.append((path, tpl_lines[0], "unterminated template literal"))

    return "".join(out)


def check_balance(code, path, errors):
    pairs = {")": "(", "]": "[", "}": "{"}
    stack = []
    for idx, ch in enumerate(code):
        if ch in "([{":
            stack.append((ch, idx))
        elif ch in ")]}":
            if not stack:
                errors.append((path, code.count("\n", 0, idx) + 1, f"unmatched closing '{ch}'"))
                return
            open_ch, open_idx = stack.pop()
            if open_ch != pairs[ch]:
                errors.append((path, code.count("\n", 0, idx) + 1,
                               f"'{ch}' closes '{open_ch}' opened on line {code.count(chr(10), 0, open_idx) + 1}"))
                return
    if stack:
        open_ch, open_idx = stack[-1]
        errors.append((path, code.count("\n", 0, open_idx) + 1, f"unclosed '{open_ch}'"))


# ─────────────────────────────────────────────────────── project inspection
def qml_files():
    out = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".git", "tools", "assets")]
        for f in filenames:
            if f.endswith(".qml"):
                out.append(os.path.join(dirpath, f))
    return sorted(out)


def near_miss(a, b):
    """True when `a` is one edit away from `b` and neither is trivially short."""
    if a == b or min(len(a), len(b)) < 3 or abs(len(a) - len(b)) > 1:
        return False
    if len(a) == len(b):
        return sum(x != y for x, y in zip(a, b)) == 1
    short, long = (a, b) if len(a) < len(b) else (b, a)
    for i in range(len(long)):
        if long[:i] + long[i + 1:] == short:
            return True
    return False


def rel(path):
    return os.path.relpath(path, ROOT)


DECL_RE = re.compile(
    r"^\s*(?:readonly\s+|required\s+|default\s+)*property\s+[\w<>.]+\s+(\w+)", re.M)
FUNC_RE = re.compile(r"^\s*function\s+(\w+)\s*\(", re.M)
SIGNAL_RE = re.compile(r"^\s*signal\s+(\w+)", re.M)
INLINE_COMP_RE = re.compile(r"^\s*component\s+(\w+)\s*:", re.M)
REQ_RE = re.compile(r"^\s*required\s+property\s+[\w<>.]+\s+(\w+)", re.M)
ASSIGN_RE = re.compile(r"^\s*(\w+)\s*:", re.M)
ID_RE = re.compile(r"^\s*id\s*:\s*(\w+)", re.M)
USE_RE = re.compile(r"(?<![\w.])([A-Z]\w*)\s*\{")
IMPORT_QS_RE = re.compile(r"^\s*import\s+qs((?:\.\w+)*)\s*$", re.M)
IMPORT_DIR_RE = re.compile(r'^\s*import\s+"([^"]+)"(?:\s+as\s+\w+)?\s*$', re.M)


def main():
    errors = []
    warnings = []
    files = qml_files()
    if not files:
        print("no .qml files found")
        return 1

    codes = {}
    sources = {}
    for path in files:
        with open(path, encoding="utf-8") as fh:
            src = fh.read()
        sources[path] = src
        code = strip_code(src, rel(path), errors)
        check_balance(code, rel(path), errors)
        codes[path] = code

    # --- what each file provides -------------------------------------------
    singletons = {}          # name -> set(members)
    by_dir = {}              # dir -> set(component names)
    for path, code in codes.items():
        name = os.path.splitext(os.path.basename(path))[0]
        d = os.path.dirname(path)
        by_dir.setdefault(d, set()).add(name)
        if "pragma Singleton" in code:
            members = set(DECL_RE.findall(code)) | set(FUNC_RE.findall(code)) | set(SIGNAL_RE.findall(code))
            singletons[name] = members

    # --- qmldir files: present, complete, and honest about singletons --------
    # Quickshell synthesises a qmldir for any directory that has none, and the
    # synthesis has failed this project once already: it registered
    # Dispatch.qml — a file with `pragma Singleton` — without `singleton`,
    # so every `Dispatch.x` call site got a hollow object and half the shell
    # died without an error anywhere you could see. A real qmldir per directory
    # is the source of truth now; this check keeps it that way.
    for d in sorted(by_dir):
        if d == ROOT:
            continue
        qd = os.path.join(d, "qmldir")
        rd = os.path.relpath(d, ROOT)
        if not os.path.isfile(qd):
            errors.append((rd, 1, "directory with .qml files has no qmldir — "
                           "Quickshell will synthesise one and may get it wrong"))
            continue
        with open(qd, encoding="utf-8") as fh:
            qd_src = fh.read()
        entries = {}
        for line in qd_src.splitlines():
            parts = line.strip().split()
            if not parts or parts[0] == "module" or parts[0].startswith("#"):
                continue
            if parts[0] == "singleton" and len(parts) == 4:
                entries[parts[1]] = (True, parts[3])
            elif len(parts) == 3:
                entries[parts[0]] = (False, parts[2])
        for name in sorted(provided := by_dir[d]):
            if name not in entries:
                errors.append((os.path.join(rd, "qmldir"), 1,
                               f"{name}.qml is not listed in qmldir — Quickshell "
                               f"cannot see it"))
                continue
            is_sg, _ = entries[name]
            pragma = bool(re.search(r"^pragma Singleton\s*$", codes[os.path.join(d, name + ".qml")], re.M))
            if pragma and not is_sg:
                errors.append((os.path.join(rd, "qmldir"), 1,
                               f"{name}.qml has `pragma Singleton` but qmldir "
                               f"lists it without `singleton` — every call site "
                               f"gets a hollow object"))
            if is_sg and not pragma:
                errors.append((os.path.join(rd, "qmldir"), 1,
                               f"qmldir lists {name}.qml as singleton but the file "
                               f"has no `pragma Singleton`"))
        for name in entries:
            if name not in by_dir[d]:
                errors.append((os.path.join(rd, "qmldir"), 1,
                               f"qmldir entry `{name}` has no file in the directory"))

    # --- two object literals with no comma between them ----------------------
    # `}` then `{` on the next line is never QML (a sibling object starts with
    # its type name) — it is a JS array missing a comma, a mistake the brace
    # count cannot see and QML refuses the whole file for ("Expected token ,").
    # Schema.qml lost its whole settings menu to exactly this.
    for path, code in codes.items():
        for m in re.finditer(r"\}[ \t]*\n[ \t]*\{", code):
            errors.append((rel(path), code.count("\n", 0, m.start()) + 1,
                           "`}` followed by `{` on the next line — a missing comma "
                           "between two list entries"))

    # --- a qmldir must end with a newline ------------------------------------
    # Appending `Name 1.0 Name.qml` to a qmldir without one glues two entries
    # into one line and the reload fails. Keep them all newline-terminated.
    for d in sorted(by_dir):
        qd = os.path.join(d, "qmldir")
        if os.path.isfile(qd):
            with open(qd, "rb") as fh:
                data = fh.read()
            if data and not data.endswith(b"\n"):
                errors.append((os.path.join(rel(d), "qmldir"), 1,
                               "qmldir does not end with a newline — the next "
                               "appended entry would be glued onto the last one"))

    # --- a singleton named after a built-in type -----------------------------
    # This has now cost two rounds. `Keys` is QML's attached type for key
    # handling; `Canvas` is a QtQuick item. A singleton by either name is
    # shadowed by the real type in every file that imports QtQuick — which is
    # every file — and the failure is not an error. It is a TypeError per
    # binding, and everything derived from the singleton silently becoming
    # undefined or NaN. Whole features stop working and the shell still starts.
    for path, code in codes.items():
        if "pragma Singleton" not in code:
            continue
        name = os.path.splitext(os.path.basename(path))[0]
        if name in KNOWN_TYPES:
            errors.append((rel(path), 1,
                           f"singleton `{name}` has the same name as a built-in "
                           f"QML type, which shadows it everywhere QtQuick is "
                           f"imported. Rename the singleton"))

    # And the other half of the same mistake: a name used as if it were one of
    # our singletons when it is really a built-in type. `Connections { target:
    # Canvas }` binds to QtQuick's Canvas and reports nothing.
    for path, code in codes.items():
        r = rel(path)
        for m in re.finditer(r"target:\s*([A-Z]\w*)\s*$", code, re.M):
            name = m.group(1)
            if name in KNOWN_TYPES and name not in EXTERNAL_SINGLETONS:
                errors.append((r, code.count("\n", 0, m.start()) + 1,
                               f"`target: {name}` — {name} is a QML type, not an "
                               f"object. This binds to nothing and reports nothing"))

    # --- per-file cross checks ---------------------------------------------
    for path, code in codes.items():
        r = rel(path)
        d = os.path.dirname(path)

        visible = set(KNOWN_TYPES)
        visible |= by_dir.get(d, set())          # implicit same-directory import
        visible |= set(INLINE_COMP_RE.findall(code))
        visible |= set(singletons)               # singletons are globally visible

        for suffix in IMPORT_QS_RE.findall(sources[path]):
            sub = suffix.strip(".").replace(".", os.sep)
            target = os.path.join(ROOT, sub) if sub else ROOT
            if not os.path.isdir(target):
                errors.append((r, 0, f"import qs{suffix} → no such directory {rel(target)}"))
            else:
                visible |= by_dir.get(target, set())

        for reldir in IMPORT_DIR_RE.findall(sources[path]):
            target = os.path.normpath(os.path.join(d, reldir))
            if reldir.endswith(".js"):
                # A JavaScript library import — needs the file, adds no types.
                if not os.path.isfile(target):
                    errors.append((r, 0, f'import "{reldir}" → no such file {rel(target)}'))
                continue
            if not os.path.isdir(target):
                errors.append((r, 0, f'import "{reldir}" → no such directory'))
            else:
                visible |= by_dir.get(target, set())

        used = set(USE_RE.findall(code))
        # `on<Signal>: Foo {` style and enum-ish false positives are filtered by
        # requiring the name to look like a type, which the regex already does.
        for name in sorted(used - visible):
            if name in ("Behavior", "Component"):
                continue
            errors.append((r, 0, f"unknown component: {name} {{"))

        # --- singleton member access ---------------------------------------
        local_ids = set(ID_RE.findall(code))
        for m in re.finditer(r"(?<![\w.])([A-Z]\w*)\.(\w+)", code):
            obj, member = m.group(1), m.group(2)
            if obj in EXTERNAL_SINGLETONS or obj in local_ids:
                continue
            if obj not in singletons:
                continue
            if member not in singletons[obj]:
                line = code.count("\n", 0, m.start()) + 1
                errors.append((r, line, f"{obj}.{member} — {obj} declares no such member"))

    # --- the same property assigned twice in one block ----------------------
    # "Property value set multiple times" is a hard load failure, and it is the
    # easiest mistake in the world to make while editing: you add a line that
    # is already there fifteen lines further down. Purely structural, so it
    # needs no knowledge of what the properties mean.
    DUP_SKIP = {"on", "when", "function", "property", "readonly", "required",
                "signal", "component", "default", "import", "pragma", "case",
                "return", "if", "else", "for", "while", "const", "let", "var"}

    for path, code in codes.items():
        r = rel(path)
        lines = code.split("\n")
        # depth -> {name: first line it was assigned at}
        seen = {}
        depth = 0
        for i, line in enumerate(lines, 1):
            opens = line.count("{")
            closes = line.count("}")

            am = ASSIGN_RE.match(line)
            if am and opens == 0 and closes == 0:
                prop = am.group(1)
                if prop not in DUP_SKIP:
                    here = seen.setdefault(depth, {})
                    if prop in here:
                        errors.append((r, i,
                                       f"`{prop}` is set twice in the same block "
                                       f"(also line {here[prop]}) — QML refuses "
                                       f"the whole file"))
                    else:
                        here[prop] = i

            # A block that opens or closes on this line starts a new scope for
            # anything that follows, so the record for every deeper level goes.
            if opens or closes:
                depth += opens - closes
                for d in [d for d in seen if d >= depth]:
                    seen.pop(d, None)

    # --- `parent` from inside something that is not an Item -----------------
    # An Animation, a Transform, a Timer, a Connections — none of them are
    # Items, so none of them have a `parent`. Writing `parent.x` inside one
    # does not fail loudly: QML resolves the name through the surrounding
    # scope, which usually means it silently points somewhere other than where
    # the markup makes it look like it points. Reference an id instead.
    NON_ITEM_BLOCKS = {
        "Translate", "Scale", "Rotation", "Matrix4x4",
        "NumberAnimation", "ColorAnimation", "PropertyAnimation",
        "RotationAnimation", "AnchorAnimation", "PauseAnimation",
        "SequentialAnimation", "ParallelAnimation", "SpringAnimation",
        "SmoothedAnimation", "PropertyAction", "ScriptAction",
        "Behavior", "Timer", "Connections", "State", "Transition",
        "PropertyChanges", "Binding", "FontLoader", "SystemClock",
    }

    for path, code in codes.items():
        r = rel(path)
        for m in re.finditer(r"(?<![\w.])([A-Z]\w*)\s*\{", code):
            if m.group(1) not in NON_ITEM_BLOCKS:
                continue
            depth = 0
            i = m.end() - 1
            start = i + 1
            while i < len(code):
                if code[i] == "{":
                    depth += 1
                elif code[i] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            block = code[start:i]
            for pm in re.finditer(r"(?<![\w.])parent(?![\w])", block):
                errors.append((r, code.count("\n", 0, start + pm.start()) + 1,
                               f"`parent` inside a {m.group(1)} — that is not an "
                               f"Item and has no parent; the name resolves "
                               f"through the surrounding scope instead. Use an id"))

    # Chained parent walking is fragile wherever it appears: it counts levels of
    # markup, and re-nesting anything silently repoints it.
    for path, code in codes.items():
        for m in re.finditer(r"parent\s*\.\s*parent", code):
            errors.append((rel(path), code.count("\n", 0, m.start()) + 1,
                           "`parent.parent` counts levels of nesting — give the "
                           "thing you mean an id and reference that"))

    # --- shadowing a FINAL property of Item ---------------------------------
    # `left`, `right`, `top`, `bottom` and friends are not free names: Item
    # exposes them as anchor lines — `parent.right` is exactly that — and they
    # are FINAL, so declaring one is "Cannot override FINAL property" and the
    # whole file is refused. The mistake is easy because they read like
    # perfectly ordinary booleans for a corner or an edge.
    ANCHOR_LINES = {"left", "right", "top", "bottom",
                    "horizontalCenter", "verticalCenter", "baseline"}
    FINAL_ITEM_PROPS = ANCHOR_LINES | {
        "anchors", "data", "children", "resources", "visibleChildren",
        "childrenRect", "states", "transitions",
    }
    # Not FINAL, so QML accepts these — and then draws with them.
    SHADOWED_ITEM_PROPS = {
        "scale", "opacity", "rotation", "x", "y", "z", "width", "height",
        "visible", "enabled", "clip", "smooth", "antialiasing", "focus",
        "state", "parent", "implicitWidth", "implicitHeight",
        "transformOrigin",
    }

    for path, code in codes.items():
        if "pragma Singleton" in code:
            continue      # QtObject roots have no anchor lines to shadow
        r = rel(path)
        for m in re.finditer(
                r"^\s*(?:readonly\s+|required\s+|default\s+)*property\s+"
                r"(?:alias|[\w<>.]+)\s+(\w+)\s*:", code, re.M):
            name = m.group(1)
            line = code.count("\n", 0, m.start()) + 1
            if name in ANCHOR_LINES:
                errors.append((r, line,
                               f"`{name}` is Item's anchor line (the one you use "
                               f"as parent.{name}) and is FINAL — declaring it "
                               f"makes QML refuse the whole file"))
            elif name in FINAL_ITEM_PROPS:
                errors.append((r, line,
                               f"`{name}` is a FINAL property of Item — declaring "
                               f"it makes QML refuse the whole file"))
            elif name in SHADOWED_ITEM_PROPS:
                # Not fatal, which is what makes it worse: the file loads and
                # the property silently drives rendering. `scale` on a map that
                # fits a canvas into a panel is about 0.05, and the panel draws
                # at a twentieth of its size with no error anywhere.
                errors.append((r, line,
                               f"`{name}` shadows Item.{name} — this loads fine "
                               f"and then quietly drives how the item is drawn; "
                               f"give it another name"))

    # --- the same property declared twice in one block -----------------------
    # A sibling of the assignment check above, and just as fatal, but it slips
    # past it: `readonly property real unit:` does not look like an assignment
    # to a line-based reader, so it needs its own pass.
    DECL_LINE_RE = re.compile(
        r"^(\s*)(?:readonly\s+|required\s+|default\s+)*property\s+"
        r"(?:alias|[\w<>.]+)\s+(\w+)\s*:")

    for path, code in codes.items():
        r = rel(path)
        seen = {}
        depth = 0
        for i, line in enumerate(code.split("\n"), 1):
            m = DECL_LINE_RE.match(line)
            if m:
                here = seen.setdefault(depth, {})
                name = m.group(2)
                if name in here:
                    errors.append((r, i,
                                   f"`{name}` is declared twice in the same block "
                                   f"(also line {here[name]}) — QML refuses the "
                                   f"whole file"))
                else:
                    here[name] = i
            opens = line.count("{")
            closes = line.count("}")
            if opens or closes:
                depth += opens - closes
                for d in [d for d in seen if d > depth]:
                    seen.pop(d, None)

    # --- Behavior on a readonly property -------------------------------------
    # A Behavior animates a property by writing to it, so it cannot sit on one
    # that is readonly. QML says "Invalid property assignment: X is a read-only
    # property" and refuses the file — and the temptation is constant, because
    # a derived offset is exactly the kind of thing you want to smooth.
    #
    # Matched by block, not by name alone: `zoom` can perfectly well be
    # writable on the window and readonly on an item inside it, and flagging
    # the wrong one of those would make this rule worse than nothing.
    for path, code in codes.items():
        r = rel(path)
        readonly = set()       # (depth, name)
        behaviors = []         # (depth, name, line)
        depth = 0
        for i, line in enumerate(code.split("\n"), 1):
            m = re.match(r"^\s*readonly\s+property\s+(?:alias|[\w<>.]+)\s+(\w+)\s*:", line)
            if m:
                readonly.add((depth, m.group(1)))
            m = re.search(r"(?<![\w.])Behavior\s+on\s+(\w+)", line)
            if m:
                behaviors.append((depth, m.group(1), i))
            depth += line.count("{") - line.count("}")

        for d, name, line_no in behaviors:
            if (d, name) in readonly:
                errors.append((r, line_no,
                               f"`Behavior on {name}` — `{name}` is readonly in this "
                               f"block, and a Behavior works by writing to it. "
                               f"Animate whatever it is derived from instead"))

    # --- two things with the same id in one file ----------------------------
    # Also a hard load failure, also easy to introduce while copying a block.
    for path, code in codes.items():
        r = rel(path)
        first = {}
        # Anchored to the end of the line on purpose: a QML id is a bare name
        # and nothing else, while `id: root.nextId++,` inside an object literal
        # is ordinary JavaScript and none of this rule's business.
        for m in re.finditer(r"^[ \t]*id\s*:\s*([a-z_]\w*)[ \t]*$", code, re.M):
            name = m.group(1)
            line = code.count("\n", 0, m.start()) + 1
            if name in first:
                errors.append((r, line,
                               f"id `{name}` is used twice (also line {first[name]}) "
                               f"— ids must be unique within a file"))
            else:
                first[name] = line

    # --- nested singleton members ------------------------------------------
    # `Appearance.row.titel` is not a syntax error and not a missing member of
    # Appearance either — it is `undefined` two levels down, which renders as a
    # zero-size font and looks like a layout bug. Singletons group their tokens
    # in QtObject blocks, so the same walk that validates Config keys works
    # here once the tree is built from `property X n: QtObject {`.
    GROUP_RE = re.compile(
        r"^\s*(?:readonly\s+)?property\s+[\w<>.]+\s+(\w+)\s*:\s*QtObject\s*\{")
    LEAF_RE = re.compile(
        r"^\s*(?:readonly\s+|required\s+|default\s+)*property\s+[\w<>.]+\s+(\w+)\s*:")

    def member_tree(text):
        tree = {}
        stack = [tree]
        depth_of = [0]
        depth = 0
        for line in text.split("\n"):
            m = GROUP_RE.match(line)
            if m:
                child = {}
                stack[-1][m.group(1)] = child
                depth += line.count("{") - line.count("}")
                stack.append(child)
                depth_of.append(depth)
                continue
            m = LEAF_RE.match(line)
            if m:
                stack[-1].setdefault(m.group(1), True)
            depth += line.count("{") - line.count("}")
            while len(depth_of) > 1 and depth < depth_of[-1]:
                stack.pop()
                depth_of.pop()
        return tree

    trees = {}
    for path, code in codes.items():
        if "pragma Singleton" not in code:
            continue
        name = os.path.splitext(os.path.basename(path))[0]
        t = member_tree(code)
        t.update({f: True for f in FUNC_RE.findall(code)})
        t.update({g: True for g in SIGNAL_RE.findall(code)})
        trees[name] = t

    for path, code in codes.items():
        r = rel(path)
        own = os.path.splitext(os.path.basename(path))[0]
        local_ids = set(ID_RE.findall(code))
        for m in re.finditer(r"(?<![\w.])([A-Z]\w*)\.(\w+(?:\.\w+)+)", code):
            obj = m.group(1)
            if obj in EXTERNAL_SINGLETONS or obj in local_ids or obj == own:
                continue
            if obj not in trees or obj == "Config":     # Config has its own pass
                continue
            node = trees[obj]
            walked = []
            for part in m.group(2).split("."):
                if not isinstance(node, dict):
                    break              # reached a value; the rest is JS
                if part not in node:
                    errors.append((r, code.count("\n", 0, m.start()) + 1,
                                   f"{obj}." + ".".join(walked + [part])
                                   + f" — {obj} declares no such member"))
                    break
                walked.append(part)
                node = node[part]

    # --- required properties actually get set ------------------------------
    # Quickshell refuses to load a component whose required property is unset,
    # and the error points at the definition rather than the call site, so
    # catching it here saves real time.
    #
    # One component-aware decl pass serves this check and the property
    # assignment check below: inline `component X: …` blocks declare their
    # own properties, which belong to X — never to the file's root component.
    file_decls = {}         # file root component -> names it declares itself
    file_reqs = {}          # file root component -> required props
    for path, code in codes.items():
        name = os.path.splitext(os.path.basename(path))[0]
        decls = set()
        reqs = set()
        depth = 0
        in_inline = []
        for line in code.split("\n"):
            stripped = line.strip()
            if INLINE_COMP_RE.match(line):
                in_inline.append(depth)
            dm = DECL_RE.match(line)
            rm = REQ_RE.match(line)
            if (dm or rm) and len(in_inline) == 0:
                if dm:
                    decls.add(dm.group(1))
                if rm:
                    reqs.add(rm.group(1))
            depth += stripped.count("{") - stripped.count("}")
            while in_inline and in_inline[-1] >= depth:
                in_inline.pop()
        file_decls[name] = decls
        file_reqs[name] = reqs

    required = {}
    for path, code in codes.items():
        name = os.path.splitext(os.path.basename(path))[0]
        if file_reqs.get(name):
            required[name] = file_reqs[name]

    AUTO_FILLED = {"modelData", "index"}

    for path, code in codes.items():
        r = rel(path)
        own = os.path.splitext(os.path.basename(path))[0]
        for m in re.finditer(r"(?<![\w.])([A-Z]\w*)\s*\{", code):
            name = m.group(1)
            if name not in required or name == own:
                continue
            # Walk to the matching closing brace.
            depth = 0
            i = m.end() - 1
            start = i + 1
            while i < len(code):
                if code[i] == "{":
                    depth += 1
                elif code[i] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            block = code[start:i]
            # Only assignments at this block's own depth count.
            provided = set()
            d = 0
            for line in block.split("\n"):
                am = ASSIGN_RE.match(line)
                if am and d == 0:
                    provided.add(am.group(1))
                d += line.count("{") - line.count("}")
            provided |= set(REQ_RE.findall(block))
            missing = required[name] - provided - AUTO_FILLED
            if missing:
                line_no = code.count("\n", 0, m.start()) + 1
                errors.append((r, line_no,
                               f"{name} {{ }} missing required: {', '.join(sorted(missing))}"))

    # --- Component.onCompleted on a non-Item root ---------------------------
    # ShellRoot, Singleton and the window types are plain QObjects; the
    # Component attached object does not exist on them and Quickshell refuses
    # to load the file ("Non-existent attached object").
    NON_ITEM_ROOTS = {"Singleton", "ShellRoot", "PanelWindow", "PopupWindow",
                      "FloatingWindow", "Scope", "Variants", "QtObject",
                      "LazyLoader", "PersistentProperties"}
    for path, code in codes.items():
        r = rel(path)
        root_type = None
        for line in code.split("\n"):
            m = re.match(r"^([A-Z]\w*)\s*\{", line)
            if m:
                root_type = m.group(1)
                break
        if root_type not in NON_ITEM_ROOTS:
            continue
        depth = 0
        for i, line in enumerate(code.split("\n"), 1):
            if depth == 1 and re.match(r"^\s*Component\.on(Completed|Destruction)\s*:", line):
                errors.append((r, i,
                               f"Component.on… on a {root_type} root — not an Item, "
                               f"use a one-shot Timer or an eager binding instead"))
            depth += line.count("{") - line.count("}")

    # --- assignments to properties our own components do not declare --------
    # `Resources { win: ... }` where Resources never declared `win` is a hard
    # QML error ("Cannot assign to non-existent property"), and it takes the
    # whole file with it — so one missing line in a leaf module can cost you
    # the entire bar. Only names that appear as a declared property somewhere
    # in this shell are considered, so ordinary QtQuick properties are never
    # second-guessed.
    own_decls = {}          # component -> set(names it declares itself)
    root_type_of = {}       # component -> its root type
    for path, code in codes.items():
        name = os.path.splitext(os.path.basename(path))[0]
        own_decls[name] = (file_decls.get(name, set()) | file_reqs.get(name, set())
                           | set(SIGNAL_RE.findall(code)))
        for line in code.split("\n"):
            m = re.match(r"^([A-Z]\w*)\s*\{", line)
            if m:
                root_type_of[name] = m.group(1)
                break

    def declared(component, seen=None):
        """Everything a component accepts, following our own inheritance."""
        seen = seen or set()
        if component in seen or component not in own_decls:
            return set()
        seen.add(component)
        out = set(own_decls[component])
        # A signal `foo` is assigned as `onFoo:`.
        out |= {"on" + n[0].upper() + n[1:] for n in own_decls[component]}
        parent = root_type_of.get(component)
        if parent and parent in own_decls:
            out |= declared(parent, seen)
        return out

    # Names that are ours and could not be mistaken for a QtQuick property.
    BUILTIN_PROPS = {
        "width", "height", "color", "text", "opacity", "visible", "enabled",
        "x", "y", "z", "scale", "rotation", "radius", "source", "running",
        "spacing", "padding", "focus", "clip", "smooth", "antialiasing",
        "value", "target", "duration", "from", "to", "loops", "interval",
        "active", "item", "model", "delegate", "orientation", "position",
        "state", "screen", "title", "icon", "name", "sub", "label", "index",
        "modelData", "data", "children", "layer", "transform", "leftPadding",
        "rightPadding", "topPadding", "bottomPadding", "implicitWidth",
        "implicitHeight", "containmentMask", "sourceComponent", "asynchronous",
        "cursorShape", "hoverEnabled", "pressed", "checked", "flow", "columns",
        "rows", "path", "mask", "layout", "message", "player", "count",
        # Real QtQuick property names that one of our own singletons also
        # happens to declare. Only genuine built-ins belong here — every
        # name listed is a name this check can no longer catch.
        "font", "size", "border", "status", "progress",
    }
    vocab = set()
    for names in own_decls.values():
        vocab |= names
    vocab -= BUILTIN_PROPS

    for path, code in codes.items():
        r = rel(path)
        own = os.path.splitext(os.path.basename(path))[0]
        inline = set(INLINE_COMP_RE.findall(code))
        for m in re.finditer(r"(?<![\w.])([A-Z]\w*)\s*\{", code):
            name = m.group(1)
            if name not in own_decls or name in inline:
                continue
            accepts = declared(name)
            depth = 0
            i = m.end() - 1
            start = i + 1
            while i < len(code):
                if code[i] == "{":
                    depth += 1
                elif code[i] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            block = code[start:i]
            d = 0
            for offset, line in enumerate(block.split("\n")):
                am = ASSIGN_RE.match(line)
                if am and d == 0:
                    prop = am.group(1)
                    line_no = code.count("\n", 0, start) + offset + 1
                    if prop in vocab and prop not in accepts:
                        errors.append((r, line_no,
                                       f"{name} {{ {prop}: … }} — {name} declares no "
                                       f"property `{prop}` (QML refuses the whole file)"))
                    elif prop not in accepts and prop not in vocab:
                        # A name this shell has never heard of, one letter away
                        # from one of this component's own properties. `tipp`
                        # for `tip` is not a name QML knows either, so it is
                        # the same hard failure — it just cannot be caught by
                        # asking whether anyone declares it.
                        near = [a for a in accepts if near_miss(prop, a)]
                        if near and prop not in BUILTIN_PROPS:
                            errors.append((r, line_no,
                                           f"{name} {{ {prop}: … }} — did you mean "
                                           f"`{sorted(near)[0]}`? {name} has no `{prop}`"))
                d += line.count("{") - line.count("}")

    # --- schema keys resolve to real config properties ----------------------
    # A typo in Schema.qml produces a row that reads and writes nothing, which
    # looks fine on screen and silently does nothing. Worth catching.
    cfg_path = os.path.join(ROOT, "config", "Config.qml")
    schema_path = os.path.join(ROOT, "config", "Schema.qml")
    if cfg_path in codes and schema_path in codes:
        cfg = codes[cfg_path]

        def config_tree(text):
            """Walk the JsonAdapter block into a nested dict of property names."""
            tree = {}
            stack = [tree]
            depth_of = [0]
            depth = 0
            for line in text.split("\n"):
                stripped = line.strip()
                m = re.match(r"property\s+JsonObject\s+(\w+)\s*:\s*JsonObject\s*\{", stripped)
                if m:
                    child = {}
                    stack[-1][m.group(1)] = child
                    depth += line.count("{") - line.count("}")
                    stack.append(child)
                    depth_of.append(depth)
                    continue
                m = re.match(r"(?:readonly\s+)?property\s+[\w<>.]+\s+(\w+)\s*:", stripped)
                if m:
                    stack[-1].setdefault(m.group(1), True)
                depth += line.count("{") - line.count("}")
                while len(depth_of) > 1 and depth < depth_of[-1]:
                    stack.pop()
                    depth_of.pop()
            return tree

        tree = config_tree(cfg)

        def resolve(path):
            node = tree
            for part in path.split("."):
                if not isinstance(node, dict) or part not in node:
                    return False
                node = node[part]
            return True

        with open(schema_path, encoding="utf-8") as fh:
            schema_src = fh.read()
        for m in re.finditer(r'\b(?:key|valueKey)\s*:\s*"([^"]+)"', schema_src):
            key = m.group(1)
            if not resolve(key):
                line = schema_src.count("\n", 0, m.start()) + 1
                errors.append(("config/Schema.qml", line,
                               f'key "{key}" does not exist in Config.qml'))

        # The same typo is just as silent anywhere else a dotted key is passed
        # to Config.get / Config.set / Config.toggle, or listed in a service
        # that drives them. Only strings whose first segment is a real top-level
        # config section are judged, so ordinary dotted strings are left alone.
        top = set(tree)
        for path in codes:
            if path in (cfg_path, schema_path):
                continue
            # The stripped code has had its string bodies removed — which is
            # what the brace check needs and exactly what this check must not
            # have. Read the original, and skip comment lines so prose cannot
            # trip it.
            src = sources[path]
            for m in re.finditer(r'"([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+)"', src):
                key = m.group(1)
                if key.split(".")[0] not in top or resolve(key):
                    continue
                line_start = src.rfind("\n", 0, m.start()) + 1
                if src[line_start:m.start()].lstrip().startswith("//"):
                    continue
                errors.append((rel(path), src.count("\n", 0, m.start()) + 1,
                               f'config key "{key}" does not exist in Config.qml'))

            # And the same key written the other way: Config.bar.thicknes reads
            # `undefined` rather than failing, so nothing about it looks wrong
            # until the setting silently does nothing. Anything after a real
            # leaf is JavaScript on that value (.toFixed, .length) and is fine —
            # only a name missing from a *section* is a typo.
            for m in re.finditer(r'(?<![\w.])Config\.([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+)',
                                 codes[path]):
                parts = m.group(1).split(".")
                if parts[0] not in top:
                    continue
                node = tree
                walked = []
                for part in parts:
                    if not isinstance(node, dict):
                        break          # reached a value; the rest is JS
                    if part not in node:
                        errors.append((rel(path),
                                       codes[path].count("\n", 0, m.start()) + 1,
                                       "Config." + ".".join(walked + [part])
                                       + " does not exist in Config.qml"))
                        break
                    walked.append(part)
                    node = node[part]

    # --- keybinds actually reach something -----------------------------------
    # A keybind that names a global shortcut the shell never declares, or an
    # IPC target that does not exist, fails in the quietest way there is: you
    # press the key and nothing happens, with no error anywhere. Both halves
    # live in this repo, so both halves can be checked against each other.
    shortcut_names = set()
    ipc = {}          # target -> set(function names)
    # The ORIGINAL source, not the stripped code: strip_code empties string
    # bodies, and every name this check needs is inside one.
    for path, code in sources.items():
        for m in re.finditer(r"GlobalShortcut\s*\{", code):
            block = code[m.end():code.find("}", m.end()) + 1]
            nm = re.search(r'name:\s*"([^"]+)"', block)
            if nm:
                shortcut_names.add(nm.group(1))
        for m in re.finditer(r"IpcHandler\s*\{", code):
            depth = 0
            i = m.end() - 1
            start = i + 1
            while i < len(code):
                if code[i] == "{":
                    depth += 1
                elif code[i] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            block = code[start:i]
            tm = re.search(r'target:\s*"([^"]+)"', block)
            if tm:
                ipc.setdefault(tm.group(1), set()).update(FUNC_RE.findall(block))

    for name in ("hypr/velvet-shell.conf", "hypr/velvet-shell.lua"):
        f = os.path.join(ROOT, name)
        if not os.path.isfile(f):
            continue
        with open(f, encoding="utf-8") as fh:
            text = fh.read()
        for i, line in enumerate(text.split("\n"), 1):
            bare = line.split("#")[0].split("--")[0]
            for m in re.finditer(r"quickshell:(\w+)", bare):
                if m.group(1) not in shortcut_names:
                    errors.append((name, i,
                                   f"binds global shortcut `{m.group(1)}`, which no "
                                   f"GlobalShortcut declares — the key does nothing"))
            for m in re.finditer(r"ipc\s+call\s+(\w+)\s+(\w+)", bare):
                target, fn = m.group(1), m.group(2)
                if target not in ipc:
                    errors.append((name, i,
                                   f"calls IPC target `{target}`, which no "
                                   f"IpcHandler declares — the key does nothing"))
                elif fn not in ipc[target]:
                    errors.append((name, i,
                                   f"calls `{target} {fn}`, but that handler has no "
                                   f"function `{fn}` — the key does nothing"))

    # --- every config section is reachable from outside Config ---------------
    # A section declared in the JsonAdapter but never given a shortcut is
    # `undefined` at every call site — and because the dotted-key checks above
    # resolve against the adapter, they call it perfectly valid. QML then warns
    # once per binding per frame and the feature quietly does nothing. Five
    # sections shipped that way.
    if cfg_path in codes:
        cfg_src = sources[cfg_path]
        declared = set(re.findall(
            r"^\s*property\s+JsonObject\s+(\w+)\s*:\s*JsonObject\s*\{",
            cfg_src, re.M))
        # Only the top level: nested groups are reached through their parent.
        top_level = set()
        depth = 0
        for line in cfg_src.split("\n"):
            m = re.match(r"^\s*property\s+JsonObject\s+(\w+)\s*:\s*JsonObject\s*\{", line)
            if m and depth <= 3:
                top_level.add(m.group(1))
            depth += line.count("{") - line.count("}")

        exposed = set(re.findall(
            r"^\s*readonly\s+property\s+var\s+(\w+)\s*:\s*adapter\.\1\s*$",
            cfg_src, re.M))

        for name in sorted(top_level - exposed):
            line = cfg_src.count("\n", 0, cfg_src.index(f"property JsonObject {name}:")) + 1
            errors.append(("config/Config.qml", line,
                           f"section `{name}` has no `readonly property var {name}: "
                           f"adapter.{name}` — Config.{name} is undefined everywhere"))

    # --- an id is not a member of the root object ---------------------------
    # `root.settleTimer.restart()` looks right and is not: an id lives in the
    # document's own scope, not on the root object, so that expression is
    # undefined at runtime and the call throws. Written here as a rule because
    # it is a mistake that reads as correct code.
    for path, code in codes.items():
        r = rel(path)
        ids = set(re.findall(r"^\s*id:\s*([A-Za-z_]\w*)\s*$", code, re.M))
        root_id = None
        m = re.search(r"^\s*id:\s*([A-Za-z_]\w*)\s*$", code, re.M)
        if m:
            root_id = m.group(1)
        if not root_id:
            continue
        others = ids - {root_id}
        if not others:
            continue
        declared_here = (set(DECL_RE.findall(code)) | set(REQ_RE.findall(code))
                         | set(SIGNAL_RE.findall(code)) | set(FUNC_RE.findall(code)))
        for hit in re.finditer(r"\b" + re.escape(root_id) + r"\.([A-Za-z_]\w*)", code):
            name = hit.group(1)
            if name in others and name not in declared_here:
                errors.append((r, code.count("\n", 0, hit.start()) + 1,
                               f"{root_id}.{name} — `{name}` is an id, not a member of "
                               f"{root_id}; write `{name}.` on its own"))

    # --- a Timer with a `running:` binding that is also restart()ed ---------
    # restart() and start() ASSIGN running, which destroys the binding. After
    # the first call the binding never fires again, so whatever the timer was
    # driving stops for the rest of the session — silently.
    for path, code in codes.items():
        r = rel(path)
        lines = code.split("\n")
        depth = 0
        blocks = []          # (id, has_running_binding, start_line)
        stack = []
        for i, line in enumerate(lines, 1):
            m = re.match(r"^\s*Timer\s*\{", line)
            if m:
                stack.append({"depth": depth, "id": None, "bound": False, "line": i})
            for entry in stack:
                if entry["depth"] + 1 == depth + line.count("{") - line.count("}") or True:
                    pass
            if stack:
                top = stack[-1]
                mid = re.match(r"^\s*id:\s*([A-Za-z_]\w*)\s*$", line)
                if mid:
                    top["id"] = mid.group(1)
                if re.match(r"^\s*running:\s*(?!true\s*$)(?!false\s*$).+", line):
                    top["bound"] = True
            depth += line.count("{") - line.count("}")
            while stack and depth <= stack[-1]["depth"]:
                blocks.append(stack.pop())
        blocks.extend(stack)
        for b in blocks:
            if not b["id"] or not b["bound"]:
                continue
            call = re.search(r"\b" + re.escape(b["id"]) + r"\.(restart|start)\s*\(", code)
            if call:
                errors.append((r, code.count("\n", 0, call.start()) + 1,
                               f"{b['id']}.{call.group(1)}() on a Timer whose `running` is a "
                               f"binding (line {b['line']}) — the call replaces the binding "
                               f"and the timer never runs from it again"))

    # --- writing to a readonly property -------------------------------------
    # QML refuses the write at runtime and logs it, which in practice means the
    # feature silently does nothing.
    for path, code in codes.items():
        r = rel(path)
        m = re.search(r"^\s*id:\s*([A-Za-z_]\w*)\s*$", code, re.M)
        if not m:
            continue
        root_id = m.group(1)
        ro = set(re.findall(r"^\s*readonly\s+property\s+[\w<>.]+\s+(\w+)\s*[:{]", code, re.M))
        for name in sorted(ro):
            for hit in re.finditer(r"\b" + re.escape(root_id) + r"\." + re.escape(name)
                                   + r"\s*(?:\+|-|\*|/)?=(?!=)", code):
                errors.append((r, code.count("\n", 0, hit.start()) + 1,
                               f"{root_id}.{name} is readonly and is being assigned"))

    # --- a schema row that reaches nothing ----------------------------------
    # `fn:` names an action Bridge.act() must handle and `live:` names a value
    # Bridge.get() must return. A name with no case is not an error anywhere —
    # the row renders, you press it, and nothing happens.
    schema_src = sources.get(os.path.join(ROOT, "config", "Schema.qml"), "")
    bridge_src = sources.get(os.path.join(ROOT, "services", "Bridge.qml"), "")
    if schema_src and bridge_src:
        cases = set(re.findall(r'case\s+"(\w+)"\s*:', bridge_src))
        for kind in ("fn", "live"):
            for m in re.finditer(kind + r':\s*"(\w+)"', schema_src):
                name = m.group(1)
                if name not in cases:
                    errors.append(("config/Schema.qml",
                                   schema_src.count("\n", 0, m.start()) + 1,
                                   f'{kind}: "{name}" — Bridge handles no such case, so the '
                                   f"row renders and then does nothing"))

    # --- a bar module whose settings have no rows ---------------------------
    # Modules.qml lists the config keys each module owns; the layout editor
    # renders `Schema.rowsFor(those keys)` beside the module you pick. A key
    # with no row in Schema.qml is a module that looks like it has settings and
    # shows an empty panel instead.
    modules_src = sources.get(os.path.join(ROOT, "config", "Modules.qml"), "")
    if modules_src and schema_src:
        schema_keys = (set(re.findall(r'\bkey:\s*"([\w.]+)"', schema_src))
                       | set(re.findall(r'\bvalueKey:\s*"([\w.]+)"', schema_src)))
        seen_keys = set()
        for m in re.finditer(r'keys:\s*\[([^\]]*)\]', modules_src):
            for km in re.finditer(r'"([\w.]+)"', m.group(1)):
                key = km.group(1)
                if key in seen_keys or key in schema_keys:
                    continue
                seen_keys.add(key)
                errors.append(("config/Modules.qml",
                               modules_src.count("\n", 0, m.start() + km.start()) + 1,
                               f'module key "{key}" has no row in Schema.qml — the module '
                               f"inspector will render an empty panel for it"))

    # --- a type used without the import that provides it --------------------
    # This is the worst failure in the whole list, and the only one whose
    # symptom is not an error you can read: QML refuses the file, Quickshell
    # registers the singleton's NAME anyway, and every call site then gets
    # "Property 'x' of object Y is not a function" from a hollow object — with
    # the real cause scrolled off the top of the log.
    PROVIDES = {
        "Quickshell.Io": {
            "Process", "StdioCollector", "SplitParser", "DataStream", "DataStreamParser",
            "FileView", "JsonAdapter", "JsonObject", "IpcHandler", "Socket", "SocketServer",
            "FileViewError",
        },
        "Quickshell.Hyprland": {
            "Hyprland", "HyprlandWorkspace", "HyprlandMonitor", "HyprlandToplevel",
            "HyprlandEvent", "GlobalShortcut", "HyprlandFocusGrab",
        },
        "Quickshell.Wayland": {
            "WlrLayershell", "WlrLayer", "WlrKeyboardFocus", "WlSessionLock",
            "WlSessionLockSurface", "Toplevel", "ToplevelManager", "ScreencopyView",
        },
        "Quickshell.Widgets": {
            "IconImage", "WrapperItem", "WrapperRectangle", "ClippingRectangle",
            "ClippingWrapperRectangle", "MarginWrapperManager",
        },
        "Quickshell.Services.Notifications": {
            "NotificationServer", "Notification", "NotificationAction", "NotificationUrgency",
        },
        "Quickshell.Services.Pipewire": {
            "Pipewire", "PwNode", "PwNodeAudio", "PwObjectTracker", "PwLink", "PwLinkGroup",
        },
        "Quickshell.Services.UPower": {"UPower", "UPowerDevice", "UPowerDeviceState"},
        "Quickshell.Services.SystemTray": {
            "SystemTray", "SystemTrayItem", "QsMenuOpener", "QsMenuAnchor", "QsMenuEntry",
        },
        "Quickshell.Services.Pam": {"PamContext", "PamResult", "PamError"},
        "Quickshell": {
            "Singleton", "ShellRoot", "PanelWindow", "FloatingWindow", "PopupWindow",
            "Variants", "Scope", "LazyLoader", "Region", "ShellScreen", "DesktopEntries",
            "DesktopEntry", "DesktopAction", "Quickshell", "PersistentProperties",
            "QuickshellSettings", "SystemClock", "ElapsedTimer", "ColorQuantizer",
            "TransformWatcher", "ObjectRepeater", "ScriptModel", "ExclusionMode",
            "QsWindow", "Edges",
        },
    }
    owner = {}
    for mod, names in PROVIDES.items():
        for n in names:
            # A name offered by two modules is ambiguous; only check the clear ones.
            owner[n] = None if n in owner else mod

    for path, code in codes.items():
        r = rel(path)
        # `[ \t]` not `\s`: a blanked `import "dir"` line leaves trailing spaces,
        # and \s+ would happily eat the newline and capture the NEXT line's
        # `import` keyword as the module name.
        imports = set(re.findall(r"^[ \t]*import[ \t]+([\w.]+)", code, re.M))
        # The import lines themselves are not uses: `import Quickshell.Wayland`
        # would otherwise read as "this file uses Quickshell".
        body = re.sub(r"^[ \t]*import[ \t]+[^\n]*", "", code, flags=re.M)
        used = set(re.findall(r"^\s*([A-Z]\w*)\s*\{", body, re.M))
        used |= set(re.findall(r"\b([A-Z]\w*)\.[a-zA-Z_]\w*", body))
        used |= set(re.findall(r"property\s+([A-Z]\w*)\s+\w+", body))
        used |= set(re.findall(r":\s*([A-Z]\w*)\s*\{", body))
        # Type annotations on functions count too: a parameter or return type
        # from a module you did not import is the same compile error.
        used |= set(re.findall(r"\w+\s*:\s*([A-Z]\w*)\s*[,)]", body))
        used |= set(re.findall(r"\)\s*:\s*([A-Z]\w*)", body))
        for name in sorted(used):
            mod = owner.get(name)
            if not mod or mod in imports:
                continue
            line = 1
            m = re.search(r"\b" + re.escape(name) + r"\b", code)
            if m:
                line = code.count("\n", 0, m.start()) + 1
            errors.append((r, line,
                           f"uses `{name}` but never imports {mod} — QML refuses the whole "
                           f"file, and a singleton that does not load still answers to its "
                           f"name with nothing in it"))

    # --- novel API surface on a Quickshell type -----------------------------
    # A property or handler that does not exist on a built-in type is not a
    # warning at runtime — QML refuses the whole file, and a singleton that
    # failed to load still answers to its name with nothing on it. The shell
    # proves an API works by running; a member used exactly ONCE in the whole
    # project has never been proven by anything. Reported as a warning, since
    # a first use has to be allowed — but a first use is exactly the moment to
    # go and check the documentation.
    RISKY_TYPES = {
        "Process", "StdioCollector", "SplitParser", "FileView", "JsonAdapter",
        "IpcHandler", "GlobalShortcut", "PanelWindow", "Region", "Variants",
        "LazyLoader", "ScreencopyView", "NotificationServer", "WlSessionLock",
        "WlSessionLockSurface", "PamContext", "SystemClock", "ColorQuantizer",
        "PersistentProperties", "ObjectRepeater", "Socket", "SocketServer",
    }
    seen_members = {}          # (type, member) -> [(file, line), …]
    for path, code in codes.items():
        r = rel(path)
        lines = code.split("\n")
        stack = []
        depth = 0
        for i, line in enumerate(lines, 1):
            m = re.match(r"^\s*([A-Z]\w*)\s*\{", line)
            if m:
                stack.append((depth, m.group(1)))
            elif stack and stack[-1][0] + 1 == depth:
                a = re.match(r"^\s*(?!property\b)(?!readonly\b)(?!function\b)(?!signal\b)([a-z]\w*)\s*:", line)
                if a and stack[-1][1] in RISKY_TYPES:
                    seen_members.setdefault((stack[-1][1], a.group(1)), []).append((r, i))
            depth += line.count("{") - line.count("}")
            while stack and depth <= stack[-1][0]:
                stack.pop()

    # Only worth saying for a type the shell uses in several places: there the
    # API is established by everything that already works, so ONE novel member
    # stands out. A type used in a single file proves nothing either way, and
    # flagging every line of it is noise.
    type_files = {}
    for (kind, member), where in seen_members.items():
        type_files.setdefault(kind, set()).update(f for f, _ in where)

    for (kind, member), where in sorted(seen_members.items()):
        if len(where) > 1 or member == "id":
            continue
        if len(type_files.get(kind, ())) < 2:
            continue
        r, i = where[0]
        # `onSomethingChanged` for a property this very file declares is not
        # novel API at all.
        m = re.match(r"^on([A-Z]\w*)Changed$", member)
        if m:
            own = m.group(1)[0].lower() + m.group(1)[1:]
            src = codes.get(os.path.join(ROOT, r), "")
            if re.search(r"^\s*(readonly\s+)?property\s+[\w<>.]+\s+" + re.escape(own) + r"\b", src, re.M):
                continue
        # FileView's reload-and-save wiring is part of Quickshell's own
        # documented example config (onFileChanged: reload(),
        # onAdapterUpdated: writeAdapter()). Those handlers are per-file by
        # nature, so a single use of one is the documented pattern, not a
        # novel member to verify.
        if kind == "FileView" and member in (
            "onLoaded", "onLoadFailed", "onAdapterUpdated", "onFileChanged",
            "onReloaded", "reload", "writeAdapter",
        ):
            continue
        warnings.append((r, i,
                         f"{kind} {{ {member}: … }} — used nowhere else in the shell, on a "
                         f"type the shell uses everywhere. If that member does not exist, "
                         f"QML refuses this entire file and everything in it goes quiet "
                         f"rather than erroring. Check the documentation before shipping."))

    # --- report -------------------------------------------------------------
    print(f"qmlcheck · {len(files)} files, {len(singletons)} singletons\n")
    if warnings:
        for path, line, msg in warnings:
            print(f"  warn  {path}:{line}  {msg}")
        print()
    if errors:
        seen = set()
        for path, line, msg in errors:
            key = (path, line, msg)
            if key in seen:
                continue
            seen.add(key)
            loc = f"{path}:{line}" if line else path
            print(f"  \033[31mERROR\033[0m {loc}  {msg}")
        print(f"\n{len(set(errors))} problem(s).")
        return 1

    print("  \033[32mAll clear.\033[0m")
    return 0


if __name__ == "__main__":
    sys.exit(main())
