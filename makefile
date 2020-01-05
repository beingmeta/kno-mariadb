prefix		::= $(shell knoconfig prefix)
libsuffix	::= $(shell knoconfig libsuffix)
KNO_CFLAGS	::= -I. -fPIC $(shell knoconfig cflags)
KNO_LDFLAGS	::= -fPIC $(shell knoconfig ldflags)
MYSQL_CFLAGS    ::= $(shell etc/pkc --cflags mysqlclient)
MYSQL_LDFLAGS    ::= $(shell etc/pkc --libs mysqlclient)
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
MKSO		::= $(CC) -shared $(LDFLAGS) $(LIBS)
MSG		::= echo
SYSINSTALL      ::= /usr/bin/install -c
MOD_NAME	::= mysql
MOD_RELEASE     ::= $(shell cat etc/release)
MOD_VERSION	::= ${KNO_MAJOR}.${KNO_MINOR}.${MOD_RELEASE}

GPGID           ::= FE1BC737F9F323D732AA26330620266BE5AFF294
SUDO            ::= ${SUDO:-$(shell which sudo)}

default: ${MOD_NAME}.${libsuffix}

mysql.so: mysql.c
	@$(MKSO) $(CFLAGS) -o $@ mysql.c
	@$(MSG) MKSO  $@ $<
	@ln -sf $(@F) $(@D)/$(@F).${KNO_MAJOR}
mysql.dylib: mysql.c
	@$(MACLIBTOOL) -install_name \
		`basename $(@F) .dylib`.${KNO_MAJOR}.dylib \
		${CFLAGS} -o $@ $(DYLIB_FLAGS) \
		mysql.c
	@$(MSG) MACLIBTOOL  $@ $<

TAGS: mysql.c
	etags -o TAGS mysql.c

install:
	@${SUDO} ${SYSINSTALL} ${MOD_NAME}.${libsuffix} \
			${CMODULES}/${MOD_NAME}.so.${MOD_VERSION}
	@echo === Installed ${CMODULES}/${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} \
			${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}.${KNO_MINOR}
	@echo === Linked ${CMODULES}/mongodb.so.${KNO_MAJOR}.${KNO_MINOR} \
		to mongodb.so.${MOD_VERSION}
	@${SUDO} ln -sf mongodb.so.${MOD_VERSION} \
			${CMODULES}/mongodb.so.${KNO_MAJOR}
	@echo === Linked ${CMODULES}/mongodb.so.${KNO_MAJOR} \
		to mongodb.so.${MOD_VERSION}
	@${SUDO} ln -sf mongodb.so.${MOD_VERSION} ${CMODULES}/mongodb.so
	@echo === Linked ${CMODULES}/mongodb.so to mongodb.so.${MOD_VERSION}

clean:
	rm -f *.o *.${libsuffix}
fresh:
	make clean
	make default

debian/changelog: makefile mysql.c \
		  debian/rules debian/control debian/changelog.base
	cat debian/changelog.base | etc/gitchangelog kno-mysql > $@

debian.built: mysql.c makefile mysql/*.c mysql/*.h \
		debian/rules debian/control debian/changelog
	dpkg-buildpackage -sa -us -uc -b -rfakeroot && \
	touch $@

debian.signed: debian.built
	debsign --re-sign -k${GPGID} ../kno-mysql_*.changes && \
	touch $@

debian.updated: debian.signed
	dupload -c ./debian/dupload.conf --nomail --to bionic ../kno-mysql_*.changes && touch $@

update-apt: debian.updated

debclean:
	rm -f ../kno-mysql_* ../kno-mysql-* debian/changelog

debfresh:
	make debclean
	make debian.built
