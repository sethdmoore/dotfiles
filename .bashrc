export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

# force bash to write and re-read history every time you issue a command.
# Semicolon already exists
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

export EDITOR=/usr/bin/vim

export HISTSIZE=50000
export HISTFILESIZE=500000
export HISTTIMEFORMAT="%d/%m/%y %T "

export HISTTIMEFORMAT="%d/%m/%y %T "

