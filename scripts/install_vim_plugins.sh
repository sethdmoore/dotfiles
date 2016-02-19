#!/bin/sh

# 79 characters baby, vim author/plugin, comma delim
vim_plugins="fatih/vim-go,tpope/vim-repeat,tpope/vim-surround,nvie/vim-flake8"
vim_plugins="${vim_plugins},jiangmiao/auto-pairs"
vim_plugins="${vim_plugins},ntpeters/vim-better-whitespace"

# Note the abuse of local IFS here. stolen with love from
# blog.isonoe.net/post/2010/10/01/Split-a-string-by-character(s)-in-POSIX-shell
function plugin_split() {
    local author plugin IFS
    plugin="${1}"
    IFS='/:'
    read -r author plugin_name <<EOF
$plugin
EOF
}

# pathogen paths
mkdir -p "${HOME}/.vim/autoload" \
    "${HOME}/.vim/bundle" \
    "${HOME}/.vim/colors" && \
curl -LSso "${HOME}/.vim/autoload/pathogen.vim" "https://tpo.pe/pathogen.vim"

# sourcerer colors
curl -LSso "${HOME}/.vim/colors/sourcerer.vim" \
    "https://raw.githubusercontent.com/xero/sourcerer/master/sourcerer.vim"

# IFS abuse for pathogen bundles
IFS=',:'
for plugin_gh_path in $vim_plugins; do
    plugin_split $plugin_gh_path
    git clone "git@github.com:${plugin_gh_path}.git" \
        "${HOME}/.vim/bundle/${plugin_name}"
done
