" Specify a directory for plugins
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')
    " COC explorer replaces
    " Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle'  } " filesystem tree
    Plug 'dhruvasagar/vim-zoom' " prefix-z style zooming
    " Plug 'nvie/vim-flake8' " python pep8
    Plug 'posva/vim-vue' " vue file highlighting
    "Plug 'jiangmiao/auto-pairs' " match parens and quotes
    Plug 'vim-scripts/Tabmerge' " like tmux join-pane
    Plug 'ntpeters/vim-better-whitespace' " highlight ugly trailing whitespace
    Plug 'hashivim/vim-terraform' " highlight support for terraform
    Plug 'tpope/vim-surround' " surround visual mode with () \"\" and ''
    Plug 'tpope/vim-repeat' " better repeat support (.), repeat anything
    Plug 'rodjek/vim-puppet' " puppet highlighting
    Plug 'michaeljsmith/vim-indent-object' " better indenting
    Plug 'godlygeek/tabular' " line up ya text like it's ruby
    Plug 'dhruvasagar/vim-table-mode' " leader-t-m for MD table support
    Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }, 'for': ['markdown', 'vim-plug']}
    " Plug 'ervandew/supertab' " do crazy shit with tab
    " Plug 'SirVer/ultisnips' " code snips, needs set up
    " Plug 'w0rp/ale' " async linting
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' } " fuzzy finder in vim
    Plug 'junegunn/fzf.vim' " see above
    " Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' } " rock solid vim stuff
    Plug 'OmniSharp/omnisharp-vim' " develop C# anywhere
    " try COC.vim
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
call plug#end()
