#!/bin/sh
#echo $0
for file in $(git ls-tree master  ../dot/ --name-only); do
  file=$(basename $file)
  cwd=$(echo $PWD | sed 's_scripts_dot_')
  #echo $cwd
  #echo $PWD/$file
  ln -vs "$cwd/$file" $HOME/$file
done
