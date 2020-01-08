prefix		::= $(shell knoconfig prefix)
libsuffix	::= $(shell knoconfig libsuffix)
KNO_CFLAGS	::= -I. -fPIC $(shell knoconfig cflags)
KNO_LDFLAGS	::= -fPIC $(shell knoconfig ldflags)
MYSQL_CFLAGS    ::= $(shell etc/pkc --cflags mysqlclient)
MYSQL_LDFLAGS   ::= $(shell etc/pkc --libs mysqlclient)
CFLAGS		::= ${CFLAGS} ${MYSQL_CFLAGS} ${KNO_CFLAGS} 
LDFLAGS		::= ${LDFLAGS} ${MYSQL_LDFLAGS} ${KNO_LDFLAGS}
CMODULES	::= $(DESTDIR)$(shell knoconfig cmodules)
LIBS		::= $(shell knoconfig libs)
LIB		::= $(shell knoconfig lib)
INCLUDE		::= $(shell knoconfig include)
KNO_VERSION	::= $(shell knoconfig version)
KNO_MAJOR	::= $(shell knoconfig major)
KNO_MINOR	::= $(shell knoconfig minor)
PKG_RELEASE	::= $(cat ./etc/release)
DPKG_NAME	::= $(shell ./etc/dpkgname)
MKSO		::= $(CC) -shared $(CFLAGS) $(LDFLAGS) $(LIBS)
MSG		::= echo
SYSINSTALL      ::= /usr/bin/install -c
MOD_NAME	::= mysql
MOD_RELEASE     ::= $(shell cat etc/release)
MOD_VERSION	::= ${KNO_MAJOR}.${KNO_MINOR}.${MOD_RELEASE}

GPGID = FE1BC737F9F323D732AA26330620266BE5AFF294
SUDO  = $(shell which sudo)

default: ${MOD_NAME}.${libsuffix}

mysql.o: mysql.c makefile
	@$(CC) $(CFLAGS) -o $@ -c $<
	@$(MSG) CC "(MYSQL)" $@
mysql.so: mysql.o
	$(MKSO) $(LDFLAGS) -o $@ mysql.o ${LDFLAGS}
	@$(MSG) MKSO  $@ $<
	@ln -sf $(@F) $(@D)/$(@F).${KNO_MAJOR}
mysql.dylib: mysql.c makefile
	@$(MACLIBTOOL) -install_name \
		`basename $(@F) .dylib`.${KNO_MAJOR}.dylib \
		${CFLAGS} ${LDFLAGS} -o $@ $(DYLIB_FLAGS) \
		mysql.c
	@$(MSG) MACLIBTOOL  $@ $<

TAGS: mysql.c
	etags -o TAGS mysql.c

install:
	@${SUDO} ${SYSINSTALL} ${MOD_NAME}.${libsuffix} ${CMODULES}/${MOD_NAME}.so.${MOD_VERSION}
	@echo === Installed ${CMODULES}/${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}.${KNO_MINOR}
	@echo === Linked ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}.${KNO_MINOR} to ${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} \
			${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}
	@echo === Linked ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR} to ${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} ${CMODULES}/${MOD_NAME}.so
	@echo === Linked ${CMODULES}/${MOD_NAME}.so to ${MOD_NAME}.so.${MOD_VERSION}

suinstall doinstall:
	sudo make install

clean:
	rm -f *.o *.${libsuffix}
fresh:
	make clean
	make default

debian: mysql.c makefile \
	dist/debian/rules dist/debian/control \
	dist/debian/changelog.base
	rm -rf debian
	cp -r dist/debian debian

debian/changelog: debian mysql.c makefile
	cat debian/changelog.base | etc/gitchangelog kno-mysql > $@.tmp
	if test ! -f debian/changelog; then \
	  mv debian/changelog.tmp debian/changelog; \
	elif diff debian/changelog debian/changelog.tmp 2>&1 > /dev/null; then \
	  mv debian/changelog.tmp debian/changelog; \
	else rm debian/changelog.tmp; fi

dist/debian.built: mysql.c makefile debian debian/changelog
	dpkg-buildpackage -sa -us -uc -b -rfakeroot && \
	touch $@

dist/debian.signed: dist/debian.built
	debsign --re-sign -k${GPGID} ../kno-mysql_*.changes && \
	touch $@

dist/debian.updated: dist/debian.signed
	dupload -c ./debian/dupload.conf --nomail --to bionic ../kno-mysql_*.changes && touch $@

dpkg dpkgs: dist/debian.signed

update-apt: dist/debian.updated

debinstall: dist/debian.signed
	${SUDO} dpkg -i ../kno-mysql*.deb

debclean:
	rm -f ../kno-mysql_* ../kno-mysql-* debian/changelog

debfresh:
	make debclean
	make dist/debian.built
