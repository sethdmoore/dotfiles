" Specify a directory for plugins
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')
    Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle'  }
    Plug 'nvie/vim-flake8'
    Plug 'jiangmiao/auto-pairs'
    Plug 'vim-scripts/Tabmerge'
    Plug 'ntpeters/vim-better-whitespace'
    Plug 'hashivim/vim-terraform'
    Plug 'tpope/vim-surround'
    Plug 'tpope/vim-repeat'
    Plug 'rodjek/vim-puppet'
    Plug 'michaeljsmith/vim-indent-object'
    Plug 'godlygeek/tabular'
    Plug 'dhruvasagar/vim-table-mode'
    Plug 'ervandew/supertab'
    Plug 'SirVer/ultisnips'
    Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
    Plug 'w0rp/ale'
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
    Plug 'junegunn/fzf.vim'
    Plug 'deoplete-plugins/deoplete-go', { 'do': 'make' }
    Plug 'deoplete-plugins/deoplete-jedi'
    Plug 'OmniSharp/omnisharp-vim'
    if has('nvim')
      Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
    else
      " deoplete deps for pleb non-nvim users
      Plug 'Shougo/deoplete.nvim'
      Plug 'roxma/nvim-yarp'
      Plug 'roxma/vim-hug-neovim-rpc'
    endif
call plug#end()
