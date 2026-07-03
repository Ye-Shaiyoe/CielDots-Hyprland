# /* ---- 💫 CielDots — Rimuru Tempest ZSH 💫 ---- */
# Inspired by JaKooLit's Hyprland-Dots zsh config

# ── Performance: skip compinit for non-interactive ───────────
[[ $- != *i* ]] && return

# ── History ──────────────────────────────────────────────────
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=10000
SAVEHIST=10000
mkdir -p "$(dirname "$HISTFILE")"

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY

# ── Options ──────────────────────────────────────────────────
setopt AUTO_CD
setopt CORRECT
setopt COMPLETE_ALIASES
setopt EXTENDED_GLOB
setopt NO_BEEP
setopt GLOB_DOTS
setopt INTERACTIVE_COMMENTS

# ── Completion ───────────────────────────────────────────────
autoload -Uz compinit
# Only regen once a day (zsh glob — zsh-only syntax, intentional)
local _zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ ! -f "$_zcompdump" ]] || \
   [[ $(find "$_zcompdump" -mmin +1440 2>/dev/null) ]]; then
    compinit -d "$_zcompdump"
else
    compinit -C -d "$_zcompdump"
fi
unset _zcompdump

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath 2>/dev/null || ls $realpath'

# ── Plugins (no plugin manager, pure path-based) ─────────────
# Try Gentoo paths first, then fallback paths

_load_plugin() {
    for path in "$@"; do
        [[ -f "$path" ]] && { source "$path"; return; }
    done
}

# zsh-autosuggestions
_load_plugin \
    /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
    /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting  (must load BEFORE zsh-history-substring-search)
_load_plugin \
    /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
    /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# zsh-history-substring-search
_load_plugin \
    /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh \
    /usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh

# fzf shell integration (Gentoo: app-shells/fzf)
_load_plugin \
    /usr/share/fzf/key-bindings.zsh \
    /usr/share/fzf/shell/key-bindings.zsh
_load_plugin \
    /usr/share/fzf/completion.zsh \
    /usr/share/fzf/shell/completion.zsh

unset -f _load_plugin

# ── Keybindings ──────────────────────────────────────────────
bindkey -e
bindkey '^[[A'  history-substring-search-up   2>/dev/null || bindkey '^[[A'  up-line-or-history
bindkey '^[[B'  history-substring-search-down 2>/dev/null || bindkey '^[[B'  down-line-or-history
bindkey '^[[H'  beginning-of-line
bindkey '^[[F'  end-of-line
bindkey '^[[3~' delete-char
bindkey '^H'    backward-delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# ── Plugin settings ──────────────────────────────────────────
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#1a2540"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# ── Environment ──────────────────────────────────────────────
export EDITOR=nvim
export VISUAL=nvim
export TERMINAL=kitty
export BROWSER=firefox
export PAGER=less
export LESS="-R --mouse"
export PATH="$HOME/.local/bin:$PATH"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# Wayland
export MOZ_ENABLE_WAYLAND=1
export _JAVA_AWT_WM_NONREPARENTING=1
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1

# FZF — Rimuru color scheme
export FZF_DEFAULT_OPTS="
    --color=bg+:#1a2540,bg:#0a0e1a,spinner:#00e5ff,hl:#00e5ff
    --color=fg:#c8d6e8,header:#29b6f6,info:#aa80ff,pointer:#00e5ff
    --color=marker:#00e676,fg+:#c8d6e8,prompt:#00e5ff,hl+:#18ffff
    --color=border:#1a2540
    --border=rounded
    --prompt='❯ '
    --pointer='󰁔 '
    --marker='✓ '
    --layout=reverse
    --info=inline
"
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git 2>/dev/null || find . -type f'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git 2>/dev/null || find . -type d'

# ── Aliases ──────────────────────────────────────────────────

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias -- -='cd -'

# List files
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first --color=always'
    alias ll='eza --icons --group-directories-first -lh --color=always'
    alias la='eza --icons --group-directories-first -lah --color=always'
    alias lt='eza --icons --tree --level=2 --color=always'
    alias lta='eza --icons --tree --level=2 -a --color=always'
else
    alias ls='ls --color=auto --group-directories-first'
    alias ll='ls -lh --color=auto'
    alias la='ls -lha --color=auto'
