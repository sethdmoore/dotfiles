" #Section :keybinds
" This unsets the 'last search pattern' register by hitting return
nnoremap <CR> :noh<CR><CR>

"Turn off default help bindings
nmap <F1> :echo<CR>
imap <F1> <C-o>:echo<CR>

" Exec the current line as shell command
nmap <F6> :exec '!'.getline('.')

" allow writing to any file with sudo
" EG: you opened a file you don't own and forgot sudo prefix
cmap w!! w !sudo tee > /dev/null %

"remap colon to semicolon
map ; :

map <Leader>! <C-W>T<CR>

" replace word under cursor with something new
:nnoremap <Leader>s :s/\<<C-r><C-w>\>//g<Left><Left>

" #Section :splits
" Fix up the split keybinds
" nnoremap <C-_> :split<CR>
nnoremap <Leader>- :split<CR>
nnoremap <Leader>\ :vsplit<CR>

" Rotate splits
" vertical
nmap <Leader>v :wincmd H<CR>
" horizontal
nmap <Leader>h :wincmd J<CR>

" nnoremap <C-\> :vsplit<CR>
" C-hjkl for navigating splits
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Tabs with sane bindings
" alt-t new tab
nnoremap <M-t> :tabnew<CR>
" alt-w close tab
nnoremap <M-w> :q<CR>
" alt-{1..6} to switch tabs
for i in range(1,6)
  let key = 'map ' . '<M-' . i . '> ' . i . 'gt<CR>'
  execute key
endfor



" Plugin specific bindings
function! PluginBindings()
    " NERDTree is awkward to type
    "if exists(":CocCommand explorer")
    map <silent> <C-n> :CocCommand explorer<CR>
    "endif

    if exists(":Tabmerge")
        map <Leader>m :Tabmerge<CR>
    endif

    if hasmapto('<Plug>(zoom-toggle)')
	    nmap <Leader>z <Plug>(zoom-toggle)
    endif
endfunction

au VimEnter * call PluginBindings()
