#!/bin/bash
# ============================================================
# startup.sh — Hyprland startup sequence
# Dipanggil dari hyprland.conf:
#   exec-once = ~/.config/hypr/startup.sh
# ============================================================

# Tunggu Hyprland benar-benar siap
sleep 0.5

LOG_FILE="$HOME/.cache/hyprland-startup.log"
mkdir -p "$HOME/.cache"
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ---- Fungsi launch yang cerdas ----
# Hanya jalankan kalau belum running

launch() {
    local name="$1"
    shift
    if ! pgrep -x "$name" &>/dev/null; then
        log "Starting $name..."
        "$@" &
        disown
    else
        log "$name already running, skipping"
    fi
}

launch_once() {
    local flag="$HOME/.cache/first_run_$1"
    shift
    if [[ ! -f "$flag" ]]; then
        "$@"
        touch "$flag"
    fi
}

log "=== Hyprland Startup ==="
log "Session: $XDG_SESSION_TYPE"
log "Display: $WAYLAND_DISPLAY"

# ---- Startup splash ----
if [[ -f "$HOME/.config/hypr/scripts/startup-splash.py" ]]; then
    kitty --class=splash \
          --override background_opacity=0.0 \
          --override hide_window_decorations=yes \
          --override remember_window_size=no \
          --override initial_window_width=700 \
          --override initial_window_height=420 \
          -- python3 "$HOME/.config/hypr/scripts/startup-splash.py" &
    sleep 2.5
fi

# ---- D-Bus & Portal ----
log "Setting up D-Bus environment..."
dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE \
    HYPRLAND_INSTANCE_SIGNATURE \
    QT_QPA_PLATFORM \
    GDK_BACKEND 2>/dev/null

systemctl --user import-environment \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP 2>/dev/null

# ---- Core services ----
launch swww-daemon swww-daemon
sleep 0.3

# Set wallpaper
if [[ -f "$HOME/.cache/current_wallpaper" ]]; then
    WALL="$(cat "$HOME/.cache/current_wallpaper")"
    [[ -f "$WALL" ]] && swww img "$WALL" --transition-type fade --transition-duration 1
else
    # Default ke random kalau script tersedia
    if [[ -f "$HOME/.config/hypr/scripts/wallpaper.sh" ]]; then
        bash "$HOME/.config/hypr/scripts/wallpaper.sh"
    elif ls "$HOME/Pictures/Wallpapers"/*.{jpg,png,jpeg} &>/dev/null 2>&1; then
        WALL="$(ls "$HOME/Pictures/Wallpapers"/*.{jpg,png,jpeg} 2>/dev/null | shuf -n1)"
        swww img "$WALL" --transition-type fade
    fi
fi

# ---- UI Components ----
sleep 0.2
launch waybar waybar
launch mako mako

# ---- Authentication agent ----
if [[ -f /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]]; then
    launch polkit-gnome-authentication-agent-1 \
        /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
elif [[ -f /usr/lib/polkit-kde-authentication-agent-1 ]]; then
    launch polkit-kde-authentication-agent-1 \
        /usr/lib/polkit-kde-authentication-agent-1
fi

# ---- System tray apps ----
launch nm-applet nm-applet --indicator
launch blueman-applet blueman-applet 2>/dev/null

# ---- Clipboard manager ----
# cliphist stores clipboard history, used by launcher.sh clipboard
if command -v wl-paste &>/dev/null && command -v cliphist &>/dev/null; then
    wl-paste --watch cliphist store &
    disown
    log "cliphist daemon started"
fi

# ---- XDG portal ----
# Restart portal untuk memastikan screen sharing jalan
pkill -f xdg-desktop-portal 2>/dev/null
sleep 0.5
launch xdg-desktop-portal /usr/lib/xdg-desktop-portal --replace &
sleep 0.2
launch xdg-desktop-portal-hyprland /usr/lib/xdg-desktop-portal-hyprland &

# ---- User services ----
# Hypridle (auto lock)
launch hypridle hypridle

# ---- First run setup ----
launch_once xdg_dirs xdg-user-dirs-update

# ---- Done ----
log "=== Startup complete ==="

# Welcome notification
notify-send \
    -a "Hyprland" \
    -i "preferences-system" \
    -t 3000 \
    "Hyprland ready" \
    "$(date '+%A, %d %B %Y')" 2>/dev/null
