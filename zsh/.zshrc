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

export PS1="%~ %(?.%{$fg[blue]%}►.%{$fg[red]%}►) %{$reset_color%}"
# export RPROMPT="$(date +%H:%M)"
export HISTSIZE=1000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
export GO15VENDOREXPERIMENT=1
export EDITOR="nvim"
# export VIMINIT="source ~/.config/vim/.vimrc"

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

# split returns the len of input s, use that as end of array
# basically see if Microsoft put their name in the kernel build
KERNEL_BUILD="$(uname -r | \
                awk '{l=split($0, k, "-");
                      print tolower(k[l])}')"

# WSL detection, otherwise kernel will be darwin || linux
if [ "$KERNEL_BUILD" = "microsoft" ]; then
    KERNEL="$KERNEL_BUILD"
else
    KERNEL="$(uname -s | \
              awk '{print tolower($0)}')"
fi

append_path() {
    local IFS path_iterator array_path appender match mode
    appender="${1}"
    mode="${2}"
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

    if [ "${mode}" = "prepend" ]; then
        export PATH="${appender}:$PATH"
    else
        export PATH="$PATH:${appender}"
    fi
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

if [ "$KERNEL" = "darwin" ]; then
    # append to zsh array 9_9
    MY_DOT_FILES+=(".rbenv_env" ".travis/travis.sh" ".dockerenv")
    append_path "/usr/local/sbin"
elif [ "$KERNEL" = "linux" ]; then
    FZF_ZSH_COMPLETION="/usr/share/fzf/completion.zsh"
    FZF_ZSH_BINDINGS="/usr/share/fzf/key-bindings.zsh"

    # connect to the ssh-agent sock
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
elif [ "$KERNEL" = "microsoft" ]; then
    FZF_ZSH_BINDINGS="${HOME}/.fzf/shell/key-bindings.zsh"
    FZF_ZSH_COMPLETION="${HOME}/.fzf/shell/key-bindings.zsh"
    # fix bad umask on WSL
    # https://www.turek.dev/post/fix-wsl-file-permissions/
    # https://github.com/Microsoft/WSL/issues/352
    if [ "$(umask)" = "000" ]; then
      umask 0022
    fi
fi

# fzf
if [ -f "$FZF_ZSH_COMPLETION" ] && [ -f "$FZF_ZSH_BINDINGS" ]; then
    source "$FZF_ZSH_BINDINGS"
    source "$FZF_ZSH_COMPLETION"
else
    NO_FZF=true
fi

# golang tools
if [ -d "${HOME}/dev/go" ]; then
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
    append_path "${HOME}/bin" "prepend"
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

run_ssh_agent() {
    ssh-agent -s > ~/.ssh/.agent 2>/dev/null
    . ~/.ssh/.agent >/dev/null
}

source_ssh_agent() {
    if [ "$KERNEL" != "microsoft" ]; then
        return
    fi

    agent_count="$(pgrep -c ssh-agent)"

    if [ "$agent_count" -eq "0" ]; then
        # start the agent
        printf -- "INFO: starting ssh-agent\n"
        run_ssh_agent
    elif [ "$agent_count" -gt "1" ]; then
        # too many agents
        echo "WARN: ${agent_count} ssh-agents found"
        killall ssh-agent 2>/dev/null
        run_ssh_agent
    elif [ "$agent_count" -eq "1" ]; then
        # source the running agent
        . ~/.ssh/.agent >/dev/null
    fi

    if ! agent_pid=$(
       pgrep ssh-agent
    ); then
        echo "ERROR: ssh-agent: not running"
    fi

    if [ "$SSH_AGENT_PID" -ne "$agent_pid" ]; then
        printf -- "WARN: SSH_AGENT_PID %s != %s\n" \
            $SSH_AGENT_PID $agent_pid
        killall ssh-agent
        run_ssh_agent
    fi
}

source_ssh_agent
