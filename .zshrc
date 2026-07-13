# ~/.zshrc.no-omz — minimal, framework-free replacement for Oh My Zsh
#
# Goal: same look/behavior as the current agnoster-themed OMZ setup,
# but without the Oh My Zsh framework overhead. Ported piece-by-piece
# from ~/.oh-my-zsh/lib/{history,directories,misc,completion,key-bindings}.zsh
# and ~/.oh-my-zsh/themes/agnoster.zsh-theme.
#
# To test without touching your real setup:
#   ZDOTDIR=$HOME/.zshrc.no-omz.test zsh   (see migration notes)
# or simply:
#   zsh -c 'source ~/.zshrc.no-omz; zsh'

# --- .zprofile guard (same pattern as before, for non-login interactive shells) ---
if [ -z "$ZPROFILE_LOADED" ] && [ -f "$HOME/.zprofile" ]; then
  source "$HOME/.zprofile"
fi

## ============================================================
## History (from OMZ lib/history.zsh)
## ============================================================
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=10000
setopt extended_history hist_expire_dups_first hist_ignore_dups \
       hist_ignore_space hist_verify share_history

## ============================================================
## Directory navigation (from OMZ lib/directories.zsh)
## ============================================================
setopt auto_cd auto_pushd pushd_ignore_dups pushdminus

alias -g ...='../..'
alias -g ....='../../..'
alias -g .....='../../../..'
alias -g ......='../../../../..'

alias -- -='cd -'
alias 1='cd -1' 2='cd -2' 3='cd -3' 4='cd -4' 5='cd -5'
alias 6='cd -6' 7='cd -7' 8='cd -8' 9='cd -9'

alias md='mkdir -p'
alias rd=rmdir

d() {
  if [[ -n $1 ]]; then
    dirs "$@"
  else
    dirs -v | head -n 10
  fi
}

alias lsa='ls -lah'
alias ll='ls -lh'
alias la='ls -lAh'
# NOTE: `l` is intentionally left unset here — ~/.aliases defines
# `alias l="ls -laF"` and sources later, exactly as it did before.

## ============================================================
## Misc shell options (from OMZ lib/misc.zsh)
## ============================================================
setopt multios long_list_jobs interactivecomments
(( $+commands[less] )) && { export PAGER=less; export LESS='-R'; }
alias _='sudo '
if (( $+commands[ack-grep] )); then
  alias afind='ack-grep -il'
elif (( $+commands[ack] )); then
  alias afind='ack -il'
fi

## ============================================================
## Completion system (from OMZ lib/completion.zsh + oh-my-zsh.sh compinit)
## ============================================================
zmodload -i zsh/complist
WORDCHARS=''
unsetopt menu_complete flowcontrol
setopt auto_menu complete_in_word always_to_end

