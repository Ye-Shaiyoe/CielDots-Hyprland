#!/usr/bin/env python3
# /* ---- 💫 CielDots — Weather Widget 💫 ---- */
# Fetches weather from wttr.in — no API key needed
# Usage:
#   weather.py              → Waybar module output (JSON)
#   weather.py --widget     → Full overlay widget (requires notify-send or eww)
#   weather.py --fetch      → Force refresh cache
#   weather.py --plain      → Plain text summary

import json
import os
import sys
import time
import argparse
import subprocess
from pathlib import Path
from datetime import datetime, timezone
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError


CACHE_FILE   = Path.home() / ".cache" / "cieldots-weather.json"
CACHE_TTL    = 1800   # 30 minutes
REQUEST_TIMEOUT = 5   # seconds
WTTR_URL     = "https://wttr.in/?format=j1"

# ── Weather condition → Nerd Font icon ───────────────────────
CONDITION_ICONS = {
    "sunny":            "󰖙",
    "clear":            "󰖙",
    "partly cloudy":    "󰖕",
    "cloudy":           "󰖐",
    "overcast":         "󰖐",
    "mist":             "󰖑",
    "fog":              "󰖑",
    "rain":             "󰖗",
    "drizzle":          "󰖗",
    "shower":           "󰖗",
    "thunderstorm":     "󰖓",
    "thunder":          "󰖓",
    "snow":             "󰖘",
    "blizzard":         "󰖘",
    "sleet":            "󰖘",
    "hail":             "󰖒",
    "wind":             "󰖝",
    "tornado":          "󰖝",
    "night clear":      "󰖔",
    "night cloudy":     "󰖑",
}

WIND_DIRS = {
    "N": "↑", "NE": "↗", "E": "→", "SE": "↘",
    "S": "↓", "SW": "↙", "W": "←", "NW": "↖",
}


def condition_icon(desc: str) -> str:
    desc_lower = desc.lower()
    for key, icon in CONDITION_ICONS.items():
        if key in desc_lower:
            return icon
    return "󰖐"  # default: cloud


# ── Cache helpers ─────────────────────────────────────────────

def cache_age() -> float:
    """Returns age of cache in seconds, or inf if not exists"""
    try:
        mtime = CACHE_FILE.stat().st_mtime
        return time.time() - mtime
    except FileNotFoundError:
        return float("inf")


def load_cache() -> dict | None:
    try:
        with open(CACHE_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def save_cache(data: dict):
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CACHE_FILE, "w") as f:
        json.dump(data, f)


# ── Fetch ─────────────────────────────────────────────────────

def fetch_weather() -> dict | None:
    try:
        req = Request(WTTR_URL, headers={"User-Agent": "CielDots/1.0"})
        with urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            raw = json.loads(resp.read().decode())
            save_cache(raw)
            return raw
    except (URLError, HTTPError, json.JSONDecodeError, OSError):
        return None


def get_weather(force_refresh: bool = False) -> tuple[dict | None, bool]:
    """Returns (data, from_cache)"""
    age = cache_age()

    if not force_refresh and age < CACHE_TTL:
        data = load_cache()
        if data:
            return data, True

    data = fetch_weather()
    if data:
        return data, False

    # Fallback to stale cache
    data = load_cache()
    return data, True


# ── Parsers ──────────────────────────────────────────────────

def parse_current(data: dict) -> dict:
    cur = data["current_condition"][0]
    area = data.get("nearest_area", [{}])[0]

    city = area.get("areaName", [{}])[0].get("value", "")
    country = area.get("country", [{}])[0].get("value", "")
    location = f"{city}, {country}" if city else "Unknown"

    desc       = cur["weatherDesc"][0]["value"]
    temp_c     = int(cur["temp_C"])
    feels_c    = int(cur["FeelsLikeC"])
    humidity   = int(cur["humidity"])
    wind_kmph  = int(cur["windspeedKmph"])
    wind_dir   = cur.get("winddir16Point", "N")
    visibility = int(cur.get("visibility", 0))
    uv_index   = int(cur.get("uvIndex", 0))

    return {
        "location":   location,
        "desc":       desc,
        "icon":       condition_icon(desc),
        "temp":       temp_c,
        "feels_like": feels_c,
        "humidity":   humidity,
        "wind_kmph":  wind_kmph,
        "wind_dir":   WIND_DIRS.get(wind_dir, "→"),
        "visibility": visibility,
        "uv":         uv_index,
    }


