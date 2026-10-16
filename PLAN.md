# Plan: arno again, in raz

arno is rebuilt in raz, not ported. `~/lib/arno` (Free Pascal, 16,600
lines) is the reference for what arno does and what it learned; its
code is not translated. It is frozen as of 2026-10-16, and stays the
installed arno until the raz one covers daily work.

Every feature of the Pascal arno is kept: the full screen, `@path`
attachments, the stage, the jail and the shell tool, MCP, peers,
`--serve` and `--attach`, and what arno tells the model ahead of time.
What changes is the design, below, and what the eval log showed to be
dead weight (auto mode, brain and worker, plans) stays out.

## Decisions

- **HTTP in process, with rnet.** `Http.open` streams the body for
  server-sent events; TLS is rnet's `Tls`, over OpenSSL or GnuTLS.
  arno is then linked dynamically, needing libc and libssl, the
  libraries curl itself needs, and makes threads with pthreads. No
  curl, no rfetch, no fallback between them. A static arno that ran a
  fetcher was the other choice; it keeps a child process, a config on
  stdin to hide keys from `ps`, and SSE read from a pipe.
- **The screen is rtui's.** `TuiLoop` owns the terminal and the loop;
  arno writes the transcript view, copy mode, completion and the status
  line on top. What rtui lacks is asked of rtui, not built here.
- **One thread per request, and `TuiLoop.wake`.** A request runs on its
  own thread, with blocking reads, and wakes the loop when it has text.
  Only the loop's thread touches the board and draws. A stop is
  `Awire.Request.stopped`, asked after every read; one that must break
  into a wait signals the request's thread, whose `Sys.handle` makes
  the wait fail at once, as `^C` does in one-shot mode.
- **Memory by arena.** A turn's work goes in an arena dropped at the
  turn's end; the conversation, which lives for hours, keeps its own
  storage and is never pointed into from a turn's arena.
- **Messages are records,** not JSON trees: a message, its blocks, a
  tool call, its result. JSON is only how they are written to the wire
  and to disk, and the writer gives the same bytes for the same history,
  so the provider's prompt cache holds.
- **The formats on disk stay readable:** conversations in
  `~/.local/share/arno`, config in `~/.config/arno`, `stage.json`,
  `tests.json`, memory and notes. The raz arno loads every saved
  conversation the Pascal one wrote.
- **Peers are not te's.** The editor protocol is written down as its
  own page, `arno-peer(5)`: a client asks arno, an editor serves its
  buffers to arno, and an editor says which verbs it takes (read a
  buffer, open, edit); arno uses the disk for any it lacks. Discovery
  is by a directory of sockets and `$ARNO_EDITOR`, not by `te-*.sock`.
  te is one editor that speaks it. The viewer protocol of `--attach`
  gets its own socket, apart from the editor's.
- **`--serve` keeps its protocol.** arnold (`~/lib/arnold`, arno in a
  window) drives `arno --serve` through arnoc(3), so `wire.pas`'s
  messages stay as they are; arnold works against the raz arno
  unchanged, or changes with it in the same piece of work.
- **The eval drives the binary.** `eval/stub` (canned replies) and the
  jailed runs grade the raz arno and the Pascal one alike, so a stage
  can be compared with the reference by its transcripts and files.

## Stages

Each stage stands on its own, is used before the next starts, and is
one or more commits that build with `-Werror`.

