#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ==============================================================================
#  PREMIUM WALLPAPER CAROUSEL - 4K VELVET EDITION (KEYBOARD NAV UPGRADE)
# ==============================================================================

import sys
import os
import json
import subprocess
import wave
import struct
import random
import math
from pathlib import Path

os.environ["QT_QPA_PLATFORM"] = "wayland;xcb"

try:
    from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout,
                                 QPushButton, QLabel, QMenu, QMainWindow)
    from PyQt6.QtGui import (QIcon, QPainter, QPixmap, QColor, QPainterPath,
                             QLinearGradient, QBrush, QPen, QTransform, QCursor)
    from PyQt6.QtCore import (Qt, QSize, QTimer, QThread, pyqtSignal, QRectF)
    from PIL import Image
except ImportError as e:
    print(f"FEHLER: Abhängigkeiten fehlen!\n{e}")
    sys.exit(1)


# ==============================================================================
#  1. PFADE
# ==============================================================================
WALLPAPER_DIR = os.path.expanduser("~/Bilder/Wallpapers/")
CACHE_DIR = os.path.expanduser("~/.cache/premium_carousel/")
THUMB_DIR = os.path.join(CACHE_DIR, "thumbs")
CACHE_FILE = os.path.join(CACHE_DIR, "data.json")
FAV_FILE = os.path.expanduser("~/.config/premium_carousel_favs.json")
SOUND_FILE = os.path.join(CACHE_DIR, "creamy_poof.wav")

os.makedirs(THUMB_DIR, exist_ok=True)

COLORS = {
    "Rot": (255, 50, 50), "Grün": (50, 255, 50), "Blau": (50, 50, 255),
    "Gelb": (255, 255, 50), "Lila": (200, 50, 255), "Grau/Dunkel": (100, 100, 100)
}

