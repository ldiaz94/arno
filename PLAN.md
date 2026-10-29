# Plan: arno again, in raz

arno is rebuilt in raz, not ported. `~/lib/arno` (Free Pascal, 16,600
lines) is the reference for what arno does and what it learned; its
code is not translated. It is frozen as of 2026-10-16, and stays the
installed arno until the raz one covers daily work.

Every feature of the Pascal arno is kept: the full screen, `@path`
attachments, the stage, the jail and the shell tool, MCP, peers,
`--serve` and `--attach`, and what arno tells the model ahead of time.
What changes is the design, below, and what the eval log showed to be
dead weight (auto mode, brain and worker, plans) stays out, though
stage 8 takes workers up again, behind a plan agreed first.

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
     is no `Forget`, which came with `--serve` in stage 6.
   - [x] c. The stage: `Astage` (the worktree, seeded from the tree as
     it stands; the diff asked about once at a turn's end; apply,
     drop, carry on resume), `/stage`, `stage.json`; the stage's copy
     joins the scratch in `ours`. `Astage` runs git as a detached
     `Arun.Job`, which has no input, so `git apply` reads the diff
     from a file beside the copy, where the Pascal arno wrote to
     git's standard input; a diff past 64 MB isn't offered. `Afence`
     keeps `root`, the human's project, beside `zone`, which is the
     copy while the stage is up: notes and `tests.json`, as
     `stage.json`, are kept under `root`, as the Pascal arno kept
     them under its `Root`. The question is the session's
     (`Asession.propose`), after a turn is saved, in `/test` and a
     one-shot too; with nobody to ask, or a no, the diff stays in the
     copy and in the scratch's `stage.diff`, and `/load` and
     `--resume` carry it back. Not done: the
     copy isn't removed on SIGTERM or SIGHUP (arno has no handler, so
     the next stage sweeps it, as after a crash), and `ours` doesn't
     refuse a hard-linked file, as for the scratch. `ours` does refuse
     the copy's `.git` and all below it, and every git command in the
     copy pins the git directory `up` recorded and turns fsmonitor off,
     since a model-written `.git` could name a program git would run
     unjailed at the turn's end. Open until stage 8 (4d jails only `shell`): `check`
     and a trusted `run` program (make, say) execute the copy's own files,
     which the model edits without approval, so `edit Makefile` then
     `check` runs code nobody approved, outside the jail.
   - [x] d. `Ajail` and `shell`: the namespaces (user, mount, net,
     pid, ipc) by raz's `SYSCALL`, entered by the helper. `Arun.Job`
     gains `jail`, `rw`, `timeout`, `flood` and `dir`; the helper
     (`--arno-jail`, `Arun.child`) calls `Ajail.enter` before it execs,
     and the program's environment is cut to the allow-list (`PATH`,
     `HOME`, `USER`, `LOGNAME`, `LANG`, `LC_*`, `TZ`) plus `TERM=dumb`
     and `TMPDIR=/tmp`. `Arun.start` gives a third result, whether the
     program was killed for a flood past `flood` (4 MB for `shell`),
     and `Arun.jails` says, by running a jailed `true` once, whether
     the kernel allows it; the Pascal arno probed by forking, which a
     program with threads mustn't. `shell` is offered where `edit` is,
     unless config's `shell` is `no` or the jail doesn't work; its
     timeout (default 120 s, at most 600) is the jail's, status 124.
     The jail's own test is `Ajailtest` (it can't be `Ajail`'s main,
     as Arun imports Ajail): jailtest's 25 cases, kept, and escapes
     that must fail added (the device, proc and run files, remounts,
     links out of a writable directory, a secret file read). Not as
     the Pascal arno did: the waiting parent polls (1 to 20 ms) rather
     than sleeping on SIGALRM, as raz's signal handlers can only note
     a signal; x86_64 only (the syscall numbers). As in the Pascal
     arno, `shell` is offered only while the stage is up
     (`Atools.shellOn`), and works and writes only in the stage's copy
     (`Afence.stage`): in the project's own tree it could rewrite
     `.git` or the Makefile, which git and `check` run outside the jail.
