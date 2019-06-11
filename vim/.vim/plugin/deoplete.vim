" deoplete-plugins/deoplete-go

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
"
autocmd InsertEnter * call deoplete#enable()
