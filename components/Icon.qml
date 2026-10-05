//  VELVET  ·  components/Icon.qml
//  Material Symbols when the font is installed; a readable unicode fallback
//  when it isn't, so the bar never shows tofu.
import qs.config
import QtQuick

Text {
    id: root

    property string name: ""
    property bool filled: false
    property real grade: 0

    readonly property var fallbacks: ({
            "power_settings_new": "⏻",
            "settings": "⚙",
            "search": "⌕",
            "close": "✕",
            "check": "✓",
            "chevron_right": "›",
            "chevron_left": "‹",
            "expand_more": "⌄",
            "expand_less": "⌃",
            "lan": "⇄",
            "network_wifi": "▲",
            "network_wifi_3_bar": "▲",
            "network_wifi_2_bar": "△",
            "network_wifi_1_bar": "△",
            "signal_wifi_0_bar": "△",
            "signal_wifi_off": "⊘",
            "bluetooth": "ᛗ",
            "bluetooth_disabled": "⊘",
            "volume_up": "▶",
            "volume_down": "▷",
            "volume_off": "⊘",
            "mic": "☉",
            "mic_off": "⊘",
            "battery_full": "▮",
            "battery_charging_full": "⚡",
            "battery_alert": "⚠",
            "memory": "▦",
            "developer_board": "▤",
            "device_thermostat": "↑",
            "light_mode": "☀",
            "dark_mode": "☾",
            "notifications": "●",
            "notifications_off": "○",
            "calculate": "∑",
            "terminal": "▸",
            "apps": "∷",
            "image": "▣",
            "star": "★",
            "star_border": "☆",
            "lock": "⚿",
            "bedtime": "☾",
            "restart_alt": "↻",
            "logout": "→",
            "tune": "≡",
            "palette": "◐",
            "monitor": "▭",
            "keyboard": "⌨",
            "folder": "▱",
            "arrow_back": "←",
            "arrow_forward": "→",
            "play_arrow": "▶",
            "pause": "⏸",
            "skip_next": "⏭",
            "skip_previous": "⏮",
            "cloud": "☁",
            "rainy": "☂",
            "foggy": "≈",
            "thunderstorm": "⚡",
            "weather_snowy": "❄",
            "graphic_eq": "⋮⋮",
            "photo_camera": "▣",
            "timer": "◷",
            "drag_handle": "⋯",
            "music_note": "♪",
            "keyboard_alt": "⌨",
            "visibility": "◉",
            "visibility_off": "◌",
            "warning": "⚠",
            "hard_drive": "▤",
            "checklist": "☑",
            "add": "＋",
            "push_pin": "✱",
            "bolt": "ϟ",
            "auto_awesome": "✦",
            "wifi": "⌁",
            "airplane": "✈",
            "headset": "♫",
            "mouse": "▧",
            "speaker": "◖",
            "tv": "▭",
            "smartphone": "▯",
            "videocam": "◎",
            "watch": "◷",
            "computer": "▢",
            "sports_esports": "⌹",
            "refresh": "↻",
            "bluetooth_searching": "ᛗ",
            "bluetooth_connected": "ᛗ",
            "bluetooth_audio": "♫",
            "delete": "✕",
            "delete_forever": "✕",
            "add_task": "☑",
            "task_alt": "✓",
            "check_box": "☑",
            "check_box_outline_blank": "☐",
            "wifi_find": "⌕",
            "signal_cellular_alt": "▮"
        })

    text: Appearance.hasIconFont ? name : (fallbacks[name] ?? "▪")
    font.family: Appearance.hasIconFont ? Appearance.fontFamily.icon : Appearance.fontFamily.body
    font.pixelSize: Appearance.font.size.large
    font.weight: filled ? Font.DemiBold : Font.Normal
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    renderType: Text.QtRendering
    antialiasing: true
}
