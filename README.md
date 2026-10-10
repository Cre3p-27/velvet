# VELVET

**Many desktops in one.** A Quickshell desktop for Hyprland: arcade, glass,
terminal, newspaper, neumorph, clay, Windows 95 to 11 — every look changes the
bar, the settings, the launcher, the notifications, the lock screen and the
sounds, and every part can be tuned. An infinite desktop with a real zoom-out
comes with it.

## New to Linux? Three steps

1. **Use an Arch-based system with Hyprland** — for example
   [EndeavourOS](https://endeavouros.com) or [CachyOS](https://cachyos.org), and pick
   *Hyprland* during installation (or install it later: `sudo pacman -S hyprland`).
2. **Open a terminal and paste this one line:**

   ```bash
   curl -fsSL https://raw.githubusercontent.com/Cre3p-27/velvet/main/get.sh | bash
   ```

   It downloads Velvet, installs everything that is missing (it asks for your
   password once), downloads the fonts, wires up Hyprland and adapts the shell to
   your screen, your wallpapers and your current Hyprland settings.
3. **Log out and back in.** A welcome page opens and shows you the first steps.

Updating later: **Super+Tab → SHELL → UPDATE & REPAIR** — it downloads the newest Velvet, brings its
Hyprland files up to date, rebuilds and swaps the zoom plugin and restarts the shell, all in one go (or run the
same install line again). Velvet checks this by itself after it starts and tells you when something is out of step.  
**Removing Velvet completely:** Super+Tab → SHELL → *Uninstall Velvet* — or in a terminal:

```bash
bash ~/.config/quickshell/velvet/uninstall.sh
```

It stops the shell and removes everything it installed: the shell, its Hyprland
lines and files (your config gets back exactly what it had before), its programs,
fonts and settings. Velly's models and voices (they can be tens of gigabytes) are
only deleted after it has told you how big they are — `--keep-ai` keeps them,
`--keep-config` keeps your settings. Packages like Hyprland stay — other programs
may use them.

**Settings in a knot?** Super+Tab → SHELL → *Reset all settings* puts every
setting back to a fresh start (looks, desktops and wallpapers stay; the old file
is kept as `config.json.before-reset-<date>`).

**If something goes wrong:** the shell is started by `velvet-session`, which
starts it again when it crashes. If you use Velvet's lock as the login screen
(LOCK AT BOOT) and the lock cannot come up, the session is never left open:
hyprlock locks it instead, or the session ends and the login screen asks for the
password. Its log: `$XDG_RUNTIME_DIR/velvet-session.log`.

No wallpapers yet? The installer starts `~/Pictures/Wallpapers` with three of
Velvet's own — add your pictures there.

### The keys you need first

| | |
|---|---|
| `Super + Tab` | settings — opens fullscreen, just start typing to search |
| `Super + Space` | launch apps |
| `Super + N` | notifications |
| `Super + Escape` | power menu |
| `Super + L` | lock the screen |
| `Super + Z` / `X` | previous / next desktop |
| `Super + D` | floating ⇄ tiled windows |
| `Super + Alt + mouse wheel` | zoom out over the whole desktop |
| `Super + Alt + right click` | every window at a glance · `left click` back to 1:1 |
| `Super + W` | wallpapers |
| `Super + Shift + K` | every shortcut on one screen |

---

# (the full guide)

A Quickshell desktop for Hyprland. The bar is narrow and quiet — it gets out
of the way. The settings menu is not: `Super+Tab` throws
a Persona-style overlay across the screen, and every single thing the shell can
do lives in it.

Nothing here patches anyone else's config. Velvet owns its own state, so a
slider moves and the bar changes **while you are still dragging it**.

---

## Install

```bash
git clone <this> velvet && cd velvet
./install.sh
hyprctl reload
~/.config/quickshell/velvet/bin/velvet-session &   # or log out and in
```

`install.sh` symlinks the folder into `~/.config/quickshell/velvet`, wires up
Hyprland (with a backup of your config), reads your **current** Hyprland
settings so the first launch changes nothing about your desktop, sizes the bar
for your actual panel, and tells you which optional tools are missing.
Re-running it is safe — it never touches an existing `config.json`.

### What you need

| | |
|---|---|
| **Required** | `quickshell` (0.2+), `hyprland` |
| **Strongly recommended** | `wpctl` (pipewire), `brightnessctl`, `nmcli`, a Material Symbols font, a heavy display font |
| **Optional** | `bluetoothctl`, `swww` / `hyprpaper` / `swaybg`, `hyprsunset` / `wlsunset`, `pw-play`, `playerctl`, `ddcutil`, `wl-clipboard`, `ollama` (another local brain). For Velly nothing here is required: her local brain, ears and voice are fetched by her own SETUP (`bin/velvet-local`), and `piper-tts` or `espeak-ng` are only needed if you would rather pick a voice yourself |

On Arch:

```bash
paru -S quickshell-git otf-material-symbols-git ttf-archivo \
        brightnessctl swww hyprsunset playerctl wl-clipboard
```

No AUR helper? The two fonts are the only AUR packages that matter, and both are
freely licensed, so you can drop them in by hand:

```bash
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts
curl -fLO 'https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf'
curl -fLO 'https://github.com/google/fonts/raw/main/ofl/archivo/Archivo%5Bwdth%2Cwght%5D.ttf'
fc-cache -f
```

Everything optional degrades quietly. No bluetooth adapter means no bluetooth
icon, not a broken bar.

---

## Keys

| | |
|---|---|
| `Super + Tab` | Settings |
| `Super + Space` | Launcher |
| `Super + N` | Notifications |
| `Super + Escape` | Power menu |
| `Super + M` | The mini desktop |
| `Super + L` | Lock the screen |
| `Super + Enter` | Record the screen · stop |
| `Super + Shift + S` | Open the desktop you arranged |
| `Super + Shift + F` | Focus mode on · off |
| `Super + W` | Wallpaper wheel |
| `Super + Shift + L` | Lyrics |
| `Super + Shift + K` | Every shortcut, on one screen |

`Super+Tab` opens on one screen and stays there. It lands on a front page:
nothing but the categories, lined up down the **right** edge with the big word
beside them. Click one — or press `→`/`Enter` — and the rail glides to the
left while that category's settings unfold on the right. A page (MODULES →
TASKBAR, LOCK SCREEN → CLOCK & SOUND …) opens as a **sub-tab of its own**: the
list slides over to just that page, a banner says what it is for, the
breadcrumb on top (`MODULES › TASKBAR › WORKSPACES`) takes you back to any
level with a click, and the category in the rail shows where you are. `Esc`,
`Backspace`, `←` or BACK step out again and land on the row you came from.

Every setting explains itself: the strip under the list describes the row
under the cursor in whole sentences — what it does, where you see it, what it
works with. The search also finds words in those explanations ("frost" finds
BLUR).

Nothing is dimmed into illegibility any more either. The cursor is a bar and a
lift; every other row stays readable, because reading them is the point.

Inside the settings menu:

| | |
|---|---|
| `↑ ↓` | move |
| `← →` | switch column · move a slider · flip a toggle · step a choice · `→` opens a page, `←` steps out |
| `Enter` | open a category · open a page · unfold a slider or a choice · flip a toggle |
| `Space` | toggle |
| `Esc` `Backspace` · mouse back button | one step back: close an unfolded row, leave a page, back to the categories |
| `Tab` | next category |
| `Ctrl + ← →` | adjust in big steps |
| `PgUp PgDn` | jump five rows |
| `Ctrl + 1…9` | jump straight to a category |
| **any letter** | **search every setting in the shell** |
| `F1` or `?` | every shortcut in the shell, on one screen |
| `Esc` on the categories | close |

`F1` opens a help overlay listing every binding in every context. It renders
`config/Shortcuts.qml` and nothing else, so what it shows is what exists.

That last one is the important one. There are about 360 settings and pages
across twelve categories; typing `blur` or `gaps` or `wifi` from anywhere jumps
you straight at the right row, three levels deep if that's where it lives —
and typing the name of a page (`arrange by hand`, `soft lock`) opens the page.
You never have to remember which category something is in.

The launcher searches them too. `Super+Space`, type `blur`, and the setting
shows up under the apps with a `SETTING` tag; `Enter` opens the menu already
scrolled to that row. Turn it off in **SHELL → LAUNCHER → SEARCH SETTINGS TOO**
if you only ever want apps there.

The mouse does everything the keyboard does, and the two never fight:

- **Hovering** only lights a row up (and its explanation shows at the bottom);
  it never moves the cursor, so the **wheel** scrolls the list smoothly, one
  row per notch, and never changes a value it rolls over.
- **Click** a row to use it: a toggle flips, a page opens, a **slider unfolds**
  under its row (the row itself shows the value and a small gauge) with − and +
  beside it, a **choice unfolds** into all its options as chips. `‹ ›` on a
  choice step through it without unfolding.
- Dangerous actions (RESTART, SHUT DOWN, LOG OUT, FORGET EVERY LOOK, RESET
  ARRANGEMENT) ask for a second click within a few seconds.
- The categories on the left light up under the pointer and open on a click —
  passing over them no longer swaps the list.
- The mouse's **back** button walks one step back (it never closes the menu);
  **forward** opens the page under the cursor.

Right-clicking a module in the bar opens the setting that controls *that*
module — right-click the clock for clock settings, the weather for its
location, the launcher button for the launcher's own page.

