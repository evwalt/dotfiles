# Load login environment if needed
if [ -z "$ZPROFILE_LOADED" ] && [ -f "$HOME/.zprofile" ]; then
    source "$HOME/.zprofile"
fi

# --- completion ---
autoload -Uz compinit
compinit

# --- aliases ---
[ -r ~/.aliases ] && source ~/.aliases
[ -r ~/dev/resume-cov/.aliases-resume-cov ] && source ~/dev/resume-cov/.aliases-resume-cov

# --- node / nvm ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# cursor style
echo -ne "\e[2 q"
trap 'echo -ne "\e[2 q"' EXIT

# --- ghcup ---
source ${HOME}/.ghcup/env

# --- pyenv ---
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# --- codex completion ---
eval "$(codex completion zsh)"

# --- prompt (agnoster-like replacement) ---
autoload -U colors && colors
setopt prompt_subst

git_branch() {
  local b
  b=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ -n "$b" ]] && echo "%F{magenta} $b%f"
}

PROMPT='%F{green}%n@%m%f %F{blue}%~%f $(git_branch) %# '
