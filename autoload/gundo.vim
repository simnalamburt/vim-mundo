" ============================================================================
" File:        gundo.vim
" Description: vim global plugin to visualize your undo tree
" Maintainer:  Steve Losh <steve@stevelosh.com>
" License:     GPLv2+ -- look it up.
" Notes:       Much of this code was thiefed from Mercurial, and the rest was
"              heavily inspired by scratch.vim and histwin.vim.
"
" ============================================================================


"{{{ Init
let s:save_cpo = &cpo
set cpo&vim
if v:version < '703'"{{{
    function! s:GundoDidNotLoad()
        echohl WarningMsg|echomsg "Gundo unavailable: requires Vim 7.3+"|echohl None
    endfunction
    command! -nargs=0 GundoToggle call s:GundoDidNotLoad()
    finish
endif"}}}

call mundo#util#init()


let s:has_supported_python = 0
if g:mundo_prefer_python3 && has('python3')"{{{
    let s:has_supported_python = 2
elseif has('python')"
    let s:has_supported_python = 1
endif

if !s:has_supported_python
    function! s:GundoDidNotLoad()
        echohl WarningMsg|echomsg "Gundo requires Vim to be compiled with Python 2.4+"|echohl None
    endfunction
    command! -nargs=0 GundoToggle call s:GundoDidNotLoad()
    finish
endif"}}}


