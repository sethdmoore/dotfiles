" w0rp/ale
let g:ale_fixers = {
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'javascript': ['eslint'],
\   'json': ['fixjson'],
\}
" \   'json': ['jsonlint'],
" let g:ale_linters
