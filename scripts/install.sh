#!/bin/sh
# So far, this script works on Linux, Mac OSX and Windows (cygwin / babun)

# dotfiles
for file in $(git ls-tree master  ../dot/ --name-only); do
  file=$(basename $file)
  cwd=$(echo $PWD | sed 's_scripts_dot_')
  #echo $cwd
  #echo $PWD/$file
  ln -vs "$cwd/$file" $HOME/$file
done

. ./install_vim_plugins.sh
