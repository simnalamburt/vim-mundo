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

import difflib
import itertools
import re
import sys
import time
import tempfile

try:
    import vim
except:
    # vim isn't needed and isn't in the classpath when doing unit tests.
    pass

# one line diff functions.#{{{
def one_line_diff_str(before,after,mx=15,pre=2):
    """
    Return a summary of the differences between two strings, concatenated.
    
    Parameters:
    
      before - string before.
      after  - after string.
      mx     - the max number of strings.
      pre    - number of characters to show before diff (context)
    
    Returns a string no longer than 'mx'.
    """
    old = one_line_diff(before,after)
    result = ''
    firstEl = True
    # TODO instead of using +addition+ and -subtraction- it'd be nice to be able
    # to highlight the change w/o requiring the +/- chars.
    for v in old:
        # if the first element doesn't have a change, then don't include it.
        v = escape_returns(v)
        if firstEl:
            firstEl = False
            # add in pre character context:
            if not (v.startswith('+') or v.startswith('-')) and result == '':
                v = v[-pre:]
        # when we're going to be bigger than our max limit, lets ensure that the
        # trailing +/- appears in the text:
        if len(result) + len(v) > mx:
            if v.startswith('+') or v.startswith('-'):
                result += v[:mx - len(result) - 1]
                result += v[0]
            break
        result += v
    return result

def escape_returns(result):
    return result.replace('\n','\\n').replace('\r','\\r').replace('\t','\\t')

def one_line_diff(before,after):
  """
  Return a summary of the differences between two arbitrary strings.

  Returns a list of strings, summarizing all the changes.
  """
  s = difflib.SequenceMatcher(None,before,after)
  results = []
  for tag, i1, i2, j1, j2 in s.get_opcodes():
    #print ("%7s a[%d:%d] (%s) b[%d:%d] (%s)" % (tag, i1, i2, before[i1:i2], j1, j2, after[j1:j2]))
    if tag == 'equal':
      _append_result(results,{
        'equal': after[j1:j2]
      })
    if tag == 'insert':
      _append_result(results,{
        'plus': after[j1:j2]
      })
    elif tag == 'delete':
      _append_result(results,{
        'minus': before[i1:i2]
      })
    elif tag == 'replace':
      _append_result(results,{
        'minus': before[j1:j2],
        'plus': after[j1:j2]
      })
  final_results = []
  # finally, create a human readable string of information.
  for v in results:
    if 'minus' in v and 'plus' in v and len(v['minus']) > 0 and len(v['plus']) > 0:
      final_results.append("-%s-+%s+"% (v['minus'],v['plus']))
    elif 'minus' in v and len(v['minus']) > 0:
      final_results.append("-%s-"% (v['minus']))
    elif 'plus' in v and len(v['plus']) > 0:
      final_results.append("+%s+"% (v['plus']))
    elif 'equal' in v:
      final_results.append("%s"% (v['equal']))
  return final_results

def _append_result(results,val):
  results.append(val)
#}}}
# Mercurial's graphlog code --------------------------------------------------------#{{{
def asciiedges(seen, rev, parents):
    """adds edge info to changelog DAG walk suitable for ascii()"""
    if rev not in seen:
        seen.append(rev)
    nodeidx = seen.index(rev)

    knownparents = []
    newparents = []
    for parent in parents:
        if parent in seen:
            knownparents.append(parent)
        else:
            newparents.append(parent)

    ncols = len(seen)
    seen[nodeidx:nodeidx + 1] = newparents
    edges = [(nodeidx, seen.index(p)) for p in knownparents]

    if len(newparents) > 0:
        edges.append((nodeidx, nodeidx))
    if len(newparents) > 1:
        edges.append((nodeidx, nodeidx + 1))

    nmorecols = len(seen) - ncols
    return nodeidx, edges, ncols, nmorecols

