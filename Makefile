# arno is a harness for language models in the terminal, written in raz
# over rjson (JSON), rnet (HTTP and TLS), rwalk (walking directories),
# rtui (the screen), rterm (its colours) and rzone (local time), which
# it reaches with -I; they are siblings of this directory unless RJSON,
# RNET, RWALK, RTUI, RTERM, RZONE say otherwise.
# It builds with the raz on PATH, which must be the version it is
# written for, RAZVERSION: make warns of any other. Its tarball is on
# raz's website, at download/raz-$(RAZVERSION)-linux-x86_64.tar.gz.
# A build from raz's sources after a release, 0.21.0-1-g69d40f8, is that
# release's.

RAZ ?= raz
RAZVERSION = 0.21.0
RAZSITE = https://raz.lucelad.workers.dev
# raz's tools, the formatter among them, lie beside its real path
comma := ,
RAZTOOLS = $(dir $(realpath $(shell command -v $(RAZ))))tools

ifneq "$(firstword $(subst -, ,$(subst $(comma),,$(word 2,$(shell $(RAZ) --version 2>/dev/null)))))" "$(RAZVERSION)"
$(warning arno is written for raz $(RAZVERSION), from $(RAZSITE); $(RAZ) is $(or $(shell $(RAZ) --version 2>/dev/null),not found))
endif
RJSON ?= ../rjson
RNET ?= ../rnet
RWALK ?= ../rwalk
RTUI ?= ../rtui
RTERM ?= ../rterm
RZONE ?= ../rzone
# rnet's TLS backend, OpenSSL unless TLS says GnuTLS
TLS ?= openssl
INC = -I src -I $(RJSON)/src -I $(RNET)/src -I $(RNET)/tls/$(TLS) -I $(RWALK)/lib -I $(RTUI)/src -I $(RTERM)/src -I $(RZONE)/src
# the modules whose main is their test
MODS = Amsg Awire Astore Aconf Afence Afind Arun Aahead Amemory Aprice Aprompt Ahtml Atools Agent Aboard Ahistory Aattach Acomplete
SRC = $(wildcard src/*.raz)
# what the program is also built from, so that a change there rebuilds it
LIBS = $(wildcard $(RJSON)/src/*.raz $(RNET)/src/*.raz $(RNET)/tls/$(TLS)/*.raz $(RWALK)/lib/*.raz $(RTUI)/src/*.raz $(RTERM)/src/*.raz $(RZONE)/src/*.raz)
CONCHA = concha

all: build/arno

build:
	mkdir -p build

# the program
build/arno: $(SRC) $(LIBS) | build
	$(RAZ) -Werror $(INC) -o $@ src/Arno.raz

# the model's server the tests ask, with no TLS
build/stub: test/Astub.raz $(LIBS) | build
	$(RAZ) -Werror -I $(RJSON)/src -I $(RNET)/src -o $@ test/Astub.raz

# each module's main is its test; then the program's, test/oneshot.cn
check: build/arno build/stub
	@for m in $(MODS); do \
	    $(RAZ) -Werror $(INC) -o build/$$m src/$$m.raz && build/$$m || exit 1; \
	done
	@$(CONCHA) test/oneshot.cn build/stub build/arno

# the conversations the Pascal arno saved, each read and written back
# byte for byte: their messages, then the whole file
SAVED ?= $(HOME)/.local/share/arno
compat: | build
	$(RAZ) -Werror $(INC) -o build/Amsg src/Amsg.raz
	$(RAZ) -Werror $(INC) -o build/Astore src/Astore.raz
	@build/Amsg $(wildcard $(SAVED)/*.json) && build/Astore $(wildcard $(SAVED)/*.json) && \
	    echo "compat: $(words $(wildcard $(SAVED)/*.json)) files read and written back"

# the sources are as raz's formatter lays them out
fmt: | build
	$(RAZ) -o build/Pretty $(RAZTOOLS)/Pretty.raz
	@fail=0; for f in $(SRC) test/Astub.raz; do \
	    build/Pretty $$f | cmp -s - $$f || { echo "not formatted: $$f"; fail=1; }; \
	done; test $$fail = 0

clean:
	rm -rf build

.PHONY: all check compat fmt clean
