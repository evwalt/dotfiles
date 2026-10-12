# --- PATH setup ---
# Prevent duplicate PATH entries if sourced multiple times
typeset -U path PATH
export ZPROFILE_LOADED=1

# .NET SDK (user-local install, no admin/brew required)
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$HOME/.dotnet:$HOME/.dotnet/tools:$PATH"

# bob-managed Neovim
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

# go
export PATH="/usr/local/go/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"

# Keep rustup-managed toolchains first
export PATH="$HOME/.cargo/bin:$PATH"

# pipx
export PATH="$PATH:$HOME/.local/bin"

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

# MacPorts Installer addition on 2025-10-18_at_16:38:30: adding an appropriate PATH variable for use with MacPorts.
export PATH="$PATH:/opt/local/bin:/opt/local/sbin"
# Finished adapting your PATH environment variable for use with MacPorts.

# sbin fix per `brew doctor`
export PATH="$PATH:/usr/local/sbin"

# rvm
export PATH="$PATH:$HOME/.rvm/bin"

# scripts
export PATH="$HOME/scripts:$PATH"