# ==============================================================================
#  2. CREAMY AUDIO SYNTHESIZER
# ==============================================================================
class AudioSynthesizer:
    @staticmethod
    def generate_poof_sound():
        if os.path.exists(SOUND_FILE): return
        try:
            with wave.open(SOUND_FILE, 'w') as f:
                f.setnchannels(1)
                f.setsampwidth(2)
                f.setframerate(44100)
                duration = 0.25
                frames = int(duration * 44100)
                data = bytearray()
                last_noise = 0.0
                for i in range(frames):
                    envelope = math.exp(-5.0 * i / frames)
                    white = random.uniform(-1.0, 1.0)
                    brown = (last_noise + (0.05 * white)) / 1.05
                    last_noise = brown
                    thump_freq = 70 * math.exp(-8.0 * i / frames)
                    thump = math.sin(2 * math.pi * thump_freq * (i / 44100.0))
                    sample = (brown * 0.4 + thump * 0.8) * envelope
                    val = int(sample * 32700)
                    val = max(-32768, min(32767, val))
                    data.extend(struct.pack('<h', val))
                f.writeframes(data)
        except Exception:
            pass

    @staticmethod
    def play_sound():
        if os.path.exists(SOUND_FILE):
            subprocess.Popen(["aplay", "-q", SOUND_FILE], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# ==============================================================================
#  3. HIGH-PERFORMANCE THREADING
# ==============================================================================
class ImageLoaderThread(QThread):
    progress = pyqtSignal(int, int)
    finished_loading = pyqtSignal(list)

    def __init__(self, existing_data):
        super().__init__()
        self.existing_data = existing_data

    def get_closest_color(self, rgb):
        min_dist = float('inf')
        closest = "Grau/Dunkel"
        for name, target in COLORS.items():
            dist = sum((a - b) ** 2 for a, b in zip(rgb, target))
            if dist < min_dist:
                min_dist = dist
                closest = name
        return closest

    def run(self):
        valid_exts = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
        if not os.path.exists(WALLPAPER_DIR):
            self.finished_loading.emit([])
            return
        paths = [p for p in Path(WALLPAPER_DIR).rglob("*") if p.is_file() and p.suffix.lower() in valid_exts]
        loaded_items = []
        total = len(paths)
        for i, p in enumerate(sorted(paths)):
            full_path = str(p)
            file_name = p.name
            thumb_path = os.path.join(THUMB_DIR, f"thumb_{file_name}.jpg")
            if full_path not in self.existing_data:
                try:
                    img_tiny = Image.open(full_path).convert("RGB").resize((1, 1))
                    rgb = img_tiny.getpixel((0, 0))[:3]
                    self.existing_data[full_path] = {"rgb": rgb, "category": self.get_closest_color(rgb)}
                except Exception:
                    self.existing_data[full_path] = {"rgb": (0,0,0), "category": "Grau/Dunkel"}
            if not os.path.exists(thumb_path):
                try:
                    img = Image.open(full_path).convert("RGB")
                    img.thumbnail((1200, 1200))
                    img.save(thumb_path, "JPEG", quality=85)
                except Exception:
                    thumb_path = full_path
            loaded_items.append({
                "path": full_path, "thumb": thumb_path,
                "name": file_name, "category": self.existing_data[full_path]["category"]
            })
            if i % 5 == 0: self.progress.emit(i, total)
        self.finished_loading.emit(loaded_items)

# ==============================================================================
#  4. CUSTOM 3D COVER-FLOW ENGINE
# ==============================================================================
class CoverFlowWidget(QWidget):
    item_activated = pyqtSignal(str)
    toggle_favorite = pyqtSignal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.setMouseTracking(True)
        self.parent_app = parent
        self.items = []
        self.target_index = 0
        self.current_anim_index = 0.0
        self.anim_timer = QTimer(self)
        self.anim_timer.timeout.connect(self.update_physics)
        self.anim_timer.start(16)
        self.pixmap_cache = {}
        self.reflection_cache = {}

    def set_items(self, items):
        self.items = items
        if items:
            self.target_index = len(items) // 2
            self.current_anim_index = float(self.target_index)
        self.update()

    def get_pixmap(self, path):
        if path not in self.pixmap_cache: self.pixmap_cache[path] = QPixmap(path)
        return self.pixmap_cache[path]

    def get_reflection(self, path):
        if path not in self.reflection_cache:
            pixmap = self.get_pixmap(path)
            reflection = QPixmap(pixmap.size())
            reflection.fill(Qt.GlobalColor.transparent)
            painter = QPainter(reflection)
            transform = QTransform().scale(1, -1).translate(0, -pixmap.height())
            painter.setTransform(transform)
            painter.drawPixmap(0, 0, pixmap)
            painter.setCompositionMode(QPainter.CompositionMode.CompositionMode_DestinationIn)
            gradient = QLinearGradient(0, 0, 0, pixmap.height())
            gradient.setColorAt(0.0, QColor(0, 0, 0, 100))
            gradient.setColorAt(0.5, QColor(0, 0, 0, 20))
            gradient.setColorAt(1.0, QColor(0, 0, 0, 0))
            painter.setTransform(QTransform())
            painter.fillRect(0, 0, pixmap.width(), pixmap.height(), gradient)
            painter.end()
            self.reflection_cache[path] = reflection
        return self.reflection_cache[path]

    def update_physics(self):
        diff = self.target_index - self.current_anim_index
        self.current_anim_index += diff * 0.12
        if abs(diff) > 0.001: self.update()

    def get_current_item(self):
        if 0 <= self.target_index < len(self.items): return self.items[self.target_index]
        return None

    def keyPressEvent(self, event):
        if not self.items and self.parent_app.current_pane == 1: 
            return

        # Navigation: Wechsel zwischen Kategorien (oben) und Bildern (unten)
        if event.key() == Qt.Key.Key_Up:
            self.parent_app.focus_menu()
            AudioSynthesizer.play_sound()
            return
        elif event.key() == Qt.Key.Key_Down:
            self.parent_app.focus_carousel()
            AudioSynthesizer.play_sound()
            return

        # Wenn Top-Bar fokussiert ist, steuern Links/Rechts/Enter das Menü
        if self.parent_app.current_pane == 0:
            if event.key() == Qt.Key.Key_Left:
                self.parent_app.navigate_menu(-1)
                AudioSynthesizer.play_sound()
            elif event.key() == Qt.Key.Key_Right:
                self.parent_app.navigate_menu(1)
                AudioSynthesizer.play_sound()
            elif event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
                self.parent_app.activate_menu_item()
                AudioSynthesizer.play_sound()
            elif event.key() == Qt.Key.Key_Escape:
                self.parent_app.close()
            return

        # Wenn Cover-Flow fokussiert ist, steuern Links/Rechts/Enter die Bilder
        if event.key() == Qt.Key.Key_Left:
            if self.target_index > 0:
                self.target_index -= 1
                AudioSynthesizer.play_sound()
        elif event.key() == Qt.Key.Key_Right:
            if self.target_index < len(self.items) - 1:
                self.target_index += 1
                AudioSynthesizer.play_sound()
        elif event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
            item = self.get_current_item()
            if item: self.item_activated.emit(item["path"])
        elif event.key() == Qt.Key.Key_F:
            item = self.get_current_item()
            if item: self.toggle_favorite.emit(item["path"])
        elif event.key() == Qt.Key.Key_Escape:
            self.parent_app.close()
        else:
            super().keyPressEvent(event)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.RightButton:
            item = self.get_current_item()
            if item: self.parent_app.show_context_menu(event.globalPosition().toPoint(), item["path"])
        super().mousePressEvent(event)

    def paintEvent(self, event):
        if not self.items: return
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform)
        w, h = self.width(), self.height()
        center_x, center_y = w / 2, h / 2
        
        # Carousel abdunkeln, wenn das Menü oben fokussiert ist
        pane_opacity_mult = 0.4 if self.parent_app.current_pane == 0 else 1.0
        
        draw_list = [(i, i - self.current_anim_index, item) for i, item in enumerate(self.items) if abs(i - self.current_anim_index) <= 2.5]
        draw_list.sort(key=lambda x: abs(x[1]), reverse=True)
        
        for i, dist, item in draw_list:
            scale = max(0.4, 1.0 - abs(dist) * 0.25)
            opacity = max(0.0, 1.0 - abs(dist) * 0.35) * pane_opacity_mult
            x_offset = dist * 750
            final_w, final_h = 1200 * scale, 675 * scale
            x = center_x + x_offset - (final_w / 2)
            y = center_y - (final_h / 2) - 50
            
            painter.setOpacity(opacity)
            path = QPainterPath()
            path.addRoundedRect(QRectF(x, y, final_w, final_h), 25, 25)
            painter.setClipPath(path)
            painter.drawPixmap(int(x), int(y), int(final_w), int(final_h), self.get_pixmap(item["thumb"]))
            painter.setClipping(False)
            
            reflection_y = y + final_h + 10
            reflection_path = QPainterPath()
            reflection_path.addRoundedRect(QRectF(x, reflection_y, final_w, final_h), 25, 25)
            painter.setClipPath(reflection_path)
            painter.drawPixmap(int(x), int(reflection_y), int(final_w), int(final_h), self.get_reflection(item["thumb"]))
            painter.setClipping(False)
            
            if abs(dist) < 0.1:
                pen = QPen(QColor(255, 255, 255, int(220 * pane_opacity_mult)))
                pen.setWidth(5)
                painter.setPen(pen)
                painter.drawRoundedRect(QRectF(x, y, final_w, final_h), 25, 25)
                painter.setOpacity(1.0 * pane_opacity_mult)
                display_name = ("⭐ " if item["path"] in self.parent_app.favorites else "") + item["name"]
                font = painter.font()
                font.setPointSize(26)
                font.setBold(True)
                painter.setFont(font)
                painter.setPen(QColor(0, 0, 0, 180))
                painter.drawText(QRectF(x+2, y-58, final_w, 50), Qt.AlignmentFlag.AlignCenter, display_name)
                painter.setPen(QColor(255, 255, 255, 255))
                painter.drawText(QRectF(x, y-60, final_w, 50), Qt.AlignmentFlag.AlignCenter, display_name)