Rows are deliberately large. If they're too large, or not large enough:
**VISUALS → ROW SIZE** has three steps — compact, comfortable, spacious — and it
scales the row height, the label, the value and the spacing together, so a row
never ends up big with small text in it.

---

## What's in it

**LOOKS — one click, a whole shell** (`Super+Tab → LOOKS`, the first tab).
Four whole-shell presets as cards, each a little picture of the look on *your*
wallpaper:

- **SAKURA** — plum and pink, a thin top bar in a
  rounded screen frame, cava bars hanging from the top, the greeting lock, soft
  type, soft widgets.
- **SOFT LOCK** — only the lock: a big two-tone
  clock over round pills, the password with its pencil, cava bars on top.
- **EMBER** — warm brown and peach, a slim left bar, a wave
  dripping from the top, the three-line lyric card, a one-line lock clock.
- **VELVET** — the house look: Persona type, tilt, halftone, the FLUID lock.

A look only writes ordinary settings, so every part stays tunable in its own
row — and the other way round: build a setup by hand and **SAVE WHAT I HAVE AS
A LOOK** turns it into a card of your own (`looks-custom.json`, `ipc call looks
save` / `remove <id>`), which puts all of it back with one click later. The first look you put on remembers your own setup (`looks-before.json`);
**BACK TO MY OWN LOOK** restores it exactly, **KEEP THIS LOOK** forgets it.
*Use the look's colours* off keeps your wallpaper palette. From a terminal:
`qs -c velvet ipc call looks apply sakura` · `… looks undo` · `… looks list`.

The pieces the looks are made of are settings of their own:

- **TYPE STYLE** (VISUALS): *Persona* (heavy, italic) or *Soft* (round, upright,
  the first installed of Google Sans / DM Sans / Plus Jakarta Sans / Outfit /
  Inter / Adwaita Sans …).
- **TASKBAR → STYLE**: *Velvet* (halftone, hairline, wedge), *Clean* (a plain
  strip) or *Floating* (a pill that hugs its modules — clicks beside it go to
  the windows); **BAR COLOUR** surface, tone or black. **SCREEN FRAME** draws a
  thin frame round the desktop with rounded corners inside. Like the bar it
  sits on the top layer — above every window and the desktop's cava, below a
  fullscreen app — and takes no input — **CONNECT TO THE TASKBAR** makes bar and
  frame one surface, plus FRAME WIDTH, CORNERS, COLOUR (bar · tone · black ·
  accent), OPACITY, SHADOW and OUTLINE. **WORKSPACES → STYLE**: slash, pills, dots, numbers.
- **SOFT TONE** (VISUALS): the colour of every round pill — the accent's deep
  shade (with TONE COLOUR and TONE LIGHTNESS), surface or black.
- Lock: **CLOCK COLOURS** (two-tone · accent · ink) and **BAR DENSITY** of the
  visualizer (fine · normal · wide); the desktop's cava has its own density.
- **WIDGET FRAME → SOFT** (WALLPAPER → LIVING DESKTOP): the clock in a gear with
  its hands, the weather in a slanted pill, the music card (wavy cover, ring,
  five buttons, a squiggle timeline), the date in a pentagon, the greeting in
  a cloud — each can wear any of the sixteen shapes instead. Other widgets
  keep the SHAPES drawing.
- **LYRICS → MODE → STACK**: the line before, the line now, the line next, on a
  card over the blurred cover.

**The bar** — twenty-one modules to choose from: logo, workspaces, active window,
tray, clock, status cluster, power, now-playing, a live CPU/memory graph,
weather, a notification bell, microphone state, keyboard layout, uptime, a
screenshot button, a launcher button, a focus-mode switch, a desktop-scene
button, a mini-desktop button, a lyrics beat, and separators and spacers for
shaping the rest. Docks to any of the four edges, switchable at runtime from the menu; the
modules re-arrange themselves rather than being duplicated for each orientation.
Pin it open or let it hide until the pointer touches the edge. Scrolling over it
changes workspace, volume or brightness depending on where the pointer is.

**The LAYOUT tab** — its own category in `Super+Tab`, and an editor rather than
a list. A picture of your screen with the bar on it: **click an edge** to move
the bar there, **drag the bar's inner edge** to make it thicker. Underneath, the
modules as big chips in bar order — drag to reorder, drag off the strip to
remove, and the tray below holds everything not currently on the bar.

**Click a module and its own settings appear beside it**: the clock's format
next to the clock, the weather's location next to the weather, the map's hover
zone next to the map. That is the whole reason this is a tab and not a dialog —
arranging the bar and configuring what is on it are the same job, and they used
to be three levels apart.

Five presets to start from, because an empty bar is a bad place to begin.
Everything commits the moment you touch it, and because the real bar is drawn
*on top of* the settings overlay, you are watching your actual taskbar change,
not a preview of one.

Keyboard: `← →` selects, `Shift+← →` moves, `Del` removes.

**The quick panel** — hover the status cluster. Volume, mic, brightness and the
shell's own sounds — Velvet's clicks have their own fader, because turning the
menu clicks down must never touch your music — plus bluetooth, night light,
keep-awake, do-not-disturb and focus mode.

**The desktop** — a second editor tab, and the answer to "I always open the
same four things in the same four places".

**Super+Tab → DESKTOP** shows a picture of your screen with your wallpaper on
it. Underneath is a tray: the little terminal programs Velvet ships, and every
application you have installed with a search box over them. Drag one onto the
screen and it is on your desktop — drag it around, pull its corner to resize
it, pick which workspace it opens on, toggle whether it is placed exactly or
left to the tiler. Seven snap targets (full, halves, thirds, a corner) are one
click away, and a 24-step grid holds things in line while you drag, which the
SNAP pill turns off.

That arrangement is remembered **against the wallpaper that is up**, so a
wallpaper stops being a picture and becomes a desk with things on it. On login
the scene for the current wallpaper opens itself — skipping anything already
running, so restarting the shell does not give you four clocks. **Super+Shift+S**
opens whatever is missing at any time, and the bar's DESKTOP module says at a
glance whether the scene is complete. One button copies the arrangement to
every wallpaper; another captures the windows you already have open and turns
them into a scene, which is usually faster than placing them by hand.

**Windows on a desktop: NORMAL · TILING · FLOATING.** The card beside the picture
decides how windows sit on the desktop you are editing — as Hyprland and your
rules say, every window tiled, or every window floating (the infinite canvas).
New windows open in that mode (dialogs stay floating), the ones already there
follow when you switch, and a window you carry onto the desktop takes it on.
After that a window is yours: `Super+V` / `Super+D` still toggle it. From a
terminal or a key: `qs -c velvet ipc call wsmode set 3 tiling`.

Launching is belt-and-braces on purpose. Hyprland's `exec` window rules place
the window as it opens — the version with no flicker — and then, once the
window really exists, the same geometry is applied again through ordinary
dispatches, and measured a beat later in case it did not take.

**The programs Velvet ships** — six of them, in `bin/`, each a single
stdlib-only Python file. They are terminal programs on purpose: a terminal
window is something Hyprland already knows how to float, size, pin and rule, so
a clock you drop on the desktop behaves like every other window rather than
like a widget with its own set of problems.

| | |
|---|---|
| `velvet-clock` | big block digits with a band of light moving through them |
| `velvet-vitals` | CPU history, every core, memory, load, temperature |
| `velvet-pulse` | what is playing, with a spectrum — real levels when cava is installed, and labelled as decorative when it is not |
| `velvet-traffic` | up and down on your busiest interface, on a shared easing scale |
| `velvet-space` | where the disk went |
| `velvet-drift` | a quiet particle field that never repeats |

They read the shell's own accent out of `~/.config/velvet/palette.json`, which
the shell rewrites whenever the palette changes — so changing wallpaper
recolours the clock in the corner without restarting anything. `q` or `Esc`
closes one. `install.sh` links them into `~/.local/bin` as well, but the
desktop starts them by absolute path, so PATH is not required.

**The mini desktop** — reach for the middle of the top edge and a small plate
drops down, cut to the shape of your monitor, showing **the workspace you are
on** at the size it really is and nothing else. Scroll out and the neighbouring
desktops come into view around it, with empty ones drawn as numbered slots;
scroll back in and you are on your own desktop again. `Home` resets.

Click a window to go to it — it switches workspace and focuses it. Drag one to
move it, and drop it on another desktop to send it there. Click bare desktop to
switch to that desktop. Middle-click closes a window. Hyprland cannot move a
tiled window by pixel, so dragging one floats it first and says so once; `F`
puts it back.

The map is deliberately calm: icon cards for the windows, no live video
(per-window capture is dead on Hyprland 0.56, see below). The size is one dial
(**SIZE**, a share of the screen); there is deliberately no height dial, because
the plate is cut to your monitor's proportions and that is what makes one
workspace fill it exactly.

Opened on purpose (`Super+M` or the bar module) it takes the keyboard and
a dim line along the bottom lists everything it can do: the arrows pick the next
window *by where it is on the map* rather than by the order the compositor
happens to list things in, `Enter` goes there, `B` brings it to you instead,
`1`–`9` send it to a workspace without following it, `F` floats or tiles it,
`Del` closes it. Opened by reaching for the edge it takes nothing — hovering
must never pull the keyboard out from under you.

