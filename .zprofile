# --- PATH setup ---
# Prevent duplicate PATH entries if sourced multiple times
typeset -U path PATH
export ZPROFILE_LOADED=1

# bob-managed Neovim
export PATH="$HOME/.local/share/bob/nvim-bin:$PATH"

# Keep rustup-managed toolchains first
export PATH="$HOME/.cargo/bin:$PATH"

# pipx
export PATH="$PATH:$HOME/.local/bin"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"

##
# Your previous /Users/evan/.zprofile file was backed up as /Users/evan/.zprofile.macports-saved_2025-10-18_at_16:38:30
##

# MacPorts Installer addition on 2025-10-18_at_16:38:30: adding an appropriate PATH variable for use with MacPorts.
export PATH="$PATH:/opt/local/bin:/opt/local/sbin"
# Finished adapting your PATH environment variable for use with MacPorts.

# sbin fix per `brew doctor`
export PATH="$PATH:/usr/local/sbin"

# rvm
export PATH="$PATH:$HOME/.rvm/bin"
