#!/bin/bash

# This script must be started by each user that needs to be controlled.

if [ $(id -u) == 0 ]; then
    echo "Cannot run as root!" >&2
    exit 1
fi

export ETCDIR=${ETCDIR:-/etc}
test -e $ETCDIR/default/parentrol && . $ETCDIR/default/parentrol
export TOOLSDIR=${TOOLSDIR:-$(dirname $(readlink -f $0))}
export PARENTROLLER_DIR=${PARENTROLLER_DIR:-/tmp/parentroller}

case x"$1" in
    x-saver)
        if [ ! -d $PARENTROLLER_DIR ]; then
            echo "Directory $PARENTROLLER_DIR missing!" >&2
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

    x)
        log="$PARENTROLLER_DIR/$(id -un).log"
        inoticoming --foreground $PARENTROLLER_DIR --regexp "^$(id -un).saver$" $0 -saver {} \; >"$log" 2>&1
        ;;

    *)
        echo "Unknown argument: $1" >&2
        exit 1
        ;;
esac
