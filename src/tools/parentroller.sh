#!/bin/bash

# Parentrol: parental control
# Copyright (C) 2013-2015 Cyril Adrian <cyril.adrian@gmail.com>
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

function check_screensaver {
    #gnome-screensaver-command -q
    dbus-send --session --dest=org.gnome.ScreenSaver --type=method_call --print-reply --reply-timeout=5000 /org/gnome/ScreenSaver org.gnome.ScreenSaver.GetActive
}

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
        check_screensaver > "$file" 2>&1
        rm -f "$PARENTROLLER_DIR/$2".lock
        ;;

    x-quit)
        if [ ! -r "$PARENTROLLER_DIR/$2" ]; then
            echo "File $PARENTROLLER_DIR/$2 not found!" >&2
            exit 1
        fi
        echo $(date -R)": Logging out of GNOME session"
        gnome-session-quit --logout --force --no-prompt
        ;;

    x)
        user=$(id -un)
        log="$PARENTROLLER_LOGDIR/$user.log"
        test -w $log || {
            echo "Cannot log to $log" >&2
            exit 1
        }

        {
            echo
            echo $(date -R)": Starting parentroller"
            rm -f "$PARENTROLLER_DIR/$user.saver" "$PARENTROLLER_DIR/$user.quit"
            inoticoming --logfile "$log" --chdir $PARENTROLLER_DIR --stdout-to-log --stderr-to-log --regexp "^$user.saver$" $0 -saver {} \;
            inoticoming --logfile "$log" --chdir $PARENTROLLER_DIR --stdout-to-log --stderr-to-log --regexp "^$user.quit$" $0 -quit {} \;
        } >>$log 2>&1

        # The checker expects parentroller to be running.
        # Make the process wait without using CPU:
        run="$PARENTROLLER_DIR/$user.run"
        rm -f "$run" && mkfifo "$run"
        exec 3<> "$run" # fifo opened RW but never written to by this process; hence, wait...
        while true; do
            read r <&3
            echo "|$r" >>$log
        done
        ;;

    *)
        echo "Unknown argument: $1" >&2
        exit 1
        ;;
esac
