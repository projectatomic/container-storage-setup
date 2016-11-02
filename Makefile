DOCKER ?= docker
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

	install -D -m 755 ${DOCKER}-storage-setup.sh ${BINDIR}/${DOCKER}-storage-setup
	install -D -m 644 ${DOCKER}-storage-setup.service ${UNITDIR}/${DOCKER}-storage-setup.service
	install -D -m 644 ${DOCKER}-storage-setup.conf ${DSSLIBDIR}/${DOCKER}-storage-setup
	if [ ! -f ${SYSCONFDIR}/${DOCKER}-storage-setup ]; then \
		install -D -m 644 ${DOCKER}-storage-setup-override.conf ${SYSCONFDIR}/${DOCKER}-storage-setup; \
	fi
	install -D -m 755 libdss.sh ${DSSLIBDIR}/libdss.sh
	install -D -m 755 dss-child-read-write.sh ${DSSLIBDIR}/dss-child-read-write
	install -D -m 644 ${DOCKER}-storage-setup.1 ${MANDIR}/man1/${DOCKER}-storage-setup.1
