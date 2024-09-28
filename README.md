# Dotfiles

## Overview

This repository leverages [yadm](https://yadm.io) to manage dotfiles, settings, and text files in my macOS home directory. `yadm` simplifies tracking and synchronizing these files across systems. The local `yadm` repository is stored at `.local/share/yadm/repo.git`.

## Regular Maintenance

To ensure everything stays up-to-date, run the following commands (using the provided [aliases](./.aliases)) regularly, ideally on a weekly basis.

### Update global npm packages

```zsh
ngo
```

### Open Neovim

```zsh
n
```

### Update LazyVim, Rustup, and Homebrew

- Update LazyVim (manual step).
- Update Rustup and Homebrew:

```zsh
r && b
```

### Update VimMode Spoon

```zsh
vms
```

### Track and Push Changes in `yadm`

- Stage changes:

```zsh
us
```

- Add specific files:

```zsh
u add [path/to/file...]
```

- Commit and push changes:

```zsh
ucm "Commit message" && up
```
