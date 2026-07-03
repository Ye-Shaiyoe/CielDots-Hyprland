# nime-dots

> Arch Linux · Hyprland · Catppuccin Mocha

![Hyprland](https://img.shields.io/badge/WM-Hyprland-cba6f7?style=flat-square&logo=linux)
![Theme](https://img.shields.io/badge/Theme-Catppuccin%20Mocha-1e1e2e?style=flat-square)
![Font](https://img.shields.io/badge/Font-JetBrainsMono%20NF-89b4fa?style=flat-square)

## Stack

| Role | App |
|------|-----|
| Window Manager | Hyprland |
| Bar | Waybar |
| Terminal | Kitty |
| Shell | Zsh + Starship |
| Launcher | Wofi |
| Notifications | Mako |
| Wallpaper | SWWW |
| Lock Screen | Hyprlock |
| File Manager | Thunar |
| Color Scheme | Catppuccin Mocha |
| Font | JetBrainsMono Nerd Font |

## Install

```bash
git clone https://github.com/yourusername/nime-dots ~/.dotfiles
cd ~/.dotfiles
chmod +x install.sh
./install.sh
```

> **Requires:** `paru` or `yay` AUR helper

## Keybindings

| Key | Action |
|-----|--------|
| `Super + Return` | Terminal |
| `Super + Space` | App Launcher |
| `Super + E` | File Manager |
| `Super + B` | Browser |
| `Super + Q` | Close Window |
| `Super + F` | Fullscreen |
| `Super + V` | Toggle Float |
| `Super + L` | Lock Screen |
| `Super + R` | Resize Mode |
| `Super + 1-0` | Switch Workspace |
| `Super + Shift + 1-0` | Move to Workspace |
| `Print` | Screenshot (area) |
| `Super + Print` | Screenshot (full) |
| `Super + H/J/K/L` | Move Focus |

## Structure

```
~/.config/
├── hypr/
│   ├── hyprland.conf   # Main config
│   └── hyprlock.conf   # Lock screen
├── waybar/
│   ├── config.jsonc    # Bar modules
│   └── style.css       # Catppuccin styling
├── kitty/
│   └── kitty.conf      # Terminal + colors
├── mako/
│   └── config          # Notifications
├── wofi/
│   ├── config
│   └── style.css       # Launcher styling
├── zsh/
│   └── .zshrc          # Shell config
├── starship/
│   └── starship.toml   # Prompt
└── gtk-3.0/ gtk-4.0/
    └── settings.ini    # GTK theming
```

## Scripts

Scripts berada di `~/.config/hypr/scripts/` (symlink dari `scripts/`).

### wallpaper.sh
```bash
wallpaper.sh                  # random dari ~/Pictures/Wallpapers
wallpaper.sh /path/img.jpg    # set spesifik
wallpaper.sh --next           # next wallpaper
wallpaper.sh --prev           # previous wallpaper
wallpaper.sh --slideshow      # slideshow (default interval 5 menit)
wallpaper.sh --current        # lihat wallpaper sekarang

# Env vars
WALLPAPER_DIR=~/Pictures/Wallpapers
WALLPAPER_TRANSITION=wipe      # fade|wipe|slide|grow|center|random
WALLPAPER_INTERVAL=300         # detik untuk slideshow
```

### gaming-mode.sh
```bash
gaming-mode.sh          # toggle on/off
gaming-mode.sh on       # aktifkan
gaming-mode.sh off      # nonaktifkan
gaming-mode.sh status   # cek status
```
Efek: matiin Waybar, gaps=0, animasi off, CPU governor → performance, DnD notif.

### screenshot.sh
```bash
screenshot.sh area      # pilih area (default)
screenshot.sh full      # fullscreen
screenshot.sh window    # window aktif
screenshot.sh monitor   # monitor aktif
screenshot.sh area --edit   # capture + buka di swappy
```

### Keybindings
| Key | Action |
|-----|--------|
| `Print` | Screenshot area |
| `Super + Print` | Screenshot full |
| `Shift + Print` | Screenshot window |
| `Ctrl + Print` | Screenshot area + edit |
| `Super + Shift + W` | Random wallpaper |
| `Super + Ctrl + W` | Next wallpaper |
| `Super + Shift + G` | Toggle gaming mode |

## Wallpaper

Taruh wallpaper di `~/Pictures/Wallpapers/`. Startup script otomatis random.

```bash
# Ganti wallpaper manual
~/.config/hypr/scripts/wallpaper.sh ~/Pictures/Wallpapers/kamu.jpg
```
