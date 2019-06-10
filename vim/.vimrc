" #Section :general
set ruler
set backspace=2
set nocompatible
set incsearch
set hlsearch
set nu
set sessionoptions-=options
" fix backspace behavior
set backspace=indent,eol,start

" mouse mode is actually awesome
set mouse=a
" smooth mouse controls

if !has('nvim')
  set ttymouse=xterm2
endif

" only highlight on active windows
augroup CursorLine
  au!
  au VimEnter,WinEnter,BufWinEnter * setlocal cursorline
  au WinLeave * setlocal nocursorline
augroup END

" un-nerf your swap file
set viminfo='20,<1000

" #Section splits
" More 'natural' splits
set splitbelow
set splitright
set winheight=5
set winminheight=5

" dump swp / backup files in temp, instead of polluting local dirs
set backupdir=~/.vim/backup//
set directory^=~/.vim/swp//
set noundofile


" activates filetype detection / vim-plug does this
" filetype plugin indent on
" syntax on

" #Section :format
set et
set sw=4
set ts=4

autocmd FileType ruby setlocal sw=2 ts=2 et
autocmd FileType yaml setlocal sw=2 ts=2 et
autocmd FileType sh setlocal sw=2 ts=2 et
autocmd FileType python setlocal sw=4 ts=4 et
autocmd FileType go setlocal sw=4 ts=4 noet
autocmd FileType cs setlocal sw=4 ts=4 noet
autocmd FileType terraform setlocal commentstring=#%s


" Specify a directory for plugins
" - Avoid using standard Vim directory names like 'plugin'
call plug#begin('~/.vim/plugged')
    Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle'  }
    Plug 'nvie/vim-flake8'
    Plug 'jiangmiao/auto-pairs'
    Plug 'vim-syntastic/syntastic'
    Plug 'vim-scripts/Tabmerge'
    Plug 'ntpeters/vim-better-whitespace'
    Plug 'hashivim/vim-terraform'
    Plug 'tpope/vim-surround'
    Plug 'tpope/vim-repeat'
    Plug 'rodjek/vim-puppet'
    Plug 'michaeljsmith/vim-indent-object'
    Plug 'godlygeek/tabular'
    Plug 'dhruvasagar/vim-table-mode'
    if has('nvim')
      Plug 'OmniSharp/omnisharp-vim', { 'do': ':OmniSharpInstall'}
      Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
      Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
    else
      Plug 'fatih/vim-go'
      Plug 'OmniSharp/omnisharp-vim'
      " deoplete deps for pleb non-nvim users
      Plug 'Shougo/deoplete.nvim'
      Plug 'roxma/nvim-yarp'
      Plug 'roxma/vim-hug-neovim-rpc'
    endif
call plug#end()


" #Section :keybinds
" This unsets the 'last search pattern' register by hitting return
nnoremap <CR> :noh<CR><CR>

"Turn off default help bindings
nmap <F1> :echo<CR>
imap <F1> <C-o>:echo<CR>

"remap colon to semicolon
map ; :

" Fix up the split keybinds
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>


" #Section :plugins
" turn off horrendous 'folding' / collapsing of markdown
let g:vim_markdown_folding_disabled = 1
let g:terraform_align=1

" NERDTree is awkward to type
map <silent> <C-n> :NERDTreeFocus<CR>

" use deoplete
let g:deoplete#enable_at_startup = 1
" <TAB>: completion
" https://github.com/Shougo/deoplete.nvim/issues/816
"
" syntastic
let g:syntastic_cs_checkers = ['code_checker']

let g:OmniSharp_server_stdio = 1

nnoremap <C-_> :split<CR>
nnoremap <C-\> :vsplit<CR>

" Tabs with sane bindings
nnoremap <M-t> :tabnew<CR>
nnoremap <M-w> :q<CR>
" alt-{1..6} to switch tabs
for i in range(1,6)
  let key = 'map ' . '<M-' . i . '> ' . i . 'gt<CR>'
  execute key
endfor


" trash
command Curlfmt s/ -H / \\\r    -H /g

" best colors of all time
" https://github.com/xero/sourcerer.vim
colors sourcerer

" override sourcerer incorrectly removing syntax highlighting on CursorLine
hi CursorLine cterm=NONE ctermfg=NONE guifg=NONE
