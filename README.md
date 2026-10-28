<p align="center">
  <img src="docs/assets/arno-mascot.png" width="240" alt="Arno, a river otter holding a little terminal with a green prompt">
</p>

<h1 align="center">arno</h1>

<p align="center">A harness for language models in the terminal.</p>

<p align="center">
  Written in <a href="https://raz.lucelad.workers.dev">raz</a> ·
  <a href="#getting-started">Getting started</a> ·
  <a href="#using-arno">Usage</a> ·
  <a href="PLAN.md">Roadmap</a> ·
  <a href="LICENSE">ISC license</a>
</p>

Ask a question, explore a codebase, review a diff, or work through a change.
arno brings the model, the conversation, and the tools into the terminal
you already use. It streams replies, keeps conversations on disk, and
shows file changes for approval.

**This is the raz rebuild, under active development.** The full screen,
agent tools, attachments, and saved conversations work. Staged edits,
the jailed shell, MCP, and editor peers are still ahead; `--serve` and
`--attach` are not implemented yet. [PLAN.md](PLAN.md) tracks the work.

## What it does

- **Talk to different providers.** Ollama, Ollama Cloud, OpenAI, Gemini,
  and Claude presets, with configurable endpoints and models.
- **Read before changing.** Find files, search text, inspect definitions,
  outline code, and look through git history and diffs. File edits,
  moves, and removals ask for approval outside the conversation's scratch.
- **Keep context.** Resume conversations, compact long histories, attach
  files or images, and keep project notes and remembered facts.
- **Stay in the terminal.** A full-screen transcript with completion,
  input history, an external editor, and copy mode; one-shot and plain
  line input are available too.
- **Run the tools you choose.** Allow configured programs, run a project's
  test command, fetch pages, and optionally search through SearXNG or
  delegate to a worker model.

## Getting started

### Build

Use a Linux environment with `make`, [raz 0.25.0](https://raz.lucelad.workers.dev),
and the development files for OpenSSL, the default TLS backend.
The build links against libc, pthreads, and the TLS libraries.
[Concha](https://github.com/ldiaz94/concha) is needed for `make check`.

arno expects rnet alongside its directory, for its TLS backend; rnet, rtui, rwalk, rterm, rjson and rzone must be installed first (`make install` in each checkout, which puts it in `~/.raz/lib`):

```text
workspace/
├── arno/
└── rnet/
```

From the parent directory:

```sh
git clone https://github.com/ldiaz94/arno.git
git clone https://github.com/ldiaz94/rnet.git
cd arno
make
./build/arno --help
```

The other libraries are installed first, with `make install` in each checkout
(they go to `~/.raz/lib`, raz's `RAZ_PATH`). For another layout, set `RNET`
when running make. `TLS=gnutls` selects rnet's GnuTLS backend.
See the [Makefile](Makefile) for the build settings. There is no
`make install` target yet; run `build/arno` directly or put the binary
on your `PATH`.

### Choose a provider

Create `~/.config/arno/config`, or `$XDG_CONFIG_HOME/arno/config` if
`XDG_CONFIG_HOME` is set. It is a plain text file with one `key = value`
setting per line; `#` starts a comment line.

For an existing Ollama server, choose a model you have available:

```ini
provider = ollama
model = llama3.2
```

The default Ollama endpoint is `http://localhost:11434/v1`.

For OpenAI, for example:

```ini
provider = openai
model = gpt-5
```

Set `OPENAI_API_KEY` in arno's environment before starting it.
Keys are read from environment variables; the config's `key` setting
names a variable, rather than containing the secret itself.

| Provider | Config value | Key variable |
| --- | --- | --- |
| Ollama | `ollama` | None |
| Ollama Cloud | `ollama-cloud` | `OLLAMA_API_KEY` |
| OpenAI | `openai` | `OPENAI_API_KEY` |
| Gemini | `gemini` | `GEMINI_API_KEY` |
| Claude | `claude` | `ANTHROPIC_API_KEY` |

Put `provider` before its overrides: selecting a provider resets its
parameters. `model`, `url`, `key`, and `dialect` can override the preset;
the dialect is `openai` or `anthropic`. With no config, arno uses its
Ollama preset. Use `/models` to see the provider's models.

## Using arno

Run from the project you want to work on:

```sh
# Open a full-screen session when stdin and stdout are terminals.
./build/arno

# Ask once. The reply streams to stdout; tool activity goes to stderr.
./build/arno 'Explain how configuration is loaded in this project.'

# Continue a saved conversation by ID, list number, or title word.
./build/arno --resume ID 'Which parts would you simplify?'
```

Without a prompt, non-terminal input is read one line at a time.
One-shot runs print a resume hint when they finish. `Ctrl-C` stops a
turn and keeps the text received so far; in the full screen, stopping
may wait until the next read from the provider.

In a session, start with `/help`. A few useful commands:

| Command | Purpose |
| --- | --- |
| `/new` | Start a fresh conversation |
| `/list`, `/load N\|ID\|WORD` | Find and resume saved conversations |
| `/mode review` | Review code or changes without file-edit tools |
| `/mode improve` | Suggest simplifications without file-edit tools |
| `/mode pair` | Work through a feature step by step |
| `/provider NAME`, `/model NAME` | Switch provider or model |
| `/compact [FOCUS]` | Replace the history with a summary |
| `/tools`, `/usage` | Inspect available tools, tokens, and cost |
| `/test COMMAND` | Set and run this project's test command |
| `/remember FACT`, `/notes` | Keep a fact or inspect project notes |
| `/quit` | Leave the session |

Attach a file with `@src/Arno.raz`, a range with `@src/Arno.raz:1-40`,
or a path containing spaces with `@"path with spaces.txt"`. Directories
and images work too; image support depends on the selected model.

In the full screen, `Tab` completes commands and paths, `Shift-Tab`
cycles modes, `Ctrl-R` searches input history, `Ctrl-X Ctrl-E` opens
the external editor, and `Alt-V` enters copy mode. `Ctrl-V` pastes a
clipboard PNG through `xclip` when available.

## Files and tools

Conversations live in `~/.local/share/arno`; the raz rebuild can read
conversations saved by the Pascal arno. Configuration lives separately
in `~/.config/arno/config`.

Tools can read inside the project. Access outside it asks for a grant;
file changes show their diff and ask for approval. Each conversation
also has a scratch directory where the model may write without asking.
Context files such as `AGENTS.md` and `CLAUDE.md` are listed for approval
before they are read by default.

The `run` tool is limited to configured programs. `/test` and the
`check` tool use a test command you set. The jail is still planned, so
these commands currently run without its isolation.

Left out until the jail: while the stage's copy is up, the model edits
the copy's files, a Makefile among them, without asking, and `check` and
trusted `run` programs then execute them. Nothing is applied to your tree
without your yes, but what those commands run is not approved.

## Development

Read [PLAN.md](PLAN.md) for the design and current stage, and
[CLAUDE.md](CLAUDE.md) for the repository's working conventions.

```sh
make check    # Module tests and one-shot tests against a local stub
make fmt      # Check formatting; does not rewrite sources
make compat   # Check saved conversations round-trip byte for byte
```

`make compat` reads `~/.local/share/arno` by default; use `SAVED=PATH`
for another collection. `make check` uses the local stub instead of a
paid model API.

## The mascot

Meet **Arno**, a river otter with a terminal close at hand. The warm
terracotta fur and teal accents give a small, practical tool a friendly
face. The transparent [mascot PNG](docs/assets/arno-mascot.png) works on
both light and dark backgrounds.

## License

[ISC](LICENSE). Copyright © 2026 Luis Díaz.
