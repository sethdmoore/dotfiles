" activates filetype detection
filetype plugin indent on
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

autocmd FileType ruby setlocal sw=2 ts=2 et
autocmd FileType sh setlocal sw=2 ts=2 et
autocmd FileType python setlocal sw=4 ts=4 et
autocmd FileType go setlocal sw=4 ts=4 noet

command Curlfmt s/ -H / \\\r    -H /g

" dump swp / backup files in temp, instead of polluting local dirs
set backupdir=~/.vim/backup//
set directory=~/.vim/swp//

" turn off horrendous ''folding'' / collapsing of markdown
let g:vim_markdown_folding_disabled = 1

"Turn off help
nmap <F1> :echo<CR>
imap <F1> <C-o>:echo<CR>

"This unsets the "last search pattern" register by hitting return
nnoremap <CR> :noh<CR><CR>

"remap colon to semicolon
map ; :

colors sourcerer
"hi CursorLine   cterm=NONE ctermbg=darkred ctermfg=white guibg=darkred guifg=white
