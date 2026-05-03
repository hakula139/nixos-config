# ==============================================================================
# Zsh init — sourced from programs.zsh.initContent
# ==============================================================================

# Globbing options
setopt GLOB_DOTS
setopt NO_CASE_GLOB
setopt NUMERIC_GLOB_SORT
setopt EXTENDED_GLOB

# Misc options
setopt CORRECT
setopt INTERACTIVE_COMMENTS
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' special-dirs false

# Load zmv for batch renaming
autoload -U zmv

# fzf-tab styling. one:accept auto-selects a unique match.
zstyle ':fzf-tab:*' fzf-flags --height=40% --layout=reverse --border --bind=one:accept
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:complete:ls:*' fzf-preview 'eza -1 --color=always $realpath'

# Create directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# Refresh env vars from tmux session on each prompt, so existing
# panes pick up fresh tokens and sockets after reattach
if [[ -n "$TMUX" ]]; then
  _refresh_tmux_env() {
    eval "$(tmux show-environment -s 2>/dev/null | grep -E '(VSCODE_|GIT_ASKPASS|CLAUDE_CODE_SSE_PORT)')"
    # Stale WSL_INTEROP sockets cause slow Windows interop and Crashpad
    # errors; always pick the newest socket rather than trusting the
    # value inherited from tmux-resurrect or an old attach
    if [[ -d /run/WSL ]]; then
      local newest
      newest=$(find /run/WSL -maxdepth 1 -name '*_interop' -type s -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
      [[ -n "$newest" ]] && export WSL_INTEROP="$newest"
    fi
  }
  precmd_functions+=(_refresh_tmux_env)
fi

# Set EDITOR based on available editors (cursor > code > nvim > vim)
if command -v cursor &>/dev/null; then
  export EDITOR="cursor editor --wait"
elif command -v code &>/dev/null; then
  export EDITOR="code --wait"
elif command -v nvim &>/dev/null; then
  export EDITOR="nvim"
else
  export EDITOR="vim"
fi
alias e="$EDITOR"

sudoe() {
  SUDO_EDITOR="$EDITOR" sudo -e "$@"
}

# Git retag - delete and recreate a tag
git-retag() {
  local tag=$1
  if git tag | grep -q "^$tag$"; then
    git tag --delete "$tag"
    git push origin --delete "$tag"
  fi
  git tag "$tag"
  git push origin "$tag"
}
alias gtr="git-retag"
