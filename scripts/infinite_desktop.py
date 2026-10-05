#!/usr/bin/env python3
import os
import time
import subprocess

# Monitorname: per CLI-Argument, sonst ENV-Variable, sonst Fallback.
# Herausfinden mit: hyprctl monitors -j | grep '"name"'
MONITOR = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("INFINITE_DESKTOP_MONITOR", "HDMI-A-1")
BIND_CONF = os.path.expanduser("~/.config/hypr/inf_binds.conf")

def run(cmd):
    subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

os.system('clear')
print("=== INFINITE DESKTOP: THE CAMERA HACK ===")

# 1. Erschaffe die 11.5K Virtual Canvas (Scale 0.3333)
print("-> Erschaffe gigantische virtuelle Map...")
run(f"hyprctl keyword monitor {MONITOR},preferred,auto,0.333333")

# 2. Setze die Kamera sofort auf 300%, damit alles normal aussieht
print("-> Setze Kamera auf Normalansicht (3.0x)...")
run("hyprctl keyword cursor:zoom_factor 3.0")
run("hyprctl keyword misc:cursor_zoom_factor 3.0")

# 3. Keybinds (Pfeiltasten zum Zoomen, ESC zum Not-Aus)
with open(BIND_CONF, "w") as f:
    f.write("binde = SUPER, up, exec, echo 'zoom_in' > /tmp/inf_pipe\n")
    f.write("binde = SUPER, down, exec, echo 'zoom_out' > /tmp/inf_pipe\n")
    f.write("bind = SUPER, escape, exec, echo 'quit' > /tmp/inf_pipe\n")
run(f"hyprctl keyword source {BIND_CONF}")

if not os.path.exists("/tmp/inf_pipe"):
    os.mkfifo("/tmp/inf_pipe")

# Start-Variablen
zoom = 3.0
target_zoom = 3.0

print("\n-> System Online!")
print("-> STEUERUNG:")
print("   SUPER + Pfeil Runter = Kamera herauszoomen (Übersicht)")
print("   SUPER + Pfeil Hoch   = Kamera heranzoomen (Arbeitsmodus)")
print("   SUPER + ESC          = Engine beenden & Desktop fixen")

try:
    while True:
        # Lese Input
        if os.path.exists("/tmp/inf_pipe"):
            with open("/tmp/inf_pipe", "r") as f:
                cmd = f.readline().strip()
                # Bei 1.0 siehst du den gesamten 11.5K Desktop, Fenster sind winzige Texturen.
                if cmd == "zoom_out": target_zoom = max(1.0, target_zoom - 0.15)
                # Bei 3.0 bist du wieder normal drin
                if cmd == "zoom_in": target_zoom = min(3.0, target_zoom + 0.15)
                if cmd == "quit": raise KeyboardInterrupt
        
        # Interpolierte, weiche Kamerafahrt
        if abs(zoom - target_zoom) > 0.01:
            zoom += (target_zoom - zoom) * 0.15
            run(f"hyprctl keyword cursor:zoom_factor {zoom:.3f}")
            run(f"hyprctl keyword misc:cursor_zoom_factor {zoom:.3f}")
        
        # FPS-Limit der Python-Schleife (wir brauchen hier kein Mathe mehr, Wayland macht alles!)
        time.sleep(0.016)

except KeyboardInterrupt:
    # WICHTIG: Setzt alles wieder in den Normalzustand zurück, wenn du beendest!
    print("\n-> Beende Engine. Stelle normale Auflösung wieder her...")
    run(f"hyprctl keyword monitor {MONITOR},preferred,auto,1.0")
    run("hyprctl keyword cursor:zoom_factor 1.0")
    run("hyprctl keyword misc:cursor_zoom_factor 1.0")
    if os.path.exists(BIND_CONF): os.remove(BIND_CONF)