let s:plugin_path = escape(expand('<sfile>:p:h'), '\')
"}}}

"{{{ Gundo utility functions

function! s:GundoGoToWindowForBufferName(name)"{{{
    if bufwinnr(bufnr(a:name)) != -1
        exe bufwinnr(bufnr(a:name)) . "wincmd w"
        return 1
    else
        return 0
    endif
endfunction"}}}

function! s:GundoIsVisible()"{{{
    if bufwinnr(bufnr("__Mundo__")) != -1 || bufwinnr(bufnr("__Mundo_Preview__")) != -1
        return 1
    else
        return 0
    endif
endfunction"}}}

function! s:GundoInlineHelpLength()"{{{
    if g:mundo_help
        return 10
    else
        return 0
    endif
endfunction"}}}

"}}}

"{{{ Gundo buffer settings

function! s:GundoMapGraph()"{{{
    exec 'nnoremap <script> <silent> <buffer> ' . g:mundo_map_move_older . " :call <sid>GundoPython('GundoMove(1,'. v:count .')')<CR>"
    exec 'nnoremap <script> <silent> <buffer> ' . g:mundo_map_move_newer . " :call <sid>GundoPython('GundoMove(-1,'. v:count .')')<CR>"
    nnoremap <script> <silent> <buffer> <CR>          :call <sid>GundoPython('GundoRevert()')<CR>
    nnoremap <script> <silent> <buffer> o             :call <sid>GundoPython('GundoRevert()')<CR>
    nnoremap <script> <silent> <buffer> <down>        :call <sid>GundoPython('GundoMove(1,'. v:count .')')<CR>
    nnoremap <script> <silent> <buffer> <up>          :call <sid>GundoPython('GundoMove(-1,'. v:count .')')<CR>
    nnoremap <script> <silent> <buffer> J             :call <sid>GundoPython('GundoMove(1,'. v:count .',True,True)')<CR>
    nnoremap <script> <silent> <buffer> K             :call <sid>GundoPython('GundoMove(-1,'. v:count .',True,True)')<CR>
    nnoremap <script> <silent> <buffer> gg            gg:call <sid>GundoPython('GundoMove(1,'. v:count .')')<CR>
    nnoremap <script> <silent> <buffer> P             :call <sid>GundoPython('GundoPlayTo()')<CR>
    nnoremap <script> <silent> <buffer> d             :call <sid>GundoPython('GundoRenderPatchdiff()')<CR>
    nnoremap <script> <silent> <buffer> i             :call <sid>GundoPython('GundoRenderToggleInlineDiff()')<CR>
    nnoremap <script> <silent> <buffer> /             :call <sid>GundoPython('GundoSearch()')<CR>
    nnoremap <script> <silent> <buffer> n             :call <sid>GundoPython('GundoNextMatch()')<CR>
    nnoremap <script> <silent> <buffer> N             :call <sid>GundoPython('GundoPrevMatch()')<CR>
    nnoremap <script> <silent> <buffer> p             :call <sid>GundoPython('GundoRenderChangePreview()')<CR>
    nnoremap <script> <silent> <buffer> r             :call <sid>GundoPython('GundoRenderPreview()')<CR>
    nnoremap <script> <silent> <buffer> ?             :call <sid>GundoPython('GundoToggleHelp()')<CR>
    nnoremap <script> <silent> <buffer> q             :call <sid>GundoClose()<CR>
    cabbrev  <script> <silent> <buffer> q             call <sid>GundoClose()
    cabbrev  <script> <silent> <buffer> quit          call <sid>GundoClose()
    nnoremap <script> <silent> <buffer> <2-LeftMouse> :call <sid>GundoMouseDoubleClick()<CR>
endfunction"}}}

function! s:GundoMapPreview()"{{{
    nnoremap <script> <silent> <buffer> q     :call <sid>GundoClose()<CR>
    cabbrev  <script> <silent> <buffer> q     call <sid>GundoClose()
    cabbrev  <script> <silent> <buffer> quit  call <sid>GundoClose()
endfunction"}}}

function! s:GundoSettingsGraph()"{{{
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=gundo
    setlocal nolist
    setlocal nonumber
    setlocal norelativenumber
    setlocal nowrap
    call s:GundoSyntaxGraph()
    call s:GundoMapGraph()
endfunction"}}}

function! s:GundoSettingsPreview()"{{{
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=diff
    setlocal nonumber
    setlocal norelativenumber
    setlocal nowrap
    setlocal foldlevel=20
    setlocal foldmethod=diff
    call s:GundoMapPreview()
endfunction"}}}

function! s:GundoSyntaxGraph()"{{{
    let b:current_syntax = 'gundo'

    syn match GundoCurrentLocation '@'
    syn match GundoHelp '\v^".*$'
    syn match GundoNumberField '\v\[[0-9]+\]'
    syn match GundoNumber '\v[0-9]+' contained containedin=GundoNumberField
    syn region GundoDiff start=/\v<ago> / end=/$/
    syn match GundoDiffAdd '\v\+[^+-]+\+' contained containedin=GundoDiff
    syn match GundoDiffDelete '\v-[^+-]+-' contained containedin=GundoDiff

    hi def link GundoCurrentLocation Keyword
    hi def link GundoHelp Comment
    hi def link GundoNumberField Comment
    hi def link GundoNumber Identifier
    hi def link GundoDiffAdd DiffAdd
    hi def link GundoDiffDelete DiffDelete
endfunction"}}}

"}}}

"{{{ Gundo buffer/window management

function! s:GundoResizeBuffers(backto)"{{{
    call s:GundoGoToWindowForBufferName('__Mundo__')
    exe "vertical resize " . g:mundo_width

    call s:GundoGoToWindowForBufferName('__Mundo_Preview__')
    exe "resize " . g:mundo_preview_height

    exe a:backto . "wincmd w"
endfunction"}}}

function! s:GundoOpenGraph()"{{{
    let existing_gundo_buffer = bufnr("__Mundo__")

    if existing_gundo_buffer == -1
        call s:GundoGoToWindowForBufferName('__Mundo_Preview__')
        exe "new __Mundo__"
        set fdm=manual
        if g:mundo_preview_bottom
            if g:mundo_right
                wincmd L
            else
                wincmd H
            endif
        endif
        call s:GundoResizeBuffers(winnr())
    else
        let existing_gundo_window = bufwinnr(existing_gundo_buffer)

        if existing_gundo_window != -1
            if winnr() != existing_gundo_window
                exe existing_gundo_window . "wincmd w"
            endif
        else
            call s:GundoGoToWindowForBufferName('__Mundo_Preview__')
            if g:mundo_preview_bottom
                if g:mundo_right
                    exe "botright vsplit +buffer" . existing_gundo_buffer
                else
                    exe "topleft vsplit +buffer" . existing_gundo_buffer
                endif
            else
                exe "split +buffer" . existing_gundo_buffer
            endif
            call s:GundoResizeBuffers(winnr())
        endif
    endif
    if exists("g:mundo_tree_statusline")
        let &l:statusline = g:mundo_tree_statusline
    endif
endfunction"}}}

function! s:GundoOpenPreview()"{{{
    let existing_preview_buffer = bufnr("__Mundo_Preview__")

    if existing_preview_buffer == -1
        if g:mundo_preview_bottom
            exe "botright keepalt new __Mundo_Preview__"
        else
            if g:mundo_right
                exe "botright keepalt vnew __Mundo_Preview__"
            else
                exe "topleft keepalt vnew __Mundo_Preview__"
            endif
        endif
    else
        let existing_preview_window = bufwinnr(existing_preview_buffer)

        if existing_preview_window != -1
            if winnr() != existing_preview_window
                exe existing_preview_window . "wincmd w"
            endif
        else
            if g:mundo_preview_bottom
                exe "botright keepalt split +buffer" . existing_preview_buffer
            else
                if g:mundo_right
                    exe "botright keepalt vsplit +buffer" . existing_preview_buffer
                else
                    exe "topleft keepalt vsplit +buffer" . existing_preview_buffer
                endif
            endif
        endif
    endif
    if exists("g:mundo_preview_statusline")
        let &l:statusline = g:mundo_preview_statusline
    endif
endfunction"}}}

function! s:GundoClose()"{{{
    if s:GundoGoToWindowForBufferName('__Mundo__')
        quit
    endif

    if s:GundoGoToWindowForBufferName('__Mundo_Preview__')
        quit
    endif

    exe bufwinnr(g:mundo_target_n) . "wincmd w"
endfunction"}}}

function! s:GundoOpen()"{{{
    if !exists('g:mundo_py_loaded')
        if s:has_supported_python == 2 && g:mundo_prefer_python3
            exe 'py3file ' . escape(s:plugin_path, ' ') . '/gundo.py'
            python3 initPythonModule()
        else
            exe 'pyfile ' . escape(s:plugin_path, ' ') . '/gundo.py'
            python initPythonModule()
        endif

        if !s:has_supported_python
            function! s:GundoDidNotLoad()
                echohl WarningMsg|echomsg "Gundo unavailable: requires Vim 7.3+"|echohl None
            endfunction
            command! -nargs=0 GundoToggle call s:GundoDidNotLoad()
            call s:GundoDidNotLoad()
            return
        endif

        let g:mundo_py_loaded = 1
    endif

    " Save `splitbelow` value and set it to default to avoid problems with
    " positioning new windows.
    let saved_splitbelow = &splitbelow
    let &splitbelow = 0

    call s:GundoOpenPreview()
    exe bufwinnr(g:mundo_target_n) . "wincmd w"
    call s:GundoOpenGraph()

    call s:GundoPython('GundoRenderGraph()')
    call s:GundoPython('GundoRenderPreview()')

    " Restore `splitbelow` value.
    let &splitbelow = saved_splitbelow
endfunction"}}}

" This has to be outside of a function otherwise it just picks up the CWD
let s:gundo_path = escape( expand( '<sfile>:p:h' ), '\' )

function! s:GundoToggle()"{{{
    if g:mundo_python_path_setup == 0
        let g:mundo_python_path_setup = 1
        call s:GundoPython('sys.path.insert(1, "'. s:gundo_path .'")')
        call s:GundoPython('sys.path.insert(1, "'. s:gundo_path .'/mundo")')
    end
    if s:GundoIsVisible()
        call s:GundoClose()
    else
        let g:mundo_target_n = bufnr('')
        let g:mundo_target_f = @%
        call s:GundoOpen()
    endif
endfunction"}}}

function! s:GundoShow()"{{{
    if !s:GundoIsVisible()
        let g:mundo_target_n = bufnr('')
        let g:mundo_target_f = @%
        call s:GundoOpen()
    endif
endfunction"}}}

function! s:GundoHide()"{{{
    if s:GundoIsVisible()
        call s:GundoClose()
    endif
endfunction"}}}

"}}}

"{{{ Gundo mouse handling

function! s:GundoMouseDoubleClick()"{{{
    let start_line = getline('.')

    if stridx(start_line, '[') == -1
        return
    else
        call <sid>GundoPython('GundoRevert()')
    endif
endfunction"}}}

"}}}

"{{{ Gundo rendering

function! s:GundoPython(fn)"{{{
    if s:has_supported_python == 2 && g:mundo_prefer_python3
        exec "python3 ". a:fn
    else
        exec "python ". a:fn
    endif
endfunction"}}}

"}}}

"{{{ Misc

function! gundo#GundoToggle()"{{{
    call s:GundoToggle()
endfunction"}}}

function! gundo#GundoShow()"{{{
    call s:GundoShow()
endfunction"}}}

function! gundo#GundoHide()"{{{
    call s:GundoHide()
endfunction"}}}

function! gundo#GundoRenderGraph()"{{{
    call s:GundoPython('GundoRenderGraph()')
endfunction"}}}

" automatically reload Gundo buffer if open
function! s:GundoRefresh()"{{{
  " abort when there were no changes

  let gundoWin    = bufwinnr('__Mundo__')
  let gundoPreWin = bufwinnr('__Mundo_Preview__')
  let currentWin  = bufwinnr('%')

  " abort if Gundo is closed or is current window
  if (gundoWin == -1) || (gundoPreWin == -1) || (gundoPreWin == currentWin)
    return
  endif

  let winView = winsaveview()
  :GundoRenderGraph

  " switch back to previous window
  execute currentWin .'wincmd w'
  call winrestview(winView)
endfunction"}}}

augroup GundoAug
    autocmd!
    autocmd BufNewFile __Mundo__ call s:GundoSettingsGraph()
    autocmd BufNewFile __Mundo_Preview__ call s:GundoSettingsPreview()
    autocmd CursorHold * call s:GundoRefresh()
    autocmd CursorMoved * call s:GundoRefresh()
    autocmd BufEnter * let b:gundoChangedtick = 0
augroup END

"}}}


let &cpo = s:save_cpo
unlet s:save_cpo
