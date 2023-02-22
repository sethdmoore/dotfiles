# set expected XDG_ standard directories
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_STATE_HOME="${HOME}/.local/state"
export XDG_CACHE_HOME="${HOME}/.cache"

export GNUPGHOME="${XDG_DATA_HOME}/gnupg"
export PASSWORD_STORE_DIR="${XDG_DATA_HOME}/pass"
export BROWSER=firefox

# export GTK2_RC_FILES="/usr/share/themes/Arc-Dark/gtk-2.0/gtkrc"
# export GTK_MODULES="canberra-gtk-module"
# export GTK_THEME="Arc-Dark"
