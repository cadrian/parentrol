.SILENT:
.PHONY: build install

build:
#	nothing to do

install:
	install -d $(DESTDIR)/usr/sbin
	install -d $(DESTDIR)/usr/share/parentrol
	install -d $(DESTDIR)/etc/parentrol
	install -d $(DESTDIR)/etc/cron.d
	install -d $(DESTDIR)/etc/logrotate.d
	install -d $(DESTDIR)/etc/default
	install -m 0700 src/parentrol $(DESTDIR)/usr/sbin
	install -m 0544 src/tools/check.sh $(DESTDIR)/usr/share/parentrol/
	install -m 0644 src/tools/_common.sh $(DESTDIR)/usr/share/parentrol/
	install -m 0544 src/tools/_login_time.awk $(DESTDIR)/usr/share/parentrol/
	install -m 0644 etc/cron.d/parentrol $(DESTDIR)/etc/cron.d/
	install -m 0644 etc/logrotate.d/parentrol $(DESTDIR)/etc/logrotate.d/
	install -m 0644 etc/defaults/parentrol $(DESTDIR)/etc/default/