# ==============================================================================
#  5. HAUPT-APP & UI (MIT FOCUS MANAGEMENT)
# ==============================================================================
class WallpaperApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Premium Wallpaper Carousel")
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setFixedSize(3840, 2160)
        
        self.all_items = []
        self.favorites = []
        self.image_data_cache = {}
        
        # Focus State (1 = Carousel, 0 = Menu Top-Bar)
        self.current_pane = 1 
        self.menu_index = 1
        self.menu_buttons = []
        self.filter_names = ["Favoriten", None] + list(COLORS.keys())
        
        self.load_cache()
        self.init_ui()
        AudioSynthesizer.generate_poof_sound()
        self.loader = ImageLoaderThread(self.image_data_cache)
        self.loader.progress.connect(self.update_loading_text)
        self.loader.finished_loading.connect(self.on_load_finished)
        self.loader.start()

    def load_cache(self):
        if os.path.exists(FAV_FILE):
            with open(FAV_FILE, "r") as f: self.favorites = json.load(f)
        if os.path.exists(CACHE_FILE):
            with open(CACHE_FILE, "r") as f: self.image_data_cache = json.load(f)

    def save_cache(self):
        with open(FAV_FILE, "w") as f: json.dump(self.favorites, f)
        with open(CACHE_FILE, "w") as f: json.dump(self.image_data_cache, f)

    def init_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        self.main_layout = QVBoxLayout(central_widget)
        self.main_layout.setContentsMargins(0, 0, 0, 0)
        self.bg_widget = QWidget()
        self.bg_widget.setStyleSheet("background-color: rgba(12, 12, 15, 0.85);")
        self.main_layout.addWidget(self.bg_widget)
        
        layout = QVBoxLayout(self.bg_widget)
        layout.setContentsMargins(80, 60, 80, 60)
        layout.setSpacing(20)
        top_bar = QHBoxLayout()
        top_bar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        
        # 0. Favoriten Button
        self.btn_fav = QPushButton("⭐ Favoriten")
        self.btn_fav.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))
        self.btn_fav.clicked.connect(lambda: self.apply_filter("Favoriten", 0))
        top_bar.addWidget(self.btn_fav)
        self.menu_buttons.append(self.btn_fav)
        
        # 1. Alle Bilder Button
        self.btn_all = QPushButton("Alle Bilder")
        self.btn_all.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))
        self.btn_all.clicked.connect(lambda: self.apply_filter(None, 1))
        top_bar.addWidget(self.btn_all)
        self.menu_buttons.append(self.btn_all)
        
        # 2-7. Color Buttons
        for i, (name, rgb) in enumerate(COLORS.items()):
            btn = QPushButton()
            btn.setFixedSize(45, 45)
            btn.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))
            btn.clicked.connect(lambda checked, n=name, idx=i+2: self.apply_filter(n, idx))
            top_bar.addWidget(btn)
            self.menu_buttons.append(btn)
            
        layout.addLayout(top_bar)
        
        self.loading_label = QLabel("Initialisiere 4K Cover-Flow Engine...")
        self.loading_label.setStyleSheet("color: white; font-size: 32px; font-weight: bold;")
        self.loading_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(self.loading_label)
        
        self.carousel = CoverFlowWidget(self)
        self.carousel.item_activated.connect(self.execute_wallpaper_change)
        self.carousel.toggle_favorite.connect(self.toggle_favorite_path)
        self.carousel.hide()
        layout.addWidget(self.carousel, 1)
        
        self.update_menu_ui()

    def update_menu_ui(self):
        for i, btn in enumerate(self.menu_buttons):
            is_active = (self.current_pane == 0 and i == self.menu_index)
            if i == 0:
                btn.setStyleSheet(self.get_text_btn_style("#d4af37", is_active))
            elif i == 1:
                btn.setStyleSheet(self.get_text_btn_style("#ffffff", is_active))
            else:
                name = self.filter_names[i]
                rgb = COLORS[name]
                hex_color = f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"
                btn.setStyleSheet(self.get_color_btn_style(hex_color, is_active))

    def get_text_btn_style(self, color, is_active):
        border = "4px solid #ffffff" if is_active else f"2px solid {color}"
        bg = "rgba(255, 255, 255, 0.15)" if is_active else "transparent"
        return f"QPushButton {{ background-color: {bg}; color: {color}; border: {border}; border-radius: 12px; padding: 12px 30px; font-size: 18px; font-weight: bold; }}"

    def get_color_btn_style(self, hex_color, is_active):
        border = "4px solid #ffffff" if is_active else "3px solid #1a1e1c"
        return f"QPushButton {{ background-color: {hex_color}; border-radius: 22px; border: {border}; }}"

    def focus_menu(self):
        if self.current_pane == 1:
            self.current_pane = 0
            self.update_menu_ui()
            self.carousel.update()

    def focus_carousel(self):
        if self.current_pane == 0:
            self.current_pane = 1
            self.update_menu_ui()
            self.carousel.update()

    def navigate_menu(self, direction):
        if self.current_pane == 0:
            self.menu_index = (self.menu_index + direction) % len(self.menu_buttons)
            self.update_menu_ui()

    def activate_menu_item(self):
        if self.current_pane == 0:
            filter_name = self.filter_names[self.menu_index]
            self.apply_filter(filter_name, self.menu_index)

    def update_loading_text(self, current, total):
        self.loading_label.setText(f"Lade 4K Texturen... ({current}/{total})")

    def on_load_finished(self, items):
        self.all_items = items
        self.save_cache()
        self.loading_label.hide()
        self.apply_filter(None, 1)
        self.carousel.show()
        self.carousel.setFocus()

    def apply_filter(self, filter_name, clicked_idx=None):
        if clicked_idx is not None:
            self.menu_index = clicked_idx
            
        filtered = []
        for item in self.all_items:
            if filter_name == "Favoriten" and item["path"] not in self.favorites: continue
            if filter_name and filter_name != "Favoriten" and item["category"] != filter_name: continue
            filtered.append(item)
            
        self.carousel.set_items(filtered)
        self.update_menu_ui()
        # Fokus nach Filter-Anwendung automatisch wieder nach unten setzen
        self.focus_carousel()

    def toggle_favorite_path(self, path):
        if path in self.favorites: self.favorites.remove(path)
        else: self.favorites.append(path)
        self.save_cache()
        self.carousel.update()

    def show_context_menu(self, global_pos, path):
        is_fav = path in self.favorites
        menu = QMenu(self)
        menu.setStyleSheet("QMenu { background: #1a1e1c; border: 1px solid #ffffff; border-radius: 8px; } QMenu::item { padding: 12px 30px; color: #fff; font-size: 16px; font-weight: bold; }")
        fav_action = menu.addAction("❌ Aus Favoriten entfernen" if is_fav else "⭐ Zu Favoriten hinzufügen")
        if menu.exec(global_pos) == fav_action: self.toggle_favorite_path(path)

