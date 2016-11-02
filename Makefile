# Installation directories.
PREFIX ?= $(DESTDIR)/usr
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man
UNITDIR ?= $(PREFIX)/lib/systemd/system
DSSLIBDIR ?= $(PREFIX)/lib/docker-storage-setup
SYSCONFDIR ?= $(DESTDIR)/etc/sysconfig

.PHONY: clean
clean:
	-rm -rf *~ \#* .#*

.PHONY: install
install:

	install -D -m 755 docker-storage-setup.sh ${BINDIR}/docker-storage-setup
	install -D -m 644 docker-storage-setup.service ${UNITDIR}/docker-storage-setup.service
	install -D -m 644 docker-storage-setup.conf ${DSSLIBDIR}/docker-storage-setup
	if [ ! -f ${SYSCONFDIR}/docker-storage-setup ]; then \
		install -D -m 644 docker-storage-setup-override.conf ${SYSCONFDIR}/docker-storage-setup; \
	fi
	install -D -m 755 libdss.sh ${DSSLIBDIR}/libdss.sh
	install -D -m 755 dss-child-read-write.sh ${DSSLIBDIR}/dss-child-read-write
	install -D -m 644 docker-storage-setup.1 ${MANDIR}/man1/docker-storage-setup.1
