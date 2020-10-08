" deoplete-plugins/deoplete-go

" use deoplete
let g:deoplete#enable_at_startup = 1
let g:deoplete#enable_ignore_case = 1
call deoplete#custom#option({
    \   'auto_complete_delay': 20,
    \   'auto_refresh_delay': 5,
    \   'min_pattern_length': 2,
    \   'smart_case': v:true,
    \   'sources': {
    \      '_':      ['neosnippets'],
    \      'python': ['jedi', 'ultisnips', 'buffer', 'file'],
    \      'cs':     ['omnisharp', 'ultisnips', 'buffer', 'file'],
    \      'go':     ['ultisnips', 'buffer', 'file'],
    \   },
    \   'omni_patterns': {
    \     'cs': ['\w\w', '\w\.'],
    \     'go': ['\w\w', '\w\.'],
    \   },
    \ })

call deoplete#custom#source('omnisharp', 'rank', 999)
call deoplete#custom#source('go', 'converters', ['converter_auto_paren'])
"    omni_patterns: {'cs': ['\w', '\w\.']}  <= matches both word<> and word.<>
"    \     'go': ['\w\w', '\w\.'],
" let g:deoplete#sources#go#gocode_binary = $GOPATH.'/bin/gocode'
" let g:deoplete#sources#go#sort_class = ['package', 'func', 'type', 'var', 'const']


" debuggin
" call deoplete#custom#option('profile', v:true)
" call deoplete#enable_logging('DEBUG', '~/deoplete.log')
let g:neopairs#enable = 1
imap <expr><TAB> pumvisible() ? "\<C-n>" : (neosnippet#expandable_or_jumpable() ? "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>") 


call deoplete#enable()
autocmd VimEnter * call deoplete#initialize()
