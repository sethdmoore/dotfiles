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
if [ ! -d "${HOME}/go" ]; then
    printf "Creating GOPATH: ${HOME}/go\n"
    mkdir -p "${HOME}/go"
fi
export GOPATH="${HOME}/go"

# zshrc executed without POSIX compat
# use array type (http://zsh.sourceforge.net/FAQ/zshfaq03.html)
MY_DOT_FILES=(".aliases" ".auth" ".dockerenv" ".travis/travis.sh")

source_dot_files() {
    local dot
    # don't need IFS abuse since we're using arraytype
    for dot in $MY_DOT_FILES; do
        if [ -f "${HOME}/${dot}" ]; then
            source "${HOME}/${dot}"
        fi
    done
}


if [ "$KERNEL" = "Darwin" ]; then
    source "${HOME}/.rbenv_env"
    source "${HOME}/.travis/travis.sh"
fi

if [ -f "${HOME}/.aliases" ]; then
    source "${HOME}/.aliases"
fi

if [ -f "${HOME}/.auth" ]; then
    source "${HOME}/.auth"
fi

if [ -f "${HOME}/.dockerenv" ]; then
    source "${HOME}/.dockerenv"
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

source_dot_files

# added by travis gem
# [ -f "${HOME}/.travis/travis.sh" ] && source "${HOME}/.travis/travis.sh"
