#!/bin/bash
# ============================================================
# CielDots — Clean Uninstaller & Rollback Tool for Gentoo
# ============================================================

set -euo pipefail

R='\033[38;2;243;139;168m'   # red
G='\033[38;2;166;227;161m'   # green
Y='\033[38;2;249;226;175m'   # yellow
B='\033[38;2;137;180;250m'   # blue
M='\033[38;2;203;166;247m'   # mauve
S='\033[38;2;166;173;200m'   # subtext
T='\033[38;2;205;214;244m'   # text
NC='\033[0m'

info()  { echo -e "${B}[INFO]${NC}  $*"; }
ok()    { echo -e "${G}[ OK ]${NC}  $*"; }
warn()  { echo -e "${Y}[WARN]${NC}  $*"; }
err()   { echo -e "${R}[ERR ]${NC}  $*"; }
die()   { err "$*"; exit 1; }
step()  { echo -e "\n${M}══${NC} ${T}$*${NC}"; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_BASE="$HOME/.config-backup-cieldots"
SNAPSHOT_FILE="$HOME/.cache/cieldots-install-snapshot.json"

print_banner() {
    echo -e "${R}"
    cat << 'EOF'
  ██╗   ██╗███╗   ██╗██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     
  ██║   ██║████╗  ██║██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     
  ██║   ██║██╔██╗ ██║██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     
  ██║   ██║██║╚██╗██║██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     
  ╚██████╔╝██║ ╚████║██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
   ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝
EOF
    echo -e "${NC}"
    echo -e "  ${S}CielDots Dotfiles & Configuration Removal Utility${NC}"
    echo ""
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local choice
    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n] " choice
        [[ "${choice,,}" != "n" ]]
    else
        read -rp "$prompt [y/N] " choice
        [[ "${choice,,}" == "y" ]]
    fi
}

# ── 1. Restore from Snapshot / Backups ────────────────────────
restore_backups() {
    step "1. Checking for Previous Backups & Restoring"

    local restored_count=0
    # Try snapshot first if available
    if [[ -f "$SNAPSHOT_FILE" ]] && command -v python3 &>/dev/null; then
        info "Restoring files recorded during installation snapshot..."
        python3 - "$SNAPSHOT_FILE" << 'PYEOF'
import json, shutil, sys, os
try:
    with open(sys.argv[1]) as f:
        entries = json.load(f)
    for e in entries:
        try:
            if os.path.exists(e["backup"]):
                if os.path.islink(e["path"]) or os.path.exists(e["path"]):
                    os.remove(e["path"])
                shutil.copy2(e["backup"], e["path"])
                print(f"  \033[38;2;166;227;161m[RESTORED]\033[0m {e['path']}")
        except Exception as ex:
            print(f"  \033[38;2;255;82;82m[FAILED]\033[0m   {e['path']} — {ex}")
except Exception as ex:
    print(f"Error reading snapshot: {ex}")
PYEOF
        rm -f "$SNAPSHOT_FILE"
        ok "Snapshot restore complete"
        return
    fi

    # Fallback to newest backup dir
    if [[ -d "$BACKUP_BASE" ]]; then
        local latest_bak
        latest_bak=$(find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d | sort -r | head -n 1)
        if [[ -n "$latest_bak" && -d "$latest_bak" ]]; then
            info "Found latest backup directory: $latest_bak"
            if confirm "  Restore files from this backup directory?"; then
                cp -av "$latest_bak/." "$HOME/" 2>/dev/null || true
                ok "Original configurations restored from backup"
                restored_count=$((restored_count + 1))
            fi
        fi
    fi

    if [[ $restored_count -eq 0 ]]; then
        info "No previous backup found to restore (clean system state)."
    fi
}

