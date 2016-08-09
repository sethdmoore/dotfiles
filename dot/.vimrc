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
set noundofile
set sessionoptions-=options

" dump swp / backup files in temp
set backupdir=~/.vim/backup//
set directory=~/.vim/swp//

let g:vim_markdown_folding_disabled = 1

"Turn off help
nmap <F1> :echo<CR>
imap <F1> <C-o>:echo<CR>

"This unsets the "last search pattern" register by hitting return
nnoremap <CR> :noh<CR><CR>

colors sourcerer
"hi CursorLine   cterm=NONE ctermbg=darkred ctermfg=white guibg=darkred guifg=white

execute pathogen#infect()
