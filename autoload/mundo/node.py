import diff
import difflib
import itertools
import time
import util

# Python undo tree data structures and functions ----------------------------------
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
        self.changedtick = None
        self.lines = {}
        self.clear_oneline_diffs()

    def clear_oneline_diffs(self):
        self.diffs = {}
        self.diff_has_oneline = {}

    def _check_version_location(self):
        util._goto_window_for_buffer(util.vim().eval('g:mundo_target_n'))
        target_f = util.vim().eval('g:mundo_target_f')
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

    def is_outdated(self):
        util._goto_window_for_buffer(util.vim().eval('g:mundo_target_n'))
        current_changedtick = util.vim().eval('b:changedtick')
        return self.changedtick != current_changedtick

    def make_nodes(self):
        # If the current changedtick is unchanged, we don't need to do
        # anything:
        if not self.is_outdated():
            return self.nodes_made

        self._check_version_location()
        target_f = util.vim().eval('g:mundo_target_f')
        ut = util.vim().eval('undotree()')
        entries = ut['entries']
        seq_last = ut['seq_last']
        current_changedtick = util.vim().eval('b:changedtick')

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
        self.changedtick = current_changedtick

        return self.nodes_made

    def current(self):
        """ Return the number of the current change. """
        self._check_version_location()
        nodes, nmap = self.make_nodes()
        _curhead_l = list(itertools.dropwhile(lambda n: not n.curhead, nodes))
        if _curhead_l:
            current = _curhead_l[0].parent.n
        else:
            current = int(util.vim().eval('changenr()'))
        return current

    def _fmt_time(self,t):
        return time.strftime('%Y-%m-%d %I:%M:%S %p', time.localtime(float(t)))

    def _get_lines(self,node):
        n = 0
        if node:
            n = node.n
        if n not in self.lines:
            util._undo_to(n)
            self.lines[n] = util.vim().current.buffer[:]
        return self.lines[n]

    def change_preview_diff(self,before,after):
        self._check_version_location()
        key = "%s-%s-cpd"%(before.n,after.n)
        if key in self.diffs:
            return self.diffs[key]

        util._goto_window_for_buffer(util.vim().eval('g:mundo_target_n'))
        before_lines = self._get_lines(before)
        after_lines = self._get_lines(after)

        before_name = str(before.n or 'Original')
        before_time = before.time and self._fmt_time(before.time) or ''
        after_name = str(after.n or 'Original')
        after_time = after.time and self._fmt_time(after.time) or ''

        util._undo_to(self.current())

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
            after_name = str(after.n)
            after_time = self._fmt_time(after.time)
        else:
            before_lines = self._get_lines(before)
            after_lines = self._get_lines(after)

            before_name = str(before.n)
            before_time = self._fmt_time(before.time)
            after_name = str(after.n)
            after_time = self._fmt_time(after.time)

        if unified:
            self.diffs[key] = list(difflib.unified_diff(before_lines, after_lines,
                                             before_name, after_name,
                                             before_time, after_time))
        elif inline:
            maxwidth = int(util.vim().eval("winwidth(0)"))
            self.diffs[key] = diff.one_line_diff_str('\n'.join(before_lines),'\n'.join(after_lines),maxwidth)
            self.diff_has_oneline[key] = True
        else:
            self.diffs[key] = ""

        return self.diffs[key]
