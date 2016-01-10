# import vim

normal = lambda s: vim().command('normal %s' % s)
normal_silent = lambda s: vim().command('silent! normal %s' % s)

def vim():
    """ call Vim.
    
    This is wrapped so that it can easily be mocked.
    """
    import vim
    return vim

def _goto_window_for_buffer(b):
    w = int(vim().eval('bufwinnr(%d)' % int(b)))
    vim().command('%dwincmd w' % int(w))

def _goto_window_for_buffer_name(bn):
    b = vim().eval('bufnr("%s")' % bn)
    return _goto_window_for_buffer(b)

# Rendering utility functions
def _output_preview_text(lines):
    _goto_window_for_buffer_name('__Mundo_Preview__')
    vim().command('setlocal modifiable')
    vim().current.buffer[:] = [line.rstrip() for line in lines]
    vim().command('setlocal nomodifiable')

def _undo_to(n):
    n = int(n)
    if n == 0:
        vim().command('silent earlier %s' % (int(vim().eval('&undolevels')) + 1))
    else:
        vim().command('silent undo %d' % int(n))
