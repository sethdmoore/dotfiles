" Specify a directory for plugins
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')
    " COC explorer replaces
    Plug 'dhruvasagar/vim-zoom' " prefix-z style zooming
    " New statusline
    Plug 'liuchengxu/eleline.vim'
    " Plug 'severin-lemaignan/vim-minimap'
    " Plug 'nvie/vim-flake8' " python pep8
    Plug 'posva/vim-vue' " vue file highlighting
    " Plug 'jiangmiao/auto-pairs' " match parens and quotes
    Plug 'wfxr/minimap.vim'
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
    " Plug 'w0rp/ale' " async linting
    Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' } " fuzzy finder in vim
    Plug 'junegunn/fzf.vim' " see above
    " Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' } " rock solid vim stuff
    Plug 'OmniSharp/omnisharp-vim' " develop C# anywhere
    Plug 'neoclide/coc.nvim', {'branch': 'release'}
call plug#end()
