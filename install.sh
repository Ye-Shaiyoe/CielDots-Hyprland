#!/bin/bash
# ============================================================
# CielDots — Gentoo Linux Hyprland (Lua) Dotfiles Installer
# Theme: Rimuru Tempest | Font: JetBrainsMono Nerd Font
# Hyprland Config: ~/.config/hypr/hyprland.lua (v0.55+)
# ============================================================

set -euo pipefail

R='\033[38;2;243;139;168m'   # red     #f38ba8
G='\033[38;2;166;227;161m'   # green   #a6e3a1
Y='\033[38;2;249;226;175m'   # yellow  #f9e2af
B='\033[38;2;137;180;250m'   # blue    #89b4fa
M='\033[38;2;203;166;247m'   # mauve   #cba6f7
S='\033[38;2;166;173;200m'   # subtext #a6adc8
T='\033[38;2;205;214;244m'   # text    #cdd6f4
NC='\033[0m'

LOG_DIR="$HOME/.cache"
LOG_FILE="$LOG_DIR/cieldots-install.log"
mkdir -p "$LOG_DIR"

_log()  { local lvl="$1"; shift; echo "[$(date '+%H:%M:%S')] [$lvl] $*" >> "$LOG_FILE"; }
info()  { echo -e "${B}[INFO]${NC}  $*"; _log INFO  "$*"; }
ok()    { echo -e "${G}[ OK ]${NC}  $*"; _log OK    "$*"; }
warn()  { echo -e "${Y}[WARN]${NC}  $*"; _log WARN  "$*"; }
err()   { echo -e "${R}[ERR ]${NC}  $*"; _log ERROR "$*"; }
die()   { err "$*"; exit 1; }
step()  { echo -e "\n${M}══${NC} ${T}$*${NC}"; _log STEP "$*"; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-cieldots/$(date '+%Y%m%d_%H%M%S')"
SNAPSHOT_FILE="$LOG_DIR/cieldots-install-snapshot.json"
FAILED_PKGS=()
INSTALLED_PKGS=()
TOTAL_STEPS=10
CURRENT_STEP=0

progress() {
    CURRENT_STEP=$(( CURRENT_STEP + 1 ))
    local pct=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    local filled=$(( pct / 5 ))
    local empty=$(( 20 - filled ))
    local bar
    bar="${M}$(printf '█%.0s' $(seq 1 $filled))${S}$(printf '░%.0s' $(seq 1 $empty))${NC}"
    printf "\r  [%s] ${T}%3d%%${NC} %s\n" "$bar" "$pct" "$1"
}

print_banner() {
    echo -e "${M}"
    cat << 'EOF'
   ██████╗██╗███████╗██╗     ██████╗  ██████╗ ████████╗███████╗
  ██╔════╝██║██╔════╝██║     ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝
  ██║     ██║█████╗  ██║     ██║  ██║██║   ██║   ██║   ███████╗
  ██║     ██║██╔══╝  ██║     ██║  ██║██║   ██║   ██║   ╚════██║
  ╚██████╗██║███████╗███████╗██████╔╝╚██████╔╝   ██║   ███████║
   ╚═════╝╚═╝╚══════╝╚══════╝╚═════╝  ╚═════╝    ╚═╝   ╚══════╝
EOF
    echo -e "${NC}"
    echo -e "  ${S}Gentoo Linux · Hyprland Lua · Tempest${NC}"
    echo -e "  ${S}Log: ${T}$LOG_FILE${NC}"
    echo ""
}

check_gentoo() {
    [[ -f /etc/gentoo-release ]] || die "This installer requires Gentoo Linux (missing /etc/gentoo-release)"
    info "Detected: $(cat /etc/gentoo-release)"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "Running as root is strongly discouraged!"
        read -rp "Continue anyway? [y/N] " choice
        [[ "${choice,,}" == "y" ]] || die "Aborted by user"
    fi
}

check_deps() {
    local missing=()
    for cmd in emerge eselect git curl; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Missing required commands: ${missing[*]}"
        die "Install missing tools first: sudo emerge --ask ${missing[*]}"
    fi
    ok "Prerequisites satisfied"
}

check_disk() {
    local avail_gb
    avail_gb=$(df --output=avail -BG / | tail -n1 | tr -d 'G ')
    if [[ $avail_gb -lt 10 ]]; then
        warn "Only ${avail_gb}GB available on /, recommended ≥10GB for compilation"
        read -rp "Continue anyway? [y/N] " choice
        [[ "${choice,,}" == "y" ]] || die "Aborted due to low disk space"
    fi
}

check_groups_and_seat() {
    step "Checking User Groups & Seat Manager"
    local user_groups
    user_groups=$(groups)

    for grp in video input; do
        if ! echo "$user_groups" | grep -qw "$grp"; then
            warn "User '$USER' is not in the '$grp' group (required for Wayland/Hyprland input & DRM)"
            info "Run: sudo usermod -aG $grp $USER"
        else
            ok "User in '$grp' group"
        fi
    done

    # Check elogind / seatd / systemd-logind
    if command -v loginctl &>/dev/null; then
        ok "Seat manager (loginctl) detected"
    elif [[ -e /run/seatd.sock ]] || command -v seatd &>/dev/null; then
        ok "Seat manager (seatd) detected"
        if ! echo "$user_groups" | grep -qw "seat"; then
            warn "For seatd, user '$USER' should be in the 'seat' group"
            info "Run: sudo usermod -aG seat $USER"
        fi
    else
        warn "No active seat manager (elogind/seatd) detected. Hyprland needs elogind or seatd to access DRM devices."
    fi
}

declare -a SNAPSHOT_ENTRIES=()

snapshot_file() {
    local dst="$1"
    local bak="${BACKUP_DIR}${dst}"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        mkdir -p "$(dirname "$bak")"
        cp -a "$dst" "$bak"
        SNAPSHOT_ENTRIES+=("{\"path\":\"$dst\",\"backup\":\"$bak\"}")
    fi
    write_snapshot
}

write_snapshot() {
    local json="["
    local first=true
    for entry in "${SNAPSHOT_ENTRIES[@]}"; do
        $first && first=false || json+=","
        json+="$entry"
    done
    json+="]"
    echo "$json" > "$SNAPSHOT_FILE"
}

rollback() {
    warn "Rolling back changes..."
    [[ -f "$SNAPSHOT_FILE" ]] || { warn "No snapshot found, cannot rollback"; return; }
    if command -v python3 &>/dev/null; then
        python3 - "$SNAPSHOT_FILE" << 'PYEOF'
import json, shutil, sys, os
try:
    with open(sys.argv[1]) as f:
        entries = json.load(f)
    for e in entries:
        try:
            if os.path.exists(e["backup"]):
                shutil.copy2(e["backup"], e["path"])
                print(f"  restored: {e['path']}")
        except Exception as ex:
            print(f"  FAILED:   {e['path']} — {ex}")
except Exception as ex:
    print(f"Rollback error: {ex}")
PYEOF
    fi
    ok "Rollback complete"
}

INSTALL_SUCCESS=0
trap_exit() {
    local code=$?
    if [[ $code -ne 0 && $INSTALL_SUCCESS -eq 0 ]]; then
        err "Installer exited unexpectedly with code $code"
        read -rp "Would you like to rollback file changes? [Y/n] " rb_choice
        if [[ "${rb_choice,,}" != "n" ]]; then
            rollback
        fi
    fi
}
trap trap_exit EXIT
trap 'echo ""; warn "Interrupted by user"; exit 130' INT TERM

# ── Portage USE Flags ─────────────────────────────────────────
setup_use_flags() {
    step "Configuring Portage USE flags"
    local use_base="/etc/portage/package.use"
    local target_file=""

    local use_content
    use_content=$(cat << 'USEEOF'
# ============================================================
# CielDots USE flags — auto-generated by CielDots installer
# ============================================================

# Hyprland stack (v0.55+ with Lua support)
gui-wm/hyprland             aquamarine drm gles2
gui-libs/aquamarine         drm gles2
dev-libs/wayland            scanner

# Mesa — Wayland + Vulkan acceleration
media-libs/mesa             wayland vulkan xa

# Waybar
gui-apps/waybar             experimental tray network pipewire upower

# PipeWire audio stack
media-video/pipewire        alsa bluetooth dbus gstreamer pipewire-alsa screencast sound-server

# Kitty terminal
x11-terms/kitty             wayland

# GTK / theming
x11-libs/gtk+:3             wayland
x11-libs/gtk+:4             wayland

# XDG portals
sys-apps/xdg-desktop-portal geoclue screencast

# swww & waypaper wallpaper daemons
gui-apps/swww               wayland
gui-apps/waypaper           wayland

# Notification daemon (mako)
gui-apps/mako               dbus wayland

# Qt (for apps that need it)
dev-qt/qtbase:6             wayland

# Fonts
media-fonts/noto            extra cjk
media-fonts/nerdfonts       jetbrainsmono
USEEOF
)

    if [[ -d "$use_base" ]]; then
        target_file="$use_base/cieldots"
        [[ -f "$target_file" ]] && snapshot_file "$target_file"
        echo "$use_content" | sudo tee "$target_file" > /dev/null
        ok "USE flags written to $target_file"
    elif [[ -f "$use_base" ]]; then
        snapshot_file "$use_base"
        if grep -q "# CielDots USE flags" "$use_base" 2>/dev/null; then
            info "CielDots section already exists in $use_base (updating)"
            # Replace existing block
            sudo sed -i '/# CielDots USE flags/,/# End CielDots USE flags/d' "$use_base"
        fi
        {
            echo "$use_content"
            echo "# End CielDots USE flags"
        } | sudo tee -a "$use_base" > /dev/null
        ok "USE flags appended to $use_base"
    else
        # Neither exists yet: create as directory
        sudo mkdir -p "$use_base"
        target_file="$use_base/cieldots"
        echo "$use_content" | sudo tee "$target_file" > /dev/null
        ok "Created $use_base directory and written to $target_file"
    fi
}

# ── Portage Keywords (~amd64) ─────────────────────────────────
setup_keywords() {
    step "Configuring Portage Keywords (~amd64)"
    local kw_base="/etc/portage/package.accept_keywords"
    local target_file=""

    local kw_content
    kw_content=$(cat << 'KWEOF'
# ============================================================
# CielDots ~amd64 keywords — auto-generated by CielDots installer
# ============================================================

# Hyprland and its full ecosystem
gui-wm/hyprland                     ~amd64
gui-libs/aquamarine                 ~amd64
gui-libs/hyprlang                   ~amd64
gui-libs/hyprutils                  ~amd64
gui-libs/hyprwayland-scanner         ~amd64
gui-libs/xdg-desktop-portal-hyprland ~amd64
gui-apps/hyprlock                   ~amd64
gui-apps/hypridle                   ~amd64
gui-apps/hyprpicker                 ~amd64

# Wallpaper
gui-apps/swww                       ~amd64
gui-apps/waypaper                   ~amd64

# Waybar & Launcher
gui-apps/waybar                     ~amd64
gui-apps/wofi                       ~amd64

# Notifications
gui-apps/mako                       ~amd64

# Screenshot & Clipboard
media-gfx/grim                      ~amd64
gui-apps/slurp                      ~amd64
gui-apps/swappy                     ~amd64
gui-apps/wl-clipboard               ~amd64
gui-apps/cliphist                   ~amd64

# Fonts
media-fonts/nerdfonts               ~amd64

# Misc tools from GURU / ~amd64
app-shells/starship                 ~amd64
app-misc/eza                        ~amd64
app-misc/bat                        ~amd64
app-misc/fastfetch                  ~amd64
app-shells/zsh-history-substring-search ~amd64
KWEOF
)

    if [[ -d "$kw_base" ]]; then
        target_file="$kw_base/cieldots"
        [[ -f "$target_file" ]] && snapshot_file "$target_file"
        echo "$kw_content" | sudo tee "$target_file" > /dev/null
        ok "Keywords written to $target_file"
    elif [[ -f "$kw_base" ]]; then
        snapshot_file "$kw_base"
        if grep -q "# CielDots ~amd64 keywords" "$kw_base" 2>/dev/null; then
            sudo sed -i '/# CielDots ~amd64 keywords/,/# End CielDots keywords/d' "$kw_base"
        fi
        {
            echo "$kw_content"
            echo "# End CielDots keywords"
        } | sudo tee -a "$kw_base" > /dev/null
        ok "Keywords appended to $kw_base"
    else
        sudo mkdir -p "$kw_base"
        target_file="$kw_base/cieldots"
        echo "$kw_content" | sudo tee "$target_file" > /dev/null
        ok "Created $kw_base directory and written to $target_file"
    fi
}

setup_overlays() {
    step "Setting up Portage Overlays (GURU)"

    if ! eselect repository list &>/dev/null 2>&1; then
        info "Installing app-eselect/eselect-repository..."
        sudo emerge --ask --noreplace app-eselect/eselect-repository || \
            die "Failed to install eselect-repository"
    fi

    if ! eselect repository list | grep -q "^guru "; then
        info "Adding GURU overlay..."
        sudo eselect repository enable guru
    else
        info "GURU overlay is already enabled"
    fi

    info "Syncing GURU overlay..."
    sudo emaint sync -r guru 2>&1 | tail -5
    ok "Overlays ready"
}

emerge_pkg() {
    local pkg="$1"
    info "  [Portage] Checking & installing $pkg..."
    if sudo emerge --ask=n --noreplace --autounmask-write=y --autounmask-continue=y "$pkg" >> "$LOG_FILE" 2>&1; then
        INSTALLED_PKGS+=("$pkg")
        ok "    Installed $pkg"
        return 0
    else
        warn "    FAILED: $pkg (see $LOG_FILE)"
        FAILED_PKGS+=("$pkg")
        return 1
    fi
}

install_packages() {
    step "Installing packages via Portage"
    info "Gentoo compiles from source. This step may take some time."
    echo ""

    info "── Core Hyprland & Lua Stack"
    emerge_pkg "dev-lang/lua"
    emerge_pkg "gui-wm/hyprland"
    emerge_pkg "gui-apps/hyprlock"
    emerge_pkg "gui-apps/hypridle"
    emerge_pkg "gui-apps/hyprpicker"
    emerge_pkg "gui-libs/xdg-desktop-portal-hyprland"

    info "── Wayland Essentials"
    emerge_pkg "sys-apps/xdg-desktop-portal"
    emerge_pkg "sys-apps/xdg-user-dirs"
    emerge_pkg "dev-libs/wayland"
    emerge_pkg "dev-libs/wayland-protocols"

    info "── Bar & Launcher"
    emerge_pkg "gui-apps/waybar"
    emerge_pkg "gui-apps/wofi"

    info "── Terminal & Shell"
    emerge_pkg "x11-terms/kitty"
    emerge_pkg "app-shells/zsh"
    emerge_pkg "app-shells/starship"
    emerge_pkg "app-shells/zsh-syntax-highlighting"
    emerge_pkg "app-shells/zsh-autosuggestions"

    info "── Notifications"
    emerge_pkg "gui-apps/mako"

    info "── Wallpaper Tools"
    emerge_pkg "gui-apps/swww"
    emerge_pkg "gui-apps/waypaper"

    info "── Screenshot & Clipboard Tools"
    emerge_pkg "media-gfx/grim"
    emerge_pkg "gui-apps/slurp"
    emerge_pkg "gui-apps/swappy"
    emerge_pkg "gui-apps/wl-clipboard"
    emerge_pkg "gui-apps/cliphist"

    info "── Audio"
    emerge_pkg "media-video/pipewire"
    emerge_pkg "media-sound/wireplumber"
    emerge_pkg "media-sound/pavucontrol"

    info "── Bluetooth & Network Applets"
    emerge_pkg "net-wireless/bluez"
    emerge_pkg "net-wireless/blueman"
    emerge_pkg "net-misc/networkmanager"
    emerge_pkg "gnome-extra/nm-applet"
    emerge_pkg "net-libs/libnm"

    info "── Brightness & File Manager"
    emerge_pkg "sys-power/brightnessctl"
    emerge_pkg "xfce-base/thunar"
    emerge_pkg "xfce-extra/thunar-archive-plugin"
    emerge_pkg "gnome-base/gvfs"

    info "── Fonts"
    emerge_pkg "media-fonts/nerdfonts" || emerge_pkg "media-fonts/nerd-fonts" || true
    emerge_pkg "media-fonts/noto"
    emerge_pkg "media-fonts/noto-emoji"

    info "── GTK & Qt Theming"
    emerge_pkg "x11-themes/papirus-icon-theme"
    emerge_pkg "x11-misc/qt5ct"
    emerge_pkg "x11-misc/qt6ct"
    emerge_pkg "gnome-extra/polkit-gnome"
    emerge_pkg "x11-themes/bibata-cursor-theme" || true

    info "── CLI & Python Utilities"
    emerge_pkg "app-misc/eza"
    emerge_pkg "app-misc/bat"
    emerge_pkg "sys-apps/ripgrep"
    emerge_pkg "sys-apps/fd"
    emerge_pkg "app-shells/fzf"
    emerge_pkg "app-misc/jq"
    emerge_pkg "net-misc/curl"
    emerge_pkg "dev-python/requests"
    emerge_pkg "dev-python/pillow"
    emerge_pkg "app-misc/lm-sensors"
    emerge_pkg "app-misc/fastfetch"
    emerge_pkg "app-shells/zsh-history-substring-search"
    emerge_pkg "sys-power/cpupower" || true
}

# ── Catppuccin GTK theme ─────────────────────────────────────
install_catppuccin_gtk() {
    step "Installing Catppuccin GTK Theme"
    local theme_dir="$HOME/.local/share/themes"
    local repo_url="https://github.com/catppuccin/gtk"
    local tmp_dir
    tmp_dir="$(mktemp -d)"

    if [[ -d "$theme_dir/Catppuccin-Mocha-Standard-Mauve-Dark" ]]; then
        info "Catppuccin GTK theme already installed, skipping"
        rm -rf "$tmp_dir"
        return
    fi

    mkdir -p "$theme_dir"
    if command -v python3 &>/dev/null && python3 -c "import pygobject" 2>/dev/null; then
        git clone --depth=1 "$repo_url" "$tmp_dir/catppuccin-gtk" 2>/dev/null && \
            python3 "$tmp_dir/catppuccin-gtk/install.py" \
                mocha --accent mauve --dest "$theme_dir" --name Catppuccin-Mocha && \
            ok "Catppuccin GTK theme installed" || \
            warn "Catppuccin GTK install failed — you may install manually from $repo_url"
    else
        local rel_url="https://github.com/catppuccin/gtk/releases/latest/download/Catppuccin-Mocha-Standard-Mauve-Dark.zip"
        curl -sL "$rel_url" -o "$tmp_dir/catppuccin-gtk.zip" && \
            unzip -q "$tmp_dir/catppuccin-gtk.zip" -d "$theme_dir" 2>/dev/null && \
            ok "Catppuccin GTK theme installed (pre-built archive)" || \
            warn "Catppuccin GTK download failed — can be installed manually from $repo_url"
    fi
    rm -rf "$tmp_dir"
}

# ── Symlinks ─────────────────────────────────────────────────
do_symlink() {
    local rel="$1"
    local src="$DOTFILES_DIR/$rel"
    local dst="$HOME/$rel"
    local dir
    dir="$(dirname "$dst")"

    [[ -f "$src" || -d "$src" ]] || { warn "Source missing: $src — skipping"; return; }

    mkdir -p "$dir"
    snapshot_file "$dst"

    if [[ -e "$dst" && ! -L "$dst" ]]; then
        local bak="${BACKUP_DIR}${dst}"
        mkdir -p "$(dirname "$bak")"
        mv "$dst" "$bak"
        warn "Backing up existing $(basename "$dst") → $bak"
    fi

    ln -sfn "$src" "$dst"
    ok "  $rel"
}

install_symlinks() {
    step "Symlinking config files & scripts"

    # Hyprland configs (both modern Lua and legacy conf)
    do_symlink ".config/hypr/hyprland.lua"
    do_symlink ".config/hypr/hyprland.conf"
    do_symlink ".config/hypr/hyprlock.conf"
    do_symlink ".config/hypr/hypridle.conf"

    # Waybar & UI
    do_symlink ".config/waybar/config.jsonc"
    do_symlink ".config/waybar/style.css"
    do_symlink ".config/waybar/dynamic-colors.css"
    do_symlink ".config/kitty/kitty.conf"
    do_symlink ".config/kitty/themes/rimuru.conf"
    do_symlink ".config/kitty/themes/dynamic.conf"
    do_symlink ".config/mako/config"
    do_symlink ".config/wofi/config"
    do_symlink ".config/wofi/style.css"

    # Shell & Theming
    do_symlink ".config/zsh/.zshrc"
    do_symlink ".config/starship/starship.toml"
    do_symlink ".config/gtk-3.0/settings.ini"
    do_symlink ".config/gtk-4.0/settings.ini"
    do_symlink ".config/fastfetch/config.jsonc"
    do_symlink ".config/fastfetch/rimuru.txt"

    # Link ALL scripts (*.sh and *.py) to ~/.config/hypr/scripts/ and ~/.local/bin/
    info "Linking scripts (*.sh and *.py)..."
    mkdir -p "$HOME/.config/hypr/scripts"
    mkdir -p "$HOME/.local/bin"

    for script in "$DOTFILES_DIR/scripts/"*.*; do
        [[ -f "$script" ]] || continue
        local fname
        fname="$(basename "$script")"
        local stem="${fname%.*}"

        chmod +x "$script"
        ln -sfn "$script" "$HOME/.config/hypr/scripts/$fname"
        ln -sfn "$script" "$HOME/.local/bin/$stem"
        ok "  scripts/$fname → ~/.config/hypr/scripts/$fname & ~/.local/bin/$stem"
    done
}

# ── Update .zshrc aliases for Gentoo ─────────────────────────
patch_zshrc_for_gentoo() {
    local zshrc="$DOTFILES_DIR/.config/zsh/.zshrc"
    if grep -q "emerge" "$zshrc" 2>/dev/null; then
        return
    fi

    cat >> "$zshrc" << 'ZSHEOF'

# ── Gentoo / Portage aliases (auto-added by CielDots) ──
alias pkgi='sudo emerge --ask'
alias pkgr='sudo emerge --ask --depclean'
alias pkgs='emerge --search'
alias pkgu='sudo emerge --ask --update --deep --newuse @world'
alias pkgc='sudo emerge --ask --depclean && sudo revdep-rebuild'
alias pkgl='qlist -Iv'
alias emerge='sudo emerge'
ZSHEOF

    ok "Gentoo Portage aliases added to .zshrc"
}

# ── Shell setup ──────────────────────────────────────────────
setup_shell() {
    step "Configuring Shell"

    if command -v zsh &>/dev/null; then
        if [[ "$SHELL" != "$(command -v zsh)" ]]; then
            info "Changing default shell to zsh..."
            chsh -s "$(command -v zsh)" "$USER" 2>/dev/null || warn "Could not auto-change shell with chsh. Run: chsh -s $(command -v zsh)"
        else
            info "zsh is already the default shell"
        fi
    fi

    local zshenv="/etc/zsh/zshenv"
    if [[ -d "/etc/zsh" ]]; then
        if [[ ! -f "$zshenv" ]] || ! grep -q "ZDOTDIR" "$zshenv" 2>/dev/null; then
            info "Setting ZDOTDIR=$HOME/.config/zsh in $zshenv"
            echo 'export ZDOTDIR="$HOME/.config/zsh"' | sudo tee -a "$zshenv" > /dev/null
            ok "ZDOTDIR configured in $zshenv"
        fi
    fi
}

# ── System services ──────────────────────────────────────────
enable_services() {
    step "Configuring System Services"

    local services=("bluetooth" "dbus")
    if command -v rc-update &>/dev/null; then
        info "Configuring OpenRC services..."
        for svc in "${services[@]}"; do
            sudo rc-update add "$svc" default 2>/dev/null && \
                ok "  OpenRC: $svc enabled" || \
                warn "  OpenRC: $svc not found (skipping)"
        done
        # Check if NetworkManager or another network service is used
        if rc-service NetworkManager status &>/dev/null || [[ -f /etc/init.d/NetworkManager ]]; then
            sudo rc-update add NetworkManager default 2>/dev/null && ok "  OpenRC: NetworkManager enabled" || true
        fi
    elif command -v systemctl &>/dev/null; then
        info "Configuring systemd services..."
        for svc in "${services[@]}" "NetworkManager"; do
            sudo systemctl enable --now "${svc}.service" 2>/dev/null && \
                ok "  systemd: $svc enabled" || \
                warn "  systemd: $svc not found (skipping)"
        done
    fi

    if command -v sensors-detect &>/dev/null; then
        info "Running sensors-detect (non-interactive)..."
        sudo sensors-detect --auto >> "$LOG_FILE" 2>&1 || true
    fi
}

# ── XDG dirs & wallpaper dir ─────────────────────────────────
setup_dirs() {
    step "Creating required directories"
    mkdir -p "$HOME/Pictures/Wallpapers"
    mkdir -p "$HOME/Pictures/Screenshots"
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.local/share/themes"
    mkdir -p "$HOME/.local/share/icons"
    mkdir -p "$HOME/.config/hypr/scripts"
    xdg-user-dirs-update 2>/dev/null || true
    ok "Directories ready"
}

# ── Hyprland display manager entry ───────────────────────────
setup_hyprland_entry() {
    local entry_dir="/usr/share/wayland-sessions"
    local entry_file="$entry_dir/hyprland.desktop"
    if [[ ! -f "$entry_file" ]]; then
        info "Creating Hyprland Wayland session entry..."
        sudo mkdir -p "$entry_dir"
        sudo tee "$entry_file" > /dev/null << 'DEOF'
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
DEOF
        ok "Hyprland session entry created at $entry_file"
    fi
}

# ── Summary ──────────────────────────────────────────────────
print_summary() {
    INSTALL_SUCCESS=1
    echo ""
    echo -e "${M}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${M}║        CielDots Installation Complete! 🎉        ║${NC}"
    echo -e "${M}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${G}Installed packages:${NC} ${#INSTALLED_PKGS[@]}"
    if [[ ${#FAILED_PKGS[@]} -gt 0 ]]; then
        echo -e "  ${R}Failed packages:${NC}   ${#FAILED_PKGS[@]}"
        for pkg in "${FAILED_PKGS[@]}"; do
            echo -e "    ${R}✗${NC} $pkg"
        done
        echo -e "  ${Y}Tip:${NC} Inspect $LOG_FILE or run ${T}sudo emerge --ask ${FAILED_PKGS[*]}${NC} manually"
    fi

    echo ""
    echo -e "  ${B}Log file:${NC}       ${T}$LOG_FILE${NC}"
    echo -e "  ${B}Backup:${NC}         ${T}$BACKUP_DIR${NC}"
    echo -e "  ${B}Rollback:${NC}       ${T}$0 --rollback${NC}"
    echo -e "  ${B}Lua Config:${NC}     ${T}~/.config/hypr/hyprland.lua${NC}"
    echo ""
    echo -e "  ${M}Next steps:${NC}"
    echo -e "  ${S}1.${NC} Add wallpapers to ${T}~/Pictures/Wallpapers/${NC}"
    echo -e "  ${S}2.${NC} Launch Hyprland via display manager or running ${T}Hyprland${NC}"
    echo -e "  ${S}3.${NC} Press ${T}Super + Return${NC} to open Kitty terminal"
    echo -e "  ${S}4.${NC} Press ${T}Super + Space${NC} to open Wofi launcher"
    echo -e "  ${S}5.${NC} Press ${T}Super + Shift + G${NC} to toggle gaming mode"
    echo ""
}

# ── Rollback & Uninstall modes ────────────────────────────────
if [[ "${1:-}" == "--rollback" ]]; then
    rollback
    exit 0
fi

if [[ "${1:-}" == "--uninstall" || "${1:-}" == "-u" ]]; then
    if [[ -f "$DOTFILES_DIR/uninstall.sh" ]]; then
        exec bash "$DOTFILES_DIR/uninstall.sh"
    fi
fi

# ── Main entry point ─────────────────────────────────────────
main() {
    print_banner
    echo -e "  ${T}Installing CielDots Hyprland (Lua) for Gentoo Linux...${NC}"
    echo -e "  ${S}Started: $(date '+%A, %d %B %Y %H:%M:%S')${NC}"
    echo ""

    progress "Checking system requirements"
    check_gentoo
    check_root
    check_deps
    check_disk

    progress "Checking user groups & seat management"
    check_groups_and_seat

    progress "Setting up Portage overlays (GURU)"
    setup_overlays

    progress "Configuring USE flags & keywords"
    setup_use_flags
    setup_keywords

    progress "Installing packages via Portage"
    install_packages

    progress "Installing Catppuccin GTK theme"
    install_catppuccin_gtk

    progress "Creating directories"
    setup_dirs

    progress "Symlinking config files (Lua + legacy)"
    install_symlinks

    progress "Configuring shell (zsh)"
    patch_zshrc_for_gentoo
    setup_shell

    progress "Enabling system services"
    enable_services
    setup_hyprland_entry

    progress "Done!"
    print_summary
}

main "$@"
