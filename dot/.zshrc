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
MY_DOT_FILES=(".aliases" ".auth")

if [ "$KERNEL" = "Darwin" ]; then
    # append to zsh array 9_9
    MY_DOT_FILES+=(".rbenv_env" ".travis/travis.sh" ".dockerenv")
    export PATH="${PATH}:/usr/local/sbin"
fi

# golang tools
if [ -d "${HOME}/go/bin" ]; then
    PATH="${PATH}:${HOME}/go/bin"
fi


check_path() {
    local IFS p

    IFS=':'
    for p in $PATH; do
    done
}

source_dot_files() {
    local dot
    # don't need IFS abuse since we're using arraytype
    for dot in $MY_DOT_FILES; do
        if [ -f "${HOME}/${dot}" ]; then
            source "${HOME}/${dot}"
        fi
    done
}

start_tmux () {
    if [ -z "$TMUX" ]; then
        tmux attach || tmux
    fi
}

source_dot_files
check_path

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
