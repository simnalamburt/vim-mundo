vim-mundo
=========

A Vim plugin to visualizes the Vim [undo tree](http://vimdoc.sourceforge.net/htmldoc/undo.html#undo-tree), a fork of
[Gundo](https://github.com/sjl/gundo.vim).

* [Introductory Video][video]
* Website [Project Site][site]

### How is this different than Gundo?

*   Several new features:
  * Ability to search undo history using <kbd>/</kbd>.
  * An 'in line' diff mode.
  * Navigation keys <kbd>J</kbd> and <kbd>K</kbd> to move thru written undos.
*   [Neovim][neovim] support
*   Merged upstream [pull requests][upstream-pr]:
  * [Fix paths with spaces][pr-29]
  * [Display timestamps in ISO format][pr-28]
  * [Real time updates][i-40]
  * [Show changes saved to disk][i-34]
  * [Python NoneType errors][i-38]
  * [open vimdiff of current buffer][i-28]
  * [Add global_disable option][i-33]
  * [Reduce verbosity][i-31]

#### What's your further plan?

*   Merge more reasonable pull requests
*   Make faster
*   Automated test

### Requirements

*   Vim ≥ *7.3* with `+python`
    <br>&nbsp; &nbsp; *or*<br>
    [Neovim][]

*   Python ≥ *2.4*

Recommended `vimrc` settings:

    " Enable persistent undo so that undo history persists across vim sessions
    set undofile
    set undodir=~/.vim/undo

### Testing

The tests appear to be broken in tests/. Tests unit tests can be run with
[nose](https://nose.readthedocs.org/en/latest/):

    cd autoload
    nosetests

### Contributing to Mundo

**Tagging in the issue tracker**

When submitting pull requests (commonly referred to as "PRs"), include one
of the following tags prepended to the title:

- [WIP] - Work In Progress: the PR will change, so while there is no immediate
need for review, the submitter still might appreciate it.
- [RFC] - Request For Comment: the PR needs reviewing and/or comments.
- [RDY] - Ready: the PR has been reviewed by at least one other person and has
no outstanding issues.

Assuming the above criteria has been met, feel free to change your PR's tag
yourself, as opposed to waiting for a contributor to do it for you.

--------

[GPLv2+][]

[upstream-pr]: https://github.com/sjl/gundo.vim/pulls
[video]: http://screenr.com/M9l
[site]: //simnalamburt.github.io/vim-mundo
[neovim]: //neovim.org/
[pr-29]: https://github.com/sjl/gundo.vim/pull/29
[pr-28]: https://github.com/sjl/gundo.vim/pull/28
[i-34]: https://bitbucket.org/sjl/gundo.vim/issue/34/show-changes-that-were-saved-onto-disk
[i-38]: https://bitbucket.org/sjl/gundo.vim/issue/38/python-errors-nonetype-not-iterable-with
[i-40]: https://bitbucket.org/sjl/gundo.vim/issue/40/feature-request-live-reload
[i-28]: https://bitbucket.org/sjl/gundo.vim/issue/28/feature-request-open-vimdiff-of-current#comment-3129981
[i-33]: https://bitbucket.org/sjl/gundo.vim/issue/33/let-g-gundo_disable-0-is-not-available
[i-31]: https://bitbucket.org/sjl/gundo.vim/issue/31/reduce-verbosity-of-the-list
[GPLv2+]: http://opensource.org/licenses/gpl-2.0
