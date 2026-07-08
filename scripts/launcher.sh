#!/bin/bash
# /* ---- ✦ CielDots — Custom Launcher ✦ ---- */
# Multi-mode launcher wrapper around wofi
# Usage:
#   launcher.sh apps       → app launcher (default)
#   launcher.sh power      → power menu
#   launcher.sh clipboard  → clipboard history (cliphist)
#   launcher.sh emoji      → emoji picker
#   launcher.sh files      → recent files (fd)

MODE="${1:-apps}"

# ── Wofi common options ───────────────────────────────────────
WOFI_STYLE="$HOME/.config/wofi/style.css"
WOFI_BASE=(wofi --style "$WOFI_STYLE" --gtk-dark)

# ── Notify helper ─────────────────────────────────────────────
notif() {
    notify-send -a "Launcher" -t 2000 "$1" "$2" 2>/dev/null
}

# ══════════════════════════════════════════════════════════════
# MODE: apps
# ══════════════════════════════════════════════════════════════
mode_apps() {
    "${WOFI_BASE[@]}" \
        --show drun \
        --prompt "  Search apps..." \
        --width 520 \
        --height 380 \
        --define=image_size=28 \
        --define=allow_images=true \
        --define=no_actions=true
}

# ══════════════════════════════════════════════════════════════
# MODE: power
# ══════════════════════════════════════════════════════════════
mode_power() {
    local options=(
        "⏻  Shutdown"
        "  Reboot"
        "󰤄  Suspend"
        "  Hibernate"
        "  Lock"
        "󰗼  Logout"
    )

    local choice
    choice=$(printf '%s\n' "${options[@]}" | \
        "${WOFI_BASE[@]}" \
            --show dmenu \
            --prompt "  Power..." \
            --width 280 \
            --height 300 \
            --define=no_actions=true \
            --define=allow_markup=true)

    [[ -z "$choice" ]] && exit 0

    case "$choice" in
        *Shutdown*)
            _confirm "Shutdown" && systemctl poweroff ;;
        *Reboot*)
            _confirm "Reboot" && systemctl reboot ;;
        *Suspend*)
            systemctl suspend ;;
        *Hibernate*)
            systemctl hibernate ;;
        *Lock*)
            hyprlock ;;
        *Logout*)
            _confirm "Logout" && hyprctl dispatch exit ;;
    esac
}

_confirm() {
    local action="$1"
    local result
    result=$(printf 'Yes\nNo' | \
        "${WOFI_BASE[@]}" \
            --show dmenu \
            --prompt "  $action?" \
            --width 200 \
            --height 130)
    [[ "$result" == "Yes" ]]
}

# ══════════════════════════════════════════════════════════════
# MODE: clipboard
# ══════════════════════════════════════════════════════════════
mode_clipboard() {
    if ! command -v cliphist &>/dev/null; then
        notif "Clipboard" "cliphist not installed"
        exit 1
    fi
    if ! pgrep -x cliphist &>/dev/null; then
        notif "Clipboard" "cliphist daemon not running"
        exit 1
    fi

    local selected
    selected=$(cliphist list | \
        "${WOFI_BASE[@]}" \
            --show dmenu \
            --prompt "  Clipboard..." \
            --width 600 \
            --height 420 \
            --define=no_actions=true)

    [[ -z "$selected" ]] && exit 0
    cliphist decode <<<"$selected" | wl-copy
}

# ══════════════════════════════════════════════════════════════
# MODE: emoji
# ══════════════════════════════════════════════════════════════
mode_emoji() {
    # Built-in emoji list — no external file needed
    # Format: "emoji description"
    local EMOJI_LIST
    EMOJI_LIST=$(cat << 'EOF'
😀 grinning face
😂 face with tears of joy
🥹 face holding back tears
😍 smiling face with heart-eyes
🥰 smiling face with hearts
😎 smiling face with sunglasses
🤩 star-struck
😭 loudly crying face
😤 face with steam from nose
🥺 pleading face
😴 sleeping face
🤔 thinking face
🫡 saluting face
🤯 exploding head
👀 eyes
🫶 heart hands
👍 thumbs up
👎 thumbs down
✅ check mark
❌ cross mark
🔥 fire
💥 collision
⭐ star
🌟 glowing star
💫 dizzy
✨ sparkles
❤️ red heart
🩵 light blue heart
💜 purple heart
🖤 black heart
🤍 white heart
🎉 party popper
🎊 confetti ball
🎮 video game
💻 laptop computer
🖥️ desktop computer
⌨️ keyboard
🖱️ mouse
📱 mobile phone
🔧 wrench
⚙️ gear
🗂️ card index dividers
📁 file folder
📝 memo
🔑 key
🔒 locked
🔓 unlocked
🌐 globe
🌙 crescent moon
☀️ sun
⛅ sun behind cloud
🌧️ cloud with rain
⚡ lightning
🌊 water wave
🍜 steaming bowl
🍣 sushi
🍕 pizza
☕ hot beverage
🧋 bubble tea
🍺 beer mug
EOF
    )

    local selected
    selected=$(echo "$EMOJI_LIST" | \
        "${WOFI_BASE[@]}" \
            --show dmenu \
            --prompt "  Emoji..." \
            --width 400 \
            --height 500 \
            --define=no_actions=true)

    [[ -z "$selected" ]] && exit 0

    # Extract just the emoji character (first field)
    local emoji
    emoji=$(echo "$selected" | awk '{print $1}')
    echo -n "$emoji" | wl-copy
    notif "Emoji" "Copied: $emoji"
}

# ══════════════════════════════════════════════════════════════
# MODE: files
# ══════════════════════════════════════════════════════════════
mode_files() {
    if ! command -v fd &>/dev/null; then
        notif "Files" "fd not installed"
        exit 1
    fi

    local selected
    selected=$(fd --type f --max-depth 3 --base-directory "$HOME" \
            --exclude .git --exclude node_modules --exclude ".cache" \
        2>/dev/null | sort | \
        "${WOFI_BASE[@]}" \
            --show dmenu \
            --prompt "  Files..." \
            --width 700 \
            --height 480 \
            --define=no_actions=true)

    [[ -z "$selected" ]] && exit 0

    local fullpath="$HOME/$selected"
    if [[ -f "$fullpath" ]]; then
        xdg-open "$fullpath" &
    fi
}

# ══════════════════════════════════════════════════════════════
# MODE: wallpaper
# ══════════════════════════════════════════════════════════════
mode_wallpaper() {
    local walls_dir="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
    if [[ ! -d "$walls_dir" ]]; then
        notif "Wallpaper" "Directory not found: $walls_dir"
        exit 1
    fi

    local selected
    # List all image files and prompt user with wofi
    selected=$(find "$walls_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -printf "%f\n" | sort | \
        "${WOFI_BASE[@]}" \
            --show dmenu \
            --prompt "  Select Wallpaper..." \
            --width 600 \
            --height 400 \
            --define=no_actions=true)

    [[ -z "$selected" ]] && exit 0

    bash ~/.config/hypr/scripts/wallpaper.sh "$walls_dir/$selected"
}

# ══════════════════════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════════════════════
case "$MODE" in
    apps|a)       mode_apps ;;
    power|p)      mode_power ;;
    clipboard|c)  mode_clipboard ;;
    emoji|e)      mode_emoji ;;
    files|f)      mode_files ;;
    wallpaper|w)  mode_wallpaper ;;
    *)
        echo "Usage: $(basename "$0") [apps|power|clipboard|emoji|files|wallpaper]"
        exit 1
        ;;
esac
