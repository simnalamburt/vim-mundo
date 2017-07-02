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
"}}}

"{{{ Mundo utility functions

function! s:MundoSetupPythonPath()"{{{
    if g:mundo_python_path_setup == 0
        let g:mundo_python_path_setup = 1
        call s:MundoPython('sys.path.insert(1, "'. s:mundo_path .'")')
        call s:MundoPython('sys.path.insert(1, "'. s:mundo_path .'/mundo")')
    end
endfunction"}}}

function! s:MundoGoToWindowForBufferName(name)"{{{
    if bufwinnr(bufnr(a:name)) != -1
        exe bufwinnr(bufnr(a:name)) . "wincmd w"
        return 1
    else
        return 0
    endif
endfunction"}}}

function! s:MundoIsVisible()"{{{
    if bufwinnr(bufnr("__Mundo__")) != -1 || bufwinnr(bufnr("__Mundo_Preview__")) != -1
        return 1
    else
        return 0
    endif
endfunction"}}}

function! s:MundoInlineHelpLength()"{{{
    if g:mundo_help
        return 10
    else
        return 0
    endif
endfunction"}}}

"}}}

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
    call s:MundoGoToWindowForBufferName('__Mundo__')
    exe "vertical resize " . g:mundo_width

    call s:MundoGoToWindowForBufferName('__Mundo_Preview__')
    exe "resize " . g:mundo_preview_height

    exe a:backto . "wincmd w"
endfunction"}}}

function! s:MundoOpenGraph()"{{{
    let existing_mundo_buffer = bufnr("__Mundo__")

    if existing_mundo_buffer == -1
        call s:MundoGoToWindowForBufferName('__Mundo_Preview__')
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
            call s:MundoGoToWindowForBufferName('__Mundo_Preview__')
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

function! s:MundoClose()"{{{
    if s:MundoGoToWindowForBufferName('__Mundo__')
        quit
    endif

    if s:MundoGoToWindowForBufferName('__Mundo_Preview__')
        quit
    endif

    exe bufwinnr(g:mundo_target_n) . "wincmd w"
endfunction"}}}

function! s:InitPythonModule(python)
    exe a:python .' import sys'
    exe a:python .' if sys.version_info[:2] < (2, 4): vim.command("let s:has_supported_python = 0")'
endfunction


function! s:MundoOpen()"{{{
    if !exists('g:mundo_py_loaded')
        if s:has_supported_python == 2
            exe 'py3file ' . escape(s:plugin_path, ' ') . '/mundo.py'
            call s:InitPythonModule('python3')
        else
            exe 'pyfile ' . escape(s:plugin_path, ' ') . '/mundo.py'
            call s:InitPythonModule('python')
        endif

        if !s:has_supported_python
            function! s:MundoDidNotLoad()
                echohl WarningMsg|echomsg "Mundo unavailable: requires Vim 7.3+"|echohl None
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
    exe bufwinnr(g:mundo_target_n) . "wincmd w"
    call s:MundoOpenGraph()

    call s:MundoPython('MundoRenderGraph()')
    call s:MundoPython('MundoRenderPreview()')

    " Restore `splitbelow` value.
    let &splitbelow = saved_splitbelow
endfunction"}}}

" This has to be outside of a function otherwise it just picks up the CWD
let s:mundo_path = escape( expand( '<sfile>:p:h' ), '\' )

function! s:MundoToggle()"{{{
    call s:MundoSetupPythonPath()
    if s:MundoIsVisible()
        call s:MundoClose()
    else
        let g:mundo_target_n = bufnr('')
        let g:mundo_target_f = @%
        call s:MundoOpen()
    endif
endfunction"}}}

function! s:MundoShow()"{{{
    call s:MundoSetupPythonPath()
    if !s:MundoIsVisible()
        let g:mundo_target_n = bufnr('')
        let g:mundo_target_f = @%
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

function! mundo#MundoRenderGraph()"{{{
    call s:MundoPython('MundoRenderGraph()')
endfunction"}}}

" automatically reload Mundo buffer if open
function! s:MundoRefresh()"{{{
  " abort when there were no changes

  let mundoWin    = bufwinnr('__Mundo__')
  let mundoPreWin = bufwinnr('__Mundo_Preview__')
  let currentWin  = bufwinnr('%')

  " abort if Mundo is closed or is current window
  if (mundoWin == -1) || (mundoPreWin == -1) || (mundoPreWin == currentWin)
    return
  endif

  let winView = winsaveview()
  :MundoRenderGraph

  " switch back to previous window
  execute currentWin .'wincmd w'
  call winrestview(winView)
endfunction"}}}

augroup MundoAug
    autocmd!
    autocmd BufNewFile __Mundo__ call s:MundoSettingsGraph()
    autocmd BufNewFile __Mundo_Preview__ call s:MundoSettingsPreview()
    autocmd CursorHold * call s:MundoRefresh()
    autocmd CursorMoved * call s:MundoRefresh()
    autocmd BufEnter * let b:mundoChangedtick = 0
augroup END

"}}}


let &cpo = s:save_cpo
unlet s:save_cpo
