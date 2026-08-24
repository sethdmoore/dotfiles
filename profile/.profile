# set expected XDG_ standard directories
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_STATE_HOME="${HOME}/.local/state"
export XDG_CACHE_HOME="${HOME}/.cache"

# must be set on all OS's. already set in linux
export GNUPGHOME="${XDG_DATA_HOME}/gnupg"
export PASSWORD_STORE_DIR="${XDG_DATA_HOME}/pass"

# disabled because zshrc -> os.d/darwin changes shell paths if enabled
# we switched back to brew again, it's much faster than it used to be.
# export MACPORTS_HOME="${XDG_STATE_HOME}/macports"
