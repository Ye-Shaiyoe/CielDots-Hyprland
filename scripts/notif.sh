#!/bin/bash
# /* ---- 💫 CielDots — Smart Notification Manager 💫 ---- */
# Wrapper around makoctl for mute, history, and DnD
# Usage:
#   notif.sh mute <app>     → mute app notifications temporarily
#   notif.sh unmute <app>   → unmute an app
#   notif.sh mute --list    → list muted apps
#   notif.sh mute --clear   → clear all mutes
#   notif.sh history        → show notification history via launcher
#   notif.sh dnd            → toggle do-not-disturb
#   notif.sh dnd status     → show DnD status

MUTE_FILE="$HOME/.cache/cieldots-muted-apps"
MAKO_CONFIG="$HOME/.config/mako/config"
MAKO_RULES_FILE="$HOME/.config/mako/rules-muted"

# ── Helpers ───────────────────────────────────────────────────
notif_send() {
    notify-send -a "Notifications" -t 3000 "$1" "$2" 2>/dev/null
}

require_mako() {
    pgrep -x mako &>/dev/null || { echo "mako not running"; exit 1; }
    command -v makoctl &>/dev/null || { echo "makoctl not found"; exit 1; }
}

# ── Mute ─────────────────────────────────────────────────────
do_mute() {
    local app="$1"
    require_mako
    mkdir -p "$HOME/.cache"

    # Track in mute list
    grep -qxF "$app" "$MUTE_FILE" 2>/dev/null || echo "$app" >> "$MUTE_FILE"

    # Write mako rule to suppress (guard against duplicate entries)
    if ! grep -qF "[app-name=$app]" "$MAKO_RULES_FILE" 2>/dev/null; then
        printf '\n[app-name=%s]\ninvisible=1\n' "$app" >> "$MAKO_RULES_FILE"
    fi

    makoctl reload
    notif_send "Muted" "Notifications from '$app' silenced"
    echo "Muted: $app"
}

do_unmute() {
    local app="$1"
    require_mako

    # Remove from mute list
    sed -i "/^${app}$/d" "$MUTE_FILE" 2>/dev/null

    # Remove block: [app-name=X]\ninvisible=1 from rules file
    if [[ -f "$MAKO_RULES_FILE" ]]; then
        sed -i "/^\[app-name=${app}\]/,/^invisible=1$/d" "$MAKO_RULES_FILE"
        # Remove orphaned blank lines left behind
        sed -i '/^$/N;/^\n$/d' "$MAKO_RULES_FILE"
    fi

    makoctl reload
    notif_send "Unmuted" "Notifications from '$app' restored"
    echo "Unmuted: $app"
}

list_muted() {
    if [[ ! -f "$MUTE_FILE" ]] || [[ ! -s "$MUTE_FILE" ]]; then
        echo "No apps currently muted"
        return
    fi
    echo "Muted apps:"
    while IFS= read -r app; do
        echo "  • $app"
    done < "$MUTE_FILE"
}

clear_mutes() {
    require_mako
    : > "$MUTE_FILE"
    : > "$MAKO_RULES_FILE" 2>/dev/null
    makoctl reload
    notif_send "Notifications" "All mutes cleared"
    echo "All mutes cleared"
}

# ── Do Not Disturb ───────────────────────────────────────────
do_dnd_toggle() {
    require_mako
    local current
    current=$(makoctl get-mode 2>/dev/null || echo "default")

    if [[ "$current" == "do-not-disturb" ]]; then
        makoctl set-mode default
        notif_send "DnD OFF" "Notifications restored"
        echo "Do-not-disturb: OFF"
    else
        makoctl set-mode do-not-disturb
        # Silent — DnD means no notifications
        echo "Do-not-disturb: ON"
    fi
}

do_dnd_status() {
    require_mako
    local mode
    mode=$(makoctl get-mode 2>/dev/null || echo "unknown")
    if [[ "$mode" == "do-not-disturb" ]]; then
        echo "DnD: ON 󰂛"
    else
        echo "DnD: OFF 󰂜"
    fi
}

# ── History via launcher ──────────────────────────────────────
do_history() {
    require_mako
    command -v wofi &>/dev/null || { echo "wofi not found"; exit 1; }

    # Get history from makoctl
    local history
    history=$(makoctl history 2>/dev/null | \
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for group in reversed(data.get('data', [[]])):
        for n in group:
            app     = n.get('app-name', {}).get('data', 'unknown')
            summary = n.get('summary', {}).get('data', '')
            body    = n.get('body', {}).get('data', '')
            line = f'[{app}] {summary}'
            if body:
                line += f' — {body[:60]}'
            print(line)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
" 2>/dev/null)

    if [[ -z "$history" ]]; then
        notif_send "History" "No notification history"
        return
    fi

    local selected
    selected=$(echo "$history" | \
        wofi \
            --style "$HOME/.config/wofi/style.css" \
            --gtk-dark \
            --show dmenu \
            --prompt "  History..." \
            --width 700 \
            --height 500 \
            --define=no_actions=true)

    [[ -z "$selected" ]] && return

    # Copy selected text to clipboard
    echo -n "$selected" | wl-copy
    notif_send "Copied" "Notification text copied to clipboard"
}

# ── Main ─────────────────────────────────────────────────────
case "${1:-}" in
    mute)
        case "${2:-}" in
            --list)  list_muted ;;
            --clear) clear_mutes ;;
            "")      echo "Usage: notif.sh mute <app|--list|--clear>"; exit 1 ;;
            *)       do_mute "$2" ;;
        esac
        ;;
    unmute)
        [[ -z "${2:-}" ]] && { echo "Usage: notif.sh unmute <app>"; exit 1; }
        do_unmute "$2"
        ;;
    history|h)
        do_history
        ;;
    dnd)
        case "${2:-}" in
            status) do_dnd_status ;;
            *)      do_dnd_toggle ;;
        esac
        ;;
    *)
        echo "Usage: $(basename "$0") <command> [args]"
        echo ""
        echo "Commands:"
        echo "  mute <app>      Silence notifications from an app"
        echo "  mute --list     List all muted apps"
        echo "  mute --clear    Clear all mutes"
        echo "  unmute <app>    Restore notifications from an app"
        echo "  history         Show notification history in launcher"
        echo "  dnd             Toggle do-not-disturb"
        echo "  dnd status      Show DnD state"
        exit 1
        ;;
esac
