# Load the session environment in every zsh, not just under uwsm (TTY, SSH,
# tools that spawn their own shells), so XDG overrides like GNUPGHOME apply.
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/uwsm/env" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/uwsm/env"
