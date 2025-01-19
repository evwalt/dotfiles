for file in ~/.aliases; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file"
done
. "$HOME/.cargo/env"

source ${HOME}/.ghcup/env
