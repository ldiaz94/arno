# arno is a harness for language models in the terminal, written in raz
# over rnet (HTTP and TLS) and rtui (the screen); rnet, rtui, rjson, rzone, rwalk
# and rterm are installed in ~/.raz/lib (make install in each checkout); only
# rnet's TLS backend is reached with -I, as a sibling unless RNET says otherwise.
# It builds with the raz on PATH, which must be the version it is
# written for, RAZVERSION: make warns of any other. Its tarball is on
# raz's website, at download/raz-$(RAZVERSION)-linux-x86_64.tar.gz.
# A build from raz's sources after a release, 0.21.0-1-g69d40f8, is that
# release's.

RAZ ?= raz
RAZVERSION = 0.25.0
RAZSITE = https://raz.lucelad.workers.dev
# raz's tools, the formatter among them, lie beside its real path
comma := ,
RAZTOOLS = $(dir $(realpath $(shell command -v $(RAZ))))tools

ifneq "$(firstword $(subst -, ,$(subst $(comma),,$(word 2,$(shell $(RAZ) --version 2>/dev/null)))))" "$(RAZVERSION)"
$(warning arno is written for raz $(RAZVERSION), from $(RAZSITE); $(RAZ) is $(or $(shell $(RAZ) --version 2>/dev/null),not found))
endif
RNET ?= ../rnet
# rnet's TLS backend, OpenSSL unless TLS says GnuTLS
TLS ?= openssl
INC = -I src -I $(RNET)/tls/$(TLS)
# the modules whose main is their test
MODS = Aframe Aview Amsg Awire Astore Aconf Afence Astage Afind Arun Ajailtest Aahead Amemory Aprice Aprompt Ahtml Amcp Atools Agent Aboard Ahistory Aattach Acomplete
SRC = $(wildcard src/*.raz)
# what the program is also built from, so that a change there rebuilds it
LIBS = $(wildcard $(RNET)/tls/$(TLS)/*.raz)
CONCHA = concha
# where make install puts the program (bin) and its man pages (share/man)
PREFIX ?= $(HOME)/.local

all: build/arno

build:
	mkdir -p build

# the program
build/arno: $(SRC) $(LIBS) | build
	$(RAZ) -Werror $(INC) -o $@ src/Arno.raz

# the model's server the tests ask, with no TLS
build/stub: test/Astub.raz $(LIBS) | build
	$(RAZ) -Werror -o $@ test/Astub.raz

# an MCP server, for Amcp's test and oneshot.cn
build/mcpstub: test/Amcpstub.raz $(LIBS) | build
	$(RAZ) -Werror -I src -o $@ test/Amcpstub.raz

# a host in miniature, which drives arno --serve
build/host: test/Ahost.raz src/Aframe.raz | build
	$(RAZ) -Werror -I src -o $@ test/Ahost.raz

# each module's main is its test; then the program's, test/oneshot.cn and
# test/serve.cn; then the man pages
check: build/arno build/stub build/mcpstub build/host man
	@for m in $(MODS); do \
	    $(RAZ) -Werror $(INC) -o build/$$m src/$$m.raz && build/$$m || exit 1; \
	done
	@$(CONCHA) test/oneshot.cn build/stub build/arno
	@$(CONCHA) test/serve.cn build/stub build/arno build/host

# the man pages, doc/*.1 and doc/*.5, must give no groff warning at all
man:
	@fail=0; for f in $(wildcard doc/*.1 doc/*.5); do \
	    out=$$(groff -mandoc -Tutf8 -ww -z $$f 2>&1) || fail=1; \
	    test -z "$$out" || { echo "$$out"; fail=1; }; \
	done; test $$fail = 0

# the program to $(PREFIX)/bin and the man pages to $(PREFIX)/share/man
install: build/arno man
	install -d $(PREFIX)/bin $(PREFIX)/share/man/man1 $(PREFIX)/share/man/man5
	install -m 755 build/arno $(PREFIX)/bin/
	for f in $(wildcard doc/*.1); do install -m 644 $$f $(PREFIX)/share/man/man1/; done
	for f in $(wildcard doc/*.5); do install -m 644 $$f $(PREFIX)/share/man/man5/; done

# removes what install put in place
uninstall:
	rm -f $(PREFIX)/bin/arno \
	    $(addprefix $(PREFIX)/share/man/man1/,$(notdir $(wildcard doc/*.1))) \
	    $(addprefix $(PREFIX)/share/man/man5/,$(notdir $(wildcard doc/*.5)))

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
	@fail=0; for f in $(SRC) test/Astub.raz test/Amcpstub.raz test/Ahost.raz; do \
	    build/Pretty $$f | cmp -s - $$f || { echo "not formatted: $$f"; fail=1; }; \
	done; test $$fail = 0

clean:
	rm -rf build

.PHONY: all check compat fmt man install uninstall clean
