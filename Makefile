.SILENT:
.PHONY: build install

build:
#	nothing to do

install:
	install -d $(DESTDIR)/usr/share/parentrol
	install -d $(DESTDIR)/etc/parentrol
	install -d $(DESTDIR)/etc/cron.d
	install -d $(DESTDIR)/etc/logrotate.d
	install -d $(DESTDIR)/etc/default
	install -m 0544 tools/check.sh $(DESTDIR)/usr/share/parentrol/
	install -m 0644 tools/_common.sh $(DESTDIR)/usr/share/parentrol/
	install -m 0544 tools/_login_time.awk $(DESTDIR)/usr/share/parentrol/
	install -m 0644 cron.d/parentrol $(DESTDIR)/etc/cron.d/
	install -m 0644 logrotate.d/parentrol $(DESTDIR)/etc/logrotate.d/
	install -m 0644 defaults/parentrol $(DESTDIR)/etc/default/
