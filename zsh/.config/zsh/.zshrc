# Profiling for when zshrc gets slow again
# zmodload zsh/zprof
autoload -U colors && colors
# add git autocomplete
autoload -Uz compinit && compinit

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
MY_DOT_FILES=(
    "${HOME}/.config/zsh/aliases"
    "${HOME}/.config/zsh/ENV"
    "${HOME}/.config/zsh/private_environment"
    "${HOME}/.config/zsh/private_aliases"
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


source_fzf() {
    # fzf
    if [ -f "$FZF_ZSH_COMPLETION" ] && [ -f "$FZF_ZSH_BINDINGS" ]; then
        source "$FZF_ZSH_BINDINGS"
        source "$FZF_ZSH_COMPLETION"
    else
        if ! command -v fzf &>/dev/null ; then
          NO_FZF=true
        fi
    fi
}


setup_path_additions() {
    # python3 -m pip install <module>
    # python3 -m pip install --user <module>
    if [ -d "${HOME}/.local/bin" ]; then
        append_path "${HOME}/.local/bin" "prepend"
    fi

    # macports disgustingly writes / creates ~/.zprofile -
    # ignoring the value of ZDOTDIR
    # this fixes macports
    if [ -d "/opt/local/bin" ] || [ -d "/opt/local/sbin" ]; then
        append_path "/opt/local/sbin" "prepend"
        append_path "/opt/local/bin" "prepend"
    fi
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

setup_ssh_agent() {
    if [ "$KERNEL" != "microsoft" ]; then
        return
    fi

    local windows_path="${HOME}/.config/zsh/windows.sh"

    if [ -e "$windows_path" ]; then
        . "$windows_path"
    else
        printf -- "ERROR: %s is missing. Stow zsh again\n" $windows_path
    fi

    source_ssh_agent
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
    if [ "$KERNEL" = "darwin" ]; then

        # write OSX version to tmp
        if ! [ -e "/tmp/osx_ver" ]; then
          sw_vers -productVersion  > /tmp/osx_ver
          cat /tmp/osx_ver | cut -d '.' -f1 > /tmp/osx_major_ver
        fi

        osx_ver="$(cat /tmp/osx_ver)"
        osx_major_ver="$(cat /tmp/osx_major_ver)"

        # append to zsh array 9_9
        if [ -d "/opt/local/share/fzf/shell" ]; then
            MY_DOT_FILES+=("/opt/local/share/fzf/shell/key-bindings.zsh" "/opt/local/share/fzf/shell/completion.zsh")
        fi

        if ! [ -f "/tmp/zsh-ssh-agent" ]; then
            if ! ssh-add -l > /dev/null 2>&1; then
                ssh-add --apple-load-keychain > /dev/null 2>&1
                touch "/tmp/zsh-ssh-agent"
            fi
        fi

        # sonoma (14+) fixes tmux-256color
        # this is for older macbooks
        if [ "$osx_major_ver" -lt "14" ]; then
            if [ -e "${XDG_DATA_HOME}/terminfo" ]; then
                export TERMINFO_DIRS=$TERMINFO_DIRS:$HOME/.local/share/terminfo
            else
                echo "CRITICAL: tmux-256color needs a manual patch"
                echo "https://gpanders.com/blog/the-definitive-guide-to-using-tmux-256color-on-macos/"
                echo "https://archive.ph/4daXH"
            fi
        fi

        setup_pip_bins_osx
    elif [ "$KERNEL" = "linux" ]; then
        FZF_ZSH_COMPLETION="/usr/share/fzf/completion.zsh"
        FZF_ZSH_BINDINGS="/usr/share/fzf/key-bindings.zsh"

        MY_DOT_FILES+=("$FZF_ZSH_COMPLETION" "$FZF_ZSH_BINDINGS")
        # connect to the ssh-agent sock
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
    elif [ "$KERNEL" = "mingw" ]; then
        export DISPLAY=":0"
        implement_xclip
    elif [ "$KERNEL" = "microsoft" ]; then
        FZF_ZSH_BINDINGS="${HOME}/.fzf/shell/key-bindings.zsh"
        FZF_ZSH_COMPLETION="${HOME}/.fzf/shell/key-bindings.zsh"

        MY_DOT_FILES+=("$FZF_ZSH_COMPLETION" "$FZF_ZSH_BINDINGS")
        # fix bad umask on WSL
        # https://www.turek.dev/post/fix-wsl-file-permissions/
        # https://github.com/Microsoft/WSL/issues/352
        if [ "$(umask)" = "000" ]; then
            umask 0022
        fi
        setup_ssh_agent
    fi
}

implement_xclip() {
    if [ -e "${HOME}/bin/xclip" ]; then
        return
    fi
    echo "Creating fake xclip in ~/bin/xclip"
    cat <<EOF > "${HOME}/bin/xclip"
#!/bin/sh
if  [ -p /dev/stdin ]; then
    cat - > /dev/clipboard
fi
EOF
}

setup_pip_bins_osx() {
    # set up pip path
    local awk_script="${HOME}/.config/zsh/get_python3_version.awk"
    local python_version_file="${LOCAL_ENV_DIR}/python3_version"
    # check if the python_version_file exists
    if [ ! -e "$python_version_file" ]; then
        # spit out "3.9" instead of "Python 3.9.x"
        if ! awk -f "$awk_script" > "$python_version_file"; then
            printf "ERROR: Couldn't write to %s!\n" $python_version_file
        fi
    fi
    . "$python_version_file"

    append_path "${HOME}/Library/Python/${PYTHON_MAJOR_VERSION}/bin"
}

set_editor() {
    if command -v nvim 2>&1 >/dev/null; then
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

    # create directories
    setup_workspace

    # write or read $LOCAL_ENV_DIR/kernel
    determine_kernel

    # tmux window pane PWD hack
    setup_precmd

    # append_path foo bar baz
    setup_path_additions

    # write or read PYTHON_MAJOR_VERSION for bins
    setup_os_specific_fixes

    # source our dots, should be second to last function
    # as we inject additional items per function
    source_dot_files

    # set EDITOR based on availability
    set_editor

    # determine whether we want tmux automatically started or not
    auto_start_tmux
}

main "$@"
# zprof
# ^ uncomment for profiling ^