def get_nodeline_edges_tail(
        node_index, p_node_index, n_columns, n_columns_diff, p_diff, fix_tail):
    if fix_tail and n_columns_diff == p_diff and n_columns_diff != 0:
        # Still going in the same non-vertical direction.
        if n_columns_diff == -1:
            start = max(node_index + 1, p_node_index)
            tail = ["|", " "] * (start - node_index - 1)
            tail.extend(["/", " "] * (n_columns - start))
            return tail
        else:
            return ["\\", " "] * (n_columns - node_index - 1)
    else:
        return ["|", " "] * (n_columns - node_index - 1)

def draw_edges(edges, nodeline, interline):
    for (start, end) in edges:
        if start == end + 1:
            interline[2 * end + 1] = "/"
        elif start == end - 1:
            interline[2 * start + 1] = "\\"
        elif start == end:
            interline[2 * start] = "|"
        else:
            nodeline[2 * end] = "+"
            if start > end:
                (start, end) = (end, start)
            for i in range(2 * start + 1, 2 * end):
                if nodeline[i] != "+":
                    nodeline[i] = "-"

def fix_long_right_edges(edges):
    for (i, (start, end)) in enumerate(edges):
        if end > start:
            edges[i] = (start, end + 1)

def ascii(state, type, char, text, coldata, verbose):
    """prints an ASCII graph of the DAG

    takes the following arguments (one call per node in the graph):

      - Somewhere to keep the needed state in (init to asciistate())
      - Column of the current node in the set of ongoing edges.
      - Type indicator of node data == ASCIIDATA.
      - Payload: (char, lines):
        - Character to use as node's symbol.
        - List of lines to display as the node's text.
      - Edges; a list of (col, next_col) indicating the edges between
        the current node and its parents.
      - Number of columns (ongoing edges) in the current revision.
      - The difference between the number of columns (ongoing edges)
        in the next revision and the number of columns (ongoing edges)
        in the current revision. That is: -1 means one column removed;
        0 means no columns added or removed; 1 means one column added.
      - Verbosity: if enabled then the graph prints an extra '|' 
        between each line of information.

    Returns a string representing the output.
    """

    idx, edges, ncols, coldiff = coldata
    assert -2 < coldiff < 2
    if coldiff == -1:
        # Transform
        #
        #     | | |        | | |
        #     o | |  into  o---+
        #     |X /         |/ /
        #     | |          | |
        fix_long_right_edges(edges)

    # add_padding_line says whether to rewrite
    #
    #     | | | |        | | | |
    #     | o---+  into  | o---+
    #     |  / /         |   | |  # <--- padding line
    #     o | |          |  / /
    #                    o | |
    add_padding_line = (len(text) > 2 and coldiff == -1 and
                        [x for (x, y) in edges if x + 1 < y] and
                        verbose)

    # fix_nodeline_tail says whether to rewrite
    #
    #     | | o | |        | | o | |
    #     | | |/ /         | | |/ /
    #     | o | |    into  | o / /   # <--- fixed nodeline tail
    #     | |/ /           | |/ /
    #     o | |            o | |
    fix_nodeline_tail = len(text) <= 2 and not add_padding_line

    # nodeline is the line containing the node character (typically o)
    nodeline = ["|", " "] * idx
    nodeline.extend([char, " "])

    nodeline.extend(
        get_nodeline_edges_tail(idx, state[1], ncols, coldiff,
                                state[0], fix_nodeline_tail))

    # shift_interline is the line containing the non-vertical
    # edges between this entry and the next
    shift_interline = ["|", " "] * idx
    if coldiff == -1:
        n_spaces = 1
        edge_ch = "/"
    elif coldiff == 0:
        n_spaces = 2
        edge_ch = "|"
    else:
        n_spaces = 3
        edge_ch = "\\"
    shift_interline.extend(n_spaces * [" "])
    shift_interline.extend([edge_ch, " "] * (ncols - idx - 1))

    # draw edges from the current node to its parents
    draw_edges(edges, nodeline, shift_interline)

    # lines is the list of all graph lines to print
    lines = [nodeline]
    if add_padding_line:
        lines.append(get_padding_line(idx, ncols, edges))
    lines.append(shift_interline)

    # make sure that there are as many graph lines as there are
    # log strings
    if any("/" in s for s in lines) or verbose:
        while len(text) < len(lines):
            text.append('')
    if len(lines) < len(text):
        extra_interline = ["|", " "] * (ncols + coldiff)
        while len(lines) < len(text):
            lines.append(extra_interline)

    indentation_level = max(ncols, ncols + coldiff)
    result = []
    for (line, logstr) in zip(lines, text):
        result.append(["%-*s" % (2 * indentation_level, "".join(line)), logstr])

    # ... and start over
    state[0] = coldiff
    state[1] = idx
    return result

