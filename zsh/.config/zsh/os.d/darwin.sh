osx_ssh_agent() {
    # if no agent file and no ssh identities
    if ! [ -f "/tmp/zsh-ssh-agent" ] && ! ssh-add -l > /dev/null 2>&1; then
        # add our keychain identities
        # and signal that we have an "agent"
        ssh-add -q  \
            --apple-load-keychain \
            && touch "/tmp/zsh-ssh-agent"
    fi
}

setup_local_macports() {
    local macports_man_path="${MACPORTS_HOME}/share/man"

    # OSX /usr/local/bin/patch (conflicts with gnu patch)
    # sometimes takes precedence over /usr/bin/patch
    # instead, explicitly install gpatch and add to our PATH
    if [ -d "${MACPORTS_HOME}/libexec/gnubin" ]; then
        append_path "${MACPORTS_HOME}/libexec/gnubin" prepend
    fi

    append_path "${MACPORTS_HOME}/bin" prepend
    append_path "${MACPORTS_HOME}/sbin" prepend

    if [ -d "${MACPORTS_HOME}/share/fzf/shell" ]; then
        fzf_zsh_bindings="${MACPORTS_HOME}/share/fzf/shell/key-bindings.zsh"
        fzf_zsh_completion="${MACPORTS_HOME}/share/fzf/shell/completion.zsh"
    fi

    # macports_additional_manpages
    if ! [ -d "$macports_man_path" ]; then
        echo "WARN: no manpages in $macports_man_path"
        return
    else
        MANPATH="${MACPORTS_HOME}/share/man:${MANPATH}"
    fi
}


setup_pip_bins_osx() {
    if [ -n "$TMUX" ]; then
        return
    fi

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
    source "$python_version_file"

    append_path "${HOME}/Library/Python/${PYTHON_MAJOR_VERSION}/bin"
}


check_osx_version_string() {
    # apple silicon macbook won't be old (EG: < Sonoma / 14)
    if [ "$CPU_ARCHITECTURE" = "arm64" ]; then
        return
    fi

    local major minor patch

    IFS='.' read -r major minor patch <<< "$(sw_vers --productVersion)"

    if [ -e "${XDG_DATA_HOME}/terminfo" ]; then
        export TERMINFO_DIRS=$TERMINFO_DIRS:$HOME/.local/share/terminfo
    else
        echo "CRITICAL: tmux-256color needs a manual patch"
        echo "https://gpanders.com/blog/the-definitive-guide-to-using-tmux-256color-on-macos/"
        echo "https://archive.ph/4daXH"
    fi
}


osxmain() {
    check_osx_version_string
    setup_pip_bins_osx

    # we moved MACPORTS_HOME to "${XDG_STATE_HOME}/macports"
    if [ -n "$MACPORTS_HOME" ] && [ -d "$MACPORTS_HOME" ]; then
        setup_local_macports
    # still support global installation
    elif [ -d "/opt/local/bin" ] || [ -d "/opt/local/sbin" ]; then
        append_path "/opt/local/sbin" "prepend"
        append_path "/opt/local/bin" "prepend"

        if [ -d "/opt/local/share/fzf/shell" ]; then
            fzf_zsh_bindings="/opt/local/share/fzf/shell/key-bindings.zsh"
            fzf_zsh_completion="/opt/local/share/fzf/shell/completion.zsh"
        fi
    fi

    osx_ssh_agent

    # for terraform + tfenv
    if [ "$CPU_ARCHITECTURE" = "arm64" ]; then
        # TFENV_ARCH="$CPU_ARCHITECTURE"
        TFENV_CONFIG_DIR="${HOME}/.config/tfenv"
    fi

    # stupid rancher / docker CLI fix
    # add Rancher Desktop... no way to move this
    if [ -d "${HOME}/.rd/bin" ]; then
        append_path "${HOME}/.rd/bin"
        # docker expects a socket in /var/run/docker.sock
        # which is a protected dir on modern OSX (14+)
        if [ -e "${HOME}/.rd/docker.sock" ]; then
            export DOCKER_HOST="unix://${HOME}/.rd/docker.sock"
        fi

        # we also do not want this environment variable as it points
        # docker to the default socket
        unset DOCKER_CONFIG
    fi

}

osxmain
