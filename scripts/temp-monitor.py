#!/usr/bin/env python3
# /* ---- 💫 CielDots — Temperature Monitor 💫 ---- */
# Reads CPU & GPU temps for Waybar custom modules
# Usage:
#   temp-monitor.py            → plain text output (Waybar format)
#   temp-monitor.py --cpu      → CPU temp only
#   temp-monitor.py --gpu      → GPU temp only
#   temp-monitor.py --all      → all sensors, pretty print
#   temp-monitor.py --json     → JSON output
#   temp-monitor.py --watch 2  → refresh every N seconds
#   temp-monitor.py --waybar   → compact Waybar module output

import json
import os
import sys
import glob
import time
import argparse
import subprocess
from pathlib import Path


# ── Rimuru temp color thresholds ─────────────────────────────
# Used when --waybar flag is set (CSS class names)
def temp_class(temp: int) -> str:
    if temp >= 80:
        return "critical"   # red  #ff5252
    if temp >= 60:
        return "warn"       # amber #ffb300
    return ""               # green #00e676


def temp_icon(temp: int) -> str:
    if temp >= 80:
        return "󰸁"   # fire
    if temp >= 60:
        return "󰔏"   # warm
    return "󰔐"        # cool


# ── CPU temperature ──────────────────────────────────────────

def read_cpu_sysfs() -> int | None:
    """Read highest temp from /sys/class/thermal/thermal_zone*/temp"""
    zones = glob.glob("/sys/class/thermal/thermal_zone*/temp")
    temps = []
    for zone in zones:
        try:
            with open(zone) as f:
                val = int(f.read().strip())
                temps.append(val // 1000)  # millidegrees → degrees
        except (OSError, ValueError):
            continue
    return max(temps) if temps else None


def read_cpu_lmsensors() -> int | None:
    """Parse lm_sensors JSON output for CPU package temp"""
    try:
        result = subprocess.run(
            ["sensors", "-j"],
            capture_output=True, text=True, timeout=3
        )
        if result.returncode != 0:
            return None
        data = json.loads(result.stdout)
        candidates = []
        for chip, sensors in data.items():
            for sensor_name, readings in sensors.items():
                # Look for Package, Tdie, CPU keys
                name_lower = sensor_name.lower()
                if any(k in name_lower for k in ("package", "tdie", "cpu temp", "tctl")):
                    for key, val in readings.items():
                        if "input" in key and isinstance(val, (int, float)):
                            candidates.append(int(val))
        return max(candidates) if candidates else None
    except (FileNotFoundError, json.JSONDecodeError, subprocess.TimeoutExpired):
        return None


def get_cpu_temp() -> int | None:
    # Try lm_sensors first (more accurate)
    temp = read_cpu_lmsensors()
    if temp is not None:
        return temp
    # Fallback to sysfs
    return read_cpu_sysfs()


# ── GPU temperature ──────────────────────────────────────────

def get_gpu_temp_nvidia() -> int | None:
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader"],
            capture_output=True, text=True, timeout=3
        )
        if result.returncode == 0:
            return int(result.stdout.strip())
    except (FileNotFoundError, ValueError, subprocess.TimeoutExpired):
        pass
    return None


def get_gpu_temp_amd() -> int | None:
    """Read AMD GPU temp from hwmon sysfs"""
    patterns = [
        "/sys/class/drm/card*/device/hwmon/hwmon*/temp1_input",
        "/sys/bus/pci/devices/*/hwmon/hwmon*/temp1_input",
    ]
    for pattern in patterns:
        paths = glob.glob(pattern)
        for path in paths:
            try:
                with open(path) as f:
                    val = int(f.read().strip())
                    return val // 1000
            except (OSError, ValueError):
                continue
    return None


def get_gpu_temp() -> int | None:
    temp = get_gpu_temp_nvidia()
    if temp is not None:
        return temp
    return get_gpu_temp_amd()


# ── Output formatters ────────────────────────────────────────

def fmt_json(cpu: int | None, gpu: int | None) -> str:
    return json.dumps({
        "cpu": cpu,
        "gpu": gpu,
        "unit": "celsius"
    })


def fmt_waybar(cpu: int | None, gpu: int | None, target: str = "cpu") -> str:
    """
    Waybar custom module format:
    stdout → text, tooltip → full info, class → CSS class
    """
    temp = cpu if target == "cpu" else gpu

    if temp is None:
        output = {"text": "N/A", "tooltip": "Sensor not found", "class": ""}
    else:
        icon = temp_icon(temp)
        cls  = temp_class(temp)
        parts = [f"CPU {cpu}°C"] if cpu is not None else []
        if gpu is not None:
            parts.append(f"GPU {gpu}°C")
        output = {
            "text":    f"{icon} {temp}°C",
            "tooltip": " · ".join(parts),
            "class":   cls,
        }
    return json.dumps(output)


def fmt_plain(cpu: int | None, gpu: int | None) -> str:
    parts = []
    if cpu is not None:
        parts.append(f"CPU: {cpu}°C {temp_icon(cpu)}")
    if gpu is not None:
        parts.append(f"GPU: {gpu}°C {temp_icon(gpu)}")
    return "  ".join(parts) if parts else "No sensors found"


def fmt_pretty(cpu: int | None, gpu: int | None) -> str:
    lines = ["── Temperature Monitor ──────────────────"]
    if cpu is not None:
        bar_len = min(cpu, 100) // 5
        bar = "█" * bar_len + "░" * (20 - bar_len)
        lines.append(f"  CPU │{bar}│ {cpu}°C")
    else:
        lines.append("  CPU  no sensor found")
    if gpu is not None:
        bar_len = min(gpu, 100) // 5
        bar = "█" * bar_len + "░" * (20 - bar_len)
        lines.append(f"  GPU │{bar}│ {gpu}°C")
    else:
        lines.append("  GPU  not detected")
    lines.append("────────────────────────────────────────")
    return "\n".join(lines)


# ── Main ─────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(
        description="CielDots temperature monitor — Waybar + CLI"
    )
    p.add_argument("--cpu",     action="store_true", help="Show CPU temp only")
    p.add_argument("--gpu",     action="store_true", help="Show GPU temp only")
    p.add_argument("--all",     action="store_true", help="Show all temps, pretty")
    p.add_argument("--json",    action="store_true", help="JSON output")
    p.add_argument("--waybar",  action="store_true", help="Waybar module output (JSON)")
    p.add_argument("--target",  choices=["cpu","gpu"], default="cpu",
                   help="Which temp to show in --waybar text (default: cpu)")
    p.add_argument("--watch",   type=float, metavar="SECS",
                   help="Refresh every N seconds (Ctrl+C to stop)")
    return p.parse_args()


def run_once(args) -> str:
    cpu = get_cpu_temp()
    gpu = get_gpu_temp()

    if args.json:
        return fmt_json(cpu, gpu)
    if args.waybar:
        return fmt_waybar(cpu, gpu, args.target)
    if args.all:
        return fmt_pretty(cpu, gpu)
    if args.cpu:
        return f"{cpu}°C" if cpu is not None else "N/A"
    if args.gpu:
        return f"{gpu}°C" if gpu is not None else "N/A"
    return fmt_plain(cpu, gpu)


def main():
    args = parse_args()

    if args.watch:
        try:
            while True:
                output = run_once(args)
                # Clear line and reprint for --all mode
                if args.all:
                    os.system("clear")
                print(output, flush=True)
                time.sleep(args.watch)
        except KeyboardInterrupt:
            pass
    else:
        print(run_once(args))


if __name__ == "__main__":
    main()