# ==============================================================================
#  6. SHELL INTEGRATION (MIT EXTERNEM SKRIPT)
# ==============================================================================
    def execute_wallpaper_change(self, img_path):
        rgb = self.image_data_cache.get(img_path, {}).get("rgb", (0, 168, 255))
        hex_color = f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"
        
        theme_dir = os.path.expanduser("~/.config/quickshell/persona/")
        os.makedirs(theme_dir, exist_ok=True)
        
        theme_content = f'''import QtQuick
QtObject {{
    property string accent: "{hex_color}"
    property string bgDark: "#000000" // Echtes OLED-Schwarz
    property string wallpaper: "file://{img_path}"
}}
'''
        with open(os.path.join(theme_dir, "Theme.qml"), "w") as f:
            f.write(theme_content)

#
        clean_env = os.environ.copy()
        clean_env.pop("QT_QPA_PLATFORM", None)

        # (An external shell's wallpaper command used to be called here; it is
        # not installed, and Velvet takes its wallpaper from its own wheel.)

        switcher_script = os.path.expanduser("~/scripts/layout_switcher.py")
        if os.path.exists(switcher_script):
            subprocess.Popen(["python3", switcher_script, img_path], start_new_session=True)
        else:
            print(f"Warnung: {switcher_script} nicht gefunden!")

        self.close()

# ==============================================================================
#  7. START-KNOPF
# ==============================================================================
if __name__ == '__main__':
    app = QApplication(sys.argv)
    app.setDesktopFileName("premium_carousel")
    window = WallpaperApp()
    window.showFullScreen()
    sys.exit(app.exec())