1. **Core, one shot.** `arno 'question'` answers, streaming, against
   every provider, and `^C` keeps the text so far.
   - [x] a. `Amsg`, the messages as records and their JSON, read and
     written back byte for byte (`make compat`: every conversation the
     Pascal arno saved); `Awire`, both wire formats: the bodies, held
     byte for byte to the Pascal arno's own (its body functions, copied
     into a program, wrote the test's), the reply put together from
     its events, and `chat` over rnet, tried against a server of the
     test's own. rjson keeps numbers as text, so it serves.
   - [x] b. `Astore`: a conversation's file around its messages (title,
     named, model, system, turns), the list of them, last changed
     first, and the lock on arno's shared files. `make compat` saves
     every conversation the Pascal arno saved again, byte for byte.
     Two things differ, on purpose: an untitled conversation's title,
     cut at 60 bytes, is cut where a character starts, so that it is
     UTF-8; and the list holds only conversations, not `notes.json`,
     `stage.json` and `tests.json`, which the Pascal arno listed
     untitled.
   - [x] c. `Aconf` and `Arno`: the config (providers, params, keys),
     the Pascal arno's file and keys, and the one-shot program, `arno
     PROMPT` and `arno --resume ID PROMPT`, its reply streamed to
     standard output and what it says to standard error. Without the
     tools a turn has a short system prompt of its own, until stage 2
     brings the agent's. `test/oneshot.cn` runs it against a model's
     server of the test's own (`test/Astub.raz`). The config's
     `timeout` is the Pascal arno's, seconds for the whole request
     (curl's `max-time`), now rnet's deadline.
2. **The agent.** `Agent`: the loop of tool calls, read, find, grep,
   outline, edit (each approved), the fence, notes, memory, context
   files, `ahead`, `delegate` (a plain tool for a leading session, as
   in `4f21519`). Plain mode, a line at a time. The agent tells its
   front end what happens, and asks it what the human says, through a
   record of procedures; plain mode is one such front end, and the
   screen of stage 3 another, which runs a turn on its own thread and
   hands what it is told to the loop's. So the Board, the transcript a
   screen keeps, is stage 3's.
   - [x] a. `Afence`, `Atools` and `Agent`: the fence (the zone, paths
     resolved, grants asked a line at a time), the tolerant parser of
     a call's arguments, `read`, and the loop: the step cap, four
     failed steps in a row, a repeated read-only call refused, each
     ending in a hand-back. `arno PROMPT` runs a turn with the tools;
     the stub answers with calls a test asks for. Calls run one after
     another, each in an arena reset after it; forking those that
     only read waits until it is wanted. `read` stops before its
     note of where it cut, so the cap of every result can't cut the
     note off, as it did in the Pascal arno.
   - [x] b. `Afind`: `find`, `grep`, `outline`, `def`, over rwalk's
     walk, globs and ignore files (hidden names left out, links to
     files followed inside the fence); `Arun`, a program run with its
     output caught, for `git`. grep matches a fixed text until rrem
     matches patterns (it parses only, so far); the Pascal arno's
     `grep_cmd` and `find_cmd` (rg, fd) are gone. outline and def take
     raz as Pascal, know `proc`, and pass over lines inside a block
     comment that opens a line, which the Pascal arno took for
     declarations when prose began with "type" or "procedure".
   - [x] c. `edit` (approved, with its diff), `move`, `remove`; a
     declined change remembered and not asked again; "old text not
     found" naming the near misses. The front end's `ask` shows a
     detail, the diff, before its question, and `why` asks the reason
     for a no. A near miss names the first line whose blanks differ,
     not the first line alone. git's arguments that are on disk are
     fenced, as the Pascal arno's Guard fenced them.
   - [x] d. The system prompt in full: context files, `note` and
     notes.json, memory.json, `ahead` (the map, prefetch, stale
     notes); pruning; `turn_budget`. `Aprompt` makes the prompt,
     `Aahead` the map, prefetch and notes, `Aprice` the list prices
     turn_budget is counted in. The prompt leaves out, until their
     stages, the commands and modes (3), the scratch and the stage (4)
     and te (6). memory.json is read; `/remember` and `/notes` come
     with the screen. The map counts what rwalk walks, so hidden files
     are left out, where the Pascal arno counted what git tracks; the
     off-peak half price waits for the status line.
   - [x] e. `search`, `fetch` and `delegate`. fetch reads the page
     with rnet, 30 seconds and a megabyte at most, and `Ahtml` lays an
     HTML page out as text, as the Pascal arno's html(3) did; it knows
     Latin-1 and Windows-1252 besides UTF-8, and the commonest named
     characters. delegate is the agent's: a worker is a turn of the
     same loop, on config's worker model, over a conversation of its
     own. The tools that could only fail are not offered: search
     without searxng, note outside a project, delegate without a
     worker or to a worker.
   `check` and `run` run commands, and come with the jail, in stage 4.
3. **The full screen** on rtui: transcript, input, status line, copy
   mode, completion of `/` and `@`, `@path` attachments, `^V` images,
   `^X ^E`.
   - [x] a. `Asession`, the session: `arno` with no prompt reads a
     line at a time, each a turn of the same conversation or a
     command, and the one-shot run is a session of one turn. The
     commands that need no screen: `/help`, `/new`, `/clear`,
     `/compact`, `/list`, `/load`, `/export`, `/rename`, `/system`,
     `/mode`, `/model`, `/provider`, `/tools`, `/usage`, `/remember`,
     `/forget`, `/my-memory`, `/notes`, `/quit`; `Amemory` keeps the
     facts. The modes end the system prompt, and review and improve
     aren't offered edit, move and remove; Aprompt's tables of commands
     and modes serve `/help` and the model alike. `/clear` keeps the
     first exchange whole, its calls and results with it, where the
     Pascal arno kept two messages, which could leave a call without
     its result. A new id taken in the same second as a saved one
     gets `-2`, where the Pascal arno wrote over it. A turn's budget
     counts each request at its own model's price, a worker's too.
     `/models` waits for completion, `/test` and `/stage` for stage 4,
     `/clear-cache` for a cache of tool results, if one is wanted.
   - [x] b. The screen on rtui: the Board, the transcript, the input,
     the status line (with the context in use, which `/usage` then
     shows too), a turn on its own thread waking the loop, questions
     and their detail, shift-tab for the mode. `Aboard` is the
     transcript and its layout, done afresh at each draw for only the
     entries on the screen; `Ascreen` the loop, the input (rtui's
     editor, emacs's keys), the rule and the status line. Each line
     typed, a command too, runs as a job on a thread of its own, the
     first job preparing the session; a job's events reach the loop
     through a queue under a mutex, and an answer comes back by a pipe.
     A conversation /new, /load, /clear or /compact changes is shown
     again from its messages (`Asession.changed`). Shift-tab during a
     turn sets the mode for the next. A stop is heard at the next read
     of the reply, until raz can signal one thread.
   - [x] c. History and `^X ^E`. `Ahistory` keeps the lines sent in
     arno's `history`, as the Pascal arno did; the input recalls them
     with the arrows on its first and last line, `M-p` and `M-n` by
     what is typed, `C-r` by search. `^X ^E` is rtui's
     `TuiEdit.external`, the last exchange under git's scissors line.
   - [x] d. `@path` attachments and `^V` images. `Aattach` brings a
     file, its lines, a directory's listing or an image, as the Pascal
     arno's attach.pas did, less te's open files, `@git` and `@cmd`; a
     range must be N or N-M, so `@a.txt:2-3,` loses its comma, where
     the Pascal arno read `2-3,` as line 2. `^V` saves the clipboard's PNG by
     xclip, under `$XDG_RUNTIME_DIR`, removed as arno ends.
   - [x] e. Completion of `/` and `@`, and `/models`. `Acomplete`
     completes a command, its argument for /mode, /provider, /model
     and /load, and an @path, as the Pascal arno's Suggest and Files
     did, less te's open files; the screen shows a menu over the foot
     of the transcript. `/models` asks the server (`Awire.models`), or
     says arno's own list (`Awire.known`); what the server said
     completes /model. A command isn't completed during a job, which
     has the session.
   - [x] f. Copy mode. `Acopy`, on `M-v`: a cursor on the transcript
     as `Aboard.flatten` lays it out, emacs's keys and vi's letters
     (the Pascal arno took one or the other, as config's `keys` said),
     selecting characters or rows, searching, and copying by OSC 52;
     a line wrapped over rows is copied as the one line it was. The
     mouse is left out, as it is from the rest of the screen.
4. **Stage, jail, shell.** The stage worktree; the jail from
   unprivileged namespaces, with `eval/jailtest`'s 25 escapes kept and
   cases that must fail added; `run` and `shell`.
   - [x] a. `run`, `check` and `/test`. `run` starts a program of
     config's `run`, its arguments fenced (all of them, or only those
     on disk for `run_ro`), several commands parted by a lone `;` and
     asked about once, `always` trusting a program until the
     conversation changes, `env` of `run_env`'s names. `check` and
     `/test` run the project's test command, from `tests.json`
     (`Astore.keyed`) or config's `test_cmd`, keeping the end of the
     output; a failed `/test` is a turn. Each program starts detached
     (`Arun.Job`): in a session of its own, without a terminal or a
     display. raz's `spawn` makes a group, not a session, and a
     program with threads mustn't fork, so arno runs itself again as a
     helper (`Arun.child`), which calls setsid and runs the program in
     its place; the jail of 4d is entered the same way. `check` and
     `/test` start detached too, where the Pascal arno ran them in its
     own session, with the display.
   - [x] b. The scratch directory, per conversation, under the cache
     (`Astore.scratch`, made with the conversation's first use): a
     change in it (`Afence.ours`, resolved like any path) needs no
     approval, `run` and `check` see it as `$ARNO_SCRATCH`, and the prompt
     names it. A detached job's variables now take the place of arno's
     of the same name, which came first and won before. `/clear` empties it, `/compact` moves it to the new id, and
     start-up sweeps those a day old whose conversation is gone. Not
     as the Pascal arno did: `ours` doesn't refuse a file hard-linked
     to one outside the scratch until raz has a link count, and there
     is no `Forget`, which comes with `--serve` in stage 6.
   - [ ] c. The stage: `Astage` (the worktree, seeded from the tree as
     it stands; the diff asked about once at a turn's end; apply,
     drop, carry on resume), `/stage`, `stage.json`; the stage's copy
     joins the scratch in `ours`.
   - [ ] d. `Ajail` and `shell`: the namespaces by raz's `SYSCALL`,
     entered by the helper; the jail's own test, jailtest's 25 cases
     and cases that must fail; `shell` in the stage, its timeout, the
     tail kept, a flood past 4 MB killed.
5. **MCP.**
6. **Peers, serve, attach:** `arno-peer(5)`, `--serve`, `--attach`.
7. **The switch.** `make install`; the Pascal arno kept as `arno-fpc`
   for a while; `man desktop` updated.

## Asked of others first

- **rnet: bytes held back from `poll`.** `Conn` reads ahead into its
  own buffer, and a TLS backend holds decrypted bytes, so `poll` on the
  socket can say nothing while data waits. Done in rnet `3c15249`:
  `Conn.pending` counts both (a transport reports its own through
  `Conn.held`). arno's reads block on their own thread and don't need
  it.
- **raz: a signal to one thread.** A stop on the screen must break
  into the turn's wait for the server, as `^C` does in one-shot mode;
  `Sys.kill` signals the process, which any thread may take. Proposed
  in raz's PROPOSALS.md (`db917e5`): `Thread.signal(t, sig)`. Until
  then a stop waits for the next read.
- **rtui: the rows an editor's text takes.** The input grows with its
  text: done in rtui `f1f1b73`, `TuiEdit.rows`.
- **rtui: a program's own sequence to the terminal.** Copy mode sends
  OSC 52 to set the clipboard: done in rtui `b34b06d`,
  `TuiLoop.send`, written after the next draw.
- **raz: a file's link count.** `Sys.Info` has no `st_nlink`; the
  scratch's `ours` cannot refuse a file hard-linked to one outside it,
  as the Pascal arno did (`92b6bea`). Proposed in raz's PROPOSALS.md
  (`aa7f5df`): `Info.links`. Until then not checked.
- **rtui with pthreads.** `wake` is a write to a pipe and safe from a
  thread made by C; nothing else in rtui uses raz's `Thread`, and a
  job's thread wakes the loop as it should (3b).

## Open

- gzip of replies: rflate's `stream` would do it, but replies are
  small and requests can't be compressed. Not before it is wanted.
- A proxy (`https_proxy`): only if arno has to run behind one.

## What the Pascal arno learned

Each item is a test or a rule the rebuild must keep. The hash is the
commit in `~/lib/arno` that says more.

### Providers and the wire

- Anthropic caches only where marked: one `cache_control` on the
  system prompt (tools before it), one on the newest block of the last
  user turn. 95b6dd9
- Gemini 3 needs each call's `thought_signature` sent back for the rest
  of the turn, then dropped; a reasoning model's thinking likewise goes
  back only within the tool loop. aab3ac7, cb75d43
- Usage: `stream_options` for OpenAI-compatible servers;
  `message_start` and `message_delta` for Anthropic. aab3ac7
- Claude takes `output_config.effort`; OpenAI dialects take
  `reasoning_effort`; effort is per model (`effort = MODEL:LEVEL`).
  e1b8e75, 2ffaddd
- Tool-call fragments are put together by index; `^C` keeps the
  partial text; transport errors are reported as they are. d00a14d
- An image is one shape inside, translated to each dialect's. 763a84d
- Retry transport failures only, and a stream only before its first
  line, so half a reply is never replayed. 7598c61
- Model lists are a table kept by hand: Anthropic and Gemini have no
  list. Prices: off-peak rates, the nominal cost kept beside the billed,
  a tagged name (`model:0813`) falling back to the name before the
  colon. 7598c61, 74db7c8, 5d4ac44, b0a723e
- Arguments come in wrong shapes: an array sent as a string, `~` meant
  as `$HOME`. One tolerant parser, shared with the fence. 741d647,
  cb75d43, 542878d

### The agent and the model

- Four steps in a row whose calls all failed: hand back and ask what it
  was trying. At the step cap, ask for progress, not a question.
  4889a57, 64126bf
- A declined edit says nothing was changed and why not; the same
  declined change is not asked again in a conversation. e422da8,
  3de9436, e274c13
- Line numbers are parted from the text by a tab, or they leak into an
  edit's old text; "old text not found" names the near misses and how
  they differ. c84e93f, 74db7c8
- Repeated read-only calls in a turn are refused; `read` of a directory
  says so. cb75d43, 64126bf
- Notes: at most 30, a full list refuses, and a note goes only when all
  its paths are gone; never a note on what the code does now. 1f236c1,
  c15c67e
- Tool descriptions use placeholders, not examples a model copies; a
  tool's rules go in its description, not the system prompt. b54a18e,
  bf12703
- `run` batches commands with a lone `;` and asks once. c819d5e
- Old long results are pruned all at once, and only when the history
  has grown by half, so the prompt cache survives. 2ffaddd
- `max_steps` 30; `turn_budget` checked after every step; `run_env`
  (one `LS_COLORS` cost 22 test runs). 2ffaddd, 392a72a
- `--resume ID PROMPT` keeps the cache and scratch; a resumed
  conversation's stage edits are put back. c15c67e, 700343e
- Definitions found with one `git grep -l` over every name, not a walk
  per name; a forward declaration is not a second definition. db1bc0a
- `find`'s glob without `/` matches every name on the path. 42954a5

### Terminal, processes and files

- A tool that fails in a forked child must not run arno's exit and give
  the terminal back under the parent; the child drops the parent's
  key reading and drawing. ea91c38, 74f0a9b
- SIGTERM and SIGHUP give the terminal back, remove the socket and exit
  128+signal; children leave both alone. 52f139f
- `-h` exits before signals, config or any request. f991634
- `^V` saves the image when pasted, under `~/.cache/arno/paste/PID`,
  swept at exit and for dead pids. 84b5422, 0b6048e
- `@"path with spaces":N-M`; the title is made without attachments.
  5cc4266
- Context files from every directory between home and here. 394f743
- What goes into a conversation is valid UTF-8, a tool's output made so
  before it is kept: rjson reads only UTF-8, and every conversation the
  Pascal arno saved so far is. (Learned here, not there.)
- Never open a FIFO to read it; visit regular files only, by `lstat`,
  and don't follow links to directories. ea91c38
- Pipelines run with `pipefail`. 426582e
- fd's flag clusters read whole; fd's `-x`, `-X` and `--exec` refused.
  a29a826, 7620627, 2dd904d
- "Always" on a file grants its directory, never `/` or `$HOME`;
  `grant` and `trust` answer for a run with nobody there. 2013df6,
  7875a7e
- `edit` writes in place (mode and links survive); arno's own files
  are written to a temporary and renamed, under a lock, and reloaded
  before a change so two sessions don't lose each other's. 08ff3e1
- The tool cache is keyed on the arguments' exact text. c2f282f
- Only tools that need neither the human nor a shared connection are
  forked. 80726a9

### Jail and stage

- No secret on a command line: they go in a mode-600 file. 1806ac8
- The jail: no root; the tree read-only but for the named directories;
  `$HOME`'s secrets hidden; `/tmp`, `/dev/shm`, `/run` fresh; an env
  allow-list; the namespace killed on timeout; never unconfined; the
  cwd kept. `shell` keeps the tail and kills a flood past 4 MB.
  e28f617, 6e6038f
- The stage is a git worktree in `~/.cache/arno/stage/PID`, seeded from
  the tree as it stands, so the diff is the model's alone; tree against
  tree, nothing written to the human's repository; `git apply` all or
  nothing. Copies of dead pids are swept. f13ae1a, 84a128b
- Scratch: per conversation, in the fence, unreachable through a link
  or a hard link out, swept when its conversation is gone. 92b6bea

### Store

- Ordered by mtime in ns, with `updated`; each turn records its build
  and the tools git can't tell of (MCP, host); a `turns` ledger.
  5943575, 743ad84, cec7788
- `stage.json` and `tests.json` keyed by the project's real root.
  e31a875
- The log, `~/.local/state/arno/log`, holds no message text. e6ef05a

### Serve, attach, peers

- `--serve` writes its messages on its own descriptor, fd 1 made
  stderr; a cancel is heard mid-stream; lines in a turn are queued.
  74f0a9b
- Host tools: never forked or fenced; a clash with a builtin refused;
  builtins the host leaves out removed, not just unoffered. 74f0a9b
- Viewers written without waiting, each with an outbox, dropped a
  megabyte behind; questions go only to the owner. 46f4b24
- An empty id means the current conversation. dbabb29
- **Open in the Pascal arno, to be closed here:** a forged ask on the
  socket becomes the human's message, and an ask's `sock` names any
  socket for the reply to dial. The socket's mode, its directory (no
  `/tmp`) and who may connect are decided in `arno-peer(5)`. 52f139f,
  489851e
