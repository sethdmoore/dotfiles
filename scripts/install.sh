#!/bin/bash
echo $0
for file in $(git ls-tree master  ../ --name-only); do
  echo $(basename $file)
done