Hyprland 0.56 stopped delivering the per-window toplevel-export frames this
shell used before (the protocol is still advertised, the frames never arrive),
so the cards show the app's icon and title instead of a picture of the window.
A click off the plate closes a map you opened on purpose; one opened by
reaching for the edge closes when the pointer leaves it.

**The wallpaper wheel** — `Super+W`. A card, not a takeover: twelve
wallpapers on a ring, the one you are on filling an octagon in the middle, the
palette it would give the shell along the bottom, and one dim line of keys. The
wallpaper actually up is marked with a bright edge, so the ring always tells you
where home is. `← →` or the wheel turns it, `Enter` applies, `F` favourites, `R`
is random, `S` saves the look. Everything behind the card recolours as you turn
it, because the palette is live — you are choosing a desktop, not an image.

**Looks** — a look is the appearance you chose while a particular wallpaper was
up. The palette already follows the wallpaper on its own; what it cannot know is
that a busy photograph wants a heavier bar and less transparency while a flat
gradient can carry a thin one. That is taste, and this remembers it. Change
wallpaper, get your taste for that wallpaper back. A look holds *every* setting
the menu has, in six groups you can switch on and off under **WALLPAPER LOOKS**:
colours and style, the taskbar (where it sits, size, opacity), windows (opacity,
gaps, rounding, blur), the lock screen, desktop and canvas, and everything else
(launcher, notifications, OSD, sounds …). It saves itself a moment after you stop
changing something. Nothing is destructive: a look only writes settings it has a
saved value for, a group that is off is neither saved nor restored, and a
wallpaper with no look leaves everything exactly as it is.

Everything lives in one place: the **PER WALLPAPER** tab of the settings (also
reachable from the desktop right-click menu). It shows what the current wallpaper
remembers — how many settings of each group are kept, with a switch and a jump to
the tab where you change them — whether you have unsaved changes (SAVE LOOK,
UNDO CHANGES, FORGET LOOK), and every wallpaper that has a look, so you can use
one, copy its look onto the current wallpaper, or forget it.

**Controller slot** — QUICK SETTINGS → *CONTROLLER · P1 / P2* (the taskbar's quick
panel has the same chip). Games number pads in the order the system lists them,
so a lone pad is always player 1 — a problem the moment you want two-player
couch co-op. P2 makes your pad the second player, over Bluetooth and cable alike
(`bin/velvet-pad`: it holds the real pad silent in slot 1 and publishes a live
copy after it; the kernel undoes everything if it ever dies). Measured with SDL2
and SDL3: the live pad lands at index 1. Rumble is not forwarded while P2 is on,
and with two real pads on the desk keep P1 and let the games number them.
Most Steam games get the pad through **Steam Input**, which opens a DualSense & co.
itself (hidraw) and hands the game a virtual Xbox pad in slot 1 — the evdev arrangement
never reaches it. So while P2 runs, `bin/velvet-pad` asks Steam itself to move the pad to
its player 2 (`SteamClient.Input.SwapControllerOrder`, through Steam's local DevTools port
— `bin/_steam.py`). That needs one switch: tap **STEAM · ALLOW ORDER** in Quick Settings
(or `velvet-pad steam enable`) and restart Steam once. `velvet-pad steam status` shows where
it stands. Games that run without Steam Input read the pad over hidraw; for those
**COPY LAUNCH OPTION** gives `velvet-pad launch -- %command%`, and apps started from the
shell get `SDL_JOYSTICK_HIDAPI=0` automatically while P2 is on.

**Vibes** — SETTINGS → LOOKS (top), or QUICK SETTINGS → *VIBE*. Ten completely different
shells, not recolours — and none of them shouts: every card, chip and panel changes its **shape**
(slash, round, square, notch, bracket, pixel, bevel), **outline**, **shadow**, **ground** (dark or a
light page), **type**, **motion**, backdrop pattern and **sounds**; the bar, the island, the windows'
borders and the lyrics follow. ARCADE (pixel headings, yellow on navy), CYBER (notched panels, hairline
cyan), TERMINAL (lowercase mint on near-black), PAPER (ink on cream, serif), GLASS (frosted round panes),
RPG (gold line on leather), BRUTAL (warm paper, black outlines, one coral), GLASSMORPHISM (frosted glass over an aurora), NEUMORPH (soft extruded surfaces), CLAY (pillowy pastel), FLAT (solid colour blocks), MINIMAL (black on warm white), STREET (dirty concrete, tape, tags in caution yellow), **CLEAN** (a soft white sheet,
one blue accent, hairlines, calm motion), **WILDSTYLE** (a painted brick wall: the headlines are real
graffiti pieces — outlined, two-tone, with a swept 3D block, arrows, glints and drips; sticker cards, a
paint colour for every row and category, spray-can sounds) and **WINDOWS** — in five editions: **95** (grey bevels, navy
title bar, Start button), **XP** (Luna blue, green Start), **7** (Aero glass, orb), **10** (flat, sharp),
**11** (mica, rounded). Pick the edition under the vibes on the LOOKS tab or in VISUALS → VIBE → WINDOWS
VERSION; while the look is on, the whole shell follows — settings window, taskbar, Start button, windows,
sounds. Each vibe also builds the **settings window itself** differently — a terminal with a path prompt
and `key = value` lines, a game's level-select menu, a HUD with sectors, a newspaper with a table of
contents, floating frosted panes, a book with chapters, a poster with outlined labels, one quiet sheet,
a painted wall, or a Windows window (`appearance.skin`, VISUALS → VIBE → SETTINGS LAYOUT) — and wipes the
screen briefly in its own way when you put it on (WILDSTYLE rolls seven stripes of paint across it). Each is only settings — tune any of them one by one in VISUALS → VIBE,
save the result as a look of your own, or let a wallpaper keep its own vibe. From a terminal:
`qs -c velvet ipc call looks apply clean` (`windows` is the edition you chose last; `win95 winxp win7
win10 win11` name one). The sound packs and the pixel typeface are made by `assets/make-sfx-packs.py`
and `assets/make-font.py` (the installer runs them if missing).