def parse_forecast(data: dict) -> list[dict]:
    result = []
    for day in data.get("weather", [])[:3]:
        date_str = day["date"]
        try:
            d = datetime.strptime(date_str, "%Y-%m-%d")
            day_name = d.strftime("%a")
        except ValueError:
            day_name = date_str

        desc    = day["hourly"][4]["weatherDesc"][0]["value"]  # noon
        max_c   = int(day["maxtempC"])
        min_c   = int(day["mintempC"])
        rain_mm = float(day.get("hourly", [{}])[4].get("precipMM", 0))

        result.append({
            "day":     day_name,
            "icon":    condition_icon(desc),
            "desc":    desc,
            "max":     max_c,
            "min":     min_c,
            "rain_mm": rain_mm,
        })
    return result


# ── Output formatters ─────────────────────────────────────────

def fmt_waybar(cur: dict, from_cache: bool, stale: bool) -> str:
    """Compact single-line for Waybar"""
    suffix = " (cache)" if stale else ""
    text   = f"{cur['icon']} {cur['temp']}°C"
    tooltip = (
        f"{cur['icon']} {cur['desc']}\n"
        f"  Feels like {cur['feels_like']}°C\n"
        f"  Humidity {cur['humidity']}%\n"
        f"  Wind {cur['wind_kmph']} km/h {cur['wind_dir']}\n"
        f"  {cur['location']}{suffix}"
    )
    return json.dumps({
        "text":    text + suffix,
        "tooltip": tooltip,
        "class":   "",
    })


def fmt_plain(cur: dict, forecast: list, from_cache: bool) -> str:
    lines = [
        f"{cur['icon']}  {cur['desc']} · {cur['temp']}°C (feels {cur['feels_like']}°C)",
        f"   {cur['location']}",
        f"   Humidity {cur['humidity']}%  Wind {cur['wind_kmph']} km/h {cur['wind_dir']}",
        "",
        "   3-day forecast:",
    ]
    for f in forecast:
        lines.append(f"   {f['day']}  {f['icon']}  {f['min']}–{f['max']}°C  {f['desc']}")
    if from_cache:
        lines.append("\n   (cached data)")
    return "\n".join(lines)


def fmt_widget(cur: dict, forecast: list, from_cache: bool, stale: bool):
    """Send as desktop notification (widget-style)"""
    age_str = ""
    if stale:
        age = cache_age()
        mins = int(age // 60)
        age_str = f"\nOffline — cached {mins}m ago"

    body = (
        f"<b>{cur['desc']}</b>\n"
        f"{cur['temp']}°C · feels {cur['feels_like']}°C\n"
        f"Humidity {cur['humidity']}%  Wind {cur['wind_kmph']} km/h {cur['wind_dir']}\n"
        f"UV index {cur['uv']}\n\n"
        f"<b>Forecast:</b>\n"
    )
    for f in forecast:
        body += f"{f['day']}  {f['icon']}  {f['min']}–{f['max']}°C\n"
    body += age_str

    try:
        subprocess.run([
            "notify-send",
            "--app-name=Weather",
            f"--icon=weather-few-clouds",
            "--urgency=low",
            "--expire-time=10000",
            f"{cur['icon']} {cur['location']}",
            body,
        ], check=False)
    except FileNotFoundError:
        print(fmt_plain(cur, forecast, from_cache))


# ── Main ─────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description="CielDots weather — wttr.in")
    p.add_argument("--widget",  action="store_true", help="Show desktop notification widget")
    p.add_argument("--plain",   action="store_true", help="Plain text output")
    p.add_argument("--fetch",   action="store_true", help="Force refresh cache")
    p.add_argument("--json",    action="store_true", help="Raw wttr.in JSON dump")
    return p.parse_args()


def main():
    args = parse_args()

    data, from_cache = get_weather(force_refresh=args.fetch)

    if data is None:
        # No data at all
        if args.widget:
            subprocess.run([
                "notify-send", "--app-name=Weather", "Weather",
                "Cannot fetch weather data — no connection and no cache",
            ], check=False)
        else:
            err = {"text": "󰖑 N/A", "tooltip": "No weather data", "class": ""}
            print(json.dumps(err))
        sys.exit(1)

    if args.json:
        print(json.dumps(data, indent=2))
        return

    cur      = parse_current(data)
    forecast = parse_forecast(data)
    stale    = from_cache and cache_age() > CACHE_TTL

    if args.plain:
        print(fmt_plain(cur, forecast, from_cache))
    elif args.widget:
        fmt_widget(cur, forecast, from_cache, stale)
    else:
        # Default: Waybar module
        print(fmt_waybar(cur, stale, stale))


if __name__ == "__main__":
    main()