autoload -Uz compinit
# Full security audit + rebuild once/day; instant load (-C) the rest of the time.
_zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -n ${_zcompdump}(#qN.mh+24) ]]; then
  compinit -C -d "$_zcompdump"
else
  compinit -d "$_zcompdump"
fi
unset _zcompdump

bindkey -M menuselect '^o' accept-and-infer-next-history
zstyle ':completion:*:*:*:*:*' menu select
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
zstyle ':completion:*:cd:*' tag-order local-directories directory-stack path-directories
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "${ZDOTDIR:-$HOME}/.zcompcache"

autoload -Uz bashcompinit && bashcompinit

## ============================================================
## Key bindings (from OMZ lib/key-bindings.zsh)
## ============================================================
if (( ${+terminfo[smkx]} )) && (( ${+terminfo[rmkx]} )); then
  zle-line-init() { echoti smkx }
  zle-line-finish() { echoti rmkx }
  zle -N zle-line-init
  zle -N zle-line-finish
fi

bindkey -e

[[ -n "${terminfo[kpp]}" ]] && bindkey "${terminfo[kpp]}" up-line-or-history
[[ -n "${terminfo[knp]}" ]] && bindkey "${terminfo[knp]}" down-line-or-history

autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" up-line-or-beginning-search
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" down-line-or-beginning-search

[[ -n "${terminfo[khome]}" ]] && bindkey "${terminfo[khome]}" beginning-of-line
[[ -n "${terminfo[kend]}"  ]] && bindkey "${terminfo[kend]}"  end-of-line
[[ -n "${terminfo[kcbt]}"  ]] && bindkey "${terminfo[kcbt]}"  reverse-menu-complete

bindkey '^?' backward-delete-char
if [[ -n "${terminfo[kdch1]}" ]]; then
  bindkey "${terminfo[kdch1]}" delete-char
else
  bindkey '^[[3~' delete-char
  bindkey '^[3;5~' delete-char
fi

bindkey '^[[3;5~' kill-word        # Ctrl-Delete
bindkey '^[[1;5C' forward-word     # Ctrl-Right
bindkey '^[[1;5D' backward-word    # Ctrl-Left

bindkey '\ew' kill-region
bindkey -s '\el' '^q ls\n'
bindkey '^r' history-incremental-search-backward
bindkey ' ' magic-space

autoload -U edit-command-line
zle -N edit-command-line
bindkey '\C-x\C-e' edit-command-line
bindkey '^[m' copy-prev-shell-word

## ============================================================
## Terminal title (from OMZ lib/termsupport.zsh) — cheap, tmux/iTerm aware
## ============================================================
_title() {
  setopt localoptions nopromptsubst
  case "$TERM" in
    screen*|tmux*) print -Pn "\ek${1:q}\e\\" ;;
    xterm*|rxvt*|alacritty*|wezterm*)
      print -Pn "\e]2;${2:q}\a\e]1;${1:q}\a" ;;
  esac
}
_omz_like_precmd() { _title "%15<..<%~%<<" "%n@%m:%~" }
autoload -Uz add-zsh-hook
add-zsh-hook precmd _omz_like_precmd

## ============================================================
## Prompt: agnoster-style, recreated without the OMZ theme engine
## Same segments/colors/separators as your current ZSH_THEME="agnoster"
## ============================================================
setopt promptsubst
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' get-revision true
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr '✚'
zstyle ':vcs_info:*' unstagedstr '±'
zstyle ':vcs_info:*' formats ' %u%c'
zstyle ':vcs_info:*' actionformats ' %u%c'

_SEGMENT_SEPARATOR=$''
_PL_BRANCH_CHAR=$''

_prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $_CURRENT_BG != 'NONE' && $1 != $_CURRENT_BG ]]; then
    print -n " %{$bg%F{$_CURRENT_BG}%}$_SEGMENT_SEPARATOR%{$fg%} "
  else
    print -n "%{$bg%}%{$fg%} "
  fi
  _CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}

_prompt_end() {
  if [[ -n $_CURRENT_BG ]]; then
    print -n " %{%k%F{$_CURRENT_BG}%}$_SEGMENT_SEPARATOR"
  else
    print -n "%{%k%}"
  fi
  print -n "%{%f%}"
  _CURRENT_BG=''
}

_prompt_status() {
  local -a symbols
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"
  [[ -n "$symbols" ]] && _prompt_segment black default "$symbols"
}

_prompt_virtualenv() {
  [[ -n "$CONDA_DEFAULT_ENV" ]] && _prompt_segment magenta black "🐍 $CONDA_DEFAULT_ENV"
  [[ -n "$VIRTUAL_ENV" ]] && _prompt_segment blue black "(${VIRTUAL_ENV:t})"
}

_prompt_aws() {
  [[ -z "$AWS_PROFILE" ]] && return
  case "$AWS_PROFILE" in
    *-prod|*production*) _prompt_segment red yellow "AWS: $AWS_PROFILE" ;;
    *) _prompt_segment green black "AWS: $AWS_PROFILE" ;;
  esac
}

_prompt_context() {
  if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    _prompt_segment black default "%(!.%{%F{yellow}%}.)%n@%m"
  fi
}

_prompt_dir() {
  _prompt_segment blue black '%~'
}

