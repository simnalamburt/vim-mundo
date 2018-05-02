" ============================================================================
" File:        mundo.vim
" Description: vim global plugin to visualize your undo tree
" Maintainer:  Hyeon Kim <simnalamburt@gmail.com>
" License:     GPLv2+ -- look it up.
" Notes:       Much of this code was thiefed from Mercurial, and the rest was
"              heavily inspired by scratch.vim and histwin.vim.
"
" ============================================================================


"{{{ Init
let s:save_cpo = &cpo
set cpo&vim
if v:version < '703'"{{{
    function! s:MundoDidNotLoad()
        echohl WarningMsg|echomsg "Mundo unavailable: requires Vim 7.3+"|echohl None
    endfunction
    command! -nargs=0 MundoToggle call s:MundoDidNotLoad()
    finish
endif"}}}

call mundo#util#init()


let s:has_supported_python = 0
if g:mundo_prefer_python3 && has('python3')"{{{
    let s:has_supported_python = 2
elseif has('python')"
    let s:has_supported_python = 1
elseif has('python3')"
    let s:has_supported_python = 2
endif

if !s:has_supported_python
    function! s:MundoDidNotLoad()
        echohl WarningMsg|echomsg "Mundo requires Vim to be compiled with Python 2.4+"|echohl None
    endfunction
    command! -nargs=0 MundoToggle call s:MundoDidNotLoad()
    finish
endif"}}}


