# to be sourced

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


umask 077
export LANG=C
export NOW=$(date +'%H * 60 + %M' | bc)
export DAY=$(date +'%a')
export LOG=${LOG:-/var/log/parentrol.d/check.log}
export TMPDIR=${TMPDIR:-/tmp}/parentrol.$(id -u)
export PARENTROLLER_DIR=${PARENTROLLER_DIR:-/tmp/parentroller}
export PARENTROLLER_LOGDIR=${PARENTROLLER_LOGDIR:-/tmp/parentroller}

mkdir -p $TMPDIR $PARENTROLLER_DIR $(dirname $LOG)
chmod 1777 $PARENTROLLER_DIR
chmod 755 $(dirname $LOG)
chmod 644 $LOG

function log {
    echo $(date +'%Y/%m/%d %H:%M:%S') "$@" >> $LOG
}

function check_parentroller {
    local user=$1
    local starttime=$2
    local check=2

    while [ $ckeck -gt 0 ]; do
        ps axu | egrep "^$user[[:space:]]" | cut -c66- | egrep -q '^(/bin/bash )?'${TOOLSDIR%/}'/parentroller.sh$' || {
            if [ $NOW -gt $(($starttime + 1)) ]; then
                echo "Parentroller for user $user seems not to be running (in $TOOLSDIR)!" >&2 # will be mailed by cron
                log "Error: parentroller for user $user seems not to be running."
                check=0
            else
                # $NOW is only slightly greater than $starttime, maybe the user just logged in and the parentroller is not yet started.
                log "Warning: parentroller for user $user seems not to be running (just logged in?) Waiting a bit."
                check=$(($check - 1))
                if [ $check -gt 0 ]; then
                    sleep 30
                fi
            fi
        }
    done
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

    log="$PARENTROLLER_LOGDIR/$user.log"
    touch "$log"
    chown $user:$user "$log"
    chmod 644 "$log"
}

function get_user_display {
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
    local starttime=$2
    local display

    shift 2
    log "**** Kill user: $user ($@)"
    display=$(get_user_display $user) && {
        $DRY_RUN || {
            local active_vt=$(fgconsole)
            local user_vt=$(grep "using VT number" /var/log/Xorg.${display#:}.log | egrep -o '[0-9]+$')
            log "Killing $user -- active VT is $active_vt / user VT is $user_vt"
            if [ $active_vt -ne $user_vt ]; then
                echo "User $user should be slain; waiting because s/he is not active."
                if [ -e $TMPDIR/$user.slay ]; then
                    log "$user already warned"
                else
                    touch $TMPDIR/$user.slay
                    su $user -c "DISPLAY=$display yad --title 'ATTENTION' --text='SESSION EXPIRÉE' --no-buttons --undecorated --fullscreen --sticky --center --on-top --justify=center" &
                fi
            else
                passwd -lq $user
                {
                    check_parentroller $user $starttime && {
                        test -p $PARENTROLLER_DIR/${user}.run && echo "Parentrol: ask quit $user" >> $PARENTROLLER_DIR/${user}.run
                        touch $PARENTROLLER_DIR/${user}.quit
                        sleep 10
                    }
                    slay -clean $user
                } >/dev/null 2>&1
                echo "User $user slain!" >&2 # will be mailed by cron
            fi
        }
    }
}

function warn_user {
    local user=$1
    local gracetime=$2
    local display

    log "**** Warn user: $user"
    display=$(get_user_display $user) && {
        $DRY_RUN || {
            su $user -c "DISPLAY=$display yad --title 'ATTENTION' --text='FIN DE SESSION DANS $gracetime MINUTES' --button=gtk-ok:0 --undecorated --sticky --center --on-top --justify=center" &
        }
    }
}

function check_screensaver {
    local user=$1
    local starttime=$2
    local display
    local saver
    local lock

    log "Checking screensaver of $user"
    display=$(get_user_display $user) && {
        check_parentroller $user $starttime || {
            log "Considering screensaver of $user inactive."
            return 1
        }

        local active_vt=$(fgconsole)
        local user_vt=$(grep "using VT number" /var/log/Xorg.${display#:}.log | egrep -o '[0-9]+$')
        if [ $active_vt -ne $user_vt ]; then
            log "Active VT is $active_vt, $user's VT is $user_vt - obviously the user is not active."
            # Hence behave as if the screensaver were active
            return 0
        fi

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
            log "$lock not removed by parentroller of $user... taking too long? Considering screensaver inactive."
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
        if grep -q "boolean true" $saver.data || grep -q "The screensaver is active" $saver.data; then
            log "Screensaver is running for $user!"
            rm -f $saver*
            return 0
        elif grep -q '^Error org.freedesktop.DBus.Error.NoReply:' $saver.data; then
            # Looks like the dbus daemon refuses to answer when not on the right console.
            # If we are not on the right console, we consider that the use is not active.
            log "Screensaver check failed for $user."
            rm -rf $saver*
            return 0
        fi
        rm -f $saver*
    }
    return 1
}

function count_screensaver {
    local user=$1
    local starttime=$2
    local file
    local ss_count

    file=$TMPDIR/$user.screensaver
    if [ -e $file ]; then
        ss_count=$(<$file)
    else
        ss_count=0
    fi

    if check_screensaver $user $starttime ; then
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
        kill_user $user $starttime "too early"
        return 0
    elif [ $NOW -gt $endtime ]; then
        kill_user $user $starttime "too late"
        return 0
    else
        ss_count=$(count_screensaver $user $starttime) || return 0

        if [ $(($login_time - $ss_count)) -gt $(($maxtime)) ]; then
            kill_user $user $starttime "time expired"
            return 0
        elif [ $(($login_time - $ss_count)) -gt $(($maxtime - $gracetime)) -o $NOW -gt $(($endtime - $gracetime)) ]; then
            if [ -e $TMPDIR/$user.warn ]; then
                log "$user already warned"
            else
                touch $TMPDIR/$user.warn
                warn_user $user $gracetime
            fi
            return 0
        else
            t=$(
                t1=$(($login_time - $ss_count - $maxtime))
                t2=$(($endtime - $NOW))
                if [ $t1 -gt $t2 ]; then
                    echo $t1
                else
                    echo $t2
                fi
            )
            log "$user has $t minute(s) left"
        fi
    fi

    return 1
}

function check_user {
    local user=$1
    local maxtime=$2
    local gracetime=$3
    local starttime=$4
    local endtime=$5

    log "Checking $user ($starttime-$endtime: max $maxtime/$gracetime)"
    log "Display of $user is" $(get_user_display $user)
    last -R $user | grep "still logged in" | while read line; do
        log " | $line"
    done

    ensure_parentroller $user

    if last -R $user | grep -v "$(date +'%a %b %_d')" | grep -q "still logged in" ; then
        kill_user $user $starttime "still logged in since yesterday"
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
        rm -f $TMPDIR/$user.warn $TMPDIR/$user.slay $TMPDIR/$user.screensaver
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
