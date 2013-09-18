umask 077
export NOW=$(date +'%H * 60 + %M' | bc)
export LOG=${LOG:-/var/log/parentrol}
export TMPDIR=${TMPDIR:-/tmp}

function log {
    echo $(date +'%Y/%m/%d %H:%M:%S') "$@" >> $LOG
}

function get_display {
    user=$1
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
    user=$1
    shift
    log "**** Kill user: $user ($@)"
    display=$(get_display $user) && {
        $DRY_RUN || {
            passwd -lq $user
            su $user -c "DISPLAY=$display gnome-session-quit --logout --no-prompt"
            sleep 10
            slay -clean $user
        }
    }
}

function warn_user {
    user=$1
    gracetime=$2
    log "**** Warn user: $user"
    display=$(get_display $user) && {
        $DRY_RUN || {
            su $user -c "DISPLAY=$display yad --title 'ATTENTION' --text='FIN DE SESSION DANS $gracetime MINUTES' --button=gtk-ok:0 --sticky --center --on-top --justify=center" &
        }
    }
}

function check_screensaver {
    user=$1
    log "Checking screensaver of $user"
    display=$(get_display $user) && {
        su $user -c "DISPLAY=$display LANG=C gnome-screensaver-command -q" | grep -q "is active" && return 0
    }
    return 1
}

function count_screensaver {
    user=$1

    if check_screensaver $user ; then
        file=$TMPDIR/parentrol-$user.screensaver
        if [ -e $file ]; then
            ss_count=$(<$file)
        else
            ss_count=0
        fi
        echo $(($ss_count + 1)) > $file
        return 1
    else
        ss_count=0
    fi

    log "screensaver count for $user: $ss_count"
    return 0
}

function check_logged_in_user {
    user=$1
    maxtime=$2
    gracetime=$3
    starttime=$4
    endtime=$5

    ss_count=$(count_screensaver $user)
    test -n "$ss_count" || return 0

    login_time=$(
        last -R $user | grep "$(date +'%a %b %_d')" | $TOOLSDIR/_login_time.awk
    )

    if [ $NOW -lt $starttime ]; then
        kill_user $user "too early"
        return 0
    elif [ $NOW -gt $endtime ]; then
        kill_user $user "too late"
        return 0
    elif [ $(($login_time - $ss_count)) -gt $(($maxtime + 1)) ]; then
        kill_user $user "time expired"
        return 0
    elif [ $login_time -gt $(($maxtime - $gracetime - 1)) -o $NOW -gt $(($endtime - $gracetime - 1))]; then
        if [ -e $TMPDIR/parentrol_$user.flag ]; then
            log "$user already warned"
        else
            touch $TMPDIR/parentrol_$user.flag
            warn_user $user $gracetime
        fi
        return 0
    fi

    return 1
}

function check_user {
    user=$1
    maxtime=$2
    gracetime=$3
    starttime=$4
    endtime=$5

    log "Checking $user ($starttime-$endtime: max $maxtime/$gracetime)"
    log "Display of $user is" $(get_display $user)

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
        # user currently not logged in
        log "$user not logged in"
    elif [ $NOW -lt $starttime ]; then
        log "$user cannot log in yet (too early)"
        $DRY_RUN || passwd -lq $user
    elif [ $NOW -gt $endtime ]; then
        log "$user cannot log in anymore (too late)"
        $DRY_RUN || passwd -lq $user
    else
        log "$user allowed, not logged in"
        # (always do it to return to sane defaults)
        $DRY_RUN || passwd -uq $user
        rm -f $TMPDIR/parentrol_$user.flag
    fi
}

function cat_or_default {
    file=$1
    default=$2
    if [ -e $file ]; then
        cat $file
    else
        echo $default
    fi
}
