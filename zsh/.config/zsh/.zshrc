# Profiling for when zshrc gets slow again
# zmodload zsh/zprof
# autoload -U colors && colors
# add git autocomplete
autoload -Uz compinit colors && compinit && colors

setopt inc_append_history
setopt share_history
setopt interactivecomments
# setopt hist_find_no_dups
setopt hist_ignore_dups
setopt hist_ignore_space

zstyle ':completion:*' menu select
zmodload zsh/complist

export EDITOR

export GOPATH="${HOME}/dev/go"
export GOBIN="${HOME}/.local/bin"

export HISTSIZE=1000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
export HISTIGNORESPACE=1
export LOCAL_ENV_DIR="${HOME}/.config/local_environment"
export KERNEL
export CPU_ARCHITECTURE

export CURLOPT_TIMEOUT=60
export GPGKEY='4096R/1CF9C381'
export GPG_TTY=$(tty)

export TFENV_ARCH
export TFENV_CONFIG_DIR

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
MY_DOT_FILES=(
    "${ZDOTDIR}/aliases"
    "${ZDOTDIR}/ENV"
    "${ZDOTDIR}/private_environment"
    "${ZDOTDIR}/private_aliases"
)

set_ps1() {
    # only display PWD when outside of tmux
    if [ -z "$TMUX" ]; then
        export PS1="%~ %(?.%{$fg[blue]%}►.%{$fg[red]%}►) %{$reset_color%}"
    else
        export PS1="%(?.%{$fg[blue]%}►.%{$fg[red]%}►) %{$reset_color%}"
    fi
}


set_ls_colors() {
    # LS_COLORS
    if [ -e "$HOME/.config/ls/lesscolors" ]; then
        eval $(dircolors -b "$HOME/.config/ls/lesscolors")
    fi
}

determine_kernel() {
    local kernel="${HOME}/.config/local_environment/kernel"
    local arch="${HOME}/.config/local_environment/arch"
    if [ -e "$kernel" ]; then
        . "$kernel"
        return
    fi

    # use grep like a sane person,
    # instead of awk substring splitting to determine ms kernel
    parsed_kernel="$(uname -s)"
    if echo "$parsed_kernel" | grep -qi "microsoft"; then
        KERNEL='microsoft'
    elif echo "$parsed_kernel" | grep -qi "ming"; then
        KERNEL='mingw'
    else
        KERNEL="$(uname -s \
                  | awk '{print tolower($0)}')"
    fi
    echo export KERNEL="${KERNEL}" > "${kernel}"
}

determine_arch() {
    local arch="${HOME}/.config/local_environment/arch"
    if [ -e "$arch" ]; then
        . "$arch"
        return
    fi

    # this appears to be portable
    echo "CPU_ARCHITECTURE=$(uname -m)" > "$arch"
}

append_path() {
    # Rebuild PATH and prevent duplicate entries
    if [ -n "$TMUX" ]; then
        # don't re-run this function in a tmux session
        # inherit PATH from parent shell
        return
    fi

    local IFS path_iterator array_path appender mode path_copy
    appender="${1}"
    mode="${2}"

    # use this variable to store a temporary PATH
    path_copy=""

    IFS=':'

    # convert PATH to an array
    array_path=("${(@s/:/)PATH}")
    for path_iterator in $array_path; do
        # if the iterated item is a duplicate of the appender argument
        # skip this cycle of the loop. we will append it below
        if [ "${path_iterator}" = "${appender}" ]; then
            continue
        fi

        # if path_copy is an empty string (no join function)
        if [ -z "$path_copy" ]; then
            path_copy="$path_iterator"
        # otherwise continue reconstructing PATH
        else
            path_copy="${path_copy}:${path_iterator}"
        fi
    done

    unset IFS

    # finally add the path to our copy
    if [ "${mode}" = "prepend" ]; then
        path_copy="${appender}:$path_copy"
    else
        path_copy="$path_copy:${appender}"
    fi

    # protect against catastrophic failure
    if [ -z "$path_copy" ]; then
        echo "ERROR: path_copy is empty somehow"
        return
    fi

    # set PATH to the copy
    PATH="$path_copy"
}

source_dot_files() {
    local dot
    # don't need IFS abuse since we're using arraytype
    for dot in $MY_DOT_FILES; do
        if [ -e "${dot}" ]; then
            source "${dot}"
        fi
    done
}

start_tmux() {
    if [ -n "$TMUX" ]; then
        return
    fi

    # determine if we have any tmux sessions
    if tmux list-sessions >/dev/null 2>&1; then
        tmux attach -d
    else
        tmux new-session
    fi
}

