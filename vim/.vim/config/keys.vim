" #Section :keybinds
" This unsets the 'last search pattern' register by hitting return
nnoremap <CR> :noh<CR><CR>

"Turn off default help bindings
nmap <F1> :echo<CR>
imap <F1> <C-o>:echo<CR>

"remap colon to semicolon
map ; :

" #Section :splits
" Fix up the split keybinds
nnoremap <C-_> :split<CR>
nnoremap <C-\> :vsplit<CR>
" C-hjkl for navigating splits
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>

" Tabs with sane bindings
nnoremap <M-t> :tabnew<CR>
nnoremap <M-w> :q<CR>
" alt-{1..6} to switch tabs
for i in range(1,6)
  let key = 'map ' . '<M-' . i . '> ' . i . 'gt<CR>'
  execute key
endfor



" Plugin specific bindings
function! PluginBindings()
    " NERDTree is awkward to type
    if exists(":NERDTree")
        map <silent> <C-n> :NERDTreeFocus<CR>
    endif
endfunction

au VimEnter * call PluginBindings()
