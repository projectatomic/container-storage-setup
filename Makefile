DOCKER ?= docker
# Installation directories.
PREFIX ?= $(DESTDIR)/usr
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man
UNITDIR ?= $(PREFIX)/lib/systemd/system
CSSLIBDIR ?= $(PREFIX)/lib/container-storage-setup
SYSCONFDIR ?= $(DESTDIR)/etc/sysconfig

.PHONY: clean
clean:
	-rm -rf *~ \#* .#*

.PHONY: install
install: install-docker install-core

.PHONY: install-docker
install-docker:
	install -D -m 644 docker-storage-setup.service ${UNITDIR}/${DOCKER}-storage-setup.service
	if [ ! -f ${SYSCONFDIR}/${DOCKER}-storage-setup ]; then \
		install -D -m 644 docker-storage-setup-override.conf ${SYSCONFDIR}/${DOCKER}-storage-setup; \
		echo "CONTAINER_THINPOOL=docker-pool" >> ${SYSCONFDIR}/${DOCKER}-storage-setup; \
	fi
	install -d -m 755 ${BINDIR}
	(cd ${BINDIR}; ln -sf /usr/bin/container-storage-setup ${DOCKER}-storage-setup)
	install -D -m 644 docker-storage-setup.1 ${MANDIR}/man1/${DOCKER}-storage-setup.1

.PHONY: install-core
install-core:
	install -D -m 755 container-storage-setup.sh ${BINDIR}/container-storage-setup
	install -D -m 644 container-storage-setup.conf ${CSSLIBDIR}/container-storage-setup
	install -D -m 755 libcss.sh ${CSSLIBDIR}/libcss.sh
	install -D -m 755 css-child-read-write.sh ${CSSLIBDIR}/css-child-read-write
	install -D -m 644 container-storage-setup.1 ${MANDIR}/man1/container-storage-setup.1
