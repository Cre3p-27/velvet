"""_steam.py — put the game controller on Steam's player slot 2.

Steam owns the pad: it reads a DualSense & co. over hidraw and hands every
game a virtual Xbox pad in "XInput slot 0" — player 1 — no matter what the
kernel lists. That order is Steam's own (the "Controller Order" list in its
quick-access menu, which only shows up for a lone pad if it already sits in a
later slot). Steam keeps it in memory, so the only way to change it from
outside is its own UI process, which opens a local Chromium DevTools port when
the file ~/.local/share/Steam/.cef-enable-debugging exists at start-up.

This talks to that port with the standard library only (a few lines of
WebSocket) and runs Steam's own SteamClient.Input.SwapControllerOrder.

    state()              what is possible right now
    enable()             create the flag file (Steam must be restarted once)
    slot(n)              move the lone controller to player n (1..4)
"""
import base64
import json
import os
import socket
import struct
import urllib.request

HOME = os.path.expanduser("~")
PORT = int(os.environ.get("VELVET_STEAM_PORT", "8080"))
HOST = "127.0.0.1"


def steam_root():
    for p in (f"{HOME}/.local/share/Steam", f"{HOME}/.steam/steam", f"{HOME}/.steam/root"):
        if os.path.isdir(p):
            return os.path.realpath(p)
    return ""


def flag_path():
    root = steam_root()
    return os.path.join(root, ".cef-enable-debugging") if root else ""


def steam_pid():
    """Start time (clock ticks since boot) of the running Steam client, or 0."""
    for name in os.listdir("/proc"):
        if not name.isdigit():
            continue
        try:
            with open(f"/proc/{name}/comm") as f:
                comm = f.read().strip()
            if comm != "steam":
                continue
            with open(f"/proc/{name}/stat") as f:
                start = int(f.read().rsplit(")", 1)[1].split()[19])
            return start
        except (OSError, ValueError, IndexError):
            continue
    return 0


def started_at(ticks):
    """Wall-clock time a process with that start tick began."""
    try:
        hz = os.sysconf("SC_CLK_TCK")
        with open("/proc/uptime") as f:
            up = float(f.read().split()[0])
        import time
        return time.time() - up + ticks / hz
    except (OSError, ValueError):
        return 0.0


def port_open():
    try:
        with socket.create_connection((HOST, PORT), 0.4):
            return True
    except OSError:
        return False


# ───────────────────────────────────────────────────────────── tiny WebSocket
class Socket:
    def __init__(self, url_path, timeout=4.0):
        self.s = socket.create_connection((HOST, PORT), timeout)
        key = base64.b64encode(os.urandom(16)).decode()
        self.s.sendall((f"GET {url_path} HTTP/1.1\r\nHost: {HOST}:{PORT}\r\nUpgrade: websocket\r\n"
                        f"Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n").encode())
        head = b""
        while b"\r\n\r\n" not in head:
            chunk = self.s.recv(1024)
            if not chunk:
                raise OSError("closed during handshake")
            head += chunk
        if b" 101 " not in head.split(b"\r\n", 1)[0]:
            raise OSError("websocket refused: " + head.split(b"\r\n", 1)[0].decode(errors="replace"))
        self.rest = head.split(b"\r\n\r\n", 1)[1]
        self.next_id = 0

    def _read(self, n):
        buf = self.rest[:n]
        self.rest = self.rest[n:]
        while len(buf) < n:
            chunk = self.s.recv(n - len(buf))
            if not chunk:
                raise OSError("connection closed")
            buf += chunk
        return buf

    def send(self, text):
        data = text.encode()
        head = bytearray([0x81])
        n = len(data)
        if n < 126:
            head.append(0x80 | n)
        elif n < 65536:
            head.append(0x80 | 126)
            head += struct.pack(">H", n)
        else:
            head.append(0x80 | 127)
            head += struct.pack(">Q", n)
        mask = os.urandom(4)
        head += mask
        self.s.sendall(bytes(head) + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))

    def recv(self):
        out = b""
        while True:
            b0, b1 = self._read(2)
            op = b0 & 0x0F
            n = b1 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self._read(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self._read(8))[0]
            payload = self._read(n)
            if op == 0x8:
                raise OSError("closed by peer")
            if op == 0x9:                     # ping -> pong
                mask = os.urandom(4)
                self.s.sendall(bytes([0x8A, 0x80 | len(payload)]) + mask +
                               bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))
                continue
            if op == 0xA:
                continue
            out += payload
            if b0 & 0x80:
                return out.decode(errors="replace")

    def call(self, method, params=None):
        self.next_id += 1
        mine = self.next_id
        self.send(json.dumps({"id": mine, "method": method, "params": params or {}}))
        while True:
            msg = json.loads(self.recv())
            if msg.get("id") == mine:
                if "error" in msg:
                    raise OSError(f"{method}: {msg['error'].get('message')}")
                return msg.get("result", {})

    def close(self):
        try:
            self.s.close()
        except OSError:
            pass


def targets():
    with urllib.request.urlopen(f"http://{HOST}:{PORT}/json", timeout=2) as r:
        return json.load(r)


def page_paths():
    """DevTools paths of Steam's UI pages, the shared script context first —
    the controller list lives in whichever of them started its input store."""
    pages = [t for t in targets() if t.get("type") == "page" and t.get("webSocketDebuggerUrl")]
    pages.sort(key=lambda t: 0 if "SharedJSContext" in (t.get("title", "") + t.get("url", "")) else 1)
    if not pages:
        raise OSError("Steam's UI context is not open yet")
    return [(t.get("title", ""), t["webSocketDebuggerUrl"].split(str(PORT), 1)[1]) for t in pages]


