#!/bin/bash

# Parentrol: parental control
# Copyright (C) 2013-2014 Cyril Adrian <cyril.adrian@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# NOTE:
# This script must be started by each user that needs to be controlled.

if [ $(id -u) == 0 ]; then
    echo "Cannot run as root!" >&2
    exit 1
fi

export ETCDIR=${ETCDIR:-/etc}
test -e $ETCDIR/default/parentrol && . $ETCDIR/default/parentrol
export TOOLSDIR=${TOOLSDIR:-$(dirname $(readlink -f $0))}
export PARENTROLLER_DIR=${PARENTROLLER_DIR:-/tmp/parentroller}
export PARENTROLLER_LOGDIR=${PARENTROLLER_LOGDIR:-/var/log/parentrol.d}

case x"$1" in
    x-saver)
        if [ ! -r "$PARENTROLLER_DIR/$2" ]; then
            echo "File $PARENTROLLER_DIR/$2 not found!" >&2
            exit 1
        fi

        file=$(<"$PARENTROLLER_DIR/$2")
        if [ -e "$file" ]; then
            echo "File $file must not exist!" >&2
            exit 1
        fi
        dbus-send --session --dest=org.gnome.ScreenSaver --type=method_call --print-reply --reply-timeout=5000 /org/gnome/ScreenSaver org.gnome.ScreenSaver.GetActive > "$file" 2>&1
        rm -f "$PARENTROLLER_DIR/$2".lock
        ;;

    x-quit)
        if [ ! -r "$PARENTROLLER_DIR/$2" ]; then
            echo "File $PARENTROLLER_DIR/$2 not found!" >&2
            exit 1
        fi
        echo "Logging out of GNOME session."
        gnome-session-quit --logout --no-prompt
        ;;

    x)
        user=$(id -un)
        log="$PARENTROLLER_LOGDIR/$user.log"
        rm -f $PARENTROLLER_DIR/$user.saver $PARENTROLLER_DIR/$user.quit
        inoticoming --foreground $PARENTROLLER_DIR --regexp "^$user.saver$" $0 -saver {} \; >"$log" 2>&1
        inoticoming --foreground $PARENTROLLER_DIR --regexp "^$user.quit$" $0 -quit {} \; >"$log" 2>&1
        ;;

    *)
        echo "Unknown argument: $1" >&2
        exit 1
        ;;
esac
