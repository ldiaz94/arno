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
  Only the loop's thread touches the board and draws.
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

1. **Core, one shot.** `Json` (rjson if it can keep numbers as text,
   else our own), `Msg` (the records), `Wire` (OpenAI-compatible and
   Anthropic: requests, SSE, tool calls, usage), `Store` (reads and
   writes the conversations), config. `arno 'question'` answers,
   streaming, against every provider, and `^C` keeps the text so far.
2. **The agent.** `Agent` and `Board`: the loop of tool calls, read,
   find, grep, outline, edit (each approved), the fence, notes, memory,
   context files, `ahead`, `delegate` (a plain tool for a leading
   session, as in `4f21519`). Plain mode, a line at a time.
3. **The full screen** on rtui: transcript, input, status line, copy
   mode, completion of `/` and `@`, `@path` attachments, `^V` images,
   `^X ^E`.
4. **Stage, jail, shell.** The stage worktree; the jail from
   unprivileged namespaces, with `eval/jailtest`'s 25 escapes kept and
   cases that must fail added; `run` and `shell`.
5. **MCP.**
6. **Peers, serve, attach:** `arno-peer(5)`, `--serve`, `--attach`.
7. **The switch.** `make install`; the Pascal arno kept as `arno-fpc`
   for a while; `man desktop` updated.

## Asked of others first

- **rnet: bytes held back from `poll`.** `Conn` reads ahead into its
  own buffer, and a TLS backend holds decrypted bytes, so `poll` on the
  socket can say nothing while data waits. rnet wants `Conn.pending`,
  covering both, for any program with an event loop. arno doesn't need
  it (its reads block on their own thread); it is rnet's step, on the
  owner's word.
- **rtui with pthreads.** `wake` is a write to a pipe and safe from a
  thread made by C; check that nothing else in rtui needs raz's
  `Thread`.

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
