autoload -U colors && colors
bindkey -v
bindkey '^R' history-incremental-search-backward

export PS1="%n %~ %(?.%{$fg[blue]%}╠►.%{$fg[red]%}╠►) %{$reset_color%}"
export HISTSIZE=1000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
export GO15VENDOREXPERIMENT=1
export EDITOR="vim"

KERNEL="$(uname -s)"

if [ -f "${HOME}/.aliases" ]; then
    source "${HOME}/.aliases"
fi

if [ -f "${HOME}/.auth" ]; then
    source "${HOME}/.auth"
fi

start_tmux () {
    if [ -z "$TMUX" ]; then
        tmux attach || tmux
    fi
}

# always start tmux in remote sessions
if [ -n "${SSH_CLIENT}" ]; then
    export PS1="%m ${PS1}"
    start_tmux
# do not start tmux if we have no X11 session
elif [ "$KERNEL" = "Linux" ] && [ -z "$DISPLAY" ]; then
    # echo "should probably startx, no?"
# start tmux by default
else
    start_tmux
fi

if [ -f "${HOME}/.dockerenv" ]; then
    source "${HOME}/.dockerenv"
fi

# added by travis gem
[ -f "${HOME}/.travis/travis.sh" ] && source "${HOME}/.travis/travis.sh"