let s:plugin_path = escape(expand('<sfile>:p:h'), '\')
let s:auto_preview_timer = -1
let s:auto_preview_line = -1
"}}}

"{{{ Mundo utility functions

function! s:MundoSetupPythonPath()"{{{
    if g:mundo_python_path_setup == 0
        let g:mundo_python_path_setup = 1
        call s:MundoPython('sys.path.insert(1, "'. s:mundo_path .'")')
        call s:MundoPython('sys.path.insert(1, "'. s:mundo_path .'/mundo")')
    end
endfunction"}}}

" Moves to the first window in the current tab corresponding to expr. Accepts
" an integer buffer number or a string file-pattern; for a detailed description
" see :h bufname. Returns 1 if successful, 0 otherwise.
function! s:MundoGoToWindowForBuffer(expr)"{{{
    if bufwinnr(bufnr(a:expr)) != -1
        exe bufwinnr(bufnr(a:expr)) . "wincmd w"
        return 1
    endif

    return 0
endfunction"}}}

" Similar to MundoGoToWindowForBuffer, but considers windows in all tabs.
" Prioritises matches in the current tab.
function! s:MundoGoToWindowForBufferGlobal(expr)"{{{
    if s:MundoGoToWindowForBuffer(a:expr)
        return 1
    endif

    let l:bufWinIDs = win_findbuf(bufnr(a:expr))

    if len(l:bufWinIDs) <= 0
        return 0
    endif

    call win_gotoid(l:bufWinIDs[0])
    return 1
endfunction"}}}

" Returns True if the graph or preview windows are open in the current tab.
function! s:MundoIsVisible()"{{{
    return bufwinnr(bufnr("__Mundo__")) != -1 ||
                \ bufwinnr(bufnr("__Mundo_Preview__")) != -1
endfunction"}}}

function! s:MundoInlineHelpLength()"{{{
    if g:mundo_help
        return 10
    else
        return 0
    endif
endfunction"}}}}}

"{{{ Mundo buffer settings

function! s:MundoMapGraph()"{{{
    exec 'nnoremap <script> <silent> <buffer> ' . g:mundo_map_move_older . " :<C-u>call <sid>MundoPython('MundoMove(1,'. v:count .')')<CR>"
    exec 'nnoremap <script> <silent> <buffer> ' . g:mundo_map_move_newer . " :<C-u>call <sid>MundoPython('MundoMove(-1,'. v:count .')')<CR>"
    nnoremap <script> <silent> <buffer> <CR>          :call <sid>MundoPython('MundoRevert()')<CR>
    nnoremap <script> <silent> <buffer> o             :call <sid>MundoPython('MundoRevert()')<CR>
    nnoremap <script> <silent> <buffer> <down>        :<C-u>call <sid>MundoPython('MundoMove(1,'. v:count .')')<CR>
    nnoremap <script> <silent> <buffer> <up>          :<C-u>call <sid>MundoPython('MundoMove(-1,'. v:count .')')<CR>
    nnoremap <script> <silent> <buffer> J             :<C-u>call <sid>MundoPython('MundoMove(1,'. v:count .',True,True)')<CR>
    nnoremap <script> <silent> <buffer> K             :<C-u>call <sid>MundoPython('MundoMove(-1,'. v:count .',True,True)')<CR>
    nnoremap <script> <silent> <buffer> gg            gg:<C-u>call <sid>MundoPython('MundoMove(1,'. v:count .')')<CR>
    nnoremap <script> <silent> <buffer> P             :call <sid>MundoPython('MundoPlayTo()')<CR>
    nnoremap <script> <silent> <buffer> d             :call <sid>MundoPython('MundoRenderPatchdiff()')<CR>
    nnoremap <script> <silent> <buffer> i             :call <sid>MundoPython('MundoRenderToggleInlineDiff()')<CR>
    nnoremap <script> <silent> <buffer> /             :call <sid>MundoPython('MundoSearch()')<CR>
    nnoremap <script> <silent> <buffer> n             :call <sid>MundoPython('MundoNextMatch()')<CR>
    nnoremap <script> <silent> <buffer> N             :call <sid>MundoPython('MundoPrevMatch()')<CR>
    nnoremap <script> <silent> <buffer> p             :call <sid>MundoPython('MundoRenderChangePreview()')<CR>
    nnoremap <script> <silent> <buffer> r             :call <sid>MundoPython('MundoRenderPreview()')<CR>
    nnoremap <script> <silent> <buffer> ?             :call <sid>MundoPython('MundoToggleHelp()')<CR>
    nnoremap <script> <silent> <buffer> q             :call <sid>MundoClose()<CR>
    cabbrev  <script> <silent> <buffer> q             call <sid>MundoClose()
    cabbrev  <script> <silent> <buffer> quit          call <sid>MundoClose()
    nnoremap <script> <silent> <buffer> <2-LeftMouse> :call <sid>MundoMouseDoubleClick()<CR>
endfunction"}}}

function! s:MundoMapPreview()"{{{
    nnoremap <script> <silent> <buffer> q     :call <sid>MundoClose()<CR>
    cabbrev  <script> <silent> <buffer> q     call <sid>MundoClose()
    cabbrev  <script> <silent> <buffer> quit  call <sid>MundoClose()
endfunction"}}}

function! s:MundoSettingsGraph()"{{{
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=Mundo
    setlocal nolist
    setlocal nonumber
    setlocal norelativenumber
    setlocal nowrap
    call s:MundoSyntaxGraph()
    call s:MundoMapGraph()
endfunction"}}}

function! s:MundoSettingsPreview()"{{{
    setlocal buftype=nofile
    setlocal bufhidden=hide
    setlocal noswapfile
    setlocal nobuflisted
    setlocal nomodifiable
    setlocal filetype=MundoDiff
    setlocal syntax=diff
    setlocal nonumber
    setlocal norelativenumber
    setlocal nowrap
    setlocal foldlevel=20
    setlocal foldmethod=diff
    call s:MundoMapPreview()
endfunction"}}}

function! s:MundoSyntaxGraph()"{{{
    let b:current_syntax = 'mundo'

    syn match MundoCurrentLocation '@'
    syn match MundoHelp '\v^".*$'
    syn match MundoNumberField '\v\[[0-9]+\]'
    syn match MundoNumber '\v[0-9]+' contained containedin=MundoNumberField
    syn region MundoDiff start=/\v<ago> / end=/$/
    syn match MundoDiffAdd '\v\+[^+-]+\+' contained containedin=MundoDiff
    syn match MundoDiffDelete '\v-[^+-]+-' contained containedin=MundoDiff

    hi def link MundoCurrentLocation Keyword
    hi def link MundoHelp Comment
    hi def link MundoNumberField Comment
    hi def link MundoNumber Identifier
    hi def link MundoDiffAdd DiffAdd
    hi def link MundoDiffDelete DiffDelete
endfunction"}}}

"}}}

"{{{ Mundo buffer/window management

function! s:MundoResizeBuffers(backto)"{{{
    call s:MundoGoToWindowForBuffer('__Mundo__')
    exe "vertical resize " . g:mundo_width

    call s:MundoGoToWindowForBuffer('__Mundo_Preview__')
    exe "resize " . g:mundo_preview_height

    exe a:backto . "wincmd w"
endfunction"}}}

function! s:MundoOpenGraph()"{{{
    let existing_mundo_buffer = bufnr("__Mundo__")

    if existing_mundo_buffer == -1
        call assert_true(s:MundoGoToWindowForBuffer('__Mundo_Preview__'))
        exe "new __Mundo__"
        set fdm=manual
        if g:mundo_preview_bottom
            if g:mundo_right
                wincmd L
            else
                wincmd H
            endif
        endif
        call s:MundoResizeBuffers(winnr())
    else
        let existing_mundo_window = bufwinnr(existing_mundo_buffer)

        if existing_mundo_window != -1
            if winnr() != existing_mundo_window
                exe existing_mundo_window . "wincmd w"
            endif
        else
            call s:MundoGoToWindowForBuffer('__Mundo_Preview__')
            if g:mundo_preview_bottom
                if g:mundo_right
                    exe "botright vsplit +buffer" . existing_mundo_buffer
                else
                    exe "topleft vsplit +buffer" . existing_mundo_buffer
                endif
            else
                exe "split +buffer" . existing_mundo_buffer
            endif
            call s:MundoResizeBuffers(winnr())
        endif
    endif
    if exists("g:mundo_tree_statusline")
        let &l:statusline = g:mundo_tree_statusline
    endif
endfunction"}}}

function! s:MundoOpenPreview()"{{{
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

" Quits *all* open Mundo graph and preview windows.
function! s:MundoClose() abort "{{{
    let [l:tabid, l:winid] = win_id2tabwin(win_getid())

    while s:MundoGoToWindowForBufferGlobal('__Mundo__')
        quit
    endwhile

    while s:MundoGoToWindowForBufferGlobal('__Mundo_Preview__')
        quit
    endwhile

    if win_gotoid(l:winid)
        return
    elseif l:tabid != 0 && l:tabid <= tabpagenr('$')
        execute 'normal! ' . l:tabid . 'gt'
    endif

    call s:MundoGoToWindowForBuffer(get(g:, 'mundo_target_n', -1))
endfunction"}}}

function! s:InitPythonModule(python)"{{{
    exe a:python .' import sys'
    exe a:python .' if sys.version_info[:2] < (2, 4): '.
                \ 'vim.command("let s:has_supported_python = 0")'
endfunction"}}}

" Returns 1 if the current buffer is a valid target buffer for Mundo, or a
" (falsy) string indicating the reason if otherwise.
function! s:MundoIsValidBuffer()"{{{
    if !&modifiable | return 'is not modifiable' | endif
    if &previewwindow | return 'is preview window' | endif
    if &buftype != '' && &buftype != 'acwrite' |
                \ return 'invalid buffer type "'.&buftype.'"' | endif
    return 1
endfunction "}}}

" }}}

" Open/reopen Mundo for the current buffer, initialising the python module if
" necessary.
function! s:MundoOpen() abort "{{{
    " Validate and target buffer, store buffer number & file
    let is_valid_reason = s:MundoIsValidBuffer()

    if ! is_valid_reason
        echom 'Current buffer ('.bufnr('').') is not a valid target for Mundo'.
                    \ ' (Reason: '.is_valid_reason.')'
        return
    endif

    let g:mundo_target_n = bufnr('')
    let g:mundo_target_f = @%

    " Close *all* existing Mundo windows
    call s:MundoClose()

    " Load python
    if !exists('g:mundo_py_loaded')
        " Add Mundo to python path
        call s:MundoSetupPythonPath()

        " Initialise python module
        if s:has_supported_python == 2
            exe 'py3file ' . escape(s:plugin_path, ' ') . '/mundo.py'
            call s:InitPythonModule('python3')
        else
            exe 'pyfile ' . escape(s:plugin_path, ' ') . '/mundo.py'
            call s:InitPythonModule('python')
        endif

        if !s:has_supported_python
            function! s:MundoDidNotLoad()
                echohl WarningMsg
                echomsg "Mundo unavailable: requires Vim 7.3+"
                echohl None
            endfunction

            command! -nargs=0 MundoToggle call s:MundoDidNotLoad()
            call s:MundoDidNotLoad()
            return
        endif

        let g:mundo_py_loaded = 1
    endif

    " Save `splitbelow` value and set it to default to avoid problems with
    " positioning new windows.
    let saved_splitbelow = &splitbelow
    let &splitbelow = 0

    call s:MundoOpenPreview()
"    exe bufwinnr(g:mundo_target_n) . "wincmd w"
    call s:MundoGoToWindowForBuffer(g:mundo_target_n)
    call s:MundoOpenGraph()

    call mundo#MundoRenderGraph()

    " Move cursor to the graph if the window was created
    if line('.') == 1
        call s:MundoPython('MundoMove(1, 1)')
    endif

    call mundo#MundoRenderPreview()

    " Restore `splitbelow` value.
    let &splitbelow = saved_splitbelow
endfunction"}}}

" This has to be outside of a function otherwise it just picks up the CWD
let s:mundo_path = escape( expand( '<sfile>:p:h' ), '\' )

function! s:MundoToggle()"{{{
    if s:MundoIsVisible()
        call s:MundoClose()
    else
        call s:MundoOpen()
    endif
endfunction"}}}

function! s:MundoShow()"{{{
    if !s:MundoIsVisible()
        call s:MundoOpen()
    endif
endfunction"}}}

function! s:MundoHide()"{{{
    call s:MundoSetupPythonPath()
    if s:MundoIsVisible()
        call s:MundoClose()
    endif
endfunction"}}}

"}}}

"{{{ Mundo mouse handling

function! s:MundoMouseDoubleClick()"{{{
    let start_line = getline('.')

    if stridx(start_line, '[') == -1
        return
    else
        call <sid>MundoPython('MundoRevert()')
    endif
endfunction"}}}

"}}}

"{{{ Mundo rendering

function! s:MundoPython(fn)"{{{
    if s:has_supported_python == 2
        exec "python3 ". a:fn
    else
        exec "python ". a:fn
    endif
endfunction"}}}

" Wrapper for MundoPython() that restores the window state and prevents other
" Mundo autocommands (with the exception of BufNewFile) from triggering.
function! s:MundoPythonRestoreView(fn)"{{{
    " Save current window and view information, ignore autocommands
    let currentWin  = winnr()
    let winView = winsaveview()
    let eventignorePrev = &eventignore
    set eventignore=CursorHold,CursorMoved,TextChanged,InsertLeave,BufLeave,
                \BufEnter

    call s:MundoPython(a:fn)

    " Restore ignored autocommands, window and view information
    silent exec 'set eventignore='.eventignorePrev
    execute currentWin .'wincmd w'
    call winrestview(winView)
endfunction"}}}

function! mundo#MundoRenderGraph()"{{{
    call s:MundoPythonRestoreView('MundoRenderGraph()')
endfunction"}}}

function! mundo#MundoRenderPreview()"{{{
    call s:MundoPythonRestoreView('MundoRenderPreview()')
endfunction"}}}

"}}}

"{{{ Misc

function! mundo#MundoToggle()"{{{
    call s:MundoToggle()
endfunction"}}}

function! mundo#MundoShow()"{{{
    call s:MundoShow()
endfunction"}}}

function! mundo#MundoHide()"{{{
    call s:MundoHide()
endfunction"}}}

" automatically reload Mundo buffer if open
function! s:MundoRefresh()"{{{
    " abort if Mundo is closed or cursor is in the preview window
    let mundoWin    = bufwinnr('__Mundo__')
    let mundoPreWin = bufwinnr('__Mundo_Preview__')
    let currentWin  = bufwinnr('%')

    if (mundoWin == -1) || (mundoPreWin == -1) || (mundoPreWin == currentWin)
        return
    endif

    " Handle normal refresh
    if get(g:, 'mundo_auto_preview_delay', 0) <= 0
        call mundo#MundoRenderGraph()

        if get(g:, 'mundo_auto_preview', 0) && (currentWin == mundoWin)
                    \ && mode() == 'n'
            call mundo#MundoRenderPreview()
        endif
        return
    endif

    " Handle delayed refresh
    call s:MundoRestartRefreshTimer()
endfunction"}}}

function! s:MundoRestartRefreshTimer()"{{{
    call s:MundoStopRefreshTimer()
    let s:auto_preview_timer = timer_start(
                \ get(g:, 'mundo_auto_preview_delay', 0),
                    \ function('s:MundoRefreshDelayed')
                \ )
endfunction"}}}

function! s:MundoStopRefreshTimer()"{{{
    if s:auto_preview_timer != -1
        call timer_stop(s:auto_preview_timer)
        let s:auto_preview_timer = -1
    endif
endfunction"}}}

function! s:MundoRefreshDelayed(...)"{{{
    " abort if Mundo is closed or cursor is in the preview window
    let mundoWin    = bufwinnr('__Mundo__')
    let mundoPreWin = bufwinnr('__Mundo_Preview__')
    let currentWin  = bufwinnr('%')

    if (mundoWin == -1) || (mundoPreWin == -1) || (mundoPreWin == currentWin)
        return
    endif

    call mundo#MundoRenderGraph()

    " Handle other windows
    if currentWin != mundoWin
        return
    endif

    " Handle graph window (__Mundo__)
    if s:auto_preview_line == line('.')
        return
    endif

    if mode() != 'n'
        call s:MundoRestartRefreshTimer()
        return
    endif

    let s:auto_preview_line = line('.')
    call mundo#MundoRenderPreview()
endfunction"}}}

augroup MundoAug"{{{
    autocmd!
    autocmd BufNewFile __Mundo__ call s:MundoSettingsGraph()
    autocmd BufNewFile __Mundo_Preview__ call s:MundoSettingsPreview()
    autocmd CursorHold,CursorMoved,TextChanged,InsertLeave *
                \ call s:MundoRefresh()
    autocmd BufLeave __Mundo__ call s:MundoStopRefreshTimer()
    autocmd BufEnter __Mundo__ let s:auto_preview_line = -1
augroup END"}}}

"}}}


let &cpo = s:save_cpo
unlet s:save_cpo
