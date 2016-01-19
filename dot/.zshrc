autoload -U colors && colors
bindkey -v
bindkey '^R' history-incremental-search-backward

export PS1="%n %~ %{$fg[blue]%}╠► %{$reset_color%}"
export HISTSIZE=1000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
export GO15VENDOREXPERIMENT=1
export EDITOR="$(which vim)"

source ~/.aliases

if [ -f "${HOME}/.auth" ]; then
    source "${HOME}/.auth"
fi

if [ -z "$TMUX" ]; then
    tmux attach || tmux
fi

if [ -f "${HOME}/.dockerenv" ]; then
    source "${HOME}/.dockerenv"
fi

# added by travis gem
[ -f "${HOME}/.travis/travis.sh" ] && source "${HOME}/.travis/travis.sh"
