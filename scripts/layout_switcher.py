#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
import time
import json
import subprocess
import shutil

bild = sys.argv[1] if len(sys.argv) > 1 else ""
TERMINAL = "kitty" if shutil.which("kitty") else "alacritty"

# Bugfix: einige Branches unten (wallhaven_zyvxvy, train_and_lake,
# wallhaven_qz796r) haben trans_bg benutzt, ohne es vorher zu setzen ->
# NameError bei diesen Wallpapern. Jetzt gibt es einen sinnvollen Default,
# einzelne Branches ueberschreiben ihn bei Bedarf weiterhin lokal.
trans_bg = "-o background_opacity=0.0" if "kitty" in TERMINAL else ""

print("1. Wechsle auf Workspace 1...")
os.system("hyprctl dispatch 'hl.dsp.focus({workspace=1})' >/dev/null 2>&1")
time.sleep(0.5)

print("2. Räume Workspace 1 auf — nur die Layout-Terminals werden beendet...")
try:
    # Fensterliste abrufen und Lua-Warnungen abschneiden
    raw_output = subprocess.check_output(["hyprctl", "clients", "-j"]).decode("utf-8", errors="ignore")
    json_start = raw_output.find('[')

    # WICHTIG: `killall quickshell` ist GESTRICHEN. Velvet malt selbst das
    # Wallpaper — die Shell zu killen macht den Bildschirm schwarz, das sah
    # aus wie ein PC-Absturz.
    LAYOUT_CLASSES = (
        "my_", "wh_", "fd_", "fl_", "bg_", "cat_", "stars_",
        "cd_", "dp_", "tl_", "yk_", "wk_", "shrine_", "pr_"
    )

    def kill_tree(pid):
        pid = int(pid)
        if pid <= 1:
            return
        # Erst der Terminal-Prozess selbst, dann seine Kinder (das eigentliche
        # Programm) — sonst überleben verwaiste python3-Prozesse den Wechsel.
        os.system(f"kill -TERM {pid} >/dev/null 2>&1")
        os.system(f"pkill -TERM -P {pid} >/dev/null 2>&1")
        time.sleep(0.8)
        if os.system(f"kill -0 {pid} >/dev/null 2>&1") == 0:
            os.system(f"kill -KILL {pid} >/dev/null 2>&1")
            os.system(f"pkill -KILL -P {pid} >/dev/null 2>&1")

    if json_start != -1:
        fenster_liste = json.loads(raw_output[json_start:])

        for f in fenster_liste:
            ws_id = str(f.get("workspace", {}).get("id", ""))
            pid = f.get("pid")
            cls = f.get("class", "Unbekannt")
            addr = f.get("address", "")

            # NUR Workspace 1 wird angefasst — andere Desktops bleiben, wie
            # sie sind.
            if ws_id != "1":
                continue

            if cls.startswith(LAYOUT_CLASSES) and pid:
                # Unsere eigenen Layout-Terminals: kompletten Prozessbaum
                # beenden, keine kitty-Rückfrage.
                print(f" -> RÄUME AB: {cls} (PID {pid})")
                kill_tree(pid)
            elif addr:
                # Fremde Fenster auf Workspace 1: höflich schließen (Programme
                # können noch nachfragen/speichern), niemals kill -9.
                print(f" -> SCHLIESSE: {cls}")
                os.system(f"hyprctl dispatch closewindow address:{addr} >/dev/null 2>&1")
except Exception as e:
    print(f"Fehler beim Aufräumen: {e}")

# Kurze Pause, damit die Fenster sauber zu sind
time.sleep(1.0)

print(f"3. Starte neues Layout für {os.path.basename(bild)}...")
# Wir nutzen deine nativen Klassen (my_peaclock, my_cava etc.), 
# damit die Floating-Regeln aus deinem Setup greifen.

if "Anime-City-Night.png" in bild:
    os.system(f"{TERMINAL} --class my_peaclock --hold -e btop &")
    os.system(f"{TERMINAL} --class my_lavat --hold -e cmatrix &")
    os.system(f"{TERMINAL} --class my_cava --hold -e cava &")

elif "retro_city.gif" in bild:
    os.system(f"{TERMINAL} --class my_sptlrx --hold -e fastfetch &")
    os.system(f"{TERMINAL} --class my_peaclock --hold -e htop &")
    os.system(f"{TERMINAL} --class my_cava --hold -e cava &")

