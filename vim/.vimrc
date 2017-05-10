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

" only highlight on active windows
augroup CursorLine
  au!
  au VimEnter,WinEnter,BufWinEnter * setlocal cursorline
  au WinLeave * setlocal nocursorline
augroup END


" More 'natural' splits
set splitbelow
set splitright

" dump swp / backup files in temp, instead of polluting local dirs
set backupdir=~/.vim/backup//
set directory=~/.vim/swp//
set noundofile

" activates filetype detection
filetype plugin indent on
syntax on

" #Section :format
set et
set sw=4
set ts=4

autocmd FileType ruby setlocal sw=2 ts=2 et
autocmd FileType sh setlocal sw=2 ts=2 et
autocmd FileType python setlocal sw=4 ts=4 et
autocmd FileType go setlocal sw=4 ts=4 noet

" #Section :plugins
" turn off horrendous 'folding' / collapsing of markdown
let g:vim_markdown_folding_disabled = 1

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

nnoremap <C-_> :split<CR>
nnoremap <C-\> :vsplit<CR>


" trash
command Curlfmt s/ -H / \\\r    -H /g


" best colors of all time
" https://github.com/xero/sourcerer.vim
colors sourcerer

" override sourcerer incorrectly removing syntax highlighting on CursorLine
hi CursorLine cterm=NONE ctermfg=NONE guifg=NONE
