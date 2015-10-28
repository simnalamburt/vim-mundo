# vim: set fdm=marker ts=4 sw=4 et:
# ============================================================================
# File:        gundo.py
# Description: vim global plugin to visualize your undo tree
# Maintainer:  Steve Losh <steve@stevelosh.com>
# License:     GPLv2+ -- look it up.
# Notes:       Much of this code was thieved from Mercurial, and the rest was
#              heavily inspired by scratch.vim and histwin.vim.
#
# ============================================================================

import re
import sys
import tempfile
import vim

from mundo.node import Nodes
import mundo.util as util
import mundo.graphlog as graphlog

# Python Vim utility functions -----------------------------------------------------#{{{

MISSING_BUFFER = "Cannot find Gundo's target buffer (%s)"
MISSING_WINDOW = "Cannot find window (%s) for Gundo's target buffer (%s)"

def _check_sanity():
    '''Check to make sure we're not crazy.

    Does the following things:

        * Make sure the target buffer still exists.
    '''
    global nodesData
    if not nodesData:
        nodesData = Nodes()
    b = int(vim.eval('g:gundo_target_n'))

    if not vim.eval('bufloaded(%d)' % int(b)):
        vim.command('echo "%s"' % (MISSING_BUFFER % b))
        return False

    w = int(vim.eval('bufwinnr(%d)' % int(b)))
    if w == -1:
        vim.command('echo "%s"' % (MISSING_WINDOW % (w, b)))
        return False

    return True

INLINE_HELP = '''\
" Gundo (%d) - Press ? for Help:
" %s/%s  - Next/Prev undo state.
" J/K  - Next/Prev write state.
" i    - Toggle 'inline diff' mode.
" /    - Find changes that match string.
" n/N  - Next/Prev undo that matches search.
" P    - Play current state to selected undo.
" d    - Vert diff of undo with current state.
" p    - Diff of selected undo and current state.
" r    - Diff of selected undo and prior undo.
" q    - Quit!
" <cr> - Revert to selected state.

'''

#}}}

nodesData = Nodes()

# from profilehooks import profile
# @profile(immediate=True)
def GundoRenderGraph(force=False):
    if not _check_sanity():
        return

    first_visible_line = int(vim.eval("line('w0')"))
    last_visible_line = int(vim.eval("line('w$')"))

    verbose = vim.eval('g:gundo_verbose_graph') == "1"
    target = (int(vim.eval('g:gundo_target_n')),
                vim.eval('g:gundo_map_move_older'),
                vim.eval('g:gundo_map_move_newer'))

    if int(vim.eval('g:gundo_help')):
        header = (INLINE_HELP % target).splitlines()
    else:
        header = [(INLINE_HELP % target).splitlines()[0], '\n']

    show_inline_undo = int(vim.eval("g:gundo_inline_undo")) == 1
    gundo_last_visible_line = int(vim.eval("g:gundo_last_visible_line"))
    gundo_first_visible_line = int(vim.eval("g:gundo_first_visible_line"))

    if not force and not nodesData.is_outdated() and (
                not show_inline_undo or 
                not (
                    gundo_first_visible_line == first_visible_line and
                    gundo_last_visible_line == last_visible_line
                )
            ):
        return

    result = graphlog.generate(
            verbose,
            len(header)+1,
            first_visible_line,
            last_visible_line,
            show_inline_undo,
            nodesData
    )
    vim.command("let g:gundo_last_visible_line=%s"%last_visible_line)
    vim.command("let g:gundo_first_visible_line=%s"%first_visible_line)

    output = []
    # right align the dag and flip over the y axis:
    flip_dag = int(vim.eval("g:gundo_mirror_graph")) == 1
    dag_width = 1
    maxwidth = int(vim.eval("g:gundo_width"))
    for line in result:
        if len(line[0]) > dag_width:
            dag_width = len(line[0])
    for line in result:
        if flip_dag:
            dag_line = (line[0][::-1]).replace("/","\\")
            output.append("%*s %s"% (dag_width,dag_line,line[1]))
        else:
            output.append("%-*s %s"% (dag_width,line[0],line[1]))

    vim.command('call s:GundoOpenGraph()')
    vim.command('setlocal modifiable')
    lines = (header + output)
    lines = [line.rstrip() for line in lines]
    vim.current.buffer[:] = lines
    vim.command('setlocal nomodifiable')

    i = 1
    for line in output:
        try:
            line.split('[')[0].index('@')
            i += 1
            break
        except ValueError:
            pass
        i += 1
    vim.command('%d' % (i+len(header)-1))

def GundoRenderPreview():
    if not _check_sanity():
        return

    target_state = GundoGetTargetState()
    # Check that there's an undo state. There may not be if we're talking about
    # a buffer with no changes yet.
    if target_state == None:
        util._goto_window_for_buffer_name('__Gundo__')
        return
    else:
        target_state = int(target_state)

    util._goto_window_for_buffer(vim.eval('g:gundo_target_n'))

    nodes, nmap = nodesData.make_nodes()

    node_after = nmap[target_state]
    node_before = node_after.parent

    vim.command('call s:GundoOpenPreview()')
    util._output_preview_text(nodesData.preview_diff(node_before, node_after))

    util._goto_window_for_buffer_name('__Gundo__')

