"""
VELVET · bin/_gpu.py

Two questions every local model on this machine has to ask, answered once:

  · **Which card?**  llama.cpp's Vulkan build offers every Vulkan device it
    finds — here the Radeon RX 9070 XT AND the Ryzen's integrated graphics,
    which reports 16 GB because it borrows the system RAM. Left alone,
    llama.cpp splits a model across both, and the share on the iGPU crawls.
    `pick_device()` names the discrete card for `--device`.

  · **Is somebody gaming?**  A fullscreen game owns the graphics card; a model
    loading 12 GB or generating beside it makes it stutter. `game_running()`
    is the same check the voice has always used.

Stdlib only, like everything in bin/.
"""

import json
import os
import re
import subprocess
import time

HOME = os.path.expanduser("~")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"), "velvet", "gpu-device.json")

# Names that are not a graphics card of their own: an APU's integrated
# graphics (RADV names it after the CPU), a software rasteriser, and plain
# "… Graphics" iGPUs. A discrete card that happens to say "Graphics" (Intel
# Arc) keeps its place.
NOT_A_CARD = re.compile(r"Processor|llvmpipe|lavapipe|SwiftShader|Software|\bCPU\b", re.I)
IGPU = re.compile(r"\b(UHD|HD|Iris|Radeon)\s+Graphics\b|\bGraphics\s*\(RADV", re.I)
DISCRETE_HINT = re.compile(r"\b(RX|Pro|Arc|GeForce|RTX|GTX|Quadro|Titan|Instinct|FirePro)\b", re.I)

DEVICE_LINE = re.compile(r"^\s*(\w+?\d+):\s*(.+?)\s*\((\d+)\s*MiB,\s*(\d+)\s*MiB free\)\s*$")


def boot_id() -> str:
    try:
        with open("/proc/sys/kernel/random/boot_id", "r", encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return ""


def list_devices(server: str) -> list:
    """[{id: "Vulkan0", name, total, free}] as llama-server reports them."""
    if not server or not os.path.isfile(server):
        return []
    env = dict(os.environ)
    env["LD_LIBRARY_PATH"] = os.path.dirname(server) + (":" + env["LD_LIBRARY_PATH"] if env.get("LD_LIBRARY_PATH") else "")
    try:
        proc = subprocess.run([server, "--list-devices"], capture_output=True, timeout=20, env=env)
    except (OSError, subprocess.TimeoutExpired):
        return []
    out = []
    text = (proc.stdout + proc.stderr).decode("utf-8", "replace")
    for line in text.splitlines():
        match = DEVICE_LINE.match(line)
        if match:
            out.append({"id": match.group(1), "name": match.group(2),
                        "total": int(match.group(3)), "free": int(match.group(4))})
    return out


def score(dev: dict) -> int:
    name = dev.get("name") or ""
    if NOT_A_CARD.search(name):
        return 0
    if IGPU.search(name) and not DISCRETE_HINT.search(name):
        return 1
    return 2


def pick_device(server: str) -> str:
    """The id to hand llama-server as `--device`, or "" to let it decide
    (one device only, or nothing recognisable). VELLY_DEVICE overrides.
    Cached per boot — the list only changes when the hardware does."""
    forced = (os.environ.get("VELLY_DEVICE") or "").strip()
    if forced:
        return forced
    try:
        mtime = os.path.getmtime(server)
    except OSError:
        return ""
    try:
        with open(CACHE, "r", encoding="utf-8") as fh:
            cached = json.load(fh)
        if cached.get("boot") == boot_id() and cached.get("server") == server and cached.get("mtime") == mtime:
            return str(cached.get("device") or "")
    except (OSError, ValueError):
        pass
    devices = list_devices(server)
    chosen = ""
    if len(devices) > 1:
        best = max(devices, key=lambda d: (score(d), d["free"]))
        if score(best) > 0:
            chosen = best["id"]
    try:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE, "w", encoding="utf-8") as fh:
            json.dump({"boot": boot_id(), "server": server, "mtime": mtime, "device": chosen,
                       "devices": devices, "at": int(time.time())}, fh)
    except OSError:
        pass
    return chosen


def game_running() -> bool:
    """A fullscreen game (or a known game launcher window) has the card."""
    try:
        out = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, timeout=1.5, text=True).stdout
        win = json.loads(out or "{}")
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return False
    cls = str(win.get("class") or "").lower()
    full = int(win.get("fullscreen") or 0) > 0
    gamey = cls.startswith("steam_app") or cls in ("gamescope", "steam_proton") or ".exe" in cls \
        or any(k in cls for k in ("minecraft", "lutris", "heroic", "wine", "retroarch", "osu"))
    return gamey or (full and cls not in ("google-chrome", "firefox", "mpv", "vlc", "chromium", "brave-browser"))


if __name__ == "__main__":
    import sys
    srv = sys.argv[1] if len(sys.argv) > 1 else ""
    for dev in list_devices(srv):
        print(f"{dev['id']}: {dev['name']} · {dev['free']} of {dev['total']} MiB free · score {score(dev)}")
    print("pick:", pick_device(srv) or "(let llama.cpp decide)")
    print("game running:", game_running())
