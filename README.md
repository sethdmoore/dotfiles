# DOTFILES
## Introduction
Dotfiles are managed GNU stow.  
Clone this repository directory into $HOME  
When you want to use an application configuration, simply:  
```sh
cd $HOME/dotfiles
stow $PROGRAM
```
EG:   
```sh
$ cd $HOME/dotfiles && stow vim
```

Stow will create all symbolic links / directories automatically for you.
It's magic.
It automatically handles directory conflict by physically creating the 
directories if necessary and creating top-level symlinks.

## Caveats
Any application configs with a "\_root" suffix require root as well as stow's 
--target="/" flag. EG:  
```sh
sudo stow -t / lemonbar_root
```

Most of the time it symlinks into either /usr/local/{sbin,bin} or /etc/$PROGRAM
