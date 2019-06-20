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

" I hate this
set nofoldenable

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


" #Section :format
set et
set sw=4
set ts=4
autocmd FileType ruby setlocal sw=2 ts=2 et
autocmd FileType yaml setlocal sw=2 ts=2 et
autocmd FileType sh setlocal sw=2 ts=2 et
autocmd FileType python setlocal sw=4 ts=4 et
autocmd FileType go setlocal sw=4 ts=4 noet
autocmd FileType cs setlocal sw=4 ts=4 et
autocmd FileType vim setlocal sw=4 ts=4 et
autocmd FileType terraform setlocal commentstring=#%s

source ~/.vim/config/vim-plug.vim
source ~/.vim/config/keys.vim

" trash
command Curlfmt s/ -H / \\\r    -H /g

" best colors of all time
" https://github.com/xero/sourcerer.vim
colors sourcerer

" override sourcerer incorrectly removing syntax highlighting on CursorLine
hi CursorLine cterm=NONE ctermfg=NONE guifg=NONE
