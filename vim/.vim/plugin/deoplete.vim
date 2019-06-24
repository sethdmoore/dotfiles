" deoplete-plugins/deoplete-go

" use deoplete
let g:deoplete#enable_at_startup = 0
" call deoplete#enable()
let g:deoplete#enable_ignore_case = 1
" call deoplete#custom#option('sources', { 'cs': ['omnisharp'], })
call deoplete#custom#option({
    \   'auto_complete_delay': 50,
    \   'auto_refresh_delay': 10,
    \   'smart_case': v:true,
    \   'omni_patterns': {
    \     'cs': '\w*',
    \   },
    \   'sources': { 'cs':     ['omnisharp', 'ultisnips', 'buffer', 'file'],
    \                'python': ['jedi', 'ultisnips', 'buffer', 'file'],
    \   },
    \ })

"    \ 'omni_patterns': {
"    \   'cs': '\w*',
"    \ },

"    \ 'sources': { 'cs':     ['omnisharp', 'ultisnips', 'buffer', 'file'],
"    \ 'sources': { 'cs':     ['cs', 'ultisnips', 'buffer', 'file'],

" omni_patterns rely on omnifunc with is *not* async
"    \ 'omni_patterns': {
"    \   'cs': '\w*',
"    \ },

" call deoplete#custom#var('omni', 'input_patterns', {
"     \ 'ruby': ['[^. *\t]\.\w*', '[a-zA-Z_]\w*::'],
"     \ 'java': '[^. *\t]\.\w*',
"     \ 'cs': '\w+|[^. *\t]\.\w*',
"     \ 'php': '\w+|[^. \t]->\w*|\w+::\w*',
"     \})

call deoplete#custom#option('min_pattern_length', 1)
let g:deoplete#auto_complete_start_length = 1

" call deoplete#enable_logging('DEBUG', '/home/seth/deoplete.log')
" autocmd VimEnter * call deoplete#initialize()
" autocmd InsertEnter * call deoplete#enable()

call deoplete#initialize()
autocmd VimEnter * call deoplete#enable()
