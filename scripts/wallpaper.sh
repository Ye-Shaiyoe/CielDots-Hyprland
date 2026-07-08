#!/bin/bash
# ============================================================
# wallpaper.sh — Smart wallpaper switcher with swww
# Usage:
#   wallpaper.sh              → random dari ~/Pictures/Wallpapers
#   wallpaper.sh <file>       → set wallpaper spesifik
#   wallpaper.sh --next       → next wallpaper (sorted)
#   wallpaper.sh --prev       → previous wallpaper
#   wallpaper.sh --slideshow  → slideshow mode (interval dari config)
# ============================================================

WALLPAPER_DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
CACHE_FILE="$HOME/.cache/current_wallpaper"
INDEX_FILE="$HOME/.cache/wallpaper_index"
INTERVAL="${WALLPAPER_INTERVAL:-300}"  # default 5 menit

# Transisi swww yang tersedia:
# fade, wipe, slide, grow, center, any, outer, random
TRANSITION="${WALLPAPER_TRANSITION:-wipe}"
TRANSITION_DURATION="${WALLPAPER_TRANSITION_DURATION:-1.5}"
TRANSITION_FPS="${WALLPAPER_FPS:-60}"

# ---- Helpers ----

log() { notify-send -a "Wallpaper" -i "$1" "${@:2}" 2>/dev/null || echo "[wallpaper] ${*:2}"; }

check_deps() {
    for dep in swww swww-daemon; do
        command -v "$dep" &>/dev/null || { echo "Error: $dep not found"; exit 1; }
    done
}

ensure_daemon() {
    pgrep -x swww-daemon &>/dev/null || {
        swww-daemon &
        sleep 0.5
    }
}

get_wallpapers() {
    find "$WALLPAPER_DIR" -type f \( \
        -iname "*.jpg" -o -iname "*.jpeg" -o \
        -iname "*.png" -o -iname "*.gif"  -o \
        -iname "*.webp" \
    \) | sort
}

set_wallpaper() {
    local img="$1"
    [[ -f "$img" ]] || { echo "Error: file not found: $img"; exit 1; }

    ensure_daemon

    swww img "$img" \
        --transition-type "$TRANSITION" \
        --transition-duration "$TRANSITION_DURATION" \
        --transition-fps "$TRANSITION_FPS"

    echo "$img" > "$CACHE_FILE"
    log "$img" "Wallpaper changed" "$(basename "$img")"

    # ── Dynamic color scheme — extract wallpaper colors ──────
    # Set WALLPAPER_NO_COLORS=1 to disable
    if [[ "${WALLPAPER_NO_COLORS:-0}" != "1" ]]; then
        local cs_script="$HOME/.config/hypr/scripts/colorscheme.py"
        if command -v python3 &>/dev/null && [[ -f "$cs_script" ]]; then
            # Run async — don't block wallpaper change
            python3 "$cs_script" "$img" &>/dev/null &
            disown
        fi
    fi
}

set_random() {
    local walls
    mapfile -t walls < <(get_wallpapers)

    [[ ${#walls[@]} -eq 0 ]] && {
        echo "No wallpapers found in $WALLPAPER_DIR"
        exit 1
    }

    local idx=$(( RANDOM % ${#walls[@]} ))
    set_wallpaper "${walls[$idx]}"
    echo "$idx" > "$INDEX_FILE"
}

set_next() {
    local walls
    mapfile -t walls < <(get_wallpapers)
    [[ ${#walls[@]} -eq 0 ]] && { echo "No wallpapers found"; exit 1; }

    local idx=0
    [[ -f "$INDEX_FILE" ]] && idx=$(( $(cat "$INDEX_FILE") + 1 ))
    [[ $idx -ge ${#walls[@]} ]] && idx=0

    set_wallpaper "${walls[$idx]}"
    echo "$idx" > "$INDEX_FILE"
}

set_prev() {
    local walls
    mapfile -t walls < <(get_wallpapers)
    [[ ${#walls[@]} -eq 0 ]] && { echo "No wallpapers found"; exit 1; }

    local idx=$(( ${#walls[@]} - 1 ))
    [[ -f "$INDEX_FILE" ]] && idx=$(( $(cat "$INDEX_FILE") - 1 ))
    [[ $idx -lt 0 ]] && idx=$(( ${#walls[@]} - 1 ))

    set_wallpaper "${walls[$idx]}"
    echo "$idx" > "$INDEX_FILE"
}

slideshow() {
    echo "Starting slideshow (interval: ${INTERVAL}s). Ctrl+C to stop."
    while true; do
        set_random
        sleep "$INTERVAL"
    done
}

# ---- Main ----

check_deps
mkdir -p "$HOME/.cache" "$WALLPAPER_DIR"

case "${1:-}" in
    --next)      set_next ;;
    --prev)      set_prev ;;
    --slideshow) slideshow ;;
    --list)      get_wallpapers ;;
    --current)   cat "$CACHE_FILE" 2>/dev/null || echo "No wallpaper set yet" ;;
    "")          set_random ;;
    *)           set_wallpaper "$1" ;;
esac