setup_workspace() {
    if ! [ -e "${LOCAL_ENV_DIR}" ]; then
        mkdir -p "${LOCAL_ENV_DIR}"
    fi

    if ! [ -e "${HOME}/dev/go/src" ]; then
        mkdir -p "${HOME}/dev/go/src"
    fi

    if ! [ -e "${HOME}/.local/state/zsh" ]; then
        mkdir -p "${HOME}/.local/state/zsh"
    fi
}

setup_path_additions() {
    # Don't modify PATH inside of tmux
    # it is inherited from the parent shell
    if [ -n "$TMUX" ]; then
        return
    fi

    # python3 -m pip install <module>
    # python3 -m pip install --user <module>
    if [ -d "${HOME}/.local/bin" ]; then
        append_path "${HOME}/.local/bin" "prepend"
    fi
}

setup_conda() {
    if [ -f "/usr/etc/profile.d/conda.sh" ]; then
        source "/usr/etc/profile.d/conda.sh"
    fi
}

# this function will check to see if nvm has installed node versions
# if so, it will prepend the latest node version to the PATH
setup_nvm_node() {
    local node_versions
    local latest_node_version
    local node_path_cache

    if [ -n "$TMUX" ]; then
        return
    fi

    # NVM_DIR not set or doesn't exist
    if [ -z "$NVM_DIR" ] || ! [ -d "$NVM_DIR" ]; then
        return
    # NVM never used
    elif ! [ -d "$NVM_DIR/versions/node" ]; then
        return
    fi

    node_versions=$(ls -1 "$NVM_DIR/versions/node")

    # no installed node versions
    if [ -z "$node_versions" ]; then
        return
    fi

    latest_node_version=$(echo $node_versions \
        | sort -t "." -k1,1n -k2,2n -k3,3n \
        | head -n1 \
    )

    append_path \
        "${NVM_DIR}/versions/node/${latest_node_version}/bin" \
        "prepend"
}


auto_start_tmux() {
    # always start tmux in remote sessions
    if [ -n "${SSH_CLIENT}" ]; then
        # user@host if we're remote
        export PS1="%* %n@%m ${PS1}"
        start_tmux
    else
        # insert timestamp
        export PS1="%* %n ${PS1}"
    fi
}


setup_precmd() {
    # tmux pane title display
    precmd() {
        if [ -n "$TMUX" ]; then
            # PROMPT_COMMAND, show PWD (relative to $HOME on window title
            printf "\033]2;#[fg=colour39]${PWD/$HOME/~}#[default]\033\\"
        fi
    }
}

setup_os_specific_fixes() {
    local fzf_zsh_bindings
    local fzf_zsh_completion
    local os_fix_script
    os_fix_script="${ZDOTDIR}/os.d/${KERNEL}.sh"

    if [ -n "$TMUX" ]; then
        return
    elif [ -e "$os_fix_script" ]; then
        . "$os_fix_script"
    fi
}

set_editor() {
    if command -v astronvim_editor 2>&1 >/dev/null; then
        # keep nvim from leaking metadata and secrets all over the place
        # honestly, if we're invoking $EDITOR directly, it's probably
        # git commit or something that shouldn't be stored
        EDITOR="$(which astronvim_editor)"
    elif command -v nvim 2>&1 >/dev/null; then
        EDITOR="$(which nvim)"
    elif command -v vim 2>&1 >/dev/null; then
        EDITOR="$(which vim)"
    elif command -v vi 2>&1 >/dev/null; then
        echo "WARN: only vi is available. This is anarchy!"
        EDITOR="$(which vi)"
    else
        echo "WARN: no vi or vim variants detected."
    fi
}

main() {
    # decide whether to bother people
    # prereq
    set_ps1

    # involves icky eval
    set_ls_colors

    # source our dots first
    source_dot_files

    # create directories
    setup_workspace

    # write or read $LOCAL_ENV_DIR/kernel
    determine_kernel

    # write or read $LOCAL_ENV_DIR/arch
    determine_arch

    # tmux window pane PWD hack
    setup_precmd

    # append_path foo bar baz
    setup_path_additions

    # `conda init` hardcoded to modify ~/.bashrc 9_9
    setup_conda

    # always use the latest node version
    setup_nvm_node

    # write or read PYTHON_MAJOR_VERSION for bins
    setup_os_specific_fixes

    # set EDITOR based on availability
    set_editor

    # determine whether we want tmux automatically started or not
    auto_start_tmux
}

main "$@"
# zprof
# ^ uncomment for profiling ^
