# to be sourced

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


umask 077
export LANG=C
export NOW=$(date +'%H * 60 + %M' | bc)
export DAY=$(date +'%a')
export LOG=${LOG:-/var/log/parentrol.d/check.log}
export TMPDIR=${TMPDIR:-/tmp}/parentrol.$(id -u)
export PARENTROLLER_DIR=${PARENTROLLER_DIR:-/tmp/parentroller}

mkdir -p $TMPDIR $PARENTROLLER_DIR $(dirname $LOG)
chmod 1777 $PARENTROLLER_DIR

function log {
    echo $(date +'%Y/%m/%d %H:%M:%S') "$@" >> $LOG
}

function get_display {
    local user=$1
    local tty

    tty=$(last -R $user | grep "still logged in" | awk '$2 ~ /:[0-9]+/ {print $2}') && {
        test -n "$tty" && {
            echo $tty
            return 0
        }
    }
    tty=$(last -R $user | grep "still logged in" | awk '$2 ~ /tty[0-9]+/ {print $2}') && {
        test -n "$tty" && {
            ps -f -C Xorg | awk '$6 == "'$tty'" { print $9 }'
            return 0
        }
    }
    echo "not found"
    return 1
}

function kill_user {
    local user=$1
    local display

    shift
    log "**** Kill user: $user ($@)"
    display=$(get_display $user) && {
        $DRY_RUN || {
            passwd -lq $user
            {
                touch $PARENTROLLER_DIR/${user}.quit
                sleep 10
                slay -clean $user
            } >/dev/null 2>&1
            echo "Slayed user: $user" >&2 # will be mailed by cron
        }
    }
}

function warn_user {
    local user=$1
    local gracetime=$2
    local display

    log "**** Warn user: $user"
    display=$(get_display $user) && {
        $DRY_RUN || {
            su $user -c "DISPLAY=$display yad --title 'ATTENTION' --text='FIN DE SESSION DANS $gracetime MINUTES' --button=gtk-ok:0 --sticky --center --on-top --justify=center" &
        }
    }
}

function check_screensaver {
    local user=$1
    local display
    local saver
    local lock

    log "Checking screensaver of $user"
    display=$(get_display $user) && {
        #I'd have like the code below to work, but it does not work since gnome 3.8
        #su $user -c "DISPLAY=$display dbus-send --session --dest=org.gnome.ScreenSaver --type=method_call --print-reply /org/gnome/ScreenSaver org.gnome.ScreenSaver.GetActive" 2>/dev/null | grep -q "boolean true" && return 0

        ps axu | egrep "^$user[[:space:]]" | cut -c66- | egrep -q '^(/bin/bash )?'${TOOLSDIR%/}'/parentroller.sh$' || {
            echo "Parentroller for user $user seems not to be running (in $TOOLSDIR)!" >&2 # will be mailed by cron
            log "Error: parentroller for user $user seems not to be running. Considering screensaver inactive."
            return 1
        }

        saver=$PARENTROLLER_DIR/${user}.saver
        rm -f $saver*
        lock=$saver.lock
        /usr/bin/dotlockfile -l -r 3 $lock || {
            log "Error: $lock already existing?? Ignoring"
        }
        chown $user:$user $lock # will be removed by parentroller, therefore it must belong to the right user
        echo $saver.data > $saver # triggers inotify => the user's parentroller
        chmod a+r $saver

        /usr/bin/dotlockfile -l -r 3 $lock || {
            log "$lock not removed by user, parentroller taking too long? Considering screensaver inactive."
            rm -f $saver*
            return 1
        }
        log $(ls $saver*)
        test -r $saver.data || {
            log "No data returned by parentroller of $user. Considering screensaver inactive."
            rm -f $saver*
            return 1
        }
        while read line; do
            log " | $line"
        done < $saver.data
        if grep -q "boolean true" $saver.data; then
            log "Screensaver is running for $user!"
            rm -f $saver*
            return 0
        elif grep -q '^Error org.freedesktop.DBus.Error.NoReply:' $saver.data; then
            # Looks like the dbus daemon refuses to answer when not on the right console
            log "Screensaver check failed for $user, certainly because the virtual console is not active"
            rm -rf $saver*
            return 0
        fi
        rm -f $saver*
    }
    return 1
}

