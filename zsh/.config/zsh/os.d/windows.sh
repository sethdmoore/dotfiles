setup_ssh_agent() {
    local windows_path="${ZDOTDIR}/.config/zsh/windows.sh"

    if [ -e "$windows_path" ]; then
        . "$windows_path"
    else
        printf -- "ERROR: %s is missing. Stow zsh again\n" $windows_path
    fi

    source_ssh_agent
}

main() {
    fzf_zsh_bindings="${HOME}/.fzf/shell/key-bindings.zsh"
    fzf_zsh_completion="${HOME}/.fzf/shell/key-bindings.zsh"

    # fix bad umask on WSL
    # https://www.turek.dev/post/fix-wsl-file-permissions/
    # https://github.com/Microsoft/WSL/issues/352
    if [ "$(umask)" = "000" ]; then
        umask 0022
    fi
    setup_ssh_agent
}

main
