#!/usr/bin/env python3
# /* ---- 💫 CielDots — Startup Splash Animator 💫 ---- */
# Shows Rimuru-themed ASCII animation on Hyprland login
# Respects CIELDOTS_NO_SPLASH=1 for headless/CI environments

import os
import sys
import time
from datetime import datetime


# ── Skip flag ────────────────────────────────────────────────
if os.environ.get("CIELDOTS_NO_SPLASH") == "1":
    sys.exit(0)


# ── ANSI helpers ─────────────────────────────────────────────
# Rimuru Tempest palette via 24-bit ANSI
def rgb(r, g, b, text):        return f"\033[38;2;{r};{g};{b}m{text}\033[0m"
def rgb_bg(r, g, b, text):     return f"\033[48;2;{r};{g};{b}m{text}\033[0m"
def bold(text):                return f"\033[1m{text}\033[0m"
def italic(text):              return f"\033[3m{text}\033[0m"
def dim(text):                 return f"\033[2m{text}\033[0m"
def clear():                   print("\033[2J\033[H", end="", flush=True)
def hide_cursor():             print("\033[?25l", end="", flush=True)
def show_cursor():             print("\033[?25h", end="", flush=True)
def move(row, col):            print(f"\033[{row};{col}H", end="", flush=True)

# Colors
CYAN   = lambda t: rgb(0,   229, 255, t)
BLUE   = lambda t: rgb(41,  182, 246, t)
PURPLE = lambda t: rgb(124, 77,  255, t)
SILVER = lambda t: rgb(200, 214, 232, t)
MIST   = lambda t: rgb(122, 145, 176, t)
GHOST  = lambda t: rgb(74,  96,  122, t)
GREEN  = lambda t: rgb(0,   230, 118, t)
AMBER  = lambda t: rgb(255, 179,  0,  t)


# ── Logo frames ──────────────────────────────────────────────
LOGO = [
    "                                          ",
    "     ██████╗██╗███████╗██╗               ",
    "    ██╔════╝██║██╔════╝██║               ",
    "    ██║     ██║█████╗  ██║               ",
    "    ██║     ██║██╔══╝  ██║               ",
    "    ╚██████╗██║███████╗███████╗          ",
    "     ╚═════╝╚═╝╚══════╝╚══════╝          ",
    "                                          ",
    "    ██████╗  ██████╗ ████████╗███████╗   ",
    "    ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝   ",
    "    ██║  ██║██║   ██║   ██║   ███████╗   ",
    "    ██║  ██║██║   ██║   ██║   ╚════██║   ",
    "    ██████╔╝╚██████╔╝   ██║   ███████║   ",
    "    ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝   ",
    "                                          ",
]

TAGLINE   = "  Gentoo Linux · Hyprland · Rimuru Tempest"
QUOTE     = "  「 That Which is Slime, Sees All 」"
SEPARATOR = "  ────────────────────────────────────────"


def color_logo_line(line: str, frame: int) -> str:
    """Animate logo color: cyan → blue → purple wave"""
    colors = [
        (0, 229, 255),    # cyan
        (41, 182, 246),   # blue
        (124, 77, 255),   # purple
        (170, 128, 255),  # violet
        (41, 182, 246),   # blue
    ]
    idx = frame % len(colors)
    r, g, b = colors[idx]
    return rgb(r, g, b, bold(line))


def print_logo(frame: int):
    for line in LOGO:
        print(color_logo_line(line, frame))


def type_write(text: str, color_fn, delay: float = 0.018):
    """Print text character by character"""
    for ch in text:
        print(color_fn(ch), end="", flush=True)
        time.sleep(delay)
    print()


def loading_bar(label: str, steps: int = 30, delay: float = 0.04):
    """Animated loading bar"""
    bar_color_full = CYAN
    bar_color_empty = GHOST

    for i in range(steps + 1):
        filled = i
        empty  = steps - i
        pct    = int(i * 100 / steps)
        bar    = bar_color_full("█" * filled) + bar_color_empty("░" * empty)
        status = f"\r  {MIST(label)}  [{bar}]  {CYAN(f'{pct:3d}%')}"
        print(status, end="", flush=True)
        time.sleep(delay)
    print()


def glitch_text(text: str, color_fn, cycles: int = 4):
    """Flicker effect before settling"""
    glitch_chars = "░▒▓█╬╪╫╩╦╠═╔╗╚╝│─┤├┬┴┼"
    import random
    for _ in range(cycles):
        glitched = "".join(
            random.choice(glitch_chars) if random.random() < 0.3 else c
            for c in text
        )
        print(f"\r{GHOST(glitched)}", end="", flush=True)
        time.sleep(0.06)
    print(f"\r{color_fn(text)}")


def particles_line(width: int = 44):
    """Random particle burst line"""
    import random
    chars = "·∘◦○◎●◉◈◇◆◊"
    line = ""
    for _ in range(width):
        if random.random() < 0.3:
            r = random.randint(0, 3)
            if r == 0:   line += CYAN(random.choice(chars))
            elif r == 1: line += BLUE(random.choice(chars))
            elif r == 2: line += PURPLE(random.choice(chars))
            else:        line += GHOST(" ")
        else:
            line += " "
    print(f"  {line}")


# ── Main animation sequence ──────────────────────────────────

def run_splash():
    hide_cursor()
    try:
        clear()

        # Phase 1: particle burst
        print()
        for _ in range(4):
            particles_line()
            time.sleep(0.08)

        # Phase 2: logo reveal with wave colors
        clear()
        print()
        for frame in range(5):
            clear()
            print()
            print_logo(frame)
            time.sleep(0.12)

        # Phase 3: settle on final logo
        clear()
        print()
        print_logo(0)
        print()

        # Phase 4: type-write tagline
        type_write(TAGLINE, SILVER, delay=0.02)
        time.sleep(0.1)

        # Phase 5: glitch quote into existence
        print()
        glitch_text(QUOTE, lambda t: italic(MIST(t)), cycles=5)
        print(GHOST(SEPARATOR))
        print()

        # Phase 6: loading bar
        loading_bar("Initializing", steps=25, delay=0.035)
        print()

        # Phase 7: timestamp
        now = datetime.now().strftime("%A, %d %B %Y  %H:%M")
        type_write(f"  {now}", MIST, delay=0.015)
        print()

        # Phase 8: final glow flash
        for _ in range(3):
            print(f"\r  {CYAN(bold('[ READY ]'))}", end="", flush=True)
            time.sleep(0.2)
            print(f"\r  {GHOST('[ READY ]')}", end="", flush=True)
            time.sleep(0.15)
        print(f"\r  {GREEN(bold('[ READY ]'))}")
        print()

        time.sleep(0.6)

    finally:
        show_cursor()


if __name__ == "__main__":
    run_splash()
