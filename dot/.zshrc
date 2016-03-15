export KERNEL="$(uname -s)"

autoload -U colors && colors
bindkey -v
bindkey '^R' history-incremental-search-backward

export PS1="%~ %(?.%{$fg[blue]%}╠►.%{$fg[red]%}╠►) %{$reset_color%}"
# export RPROMPT="$(date +%H:%M)"
export HISTSIZE=1000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
export GO15VENDOREXPERIMENT=1
export EDITOR="vim"

# zshrc executed without POSIX compat
# use array type (http://zsh.sourceforge.net/FAQ/zshfaq03.html)
MY_DOT_FILES=(".aliases" ".auth")

# deprecated
check_path() {
    local IFS p array_path

    IFS=':'
    array_path=("${(@s/:/)PATH}")
    for p in $array_path; do
        printf "${p}\n"
    done
}

append_path() {
    local IFS p array_path appender match
    appender=$1
    match="false"

    IFS=':'
    array_path=("${(@s/:/)PATH}")
    for p in $array_path; do
        if [ "${p}" = "${appender}" ]; then
            printf "Duplicate PATH entry: ${p}\n"
            return
        fi
    done

    PATH="${PATH}:${appender}"
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


if [ ! -d "${HOME}/go" ]; then
    printf "Creating GOPATH: ${HOME}/go\n"
    mkdir -p "${HOME}/go"
fi


if [ "$KERNEL" = "Darwin" ]; then
    # append to zsh array 9_9
    MY_DOT_FILES+=(".rbenv_env" ".travis/travis.sh" ".dockerenv")
    # export PATH="${PATH}:/usr/local/sbin"
    append_path "/usr/local/sbin"
fi

# golang tools
if [ -d "${HOME}/go/bin" ]; then
    append_path "${HOME}/go/bin"
    # this directory will be created later
    export GOPATH="${HOME}/go"
fi

source_dot_files

# check_path

# always start tmux in remote sessions
if [ -n "${SSH_CLIENT}" ]; then
    # user@host if we're remote
    export PS1="%* %n@%m ${PS1}"
    start_tmux
# do not start tmux if we have no X11 session
elif [ "$KERNEL" = "Linux" ] && [ -z "$DISPLAY" ]; then
    # insert timestamp
    export PS1="%* %n ${PS1}"
# start tmux by default
else
    # insert timestamp
    export PS1="%* %n ${PS1}"
    start_tmux
fi