elif "anime-eye-nord.png" in bild:
    # cava: Zentriert, flach & elegant
    os.system(f"{TERMINAL} --class my_cava --hold -e cava &")
    
    # sptlrx: Oben Rechts, schmal (Spotify Lyrics)
    os.system(f"{TERMINAL} --class my_sptlrx --hold -e sptlrx &")
    
    # cbonsai: Unten Rechts (Mit Parameter '-l' für Live-Wachstum)
    os.system(f"{TERMINAL} --class my_cbonsai --hold -e cbonsai -l &")
    
    # lavat: Oben Links
    os.system(f"{TERMINAL} --class my_lavat --hold -e lavat &")
    
    # peaclock: Oben Mitte
    os.system(f"{TERMINAL} --class my_peaclock --hold -e peaclock &")

elif "wallhaven_dp19wl_3840x2160.jpg" in bild:
    # cava: Flach auf dem Boden liegend
    os.system(f"{TERMINAL} --class wh_cava --hold -e cava &")
    
    # peaclock: Oben links
    os.system(f"{TERMINAL} --class wh_clock --hold -e peaclock &")
    
    # sptlrx: Spotify Lyrics links unter der Uhr
    os.system(f"{TERMINAL} --class wh_lyrics --hold -e sptlrx &")
    
    # cbonsai: Oben rechts (Mit Live-Animation)
    os.system(f"{TERMINAL} --class wh_bonsai --hold -e cbonsai -l &")

elif "Fuji-Dark" in bild:
    # peaclock: Oben links im Dämmerungshimmel
    os.system(f"{TERMINAL} --class fd_clock --hold -e peaclock &")
    
    # sptlrx: Lyrics links unter der Uhr
    os.system(f"{TERMINAL} --class fd_lyrics --hold -e sptlrx &")
    
    # bottom: Eleganter System-Monitor unten links
    os.system(f"{TERMINAL} --class fd_sys --hold -e bottom &")
    
    # cava: Breit über der dunklen Stadtmitte
    os.system(f"{TERMINAL} --class fd_cava --hold -e cava &")

elif "Fuji_light" in bild:
    # peaclock: Oben links im hellen Himmel
    os.system(f"{TERMINAL} --class fl_clock --hold -e peaclock &")
    
    # sptlrx: Lyrics links unter der Uhr
    os.system(f"{TERMINAL} --class fl_lyrics --hold -e sptlrx &")
    
    # bottom: System-Monitor unten links
    os.system(f"{TERMINAL} --class fl_sys --hold -e bottom &")
    
    # cava: Breit über der Stadtmitte
    os.system(f"{TERMINAL} --class fl_cava --hold -e cava &")

elif "Beer-Girl" in bild:
    # peaclock: Oben links
    os.system(f"{TERMINAL} --class bg_clock --hold -e peaclock &")
    
    # sptlrx: Lyrics links an der Seite
    os.system(f"{TERMINAL} --class bg_lyrics --hold -e sptlrx &")
    
    # bottom: Im rechten Vorhang versteckt
    os.system(f"{TERMINAL} --class bg_sys --hold -e bottom &")
    
    # cava: Zwischen Katze und Mädchen
    os.system(f"{TERMINAL} --class bg_cava --hold -e cava &")

elif "kitty_dark" in bild:
    # Dieser Parameter zwingt Kitty dazu, den Hintergrund komplett unsichtbar zu machen
    trans_bg = "-o background_opacity=0.0" if "kitty" in TERMINAL else ""
    
    # Wir nutzen 'unimatrix' für den sauberen, transparenten Matrix-Effekt (-c yellow färbt es gelb)
    os.system(f"{TERMINAL} {trans_bg} --class cat_matrix --hold -e unimatrix -c yellow &")
    
    # Auch die Uhr und die Rohre bekommen den komplett unsichtbaren Hintergrund!
    os.system(f"{TERMINAL} {trans_bg} --class cat_clock --hold -e tty-clock -c -C 3 -D &")
    os.system(f"{TERMINAL} {trans_bg} --class cat_pipes --hold -e pipes.sh -p 4 -t 2 &")
    os.system(f"{TERMINAL} {trans_bg} --class cat_cava --hold -e cava &")

elif "wallhaven_zyvxvy" in bild:
        os.system(f"{TERMINAL} {trans_bg} --class stars_cava --hold -e cava &")
        time.sleep(0.3)
        # Uhr oben rechts in Gelb/Gold (-C 3) passend zur Beleuchtung
        os.system(f"{TERMINAL} {trans_bg} --class stars_clock --hold -e tty-clock -c -C 3 -D &")

