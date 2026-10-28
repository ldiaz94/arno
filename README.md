<p align="center">
  <img src="doc/img/banner.svg" alt="arno: a harness for language models in the terminal" width="800">
</p>

arno is a harness for language models in the terminal, written in
[raz](https://raz.lucelad.workers.dev). It sends a conversation to a
model (Ollama, Ollama Cloud, OpenAI, Gemini or Claude), streams the
reply, and lets the model read your project and change it through a
few tools, each one asking you before it reaches past what is safe.
Conversations are kept on disk. It runs as a full-screen session, as a
line-at-a-time filter, as a one-shot command, or as a server for
another program (a word processor, an editor) to drive.

The name is that of a river, and the mascot is a river otter: a
small, practical animal that fetches things from the water and brings
them back. The otter holds a terminal, with its prompt, and wears a
teal scarf. [`doc/img/arno-mascot.png`](doc/img/arno-mascot.png) is the
full picture; [`doc/img/logo.svg`](doc/img/logo.svg) is the emblem.

This is the raz rebuild of an earlier arno written in Pascal. It reads
the conversations that one saved. [PLAN.md](PLAN.md) has the decisions
and the stages.

## See it

There is no recording yet. It will be made, not filmed, as the other
projects' are: a script that types at arno on a pseudo-terminal and
writes down what it draws. Until then, `make check` runs arno against
a stub model and shows what it does.

## Get it

You need Linux, `make`, [raz 0.25.0](https://raz.lucelad.workers.dev)
on your `PATH`, and the OpenSSL development files (the default TLS
backend; `TLS=gnutls` selects rnet's GnuTLS one). arno links libc,
pthreads and the TLS libraries. `make check` also needs
[concha](https://github.com/ldiaz94/concha).

arno is built over its sibling libraries: rnet (HTTP and TLS) is a
directory beside arno's, and rnet, rtui, rjson, rzone, rwalk and
rterm are installed first, with `make install` in each checkout (they
go to `~/.raz/lib`).

    workspace/
    ├── arno/
    └── rnet/

    git clone https://github.com/ldiaz94/arno.git
    git clone https://github.com/ldiaz94/rnet.git
    cd arno
    make              # build/arno
    make check        # the tests
    make install      # arno and its manual pages into ~/.local

`make install` puts `arno` in `~/.local/bin` and its manual pages in
`~/.local/share/man`. For another place for rnet, set `RNET`. The
[Makefile](Makefile) has the other settings.

Then choose a provider. Make `~/.config/arno/config` (or
`$XDG_CONFIG_HOME/arno/config`), a text file with one `key = value`
to a line and `#` for a comment:

    provider = ollama
    model = llama3.2

| Provider | `provider =` | Key, read from the environment |
|---|---|---|
| Ollama | `ollama` | none |
| Ollama Cloud | `ollama-cloud` | `OLLAMA_API_KEY` |
| OpenAI | `openai` | `OPENAI_API_KEY` |
| Gemini | `gemini` | `GEMINI_API_KEY` |
| Claude | `claude` | `ANTHROPIC_API_KEY` |

The config never holds a secret: `key` names the variable. Put
`provider` first, since choosing one resets its settings; `model`,
`url`, `key` and `dialect` (`openai` or `anthropic`) then override the
preset. With no config, arno uses Ollama at
`http://localhost:11434/v1`. Any key arno does not know is passed to
the provider as a parameter (`temperature`, `top_p`, `max_tokens`).

## Learn it

From the project you want to work on:

    arno                          # a session: the full screen on a terminal
    arno 'Explain how the config is loaded.'    # one turn, new conversation
    arno --resume ID 'Simplify it.'             # one more turn of a saved one
    arno --serve                  # one session, for a program that drives it
    arno --attach [PID | -l]      # show another arno's session here, and type into it
    arno -h

The reply goes to standard output as it streams; tool calls and
questions go to standard error. With no terminal, each line of
standard input is a message or a command, and a question is answered
by a line: `y`, `n`, or `a` for always. After a `n`, the next line
says why. `ID` is a number from `/list` or a word of a title. The
exit status is 0 for a reply, 1 for a failed request or a
conversation not found, 2 for a mistake on the command line, and 130
for a turn stopped by C-c.

`man arno` has all of it. In a session, `/help` lists the commands;
these are the ones to start with:

| Command | What it does |
|---|---|
| `/new`, `/clear` | start a fresh conversation, or clear this one |
| `/list [WORD]`, `/load N\|ID\|WORD` | find and resume a saved conversation |
| `/mode [NAME]` | `chat`, `review`, `improve` or `pair`; the first two offer no editing tools |
| `/model [NAME]`, `/models`, `/provider [NAME]` | switch, or list, what answers |
| `/compact [FOCUS]` | replace the history with a summary |
| `/tools`, `/usage` | the tools on offer; tokens and cost |
| `/test [COMMAND]` | set and run the project's test command |
| `/remember [#tag,...] FACT`, `/forget`, `/my-memory` | facts kept for every conversation |
| `/notes` | this project's notes |
| `/stage [on\|off\|drop]` | the stage, below |
| `/quit` | leave (so does C-d) |

Attach a file with `@src/Arno.raz`, a line range with
`@src/Arno.raz:1-40`, or a path with spaces with `@"my file.txt"`.
Directories and images work too, if the model takes images.

| Key (full screen) | What it does |
|---|---|
| RET, M-RET | send; a new line in the input |
| C-c, C-d | stop the turn; quit |
| S-Tab | change mode |
| TAB, C-o | toggle a tool entry, all of them |
| PgUp, PgDn; S-Up, S-Down | scroll by a page, by a line |
| Up, Down; M-p, M-n | input history; by prefix |
| C-r | search the history |
| C-x C-e | edit the input in your editor |
| C-v | paste an image from the clipboard |
| M-v | copy mode: move, select and copy (OSC 52) as in tmux |

Completion offers commands and `@paths`. The man page has the other
keys, the copy-mode keys, and the config keys.

### What the model may do

The model has tools: `read`, `find`, `grep`, `def`, `outline`, `git`,
`run`, `check`, `edit`, `move`, `remove`, `note`, `search`, `fetch`
and `shell`. It reads freely inside the project; outside, it needs a
grant. Each change to a file shows its diff and asks. `run` is limited
to programs the config allows. `check` runs the test command you set.

**The stage.** With `stage = on` in the config, the model's edits go to a
copy of the project, and a turn's changes reach you as one diff and one
question, not one yes per edit. Nothing is applied to your tree
without your yes.

**The shell.** `shell` runs a command, but only in the stage's copy,
inside a jail made of Linux's unprivileged namespaces (no root, no
helper): the project is the only thing writable. It is off if the
config says `shell = no`, and it needs the stage.

**MCP servers.** A server of the Model Context Protocol, a program that
offers tools over standard input and output, is added to the config, a
line each:

    mcp = files npx -y @modelcontextprotocol/server-filesystem /home/me/work

Its tools reach the model as `NAME_TOOL`, and every call asks first,
with the arguments shown. A server is somebody else's program: the
question is the only guard.

**Serve and attach.** `arno --serve` runs one session for the program
that started it, speaking `~/lib/arnoc`'s protocol on standard input
and output; the host can offer tools of its own. `arno --attach`
shows any arno's session, a terminal's or a host's, in your terminal
and types into it.

## How it works

Six ideas, a few modules each, listed in the order to read them. Each
module opens with what it is, what it needs and what it leaves out.

**1. A conversation is data.** `Amsg` is the messages as records, read
and written as JSON back byte for byte. `Awire` sends them to a
provider in OpenAI's or Anthropic's wire format and reads the reply as
it streams. `Aconf` is the config; `Astore` keeps each conversation in
a file of its own, under a lock.

**2. Tools go through a fence.** `Afence` says where the model may reach
without asking: the project, a directory with a mark, at most two
levels up. `Afind` finds, searches and outlines files; `Arun` runs a
program to its end and catches what it writes; `Ahtml` turns a page to
text; `Aattach` makes the `@paths`. `Atools` lists the tools and runs
a call, asking when it must.

**3. The stage and the jail.** `Astage` is the copy of the project the
model works on, and the diff of what it did. `Ajail` is the sandbox
for `shell`, built of namespaces; `Ajailtest` is its test, apart from
the others because `Arun` is what runs a program in it.

**4. A turn is a loop.** `Agent` asks the model, runs the tools it
calls, and asks again with their results, until it answers with none.
`Aprompt` makes the system prompt from its sections; `Aahead` tells the
model what it would else spend its first steps finding out; `Amemory`
keeps the facts you asked it to; `Aprice` knows what a model costs;
`Amcp` brings the tools of MCP servers.

**5. One session, many ways in.** `Asession` is the conversations of
one run and the commands typed between turns. `Aboard` is the
transcript, `Ascreen` the full screen on rtui, with `Acopy`,
`Acomplete` and `Ahistory` for its copy mode, completion and recall.

**6. A session can be seen from elsewhere.** `Aview` makes a session
something others can watch, and `Aframe` the messages on a pipe or
socket that stay open. `Aserve` is `--serve` and `Aview` with `Ascreen`
is `--attach`. `Arno` ties it together: the command line.

## Correctness

Each module's `main` is its test, run by `make check`, and the program
is tried end to end: `test/oneshot.cn` runs one-shot turns against
`test/Astub.raz`, a model of the test's own, with a staged shell and
an MCP server (`test/Amcpstub.raz`); `test/serve.cn` drives `--serve`
with a host (`test/Ahost.raz`). `make compat` reads every conversation
the Pascal arno saved and writes it again, byte for byte. Everything
compiles with `-Werror`, and `make fmt` checks the layout.

## Size

14 202 lines of code in 29 modules, with 2 700 of comment, measured
with `rloc src`.

## Left out

- **A fence around `check` and `run`.** While the stage is up, the
  model's edits to the copy, a Makefile among them, are not asked
  about, and `check` and trusted `run` programs execute them outside
  the jail. Only `shell` is jailed.
- **The jail beyond x86_64.** It needs Linux 5.12 and x86_64.
- **MCP's pages and non-text.** `tools/list` is read to its first page,
  and content that is not text shows as `[type]`.
- **Editor peers**, and their protocol (stage 6b of the plan).
- **A mouse.** The screen is keys alone.

[PLAN.md](PLAN.md) lists what is still open.

## Licence

[ISC](LICENSE). Copyright © 2026 Luis Díaz.
