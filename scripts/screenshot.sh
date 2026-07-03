#!/bin/bash
# ============================================================
# screenshot.sh — Screenshot tool untuk Hyprland
# Requires: grim, slurp, swappy (optional edit), wl-clipboard
# Usage:
#   screenshot.sh area       → pilih area → copy + save + notif
#   screenshot.sh full       → fullscreen semua monitor
#   screenshot.sh window     → window aktif
#   screenshot.sh --edit     → buka di swappy untuk anotasi
# ============================================================

SAVE_DIR="${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
FILENAME="screenshot_${TIMESTAMP}.png"
FILEPATH="$SAVE_DIR/$FILENAME"
EDIT=false

# Parse flags
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --edit|-e) EDIT=true ;;
        *) ARGS+=("$arg") ;;
    esac
done
MODE="${ARGS[0]:-area}"

# ---- Helpers ----

check_deps() {
    local missing=()
    for dep in grim slurp wl-copy; do
        command -v "$dep" &>/dev/null || missing+=("$dep")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        notify-send -a "Screenshot" "Missing dependencies" "${missing[*]}" 2>/dev/null
        echo "Missing: ${missing[*]}"
        exit 1
    fi
}

notify_success() {
    local filepath="$1"
    local filename
    filename="$(basename "$filepath")"

    # Tampilkan thumbnail di notifikasi kalau bisa
    notify-send \
        -a "Screenshot" \
        -i "$filepath" \
        -t 4000 \
        "📸 Screenshot saved" \
        "$filename\n→ $SAVE_DIR" \
        --action="open=Open" \
        --action="folder=Open Folder" 2>/dev/null

    echo "Saved: $filepath"
}

open_editor() {
    local filepath="$1"
    if command -v swappy &>/dev/null; then
        swappy -f "$filepath" -o "$filepath"
    else
        notify-send -a "Screenshot" "swappy not found" "Install swappy untuk edit screenshot" 2>/dev/null
    fi
}

# ---- Screenshot modes ----

screenshot_area() {
    local geom
    geom="$(slurp -d -c '#cba6f7ff' -b '#1e1e2e40' -s '#cba6f710')" || exit 0

    grim -g "$geom" "$FILEPATH" && {
        wl-copy < "$FILEPATH"
        $EDIT && open_editor "$FILEPATH"
        notify_success "$FILEPATH"
    }
}

screenshot_full() {
    grim "$FILEPATH" && {
        wl-copy < "$FILEPATH"
        $EDIT && open_editor "$FILEPATH"
        notify_success "$FILEPATH"
    }
}

screenshot_window() {
    # Ambil geometry window aktif dari hyprctl
    local geom
    geom="$(hyprctl activewindow -j | \
        python3 -c "
import json, sys
w = json.load(sys.stdin)
at = w['at']
sz = w['size']
print(f'{at[0]},{at[1]} {sz[0]}x{sz[1]}')
" 2>/dev/null)"

    if [[ -z "$geom" ]]; then
        notify-send -a "Screenshot" "No active window" "" 2>/dev/null
        exit 1
    fi

    grim -g "$geom" "$FILEPATH" && {
        wl-copy < "$FILEPATH"
        $EDIT && open_editor "$FILEPATH"
        notify_success "$FILEPATH"
    }
}

screenshot_monitor() {
    # Screenshot monitor aktif
    local monitor
    monitor="$(hyprctl monitors -j | \
        python3 -c "
import json, sys
monitors = json.load(sys.stdin)
for m in monitors:
    if m.get('focused'):
        print(m['name'])
        break
" 2>/dev/null)"

    grim -o "${monitor:-eDP-1}" "$FILEPATH" && {
        wl-copy < "$FILEPATH"
        $EDIT && open_editor "$FILEPATH"
        notify_success "$FILEPATH"
    }
}

# ---- Main ----

check_deps
mkdir -p "$SAVE_DIR"

case "$MODE" in
    area|a)     screenshot_area ;;
    full|f)     screenshot_full ;;
    window|w)   screenshot_window ;;
    monitor|m)  screenshot_monitor ;;
    *)
        echo "Usage: $(basename "$0") [area|full|window|monitor] [--edit]"
        echo ""
        echo "  area    → pilih area dengan kursor"
        echo "  full    → seluruh layar"
        echo "  window  → window aktif"
        echo "  monitor → monitor aktif"
        echo ""
        echo "Flags:"
        echo "  --edit  → buka di swappy setelah capture"
        exit 1
        ;;
esac