# ── 2. Remove Symlinks ───────────────────────────────────────
remove_symlinks() {
    step "2. Removing CielDots Symlinks"

    local links=(
        "$HOME/.config/hypr/hyprland.lua"
        "$HOME/.config/hypr/hyprland.conf"
        "$HOME/.config/hypr/hyprlock.conf"
        "$HOME/.config/hypr/hypridle.conf"
        "$HOME/.config/waybar/config.jsonc"
        "$HOME/.config/waybar/style.css"
        "$HOME/.config/waybar/dynamic-colors.css"
        "$HOME/.config/kitty/kitty.conf"
        "$HOME/.config/kitty/themes/rimuru.conf"
        "$HOME/.config/kitty/themes/dynamic.conf"
        "$HOME/.config/mako/config"
        "$HOME/.config/wofi/config"
        "$HOME/.config/wofi/style.css"
        "$HOME/.config/zsh/.zshrc"
        "$HOME/.config/starship/starship.toml"
        "$HOME/.config/gtk-3.0/settings.ini"
        "$HOME/.config/gtk-4.0/settings.ini"
        "$HOME/.config/fastfetch/config.jsonc"
        "$HOME/.config/fastfetch/rimuru.txt"
    )

    for link in "${links[@]}"; do
        if [[ -L "$link" ]]; then
            local target
            target=$(readlink -f "$link" 2>/dev/null || true)
            # Only remove if pointing into our dotfiles directory
            if [[ "$target" == "$DOTFILES_DIR"* ]]; then
                rm -f "$link"
                ok "  Removed symlink: $link"
            fi
        fi
    done

    # Remove script symlinks from ~/.config/hypr/scripts/ and ~/.local/bin/
    info "Removing script symlinks..."
    for script in "$DOTFILES_DIR/scripts/"*.*; do
        [[ -f "$script" ]] || continue
        local fname
        fname="$(basename "$script")"
        local stem="${fname%.*}"

        local hypr_link="$HOME/.config/hypr/scripts/$fname"
        if [[ -L "$hypr_link" ]]; then
            rm -f "$hypr_link"
            ok "  Removed: $hypr_link"
        fi

        local bin_link="$HOME/.local/bin/$stem"
        if [[ -L "$bin_link" ]]; then
            local btarget
            btarget=$(readlink -f "$bin_link" 2>/dev/null || true)
            if [[ "$btarget" == "$DOTFILES_DIR"* ]]; then
                rm -f "$bin_link"
                ok "  Removed: $bin_link"
            fi
        fi
    done

    # Clean empty directories
    [[ -d "$HOME/.config/hypr/scripts" ]] && rmdir "$HOME/.config/hypr/scripts" 2>/dev/null || true
    [[ -d "$HOME/.config/hypr" ]] && rmdir "$HOME/.config/hypr" 2>/dev/null || true
}

# ── 3. Portage Configurations Cleanup ────────────────────────
clean_portage() {
    step "3. Cleaning Portage USE Flags & Keywords"

    if confirm "Remove CielDots USE flags and ~amd64 keywords from /etc/portage?"; then
        # package.use
        if [[ -f "/etc/portage/package.use/cieldots" ]]; then
            sudo rm -f "/etc/portage/package.use/cieldots"
            ok "  Removed /etc/portage/package.use/cieldots"
        elif [[ -f "/etc/portage/package.use" ]]; then
            if grep -q "# CielDots USE flags" "/etc/portage/package.use" 2>/dev/null; then
                sudo sed -i '/# CielDots USE flags/,/# End CielDots USE flags/d' "/etc/portage/package.use"
                ok "  Cleaned CielDots entries from /etc/portage/package.use"
            fi
        fi

        # package.accept_keywords
        if [[ -f "/etc/portage/package.accept_keywords/cieldots" ]]; then
            sudo rm -f "/etc/portage/package.accept_keywords/cieldots"
            ok "  Removed /etc/portage/package.accept_keywords/cieldots"
        elif [[ -f "/etc/portage/package.accept_keywords" ]]; then
            if grep -q "# CielDots ~amd64 keywords" "/etc/portage/package.accept_keywords" 2>/dev/null; then
                sudo sed -i '/# CielDots ~amd64 keywords/,/# End CielDots keywords/d' "/etc/portage/package.accept_keywords"
                ok "  Cleaned CielDots entries from /etc/portage/package.accept_keywords"
            fi
        fi
    else
        info "Skipped Portage configuration cleanup."
    fi
}