def GundoGetTargetState():
    """ Get the current undo number that gundo is at.  """
    util._goto_window_for_buffer_name('__Gundo__')
    target_line = vim.eval("getline('.')")
    matches = re.match('^.* \[([0-9]+)\] .*$',target_line)
    if matches:
        return int(matches.group(1))
    return 0

def GetNextLine(direction,move_count,write,start="line('.')"):
    start_line_no = int(vim.eval(start))
    start_line = vim.eval("getline('.')")
    gundo_verbose_graph = vim.eval('g:gundo_verbose_graph')
    if gundo_verbose_graph != "0":
        distance = 2

        # If we're in between two nodes we move by one less to get back on track.
        if start_line.find('[') == -1:
            distance = distance - 1
    else:
      distance = 1
      nextline = vim.eval("getline(%d)" % (start_line_no+direction))
      idx1 = nextline.find('@')
      idx2 = nextline.find('o')
      idx3 = nextline.find('w')
      # if the next line is not a revision - then go down one more.
      if (idx1+idx2+idx3) == -3:
          distance = distance + 1

    next_line = start_line_no + distance*direction
    if move_count > 1:
        return GetNextLine(direction,move_count-1,write,str(next_line))
    elif write:
        newline = vim.eval("getline(%d)" % (next_line))
        if newline.find('w ') == -1:
            # make sure that if we can't go up/down anymore that we quit out.
            if direction < 0 and next_line == 1:
                return next_line
            if direction > 0 and next_line >= len(vim.current.window.buffer):
                return next_line
            return GetNextLine(direction,1,write,str(next_line))
    return next_line

def GundoMove(direction,move_count=1,relative=True,write=False):
    """
    Move within the undo graph in the direction specified (or to the specific
    undo node specified).

    Parameters:

      direction  - -1/1 (up/down). when 'relative' if False, the undo node to
                   move to.
      move_count - how many times to perform the operation (irrelevent for
                   relative == False).
      relative   - whether to move up/down, or to jump to a specific undo node.

      write      - If True, move to the next written undo.
    """
    if relative:
        target_n = GetNextLine(direction,move_count,write)
    else:
        updown = 1
        if GundoGetTargetState() < direction:
            updown = -1
        target_n = GetNextLine(updown,abs(GundoGetTargetState()-direction),write)

    # Bound the movement to the graph.
    help_lines = 3
    if int(vim.eval('g:gundo_help')):
        help_lines = len(INLINE_HELP.split('\n'))
    if target_n <= help_lines:
        vim.command("call cursor(%d, 0)" % help_lines)
    else:
        vim.command("call cursor(%d, 0)" % target_n)

    line = vim.eval("getline('.')")

    # Move to the node, whether it's an @, o, or w
    idx1 = line.find('@ ')
    idx2 = line.find('o ')
    idx3 = line.find('w ')
    idxs = []
    if idx1 != -1:
        idxs.append(idx1)
    if idx2 != -1:
        idxs.append(idx2)
    if idx3 != -1:
        idxs.append(idx3)
    minidx = min(idxs)
    if idx1 == minidx:
        vim.command("call cursor(0, %d + 1)" % idx1)
    elif idx2 == minidx:
        vim.command("call cursor(0, %d + 1)" % idx2)
    else:
        vim.command("call cursor(0, %d + 1)" % idx3)

    if vim.eval('g:gundo_auto_preview') == '1':
        GundoRenderPreview()

def GundoSearch():
    search = vim.eval("input('/')");
    vim.command('let @/="%s"'% search.replace("\\","\\\\").replace('"','\\"'))
    GundoNextMatch()

def GundoPrevMatch():
    GundoMatch(-1)

def GundoNextMatch():
    GundoMatch(1)

def GundoMatch(down):
    """ Jump to the next node that matches the current pattern.  If there is a
    next node, search from the next node to the end of the list of changes. Stop
    on a match. """
    if not _check_sanity():
        return

    # save the current window number (should be the navigation window)
    # then generate the undo nodes, and then go back to the current window.
    util._goto_window_for_buffer(vim.eval('g:gundo_target_n'))

    nodes, nmap = nodesData.make_nodes()
    total = len(nodes) - 1

    util._goto_window_for_buffer_name('__Gundo__')
    curline = int(vim.eval("line('.')"))
    gundo_node = GundoGetTargetState()

    found_version = -1
    if total > 0:
        therange = range(gundo_node-1,-1,-1)
        if down < 0:
            therange = range(gundo_node+1,total+1)
        for version in therange:
            util._goto_window_for_buffer_name('__Gundo__')
            undochanges = nodesData.preview_diff(nmap[version].parent, nmap[version])
            # Look thru all of the changes, ignore the first two b/c those are the
            # diff timestamp fields (not relevent):
            for change in undochanges[3:]:
                match_index = vim.eval('match("%s",@/)'% change.replace("\\","\\\\").replace('"','\\"'))
                # only consider the matches that are actual additions or
                # subtractions
                if int(match_index) >= 0 and (change.startswith('-') or change.startswith('+')):
                    found_version = version
                    break
            # found something, lets get out of here:
            if found_version != -1:
                break
    util._goto_window_for_buffer_name('__Gundo__')
    if found_version >= 0:
        GundoMove(found_version,1,False)

