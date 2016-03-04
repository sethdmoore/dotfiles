#!/bin/sh
# So far, this script works on Linux, Mac OSX and Windows (cygwin / babun)

# dotfiles
FILE_LIST="$(git ls-tree  master --full-tree dot/ --name-only)"
for file in $FILE_LIST; do
  file=$(basename $file)
  cwd=$(echo $PWD | sed 's_scripts_dot_')
  #echo $cwd
  #echo $PWD/$file
  ln -vs "$cwd/$file" $HOME/$file
done

# . ./install_vim_plugins.sh
