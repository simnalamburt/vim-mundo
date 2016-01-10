let s:save_cpo = &cpo
set cpo&vim

if exists('g:Mundo_PluginLoaded')
    finish
endif

function! mundo#util#set_default(var, val, ...)  "{{{
  let old_var = get(a:000, 0, '')
  if exists(old_var)
    let {a:var} = {old_var}
  elseif !exists(a:var)
    let {a:var} = a:val
  endif
endfunction"}}}

if !exists('g:gundo_python_path_setup')"{{{
    let g:gundo_python_path_setup = 0
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_python_path_setup', 0,
      \ 'g:gundo_python_path_setup')

if !exists('g:gundo_first_visible_line')"{{{
    let g:gundo_first_visible_line = 0
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_first_visible_line', 0,
      \ 'g:gundo_first_visible_line')

if !exists('g:gundo_last_visible_line')"{{{
    let g:gundo_last_visible_line = 0
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_last_visible_line', 0,
      \ 'g:gundo_last_visible_line')

if !exists('g:gundo_width')"{{{
    let g:gundo_width = 45
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_width', 45,
      \ 'g:gundo_width')

if !exists('g:gundo_preview_height')"{{{
    let g:gundo_preview_height = 15
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_preview_height', 15,
      \ 'g:gundo_preview_height')

if !exists('g:gundo_preview_bottom')"{{{
    let g:gundo_preview_bottom = 0
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_preview_bottom', 0,
      \ 'g:gundo_preview_bottom')

if !exists('g:gundo_right')"{{{
    let g:gundo_right = 0
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_right', 0,
      \ 'g:gundo_right')

if !exists('g:gundo_help')"{{{
    let g:gundo_help = 0
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_help', 0,
      \ 'g:gundo_help')

if !exists('g:gundo_map_move_older')"{{{
    let g:gundo_map_move_older = 'j'
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_map_move_older', 'j',
      \ 'g:gundo_map_move_older')

if !exists('g:gundo_map_move_newer')"{{{
    let g:gundo_map_move_newer = 'k'
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_map_move_newer', 'k',
      \ 'g:gundo_map_move_newer')

if !exists('g:gundo_close_on_revert')"{{{
    let g:gundo_close_on_revert = 0
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_close_on_revert', 0,
      \ 'g:gundo_close_on_revert')

if !exists('g:gundo_prefer_python3')"{{{
    let g:gundo_prefer_python3 = 0
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_prefer_python3', 0,
      \ 'g:gundo_prefer_python3')

if !exists('g:gundo_auto_preview')"{{{
    let g:gundo_auto_preview = 1
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_auto_preview', 1,
      \ 'g:gundo_auto_preview')

if !exists('g:gundo_verbose_graph')"{{{
    let g:gundo_verbose_graph = 1
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_verbose_graph', 1,
      \ 'g:gundo_verbose_graph')

if !exists('g:gundo_playback_delay')"{{{
    let g:gundo_playback_delay = 60
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_playback_delay', 60,
      \ 'g:gundo_playback_delay')

if !exists('g:gundo_mirror_graph')"{{{
    let g:gundo_mirror_graph = 0
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_mirror_graph', 0,
      \ 'g:gundo_mirror_graph')

if !exists('g:gundo_inline_undo')"{{{
    let g:gundo_inline_undo = 0
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_inline_undo', 0,
      \ 'g:gundo_inline_undo')

if !exists('g:gundo_return_on_revert')"{{{
    let g:gundo_return_on_revert = 1
endif"}}}
call mundo#util#set_default(
      \ 'g:mundo_return_on_revert', 1,
      \ 'g:gundo_return_on_revert')

function! mundo#util#init() abort
    
endfunction


let g:Mundo_PluginLoaded = 1

let &cpo = s:save_cpo
unlet s:save_cpo