# JS that runs inside Steam. It finds the controller list in Steam's own
# module store (the object whose GetControllers() the Controller Order menu
# calls) and answers with plain data; with `want` it also swaps the lone pad.
JS = r"""
(async (want) => {
  const SC = window.SteamClient;
  if (!SC || !SC.Input || typeof SC.Input.SwapControllerOrder !== "function")
    return JSON.stringify({ok: false, why: "no-api"});
  let store = window.__velvetPadStore;
  if (!store) {
    const chunk = window.webpackChunksteamui;
    if (!chunk) return JSON.stringify({ok: false, why: "no-webpack"});
    let req;
    chunk.push([[Symbol("velvet")], {}, r => { req = r; }]);
    const cache = req && req.c ? req.c : {};
    outer: for (const id of Object.keys(cache)) {
      let ex;
      try { ex = cache[id].exports; } catch (e) { continue; }
      if (!ex || typeof ex !== "object") continue;
      for (const key of Object.keys(ex)) {
        let v;
        try { v = ex[key]; } catch (e) { continue; }
        if (v && typeof v === "object" && typeof v.GetControllers === "function") { store = v; break outer; }
      }
    }
    if (store) window.__velvetPadStore = store;
  }
  if (!store) return JSON.stringify({ok: false, why: "no-store"});
  const read = () => Array.from(store.GetControllers()).map(c => ({
    index: c.nControllerIndex, slot: c.nXInputIndex, type: c.eControllerType, name: c.strName}));
  let list = read();
  if (want !== null && want !== undefined && list.length === 1 && list[0].slot !== want) {
    SC.Input.SwapControllerOrder(list[0].slot, want);
    await new Promise(r => setTimeout(r, 400));
    list = read();
  }
  return JSON.stringify({ok: true, controllers: list});
})(__WANT__)
"""


def eval_in(path, want):
    ws = Socket(path)
    try:
        ws.call("Runtime.enable")
        res = ws.call("Runtime.evaluate", {
            "expression": JS.replace("__WANT__", "null" if want is None else str(int(want))),
            "awaitPromise": True, "returnByValue": True})
    finally:
        ws.close()
    if "exceptionDetails" in res:
        raise OSError("script: " + str(res["exceptionDetails"].get("exception", {}).get("description", "error"))[:200])
    return json.loads(res["result"]["value"])


def run_js(want):
    """Ask each UI page in turn; the first that knows controllers answers."""
    last = {"ok": False, "why": "no-page"}
    for _title, path in page_paths():
        try:
            res = eval_in(path, want)
        except (OSError, ValueError, KeyError):
            continue
        if res.get("ok") and res.get("controllers"):
            return res
        if res.get("ok") or last.get("why") == "no-page":
            last = res
    return last


# ─────────────────────────────────────────────────────────────── the verbs
def enable():
    """Create the flag file. Returns (changed, path)."""
    path = flag_path()
    if not path:
        return False, ""
    if os.path.exists(path):
        return False, path
    with open(path, "w"):
        pass
    return True, path


def state():
    """{"state": ..., "detail": ...}
         no-steam       Steam is not installed
         idle           Steam is not running
         needs-flag     Steam runs, the DevTools flag file is missing
         needs-restart  the flag is there but this Steam started before it
         closed         flag there, Steam started after it, no port (yet)
         ready          port open, the lone pad's slot is in `slot`
    """
    if not steam_root():
        return {"state": "no-steam", "detail": "Steam is not installed"}
    start = steam_pid()
    if not start:
        return {"state": "idle", "detail": "Steam is not running"}
    flag = flag_path()
    if not os.path.exists(flag):
        return {"state": "needs-flag", "detail": "Steam's controller order needs one switch"}
    if not port_open():
        if os.path.getmtime(flag) > started_at(start):
            return {"state": "needs-restart", "detail": "restart Steam once"}
        return {"state": "closed", "detail": "Steam's UI is still starting"}
    return {"state": "ready", "detail": ""}


def slot(player):
    """Move the lone controller to `player` (1..4). Several controllers are
    left alone — then the order is a choice for the person at the desk.
    Returns {"state": ..., "slot": n, ...}."""
    st = state()
    if st["state"] != "ready":
        return st
    try:
        res = run_js(player - 1)
    except (OSError, ValueError, KeyError) as err:
        return {"state": "error", "detail": str(err)[:160]}
    if not res.get("ok"):
        return {"state": "error", "detail": res.get("why", "unknown")}
    pads = res["controllers"]
    if not pads:
        return {"state": "closed", "detail": "Steam has not found a controller yet"}
    if len(pads) != 1:
        return {"state": "several", "detail": f"{len(pads)} controllers: Steam's order untouched", "controllers": pads}
    ok = pads[0]["slot"] == player - 1
    return {"state": "applied" if ok else "stuck", "slot": pads[0]["slot"] + 1, "controllers": pads,
            "detail": "" if ok else "Steam did not take the new order"}


def peek():
    """The controllers Steam knows, without touching the order."""
    st = state()
    if st["state"] != "ready":
        return st
    try:
        res = run_js(None)
    except (OSError, ValueError, KeyError) as err:
        return {"state": "error", "detail": str(err)[:160]}
    if not res.get("ok"):
        return {"state": "error", "detail": res.get("why", "unknown")}
    return {"state": "ready", "controllers": res["controllers"], "detail": ""}