fi

# cat → bat
command -v bat &>/dev/null && alias cat='bat --style=plain --paging=never'

# grep with color
alias grep='grep --color=auto'
alias rg='rg --color=auto'

# Editor
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# Git
alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit -m'
alias gca='git commit --amend'
alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline --graph --all --decorate'
alias gd='git diff'
alias gds='git diff --staged'
alias gco='git checkout'
alias gb='git branch'
alias gcl='git clone'

# Portage (Gentoo)
alias emerge='sudo emerge'
alias pkgi='sudo emerge --ask'
alias pkgr='sudo emerge --ask --depclean'
alias pkgs='emerge --search'
alias pkgq='emerge --search'
alias pkgu='sudo emerge --ask --update --deep --newuse @world'
alias pkgc='sudo emerge --ask --depclean && sudo revdep-rebuild'
alias pkgl='qlist -Iv'
alias pkgsync='sudo emaint sync --auto'
alias pkginfo='emerge --info'
alias pkgfiles='qlist -I'

# Hyprland config shortcuts
alias hyprconf='nvim ~/.config/hypr/hyprland.conf'
alias waybarconf='nvim ~/.config/waybar/config.jsonc'
alias waybarcss='nvim ~/.config/waybar/style.css'
alias kittyconf='nvim ~/.config/kitty/kitty.conf'
alias zshconf='nvim ~/.config/zsh/.zshrc'
alias neoconf='nvim ~/.config/nvim/'
alias dotfiles='cd ~/.dotfiles'

# System
alias cl='clear'
alias q='exit'
alias reload='exec zsh'
alias df='df -h'
alias du='du -sh'
alias free='free -h'
alias psa='ps aux | grep'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me && echo'
alias speedtest='curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -'

# Clipboard (Wayland)
alias pbcopy='wl-copy'
alias pbpaste='wl-paste'

# Quick directory listing with fzf
alias fcd='cd "$(fd --type d | fzf --preview "eza --tree --level=2 --icons {} 2>/dev/null || ls {}")"'

# ── Functions ────────────────────────────────────────────────

# mkdir + cd
mkcd() { mkdir -p "$1" && cd "$1" }

# Extract any archive
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2)  tar xjf "$1"    ;;
            *.tar.gz)   tar xzf "$1"    ;;
            *.tar.xz)   tar xJf "$1"    ;;
            *.tar.zst)  tar --zstd -xf "$1" ;;
            *.bz2)      bunzip2 "$1"    ;;
            *.rar)      unrar x "$1"    ;;
            *.gz)       gunzip "$1"     ;;
            *.tar)      tar xf "$1"     ;;
            *.tbz2)     tar xjf "$1"    ;;
            *.tgz)      tar xzf "$1"    ;;
            *.zip)      unzip "$1"      ;;
            *.Z)        uncompress "$1" ;;
            *.7z)       7z x "$1"       ;;
            *.zst)      zstd -d "$1"    ;;
            *)          echo "'$1' — unknown archive format" ;;
        esac
    else
        echo "'$1' is not a file"
    fi
}

# Quick backup
bak() { cp -v "$1" "$1.bak" }

# Find process
psg() { ps aux | grep -v grep | grep -i "$1" }

# Create temp dir and cd into it
tmp() { cd "$(mktemp -d)" }

# Pretty print PATH
path() { echo "$PATH" | tr ':' '\n' | nl }

# Quick HTTP server
serve() { python3 -m http.server "${1:-8000}" }

# Gentoo: check USE flags for a package
puse() { equery uses "$1" }

# Wallpaper shortcuts
alias wallpaper='bash ~/.config/hypr/scripts/wallpaper.sh'
alias wall-next='bash ~/.config/hypr/scripts/wallpaper.sh --next'
alias wall-prev='bash ~/.config/hypr/scripts/wallpaper.sh --prev'
alias wall-list='bash ~/.config/hypr/scripts/wallpaper.sh --list'

# ── Starship Prompt ──────────────────────────────────────────
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# ── Fastfetch on new terminal — JaKooLit style ───────────────
# Only runs in interactive, non-tmux, non-SSH sessions
if [[ -z "$TMUX" && -z "$SSH_CONNECTION" ]] && command -v fastfetch &>/dev/null; then
    fastfetch
fi
