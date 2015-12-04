" activates filetype detection
filetype plugin indent on
"filetype plugin on
syntax on

set backspace=indent,eol,start

set et
set sw=4
set ts=4
set ruler
set backspace=2
set nocompatible
set incsearch
set hlsearch
set nu
set sessionoptions-=options

"This unsets the "last search pattern" register by hitting return
nnoremap <CR> :noh<CR><CR>

colors sourcerer
"hi CursorLine   cterm=NONE ctermbg=darkred ctermfg=white guibg=darkred guifg=white

execute pathogen#infect()

