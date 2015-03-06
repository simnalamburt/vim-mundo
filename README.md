vim-mundo
========

> Gundo.vim is Vim plugin to visualize your Vim undo tree.

Maintainer of [**Gundo.vim**][upstream] looks [tired][upstream-pr].
This is my own fork of it.

<img src="https://simnalamburt.github.io/vim-mundo/dist/screenshot.jpg" height="500">

* [Introductory Video][video]
* Original [Project Site][site]

### What's the difference?

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
*   Several new features:
  * Ability to search thru gundo history using '/'.
  * A 'in line' diff.
  * Navigation keys J/K to move thru written undos.

#### What's your further plan?

*   Merge more reasonable pull requests
*   Make faster
*   Automated test

#### Do you have any plan to diverge from [upstream][]?

*   Not yet. It'll always be downstream of original

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

--------

[GPLv2+][]

[upstream]: https://github.com/sjl/gundo.vim
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