def GundoRenderPatchdiff():
    """ Call GundoRenderChangePreview and display a vert diffpatch with the
    current file. """
    if GundoRenderChangePreview():
        # if there are no lines, do nothing (show a warning).
        util._goto_window_for_buffer_name('__Gundo_Preview__')
        if vim.current.buffer[:] == ['']:
            # restore the cursor position before exiting.
            util._goto_window_for_buffer_name('__Gundo__')
            vim.command('unsilent echo "No difference between current file and undo number!"')
            return False

        # quit out of gundo main screen
        util._goto_window_for_buffer_name('__Gundo__')
        vim.command('quit')

        # save the __Gundo_Preview__ buffer to a temp file.
        util._goto_window_for_buffer_name('__Gundo_Preview__')
        (handle,filename) = tempfile.mkstemp()
        vim.command('silent! w %s' % (filename))
        # exit the __Gundo_Preview__ window
        vim.command('bdelete')
        # diff the temp file
        vim.command('silent! keepalt vert diffpatch %s' % (filename))
        vim.command('set buftype=nofile bufhidden=delete')
        return True
    return False

def GundoGetChangesForLine():
    if not _check_sanity():
        return False

    target_state = GundoGetTargetState()

    # Check that there's an undo state. There may not be if we're talking about
    # a buffer with no changes yet.
    if target_state == None:
        util._goto_window_for_buffer_name('__Gundo__')
        return False
    else:
        target_state = int(target_state)

    util._goto_window_for_buffer(vim.eval('g:gundo_target_n'))

    nodes, nmap = nodesData.make_nodes()

    node_after = nmap[target_state]
    node_before = nmap[nodesData.current()]
    return nodesData.change_preview_diff(node_before, node_after)

def GundoRenderChangePreview():
    """ Render the selected undo level with the current file.
    Return True on success, False on failure. """
    if not _check_sanity():
        return

    vim.command('call s:GundoOpenPreview()')
    util._output_preview_text(GundoGetChangesForLine())

    util._goto_window_for_buffer_name('__Gundo__')

    return True

def GundoRenderToggleInlineDiff():
    show_inline = int(vim.eval('g:gundo_inline_undo'))
    if show_inline == 0:
        vim.command("let g:gundo_inline_undo=1")
    else:
        vim.command("let g:gundo_inline_undo=0")
    line = int(vim.eval("line('.')"))
    nodesData.clear_oneline_diffs()
    GundoRenderGraph(True)
    vim.command("call cursor(%d,0)" % line)

def GundoToggleHelp():
    show_help = int(vim.eval('g:gundo_help'))
    if show_help == 0:
        vim.command("let g:gundo_help=1")
    else:
        vim.command("let g:gundo_help=0")
    vim.command("call cursor(getline('.') - %d)" % (len(INLINE_HELP.split('\n')) - 2))
    GundoRenderGraph(True)

# Gundo undo/redo
def GundoRevert():
    if not _check_sanity():
        return

    target_n = GundoGetTargetState()
    back = vim.eval('g:gundo_target_n')

    util._goto_window_for_buffer(back)
    util._undo_to(target_n)

    vim.command('GundoRenderGraph')
    if int(vim.eval('g:gundo_return_on_revert')):
        util._goto_window_for_buffer(back)

    if int(vim.eval('g:gundo_close_on_revert')):
        vim.command('GundoToggle')

def GundoPlayTo():
    if not _check_sanity():
        return

    target_n = GundoGetTargetState()
    back = int(vim.eval('g:gundo_target_n'))
    delay = int(vim.eval('g:gundo_playback_delay'))

    vim.command('echo "%s"' % back)

    util._goto_window_for_buffer(back)
    util.normal('zR')

    nodes, nmap = nodesData.make_nodes()

    start = nmap[nodesData.current()]
    end = nmap[target_n]

    def _walk_branch(origin, dest):
        rev = origin.n < dest.n

        nodes = []
        if origin.n > dest.n:
            current, final = origin, dest
        else:
            current, final = dest, origin

        while current.n >= final.n:
            if current.n == final.n:
                break
            nodes.append(current)
            current = current.parent
        else:
            return None
        nodes.append(current)

        if rev:
            return reversed(nodes)
        else:
            return nodes

    branch = _walk_branch(start, end)

    if not branch:
        vim.command('unsilent echo "No path to that node from here!"')
        return

    for node in branch:
        util._undo_to(node.n)
        vim.command('GundoRenderGraph')
        util.normal('zz')
        util._goto_window_for_buffer(back)
        vim.command('redraw')
        vim.command('sleep %dm' % delay)

def initPythonModule():
    if sys.version_info[:2] < (2, 4):
        vim.command('let s:has_supported_python = 0')