_prompt_git() {
  (( $+commands[git] )) || return
  [[ "$(command git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]] && return
  local ref dirty branch_char=$_PL_BRANCH_CHAR
  if [[ "$(command git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]; then
    dirty=$(command git status --porcelain --ignore-submodules 2>/dev/null)
    ref=$(command git symbolic-ref HEAD 2>/dev/null) || \
      ref="➦ $(command git rev-parse --short HEAD 2>/dev/null)"

    if [[ -n $dirty ]]; then
      _prompt_segment yellow black
    else
      _prompt_segment green black
    fi

    local ahead behind
    ahead=$(command git log --oneline @{upstream}.. 2>/dev/null)
    behind=$(command git log --oneline ..@{upstream} 2>/dev/null)
    if [[ -n "$ahead" && -n "$behind" ]]; then
      branch_char=$'⇅'
    elif [[ -n "$ahead" ]]; then
      branch_char=$'↱'
    elif [[ -n "$behind" ]]; then
      branch_char=$'↰'
    fi

    vcs_info
    print -n "${${ref/refs\/heads\//$branch_char }}${vcs_info_msg_0_%% }"
  fi
}

build_prompt() {
  RETVAL=$?
  _CURRENT_BG='NONE'
  _prompt_status
  _prompt_virtualenv
  _prompt_aws
  _prompt_context
  _prompt_dir
  _prompt_git
  _prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '

## ============================================================
## User configuration (unchanged)
## ============================================================
[ -r ~/.aliases ] && source ~/.aliases
[ -r ~/dev/resume-cov/tool-resume-cov.zsh ] && source ~/dev/resume-cov/tool-resume-cov.zsh

## ============================================================
## Node via nvm — LAZY LOADED (real nvm.sh costs ~800ms to source)
## First call to nvm/node/npm/npx/yarn/pnpm/corepack pays the cost once;
## everything else about the workflow (including auto .nvmrc switching
## when a project actually has one) is preserved.
## ============================================================
export NVM_DIR="$HOME/.nvm"

# Eagerly expose the default node version's bin/ on PATH (cheap glob, no nvm.sh sourcing)
# so external tools (e.g. nvim's markdownlint-cli2 subprocess) can find node/npm-installed
# binaries even in a shell that never explicitly ran a node/npm/nvm command.
if [[ -r "$NVM_DIR/alias/default" ]]; then
  _nvm_default_dirs=("$NVM_DIR"/versions/node/v"$(<"$NVM_DIR/alias/default")"*(N/n))
  [[ -n "$_nvm_default_dirs[-1]" ]] && export PATH="$_nvm_default_dirs[-1]/bin:$PATH"
  unset _nvm_default_dirs
fi

_nvm_lazy_load() {
  unset -f nvm node npm npx yarn pnpm corepack 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}
for _cmd in nvm node npm npx yarn pnpm corepack; do
  eval "${_cmd}() { _nvm_lazy_load; ${_cmd} \"\$@\" }"
done
unset _cmd

_find_up() {
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    [[ -f "$dir/$1" ]] && { print -r -- "$dir/$1"; return 0; }
    dir="${dir:h}"
  done
  return 1
}

load-nvmrc() {
  local nvmrc_path
  nvmrc_path="$(_find_up .nvmrc)" || return
  _nvm_lazy_load
  local nvmrc_node_version
  nvmrc_node_version="$(cat "$nvmrc_path")"
  if [ "$(nvm version)" != "$(nvm version "$nvmrc_node_version")" ]; then
    nvm use --silent
  fi
}
add-zsh-hook chpwd load-nvmrc
load-nvmrc

## ============================================================
## Terminal cursor shape
## ============================================================
echo -ne "\e[2 q"
trap 'echo -ne "\e[2 q"' EXIT

## ============================================================
## ghcup
## ============================================================
[ -f "${HOME}/.ghcup/env" ] && source "${HOME}/.ghcup/env"

## ============================================================
## pyenv — LAZY LOADED (the 3 `eval $(pyenv init ...)` calls cost ~580ms)
## Shims (already on PATH via ~/.zprofile + the line below) resolve the
## right python/pip per .python-version with zero shell startup cost.
## `pyenv` itself (and pyenv-virtualenv's auto-activate-on-cd behavior,
## which affects the venv prompt segment above) initializes on first use.
##
## If you rely on the venv segment appearing immediately in every new
## shell (not just after first `pyenv`/`python` use), replace this whole
## block with the eager 3-line version from the old .zshrc instead.
## ============================================================
export PATH="$PYENV_ROOT/shims:$PATH"

pyenv() {
  unset -f pyenv
  eval "$(command pyenv init -)"
  eval "$(command pyenv virtualenv-init -)"
  pyenv "$@"
}