**Lock screens of the vibes** — SETTINGS → LOCK SCREEN → LOCK STYLE → *VIBE* (every vibe sets it). The lock
wears the look: a **terminal** login (boot log, block-pixel clock, `velvet login:` and `Login incorrect`), an
**arcade** title screen (pixel clock, a row of boxes for the password), a **HUD** (ring dial, telemetry, a
notched access bar), a **newspaper** front page (masthead, "THE DESK IS LOCKED", a subscriber's box), **glass**
(frosted wallpaper, a hairline-thin clock), a **tome** (gold frame, "speak the word", diamonds), a **poster**
(black block time, one hard shadow), **clean** (the time and one pill), the **logon screens of Windows 95, XP,
7, 10 and 11**, and the **wall** (the time painted as a piece, a sticker to type into where every key sprays a
blob of paint). All of them share one input core (`modules/lock/LockKit.qml` → `Locker`); a face that fails to
load leaves a plain one, so you can always type. The LOCK SCREEN tab shows a live picture of the one you wear.

**Credits** — SETTINGS → CREDITS: Sug & Sane (SnS) · 27, what the shell stands on, and their tag as a piece of
graffiti.

**Canvas: moves or stays** — every module can be told what the infinite canvas does
to it (module settings → *WHEN THE CANVAS MOVES*): **STAYS PUT** keeps it on the
screen while you pan and zoom (widgets always do, and so does cava by default),
**MOVES WITH THE CANVAS** carries it along like a window. In the desktop editor,
zoom out to see the canvas around your screen and drag modules out onto it; a
fixed module dropped out there switches to *moves* by itself.

**Zoom like a canvas** — `Super+Alt` + mouse wheel, in and out, from 10 % to 300 %. The windows grow or shrink
around the pointer as live textures — content included — while the wallpaper, the bar, the screen frame and every
Velvet panel stay exactly as they are. 1:1 is a stop: a turn of the wheel that reaches it lands on it, the next
one goes on. Windows that sit off screen at 1:1 slide into view. Zoomed in or out, everything works as usual: click,
type, scroll, `Super`+drag to move and `Super`+right-drag to resize land on the window where you see it.
`Super+Alt` + right click zooms out just far enough that every window shows; `Super+Alt` + left click (or middle
click) goes back to 1:1 from anywhere.
`Super+Alt` + arrows swap places with the neighbouring window (Hyprland's own swap); `Super+Alt` + `H J K L` move a
tiled window through the layout. Hyprland keeps the plugin build it loaded at login: after an update the shell says so, and
`bash ~/.config/quickshell/velvet/tools/reload-zoom-plugin.sh` puts the new one in without logging out. This needs the small compositor plugin
in `plugin/velvetzoom/` (`tools/build-zoom-plugin.sh`, built by `install.sh`; rebuild after a Hyprland update).
Without it the zoom falls back to moving and resizing the windows. `touch /tmp/velvet-zoom-noplugin` forces the fallback.

**Lyrics** — `Super+Shift+L`. Timed lyrics from [lrclib.net][lrclib] — open,
free, no key, no account — driven by the player's own position. One word at a
time, the size of a headline, on a tile of its own, with the track and a
progress bar underneath. LRC stamps lines rather than words, so a line's words
are spread across its own duration: not real word timing, and it never claims
to be, but at one word on screen it lands closely enough to sing to. **LINE**
mode shows the whole line instead and fills it in as it is sung.
It sits *under* your windows on the background layer, so it is scenery: it never
takes a click and never takes focus. No match, no network, an instrumental — all
of them end in a quiet line of text rather than an error.

[lrclib]: https://lrclib.net

**Every shortcut** — `Super+Shift+K`, or the bar module, or `F1` inside the
settings menu. All three render `config/Shortcuts.qml` and nothing else, so the
list you see is the list that exists. A list of keys you can only reach by
already knowing one of the keys is not much use, which is why it stopped living
only inside the menu.

**Focus mode** — `Super+Shift+F`, or the chip in the quick panel, or the bar
module. One switch that silences notifications, keeps the screen awake, mutes
the shell's own sounds and (optionally) slides the bar away — and puts all of it
back when you turn it off. It never writes to your own do-not-disturb or keep-awake settings, so leaving focus mode restores exactly what you had.
   **DIM THE OTHER WINDOWS** goes further: every window you are not looking at
   steps back harder and the desktop behind them shades, so the window you are
   working in is the only lit thing on screen. Hyprland's own dim is borrowed for
   as long as focus is on and handed back the moment it goes off.
   Everything it does is a checkbox in **SHELL → FOCUS MODE**; the bar module
breathes a ring while it's on and counts what you missed, so a silenced desktop
can't be mistaken for a quiet one.

**Toasts** — anything the shell tries and can't do says so on screen for a few
seconds instead of failing into a log. Hovering one pauses its timer. Tick a task
off in the WORKFLOW room and the achievement answers with its own flourish and a
`QUEST COMPLETE` line, the only sound in the shell allowed to sound pleased.

**The settings menu** — `Super+Tab`. Eleven categories: visuals, modules, desktop,
lock screen, windows, audio, display, wallpaper, shell, power and home. The
bar's own settings live under MODULES → TASKBAR.

**The launcher** — `Super+Space`. Fuzzy app search with frecency ranking, a
calculator (type `2+2*8`), and `> some command` to run a shell command.
Everything it starts is handed to Hyprland to spawn rather than to the shell
itself, so restarting the shell never closes an app you opened from here.

**Notifications** — a real notification daemon, popups in the corner, history in
the panel behind the clock. Critical ones get a torn edge instead of a clean one.

**The wallpaper** — Velvet paints it itself, on a background layer under
   everything. No `swww`, no `hyprpaper`, nothing to autostart, and because it
   binds straight to the stored path it is simply there again after a reboot. It
   crossfades on change and drifts imperceptibly while idle. Browse and apply from
   the carousel in the settings menu: `Enter` applies, `F` favourites, `Tab` filters
   to favourites only. If you'd rather keep an external daemon,
   **WALLPAPER → RENDERER → SWWW / HYPRPAPER**.

**The living desktop** — `WALLPAPER → LIVING DESKTOP`, one master switch that
   turns the wallpaper from a picture into a place. The scene's widgets ride the
   wallpaper itself — clock, weather, media, anything from the lock's catalogue,
   placed by dragging them on the DESKTOP tab's picture of your screen. The box
   you drag is the widget's size: pull its corner and the widget itself grows.
   Widgets come in four frames — `SHAPES` (soft Material shapes that morph:
   the weather widget turns into a sun, a clover or a flower with the sky, the
   clock's digits roll), `GLASS` (frosted), `INK` (grounded black) or `RAW`
   (the widget melts straight into the picture) — each overridable per widget in
   the DESKTOP inspector, plus its own opacity. The widgets are alive to the
   pointer, not pictures of widgets: hovered, a widget solidifies out of the
   wallpaper, lifts and leans a few degrees under the pointer, a soft light
   follows the pointer across it and a SHAPES silhouette turns a quarter-lobe.
   A click does what the widget is about — the notifications open, the avatar
   brings the session menu, the greeting the launcher, the CPU card a system
   monitor, the network QUICK SETTINGS, the weather asks the sky again; the
   clock and calendar roll over to the date and the week number; the media
   art plays and pauses, the card grows previous · next and a seek bar, and
   the wheel over it is the volume. Right-click any widget to edit it in
   DESKTOP. Right-click a free spot of the desktop and the desktop menu opens
   there: edit the desktop, drop a widget right under the pointer, change the
   wallpaper, save its look, and jump to any desktop or the infinite canvas
   (WALLPAPER CHANGER → DESKTOP RIGHT-CLICK MENU turns it off, and bare desktop
   is click-through again). The DESKTOP tab carries the same desktop strip.
   Pick a widget in DESKTOP and every choice it has is laid out at once:
   frame, silhouette, tone, colour, opacity, details, size (S · M · L · XL),
   nine spots to send it to, and what only it has — 12/24 hours for the
   clock, your name for the greeting, CPU and/or RAM, the media controls
   always or on hover — plus LIVE or STILL for the pointer. All of it is
   saved with the wallpaper that is up: give each wallpaper its own desk,
   and its widgets come back exactly as you set them whenever it does.
   New windows drop a soft accent
   ripple where they land; the picture warms at sunset and cools after midnight;
   an optional aurora of accent light drifts under everything on minute-long
   curves; and every widget glides in when its wallpaper loads. Everything on the
   page has its own switch, so the living desktop is exactly as alive as you want
   it — including not at all.

**Modules, dressed to taste** — every module on the DESKTOP tab has a card of
   its own. The six Velvet programs share a vocabulary: upside down, mirrored,
   pinned to the top or bottom of their window, outlined, calmer or faster,
   in any palette colour or any colour at all — and each has its own switches
   (the clock's 12 hours, seconds and date; PULSE as bars only; DRIFT's density
   and trails). CAVA runs through `velvet-cava`: bars that grow up, hang down,
   lie left or right or grow from the middle, stereo or mono, thin or huge,
   in a gradient taken from your wallpaper that recolours itself live when
   the wallpaper changes. Every terminal module takes a text size, a
   background from solid to clear and its padding — and every pick shows on
   the running module at once, without a restart: the switches reach the
   program through a small live file, the window through kitty's remote
   control, and moving a tile moves the window. Place as many of one module
   as you like — two CAVAs, one standing and one hanging, are two modules.
   A module can be CLICK-THROUGH (clicks land on whatever is underneath, so a
   cava strip never gets in the way) and BARE (no border, shadow or blur —
   part of the wallpaper), and CAVA has a LEVEL: AUTO, or a fixed LOW / MEDIUM
   / HIGH that never overshoots. Modules left behind when a desk changes close
   with it, and after a monitor sleeps they return to their boxes. CAVA also
   has a STYLE: its own BARS, or a smooth filled WAVE or a thin LINE that
   `velvet-cava` draws itself from cava's raw feed (a spline through the
   bands, eighth blocks or braille dots; WAVE DETAIL from CALM hills to every
   band) — switching between them, colours, height and direction redraw live.
   CAVA stands exactly on its edge and runs edge to edge: kitty keeps its
   padding only on the far side. The designer shows CAVA LIVE — on its tile
   and big in its inspector, with every switch, from the music playing now
   (a calm demo swell when nothing plays).

**Audio-reactive** — `MODULES → AUDIO-REACTIVE`. With cava installed the shell
   moves with what is playing: a live waveform under the island's transport, the
   bar's now-playing entry breathing with the loudness, and a hairline of bands
   along the bottom of the wallpaper. It is real, not decorative —
   `bin/velvet-levels` runs cava, eases its bands and writes them to a file the
   shell reads at 30 times a second while something is audible (and twice a
   second when nothing is). Without cava there is no motion at all, because a
   meter that pretends is worse than no meter. Each of the three surfaces has
   its own switch. The wallpaper's one has a WAVE LOOK: the quiet hairline, or
   a smooth WAVE, rounded BARS or a LINE standing on any screen edge, as high
   as you like — drawn by the shell, under every window.

**The lock screen** — on by default now that it can prove PAM works before it
locks anything; see below. `SETTINGS → LOCK SCREEN` shows a LIVE PREVIEW of
the real lock beside its list, so every pick shows at once. `CLOCK & SOUND`
sets the LOCK SIZE (AUTO grows the cards with a taller screen), sizes the
clock and picks its face (light, heavy, mono, a drawn DOT matrix, or ANALOG
hands on a dial) and its SHAPE (cookie, sun, flower, clover, circle, pentagon —
hours over minutes with the hands sweeping over them), how blurred the
wallpaper behind the lock is (and whether it fills the space around the
background shape), and puts a CAVA VISUALIZER on the lock — wave, bars or line,
on the edge you choose. The power card sleeps at once and logs out, restarts
or powers off only after the password was accepted. The lock can show the
LYRICS line the song is singing, and after a while without input it goes
AMBIENT — only the clock, the lyric and the music stay until you move or type.

**OSD** — volume and brightness flash, from any source, including your media keys.

---

## The Dynamic Island, and where things stand

Touch the top edge and the island rises: swipe it for music, the desktop map,
tasks, weather, the system and Velly; pull it down to open one.

**On a side edge it is built for the edge.** MODULES → DYNAMIC ISLAND →
POSITION → **LEFT EDGE / RIGHT EDGE** turns it into a **rail**, like a vertical
taskbar: one icon per module, sliding out of that side at **ISLAND HEIGHT**
(the middle by default). Point at the rail and every module's live line unfolds
beside its icon — the song, the desktop, the tasks, the weather, CPU and RAM,
Velly — so the whole island reads at a glance. Click an icon (or pull it out of
the rail) and that module opens beside the rail; click it again and it folds
back. Scrub along the rail or turn the wheel to flip between modules, even while
one is open; hold it for Velly. Music playing and Velly awake show as a pulsing
dot on their icons. Its hot zone is a thin strip on that edge, only as long as
HOT ZONE LENGTH, and the desktop map slides in from the same edge.

**The infinite canvas lives in the island.** The DESKTOP module is the map
itself: it opens right inside the island like music or the weather — same
ground, same shape, the module tabs on top — instead of handing off to a second
window somewhere else, and Super+Shift+M, the bar's map button and Velly open it
there. A chip per desktop with a live miniature of its windows (click to go,
drop a window on one to send it, scroll over them to flip), the monitor with your
wallpaper on it, every window as a card with its app's icon, on a dot grid that
moves with the camera; windows far out on the canvas show as arrows on the edge —
click one and the camera flies there. Click a card to go to the window, drag it
anywhere, × or middle-click closes it, the second button floats or tiles it.
FIT · − · % · + · HOME drive the camera; the wheel zooms at the pointer,
Shift+wheel and a touchpad look around, a double-click on bare canvas fits; the
keyboard has arrows, Enter, Del, F, B, 1–9, + − 0, Home and Tab. Island off, the
same canvas drops as a plate of its own (`modules/map/MapCanvas.qml` is both).

**Tabs and keys.** Open, the island's dots grow into tabs with each module's
icon — one click to music, the map, tasks, weather, the system or Velly (a drag
that starts on them is still the pill's swipe); Ctrl+Tab flips modules from the
keyboard. Pulling a module out uncovers it at its final size, so nothing
squeezes on the way.

**Docked in the frame.** **DOCK TO THE EDGE** (on by default) grows the island
out of the line where the desktop starts — the screen frame, or a taskbar on that
edge: square where it meets it, flared into it with two soft inner curves, and
rising from *behind* it, never across the bar. With the theme **FRAME** island,
frame and bar are one surface, and a frame **OUTLINE** bends round the island.
**ISLAND + FRAME AS ONE** sets all of it in one click, and the frame's own
switches (width, rounding, colour, outline, bar joins the frame) are on the
island's page too. Themes: INK BLACK, GLASS (now really frosted — see below),
WALLPAPER, FRAME, TONE.

**Blur was never on.** Hyprland 0.56 answers the old `hl.config({ layerrule = … })`
with "ok" and ignores it, so no Velvet layer was ever blurred — GLASS was plain
see-through. Velvet now sends named `hl.layer_rule` rules (bar, popouts,
notifications, OSD, notification centre, island).

The other floating parts have a SIDE choice as well: the volume pop-up (OSD), the
desktop lyrics and the launcher, and notifications can rise from the middle of
the top or bottom edge as well as from a corner.

## Velly — the assistant in the island

The Dynamic Island has a resident. **Press Super+A** from anywhere — or **hold
the pill at the top edge** (do not swipe, do not click, just keep pressing) —
and the capsule grows into Velly, already listening: a ring of bars that rides
your voice, an answer that types itself out, tool chips that say what she just
did, and an input row for the things you would rather type. Super+A again sends
her back to sleep. A fresh conversation starts clean, with a few things to try
one click away (weather, music, a reminder, a system update, "what can you do").

**What you see while you talk.** Your words appear in the island *while you are
still saying them* (live captions: `bin/velvet-ears` writes a snapshot of the
open sentence every second, `velvet-ai --stt-live` reads it on the graphics
card — about 0.3 s a pass), then the sentence she actually understood, the
moment it goes out — so you know at once whether she heard you right.

**She runs Velvet for you.** "Stell die Island an den rechten Rand", "mach
den Launcher etwas langsamer", "wie ändere ich die Akzentfarbe?" — she finds
the setting among every row of the settings window (`settings.find`, with what
it does, where it lives and its current value) and changes it through the same
door the window uses (`settings.set`, checked against the values the row
allows). A question *how* gets an explanation, not a change; "mach das
rückgängig" puts the old value back; her own safety switch, her brain and the
lock's boot settings stay yours. She also remembers what you talked about days
ago (`history.search`), thinks harder for questions than for commands (and
hardest when you say "denk genau nach"), looks things up and *answers* instead
of opening a search page, and a phrase she gets stuck on is cut the moment it
starts repeating.

**She puts looks on.** "Mach alles wie Windows 11", "ich will so einen
Glas-Look", "nimm das wieder raus" — `look.apply` / `look.undo`; "was für Looks
gibt es" is read off the shell, never from memory. One-click rows of the settings
(ISLAND + FRAME AS ONE, BACK TO DEFAULTS …) she can press too — none that delete,
uninstall or power anything off. A question *how* ("wie kann ich die Island
andocken?") is answered with where it is, and nothing changes until you say so.
She knows how Velvet looks right now (the look, where the island sits and how it
is dressed, the taskbar, the frame) whenever you talk about it, opens the
island's modules by name ("zeig mir das Wetter in der Island"), and a "ja" to
something she offered does exactly that — or she asks which, when the offer left
a choice open.

**Asking before she acts.** A command or a reboot gets one question — with
**JA, MACH / NEIN** buttons in the island. Saying "ja" runs exactly the action
she asked about (it used to depend on the model repeating the call, and she
asked "sag ja" again and again); "nein" or a new wish drops it. Commands that
only look (how many packages, the disk, the kernel) run without asking, and
anything that needs a password — `sudo`, an update (`sys.update`), an install —
opens a terminal where you type it yourself.

She hears you through the microphone while she is awake, she speaks her answers,
and she can touch the whole desktop — apps, windows, workspaces, volume,
brightness, tasks, focus mode, the wallpaper, scenes, the settings menu, even
the session itself. Three rules make that safe enough to live with:

- **A session is real.** The long press opens it and writes
  `~/.config/velvet/ai-session.json` with a moving expiry; every single tool
  call re-reads that file. Closing the island, pressing Escape, or three quiet
  minutes ends the session, and the microphone is gone with it. The brain
  stays loaded for a few more minutes (**WACH BLEIBEN**, 5 by default, 0 =
  unload at once) so the next question is instant — and a fullscreen game
  takes the graphics card back the moment it starts.
- **The key never enters the repo.** Nobody needs one any more — but if you
  do add one for a cloud provider, it lives in `~/.config/velvet/ai.json`
  with permissions 600, written by her own SETUP or by
  `bin/velvet-ai --set-key`.
- **She is someone.** Warm, curious, a little cheeky — she mirrors your energy,
  varies how she says things, asks back now and then, learns your name and
  uses it, and answers facts from the web (`web.lookup` reads the results)
  instead of just opening a tab. While she speaks, the island lights up the
  sentence she is saying.
- **She talks like a person.** Whole, friendly sentences ("Der Prozessor ist
  entspannt (12 %), 6,1 von 30,4 GB sind belegt …"), German dates, no leaked
  reasoning (a model that plans out loud is cleaned before you see or hear it),
  and a voice that says "13 Uhr 42" instead of spelling a path or reading an
  emoji out loud. Whisper's phantom words on silence ("Amen.", "Okay.") are
  recognised by their low confidence and never reach her.
- **She follows the conversation.** Her own question gets its answer: after
  "wie darf ich dich nennen?" a name is a name (stored, never a song title —
  it once started Radiohead), and the name she knows is not asked for again,
  in whatever words it was stored. "Nein, das wollte ich nicht" undoes what
  she just did (the context tells her her last actions). Half a sentence
  ("… und vielleicht kannst du mir") waits for its other half instead of
  getting an answer to half a question, and a second half that arrives while
  she is still thinking replaces the first — the brain drops the old turn.
  The desktop's state only reaches her where your words touch it, so "Alles
  gut!" is not answered with the song that is paused.
- **She never corrects you.** Speech recognition gets her own name wrong
  (“Welly”, “Velli”) and mishears words; the transcript is normalised before
  she sees it and the prompt forbids commenting on your wording, spelling or
  pronunciation at all. If something is genuinely unclear she asks, once.
- **She hears what you say to her.** Whisper is told the words people use with
  her — the commands, your name, the apps you really start (built hourly into
  `~/.cache/velvet/ear-vocab.txt`); until v8.47 that prompt never reached the
  decoder (`-mc 0` drops it — measured: "mach die lautstarke leiser und öffne"
  became "Mach die Lautstärke leiser und öffne Vesktop."). Words it still gets
  wrong are fixed before the model reads them ("K-List" → Playlist,
  "Wahlpaper" → Wallpaper), and she reads the rest by its sound. Silence, noise
  and a web address made up from nothing are dropped.
- **Nothing is faked.** She is local and free by default: `bin/velvet-local`
  owns an engine room (`~/.local/share/velvet`) with llama.cpp, a Qwen3-4B
  brain, whisper.cpp ears and a piper voice. SETUP installs it with one press
  and reports real megabytes while it does. If that is not there yet, a small
  local skill set (clock, volume, brightness, apps, tasks, focus, locking,
  system) keeps working without any provider, and the header says exactly
  which of the two you are talking to.

| | |
|---|---|
| **Brain** | Local and free by default: `auto` takes the engine room first (`bin/velvet-local` — llama.cpp, Vulkan when there is a GPU) and it comes in **four sizes** — `klein` Qwen3-4B, `mittel` Qwen3-8B (the default), `gross` Qwen3-14B, `max` gpt-oss-20B. Switching is instant (`bin/velvet-local brain gross`, SETUP → MODELL-GRÖSSE) because `brain.gguf` is a symlink. The server runs on the **discrete graphics card only** (`bin/_gpu.py` picks it — llama.cpp would otherwise spread the model over the CPU's integrated graphics too) and lets llama.cpp's own **fit** place it: every layer it can on the card, and when the VRAM is a little short only a few *expert* layers of the MoE model in RAM. Measured on the RX 9070 XT: gpt-oss-20B entirely on the GPU, **~115–140 tokens/s**, the whole prompt read at ~3000 tokens/s — before, a 105 MB shortfall moved *all* experts to the CPU and it crawled at 4–6 tokens/s. Only when the chosen size is far from fitting (a game holding the card) does a smaller one serve, unless **TROTZDEM** is on. Two slots share one prompt cache, and the system prompt and the tools are warmed while she greets you, so a turn reads only its own new words (a question with a tool call: ~0.8 s; an explanation with more thought: ~1.6 s). gpt-oss thinks **low** for commands and chat and **medium** for questions worth thinking about; its sampler is its own, Qwen's is tuned for tool calls. Then a running Ollama, and only then a key. OpenAI, DeepSeek, Anthropic and any OpenAI-compatible endpoint stay supported. |
| **Ears** | **On the graphics card** when it can: whisper.cpp publishes no Linux build with Vulkan, so `bin/velvet-local ears-gpu` builds one (sources only, ~13 MB, no sudo — cmake, a compiler and `glslc` are enough) into `engines/whisper-gpu`. Measured on the RX 9070 XT with the 20B brain loaded beside it: **0.4 s** per utterance, process start included, instead of 2.6 s on the 8-core CPU — and the whole 30-second window, so nothing is trimmed. A fullscreen game keeps the card; the CPU build listens then, and whenever the GPU run fails. **HEY VELLY** (MODULES → VELLY, off by default): the ears keep listening while she sleeps, every utterance goes through the small whisper model on this machine, and only one that STARTS with her name ("Hey Velly, …", heard as "High Valley" too) wakes her — the rest of the sentence is the question. `bin/velvet-ears` listens — voice activity detection, a live level for the orb, one WAV per utterance, with a sensitivity dial in **MODULES → VELLY** — and whisper.cpp transcribes it here: `large-v3-turbo` by default (`bin/velvet-local ears small|turbo|genau` changes that), German, with a name pass so “Welly”, “Velli” and “Velley” all arrive as Velly. On the CPU whisper's window is sized to the recording (a 9-second sentence: 7.6 s → 2.3 s), a sentence heard twice becomes one, and **MUSIK LEISER** turns playing music down to a quarter while she is awake (sung lines had arrived as questions) and puts it back afterwards. A cloud `/audio/transcriptions` provider is used only when no local one exists. |
| **Voice** | **Natural first:** Kartoffel-Orpheus (a German Orpheus-3B trained on real speakers — Sophie, Marie, Mia, Lina, Lea, Julian …) on its own llama-server (`127.0.0.1:8139`, Vulkan) plus the SNAC codec on onnxruntime, 24 kHz. The server comes up when she wakes (`velvet-voice --warm`) and stands down after seven quiet minutes; she speaks sentence by sentence (the first plays while the next is made) and **while she is still writing** — the voice reads the answer along as it streams (`velvet-voice --follow`) and starts with the first finished sentence, short phrases come from a cache, and while she thinks longer than a beat she says so ("Hm, Moment."). While a fullscreen game runs, or when the VRAM is not there, Piper speaks instead — the game keeps the graphics card. Then `bin/velvet-voice` — piper (the binary or the python module) with ten German voices to pick from, **loaded once** by a small keeper that starts when she wakes and leaves after 15 quiet minutes: a sentence takes 0.03–0.2 s instead of the 1.3 s a fresh piper process cost for every sentence (measured). A voice is picked with two arrows and a SAG button in SETUP, or in **MODULES → VELLY**. A voice that is not downloaded yet fetches itself on the next sentence, and `bin/velvet-voice --fetch-voice <name>` does it from the terminal. Tempo and loudness are dials. espeak-ng, a cloud voice and labelled blips stay as the fallbacks. |
| **Memory** | `~/.config/velvet/ai-memory.json`: facts she was told, a note per session, the transcript, and counters. At the end of a session only what is NEW is distilled — facts about the person (name, likes, setup), never about a session, an error or a test; duplicates in other words are merged (`bin/velvet-ai --tidy-memory`). A new wake starts a fresh conversation instead of continuing last week's. |
| **Tools** | 69 of them, in `bin/velvet-ai --tools`, each argument described in the schema (with the allowed words where there are only a few) — including `weather.forecast` (now and seven days, here or any place — Open-Meteo, no key), `sys.time` with a place ("wie spät ist es in Tokio"), `date.lookup` ("nächsten Freitag", "Weihnachten" — counted, not guessed), `clipboard.read` / `clipboard.write`, `notifs.list` ("was hab ich verpasst"), `web.read` (a page's readable text), `media.play` (finds a song, album, artist or playlist on Spotify and really starts it; if it finds nothing it opens Spotify's search and says so), `web.lookup` (reads DuckDuckGo — and when that asks "are you a robot", Wikipedia's own search — so she can answer), `file.write` (lists, notes and texts into ~/Dokumente/Velly), `web.search` / `web.open` (a search opens in the browser: YouTube, Google, Wikipedia, Maps, GitHub, AUR, Arch Wiki …; `web.download` refuses search pages), `timer.set` / `timer.list` / `timer.cancel` (reminders and alarms that outlive the session, then notify and speak) and `calc.eval` (exact arithmetic instead of a guess), `look.list` / `look.apply` / `look.undo` (whole-desktop looks). Besides apps, windows, workspaces, media and the system: `pkg.search` and `pkg.install` (repositories and AUR — an install opens a terminal window, so the password prompt and the progress stay yours), `term.run` for anything that needs a tty, `web.download`, and `cmd.run` for the rest, which asks for a spoken confirmation first. Models that can call tools natively (the local engine, OpenAI, DeepSeek) get them as a real schema and hand their calls and results back as real tool messages; for the others she writes one line — `[[tool:name {"arg": "value"}]]`. Either way, what she says is cleaned of reasoning, markdown and emoji before you see or hear it. |

The quick answers need no model at all and answer in a blink: the time here
or in another city, which day "morgen" or "der 24.12." is, the weather now and
tomorrow, reminders in words ("erinnere mich morgen um halb acht an …"),
sums with percent, pause/next/back for the music, volume by steps ("20 Prozent
leiser"), and her own voice ("sprich leiser"). Anything they cannot really
answer — a place, advice, a question ABOUT a thing, English — goes to the model.

Switches live in **Super+Tab → MODULES → VELLY**; the island's own SETUP card
(and `bin/velvet-ai --config`, `--probe`, `--tools`, `--forget-all`) do the rest.

```bash
qs -c velvet ipc call velly wake          # the programmatic long press
qs -c velvet ipc call velly ask "wie spät ist es"
qs -c velvet ipc call velly status
qs -c velvet ipc call velly sleep

bin/velvet-local status                   # what is on disk, in real megabytes
bin/velvet-local ensure                   # fetch what is missing (same as SETUP)
bin/velvet-local brain mittel             # 4B · 8B · 14B · gpt-oss-20b
bin/velvet-local ears turbo               # small · turbo · genau
bin/velvet-local ears-gpu                 # build whisper with Vulkan: 0.4 s instead of ~3 s
bin/velvet-local serve --idle 600         # the model server, on 127.0.0.1:8137
bin/velvet-local serve --force            # … even when your size does not fit
bin/velvet-local stop                     # give the VRAM back now

qs -c velvet ipc call velly force true    # "TROTZDEM": run the chosen size anyway
qs -c velvet ipc call velly force false   # back to the largest size that fits
```

---

## The colour system

Every colour in the shell comes from one accent, and by default that accent is
extracted from your wallpaper. `services/Colours.qml` quantises the image, scores
the candidates on saturation and lightness, and normalises the winner into a
range that always reads as punchy. Surfaces, text and outlines are then tinted
toward that hue so black never looks like dead grey.

Three dials sit on top of that, in **VISUALS**:

- **COLOUR STRENGTH** — how saturated the extracted accent is allowed to be. A
  wallpaper full of neon used to hand the whole shell a colour that shouted;
  turn this down and the same wallpaper gives a calmer accent without changing
  its hue.
- **BRIGHTNESS FLOOR** and **TINT** — how light the surfaces sit and how much of
  the accent's hue they carry. If a wallpaper leaves the shell too dark, this is
  the dial; it lifts the ground colours without washing out the accent.
- **READABILITY GUARD** — on by default. Every foreground colour is checked
  against the surface it's drawn on using the WCAG contrast formula, and walked
  toward black or white until it passes. It's why no accent, however awkward,
  produces a row you have to squint at. Turn it off if you want the raw
  extracted colours and will live with the consequences.

Turn on **WINDOWS → TINT WINDOW BORDERS** and Hyprland's window borders come
from the same accent, so the desktop and the shell agree. Change the wallpaper
and everything follows in one frame. It's off by default, because a border
gradient you tuned by hand is usually one you meant.

If you'd rather pin it: **VISUALS → ACCENT SOURCE → MANUAL**.

---

## Hyprland integration

Velvet supports both config languages. It writes whichever one you already use
and the installer picks for you; `WINDOWS → CONFIG LANGUAGE` overrides it.

**hyprlang** (`hyprland.conf`) — the installer appends one line:

```
source = ~/.config/hypr/velvet-shell.conf
```

**Lua** (`hyprland.lua`) — the installer appends one line at the end:

```lua
require("velvet-shell")
```

Either way you end up with two files, doing different jobs:

- `velvet-shell.conf` / `velvet-shell.lua` — keybinds and autostart. Copied by
  the installer, yours to edit.
- `velvet.conf` / `velvet.lua` — gaps, rounding, blur, shadows, opacity.
  **Written by the shell.** Editing it by hand is pointless; it gets overwritten
  the next time you move a slider. The integration file pulls it in last so the
  menu always wins.

Changes apply through `hyprctl eval` (Lua `hl.config`) at 16 ms and get written to disk 700 ms
after you stop moving, so dragging feels direct and your config still survives a
reboot. If you'd rather manage Hyprland yourself, turn off
**WINDOWS → MANAGE HYPRLAND** and Velvet stops writing that file entirely.

Layer rules — the blur behind the bar — are *not* in either file. The shell
registers them itself over `hyprctl` at startup, which means they work the same
on both config languages and there is nothing to keep in sync.

### One Lua gotcha

Under a Lua config Hyprland takes dispatchers as Lua expressions
(`hl.dsp.focus({ workspace = 3 })`) rather than command strings
(`workspace 3`). Velvet probes which one this Hyprland speaks at startup and
retries in the other dialect if an action is refused (see "A button in the
shell does nothing at all" below). **WINDOWS → DISPATCH → DISPATCH STYLE** can
pin it, but a wrong pin is noticed and put back to `AUTO`.

Border colours are left alone by default, since a hand-tuned gradient is usually
deliberate. Turn on **WINDOWS → TINT WINDOW BORDERS** to have them follow the
wallpaper accent along with everything else.

---

## The lock screen

Three faces, one PAM core (LOCK SCREEN → LOCK STYLE): **Fluid**
(the card with side columns), **Velvet** (the original hard edges) and **Soft** — no card, the
blurred wallpaper, a big clock and a few round pills. LOG OUT · RESTART ·
SHUT DOWN arm the password — they act only after PAM has accepted it. The bell
opens the notifications, the song pill the music card.

The LOCK SCREEN settings are sorted the way you think about them: LOCK STYLE,
the master switch, the STATUS and TEST LOCK on top; then one page per style
(SOFT LOCK · FLUID LOCK · VELVET LOCK — the one you wear says **IN USE**,
the others step back); then what all of them share: CLOCK, BACKGROUND & MUSIC,
PASSWORD & HINTS and SECURITY & STARTUP.

Every piece of the soft lock is an **element** — the clock, the greeting cloud,
the date, the weather, your photo (`~/.face`), the lyric line, the power pills,
the bell, the password and the music — and every element can be moved,
resized, reshaped and shown or hidden:

- **Layouts**: VERTICAL, HORIZONTAL and GREETING stack the elements from their
  real sizes (a bigger clock pushes the pills down instead of into them);
  **CUSTOM** is your own — it appears by itself as soon as you drag something,
  and keeps every place as a share of the screen (`lock.softPlace`).
- **Arrange by hand**: LOCK SCREEN → SOFT LOCK → **ARRANGE BY HAND** opens the
  lock big in the settings, or click the **pencil** on the lock itself. Drag
  any element (it snaps to the middle of the screen, Alt places it freely),
  click one to pick it, ← → ↑ ↓ nudge it (Shift: a bigger step). On the lock
  the two panels can be dragged by their title and folded away.
- **Any shape on anything**: sixteen shapes (circle, square, cookie, gear,
  scallop, flower, clover, wavy, pebble, pentagon, soft pentagon, hexagon,
  diamond, triangle, star, burst) for the clock's dial, the greeting cloud, the
  date, the weather, your photo's frame and the music cover; round, soft or
  square corners for the pills, the password, the bell's list and the music
  card; a size for each; the clock as digits or hands only, the music as a
  pill or a card (`lock.softStyle`).
- **Motion**: seven entrances (rise, fade, zoom, drop, pop, spin, slide), played
  back on unlock; ONE AFTER ANOTHER staggers them; elements GLIDE to new places;
  SHAPES TURN SLOWLY turns every shape once in ninety seconds; the digits ROLL,
  FADE or SNAP when the minute turns.
- **Shapes change on hover**: point at a shape on the lock and it morphs into
  another (and lifts a little), back when the pointer leaves. Per element:
  AUTO (a partner of its own — star → burst, pentagon → star …), STAY, or any
  of the sixteen (`softStyle.<element>.hover`); all of it off with one switch
  under SOFT LOCK → MOTION.

The same shapes are offered to the desktop's soft widgets (WALLPAPER → LIVING
DESKTOP → a widget → SHAPE): the weather drops its slanted pill for the shape,
the music card wears it on its cover. Desktop widgets in the SHAPES and SOFT
frames morph on hover too (WALLPAPER → SHAPES CHANGE ON HOVER, and a HOVER
SHAPE per widget). A built-in LOOK clears the hand
arrangement (BACK brings it back); a look you saved yourself keeps its own.

Velvet has its own, in the same language as the rest of the shell — the
wallpaper dimmed behind it, an enormous clock, your password drawn as tally
marks rather than dots, and a hard shake when it's wrong. **It is on by
default — but it refuses to lock until it can prove it will let you back in.**

The Wayland session-lock protocol keeps the screen covered if the lock client
dies. A lock screen that cannot authenticate is therefore worse than no lock
screen at all — it is a locked machine you cannot get back into. Four rules
follow, all enforced in `services/Locker.qml`:

1. Velvet never enters the locked state until PAM has answered a prompt on this
   machine.
2. **It never hands over to a locker that is not installed.** An earlier version
   fell through to `loginctl lock-session`, which locks the session without
   drawing anything — the screen goes black with no way in. If nothing here can
   lock safely, nothing locks, and you get told why.
3. Authentication cannot hang. A stuck PAM conversation times out into a retry
   rather than a dead field, and four consecutive PAM *errors* (as opposed to
   wrong passwords, which an attacker can produce at will) abandon the lock.
4. `TEST LOCK` exists so you can try the whole thing without risk — it locks,
   and releases itself after twenty seconds no matter what.

If it can't authenticate, `Super+Escape → LOCK` does not black the screen and
does not silently do nothing either: a toast tells you what is missing. An
earlier version of this shell fell through to `loginctl lock-session` when no
locker was available, which locks the session with nothing drawn on it — a black
screen and no way in. That path is gone.

PAM is also a *build-time* option in Quickshell. If your build was compiled
without it, `services/LockAuth.qml` — the only file that imports it — fails to
create, Velvet notices, and the `STATUS` row on the lock page tells you so in
words rather than the shell failing to start.

### Setting it up

Run `./install.sh`; it offers to install `/etc/pam.d/velvet`, a two-line file
that points at your system's normal auth stack. This is exactly what hyprlock
and swaylock ship, and it means Velvet is not borrowing another program's
config. Then check **LOCK SCREEN → USE VELVET'S LOCK** (on by default) and press
**TEST LOCK**.

The `STATUS` row on that page always tells you what will actually happen when
you lock: which PAM service is in use, or which external locker will be run, or
that nothing can lock at all.

If a correct password is rejected, the PAM service is the wrong one — change it
in **PAM SERVICE**. If you ever do get stuck: `Ctrl+Alt+F2`, log in,
`loginctl unlock-session`. The lock screen prints that line itself once you have
had trouble.

`FOLLOW LOGINCTL` (on by default) means `loginctl lock-session`, the lid switch
and resume-from-suspend all reach Velvet's lock the same way they would reach
any other locker.

---

## Layout

```
shell.qml              root — the only file that instantiates windows
config/
  Config.qml           JSON on disk ⇄ live properties, two-way, watched
  Appearance.qml       derived tokens: fonts, spacing, radii, motion
  Schema.qml           every setting, as data
  Shortcuts.qml        every keybinding, as data
services/
  Colours.qml          wallpaper → palette
  Hypr / Audio / Brightness / Net / Battery / SysInfo / Display
  Wallpapers / Apps / Notifs / Sfx / Actions / Panels / Popout / Bridge
  Focus.qml            "leave me alone", as one boolean per consequence
  Desk.qml             monitors, workspaces and windows, as one world
  Scenes.qml           what belongs on the desktop, per wallpaper
  Term.qml             which terminal you have, and how to name a window
  Lyrics.qml           lrclib + MPRIS position, failing quietly
  Looks.qml            an appearance remembered per wallpaper
  Toast.qml            transient messages, so nothing can fail silently
  Locker.qml           lock state, PAM, and the self-test that prevents lockout
  LockAuth.qml         the only file that imports PAM, on purpose
  HyprConf.qml         live hyprctl + the generated conf/lua file
components/            Slash, Jagged, Octa, VelvetMark, Halftone, SlashSlider, …
modules/
  bar/                 the strip, its entries, and the popout layer
  settings/            the Persona overlay, incl. the drag-and-drop editor
  wallpaper/           the background layer, and the wheel
  map/                 the mini desktop at the top edge
  lyrics/              the line you are on, in slab type
  lock/                the session lock
  launcher/ notifs/ osd/ session/
bin/                   the six terminal programs, stdlib-only Python
```

### Adding a setting

You don't write UI. Add one entry to `config/Config.qml` (the default and its
type) and one to `config/Schema.qml` (how it presents), and it appears in the
menu — rendered, keyboard-navigable, searchable, and persisted:

```qml
// config/Config.qml, inside the bar JsonObject
property int myThing: 12

// config/Schema.qml, inside the taskbar list
{
    kind: "slider",
    key: "bar.myThing",
    name: "MY THING",
    sub: "WHAT IT DOES",
    min: 0, max: 40, step: 1, fmt: "int", unit: "px"
}
```

`kind` is one of `slider · toggle · choice · action · page · carousel · layout ·
colour · info`. A `page` nests another list inside itself, to any depth.

---

## Sounds

The ten UI sounds are synthesised, not sampled — `assets/make-sfx.py` writes
them with nothing but the Python standard library. Edit the functions in that
file and re-run it to change how the menu feels. Turn them off entirely in
**SHELL → SOUND**.

---

## Checking your changes

```bash
python3 tools/qmlcheck.py
```

Tokenises every `.qml` file and cross-references them without needing Qt. It
catches unbalanced braces, unterminated strings, imports pointing at nothing,
components used but never defined, typos in singleton member names, a required
property left unset at a call site, `Component.onCompleted` on a root that isn't
an Item, a `Schema.qml` key that doesn't resolve to anything in `Config.qml`,
a nested singleton member that does not exist (`Appearance.row.titel` is not an
error, it is `undefined` two levels down and it renders as a zero-size font), a
dotted config key that resolves to nothing whether it is written as a string or
as `Config.bar.thicknes`, a property assigned on one of this shell's own
components that the component never declared, a property name one letter away
from a real one on that component, the same property set twice in one block,
two things sharing an id in one file, a property that shadows one of Item's own
(`right` and `bottom` are anchor lines and FINAL; `scale` and `opacity` are not
FINAL, which is worse — the file loads and the property quietly drives how the
item is drawn), and `parent` referenced from inside an Animation, a Transform or
a Timer, none of which are Items and none of which have one; a `Behavior` on a
readonly property, which is a contradiction — a Behavior animates by writing;
a keybind naming a global shortcut the shell never declares, or an `ipc call`
naming a handler or a function that does not exist — both of which fail by the
key simply doing nothing;
and a config section declared in the adapter but never given a shortcut, which
makes `Config.thatSection` undefined at every single call site while every
dotted-key check still calls it valid; and a singleton named after a built-in
QML type, which the real type shadows in every file that imports QtQuick —
`Keys` and `Canvas` both cost a round of this, and the failure is never an
error, only a TypeError per binding and everything downstream quietly becoming
undefined. And three more that this round paid for in person: `root.someId`,
where `someId` is an id declared elsewhere in the file — an id lives in the
document's scope, not on the root object, so that expression is `undefined` and
the call on it throws; `someTimer.restart()` on a Timer whose `running` is a
binding, because restart() *assigns* running and the assignment destroys the
binding, after which the timer never starts from it again for the rest of the
session; and an assignment to a `readonly property`, which QML refuses at
runtime, so the feature silently does nothing. And, because a keybind that
reaches nothing is the quietest failure there is, it reads
`velvet-shell.conf` and `velvet-shell.lua` too and checks that every global
shortcut they bind is one the shell declares and every `ipc call` names a
handler and a function that exist.

Two of those rules exist because of one bad afternoon. A QML file that uses a
type without importing the module that provides it, or assigns a property a
built-in type does not have, does not fail the way you would expect: QML
refuses the **whole file**, Quickshell registers the singleton's name anyway,
and every call site then reports `Property 'x' of object Y is not a function`
from a hollow object — with the actual cause scrolled off the top of the log.
So the checker now verifies that every Quickshell type is covered by an import,
and warns about any member used exactly once on a type the shell otherwise uses
everywhere: a first use is allowed, but it is also exactly the moment to go and
read the documentation.

Its tokeniser is one state machine rather than several, which it did not used
to be: a template literal used to be scanned by a private loop that knew about
nested strings but not about regex literals, so a single
`` `${p.replace(/"/g, …)}` `` handed the rest of the file to the string scanner
and every check downstream ran on garbage — reported as a false error, but it
could just as easily have hidden a real one.

Most of those are the same shape of failure: QML refuses the entire file, and
the error names a line rather than a cause. The two that do not — a shadowed
`scale`, a stray `parent` — are worse, because the file loads and the damage is
silent.

Every rule is verified the same way it was written: by breaking something on
purpose and checking the checker notices — nineteen distinct faults this round,
nineteen caught. If you add a rule, add the fault too.

The dispatch queue in `services/Hypr.qml` is checked the same way, by
simulation rather than by reading: forty actions through all four combinations
of "which dialect Hyprland speaks" × "which one Velvet guessed", then again
with forced timeouts and the abandoned `hyprctl` answering late afterwards.
Every action has to run exactly once, none twice, and the queue has to be empty
at the end. That last case is the one that matters: a late reply used to be
applied to whichever job had moved into the finished one's place.

---

## When something is wrong

**The bar only half hides.** It used to: `REVEAL THRESHOLD` doubled as the slide
distance, so the strip that listens for your pointer was also the strip left
showing. They are separate now — **MODULES → TASKBAR → BEHAVIOUR → PEEK** is how much bar
stays visible when hidden, and it is `0`.

**The notification centre froze the shell.** The history held live
`Notification` objects, and an app going away left the list bound to something
that no longer existed. It holds plain records now and looks the live object up
only at the instant you press one of its buttons, the list is virtualised and
reuses its rows, and torn edges — the most expensive shape in the shell — are
loaded per critical alert instead of per card.

**The lock screen did nothing.** It picks a PAM service from `/etc/pam.d` and
refuses to lock until that service has proved it can authenticate. It used to
take the first one that existed and give up if it did not answer — which is
exactly what happens when `install.sh` could not write `/etc/pam.d/velvet`
without sudo. Now a refusal moves down the list (`velvet`, `hyprlock`,
`swaylock`, `system-auth`, `system-local-login`, `login`, `su`) and only a
machine where none of them answer is out of luck. **LOCK SCREEN →
STATUS** names the service in use and every one it tried.

**A button in the shell does nothing at all.** That used to mean Velvet was
speaking the wrong dispatch dialect. Hyprland accepts `focuswindow address:0x…`
from a `hyprland.conf` config and REJECTS that exact string from a
`hyprland.lua` one, where it wants `hl.dsp.focus({ window = "address:0x…" })`
instead — and a rejected dispatch raises nothing the shell can see. Velvet now
probes which dialect this Hyprland speaks at startup, reads the answer back on
every action, and retries in the other one if Hyprland said no. **WINDOWS →
DISPATCH** shows which one is in use and the last thing Hyprland refused.

**The same clock opens again every time you log in.** Three of the terminal
emulators Velvet supports — konsole, xfce4-terminal, xterm — cannot be told
what class to give their window, so a scene could not recognise its own
programs and opened another set. Velvet now gives every terminal program a
TITLE as well as a class and matches on either, which all eight can do.
**SHELL → THE DESKTOP → TERMINAL FOUND** says which one you have and whether it
can name its windows.

**A scene item says NO COMMAND.** It was captured from a window with no
matching `.desktop` entry, so Velvet knows where it sat but not how to start
it. Pick it in **DESKTOP** and the line under its name says so; give it a
command or take it off.

**`Unknown key SUPER SHIFT`.** An old `velvet-shell.lua` — modifiers join with
`" + "`, so it is `SUPER + SHIFT + F`, not `SUPER SHIFT + F`. Fixed in this
version; re-run `./install.sh` or copy the file over.

---

## Troubleshooting

**Nothing appears.** Run it in the foreground and read the errors:
`qs -c velvet`.

**`Super+Tab` does nothing.** The global shortcut needs Hyprland's global
shortcuts support. Swap the bind for the IPC form — the line is already in
`velvet-shell.conf`, commented:
`bind = SUPER, Tab, exec, qs -c velvet ipc call panels settings`

**The bar shows boxes instead of icons.** Material Symbols isn't installed.
Velvet falls back to unicode glyphs, which is legible but plain — install
`otf-material-symbols-git` for the real thing.

**The type looks wrong.** The Persona look wants a heavy display face. Install
Archivo Black, Anton, Bebas Neue or Oswald; Velvet picks the first one it finds,
or you can choose explicitly in **VISUALS → TYPEFACES**.

**No wallpapers in the carousel.** Point `wallpaper.directory` at your folder in
`~/.config/velvet/config.json`, then **WALLPAPER → RESCAN FOLDER**.

**The lock screen goes black / nothing happens.** Open **LOCK SCREEN**
and read the `STATUS` row — it says exactly what will happen when you lock. If it
says no locker is available, re-run `./install.sh` and accept the PAM file, or
install `hyprlock`. Use `TEST LOCK` to try it safely.

**The bar hides while I'm still reaching for it.** Raise **MODULES → TASKBAR → BEHAVIOUR →
HIDE DELAY**. It is the grace period between the pointer leaving the bar and the
bar sliding away.

**I broke the config.** Delete `~/.config/velvet/config.json`. Every default is
declared in `config/Config.qml` and gets rewritten on the next start.
