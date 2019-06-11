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
    Plug 'ervandew/supertab'
    Plug 'SirVer/ultisnips'
    if has('nvim')
      Plug 'OmniSharp/omnisharp-vim'
      Plug 'w0rp/ale'
      Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
      Plug 'junegunn/fzf.vim'
      Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
      Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
      Plug 'deoplete-plugins/deoplete-go', { 'do': 'make' }
    else
      Plug 'fatih/vim-go'
      Plug 'OmniSharp/omnisharp-vim'
      Plug 'w0rp/ale'
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
let g:deoplete#enable_at_startup = 0
" call deoplete#enable()
let g:deoplete#enable_ignore_case = 1
" call deoplete#custom#option('sources', { 'cs': ['omnisharp'], })
call deoplete#custom#option({
    \ 'auto_complete_delay': 200,
    \ 'smart_case': v:true,
    \ 'sources': { 'cs': ['cs', 'ultisnips', 'buffer', 'file'], }
    \ })


call deoplete#custom#option('omni_patterns', {
    \ 'cs': '\w*',
    \})
" let g:deoplete#auto_complete_start_length = 0
" let g:deoplete#sources#cs = ['omni', 'file', 'buffer', 'ultisnips']

"Super tab settings - uncomment the next 4 lines
let g:SuperTabDefaultCompletionType = 'context'
let g:SuperTabContextDefaultCompletionType = "<c-x><c-o>"
let g:SuperTabDefaultCompletionTypeDiscovery = ["&omnifunc:<c-x><c-o>","&completefunc:<c-x><c-n>"]
let g:SuperTabClosePreviewOnPopupClose = 1


let g:UltiSnipsExpandTrigger="<C-j>"

" syntastic
let g:syntastic_cs_checkers = ['code_checker']


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


let g:OmniSharp_highlight_types = 2
let g:OmniSharp_selector_ui = 'fzf'
let g:OmniSharp_server_stdio = 1
let g:OmniSharp_want_snippet = 1
let g:OmniSharp_timeout = 5
let g:ale_linters = { 'cs': ['OmniSharp'] }
set completeopt=longest,menuone,preview
autocmd FileType cs setlocal omnifunc=OmniSharp#Complete

augroup omnisharp_commands
    autocmd!

    " Show type information automatically when the cursor stops moving
    autocmd CursorHold *.cs call OmniSharp#TypeLookupWithoutDocumentation()

    " The following commands are contextual, based on the cursor position.
    autocmd FileType cs nnoremap <buffer> gd :OmniSharpGotoDefinition<CR>
    autocmd FileType cs nnoremap <buffer> <Leader>fi :OmniSharpFindImplementations<CR>
    autocmd FileType cs nnoremap <buffer> <Leader>fs :OmniSharpFindSymbol<CR>
    autocmd FileType cs nnoremap <buffer> <Leader>fu :OmniSharpFindUsages<CR>


    " Finds members in the current buffer
    autocmd FileType cs nnoremap <buffer> <Leader>fm :OmniSharpFindMembers<CR>

    autocmd FileType cs nnoremap <buffer> <Leader>fx :OmniSharpFixUsings<CR>
    autocmd FileType cs nnoremap <buffer> <Leader>tt :OmniSharpTypeLookup<CR>
    autocmd FileType cs nnoremap <buffer> <Leader>dc :OmniSharpDocumentation<CR>
    autocmd FileType cs nnoremap <buffer> <C-\> :OmniSharpSignatureHelp<CR>
    autocmd FileType cs inoremap <buffer> <C-\> <C-o>:OmniSharpSignatureHelp<CR>

    " Navigate up and down by method/property/field
    autocmd FileType cs nnoremap <buffer> <C-k> :OmniSharpNavigateUp<CR>
    autocmd FileType cs nnoremap <buffer> <C-j> :OmniSharpNavigateDown<CR>

    " Find all code errors/warnings for the current solution and populate the quickfix window
    autocmd FileType cs nnoremap <buffer> <Leader>cc :OmniSharpGlobalCodeCheck<CR>
augroup END

" Contextual code actions (uses fzf, CtrlP or unite.vim when available)
nnoremap <Leader><Space> :OmniSharpGetCodeActions<CR>
" Run code actions with text selected in visual mode to extract method
xnoremap <Leader><Space> :call OmniSharp#GetCodeActions('visual')<CR>

" Rename with dialog
nnoremap <Leader>nm :OmniSharpRename<CR>
nnoremap <F2> :OmniSharpRename<CR>
" Rename without dialog - with cursor on the symbol to rename: `:Rename newname`
command! -nargs=1 Rename :call OmniSharp#RenameTo("<args>")

nnoremap <Leader>cf :OmniSharpCodeFormat<CR>

" Start the omnisharp server for the current solution
nnoremap <Leader>ss :OmniSharpStartServer<CR>
nnoremap <Leader>sp :OmniSharpStopServer<CR>




autocmd InsertEnter * call deoplete#enable()
