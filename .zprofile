# --- PATH setup ---
# Prevent duplicate PATH entries if sourced multiple times
typeset -U path PATH
export ZPROFILE_LOADED=1

# .NET SDK (user-local install, no admin/brew required)
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"

# bob-managed Neovim
export BOB_CONFIG="$HOME/.config/bob/config.toml"
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

# go
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"

# Keep rustup-managed toolchains first
export PATH="$HOME/.cargo/bin:$PATH"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$PYENV_ROOT/shims:$PATH"

pyenv() {
  unset -f pyenv
  eval "$(command pyenv init -)"
  eval "$(command pyenv virtualenv-init -)"
  pyenv "$@"
}

# sbin fix per `brew doctor`
export PATH="$PATH:/usr/local/sbin"

# rvm
export PATH="$PATH:$HOME/.rvm/bin"

# Manual installs (release downloads, pipx) win over frozen Homebrew; updated by `mu`
export PATH="$HOME/.local/bin:$PATH"

# Homebrew is a frozen base layer on macOS 13: never auto-update or upgrade implicitly
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_UPGRADE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_AUTOREMOVE=1

# scripts
export PATH="$HOME/scripts:$PATH"