def generate(dag, edgefn, current, verbose, num_header_lines, first_visible_line, last_visible_line):
    """
    Generate an array of the graph, and text describing the node of the graph.
    """
    seen, state = [], [0, 0]
    result = []
    current = nodesData.current()

    inline_graph = int(vim.eval("g:gundo_inline_graph")) == 1

    line_number = num_header_lines
    for idx, part in list(enumerate(dag)):
        node, parents = part
        if node.time:
            age_label = age(int(node.time))
        else:
            age_label = 'Original'
        line = '[%s] %s' % (node.n, age_label)
        if node.n == current:
            char = '@'
        elif node.saved:
            char = 'w'
        else:
            char = 'o'
        show_inine_diff = inline_graph and line_number >= first_visible_line and line_number <= last_visible_line
        preview_diff = nodesData.preview_diff(node.parent, node,False,show_inine_diff)
        line = '[%s] %-10s %s' % (node.n, age_label, preview_diff)
        new_lines = ascii(state, 'C', char, [line], edgefn(seen, node, parents), verbose)
        line_number += len(new_lines)
        result.extend(new_lines)
    _undo_to(current)
    return result

# Mercurial age function -----------------------------------------------------------
agescales = [("yr", 3600 * 24 * 365),
             ("mon", 3600 * 24 * 30),
             ("wk", 3600 * 24 * 7),
             ("dy", 3600 * 24),
             ("hr", 3600),
             ("min", 60),
             ("sec", 1)]

def age(ts):
    '''turn a timestamp into an age string.'''

    def plural(t, c):
        if c == 1:
            return t
        return t + "s"
    def fmt(t, c):
        return "%d %s" % (int(c), plural(t, c))

    now = time.time()
    then = ts
    if then > now:
        return 'in the future'

    delta = max(1, int(now - then))
    if delta > agescales[0][1] * 2:
        return time.strftime('%Y-%m-%d', time.gmtime(float(ts)))

    for t, s in agescales:
        n = delta // s
        if n >= 2 or s == 1:
            return '%s ago' % fmt(t, n)

#}}}
# Python Vim utility functions -----------------------------------------------------#{{{
normal = lambda s: vim.command('normal %s' % s)
normal_silent = lambda s: vim.command('silent! normal %s' % s)

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

def _goto_window_for_buffer(b):
    w = int(vim.eval('bufwinnr(%d)' % int(b)))
    vim.command('%dwincmd w' % int(w))

def _goto_window_for_buffer_name(bn):
    b = vim.eval('bufnr("%s")' % bn)
    return _goto_window_for_buffer(b)

def _undo_to(n):
    n = int(n)
    if n == 0:
        vim.command('silent earlier %s' % (int(vim.eval('&undolevels')) + 1))
    else:
        vim.command('silent undo %d' % int(n))


