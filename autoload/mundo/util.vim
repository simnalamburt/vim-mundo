" ============================================================================
" File:        util.vim
" Description: Defines utility functions and default option values for Mundo.
" Maintainer:  Hyeon Kim <simnalamburt@gmail.com>
" License:     GPLv2+
" ============================================================================

let s:save_cpo = &cpo
set cpo&vim

if exists('g:Mundo_PluginLoaded')
    let &cpo = s:save_cpo
    finish
endif

" Utility functions{{{

" Moves to the first window in the current tab corresponding to expr. Accepts
" an integer buffer number or a string file-pattern; for a detailed description
" see :h bufname. Returns 1 if successful, 0 otherwise.
function! mundo#util#MundoGoToWindowForBuffer(expr)"{{{
    let l:winnr = bufwinnr(bufnr(a:expr))

    if l:winnr == -1
        return 0
    elseif l:winnr != winnr()
        exe l:winnr . "wincmd w"
    endif

    return 1
endfunction"}}}

" Similar to MundoGoToWindowForBuffer, but considers windows in all tabs.
" Prioritises matches in the current tab.
function! mundo#util#MundoGoToWindowForBufferGlobal(expr)"{{{
    if mundo#util#MundoGoToWindowForBuffer(a:expr)
        return 1
    endif

    let l:bufWinIDs = win_findbuf(bufnr(a:expr))

    if len(l:bufWinIDs) <= 0
        return 0
    endif

    call win_gotoid(l:bufWinIDs[0])
    return 1
endfunction"}}}

" Prints a given message with a given highlight group.
function! mundo#util#Message(higroup, text)"{{{
    exec 'echohl ' . a:higroup . ' | echomsg ' . '"' . a:text
                \ . '" | echohl None'
endfunction"}}}

" Set var to val only if var has not been set by the user. Optionally takes a
" deprecated name and shows a warning if a matching option has been set.
function! mundo#util#set_default(var, val, ...)"{{{
    if !exists(a:var)
        let {a:var} = a:val
    endif

    let old_var = get(a:000, 0, '')

    if exists(old_var)
        call mundo#util#Message(
                    \ 'WarningMsg',
                    \ "{".old_var."}is deprecated! "
                    \ ."Please change your setting to {"
                    \ .split(old_var,':')[0]
                    \ .':'
                    \ .substitute(split(old_var,':')[1],'gundo_','mundo_','g')
                    \ .'}'
        )
    endif
endfunction"}}}

"}}}

" Placeholder functions for deprecated Gundo commands{{{

function! mundo#util#MundoToggle()
    return mundo#util#Message('WarningMsg', 'GundoToggle commands are '
                \ . 'deprecated. Please change to their corresponding '
                \ . 'MundoToggle command.')
endf

function! mundo#util#MundoShow()
    return mundo#util#Message('WarningMsg', 'GundoToggle commands are '
                \ . 'deprecated. Please change to their corresponding '
                \ . 'MundoShow command.')
endf

function! mundo#util#MundoHide()
    return mundo#util#Message('WarningMsg', 'GundoToggle commands are '
                \ . 'deprecated. Please change to their corresponding '
                \ . 'MundoHide command.')
endf

function! mundo#util#MundoRenderGraph()
    return mundo#util#Message('WarningMsg', 'GundoToggle commands are '
                \ . 'deprecated. Please change to their corresponding '
                \ . 'MundoRenderGraph command.')
endf

"}}}

let g:Mundo_PluginLoaded = 1

let &cpo = s:save_cpo
unlet s:save_cpo