5. [x] **MCP.** `Amcp`: servers from config's `mcp = NAME COMMAND ARG...`
   lines (each its own line, which `Aconf.nth` reads), started over
   pipes, their tools offered as `NAME_TOOL` (at most 64 bytes), every
   call asked about (`run NAME_TOOL?`, then why after a no) and not
   fenced, as in the Pascal arno; in every mode, as there. Not as the
   Pascal arno did: an answer is told by its id and by having no
   `method`, so a server's own request with the same id isn't taken for
   it; a stop (`Human.stopped`) ends the wait for an answer, which the
   Pascal arno also did, but every 100 ms by poll, and a late answer is
   passed by later; a call with no content says `(no output)`; a
   server's `tools/list` is read once, with no `nextCursor`; a tool
   whose name the belt already has is left out; each server is in a
   process group of its own (not a session) so that ^C leaves it, and
   ends by SIGTERM after its input is closed (SIGKILL after a second),
   registered with `Rt.atExit`; its standard error is thrown away. The
   test is `Amcp`'s `main` over `test/Amcpstub.raz` (`build/mcpstub`),
   and `oneshot.cn` runs a call through the program. Also, `Atools`'s
   declined text is one `declined` for `approve`, `run` and MCP.
6. **Peers, serve, attach:** `arno-serve(5)` (the host and viewer protocol), `arno-peer(5)` (the editors'), `--serve`, `--attach`.
   - [x] a. `--serve`, `--attach` and `Forget`. `Aframe` is the
     netstring messages of `~/lib/arnoc`, byte for byte; `Aview` the
     session as others see it: every change to the Board is made
     through it, told to the owner (a host) and to the viewers on the
     session's socket, and it is the screen of an attached session
     too (`apply`); `Aserve` is `arno --serve` with the whole of
     `arnoc(3)`'s protocol: hello with its tools and builtins (`Atools`
     gained the host's tools, `addHost`, `allow` and `hosting`, and
     `Aprompt.setHost` the "# Host" section), ask and call round
     trips, cancel, lines queued, and the seven requests (recent,
     paste, rename, forget, models, system, setsystem). `Ascreen` tells
     the viewers of a terminal's arno, and `Ascreen.attach` is the
     viewer's screen: the same screen, copy mode and history, its
     lines and cancels sent to the session. `arno --attach [PID | -l]`.
     `Astore.forget` removes a saved conversation and its scratch
     directory. `test/Ahost.raz` is a host in miniature that drives
     `build/arno --serve` against the stub (`test/serve.cn`), with a
     viewer on the socket, `--attach -l`, the screen of `--attach` and
     a terminal's arno over pseudo-terminals.
     What differs from the Pascal arno: a job runs on a thread, as the
     screen's does, and the loop reads the host meanwhile, so a cancel
     is heard at once and refuses a question or call waiting, but a
     turn still stops at the next read of the reply; `models`, and
     `rename`, `system` and `setsystem` of the current conversation,
     wait for the running job to end, since it may be changing the
     provider or the conversation, and are answered then (the Pascal
     arno answered mid-turn), and so does every request that comes
     while one waits, so that replies keep the order of requests, which
     arnold pairs by; a viewer is told of a waiting
     question only as `status · a question waits in WHO`, not with
     the question (`waiting for approval in OWNER: QUESTION`); `--attach -l`
     removes the socket of a process that has ended, not one that is
     only slow to answer; the
     session's socket is `$XDG_RUNTIME_DIR/arno/PID.view`, or `run/` in
     arno's cache, in a directory of mode 700 and a socket of mode 600
     that refuses another user, no longer `arno-PID.sock` in `/tmp`
     shared with te, and `who` is answered as one framed message
     (`ok`, owner, root, title); a terminal's arno has at most seven
     viewers (rtui's `MaxWatch`), and a viewer's unsent tail waits for
     the next change (`TuiLoop.watch` is read-only). `--attach -l`
     prints its fields parted by tabs.
   - [x] b. The editors' protocol, `arno-peer(5)`: a client asks arno,
     an editor serves its buffers (read, open, edit), `$ARNO_EDITOR`
     and a directory of sockets, the forged ask closed. Written as a
     page first (`doc/arno-peer.5`), the protocol as dwa speaks it, and
     a session stands without it. `Apeer` is the module: the server
     half on `$XDG_RUNTIME_DIR/arno-PID.sock` (umask 077, none without
     the variable, removed at the end; apart from `--attach`'s
     `PID.view`), read by the session's loop without waiting, in a
     terminal's session (`Ascreen`) and under `--serve` (`Aserve`); the
     client half, which calls the editor that asked last, else
     `$ARNO_EDITOR`, else the best `dwa-PID.sock` as dwa scores arno's.
     `Atools` offers `editor` and `open` only while an editor is
     reachable (asked at each turn's start, and not while staged),
     reads through it, makes an approved edit through it and refuses to
     move or remove what it has open; `Aprompt` tells the model so.
     `Asession.ask` runs an ask as a turn. Tests: `Apeer`'s `main` (the
     framing, every refusal of a reply socket, the server, the client
     against an editor played by a thread), and `test/peer.cn` with
     `test/Apeerhost.raz`, an editor in miniature, over a pseudo-terminal
     against the real arno; also tried by hand against the real dwa.
     What differs from the Pascal arno: an ask is never the human's
     message: the transcript shows it as the editor's, with its path and
     lines, and the model's message and system prompt say so; an ask's
     reply socket must be a live user's socket directly in the socket
     directory, named NAME-PID.sock, or the ask is refused, as is a path
     with a control character, a connection of another user's
     (`Sys.peer`, SO_PEERCRED) and, under `--serve`, every ask (as the
     Pascal arno did, with its host's name); no socket without
     `$XDG_RUNTIME_DIR`, never in `/tmp`; the socket is read without
     waiting, not on a thread, so a client that says nothing holds one of
     eight slots; `$TE_SOCK` and `te-PID.sock` are gone for
     `$ARNO_EDITOR` and `dwa-PID.sock`; the turn's answer has no
     Sources footer, which the raz arno does not make; a file open in
     the editor but not on the disk can't be read by `read`; the
     `buffers` verb is not asked, so `@` completion doesn't offer the
     editor's buffers. A one-shot and a plain session take no ask.
7. **The switch.** `make install`; the Pascal arno kept as `arno-fpc`
   for a while; `man desktop` updated.
8. **Less asking, more context.** The transcripts of October showed
   models refused basic programs about 14 times, sweeping the disk for
   what `~/r/CLAUDE.md` says, and one session past 600K tokens; they
   seldom asked permission in prose. Each step a commit of its own:
   - [x] Run names its programs. Models called `run` with `ls`, `bash`,
     `sh` and `wc` and, refused, guessed again, a turn each time. The
     tool's description now ends with the programs allowed and those
     that run without asking (`Atools.runOffer`), and `Readers` (`ls wc
     head file stat`) are always allowed, trusted and fenced as
     `run_ro`'s, so `run` is offered even with an empty `run`.
   - [x] `shell` offered wherever the jail works, not only staged
     (`4a80d17`); withdrawn again by the next step, for safe.
   - [x] Safety, auto or safe. Auto, the default, is staged: edits in
     the copy unasked, `shell` there, one diff a turn. Safe is not:
     each change asked, no `shell`, so every read outside the project
     goes through the fence's question. Config's `safety`,
     `/safety auto|safe`, kept per project in `stage.json`; `/stage`
     keeps only offering and `drop`. A project git doesn't keep has no
     stage, and is safe, said at start-up.
   - [x] Auto runs `check` and `run` in the jail too, the copy and the
     scratch writable, no network: in the copy the model can rewrite
     the Makefile that `check` runs (`Atools.confine`). Where the jail
     can't be made they run as before. A test that needs the network,
     or a cache in the home, fails staged; a profile may open that up.
   - [x] The ignored dependency directories (`node_modules`, `.venv`,
     `venv`, at the top only) reach the copy as links to the human's
     (`Astage.linkDeps`), left out of the diff, read-only in the jail;
     the prompt says installing is the human's: no network in the
     jail, and an install's scripts are the classic way in. Out of the
     jail, where it can't be made, a link is written through, but the
     file tools ask, since it leads outside the copy.
   - [x] `/mode build`: a supervisor, the session's model, plans with
     the human first and has the plan approved, then hands its steps
     to workers by `delegate`, reviews and merges what they did, and
     runs `check`. It edits only small fixes itself; anything more goes
     back to a worker. The `plan` tool, build's alone, writes plan.md
     in the scratch and asks; a no brings the reason back, nobody to
     ask is a no. Until the last answer to `plan` in the conversation
     is yes, edit, move, remove and delegate are refused (not shell,
     to look with), so
     `/new` drops the approval and `/load` restores it. Round 7's
     lessons are in the mode's text: brief richly, pass findings on,
     few larger steps. `build_steps` and `build_budget` (200, $3.00)
     bound its turns; safe, `/mode build` says it works best staged.
   - [x] Each worker in a jailed worktree of its own, made from the
     supervisor's copy, giving back its diff and a report (what it did,
     read, left); one that hits its step cap hands back its copy, not
     nothing. `Astage.fork` makes worker N's copy, `PID.wN` beside the
     stage's, from the copy's tree as it stands, by the same `plant`
     as `up`; for its turn it is `Afence.stage` and the zone, and the
     working directory, so edit, shell, check and run go there
     unchanged. `gather` puts the lead's copy back, takes the diff
     against the fork's tree and a `--numstat` line a file, and removes
     the worker's copy at once, not at the merge: the diff is all the
     lead can use, kept as `worker-N.diff` in the scratch. `merge
     {worker, apply}` brings it in by `carry`, all or nothing, or drops
     it; one that no longer fits stays. Build's gate covers `merge`.
     Safe, workers work as before. Every git command in a copy now
     takes its pinned git directory as an argument (`pin`), not by
     comparing with `Afence.stage`. Left for parallel workers: the
     zone, the stage and the working directory are the process's,
     swapped for a worker's turn.
   - [x] Worker models chosen per brief, from config's `workers`.
     `delegate` takes a `model`, one of `workers` (an enum in its
     schema, listed in its description with each one's list price);
     another is refused with the list; the first of `workers` is the
     default (`worker`, which named it, is read only for old configs).
     The worker's turn runs, is priced and gets its effort as that model's (`prov.model`), and its report
     line names the model. Build mode tells the lead to weigh each step.
   - [x] Workers bounded by money, not steps. A cheap worker ran out of
     `max_steps` long before its budget, so a flash model's survey
     stopped half done. A worker's turn is now bounded by the budget
     `delegate` gives it (`budget`, in dollars), out of what the lead's
     turn has left (`Agent.stopAt`) and all of that if it names none;
     `build_steps` is only a backstop. Its report line says what it
     cost. `/budget` shows or sets the turn's budget for the session,
     build mode's in build mode.
   - [ ] A project's own context, kept by arno. What the human's other
     tools learned of a project (Claude Code's memory and rules) can't
     go in the repository, and notes are too small for it (30 lines of
     200 characters). arno's directory gets `projects/ROOT/`, where an
     AGENTS.md is read as a context file of the project, last, as the
     most particular; @imports as any other's.
   - [ ] arno-claude: Claude Code's knowledge, made arno's. A concha
     script, installed with arno, run hourly by a systemd user timer
     and by hand. For each repository Claude Code has worked in (the
     cwd its sessions record), and every worktree of it, it writes
     `projects/ROOT/AGENTS.md`: the memory entries
     (`~/.claude/projects/NAME/memory`, NAME the repository's main
     path with every character but a letter, digit or - made -), and
     a line for each of `.claude/rules/*.md`, its `paths:` and where
     to read it. One way: the file is arno-claude's alone, written
     whole each run, to a temporary renamed over it. arno knows
     nothing of Claude Code's files.
   - [ ] Roles. A worker starts blank; Claude Code's started from
     `.claude/agents/security.md` and knew the project's risks. A role
     is `projects/ROOT/roles/NAME.md`, its first line its description;
     `delegate` takes a `role`, the roles listed in its description,
     and the role's text leads the brief. arno-claude writes the
     project's and `~/.claude/agents`' as roles, their front matter
     (Claude Code's tools and models) left out.
   - [ ] The human's words in every brief. An audit's lead turned "can a
     user reach data that isn't theirs" into briefs about "procedures
     that take an ID", and its workers, given the profile and sign-up
     routers, missed a user making themselves admin: the question had
     been narrowed before it reached them. `brief` adds, after the
     lead's task, the human's message that began the turn, marked as
     context: the task stays the lead's, and the worker reports on it,
     but it sees what the work is for and can say what the task left
     out. Cut at a few thousand bytes.
   - [ ] An all-clear is a finding. The same lead re-read its workers'
     findings but passed on their "checked, clean" as given, and two
     were wrong. Build's step 3 says a worker's "nothing found" is a
     claim like any other, checked against the code before it is
     passed on, where the risk is highest first. Build's prompt is also
     a builder's; a line for read-only jobs (a survey, an audit): the
     steps are areas, there is nothing to merge, and the end is a
     report whose every finding and every all-clear the lead has
     checked.
   - [ ] Who said it. A worker's text, calls and results reach the
     screen through the lead's Front, so its sixty calls read as the
     lead's own and nothing tells them apart. Front gets the speaker,
     0 for the lead and N for worker N, set by `work`; each
     `Aboard.Entry` keeps it, and `--serve` sends it (arno-serve(5)).
     Nothing on the screen changes yet.
   - [ ] Workers' conversations kept. A worker's conversation is gone
     once it reports, so what it read can't be checked afterwards. It
     is kept as `worker-N.json` in the scratch, beside `worker-N.diff`,
     and the report line names it.
   - [ ] Views. `/view [lead|all|N]` and a key that cycles them choose
     what the transcript draws; every entry stays on the board, as
     draw only lays out what is shown, and copy mode follows the view.
     The status line says the view, so a filtered one is never taken
     for the whole. In `all`, every line says who spoke, the lead most
     plainly: its entries flush left in the plain colours, a worker's
     indented under a gutter label, `w2 glm-5.3-flash`, in a colour of
     its own, and a header where the speaker changes, so a worker's
     run reads as one block and the lead's return is plain.
   - [ ] A worker as one line. In the lead's view each worker is a line
     under its `delegate`, kept up to date: `w2 glm-5.3-flash · step 23
     · $0.04 · read enterprise/cv.ts`. Opening it shows its view. The
     shape parallel workers need, and may wait for them.
   - [ ] arnold filters by the speaker as the screen does.
   - [ ] Workers in parallel.
   - [ ] Queued prompts. Enter while a turn runs does nothing now, so the
     human waits to say the next thing. It is queued instead: shown above
     the input, dim, with a count on the status line, and run in order,
     each as its own turn, as the last ends; a slash command takes its
     place in the line. Up takes the last back to edit; ^C stops the turn
     and keeps the queue, a second ^C clears it. A turn that ends on an
     error or a stop holds the queue until Enter. An attached viewer
     queues on the host, so every screen shows the same queue.
   - [ ] An eval: a task with a good plan approved first, supervisor
     and workers against one model alone.
   - [x] Context files in an editor's sessions. `ask` was put once, at
     start-up, to a human who might not look, and its `n` (also for no
     answer) held for the session only. The answer is now kept per
     project (`context.json`), asked once, a turn with nobody to ask
     uses it, and with none kept says the files are left out. No
     answer (end of input, a gone screen) is 0, not kept.
   - [x] `fetch` and `grep` give at most so much, and say where more is.
     fetch shows 20000 bytes of the text from a byte `offset`, grep the
     same of matches; each ends with what is left out and how to get it.
   - [x] Profiles: `[DIR]` sections of the config, for the project
     whose root is DIR or below it, applied over the global keys once
     the root is found, the deepest last, a value replaced whole
     (`Aconf.apply`). Only a project's keys may be set there (`run`,
     `trust`, `test_cmd`, `safety`, `context_files` and the like); a
     provider's, or a header naming no directory, is warned of.
     `tests.json` and `stage.json` stay, the human's later word, over
     the sections. New keys for the jail: `jail_net = yes` keeps the
     network, `jail_rw` adds writable directories, a missing one passed
     over. In the human's config, never the project's, so a cloned
     repository grants itself nothing.
   - [x] Named checks: `check(name, files?)`, a profile's `check.NAME`
     commands, `{}` standing for files inside the fence. The description
     lists them and `name` is an enum; each file must exist, lie inside
     the fence (refused, not asked) and not start with `-`, and is
     shell-quoted. Files for a command without `{}` are an error; none
     for one with it runs the whole suite. Still unasked and jailed.
   - [x] `outline` and `def` know `const f = () =>` and `= function`:
     at any indentation, with async, generics and a type after the
     parameters; a call holding an arrow is not one.
   - [ ] rlsp, done in dwa: `LspWire`, `LspServer` and `LspText` made a
     library of their own, dwa unchanged in what it does.
   - [x] `Alsp`: a profile's language server for a file type; an edit's
     result carries the server's diagnostics. Config's `lsp.EXT`, also
     in a section (`Aconf.Prefixes`). Started on a turn's first edit of
     the type, rooted at the zone, stopped at the turn's end, not the
     session's: between turns the copy changes untold, and a jailed
     server dies with the turn's thread (Ajail's PDEATHSIG). Staged, it
     runs in the jail through Arun's helper (`Arun.helped`, handed to
     `LspServer.start` as its program), state and cache in the jail's
     /tmp. Blocks: 10 s to start, 2 s for each edit's diagnostics,
     pushed or pulled; at most ten errors and warnings. One that fails
     is said once and not tried again. Left for rlsp: `start` makes the
     server lead a process group, so the helper's setsid fails and a
     jailed server stays in the terminal's session.
   - [ ] `def` and `refs` by name through the server, the rule of thumb
     kept where there is none.
   - [ ] raz-lsp, done in raz: `raz -q` and a thin server on rlsp, as
     concha-lsp is.
   Left out: an index of the code (the map, notes, memory and context
   files are there; the context files did not arrive), and raz's tools
   as an MCP server (raz-lsp serves other harnesses better). Round 7 of
   the Pascal arno's eval dropped a brain and workers; that task was
   one vague line, and a plan agreed first is what workers lack.

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
  (`aa7f5df`); done in raz `261c3a0`, `Info.links`, not yet in a
  release (0.17.2 lacks it). When `RAZVERSION` moves to one that has
  it, `Afence.ours` refuses a file whose `links` is over 1.
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
- **Open in the Pascal arno, closed in 6b:** a forged ask on the
  socket becomes the human's message, and an ask's `sock` names any
  socket for the reply to dial. The socket's mode, its directory (no
  `/tmp`) and who may connect are decided in `arno-peer(5)`. 52f139f,
  489851e
