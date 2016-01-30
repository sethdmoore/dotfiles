#!/bin/sh
for file in $(git ls-tree master  ../dot/ --name-only); do
  file=$(basename $file)
  cwd=$(echo $PWD | sed 's_scripts_dot_')
  #echo $cwd
  #echo $PWD/$file
  ln -vs "$cwd/$file" $HOME/$file
done

# pathogen
mkdir -p "${HOME}/.vim/autoload" "${HOME}/.vim/bundle" "${HOME}/.vim/colors" && \
curl -LSso "${HOME}/.vim/autoload/pathogen.vim" "https://tpo.pe/pathogen.vim"

# sourcerer colors
curl -LSso "${HOME}/.vim/colors/sourcerer.vim" "https://raw.githubusercontent.com/xero/sourcerer/master/sourcerer.vim"

# pathogen bundles
git clone "git@github.com:fatih/vim-go.git" "${HOME}/.vim/bundle/vim-go"
git clone "git@github.com:tpope/vim-repeat.git" "${HOME}/.vim/bundle/vim-repeat"
git clone "git@github.com:tpope/vim-surround.git" "${HOME}/.vim/bundle/vim-surround"
git clone "git@github.com:jiangmiao/auto-pairs.git" "${HOME}/.vim/bundle/auto-pairs"
git clone "git@github.com:ntpeters/vim-better-whitespace.git" "${HOME}/.vim/bundle/vim-better-whitespace"
