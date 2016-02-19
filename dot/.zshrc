export KERNEL="$(uname -s)"

autoload -U colors && colors
bindkey -v
bindkey '^R' history-incremental-search-backward

export PS1="%n %~ %(?.%{$fg[blue]%}╠►.%{$fg[red]%}╠►) %{$reset_color%}"

export HISTSIZE=1000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
export GO15VENDOREXPERIMENT=1
export EDITOR="vim"
#export JAVA_HOME="/System/Library/Frameworks/JavaVM.framework/Versions/1.6/Home"
export GOPATH="${HOME}/go"

if [ "$KERNEL" = "Darwin" ]; then
    # set java 6 ...
    #PATH="${JAVA_HOME}/bin:${PATH}"
    # rbenv 9_9
    source "${HOME}/.rbenv_env"
fi

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
# start tmux by default
else
    start_tmux
fi

if [ -f "${HOME}/.dockerenv" ]; then
    source "${HOME}/.dockerenv"
fi

# added by travis gem
[ -f "${HOME}/.travis/travis.sh" ] && source "${HOME}/.travis/travis.sh"
