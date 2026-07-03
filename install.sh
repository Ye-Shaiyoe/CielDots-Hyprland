#!/bin/bash
# ============================================================
# Dotfiles Install Script - Arch Linux + Hyprland
# Catppuccin Mocha | JetBrainsMono Nerd Font
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAUVE='\033[0;35m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${MAUVE}"
echo "  ███╗   ██╗██╗███╗   ███╗███████╗    ██████╗  ██████╗ ████████╗███████╗"
echo "  ████╗  ██║██║████╗ ████║██╔════╝    ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝"
echo "  ██╔██╗ ██║██║██╔████╔██║█████╗      ██║  ██║██║   ██║   ██║   ███████╗"
echo "  ██║╚██╗██║██║██║╚██╔╝██║██╔══╝      ██║  ██║██║   ██║   ██║   ╚════██║"
echo "  ██║ ╚████║██║██║ ╚═╝ ██║███████╗    ██████╔╝╚██████╔╝   ██║   ███████║"
echo "  ╚═╝  ╚═══╝╚═╝╚═╝     ╚═╝╚══════╝    ╚═════╝  ╚═════╝    ╚═╝   ╚══════╝"
echo -e "${NC}"
echo "  Arch Linux · Hyprland · Catppuccin Mocha"
echo ""

# ---- 1. Install packages ----
info "Installing packages via paru..."

PKGS=(
    # Core Hyprland
    hyprland hyprlock hypridle hyprpicker
    # Bars & launchers
    waybar wofi
    # Terminal
    kitty zsh starship
    # Notification
    mako
    # Wallpaper
    swww
    # File manager
    thunar thunar-archive-plugin gvfs
    # Fonts
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji
    # Screenshot
    grimblast-git grim slurp
    # Audio
    pipewire wireplumber pipewire-pulse pavucontrol
    # Bluetooth
    bluez bluez-utils blueman
    # Network
    networkmanager network-manager-applet nm-connection-editor
    # Brightness
    brightnessctl
    # GTK Theme
    catppuccin-gtk-theme-mocha papirus-icon-theme
    # Cursor
    catppuccin-cursors-mocha
    # Misc
    polkit-gnome xdg-desktop-portal-hyprland xdg-user-dirs
    qt5ct qt6ct
    # Zsh plugins
    zsh-autosuggestions zsh-syntax-highlighting
    # Nice CLI tools
    eza bat ripgrep fd fzf
    # Logout
    wlogout
)

if command -v paru &>/dev/null; then
    paru -S --needed --noconfirm "${PKGS[@]}"
elif command -v yay &>/dev/null; then
    yay -S --needed --noconfirm "${PKGS[@]}"
else
    warn "AUR helper not found. Installing packages via pacman (some may be missing)..."
    sudo pacman -S --needed --noconfirm "${PKGS[@]}" 2>/dev/null || true
fi

success "Packages installed"

# ---- 2. Create config directories ----
info "Creating config directories..."
mkdir -p ~/.config/{hypr,waybar,kitty,mako,wofi,zsh,starship,gtk-3.0,gtk-4.0}
mkdir -p ~/.local/share/fonts
mkdir -p ~/Pictures/Wallpapers
success "Directories created"

# ---- 3. Symlink configs ----
info "Symlinking config files..."

symlink() {
    local src="$DOTFILES_DIR/$1"
    local dst="$HOME/$1"
    local dir
    dir="$(dirname "$dst")"

    mkdir -p "$dir"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        warn "Backing up existing $dst to $dst.bak"
        mv "$dst" "$dst.bak"
    fi

    ln -sfn "$src" "$dst"
    success "Linked $1"
}

symlink ".config/hypr/hyprland.conf"
symlink ".config/hypr/hyprlock.conf"
symlink ".config/waybar/config.jsonc"
symlink ".config/waybar/style.css"
symlink ".config/kitty/kitty.conf"
symlink ".config/mako/config"
symlink ".config/wofi/config"
symlink ".config/wofi/style.css"
symlink ".config/zsh/.zshrc"
symlink ".config/starship/starship.toml"
symlink ".config/gtk-3.0/settings.ini"
symlink ".config/gtk-4.0/settings.ini"
symlink ".config/hypr/hypridle.conf"

# ---- Scripts ----
info "Installing scripts..."
mkdir -p ~/.config/hypr/scripts
for script in "$DOTFILES_DIR/scripts/"*.sh; do
    name="$(basename "$script")"
    ln -sfn "$script" "$HOME/.config/hypr/scripts/$name"
    chmod +x "$script"
    success "Linked scripts/$name"
done

# ---- 4. Set default shell to zsh ----
if [ "$SHELL" != "$(which zsh)" ]; then
    info "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
    success "Shell changed to zsh"
fi

# ---- 5. Set ZDOTDIR ----
info "Setting ZDOTDIR for zsh..."
if ! grep -q "ZDOTDIR" /etc/zsh/zshenv 2>/dev/null; then
    echo 'export ZDOTDIR="$HOME/.config/zsh"' | sudo tee -a /etc/zsh/zshenv
fi
success "ZDOTDIR configured"

# ---- 6. Enable services ----
info "Enabling system services..."
sudo systemctl enable --now bluetooth.service 2>/dev/null && success "Bluetooth enabled" || warn "Bluetooth service not found"
sudo systemctl enable --now NetworkManager.service 2>/dev/null && success "NetworkManager enabled" || warn "NetworkManager not found"

# ---- 7. Setup XDG user dirs ----
xdg-user-dirs-update
success "XDG user dirs updated"

# ---- Done ----
echo ""
echo -e "${MAUVE}╔═══════════════════════════════════════╗${NC}"
echo -e "${MAUVE}║      Installation Complete! 🎉        ║${NC}"
echo -e "${MAUVE}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Next steps:${NC}"
echo -e "  1. Add a wallpaper to ${YELLOW}~/.config/hypr/wallpaper.jpg${NC}"
echo -e "     or copy one to ${YELLOW}~/Pictures/Wallpapers/${NC}"
echo -e "  2. Log out and select ${YELLOW}Hyprland${NC} in your display manager"
echo -e "  3. Press ${YELLOW}Super + Return${NC} to open Kitty terminal"
echo -e "  4. Press ${YELLOW}Super + Space${NC} to open Wofi launcher"
echo ""
echo -e "  ${BLUE}Keybindings:${NC}"
echo -e "  Super + Return    → Terminal (Kitty)"
echo -e "  Super + Space     → App Launcher (Wofi)"
echo -e "  Super + E         → File Manager (Thunar)"
echo -e "  Super + Q         → Close window"
echo -e "  Super + L         → Lock screen (Hyprlock)"
echo -e "  Super + 1-5       → Switch workspace"
echo -e "  Super + Shift+1-5 → Move window to workspace"
echo -e "  Print             → Screenshot (area)"
echo ""
