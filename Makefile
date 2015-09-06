.SILENT:
.PHONY: build install

build:
#	nothing to do

install:
	install -d $(DESTDIR)/usr/sbin
	install -d $(DESTDIR)/usr/share/parentrol
	install -d $(DESTDIR)/usr/share/gnome-shell/extensions/ParentrolView@cadrian.net
	install -d $(DESTDIR)/etc/parentrol
	install -d $(DESTDIR)/etc/bash_completion.d
	install -d $(DESTDIR)/etc/cron.d
	install -d $(DESTDIR)/etc/logrotate.d
	install -d $(DESTDIR)/etc/default
	install -m 0700 src/parentrol $(DESTDIR)/usr/sbin
	install -m 0544 src/tools/check.sh $(DESTDIR)/usr/share/parentrol/
	install -m 0544 src/tools/parentroller.sh $(DESTDIR)/usr/share/parentrol/
	install -m 0644 src/tools/_common.sh $(DESTDIR)/usr/share/parentrol/
	install -m 0544 src/tools/_login_time.awk $(DESTDIR)/usr/share/parentrol/
	install -m 0644 etc/bash_completion.d/parentrol $(DESTDIR)/etc/bash_completion.d/
	install -m 0644 etc/cron.d/parentrol $(DESTDIR)/etc/cron.d/
	install -m 0644 etc/logrotate.d/parentrol $(DESTDIR)/etc/logrotate.d/
	install -m 0644 etc/default/parentrol $(DESTDIR)/etc/default/
	install -m 0644 gnome/*.js $(DESTDIR)/usr/share/gnome-shell/extensions/ParentrolView@cadrian.net/
	install -m 0644 gnome/*.json $(DESTDIR)/usr/share/gnome-shell/extensions/ParentrolView@cadrian.net/
	install -m 0644 gnome/*.css $(DESTDIR)/usr/share/gnome-shell/extensions/ParentrolView@cadrian.net/
