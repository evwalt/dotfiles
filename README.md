# Dotfiles

## Overview

This repository leverages [yadm](https://yadm.io) to manage dotfiles, settings, and text files in my macOS home directory. `yadm` simplifies tracking and synchronizing these files across systems. The local `yadm` repository is stored at `.local/share/yadm/repo.git`.

## Regular Maintenance

To ensure everything stays up-to-date, run the following commands (using the provided [aliases](./.aliases)) regularly, ideally on a weekly basis.

### Update Global NPM Packages

- Check for outdated packages:

```zsh
ngo
```

- Update outdated packages (if applicable).

```zsh
npm -g update
```

### Update Neovim

- Open Neovim:

```zsh
nvim
```

- Update lazy.nvim plugins. Inside Neovim, run `:Lazy` to open lazy.nvim and "S" to sync plugins. And then, quit Neovim.

### Update Rustup and Homebrew

```zsh
r && b
```

### Track and Push Changes with `yadm`

- Track changes:

```zsh
us
```

- Stage specific files:

```zsh
u add [path/to/file...]
```

- Commit and push:

```zsh
ucm "Commit message" && up
```

