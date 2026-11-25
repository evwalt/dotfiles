# Dotfiles

My macOS setup, built around Neovim, Zsh, tmux, and a Dvorak keyboard, managed with [yadm](https://yadm.io) so every file stays at its normal path under `$HOME`.

It's a personal config, not a framework. Borrow whatever's useful; the pieces below are the ones most worth a look.

## Theme: Harbor Night

A custom low-glare dark palette with a periwinkle accent and muted accent colors, applied across Alacritty, Neovim, tmux, Zsh, delta, lazygit, Hammerspoon, and Claude Code.

![Harbor Night in Neovim](.github/assets/harbor-night-nvim.png)

![Harbor Night palette](.github/assets/harbor-night-palette.svg)

Where it's defined:

- Terminal palette: [`.config/alacritty/alacritty.toml`](.config/alacritty/alacritty.toml)
- Neovim: a recolor of [folke/tokyonight.nvim](https://github.com/folke/tokyonight.nvim) (tokyonight-night) in [`.config/nvim/lua/config/plugins/theme.lua`](.config/nvim/lua/config/plugins/theme.lua)
- Claude Code: [`.claude/themes/harbor-night.json`](.claude/themes/harbor-night.json)

## Highlights

**Neovim** ([`.config/nvim`](.config/nvim)): lazy.nvim, LSP with blink.cmp, Telescope, Treesitter, conform, and nvim-lint. Prose gets grammar and spell checking through ltex, with a loose mode for notes that hides warnings on likely proper nouns ([`ltex-filter.lua`](.config/nvim/lua/config/ltex-filter.lua)).

**tmux sidecar** ([`scripts/sidecar.rs`](scripts/sidecar.rs)): a group of panes that follows you from window to window and keeps its layout, with toggles to maximize either side. Written in Rust, wired up in [`tmux.conf`](.config/tmux/tmux.conf).

**Hammerspoon** ([`.hammerspoon/init.lua`](.hammerspoon/init.lua)):

- Hyper-key pickers: one combo opens a hint panel of sub-keys, each mirrored on the other hand for Dvorak, with fuzzy search across every picker
- A floating 24-hour clock with an optional countdown slot
- A focus border for Firefox when more than one window is open

**Scripts** ([`scripts/`](scripts)): small tools such as `ct` (terminal countdown timer), `msgs` (read iMessages with contact names, read-only), and `ytt` (save a YouTube transcript).

## Dependency tracking

Installed tools are recorded in plain-text lockfiles in [`packages/`](packages) (`pipx-packages.txt`, `global-npm-packages.txt`, `cargo-packages.txt`, `rust-toolchains.txt`, `bob-versions.txt`, `go-version.txt`), plus `lazy-lock.json` for Neovim plugins, so diffs show exactly what changed and when. Homebrew no longer supports macOS 13, so newer tools come from pipx, npm, cargo, or direct binary downloads.

[`packages/archive/`](packages/archive) holds snapshots that are no longer maintained: the `brew-*.txt` lists, and `vscode-extensions.txt` from before I moved to Neovim. The VS Code settings under `Library/Application Support/Code/User/` are kept for the same reason.

Weekly maintenance is one command, `wua`, defined in [`.aliases`](.aliases):

- `wup` updates lazy.nvim plugins, pipx, global npm packages, rustup, and bob
- `wl` regenerates the lockfiles
- `wuta` commits and pushes any lockfile changes

## Using it

To try the whole setup on a fresh Mac (back up your own dotfiles first):

```sh
yadm clone https://github.com/evwalt/dotfiles.git
```

Most people will get more out of copying individual files.

## License

[ISC](LICENSE)
