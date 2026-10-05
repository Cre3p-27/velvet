//  VELVET  ·  services/Weather.qml
//  wttr.in — no account, no API key, and it guesses your location from the
//  request unless you name one. Polled slowly; the weather is not urgent.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool ready: false
    property real temperature: 0
    property real feelsLike: 0
    property int humidity: 0
    property string description: ""
    property string place: ""
    property int code: 0
    property real maxTempC: 0
    property real minTempC: 0
    // Today's high/low arrived — a real flag, because 0° is a temperature
    // (and a winter's day with a high of −2° must still show it).
    property bool hasHighLow: false
    // The fluid lock's hourly strip: [{ time, tempC, code, precip, day }],
    // starting with the slot we are IN now and running on into tomorrow —
    // wttr hands out today from midnight, which put "NOW" on 0:00 at night.
    property var hourlyForecast: []
    // Every slot wttr sent (today and the next days), to cut the strip from.
    property var _slots: []

    function cutForecast(): void {
        const now = new Date();
        const hour = now.getHours() * 100 + now.getMinutes() * 100 / 60;
        const out = [];
        for (let i = 0; i < root._slots.length; i++) {
            const h = root._slots[i];
            // A slot covers three hours; it is over once its end has passed.
            if (h.day === 0 && h.time + 300 <= hour)
                continue;
            out.push(h);
        }
        root.hourlyForecast = out.slice(0, 12);
    }

    // The strip moves on by itself — a slot ends every three hours, and
    // the next fetch may be twenty minutes away.
    Timer {
        interval: 60000
        repeat: true
        running: root._slots.length > 0
        onTriggered: root.cutForecast()
    }

    // wttr's own condition codes, folded down to the icons we ship a fallback
    // glyph for. Anything unrecognised lands on a neutral cloud. Shared with
    // the forecast strip so every hour gets the same treatment.
    function iconFor(c: int): string {
        if ([113].indexOf(c) !== -1)
            return "light_mode";
        if ([116, 119, 122].indexOf(c) !== -1)
            return "cloud";
        if ([143, 248, 260].indexOf(c) !== -1)
            return "foggy";
        if (c >= 176 && c < 300)
            return "rainy";
        if ([386, 389, 392, 395, 200].indexOf(c) !== -1)
            return "thunderstorm";
        if (c >= 300 && c < 330)
            return "rainy";
        if (c >= 330 && c < 380)
            return "weather_snowy";
        return "cloud";
    }

    readonly property string icon: root.iconFor(root.code)

    // The condition folded into six moods — the wallpaper's day-and-night
    // veil reads these instead of the raw codes, so the tables live once.
    readonly property string mood: {
        if (!root.ready)
            return "";
        const c = root.code;
        if (c === 113)
            return "clear";
        if (c === 116 || c === 119 || c === 122)
            return "cloud";
        if (c === 143 || c === 248 || c === 260)
            return "fog";
        if ([386, 389, 392, 395, 200].indexOf(c) !== -1)
            return "thunder";
        // Sleet, snow and freezing variants before the wide rain band.
        if ((c >= 317 && c <= 338) || (c >= 362 && c <= 377) || c === 179 || c === 227 || c === 230 || c === 350)
            return "snow";
        if (c >= 176 && c < 360)
            return "rain";
        return "";
    }

    readonly property string short: root.ready ? `${Math.round(root.temperature)}°` : ""

    function refresh(): void {
        fetch.running = false;
        fetch.running = true;
    }

    Process {
        id: fetch

        running: Config.services.weather
        command: ["bash", "-c", `curl -sf --max-time 12 'https://wttr.in/${encodeURIComponent((Config.services.weatherLocation ?? "").trim()).replace(/%20/g, "+").replace(/'/g, "%27")}?format=j1' 2>/dev/null || true`]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (raw.length < 10)
                    return;
                try {
                    const data = JSON.parse(raw);
                    const now = data.current_condition?.[0];
                    if (!now)
                        return;

                    const metric = Config.services.weatherMetric;
                    root.temperature = parseFloat(metric ? now.temp_C : now.temp_F);
                    root.feelsLike = parseFloat(metric ? now.FeelsLikeC : now.FeelsLikeF);
                    root.humidity = parseInt(now.humidity) || 0;
                    root.description = (now.weatherDesc?.[0]?.value ?? "").trim();
                    root.code = parseInt(now.weatherCode) || 0;

                    const area = data.nearest_area?.[0];
                    root.place = area?.areaName?.[0]?.value ?? "";

                    // The fluid lock's brief info: today's high and low, and the
                    // hourly strip for the forecast row.
                    const day = data.weather?.[0];
                    const hi = parseFloat(metric ? day?.maxtempC : day?.maxtempF);
                    const lo = parseFloat(metric ? day?.mintempC : day?.mintempF);
                    root.hasHighLow = !isNaN(hi) && !isNaN(lo);
                    root.maxTempC = isNaN(hi) ? 0 : hi;
                    root.minTempC = isNaN(lo) ? 0 : lo;
                    const slots = [];
                    const days = data.weather ?? [];
                    for (let d = 0; d < Math.min(2, days.length); d++) {
                        const hourly = days[d]?.hourly ?? [];
                        for (let i = 0; i < hourly.length; i++) {
                            const h = hourly[i];
                            slots.push({
                                time: parseInt(h.time) || 0,
                                tempC: parseFloat(metric ? h.tempC : h.tempF) || 0,
                                code: parseInt(h.weatherCode) || 0,
                                precip: parseInt(h.chanceofrain) || 0,
                                day: d
                            });
                        }
                    }
                    root._slots = slots;
                    root.cutForecast();

                    root.ready = true;
                } catch (e) {
                    // Leave the last good reading in place rather than blanking.
                }
            }
        }
    }

    Timer {
        running: Config.services.weather
        interval: Math.max(5, Config.services.weatherInterval) * 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Config.services
        function onWeatherLocationChanged(): void {
            root.refresh();
        }
        function onWeatherMetricChanged(): void {
            root.refresh();
        }
    }
}