elif "City_dark" in bild:
    # Sicherheits-Setup für absolute Transparenz (keine grauen Boxen mehr!)
    trans_bg = "-o background_opacity=0.0 -o background_tint=0.0 -o window_padding_width=0" if "kitty" in TERMINAL else ""
    
    # 1. Cava als breites, borderless Fundament auf der Straße
    os.system(f"{TERMINAL} {trans_bg} --class cd_cava --hold -e cava &")
    time.sleep(0.4)
    
    # 2. Uhr auf dem Billboard (-C 1 für Neon-Rot passend zur Stadt)
    os.system(f"{TERMINAL} {trans_bg} --class cd_clock --hold -e tty-clock -c -C 1 -D &")
    time.sleep(0.4)
    
    # 3. Lavat im Himmel (Bugfix: -c red statt -c 3 verwenden, -s 1 für Slow-Motion!)
    os.system(f"{TERMINAL} {trans_bg} --class cd_lavat --hold -e lavat -s 1 -c red &")

elif "dark_pixelart" in bild:
    trans_bg = "-o background_opacity=0.0" if "kitty" in TERMINAL else ""
    
    # Lavat: Langsam und rot
    os.system(f"{TERMINAL} {trans_bg} --class dp_portal --hold -e lavat -s 1 -c red &")
    
    # tty-clock: Clean, schwebend, rote Digitalanzeige
    os.system(f"{TERMINAL} {trans_bg} --class dp_clock --hold -e tty-clock -c -C 1 -D &")

elif "train_and_lake" in bild:
        os.system(f"{TERMINAL} {trans_bg} --class tl_cava --hold -e cava &")
        time.sleep(0.3)
        # Uhr unten im Wasser, Farbe Cyan (-C 6) passend zum See
        os.system(f"{TERMINAL} {trans_bg} --class tl_clock --hold -e tty-clock -c -C 6 -D &")

elif "yellow_kyoto" in bild:
    trans_bg = "-o background_opacity=0.0" if "kitty" in TERMINAL else ""
    
    # 1. TTY-Clock oben links (mit warmem Gelbton -C 3)
    os.system(f"{TERMINAL} {trans_bg} --class yk_clock --hold -e tty-clock -c -C 3 -D &")
    time.sleep(0.4)
    
    # 2. Lavat oben rechts im Himmel (-c 3 für passenden Amber/Orange-Ton, -s 1 für Gemütlichkeit)
    os.system(f"{TERMINAL} {trans_bg} --class yk_lavat --hold -e lavat -s 1 -c yellow &")
    time.sleep(0.4)
    
    # 3. Cbonsai auf den Dächern rechts (-l für ewiges Wachstum)
    os.system(f"{TERMINAL} {trans_bg} --class yk_bonsai --hold -e cbonsai -l &")
    time.sleep(0.4)
    
    # 4. Cava unten als Audio-Equalizer
    os.system(f"{TERMINAL} {trans_bg} --class yk_cava --hold -e cava &")

elif "weeknd" in bild:
    # 0.0 Transparenz + 0 Padding für absolut nahtlose, borderlose Kanten am Boden
    trans_bg = "-o background_opacity=0.0 -o window_padding_width=0" if "kitty" in TERMINAL else ""
    
    # 1. Cava (Natives Stereo: Links & Rechts treffen sich exakt in der Mitte)
    os.system(f"{TERMINAL} {trans_bg} --class wk_cava --hold -e cava &")
    time.sleep(0.4)
    
    # 2. TTY-Clock oben rechts (mit rotem Neon-Ton -C 1)
    os.system(f"{TERMINAL} {trans_bg} --class wk_clock --hold -e tty-clock -c -C 1 -D &")
    time.sleep(0.4)
    
    # 3. Pipes oben links als Neon-Akzent
    os.system(f"{TERMINAL} {trans_bg} --class wk_pipes --hold -e pipes.sh -p 3 -t 0 &")

elif "wallhaven_qz796r" in bild:
        # Lavat sicher starten: dunkelgrün und langsam
        os.system(f"{TERMINAL} {trans_bg} --class shrine_lavat --hold -e lavat -s 1 -c green &")
        time.sleep(0.4)
        # Ultra Wide Stereo Cava
        os.system(f"{TERMINAL} {trans_bg} --class shrine_cava --hold -e cava &")

elif "persona_reload" in bild:
    # 1. Terminal Widgets für den Hintergrund (falls gewünscht)
    trans_bg = "-o background_opacity=0.0 -o window_padding_width=0" if "kitty" in TERMINAL else ""
    os.system(f"{TERMINAL} {trans_bg} --class pr_cava --hold -e cava &")
    
    # 2. Quickshell Persona Menü im Hintergrund laden (unsichtbar, wartet auf Tastendruck)
    # WICHTIG: Das & am Ende lässt es im Hintergrund laufen!
    os.system("quickshell -p ~/.config/quickshell/persona/ &")

elif "widgets_layout" in bild:
    # Hier laden wir die isolierten Widgets aus Projekt 2 dauerhaft auf den Desktop
    os.system("quickshell -p ~/.config/quickshell/desk_widgets/ &")






print("=== Fertig! ===")
