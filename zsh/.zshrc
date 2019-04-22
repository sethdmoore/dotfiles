autoload -U colors && colors
# add git autocomplete
autoload -Uz compinit && compinit

setopt inc_append_history
setopt share_history
setopt interactivecomments
# setopt hist_find_no_dups
setopt hist_ignore_dups

zstyle ':completion:*' menu select
zmodload zsh/complist

# export PATH="$HOME/bin:$PATH"

export KERNEL="$(uname -s)"
export PS1="%~ %(?.%{$fg[blue]%}►.%{$fg[red]%}►) %{$reset_color%}"
# export RPROMPT="$(date +%H:%M)"
export HISTSIZE=1000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
export GO15VENDOREXPERIMENT=1
export EDITOR="vim"

export CURLOPT_TIMEOUT=60
export GPGKEY='4096R/1CF9C381'
export GPG_TTY=$(tty)

#
# bindings
#

bindkey -v
bindkey '^R' history-incremental-search-backward
bindkey -v '^?' backward-delete-char 
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char
bindkey -M menuselect 'j' vi-down-line-or-history

# zshrc executed without POSIX compat
# use array type (http://zsh.sourceforge.net/FAQ/zshfaq03.html)
MY_DOT_FILES=(".aliases" ".auth" ".private_environment")

append_path() {
    local IFS path_iterator array_path appender match
    appender="${1}"
    match="false"

    IFS=':'

    array_path=("${(@s/:/)PATH}")
    for path_iterator in $array_path; do
        if [ "${path_iterator}" = "${appender}" ]; then
            # printf "Duplicate PATH entry: ${path_iterator}\n"
            return
        fi
    done
    unset IFS

    export PATH="$PATH:${appender}"
}

source_dot_files() {
    local dot
    # don't need IFS abuse since we're using arraytype
    for dot in $MY_DOT_FILES; do
        if [ -e "${HOME}/${dot}" ]; then
            source "${HOME}/${dot}"
        fi
    done
}

start_tmux() {
    if [ -n "$TMUX" ]; then
        return
    fi

    # determine if we have any tmux sessions
    tmux list-sessions > /dev/null
    HAS_SESSION=$?

    # determine if any clients are attached
    if [ "$HAS_SESSION" -eq 0 ]; then
        tmux attach -d
    else
        tmux new-session
    fi
}


if [ ! -d "${HOME}/dev/go" ]; then
    printf "Creating GOPATH: ${HOME}/go\n"
    mkdir -p "${HOME}/dev/go/src"
fi

if [ ! -d "${HOME}/.vim" ]; then
    printf "Creating .vim: ${HOME}/.vim\n"
    mkdir -p "${HOME}/.vim"
fi

if [ ! -d "${HOME}/.vim/backup" ]; then
    printf "Creating vim backup: ${HOME}/.vim/backup\n"
    mkdir -p "${HOME}/.vim/backup"
fi

if [ ! -d "${HOME}/.vim/swp" ]; then
    printf "Creating vim swap: ${HOME}/.vim/swp\n"
    mkdir -p "${HOME}/.vim/swp"
fi

if [ "$KERNEL" = "Darwin" ]; then
    # append to zsh array 9_9
    MY_DOT_FILES+=(".rbenv_env" ".travis/travis.sh" ".dockerenv")
    append_path "/usr/local/sbin"
elif [ "$KERNEL" = "Linux" ]; then
    FZF_ZSH_COMPLETION="/usr/share/fzf/completion.zsh"
    FZF_ZSH_BINDINGS="/usr/share/fzf/key-bindings.zsh"

    # connect to the ssh-agent sock
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

    # fzf
    if [ -f "$FZF_ZSH_COMPLETION" ] && [ -f "$FZF_ZSH_BINDINGS" ]; then
        source "$FZF_ZSH_BINDINGS"
        source "$FZF_ZSH_COMPLETION"
    else
        printf -- "WTF \n"
        cat "$FZF_ZSH_COMPLETION"
        NO_FZF=true
    fi
fi

# golang tools
if [ -d "${HOME}/go" ]; then
    # this directory will be created later
    export GOPATH="${HOME}/dev/go"

    if [ -d "${GOPATH}/bin" ]; then
        append_path "${GOPATH}/bin"
    fi
fi

# if golang is installed, add go bins to PATH
if [ -d "/usr/local/go" ] && [ -d "/usr/local/go/bin" ]; then
    append_path "/usr/local/go/bin"
fi

if [ -d "${HOME}/bin" ]; then
    append_path "${HOME}/bin"
fi

source_dot_files

# always start tmux in remote sessions
if [ -n "${SSH_CLIENT}" ]; then
    # user@host if we're remote
    export PS1="%* %n@%m ${PS1}"
    start_tmux
# do not start tmux if we have no X11 session
elif [ "$KERNEL" = "Linux" ] && [ -z "$DISPLAY" ]; then
    # insert timestamp
    export PS1="%* %n ${PS1}"
else
    # insert timestamp
    export PS1="%* %n ${PS1}"
    # start_tmux
fi

if [ ! "$KERNEL" = "Linux" ]; then
    if [ -f ~/.fzf.zsh ]; then
        source ~/.fzf.zsh
    else
        NO_FZF=true
    fi
fi

# less colors
if [ -e "$HOME/.config/ls/lesscolors" ]; then
    eval $(dircolors -b "$HOME/.config/ls/lesscolors")
fi

if [ "$NO_FZF" ]; then
    printf -- "NOTE: fzf is missing, please install with your pkg manager\n"
fi
