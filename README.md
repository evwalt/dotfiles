# Dotfiles

## About

This repo leverages [yadm](https://yadm.io) to track dotfiles, settings, and text files in my macOS home directory.

The `yadm` local repo is stored in `~/.local/share/yadm/repo.git`.

## Housekeeping

Take the following steps with shell commands ([aliases](./.aliases)) on a weekly or regular basis to keep global packages up-to-date.

Update global npm packages:

```zsh
ngo
```

Open Neovim:

```zsh
n
```

Update LazyVim.

Update Rustup and Homebrew:

```zsh
r && b
```

Update VimMode Spoon:

```zsh
vms
```

Track changes in yadm with commits and pushes:

```zsh
us
```

```zsh
u add ...
```

```zsh
ucm "..." && up
```
