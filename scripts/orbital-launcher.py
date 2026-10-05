#!/usr/bin/env python3
import sys, math, subprocess, os
from PyQt6.QtWidgets import QApplication, QWidget, QLineEdit, QLabel, QGraphicsDropShadowEffect
from PyQt6.QtCore import Qt, QTimer, QPropertyAnimation, QEasingCurve, QRect, QPointF
from PyQt6.QtGui import QFont, QPainter, QColor, QPainterPath, QPen, QRadialGradient, QBrush

# ==========================================
# 1. CORE PHYSICS ENGINE
# ==========================================
class SpringPhysics:
    def __init__(self, tension=120, friction=12):
        self.tension = tension
        self.friction = friction
        self.velocity = 0.0
        self.current = 0.0
        self.target = 0.0

    def update(self, dt=0.016):
        # Hooke's Law (F = -kx - cv) für echte Apple-ähnliche Bounce-Physik
        displacement = self.current - self.target
        spring_force = -self.tension * displacement
        damping_force = -self.friction * self.velocity
        acceleration = spring_force + damping_force
        self.velocity += acceleration * dt
        self.current += self.velocity * dt
        return self.current

# ==========================================
# 2. MAIN APPLICATION WIDGET
# ==========================================
class OrbitalEngine(QWidget):
    def __init__(self):
        super().__init__()
        
        # Wayland / Hyprland Overrides
        self.setWindowFlags(Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint | Qt.WindowType.Tool)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setFixedSize(1400, 900)

        # Die Datenbank deiner meistgenutzten Apps
        self.apps = [
            {"name": "Spotify", "cmd": "spotify", "color": (30, 215, 96)},
            {"name": "Steam", "cmd": "steam", "color": (42, 71, 94)},
            {"name": "Discord", "cmd": "discord", "color": (88, 101, 242)},
            {"name": "Modrinth", "cmd": "modrinth-app", "color": (0, 175, 92)},
            {"name": "Chrome", "cmd": "google-chrome-stable", "color": (219, 68, 55)},
            {"name": "Terminal", "cmd": "kitty", "color": (203, 166, 247)},
            {"name": "Files", "cmd": "thunar", "color": (137, 180, 250)},
            {"name": "Settings", "cmd": "kitty -e btop", "color": (243, 139, 168)}
        ]
        self.num_apps = len(self.apps)
        self.labels = []
        
        # Initialisiere die Physik
        self.angle_physics = SpringPhysics(tension=150, friction=14)
        self.glow_radius = 0.0
        self.glow_increasing = True
        self.selected_index = 0
        self.is_typing = False

        self.setup_ui()
        
        # 60 FPS Game-Loop
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.game_loop)
        self.timer.start(16)

    def setup_ui(self):
        # Das Dynamic Island / Search Bar
        self.search_bar = QLineEdit(self)
        self.search_bar.setPlaceholderText("Search System...")
        self.search_bar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.search_bar.setFont(QFont("Inter", 26, QFont.Weight.ExtraBold))
        self.search_bar.setStyleSheet("""
            QLineEdit {
                background-color: rgba(10, 10, 15, 240);
                color: #ffffff;
                border: 2px solid rgba(255, 255, 255, 40);
                border-radius: 45px;
                padding: 10px 30px;
                selection-background-color: rgba(243, 139, 168, 200);
            }
            QLineEdit:focus {
                border: 2px solid rgba(255, 255, 255, 100);
            }
        """)
        self.search_bar.setGeometry(400, 405, 600, 90)
        self.search_bar.returnPressed.connect(self.launch_app)
        self.search_bar.textEdited.connect(self.on_type)
        
        # Shadow für die Island
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(50)
        shadow.setColor(QColor(0, 0, 0, 180))
        shadow.setOffset(0, 10)
        self.search_bar.setGraphicsEffect(shadow)
        self.search_bar.setFocus()

        # App-Labels generieren
        for app in self.apps:
            lbl = QLabel("", self)
            lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            self.labels.append(lbl)

        self.update_selection_text()

    def on_type(self):
        self.is_typing = True

    def update_selection_text(self):
        if not self.is_typing:
            self.search_bar.setText(self.apps[self.selected_index]["name"])

    # ==========================================
    # 3. RENDER ENGINE & COMPOSITING
    # ==========================================
    def paintEvent(self, event):
        # Custom Painting für den pulsierenden Glow hinter der aktiven App
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        
        center_x, center_y = 700, 450
        
        # Atmender Glow-Effekt
        if self.glow_increasing:
            self.glow_radius += 0.5
            if self.glow_radius > 30: self.glow_increasing = False
        else:
            self.glow_radius -= 0.5
            if self.glow_radius < 10: self.glow_increasing = True

        # Hintergrund-Glow der Island
        grad = QRadialGradient(QPointF(center_x, center_y), 400)
        app_color = self.apps[self.selected_index]["color"]
        grad.setColorAt(0, QColor(app_color[0], app_color[1], app_color[2], int(40 + self.glow_radius)))
        grad.setColorAt(1, QColor(0, 0, 0, 0))
        painter.setBrush(QBrush(grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawRect(self.rect())

    def game_loop(self):
        # Physik updaten
        current_angle = self.angle_physics.update()
        
        center_x, center_y = 700, 450
        radius_x, radius_y = 550, 220
        
        render_queue = []

        # 3D Transformationen berechnen
        for i, lbl in enumerate(self.labels):
            offset = (2 * math.pi / self.num_apps) * i
            angle = current_angle + offset
            
            # Sinus-Kurve für die Z-Tiefe
            depth = math.sin(angle)
            scale = 1.0 + (depth * 0.5) 
            
            width = int(220 * scale)
            height = int(70 * scale)
            
            x = center_x + radius_x * math.cos(angle) - (width / 2)
            y = center_y + radius_y * depth - (height / 2)
            
            render_queue.append({
                "lbl": lbl, "depth": depth, "x": x, "y": y, 
                "w": width, "h": height, "scale": scale, "idx": i
            })

        # Nach Z-Index sortieren (hinten zuerst rendern)
        render_queue.sort(key=lambda item: item["depth"])
        
        front_app = None
        for item in render_queue:
            lbl = item["lbl"]
            lbl.setGeometry(int(item["x"]), int(item["y"]), item["w"], item["h"])
            lbl.setText(self.apps[item["idx"]]["name"])
            
            alpha_bg = int(20 + ((item["depth"] + 1) / 2) * 235)
            alpha_text = int(60 + ((item["depth"] + 1) / 2) * 195)
            
            if item["depth"] > 0.9:
                front_app = item["idx"]
                c = self.apps[item["idx"]]["color"]
                lbl.setStyleSheet(f"""
                    QLabel {{
                        background-color: rgba({c[0]}, {c[1]}, {c[2]}, 220);
                        color: white;
                        border-radius: {item["h"] // 2}px;
                        border: 3px solid rgba(255, 255, 255, 255);
                    }}
                """)
                lbl.setFont(QFont("Inter", int(20 * item["scale"]), QFont.Weight.Black))
                lbl.raise_()
            else:
                lbl.setStyleSheet(f"""
                    QLabel {{
                        background-color: rgba(255, 255, 255, {int(alpha_bg * 0.08)});
                        color: rgba(255, 255, 255, {alpha_text});
                        border-radius: {item["h"] // 2}px;
                        border: 1px solid rgba(255, 255, 255, {int(alpha_bg * 0.15)});
                    }}
                """)
                lbl.setFont(QFont("Inter", int(16 * item["scale"]), QFont.Weight.Bold))
                if item["depth"] < 0:
                    lbl.lower()

        # Update den Text nur, wenn ein neues Element exakt vorne einrastet
        if front_app is not None and front_app != self.selected_index:
            self.selected_index = front_app
            self.update_selection_text()

        self.search_bar.raise_()
        for item in render_queue:
            if item["depth"] > 0.7:
                item["lbl"].raise_()
                
        # Trigger Repaint für den Glow
        self.update()

    # ==========================================
    # 4. INPUT & EVENT HANDLING
    # ==========================================
    def keyPressEvent(self, event):
        slot_dist = 2 * math.pi / self.num_apps
        current_slot = round(self.angle_physics.target / slot_dist)
        
        if event.key() == Qt.Key.Key_Right:
            self.angle_physics.target = (current_slot - 1) * slot_dist
            self.is_typing = False
            self.search_bar.clear()
        elif event.key() == Qt.Key.Key_Left:
            self.angle_physics.target = (current_slot + 1) * slot_dist
            self.is_typing = False
            self.search_bar.clear()
        elif event.key() == Qt.Key.Key_Escape:
            self.close()
        else:
            super().keyPressEvent(event)

    def launch_app(self):
        text = self.search_bar.text().lower()
        cmd = text
        for app in self.apps:
            if app["name"].lower() == text:
                cmd = app["cmd"]
                break
        
        # Dispatched in den Hintergrund, trennt den Prozess von PyQt
        os.system(f'hyprctl dispatch exec "{cmd}"')
        QApplication.quit()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    app.setApplicationName("orbital-engine") # DER NAME FÜR DIE HYPRLAND RULE
    launcher = OrbitalEngine()
    launcher.show()
    launcher.activateWindow()
    sys.exit(app.exec())
