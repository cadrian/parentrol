# to be sourced

# Parentrol: parental control
# Copyright (C) 2013 Cyril Adrian <cyril.adrian@gmail.com>
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
export LOG=${LOG:-/var/log/parentrol.log}
export TMPDIR=${TMPDIR:-/tmp}/parentrol.$(id -u)

mkdir -p $TMPDIR

function log {
    echo $(date +'%Y/%m/%d %H:%M:%S') "$@" >> $LOG
}

function get_display {
    local user=$1
    local tty

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
                su $user -c "DISPLAY=$display gnome-session-quit --logout --no-prompt"
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

    log "Checking screensaver of $user"
    display=$(get_display $user) && {
        su $user -c "DISPLAY=$display dbus-send --session --dest=org.gnome.ScreenSaver --type=method_call --print-reply /org/gnome/ScreenSaver org.gnome.ScreenSaver.GetActive" 2>/dev/null | grep -q "boolean true" && return 0
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

    log "$user: login_time=$login_time"

    ss_count=$(count_screensaver $user) || return 0

    if [ $NOW -lt $starttime ]; then
        kill_user $user "too early"
        return 0
    elif [ $NOW -gt $endtime ]; then
        kill_user $user "too late"
        return 0
    elif [ $(($login_time - $ss_count)) -gt $(($maxtime + 1)) ]; then
        kill_user $user "time expired"
        return 0
    elif [ $login_time -gt $(($maxtime - $gracetime - 1)) -o $NOW -gt $(($endtime - $gracetime - 1)) ]; then
        if [ -e $TMPDIR/$user.flag ]; then
            log "$user already warned"
        else
            touch $TMPDIR/$user.flag
            warn_user $user $gracetime
        fi
        return 0
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
    log "Display of $user is" $(get_display $user)
    last -R $user | grep "still logged in" | while read line; do
        log " | $line"
    done

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