INLINE_HELP = '''\
" Gundo (%d) - Press ? for Help:
" %s/%s  - Next/Prev undo state.
" J/K  - Next/Prev write state.
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
# Python undo tree data structures and functions -----------------------------------#{{{
class Node(object):
    def __init__(self, n, parent, time, curhead, saved):
        self.n = int(n)
        self.parent = parent
        self.children = []
        self.curhead = curhead
        self.saved = saved
        self.time = time

    def __repr__(self):
        return "[n=%s,parent=%s,time=%s,curhead=%s,saved=%s]" % \
            (self.n,self.parent,self.time,self.curhead,self.saved)

class Nodes(object):
    def __init__(self):
        self._clear_cache()

    def _clear_cache(self):
        self.nodes_made = None
        self.target_f = None
        self.seq_last = None
        self.lines = {}
        self.diffs = {}
        self.diff_has_oneline = {}

    def _check_version_location(self):
        _goto_window_for_buffer(vim.eval('g:gundo_target_n'))
        target_f = vim.eval('g:gundo_target_f')
        if target_f != self.target_f:
            self._clear_cache()

    def _make_nodes(self,alts, nodes, parent=None):
        p = parent

        for alt in alts:
            if alt:
                curhead = 'curhead' in alt
                saved = 'save' in alt
                node = Node(n=alt['seq'], parent=p, time=alt['time'], curhead=curhead, saved=saved)
                nodes.append(node)
                if alt.get('alt'):
                    self._make_nodes(alt['alt'], nodes, p)
                p = node

    def make_nodes(self):
        self._check_version_location()
        target_f = vim.eval('g:gundo_target_f')
        ut = vim.eval('undotree()')
        entries = ut['entries']
        seq_last = ut['seq_last']

        # if the current seq_last and file are different, compute the new
        # values:
        if self.seq_last != seq_last:
            vim.command('let s:has_supported_python = 0')
            root = Node(0, None, False, 0, 0)
            nodes = []
            # TODO only compute new values (not all values)
            self._make_nodes(entries, nodes, root)
            nodes.append(root)
            nmap = dict((node.n, node) for node in nodes)

            # cache values for later use
            self.target_f = target_f
            self.seq_last = seq_last
            self.nodes_made = (nodes, nmap)

        return self.nodes_made

    def current(self):
        """ Return the number of the current change. """
        self._check_version_location()
        nodes, nmap = self.make_nodes()
        _curhead_l = list(itertools.dropwhile(lambda n: not n.curhead, nodes))
        if _curhead_l:
            current = _curhead_l[0].parent.n
        else:
            current = int(vim.eval('changenr()'))
        return current

    def _fmt_time(self,t):
        return time.strftime('%Y-%m-%d %I:%M:%S %p', time.localtime(float(t)))

    def _get_lines(self,node):
        n = 0
        if node:
            n = node.n
        if n not in self.lines:
            _undo_to(n)
            self.lines[n] = vim.current.buffer[:]
        return self.lines[n]

    def change_preview_diff(self,before,after):
        self._check_version_location()
        key = "%s-%s-cpd"%(before.n,after.n)
        if key in self.diffs:
            return self.diffs[key]

        _goto_window_for_buffer(vim.eval('g:gundo_target_n'))
        before_lines = self._get_lines(before)
        after_lines = self._get_lines(after)

        before_name = before.n or 'Original'
        before_time = before.time and self._fmt_time(before.time) or ''
        after_name = after.n or 'Original'
        after_time = after.time and self._fmt_time(after.time) or ''

        _undo_to(self.current())

        self.diffs[key] = list(difflib.unified_diff(before_lines, after_lines,
                                         before_name, after_name,
                                         before_time, after_time))
        return self.diffs[key]

    def preview_diff(self, before, after, unified=True, inline=False):
        """
        Generate a diff comparing two versions of a file.

        Parameters:

          current - ?
          before
          after
          unified - If True, generate a unified diff
          inline - Generate a one line summary line.
        """
        self._check_version_location()
        bn = 0
        an = 0
        if not after.n:    # we're at the original file
            pass
        elif not before.n: # we're at a pseudo-root state
            an = after.n
        else:
            bn = before.n
            an = after.n
        key = "%s-%s-pd-%s"%(bn,an,unified)
        needs_oneline = inline and key not in self.diff_has_oneline
        if key in self.diffs and not needs_oneline:
            return self.diffs[key]

        if not after.n:    # we're at the original file
            before_lines = []
            after_lines = self._get_lines(None)

            before_name = 'n/a'
            before_time = ''
            after_name = 'Original'
            after_time = ''
        elif not before.n: # we're at a pseudo-root state
            before_lines = self._get_lines(None)
            after_lines = self._get_lines(after)

            before_name = 'Original'
            before_time = ''
            after_name = after.n
            after_time = self._fmt_time(after.time)
        else:
            before_lines = self._get_lines(before)
            after_lines = self._get_lines(after)

            before_name = before.n
            before_time = self._fmt_time(before.time)
            after_name = after.n
            after_time = self._fmt_time(after.time)

        if unified:
            self.diffs[key] = list(difflib.unified_diff(before_lines, after_lines,
                                             before_name, after_name,
                                             before_time, after_time))
        elif inline:
            maxwidth = vim.eval("col('$')")
            self.diffs[key] = one_line_diff_str('\n'.join(before_lines),'\n'.join(after_lines),maxwidth)
            self.diff_has_oneline[key] = True
        else:
            self.diffs[key] = ""

        return self.diffs[key]


#}}}

nodesData = Nodes()

# Rendering utility functions
def _output_preview_text(lines):
    _goto_window_for_buffer_name('__Gundo_Preview__')
    vim.command('setlocal modifiable')
    vim.current.buffer[:] = [line.rstrip() for line in lines]
    vim.command('setlocal nomodifiable')

def GundoRenderGraph():
    if not _check_sanity():
        return

    first_visible_line = int(vim.eval("line('w0')"))
    last_visible_line = int(vim.eval("line('w$')"))
    nodes, nmap = nodesData.make_nodes()

    for node in nodes:
        node.children = [n for n in nodes if n.parent == node]

    def walk_nodes(nodes):
        for node in nodes:
            if node.parent:
                yield (node, [node.parent])
            else:
                yield (node, [])

    dag = sorted(nodes, key=lambda n: int(n.n), reverse=True)

    verbose = vim.eval('g:gundo_verbose_graph') == "1"
    target = (int(vim.eval('g:gundo_target_n')),
                vim.eval('g:gundo_map_move_older'),
                vim.eval('g:gundo_map_move_newer'))

    if int(vim.eval('g:gundo_help')):
        header = (INLINE_HELP % target).splitlines()
    else:
        header = [(INLINE_HELP % target).splitlines()[0], '\n']

    result = generate(walk_nodes(dag), asciiedges, nodesData.current(), verbose, len(header)+1, first_visible_line, last_visible_line)

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
        _goto_window_for_buffer_name('__Gundo__')
        return
    else:
        target_state = int(target_state)

    _goto_window_for_buffer(vim.eval('g:gundo_target_n'))

    nodes, nmap = nodesData.make_nodes()

    node_after = nmap[target_state]
    node_before = node_after.parent

    vim.command('call s:GundoOpenPreview()')
    _output_preview_text(nodesData.preview_diff(node_before, node_after))

    _goto_window_for_buffer_name('__Gundo__')

def GundoGetTargetState():
    """ Get the current undo number that gundo is at.  """
    _goto_window_for_buffer_name('__Gundo__')
    target_line = vim.eval("getline('.')")
    return int(re.match('^.* \[([0-9]+)\] .*$',target_line).group(1))

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
    _goto_window_for_buffer(vim.eval('g:gundo_target_n'))

    nodes, nmap = nodesData.make_nodes()
    total = len(nodes) - 1

    _goto_window_for_buffer_name('__Gundo__')
    curline = int(vim.eval("line('.')")) 
    gundo_node = GundoGetTargetState()

    found_version = -1
    if total > 0:
        therange = range(gundo_node-1,-1,-1)
        if down < 0:
            therange = range(gundo_node+1,total+1)
        for version in therange:
            _goto_window_for_buffer_name('__Gundo__')
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
    _goto_window_for_buffer_name('__Gundo__')
    if found_version >= 0:
        GundoMove(found_version,1,False)

def GundoRenderPatchdiff():
    """ Call GundoRenderChangePreview and display a vert diffpatch with the
    current file. """
    if GundoRenderChangePreview():
        # if there are no lines, do nothing (show a warning).
        _goto_window_for_buffer_name('__Gundo_Preview__')
        if vim.current.buffer[:] == ['']:
            # restore the cursor position before exiting.
            _goto_window_for_buffer_name('__Gundo__')
            vim.command('unsilent echo "No difference between current file and undo number!"')
            return False

        # quit out of gundo main screen
        _goto_window_for_buffer_name('__Gundo__')
        vim.command('quit')

        # save the __Gundo_Preview__ buffer to a temp file.
        _goto_window_for_buffer_name('__Gundo_Preview__')
        (handle,filename) = tempfile.mkstemp()
        vim.command('silent! w %s' % (filename))
        # exit the __Gundo_Preview__ window
        vim.command('quit')
        # diff the temp file
        vim.command('silent! keepalt vert diffpatch %s' % (filename))
        vim.command('set buftype=nofile')
        return True
    return False

def GundoGetChangesForLine():
    if not _check_sanity():
        return False

    target_state = GundoGetTargetState()

    # Check that there's an undo state. There may not be if we're talking about
    # a buffer with no changes yet.
    if target_state == None:
        _goto_window_for_buffer_name('__Gundo__')
        return False
    else:
        target_state = int(target_state)

    _goto_window_for_buffer(vim.eval('g:gundo_target_n'))

    nodes, nmap = nodesData.make_nodes()

    node_after = nmap[target_state]
    node_before = nmap[nodesData.current()]
    return nodesData.change_preview_diff(node_before, node_after)

def GundoRenderChangePreview():
    """ Render the selected undo level with the current file.
    Return True on success, False on failure. """
    if not _check_sanity():
        return

    nodes, nmap = nodesData.make_nodes()

    vim.command('call s:GundoOpenPreview()')
    _output_preview_text(GundoGetChangesForLine())

    _goto_window_for_buffer_name('__Gundo__')

    return True

def GundoToggleHelp():
    show_help = int(vim.eval('g:gundo_help'))
    if show_help == 0:
        vim.command("let g:gundo_help=1")
        vim.command("call cursor(getline('.') + %d)" % (len(INLINE_HELP.split('\n')) - 2))
    else:
        vim.command("let g:gundo_help=0")
        vim.command("call cursor(getline('.') - %d)" % (len(INLINE_HELP.split('\n')) - 2))
    GundoRenderGraph()

# Gundo undo/redo
def GundoRevert():
    if not _check_sanity():
        return

    target_n = GundoGetTargetState()
    back = vim.eval('g:gundo_target_n')

    _goto_window_for_buffer(back)
    _undo_to(target_n)

    vim.command('GundoRenderGraph')
    _goto_window_for_buffer(back)

    if int(vim.eval('g:gundo_close_on_revert')):
        vim.command('GundoToggle')

def GundoPlayTo():
    if not _check_sanity():
        return

    target_n = GundoGetTargetState()
    back = int(vim.eval('g:gundo_target_n'))
    delay = int(vim.eval('g:gundo_playback_delay'))

    vim.command('echo "%s"' % back)

    _goto_window_for_buffer(back)
    normal('zR')

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
        _undo_to(node.n)
        vim.command('GundoRenderGraph')
        normal('zz')
        _goto_window_for_buffer(back)
        vim.command('redraw')
        vim.command('sleep %dm' % delay)

def initPythonModule():
    if sys.version_info[:2] < (2, 4):
        vim.command('let s:has_supported_python = 0')
