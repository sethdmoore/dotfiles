#!/bin/sh
#echo $0
for file in $(git ls-tree master  ../dot/ --name-only); do
  file=$(basename $file)
  #echo $PWD/$file
  ln -vs "$PWD/$file" $HOME/$file
done
