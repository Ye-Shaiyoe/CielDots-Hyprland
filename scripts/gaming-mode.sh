#!/bin/bash
# ============================================================
# gaming-mode.sh — Toggle gaming mode di Hyprland
# Gaming mode: matiin waybar, gaps=0, animasi off, gamemode on
# Usage:
#   gaming-mode.sh          → toggle on/off
#   gaming-mode.sh on       → aktifkan
#   gaming-mode.sh off      → nonaktifkan
#   gaming-mode.sh status   → cek status
# ============================================================

STATE_FILE="$HOME/.cache/gaming_mode"
HYPRCTL="hyprctl"

# ---- Helpers ----

notify() {
    local icon="$1"
    local title="$2"
    local msg="$3"
    notify-send -a "Gaming Mode" -i "$icon" -t 3000 "$title" "$msg" 2>/dev/null
}

is_active() {
    [[ -f "$STATE_FILE" ]]
}

# ---- Gaming Mode ON ----

gaming_on() {
    echo "Enabling gaming mode..."

    # Kill waybar
    pkill -x waybar && echo "  → Waybar stopped"

    # Hyprland tweaks via hyprctl
    $HYPRCTL keyword general:gaps_in 0
    $HYPRCTL keyword general:gaps_out 0
    $HYPRCTL keyword general:border_size 0
    $HYPRCTL keyword decoration:rounding 0
    $HYPRCTL keyword decoration:blur:enabled false
    $HYPRCTL keyword decoration:shadow:enabled false
    $HYPRCTL keyword animations:enabled false
    $HYPRCTL keyword misc:vfr false  # disable VFR untuk performa konsisten

    # CPU governor ke performance (perlu sudo atau perms)
    if command -v cpupower &>/dev/null; then
        sudo cpupower frequency-set -g performance 2>/dev/null && \
            echo "  → CPU governor: performance"
    fi

    # GameMode daemon (kalau terinstall)
    if command -v gamemoded &>/dev/null; then
        gamemoded 2>/dev/null && echo "  → GameMode daemon started"
    fi

    # Disable notifikasi
    if command -v makoctl &>/dev/null; then
        makoctl set-mode do-not-disturb && echo "  → Notifications: do-not-disturb"
    fi

    touch "$STATE_FILE"
    notify "applications-games" "🎮 Gaming Mode ON" "Waybar off · Animasi off · Performa max"
    echo "Gaming mode ON"
}

# ---- Gaming Mode OFF ----

gaming_off() {
    echo "Disabling gaming mode..."

    # Restore Hyprland settings
    $HYPRCTL keyword general:gaps_in 5
    $HYPRCTL keyword general:gaps_out 10
    $HYPRCTL keyword general:border_size 2
    $HYPRCTL keyword decoration:rounding 10
    $HYPRCTL keyword decoration:blur:enabled true
    $HYPRCTL keyword decoration:shadow:enabled true
    $HYPRCTL keyword animations:enabled true
    $HYPRCTL keyword misc:vfr true

    # Restore CPU governor
    if command -v cpupower &>/dev/null; then
        sudo cpupower frequency-set -g schedutil 2>/dev/null && \
            echo "  → CPU governor: schedutil"
    fi

    # Stop GameMode
    if command -v gamemoded &>/dev/null; then
        pkill gamemoded 2>/dev/null && echo "  → GameMode daemon stopped"
    fi

    # Re-enable notifikasi
    if command -v makoctl &>/dev/null; then
        makoctl set-mode default && echo "  → Notifications: default"
    fi

    # Restart waybar
    waybar &
    disown
    echo "  → Waybar started"

    rm -f "$STATE_FILE"
    notify "utilities-system-monitor" "🖥️ Gaming Mode OFF" "Kembali ke mode normal"
    echo "Gaming mode OFF"
}

# ---- Status ----

show_status() {
    if is_active; then
        echo "Gaming mode: ACTIVE 🎮"
        echo "  Waybar: off"
        echo "  Animations: off"
        echo "  Gaps: 0"
    else
        echo "Gaming mode: INACTIVE 🖥️"
        echo "  Waybar: on"
        echo "  Animations: on"
    fi
}

# ---- Main ----

mkdir -p "$HOME/.cache"

case "${1:-toggle}" in
    on)     gaming_on ;;
    off)    gaming_off ;;
    status) show_status ;;
    toggle)
        if is_active; then
            gaming_off
        else
            gaming_on
        fi
        ;;
    *)
        echo "Usage: $(basename "$0") [on|off|status|toggle]"
        exit 1
        ;;
esac
