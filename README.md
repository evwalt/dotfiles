# Dotfiles

## About

This repo leverages [yadm](https://yadm.io) to track dotfiles, settings, and text files in my macOS home directory.

The `yadm` local repo is stored in `~/.local/share/yadm/repo.git`.

## Housekeeping

Take the following steps with Z shell commands on a weekly or regular basis to keep global packages up-to-date. The following commands are [aliases](./.aliases).

### Step 1

Update global npm packages:

```zsh
ngo
```

### Step 2

Open Neovim:

```zsh
n
```

Update LazyVim.

### Step 3

Update Rustup and Homebrew:

```zsh
r && b
```

### Step 4

Update VimMode Spoon:

```zsh
vms
```

### Step 5

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
