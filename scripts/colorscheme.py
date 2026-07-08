#!/usr/bin/env python3
# /* ---- 💫 CielDots — Dynamic Color Scheme (Pywal-style) 💫 ---- */
# Extracts dominant colors from wallpaper and applies them system-wide.
# Pure Python — no pywal, no colorthief dependency required.
#
# Usage:
#   colorscheme.py <wallpaper>         → extract + apply
#   colorscheme.py <wallpaper> --dry   → preview only, no reload
#   colorscheme.py --reload            → re-apply last cached colors
#   colorscheme.py --show              → print current palette
#
# What gets updated:
#   ~/.cache/cieldots/colors.json      → master palette
#   ~/.config/kitty/themes/dynamic.conf
#   ~/.config/waybar/dynamic-colors.css
#   ~/.config/mako/config              → border/bg colors
#   ~/.config/wofi/style.css           → launcher colors
#   Hyprland borders (via hyprctl)     → live, no restart needed
#   Waybar (pkill -USR2)               → live reload
#   Mako (makoctl reload)              → live reload
#   Kitty (socket broadcast)           → live reload

import sys
import os
import json
import math
import struct
import random
import shutil
import subprocess
import argparse
from pathlib import Path
from colorsys import rgb_to_hls, hls_to_rgb, rgb_to_hsv, hsv_to_rgb
from typing import Optional, List, Tuple, Dict

# ── Constants ─────────────────────────────────────────────────
CACHE_DIR   = Path.home() / ".cache" / "cieldots"
COLORS_JSON = CACHE_DIR / "colors.json"
CONFIG_DIR  = Path.home() / ".config"

KITTY_DYNAMIC   = CONFIG_DIR / "kitty" / "themes" / "dynamic.conf"
WAYBAR_DYNAMIC  = CONFIG_DIR / "waybar" / "dynamic-colors.css"
MAKO_CONFIG     = CONFIG_DIR / "mako" / "config"
WOFI_CSS        = CONFIG_DIR / "wofi" / "style.css"
HYPRLAND_CONF   = CONFIG_DIR / "hypr" / "hyprland.conf"

# ── Rimuru base (fallback when wallpaper has no color info) ───
RIMURU_BASE = {
    "bg":       (10,  14,  26),    # #0a0e1a abyss
    "bg2":      (13,  20,  32),    # #0d1420 deep
    "surface":  (26,  37,  64),    # #1a2540 overlay
    "text":     (200, 214, 232),   # #c8d6e8 silver
    "subtext":  (122, 145, 176),   # #7a91b0 mist
    "accent":   (0,   229, 255),   # #00e5ff cyan
    "accent2":  (124, 77,  255),   # #7c4dff purple
    "green":    (0,   230, 118),
    "amber":    (255, 179, 0),
    "red":      (255, 82,  82),
}


# ══════════════════════════════════════════════════════════════
# COLOR MATH UTILITIES
# ══════════════════════════════════════════════════════════════

