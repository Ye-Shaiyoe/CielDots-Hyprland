<div align="center">

# ✦ CielDots — Hyprland

**A personal Hyprland rice for Gentoo Linux**

*Clean · Fast · Catppuccin Mocha*

![Hyprland](https://img.shields.io/badge/WM-Hyprland-cba6f7?style=flat-square&logo=linux&logoColor=white)
![Gentoo](https://img.shields.io/badge/OS-Gentoo_Linux-54487a?style=flat-square&logo=gentoo&logoColor=white)
![Theme](https://img.shields.io/badge/Theme-Catppuccin_Mocha-1e1e2e?style=flat-square&logoColor=white)
![Font](https://img.shields.io/badge/Font-JetBrainsMono_NF-89b4fa?style=flat-square&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-Zsh_+_Starship-a6e3a1?style=flat-square&logoColor=white)

</div>

---

## What is this?

CielDots is a fully configured Hyprland desktop environment built specifically for **Gentoo Linux**. Everything is themed with [Catppuccin Mocha](https://catppuccin.com/) — from the terminal and bar down to the GTK apps and cursor.

The installer (`install.sh`) handles everything in one shot: Portage overlays, USE flags, ~amd64 keywords, package installation, config symlinking, and service setup.

---

## Software Stack

| Role | App | Notes |
|------|-----|-------|
| Window Manager | [Hyprland](https://hyprland.org) | Dynamic tiling Wayland compositor |
| Status Bar | [Waybar](https://github.com/Alexays/Waybar) | Top bar with system info |
| Terminal | [Kitty](https://sw.kovidgoyal.net/kitty/) | GPU-accelerated, animated cursor trail, glass opacity |
| Shell | Zsh + [Starship](https://starship.rs) | Fast prompt, Rimuru palette, fastfetch on open |
| Fetch | [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | JaKooLit-style tree layout, Rimuru ASCII logo |
| App Launcher | [Wofi](https://hg.sr.ht/~scoopta/wofi) | Wayland-native launcher |
| Notifications | [Mako](https://github.com/emersion/mako) | Lightweight notification daemon |
| Wallpaper | [swww](https://github.com/LGFae/swww) | Smooth animated transitions |
| Lock Screen | [Hyprlock](https://github.com/hyprwm/hyprlock) | Native Hyprland lock screen |
| Idle Daemon | [Hypridle](https://github.com/hyprwm/hypridle) | Auto-dim, lock, and sleep |
| File Manager | [Thunar](https://docs.xfce.org/xfce/thunar/start) | Lightweight file manager |
| Audio | PipeWire + WirePlumber | Modern audio stack |
| Color Scheme | [Catppuccin Mocha](https://catppuccin.com/) | Consistent across all apps |
| Font | JetBrainsMono Nerd Font | Coding font with icons |

---

## Quick Install

> **Requirements:** Gentoo Linux with `emerge`, `eselect`, `git`, and `curl` available on your system.

```bash
# 1. Clone the dotfiles
git clone https://github.com/yourusername/CielDots-Hyprland ~/.dotfiles

# 2. Enter the directory
cd ~/.dotfiles

# 3. Make the installer executable
chmod +x install.sh

# 4. Run it
./install.sh
```

The installer will walk you through everything automatically. No manual Portage setup required.

### What the installer does

1. **Validates** your system — checks for Gentoo, available disk space (≥10GB), and required tools
2. **Sets up overlays** — adds the [GURU](https://wiki.gentoo.org/wiki/Project:GURU) community overlay via `eselect repository`
3. **Writes USE flags** — creates `/etc/portage/package.use/cieldots` with all necessary flags (wayland, vulkan, drm, gles2, tray, etc.)
4. **Unmasks packages** — creates `/etc/portage/package.accept_keywords/cieldots` for all `~amd64` packages in the Hyprland ecosystem
5. **Installs packages** — runs `emerge` for each package, skips failures and reports them at the end
6. **Symlinks configs** — links everything from this repo into `~/.config/` (with automatic backup of existing files)
7. **Sets up Zsh** — configures `ZDOTDIR` and sets zsh as default shell
8. **Enables services** — works with both OpenRC and systemd

### If something goes wrong

The installer creates a snapshot of every file before touching it. To restore your previous state:

```bash
./install.sh --rollback
```

Backups are also saved to `~/.config-backup-cieldots/<timestamp>/` for manual recovery.

---

## Directory Structure

```
CielDots-Hyprland/
├── install.sh                  ← One-shot Gentoo installer
├── README.md
│
├── .config/
│   ├── hypr/
│   │   ├── hyprland.conf       ← Main config (Rimuru theme, slime animations)
│   │   ├── hyprlock.conf       ← Lock screen (frosted glass, cyan clock)
│   │   └── hypridle.conf       ← Idle timeouts
│   │
│   ├── waybar/
│   │   ├── config.jsonc        ← Bar modules
│   │   └── style.css           ← Rimuru Tempest glassmorphism styling
│   │
│   ├── kitty/
│   │   ├── kitty.conf          ← Terminal (cursor trail, opacity, font)
│   │   └── themes/
│   │       └── rimuru.conf     ← Rimuru color palette (swappable)
│   │
│   ├── fastfetch/
│   │   ├── config.jsonc        ← JaKooLit-style tree layout
│   │   └── rimuru.txt          ← Custom ASCII logo
│   │
│   ├── mako/
│   │   └── config              ← Notifications (glass panels)
│   │
│   ├── wofi/
│   │   ├── config
│   │   └── style.css           ← Launcher (glassmorphism)
│   │
│   ├── zsh/
│   │   └── .zshrc              ← Shell (no plugin manager, fzf, fastfetch)
│   │
│   ├── starship/
│   │   └── starship.toml       ← Prompt (Rimuru palette)
│   │
│   ├── gtk-3.0/
│   │   └── settings.ini
│   │
│   └── gtk-4.0/
│       └── settings.ini
│
└── scripts/
    ├── startup.sh
    ├── wallpaper.sh
    ├── gaming-mode.sh
    └── screenshot.sh
```

---

## Keybindings

All keybinds use `Super` (Windows key) as the modifier.

### Applications

| Key | Action |
|-----|--------|
| `Super + Return` | Open terminal (Kitty) |
| `Super + Space` | Open app launcher (Wofi) |
| `Super + E` | Open file manager (Thunar) |
| `Super + B` | Open browser (Firefox) |

### Window Management

| Key | Action |
|-----|--------|
| `Super + Q` | Close active window |
| `Super + F` | Toggle fullscreen |
| `Super + V` | Toggle floating |
| `Super + P` | Toggle pseudo-tile |
| `Super + R` | Enter resize mode (use arrow keys, Esc to exit) |
| `Super + H/J/K/L` | Move focus left/down/up/right |
| `Super + Arrow keys` | Move focus with arrow keys |
| `Super + LMB drag` | Move window |
| `Super + RMB drag` | Resize window |

### Workspaces

| Key | Action |
|-----|--------|
| `Super + 1–0` | Switch to workspace 1–10 |
| `Super + Shift + 1–0` | Move active window to workspace 1–10 |
| `Super + scroll up/down` | Cycle through workspaces |

Workspaces have names: `web`, `code`, `files`, `media`, `misc`

### Screenshots

| Key | Action |
|-----|--------|
| `Print` | Capture selected area → save + copy to clipboard |
| `Super + Print` | Capture fullscreen → save + copy |
| `Shift + Print` | Capture active window → save + copy |
| `Ctrl + Print` | Capture area + open in Swappy for annotation |

### Wallpaper & Gaming

| Key | Action |
|-----|--------|
| `Super + Shift + W` | Set random wallpaper |
| `Super + Ctrl + W` | Next wallpaper in list |
| `Super + Shift + G` | Toggle gaming mode on/off |

### System

| Key | Action |
|-----|--------|
| `Super + L` | Lock screen (Hyprlock) |
| `Super + Shift + Q` | Exit Hyprland |

### Volume & Brightness

| Key | Action |
|-----|--------|
| `XF86AudioRaiseVolume` | Volume up 5% |
| `XF86AudioLowerVolume` | Volume down 5% |
| `XF86AudioMute` | Toggle mute |
| `XF86MonBrightnessUp` | Brightness up 10% |
| `XF86MonBrightnessDown` | Brightness down 10% |

---

## Scripts

All scripts live in `scripts/` and are symlinked to `~/.config/hypr/scripts/` and `~/.local/bin/` during install.

### wallpaper

Smart wallpaper switcher powered by [swww](https://github.com/LGFae/swww).

```bash
wallpaper                        # Pick a random wallpaper from ~/Pictures/Wallpapers
wallpaper /path/to/image.jpg     # Set a specific wallpaper
wallpaper --next                 # Next wallpaper (alphabetical order)
wallpaper --prev                 # Previous wallpaper
wallpaper --slideshow            # Auto-rotate every N seconds
wallpaper --current              # Print the currently active wallpaper path
wallpaper --list                 # List all available wallpapers
```

**Environment variables you can set:**

| Variable | Default | Description |
|----------|---------|-------------|
| `WALLPAPER_DIR` | `~/Pictures/Wallpapers` | Where to look for images |
| `WALLPAPER_TRANSITION` | `wipe` | Transition type: `fade`, `wipe`, `slide`, `grow`, `center`, `random` |
| `WALLPAPER_TRANSITION_DURATION` | `1.5` | Transition duration in seconds |
| `WALLPAPER_INTERVAL` | `300` | Slideshow interval in seconds |
| `WALLPAPER_FPS` | `60` | Transition frame rate |

Supported formats: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`

### gaming-mode

Toggles performance optimizations for gaming — disables visual effects and sets CPU to performance mode.

```bash
gaming-mode          # Toggle on/off
gaming-mode on       # Activate gaming mode
gaming-mode off      # Deactivate gaming mode
gaming-mode status   # Show current state
```

**What gaming mode does when enabled:**
- Kills Waybar (frees memory and CPU)
- Sets all Hyprland gaps to 0, border size to 0
- Disables blur, shadows, and animations
- Disables VFR for consistent frame timing
- Sets CPU governor to `performance` (via `cpupower`)
- Starts GameMode daemon (if installed)
- Puts Mako into Do Not Disturb mode

**When disabled,** everything is restored: Waybar restarts, animations come back, CPU returns to `schedutil`.

### screenshot

Screenshot utility using `grim` + `slurp`, with optional annotation via `swappy`.

```bash
screenshot area             # Draw a selection box and capture
screenshot full             # Capture all monitors
screenshot window           # Capture the active window
screenshot monitor          # Capture the focused monitor
screenshot area --edit      # Capture area, then open in Swappy
```

Every screenshot is:
- Saved to `~/Pictures/Screenshots/screenshot_YYYY-MM-DD_HH-MM-SS.png`
- Automatically copied to clipboard
- Shown as a desktop notification with the filename

### startup

Called automatically by Hyprland on login (`exec-once = bash ~/.config/hypr/scripts/startup.sh`). You don't need to run this manually.

It starts: `swww-daemon` → wallpaper → Waybar → Mako → Polkit agent → nm-applet → blueman → XDG portals → Hypridle.

---

## Dynamic Color Scheme

Every time you change the wallpaper, the color scheme adapts automatically across the whole desktop.

```
Set wallpaper (wallpaper.sh)
    │
    └─► colorscheme.py runs in background
            │
            ├─► K-Means clustering → extracts 8 dominant colors
            ├─► Builds full palette (bg, text, accent, status colors)
            │
            ├─► ~/.config/kitty/themes/dynamic.conf     (reloaded live)
            ├─► ~/.config/waybar/dynamic-colors.css     (pkill -USR2)
            ├─► ~/.config/mako/config                   (makoctl reload)
            ├─► ~/.config/wofi/style.css                (next open)
            └─► hyprctl keyword → border colors          (instant)
```

**Example — red-dominant wallpaper:**
- Borders glow red-orange
- Kitty cursor and selection turn red-orange
- Waybar active workspace highlights red
- Mako notification border shifts red

**Example — blue/ocean wallpaper:**
- Everything shifts to deep blue accents
- Still dark background, but accent hue matches the water

### Manual controls

```bash
# Re-apply last extracted palette (after reboot, etc.)
colorscheme --reload
# shortcut: Super + Shift + X

# Preview palette without applying
colorscheme ~/Pictures/Wallpapers/some.jpg --dry

# Show current palette
colorscheme --show
# shortcut: Super + Ctrl + X

# Disable auto-color-extraction (keep manual palette)
export WALLPAPER_NO_COLORS=1
wallpaper --next
```

### Image reading backends (priority order)

1. **Pillow** (`dev-python/pillow`) — fastest, recommended
2. **ImageMagick** (`media-gfx/imagemagick`) — fallback
3. **ffmpeg** (`media-video/ffmpeg`) — second fallback

If none are available, falls back to Rimuru Tempest defaults.

---

## Terminal Setup

### Kitty — JaKooLit style

The kitty config is split into two files — base config and theme:

```
~/.config/kitty/
├── kitty.conf          ← base: font, cursor, opacity, keybinds
└── themes/
    └── rimuru.conf     ← Rimuru Tempest color palette (swap to change theme)
```

Key features matching JaKooLit's style:
- `cursor_trail 1` — animated cursor trail that follows movement
- `background_opacity 0.88` — glass transparency
- `dynamic_background_opacity yes` — opacity adjusts on focus
- Font: JetBrainsMono Nerd Font Mono 14pt
- Tab bar: powerline round style

To swap themes, just change the `include` line in `kitty.conf`:
```
include ./themes/rimuru.conf
```

### Fastfetch — JaKooLit tree layout

System info display on every new terminal. Layout uses the same tree-style structure JaKooLit uses (`│ ├` / `│ └` branches per section).

```
 󰣨 SYSTEM   Gentoo Linux
│ ├󰒔         6.x.x-gentoo
│ ├󰏖         1337 (emerge)
│ ├󰅐         2h 34m
│ └          zsh 5.x.x

  DE/WM     Hyprland
│ ├󰉼         Adwaita-dark
│ └          Kitty
...
```

Logo: custom Rimuru ASCII art at `~/.config/fastfetch/rimuru.txt`

To regenerate logo or disable it:
```bash
# disable logo
fastfetch --logo none

# use built-in gentoo logo instead
fastfetch --logo gentoo
```

### ZSH features

- **No plugin manager** — plugins loaded directly from system paths (Gentoo package paths)
- **Plugins:** zsh-autosuggestions, zsh-syntax-highlighting, zsh-history-substring-search, fzf integration
- **History substring search:** type partial command → Up/Down arrow to search
- **FZF:** `Ctrl+T` file picker, `Alt+C` directory jump, `Ctrl+R` history — all themed Rimuru colors
- **`fcd`** — fuzzy cd with eza tree preview
- `fastfetch` auto-runs on new terminal (skips in tmux/SSH)

---

## Portage Setup (Gentoo)

The installer handles all of this automatically. This section is for reference if you want to understand what's being set up.

### Overlays used

```bash
# GURU — community overlay with Hyprland ecosystem packages
sudo eselect repository enable guru
sudo emaint sync -r guru
```

### Key packages

```bash
# Core Hyprland stack
sudo emerge gui-wm/hyprland gui-apps/hyprlock gui-apps/hypridle

# Bar, launcher, notifications
sudo emerge gui-apps/waybar gui-apps/wofi x11-misc/mako

# Wallpaper and screenshot
sudo emerge gui-apps/swww media-gfx/grim gui-apps/slurp gui-apps/wl-clipboard

# Terminal and shell
sudo emerge x11-terms/kitty app-shells/zsh app-shells/starship
```

### After install, update your world

```bash
sudo emerge --ask --update --deep --newuse @world
```

### Useful Portage aliases (added to .zshrc automatically)

```bash
pkgi <package>   # emerge --ask (install)
pkgr             # emerge --ask --depclean (remove orphans)
pkgs <term>      # emerge --search
pkgu             # emerge --update --deep --newuse @world (full upgrade)
pkgc             # depclean + revdep-rebuild
pkgl             # qlist -Iv (list installed packages)
pkgsync          # emaint sync --auto
```

---

## Color Palette — Rimuru Tempest

| Name | Hex | Role |
|------|-----|------|
| Abyss | `#0a0e1a` | Background (deepest) |
| Deep | `#0d1420` | Background secondary |
| Storm | `#111827` | Surface |
| Overlay | `#1a2540` | Hover / inactive panels |
| Slate | `#263354` | Inactive borders |
| Silver | `#c8d6e8` | Primary text |
| Mist | `#7a91b0` | Dimmed text / subtext |
| Ghost | `#4a607a` | Very dim / placeholders |
| Cyan | `#00e5ff` | **Primary accent — slime!** |
| Blue | `#29b6f6` | Secondary / info |
| Teal | `#00bcd4` | Tertiary / network |
| Purple | `#7c4dff` | **Magic aura — highlight** |
| Violet | `#aa80ff` | Soft purple / audio |
| Green | `#00e676` | Success / battery / OK |
| Amber | `#ffb300` | Warning |
| Red | `#ff5252` | Error / critical |

---

## Theming Details

- **Color scheme:** Rimuru Tempest — Abyss navy `#0a0e1a` base, slime cyan `#00e5ff` accent, magic purple `#7c4dff` highlight
- **GTK theme:** Adwaita-dark
- **Icon theme:** Papirus-Dark
- **Cursor:** Bibata-Modern-Ice (size 24)
- **Hyprland border:** Gradient cyan `#00e5ff` → purple `#7c4dff` at 45°, animated loop
- **Window rounding:** 12px
- **Active window opacity:** 0.92 / Inactive: 0.82
- **Blur:** size 10, 3 passes, vibrancy 0.25 — full glassmorphism
- **Shadows:** cyan glow `rgba(00e5ff, 0.13)` on active windows
- **Animations:** "slime physics" bezier curves — stretchy and bouncy
- **Workspace names:** Rimuru's skills (「Predator」「Great Sage」「Storm」「Gluttony」「Raphael」)

---

## Troubleshooting

**Hyprland won't start**
Make sure `gui-libs/xdg-desktop-portal-hyprland` is installed and `XDG_CURRENT_DESKTOP=Hyprland` is set.

**No audio**
PipeWire needs WirePlumber as the session manager. Check with:
```bash
systemctl --user status pipewire wireplumber
# or for OpenRC:
rc-service pipewire status
```

**Waybar not showing**
Run `waybar` from a terminal to see error output. Usually a missing module or syntax error in `config.jsonc`.

**swww transitions are choppy**
Lower `WALLPAPER_FPS` from 60 to 30, or change `WALLPAPER_TRANSITION` to `fade`.

**Fonts look wrong / icons missing**
Ensure `media-fonts/nerd-fonts` is installed and your font cache is refreshed:
```bash
fc-cache -fv
```

**Gaming mode: cpupower fails**
You need `sudo` access for CPU governor changes. Add this to `/etc/sudoers.d/cpupower`:
```
your_username ALL=(ALL) NOPASSWD: /usr/bin/cpupower
```

---

## License

MIT — do whatever you want with it. A star is always appreciated. ✦
