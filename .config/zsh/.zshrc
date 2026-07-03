# ========================================
# Zsh Configuration - Catppuccin Mocha
# ========================================

# Path to oh-my-zsh (if using it, comment out if using bare zsh)
# export ZSH="$HOME/.oh-my-zsh"

# ---- History ----
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY

# ---- Options ----
setopt AUTO_CD
setopt CORRECT
setopt COMPLETE_ALIASES
setopt EXTENDED_GLOB
setopt NO_BEEP

# ---- Completion ----
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# ---- Plugins (manual, no plugin manager needed) ----
# zsh-autosuggestions
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-syntax-highlighting (must be last)
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ---- Starship Prompt ----
eval "$(starship init zsh)"

# ---- Environment Variables ----
export EDITOR=nvim
export VISUAL=nvim
export TERMINAL=kitty
export BROWSER=firefox
export PATH="$HOME/.local/bin:$PATH"

# Wayland specific
export WAYLAND_DISPLAY=wayland-1
export MOZ_ENABLE_WAYLAND=1
export _JAVA_AWT_WM_NONREPARENTING=1

# ---- Aliases ----
# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# List files (using eza if available, fallback to ls)
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza --icons --group-directories-first -l'
    alias la='eza --icons --group-directories-first -la'
    alias lt='eza --icons --tree --level=2'
else
    alias ls='ls --color=auto'
    alias ll='ls -lh --color=auto'
    alias la='ls -lha --color=auto'
fi

# Grep with color
alias grep='grep --color=auto'

# Editor shortcuts
alias v='nvim'
alias vi='nvim'
alias vim='nvim'

# Git shortcuts
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --all'
alias gd='git diff'

# Package manager (Arch/paru)
alias paru='paru --skipreview'
alias pkgi='paru -S'
alias pkgr='paru -Rns'
alias pkgs='paru -Ss'
alias pkgu='paru -Syu'
alias pkgl='paru -Q'

# Hyprland specific
alias hyprconf='nvim ~/.config/hypr/hyprland.conf'
alias waybarconf='nvim ~/.config/waybar/config.jsonc'
alias kittyconf='nvim ~/.config/kitty/kitty.conf'
alias zshconf='nvim ~/.config/zsh/.zshrc'

# Misc
alias cl='clear'
alias q='exit'
alias reload='source ~/.config/zsh/.zshrc'
alias df='df -h'
alias du='du -h'
alias free='free -h'

# ---- Functions ----

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract any archive
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)  tar xjf "$1"    ;;
            *.tar.gz)   tar xzf "$1"    ;;
            *.tar.xz)   tar xJf "$1"    ;;
            *.bz2)      bunzip2 "$1"    ;;
            *.rar)      unrar x "$1"    ;;
            *.gz)       gunzip "$1"     ;;
            *.tar)      tar xf "$1"     ;;
            *.tbz2)     tar xjf "$1"    ;;
            *.tgz)      tar xzf "$1"    ;;
            *.zip)      unzip "$1"      ;;
            *.Z)        uncompress "$1" ;;
            *.7z)       7z x "$1"       ;;
            *)          echo "'$1' cannot be extracted" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Quick wallpaper change with swww
wallpaper() {
    swww img "$1" --transition-type wipe --transition-duration 1
}

# ---- Autosuggestion colors ----
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c7086"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
