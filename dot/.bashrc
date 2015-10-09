export PATH="/usr/local/bin:/usr/local/go/bin:/usr/local/sbin:$PATH"
export GOPATH="${HOME}/go"

# force bash to write and re-read history every time you issue a command.
# Semicolon already exists
# export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# write history every command, but don't read it back.
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

export EDITOR=/usr/bin/vim

# lines of history in memory
# setting this too high causes the shell to return SLOWLY
# 3000 is a good number
export HISTSIZE=3000

# lines of history on disk
export HISTFILESIZE=1000000
export HISTTIMEFORMAT="%d/%m/%y %T "

export HISTTIMEFORMAT="%d/%m/%y %T "


export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting


[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
eval $(docker-machine env default)