function count_screensaver {
    local user=$1
    local file
    local ss_count

    file=$TMPDIR/$user.screensaver
    if [ -e $file ]; then
        ss_count=$(<$file)
    else
        ss_count=0
    fi

    if check_screensaver $user ; then
        ss_count=$(($ss_count + 1))
        log "screensaver is active for $user: $ss_count"
        echo $ss_count > $file
        return 1
    fi

    log "screensaver count for $user: $ss_count"
    echo $ss_count
    return 0
}

function check_logged_in_user {
    local user=$1
    local maxtime=$2
    local gracetime=$3
    local starttime=$4
    local endtime=$5
    local ss_count
    local login_time

    login_time=$(
        last -R $user | grep "$(date +'%a %b %_d')" | $TOOLSDIR/_login_time.awk
    )

    log "$user: login_time=$login_time ("$(last -R $user | grep "$(date +'%a %b %_d')")")"

    if [ $NOW -lt $starttime ]; then
        kill_user $user "too early"
        return 0
    elif [ $NOW -gt $endtime ]; then
        kill_user $user "too late"
        return 0
    else
        ss_count=$(count_screensaver $user) || return 0

        if [ $(($login_time - $ss_count)) -gt $(($maxtime + 1)) ]; then
            kill_user $user "time expired"
            return 0
        elif [ $(($login_time - $ss_count)) -gt $(($maxtime - $gracetime - 1)) -o $NOW -gt $(($endtime - $gracetime - 1)) ]; then
            if [ -e $TMPDIR/$user.flag ]; then
                log "$user already warned"
            else
                touch $TMPDIR/$user.flag
                warn_user $user $gracetime
            fi
            return 0
        fi
    fi

    return 1
}

function ensure_parentroller {
    local user=$1
    local desktop=/home/$user/.config/autostart/parentroller.sh.desktop

    test -e $desktop || {
        cat > $desktop <<EOF
[Desktop Entry]
Type=Application
Name=Parentroller
Exec=${TOOLSDIR%/}/parentroller.sh
Hidden=false
NoDisplay=false
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
Comment=Parentroller
EOF

        chmod 750 $desktop
        chown $user:$user $desktop
    }
}

function check_user {
    local user=$1
    local maxtime=$2
    local gracetime=$3
    local starttime=$4
    local endtime=$5

    log "Checking $user ($starttime-$endtime: max $maxtime/$gracetime)"
    log "Display of $user is" $(get_display $user)
    last -R $user | grep "still logged in" | while read line; do
        log " | $line"
    done

    ensure_parentroller $user

    if last -R $user | grep -v "$(date +'%a %b %_d')" | grep -q "still logged in" ; then
        kill_user $user "still logged in since yesterday"
        return 0
    fi

    if last -R $user | grep -q "still logged in" ; then
        if check_logged_in_user $user $maxtime $gracetime $starttime $endtime ; then
            return 0
        fi
    fi

    if last -R $user | grep -q "$(date +'%a %b %_d')" ; then
        log "$user logged in and out today"
    elif [ $NOW -lt $starttime ]; then
        log "$user cannot log in yet (too early)"
        $DRY_RUN || passwd -lq $user
    elif [ $NOW -gt $endtime ]; then
        log "$user cannot log in anymore (too late)"
        $DRY_RUN || passwd -lq $user
    else
        log "$user allowed, not logged in yet today"

        # (always do it to return to sane defaults)
        $DRY_RUN || passwd -uq $user
        rm -f $TMPDIR/$user.flag $TMPDIR/$user.screensaver
    fi
}

function cat_or_default {
    local file=$1
    local default=$2

    if [ -e $file.ovr ]; then
        cat $file.ovr
    elif [ -e $file.$DAY ]; then
        cat $file.$DAY
    elif [ -e $file ]; then
        cat $file
    else
        echo $default
    fi
}
