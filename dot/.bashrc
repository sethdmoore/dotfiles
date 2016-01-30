export PATH="/usr/local/bin:/usr/local/go/bin:/usr/local/sbin:$PATH:$HOME/go/bin"
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

if [ -z "$TMUX" ]; then
    tmux attach || tmux
fi


# added by travis gem
[ -f /Users/smoore/.travis/travis.sh ] && source /Users/smoore/.travis/travis.sh
