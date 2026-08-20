# --- Zsh Plugins (sourced from system) ---
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ] && source /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# --- Dynamic Environment Variables ---
export GPG_TTY=$(tty)

# --- Basic Prompt with Git Support ---
autoload -Uz vcs_info
precmd() { vcs_info }

# Gruvbox color palette
GRUVBOX_RED="%F{#cc241d}"
GRUVBOX_RED2="%F{#fb4934}"
GRUVBOX_GREEN="%F{#98971a}"
GRUVBOX_GREEN2="%F{#b8bb26}"
GRUVBOX_YELLOW="%F{#d79921}"
GRUVBOX_YELLOW2="%F{#fabd2f}"
GRUVBOX_BLUE="%F{#458588}"
GRUVBOX_BLUE2="%F{#83a598}"
GRUVBOX_MAGENTA="%F{#b16286}"
GRUVBOX_MAGENTA2="%F{#d3869b}"
GRUVBOX_CYAN="%F{#689d6a}"
GRUVBOX_CYAN2="%F{#8ec07c}"
GRUVBOX_ORANGE="%F{#d65d0e}"
GRUVBOX_ORANGE2="%F{#fe8019}"
GRUVBOX_GRAY="%F{#a89984}"
GRUVBOX_WHITE="%F{#ebdbb2}"
GRUVBOX_RESET="%f"

# Format the vcs_info_msg_0_ variable
zstyle ':vcs_info:git:*' formats "on ${GRUVBOX_MAGENTA} %b${GRUVBOX_RESET} "
zstyle ':vcs_info:*' enable git

# Define the prompt
# %n=user, %m=host, %~=cwd, %F{...}=color
setopt PROMPT_SUBST
PROMPT='${GRUVBOX_CYAN}%n${GRUVBOX_GREEN2}@${GRUVBOX_MAGENTA}%m${GRUVBOX_RESET} ${GRUVBOX_BLUE}%~${GRUVBOX_RESET} ${vcs_info_msg_0_}${GRUVBOX_YELLOW}➜${GRUVBOX_RESET} '

# --- History Config ---
HISTFILE="$XDG_STATE_HOME"/zsh/history
HISTSIZE=10000
SAVEHIST=10000
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.
setopt HIST_VERIFY               # Don't execute immediately upon history expansion.
setopt SHARE_HISTORY             # Share history between all sessions.

# --- Completion ---
autoload -Uz compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' # Case insensitive tab completion
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"   # Colored completion (matches ls)
zstyle ':completion:*' rehash true                         # automatically find new executables in path
# Speed up completion
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME"/zsh
if [ ! -d "$XDG_CACHE_HOME"/zsh ]; then
    mkdir -p "$XDG_CACHE_HOME"/zsh
fi

# Initialize completion
compinit -d "$XDG_CACHE_HOME"/zsh/zcompdump-"$ZSH_VERSION"

# --- FZF Integration ---
if command -v fzf >/dev/null; then
    source <(fzf --zsh)
fi

# Adds `~/.local/bin` and all its subdirectories to $PATH
if [ -d "$HOME/.local/bin" ]; then
    local_dirs=$(find -L "$HOME/.local/bin" -type d -printf '%p:')
    export PATH="$PATH:${local_dirs%%:}"
fi

# Add ~/.local/share/bin to PATH
if [ -d "$XDG_DATA_HOME/bin" ]; then
    export PATH="$PATH:$XDG_DATA_HOME/bin"
fi

# Add Qt6 tools such as qmllint and qmlformat to PATH
if [ -d /usr/lib/qt6/bin ] && [[ ":$PATH:" != *":/usr/lib/qt6/bin:"* ]]; then
    export PATH="$PATH:/usr/lib/qt6/bin"
fi

# --- Other program settings ---
[ -x "$(command -v nvim)" ] && alias vim="nvim" vimdiff="nvim -d" # Use neovim for vim if present.
eval "$(zoxide init zsh)"

# --- Aliases ---
alias ls='ls --color=auto'
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -vI'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias g='git'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gst='git status'
alias gd='git diff'
alias pacman='sudo pacman'
alias reload='source $ZDOTDIR/.zshrc'
alias bc="bc -ql" \
alias rsync="rsync -vrPlu" \
alias mkd="mkdir -pv" \
alias yt="yt-dlp --embed-metadata -i" \
alias yta="yt -x -f bestaudio/best" \
alias ytt="yt --skip-download --write-thumbnail" \
alias ffmpeg="ffmpeg -hide_banner"

# --- Keybindings ---
# Bind history substring search to Up/Down
if [ -f /usr/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]; then
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
fi

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d "" cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

# Autostart Hyprland with uwsm if on TTY1 and no Wayland session is active
if uwsm check may-start; then
    exec uwsm start hyprland-uwsm.desktop
fi
