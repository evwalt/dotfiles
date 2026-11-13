# Antigravity CLI (agy)

Installed from:
curl -fsSL https://antigravity.google/cli/install.sh | bash

Version:
1.5.8

Install location:
~/.local/bin/agy (single binary); state and config in ~/.gemini/

PATH:
~/.local/bin is already on PATH via ~/.zprofile. The installer appends a PATH
export to .bashrc, .zshrc, .zprofile, .bash_profile and .profile; revert with:
yadm checkout -- ~/.bashrc ~/.zshrc ~/.zprofile ~/.bash_profile ~/.profile

Login:
Google OAuth with a personal account (free Starter Quota). The account
verification link is hard-wrapped across lines; join it before opening.

Tracked config:
~/.gemini/antigravity-cli/settings.json (yadm private). Never track
~/.gemini/antigravity-cli/jetski_state.pbtxt (auth state).

Replaces:
Gemini CLI (@google/gemini-cli), which stopped serving free personal
accounts on 2026-06-18.
