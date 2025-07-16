implement_xclip() {
    if [ -e "${HOME}/.local/bin/xclip" ]; then
        return
    fi
    echo "Creating fake xclip in ~/.local/bin/xclip"
    cat <<EOF > "${HOME}/.local/bin/xclip"
#!/bin/sh
if  [ -p /dev/stdin ]; then
    cat - > /dev/clipboard
fi
EOF
}


main() {
    export DISPLAY=":0"
    implement_xclip
}
