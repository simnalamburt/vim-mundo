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
if !exists('g:mundo_debug') && (exists('g:mundo_disable') && g:mundo_disable == 1 || exists('loaded_mundo') || &cp)"{{{
    finish
endif
let loaded_mundo = 1"}}}
"}}}

"{{{ Misc
command! -nargs=0 MundoToggle call mundo#MundoToggle()
command! -nargs=0 MundoShow call mundo#MundoShow()
command! -nargs=0 MundoHide call mundo#MundoHide()
command! -nargs=0 MundoRenderGraph call mundo#MundoRenderGraph()
command! -nargs=0 GundoToggle call mundo#util#MundoToggle()
command! -nargs=0 GundoShow call mundo#util#MundoShow()
command! -nargs=0 GundoHide call mundo#util#MundoHide()
command! -nargs=0 GundoRenderGraph call mundo#util#MundoRenderGraph()
"}}}
