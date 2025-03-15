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

- Update outdated packages (if applicable) and log to `global-npm-packages.txt`.

```zsh
ngu
```

### Update pipx

- Update packages (if applicable) and log to `pipx-packages.txt`.

```zsh
pxu
```

### Update Neovim

- Open Neovim:

```zsh
nvim
```

- Update lazy.nvim plugins. Inside Neovim, run `:Lazy` to open lazy.nvim and "S" to sync plugins. And then, quit Neovim.

### Update Rustup and Homebrew

- Update rustup toolchain and brews (if applicable); log brews to text files.

```zsh
r && b
```

### Update Chrome Extensions as Neede

Whenever you add or modify Chrome Extensions, go to `chrome://extensions`, select all, copy, and paste to overwrite into `chrome-extensions.txt`.

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
ucm "Commit message" && ups
```
