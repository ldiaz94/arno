# Working on arno

arno is a harness for language models in the terminal, rebuilt in raz.
Read `PLAN.md` first: the decisions, the stages, and what the Pascal
arno learned. The Pascal arno, `~/lib/arno`, is frozen: read it as the
reference for what arno does, never edit it. The language is defined
by raz's report (`man raz`, `~/r/raz/doc/raz.md`, and the library in
`~/r/raz/doc/raz-lib.md`); arno builds with the raz on PATH, of the
version `RAZVERSION` in the Makefile says.

## Setup and checks

    make check      # each module's main, its test
    make fmt        # src/ is laid out as raz's formatter lays it out

`make check` and `make fmt` must pass before every commit. rjson and
rnet are siblings of this directory (`RJSON`, `RNET` in the Makefile).

## How we work

- Work goes step by step, as `PLAN.md` lists; one commit per step,
  pushed, then stop for review. New work starts only on the owner's
  word.
- Do not edit rjson, rnet or rtui from here: what arno needs of them is
  asked of their owners.
- Readability first: code that is easy to read and follow, and well
  commented, comes before its length.
- Each module opens with what it is, what it depends on and what it
  leaves out; comments say why. Documentation in the plain, short prose
  of raz's report.
- A comment must not hold `*)`: it ends the comment.
- Modules are named with a leading `A` (`Amsg`, `Awire`), since a
  program's module names share one space with raz's library and every
  other library's.
- raz moves only by changing `RAZVERSION` (and installing that raz),
  on its own commit, with `make check` passing. What arno needs of raz
  that raz lacks is reported to raz's owner; it is not worked around
  quietly.
- Scripts are concha (`*.cn`), not sh, unless something outside our
  control demands sh.
- Commits: author `Luis <42945842+ldiaz94@users.noreply.github.com>`,
  unsigned (`--no-gpg-sign`), no attribution trailer. Push to `main`
  (`git@ldiaz94:ldiaz94/arno`). No pull requests unless asked.
