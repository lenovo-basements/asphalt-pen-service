PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
UDEVDIR ?= $(PREFIX)/lib/udev/rules.d
SYSCONFDIR ?= /etc

.PHONY: all check install uninstall

all:

check:
	python3 -m unittest discover -s tests -v

install:
	install -Dm755 asphalt-pen $(DESTDIR)$(BINDIR)/asphalt-pen
	install -d $(DESTDIR)$(UDEVDIR)
	sed 's|@BINDIR@|$(BINDIR)|g' udev/70-asphalt-pen.rules > $(DESTDIR)$(UDEVDIR)/70-asphalt-pen.rules
	chmod 644 $(DESTDIR)$(UDEVDIR)/70-asphalt-pen.rules
	@# keep an edited config
	[ -e $(DESTDIR)$(SYSCONFDIR)/asphalt-pen.conf ] || \
		install -Dm644 asphalt-pen.conf $(DESTDIR)$(SYSCONFDIR)/asphalt-pen.conf

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/asphalt-pen $(DESTDIR)$(UDEVDIR)/70-asphalt-pen.rules