# ── 4. Cache and Theme Cleanup ───────────────────────────────
clean_cache_and_theming() {
    step "4. Cleaning Caches & Theme Files"

    if confirm "Remove CielDots cache files and Catppuccin GTK theme?"; then
        rm -f "$HOME/.cache/cieldots-"* 2>/dev/null || true
        rm -f "$HOME/.cache/hyprland-"* 2>/dev/null || true
        rm -f "$HOME/.cache/current_wallpaper" 2>/dev/null || true
        rm -f "$HOME/.cache/gaming_mode" 2>/dev/null || true
        rm -f "$HOME/.cache/wallpaper_index" 2>/dev/null || true
        rm -rf "$HOME/.local/share/themes/Catppuccin-Mocha"* 2>/dev/null || true
        ok "Cache and theme files removed"
    else
        info "Skipped cache cleanup."
    fi

    # ZDOTDIR in /etc/zsh/zshenv
    if [[ -f "/etc/zsh/zshenv" ]] && grep -q 'ZDOTDIR="$HOME/.config/zsh"' "/etc/zsh/zshenv" 2>/dev/null; then
        if confirm "Remove CielDots ZDOTDIR setting from /etc/zsh/zshenv?"; then
            sudo sed -i '/export ZDOTDIR="\$HOME\/.config\/zsh"/d' "/etc/zsh/zshenv"
            ok "Removed ZDOTDIR from /etc/zsh/zshenv"
        fi
    fi

    # Wayland session desktop entry
    if [[ -f "/usr/share/wayland-sessions/hyprland.desktop" ]]; then
        if confirm "Remove custom Hyprland session entry from /usr/share/wayland-sessions/?"; then
            sudo rm -f "/usr/share/wayland-sessions/hyprland.desktop"
            ok "Removed /usr/share/wayland-sessions/hyprland.desktop"
        fi
    fi
}

# ── 5. Package Unmerging (Optional) ──────────────────────────
unmerge_packages() {
    step "5. Package Removal (Optional)"

    echo -e "  ${T}Installed packages can be kept or safely unmerged via Portage.${NC}"
    if confirm "Would you like to unmerge Hyprland and CielDots packages now?" "n"; then
        local pkgs=(
            "gui-wm/hyprland"
            "gui-apps/hyprlock"
            "gui-apps/hypridle"
            "gui-apps/hyprpicker"
            "gui-libs/xdg-desktop-portal-hyprland"
            "gui-apps/waybar"
            "gui-apps/wofi"
            "gui-apps/mako"
            "gui-apps/swww"
            "gui-apps/waypaper"
            "gui-apps/swappy"
            "gui-apps/cliphist"
        )
        info "Running: sudo emerge --ask --depclean ${pkgs[*]}"
        sudo emerge --ask --depclean "${pkgs[@]}" || warn "Some packages were retained due to active dependencies."
    else
        info "Packages retained. To remove manually later, run:"
        echo -e "    ${B}sudo emerge --ask --depclean gui-wm/hyprland gui-apps/waybar gui-apps/wofi gui-apps/mako gui-apps/swww${NC}"
    fi
}

# ── Main ─────────────────────────────────────────────────────
main() {
    print_banner
    warn "This utility will uninstall CielDots dotfiles and configurations from your system."
    echo ""

    if ! confirm "Are you sure you want to proceed with uninstallation?"; then
        die "Uninstallation cancelled."
    fi

    restore_backups
    remove_symlinks
    clean_portage
    clean_cache_and_theming
    unmerge_packages

    echo ""
    echo -e "${G}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${G}║       CielDots Uninstallation Complete! ✨       ║${NC}"
    echo -e "${G}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    info "Your Gentoo system has been restored."
}

main "$@"
