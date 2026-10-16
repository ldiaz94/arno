# arno is a harness for language models in the terminal, written in raz
# over rjson (JSON) and rnet (HTTP and TLS), which it reaches with -I;
# they are siblings of this directory unless RJSON, RNET say otherwise.
# It builds with the raz on PATH, which must be the version it is
# written for, RAZVERSION: make warns of any other. Its tarball is on
# raz's website, at download/raz-$(RAZVERSION)-linux-x86_64.tar.gz.

RAZ ?= raz
RAZVERSION = 0.16.0
RAZSITE = https://raz.lucelad.workers.dev
# raz's tools, the formatter among them, lie beside its real path
RAZTOOLS = $(dir $(realpath $(shell command -v $(RAZ))))tools

ifneq "$(word 2,$(shell $(RAZ) --version 2>/dev/null))" "$(RAZVERSION),"
$(warning arno is written for raz $(RAZVERSION), from $(RAZSITE); $(RAZ) is $(or $(shell $(RAZ) --version 2>/dev/null),not found))
endif
RJSON ?= ../rjson
RNET ?= ../rnet
# rnet's TLS backend, OpenSSL unless TLS says GnuTLS
TLS ?= openssl
INC = -I src -I $(RJSON)/src -I $(RNET)/src -I $(RNET)/tls/$(TLS)
# the modules whose main is their test
MODS = Amsg Awire
SRC = $(wildcard src/*.raz)

all: check

build:
	mkdir -p build

# each module's main is its test
check: | build
	@for m in $(MODS); do \
	    $(RAZ) -Werror $(INC) -o build/$$m src/$$m.raz && build/$$m || exit 1; \
	done

# the conversations the Pascal arno saved, each read and written back
# byte for byte
SAVED ?= $(HOME)/.local/share/arno
compat: | build
	$(RAZ) -Werror $(INC) -o build/Amsg src/Amsg.raz
	@build/Amsg $(wildcard $(SAVED)/*.json) && echo "compat: $(words $(wildcard $(SAVED)/*.json)) files read and written back"

# the sources are as raz's formatter lays them out
fmt: | build
	$(RAZ) -o build/Pretty $(RAZTOOLS)/Pretty.raz
	@fail=0; for f in $(SRC); do \
	    build/Pretty $$f | cmp -s - $$f || { echo "not formatted: $$f"; fail=1; }; \
	done; test $$fail = 0

clean:
	rm -rf build

.PHONY: all check compat fmt clean