def hex2rgb(h: str) -> Tuple[int,int,int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgb2hex(r: int, g: int, b: int) -> str:
    return "#{:02x}{:02x}{:02x}".format(
        max(0, min(255, r)),
        max(0, min(255, g)),
        max(0, min(255, b)),
    )

def rgb_norm(r,g,b):
    return r/255, g/255, b/255

def rgb_denorm(r,g,b):
    return int(r*255), int(g*255), int(b*255)

def darken(r,g,b, amount=0.3) -> Tuple[int,int,int]:
    rn,gn,bn = rgb_norm(r,g,b)
    h,l,s = rgb_to_hls(rn,gn,bn)
    l = max(0.0, l - amount)
    return rgb_denorm(*hls_to_rgb(h,l,s))

def lighten(r,g,b, amount=0.2) -> Tuple[int,int,int]:
    rn,gn,bn = rgb_norm(r,g,b)
    h,l,s = rgb_to_hls(rn,gn,bn)
    l = min(1.0, l + amount)
    return rgb_denorm(*hls_to_rgb(h,l,s))

def saturate(r,g,b, amount=0.2) -> Tuple[int,int,int]:
    rn,gn,bn = rgb_norm(r,g,b)
    h,l,s = rgb_to_hls(rn,gn,bn)
    s = min(1.0, s + amount)
    return rgb_denorm(*hls_to_rgb(h,l,s))

def desaturate(r,g,b, amount=0.4) -> Tuple[int,int,int]:
    rn,gn,bn = rgb_norm(r,g,b)
    h,l,s = rgb_to_hls(rn,gn,bn)
    s = max(0.0, s - amount)
    return rgb_denorm(*hls_to_rgb(h,l,s))

def complementary(r,g,b) -> Tuple[int,int,int]:
    """Return complementary hue with same saturation/lightness"""
    rn,gn,bn = rgb_norm(r,g,b)
    h,l,s = rgb_to_hls(rn,gn,bn)
    h = (h + 0.5) % 1.0
    return rgb_denorm(*hls_to_rgb(h,l,s))

def analogous(r,g,b, offset=0.08) -> Tuple[int,int,int]:
    rn,gn,bn = rgb_norm(r,g,b)
    h,l,s = rgb_to_hls(rn,gn,bn)
    h = (h + offset) % 1.0
    return rgb_denorm(*hls_to_rgb(h,l,s))

def luminance(r,g,b) -> float:
    return 0.2126*(r/255) + 0.7152*(g/255) + 0.0722*(b/255)

def color_distance(c1, c2) -> float:
    return math.sqrt(sum((a-b)**2 for a,b in zip(c1,c2)))


# ══════════════════════════════════════════════════════════════
# IMAGE COLOR EXTRACTION — Pure Python (no PIL fallback to PPM)
# ══════════════════════════════════════════════════════════════

def read_image_pixels(path: str) -> List[Tuple[int,int,int]]:
    """
    Read pixels from image. Uses Pillow if available,
    falls back to ImageMagick convert → PPM parsing.
    """
    # Try Pillow first (fastest)
    try:
        from PIL import Image
        img = Image.open(path).convert("RGB")
        # Downsample to max 150x150 for speed
        img.thumbnail((150, 150))
        return list(img.getdata())
    except ImportError:
        pass

    # Fallback: ImageMagick → PPM → parse
    try:
        ppm_path = str(CACHE_DIR / "wallpaper_sample.ppm")
        subprocess.run([
            "magick", path,
            "-resize", "150x150!",
            "-depth", "8",
            ppm_path,
        ], check=True, capture_output=True, timeout=10)
        return _parse_ppm(ppm_path)
    except (FileNotFoundError, subprocess.CalledProcessError):
        pass

    # Fallback: ffmpeg → PPM
    try:
        ppm_path = str(CACHE_DIR / "wallpaper_sample.ppm")
        subprocess.run([
            "ffmpeg", "-y", "-i", path,
            "-vf", "scale=150:150",
            "-frames:v", "1",
            ppm_path,
        ], check=True, capture_output=True, timeout=10)
        return _parse_ppm(ppm_path)
    except (FileNotFoundError, subprocess.CalledProcessError):
        pass

    return []


def _parse_ppm(path: str) -> List[Tuple[int,int,int]]:
    """Parse a binary PPM (P6) file into RGB tuples"""
    with open(path, "rb") as f:
        magic = f.readline().strip()
        if magic != b"P6":
            return []
        # Skip comments
        line = f.readline()
        while line.startswith(b"#"):
            line = f.readline()
        w, h  = map(int, line.split())
        maxval = int(f.readline().strip())
        raw   = f.read()

    pixels = []
    if maxval == 255:
        for i in range(0, len(raw)-2, 3):
            pixels.append((raw[i], raw[i+1], raw[i+2]))
    return pixels


# ══════════════════════════════════════════════════════════════
# K-MEANS COLOR CLUSTERING
# ══════════════════════════════════════════════════════════════

def kmeans_colors(pixels: list, k: int = 8, iterations: int = 12) -> List[Tuple[int,int,int]]:
    """
    Simple K-Means clustering to find K dominant colors.
    Returns list of (r,g,b) sorted by cluster size (most dominant first).
    """
    if not pixels:
        return []

    # Subsample for speed (max 3000 pixels)
    if len(pixels) > 3000:
        step = len(pixels) // 3000
        pixels = pixels[::step]

    # Filter out near-black and near-white (not interesting)
    filtered = [
        p for p in pixels
        if 20 < luminance(*p)*255 < 235
        and max(p) - min(p) > 15  # skip near-gray
    ]
    if len(filtered) < k:
        filtered = pixels  # fallback if too aggressive

    # Init centroids via K-Means++ style
    centroids = [random.choice(filtered)]
    for _ in range(k - 1):
        dists = [min(color_distance(p, c)**2 for c in centroids) for p in filtered]
        total = sum(dists)
        if total == 0:
            centroids.append(random.choice(filtered))
            continue
        r = random.uniform(0, total)
        cumul = 0.0
        for p, d in zip(filtered, dists):
            cumul += d
            if cumul >= r:
                centroids.append(p)
                break

    # Iterate
    assignments = [0] * len(filtered)
    for _ in range(iterations):
        # Assign each pixel to nearest centroid
        changed = False
        for i, p in enumerate(filtered):
            nearest = min(range(k), key=lambda j: color_distance(p, centroids[j]))
            if nearest != assignments[i]:
                assignments[i] = nearest
                changed = True

        if not changed:
            break

        # Recompute centroids
        sums   = [(0,0,0)] * k
        counts = [0] * k
        for p, a in zip(filtered, assignments):
            sums[a]   = tuple(sums[a][i] + p[i] for i in range(3))
            counts[a] += 1

        new_centroids = []
        for j in range(k):
            if counts[j] > 0:
                new_centroids.append(tuple(int(sums[j][i]/counts[j]) for i in range(3)))
            else:
                new_centroids.append(centroids[j])
        centroids = new_centroids

    # Sort by cluster count (dominant first)
    counts = [0] * k
    for a in assignments:
        counts[a] += 1
    sorted_pairs = sorted(zip(counts, centroids), reverse=True)
    return [c for _, c in sorted_pairs]


# ══════════════════════════════════════════════════════════════
# PALETTE GENERATION
# ══════════════════════════════════════════════════════════════

def build_palette(dominant: List[Tuple[int,int,int]]) -> Dict:
    """
    Given K dominant colors from the wallpaper, build a full
    UI palette: background, text, accent, secondary, status colors.
    """
    if not dominant:
        # Full fallback to Rimuru
        return {k: rgb2hex(*v) for k, v in RIMURU_BASE.items()}

    # Pick accent = most saturated color among top 4
    def saturation(rgb):
        rn,gn,bn = rgb_norm(*rgb)
        _,_,s = rgb_to_hls(rn,gn,bn)
        return s

    top = dominant[:min(6, len(dominant))]
    accent_rgb = max(top, key=saturation)

    # Ensure accent is vivid enough
    accent_rgb = saturate(*accent_rgb, 0.3)
    # Make sure it's not too dark or too light
    rn,gn,bn = rgb_norm(*accent_rgb)
    h,l,s = rgb_to_hls(rn,gn,bn)
    l = max(0.45, min(0.75, l))  # keep it in readable range
    accent_rgb = rgb_denorm(*hls_to_rgb(h,l,s))

    # Secondary accent = analogous hue (+25° on color wheel)
    accent2_rgb = analogous(*accent_rgb, offset=0.07)
    accent2_rgb = saturate(*accent2_rgb, 0.2)

    # Background = darkened, desaturated dominant color
    bg_rgb      = darken(*desaturate(*dominant[0], 0.6), 0.55)
    # Clamp to max luminance 0.06 (very dark)
    while luminance(*bg_rgb) > 0.06:
        bg_rgb = darken(*bg_rgb, 0.05)

    bg2_rgb     = lighten(*bg_rgb, 0.03)
    surface_rgb = lighten(*bg_rgb, 0.10)
    overlay_rgb = lighten(*bg_rgb, 0.18)

    # Text = very light, slightly tinted with accent hue
    rn,gn,bn = rgb_norm(*accent_rgb)
    h,_,_ = rgb_to_hls(rn,gn,bn)
    text_rgb    = rgb_denorm(*hls_to_rgb(h, 0.88, 0.15))
    subtext_rgb = rgb_denorm(*hls_to_rgb(h, 0.65, 0.18))
    ghost_rgb   = rgb_denorm(*hls_to_rgb(h, 0.38, 0.15))

    # Status colors — keep semantic meaning but tinted toward accent hue
    def tint_toward(base_rgb, accent_hue, amount=0.15):
        rn,gn,bn = rgb_norm(*base_rgb)
        bh,bl,bs = rgb_to_hls(rn,gn,bn)
        # Blend hue toward accent
        bh = bh + (accent_hue - bh) * amount
        return rgb_denorm(*hls_to_rgb(bh, bl, bs))

    green_base  = (0,   210, 100)
    amber_base  = (255, 170,  0)
    red_base    = (255,  70, 70)
    blue_base   = (41,  182, 246)

    return {
        "bg":       rgb2hex(*bg_rgb),
        "bg2":      rgb2hex(*bg2_rgb),
        "surface":  rgb2hex(*surface_rgb),
        "overlay":  rgb2hex(*overlay_rgb),
        "text":     rgb2hex(*text_rgb),
        "subtext":  rgb2hex(*subtext_rgb),
        "ghost":    rgb2hex(*ghost_rgb),
        "accent":   rgb2hex(*accent_rgb),
        "accent2":  rgb2hex(*accent2_rgb),
        "green":    rgb2hex(*tint_toward(green_base, h, 0.1)),
        "amber":    rgb2hex(*tint_toward(amber_base, h, 0.1)),
        "red":      rgb2hex(*tint_toward(red_base,   h, 0.05)),
        "blue":     rgb2hex(*tint_toward(blue_base,  h, 0.2)),
        # Raw accent with alpha variants for CSS/Hyprland
        "accent_aa":  rgb2hex(*accent_rgb) + "aa",
        "accent_55":  rgb2hex(*accent_rgb) + "55",
        "accent_22":  rgb2hex(*accent_rgb) + "22",
        "bg_cc":      rgb2hex(*bg_rgb) + "cc",
        "bg_ee":      rgb2hex(*bg_rgb) + "ee",
        "surface_44": rgb2hex(*surface_rgb) + "44",
    }


# ══════════════════════════════════════════════════════════════
# CONFIG WRITERS
# ══════════════════════════════════════════════════════════════

def write_kitty_theme(p: dict):
    KITTY_DYNAMIC.parent.mkdir(parents=True, exist_ok=True)
    content = f"""# /* ---- 💫 CielDots Dynamic Theme — auto-generated 💫 ---- */
# Generated by colorscheme.py — DO NOT EDIT MANUALLY
# Source: {p.get('_wallpaper', 'unknown')}

foreground   {p['text']}
background   {p['bg']}
cursor       {p['accent']}
cursor_text_color {p['bg']}

selection_foreground {p['bg']}
selection_background {p['accent']}
url_color    {p['blue']}

active_border_color   {p['accent']}
inactive_border_color {p['surface']}
bell_border_color     {p['amber']}

active_tab_foreground   {p['bg']}
active_tab_background   {p['accent']}
inactive_tab_foreground {p['ghost']}
inactive_tab_background {p['bg2']}
tab_bar_background      {p['bg']}

color0  {p['surface']}
color8  {p['overlay']}
color1  {p['red']}
color9  {p['red']}
color2  {p['green']}
color10 {p['green']}
color3  {p['amber']}
color11 {p['amber']}
color4  {p['blue']}
color12 {p['blue']}
color5  {p['accent2']}
color13 {p['accent2']}
color6  {p['accent']}
color14 {p['accent']}
color7  {p['subtext']}
color15 {p['text']}
"""
    KITTY_DYNAMIC.write_text(content)


def write_waybar_colors(p: dict):
    WAYBAR_DYNAMIC.parent.mkdir(parents=True, exist_ok=True)
    # Strip leading # for rgba() usage
    def ra(hex_color, alpha="ff"):
        h = hex_color.lstrip("#")[:6]
        r,g,b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
        a = int(alpha,16)/255
        return f"rgba({r},{g},{b},{a:.2f})"

    content = f"""/* CielDots Dynamic Colors — auto-generated by colorscheme.py */
/* DO NOT EDIT — regenerated on every wallpaper change         */

@define-color dyn-bg      {p['bg']};
@define-color dyn-bg2     {p['bg2']};
@define-color dyn-surface {p['surface']};
@define-color dyn-overlay {p['overlay']};
@define-color dyn-text    {p['text']};
@define-color dyn-sub     {p['subtext']};
@define-color dyn-ghost   {p['ghost']};
@define-color dyn-accent  {p['accent']};
@define-color dyn-accent2 {p['accent2']};
@define-color dyn-green   {p['green']};
@define-color dyn-amber   {p['amber']};
@define-color dyn-red     {p['red']};
@define-color dyn-blue    {p['blue']};

/* Override waybar module backgrounds with dynamic colors */
.modules-left,
.modules-center,
.modules-right {{
    background: {ra(p['bg'], 'bb')};
    border: 1px solid {ra(p['accent'], '22')};
    box-shadow: 0 4px 24px rgba(0,0,0,0.5),
                inset 0 1px 0 {ra(p['accent'], '0a')};
}}

#workspaces button.active {{
    background: {ra(p['accent'], '2e')};
    color: {p['accent']};
    box-shadow: 0 0 12px {ra(p['accent'], '55')};
}}

#clock {{
    color: {p['accent']};
    text-shadow: 0 0 10px {ra(p['accent'], '99')};
}}

#custom-power:hover {{
    background: {p['accent2']};
    box-shadow: 0 0 14px {ra(p['accent2'], '99')};
}}
"""
    WAYBAR_DYNAMIC.write_text(content)


def write_mako_colors(p: dict):
    MAKO_CONFIG.parent.mkdir(parents=True, exist_ok=True)
    # Read existing config and replace color lines only
    bg_hex   = p['bg'].lstrip('#')
    acc_hex  = p['accent'].lstrip('#')
    red_hex  = p['red'].lstrip('#')
    sub_hex  = p['surface'].lstrip('#')
    txt_hex  = p['text'].lstrip('#')

    if MAKO_CONFIG.exists():
        lines = MAKO_CONFIG.read_text().splitlines()
        new_lines = []
        for line in lines:
            if line.startswith("background-color=") and "[urgency" not in "\n".join(new_lines[-3:]):
                new_lines.append(f"background-color=#{bg_hex}cc")
            elif line.startswith("text-color=") and "[urgency" not in "\n".join(new_lines[-3:]):
                new_lines.append(f"text-color=#{txt_hex}ff")
            elif line.startswith("border-color=") and "[urgency" not in "\n".join(new_lines[-3:]):
                new_lines.append(f"border-color=#{acc_hex}55")
            else:
                new_lines.append(line)
        MAKO_CONFIG.write_text("\n".join(new_lines) + "\n")


def write_wofi_colors(p: dict):
    WOFI_CSS.parent.mkdir(parents=True, exist_ok=True)
    bg  = p['bg']
    bg2 = p['bg2']
    sur = p['surface']
    acc = p['accent']
    txt = p['text']
    sub = p['subtext']
    gho = p['ghost']

    def rgba_str(hex_c, alpha):
        h = hex_c.lstrip('#')
        r,g,b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
        return f"rgba({r},{g},{b},{alpha})"

    content = f"""/* CielDots Dynamic Wofi — auto-generated */
* {{ font-family: "JetBrainsMono Nerd Font"; font-size: 13px; }}

window {{
    background-color: {rgba_str(bg, 0.88)};
    border: 1px solid {rgba_str(acc, 0.30)};
    border-radius: 16px;
    box-shadow: 0 8px 40px rgba(0,0,0,0.7),
                0 0 30px {rgba_str(acc, 0.08)};
}}
#input {{
    background-color: {rgba_str(sur, 0.80)};
    color: {txt};
    border: 1px solid {rgba_str(acc, 0.20)};
    border-radius: 10px;
    padding: 9px 14px;
    margin: 12px;
    caret-color: {acc};
    outline: none;
}}
#input:focus {{
    border-color: {rgba_str(acc, 0.55)};
    box-shadow: 0 0 0 2px {rgba_str(acc, 0.12)},
                0 0 12px {rgba_str(acc, 0.20)};
}}
#inner-box {{ background-color: transparent; margin: 0 8px 8px 8px; }}
#outer-box, #scroll {{ margin: 0; padding: 0; }}
#text {{ color: {txt}; padding: 2px 0; }}
#entry {{ padding: 8px 14px; border-radius: 10px; margin: 2px 4px; }}
#entry:hover {{ background-color: {rgba_str(acc, 0.07)}; }}
#entry:selected {{
    background-color: {rgba_str(acc, 0.14)};
    box-shadow: inset 0 0 0 1px {rgba_str(acc, 0.25)};
}}
#entry:selected #text {{ color: {acc}; font-weight: bold; }}
#img {{ margin-right: 10px; border-radius: 6px; }}
"""
    WOFI_CSS.write_text(content)


# ══════════════════════════════════════════════════════════════
# RELOAD LIVE COMPONENTS
# ══════════════════════════════════════════════════════════════

def reload_hyprland_borders(p: dict):
    """Update Hyprland border colors live via hyprctl"""
    acc  = p['accent'].lstrip('#')
    acc2 = p['accent2'].lstrip('#')
    sur  = p['surface'].lstrip('#')

    cmds = [
        f"general:col.active_border rgba({acc}cc) rgba({acc2}cc) 45deg",
        f"general:col.inactive_border rgba({sur}88)",
        f"decoration:shadow:color rgba({acc}22)",
    ]
    for kw in cmds:
        try:
            subprocess.run(["hyprctl", "keyword"] + kw.split(" ", 1),
                           capture_output=True, timeout=3)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            break


def reload_waybar():
    try:
        subprocess.run(["pkill", "-USR2", "waybar"],
                       capture_output=True, timeout=3)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass


def reload_mako():
    try:
        subprocess.run(["makoctl", "reload"],
                       capture_output=True, timeout=3)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass


def reload_kitty(theme_path: str):
    """
    Broadcast new theme to all running kitty instances via kitty's
    remote-control socket. Falls back to writing the include file.
    """
    # Update kitty.conf include to point to dynamic theme
    kitty_conf = CONFIG_DIR / "kitty" / "kitty.conf"
    if kitty_conf.exists():
        text = kitty_conf.read_text()
        # Replace include line for themes
        import re
        new_text = re.sub(
            r'^include\s+./themes/\S+\.conf',
            'include ./themes/dynamic.conf',
            text, flags=re.MULTILINE
        )
        if new_text != text:
            kitty_conf.write_text(new_text)

    # Tell kitty to reload (if remote control enabled)
    try:
        subprocess.run(
            ["kitty", "@", "set-colors", "--all", "--configured", theme_path],
            capture_output=True, timeout=5
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass


def send_notification(p: dict, wallpaper: str):
    acc  = p['accent']
    msg  = (f"Accent: {acc}\n"
            f"BG: {p['bg']}\n"
            f"From: {Path(wallpaper).name}")
    try:
        subprocess.run([
            "notify-send",
            "--app-name=ColorScheme",
            "--icon=preferences-desktop-wallpaper",
            "--urgency=low",
            "--expire-time=4000",
            "🎨 Color scheme updated",
            msg,
        ], capture_output=True, timeout=3)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass


# ══════════════════════════════════════════════════════════════
# PREVIEW / PRINT
# ══════════════════════════════════════════════════════════════

def ansi_block(hex_color: str, label: str) -> str:
    h = hex_color.lstrip('#')
    r,g,b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
    bg = f"\033[48;2;{r};{g};{b}m"
    # Contrast text
    lum = luminance(r,g,b)
    fg = "\033[38;2;10;14;26m" if lum > 0.4 else "\033[38;2;200;214;232m"
    reset = "\033[0m"
    return f"{bg}{fg}  {label:<12}{reset}"


def print_palette(p: dict, title: str = ""):
    print(f"\n  💫 CielDots Color Palette  {title}")
    print(f"  {'─'*44}")
    keys = ["bg","bg2","surface","overlay","text","subtext","ghost",
            "accent","accent2","green","amber","red","blue"]
    row = ""
    for i, k in enumerate(keys):
        val = p.get(k, "#888888")
        if len(val) > 7: val = val[:7]
        row += ansi_block(val, f"{k} {val}")
        if (i+1) % 3 == 0:
            print(f"  {row}")
            row = ""
    if row:
        print(f"  {row}")
    print()


# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════

def run_extract(wallpaper: str, dry: bool = False) -> Dict:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    print(f"\n  🎨 Extracting colors from: {Path(wallpaper).name}")

    pixels = read_image_pixels(wallpaper)
    if not pixels:
        print("  ⚠  Could not read image pixels — using Rimuru fallback palette")
        dominant = []
    else:
        print(f"  ✓  Sampled {len(pixels)} pixels")
        dominant = kmeans_colors(pixels, k=8, iterations=15)
        print(f"  ✓  Found {len(dominant)} dominant colors")

    palette = build_palette(dominant)
    palette["_wallpaper"] = str(wallpaper)
    palette["_timestamp"] = __import__("time").strftime("%Y-%m-%d %H:%M:%S")

    print_palette(palette, f"← {Path(wallpaper).name}")

    if dry:
        print("  [dry run] no files written\n")
        return palette

    # Write all configs
    print("  Writing configs...")
    write_kitty_theme(palette)
    write_waybar_colors(palette)
    write_mako_colors(palette)
    write_wofi_colors(palette)

    # Save master cache
    COLORS_JSON.write_text(json.dumps(palette, indent=2))
    print("  ✓  Configs written")

    # Reload live
    print("  Reloading components...")
    reload_hyprland_borders(palette)
    reload_waybar()
    reload_mako()
    reload_kitty(str(KITTY_DYNAMIC))
    send_notification(palette, wallpaper)
    print("  ✓  Done!\n")

    return palette


def parse_args():
    p = argparse.ArgumentParser(
        description="CielDots dynamic color scheme — extract wallpaper colors"
    )
    p.add_argument("wallpaper", nargs="?", help="Path to wallpaper image")
    p.add_argument("--dry",    action="store_true", help="Preview only, no file writes")
    p.add_argument("--reload", action="store_true", help="Re-apply last cached palette")
    p.add_argument("--show",   action="store_true", help="Show current cached palette")
    return p.parse_args()


def main():
    args = parse_args()

    if args.show:
        if not COLORS_JSON.exists():
            print("  No cached palette found. Run colorscheme.py <wallpaper> first.")
            sys.exit(1)
        p = json.loads(COLORS_JSON.read_text())
        print_palette(p, f"  (from {p.get('_timestamp','?')})")
        return

    if args.reload:
        if not COLORS_JSON.exists():
            print("  No cached palette found.")
            sys.exit(1)
        p = json.loads(COLORS_JSON.read_text())
        print(f"  ♻  Reloading cached palette from {p.get('_timestamp','?')}")
        write_kitty_theme(p)
        write_waybar_colors(p)
        write_mako_colors(p)
        write_wofi_colors(p)
        reload_hyprland_borders(p)
        reload_waybar()
        reload_mako()
        reload_kitty(str(KITTY_DYNAMIC))
        print("  ✓  Reloaded!\n")
        return

    if not args.wallpaper:
        print("  Usage: colorscheme.py <wallpaper> [--dry]")
        print("         colorscheme.py --reload")
        print("         colorscheme.py --show")
        sys.exit(1)

    run_extract(args.wallpaper, dry=args.dry)


if __name__ == "__main__":
    main()
