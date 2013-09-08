umask 077
export NOW=$(date +'%H * 60 + %M' | bc)

function get_display {
    user=$1
    tty=$(last -R $user | grep "$(date +'%a %b %_d')" | grep "still logged in" | awk '$2 ~ /tty[0-9]+/ {print $2}') && {
        test -z "$tty" && return 1
        ps -f -C Xorg | awk '$6 == "'$tty'" { print $9 }'
        return 0
    }
    return 1
}

function kill_user {
    user=$1
    shift
    display=$(get_display $user) && {
        echo "Kill user: $user ($@ -- DISPLAY=$display)"

        $DO_IT && {
            passwd -lq $user
            su $user -c "DISPLAY=$display gnome-session-quit --logout --no-prompt"
            sleep 10
            slay -clean $user
        }
    }
}

function warn_user {
    user=$1
    display=$(get_display $user) && {
        echo "Warn user: $user (DISPLAY=$display)"
        $DO_IT && {
            su $user -c "DISPLAY=$display yad --title 'ATTENTION' --text='FIN DE SESSION DANS 5 MINUTES' --button=gtk-ok:0 --sticky --center --on-top --justify=center" &
        }
    }
}

function check_screensaver {
    user=$1
    display=$(get_display $user) && {
        sudo su $user -c "DISPLAY=$display LANG=C gnome-screensaver-command -q" | grep -q "is active" && return 0
    }
    return 1
}

function count_screensaver {
    user=$1

    if check_screensaver $user; then
        file=/tmp/parentrol-$user.screensaver
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

    echo $ss_count
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
    elif [ $login_time -gt $(($maxtime - $gracetime)) -o $NOW -gt $(($endtime - $gracetime))]; then
        if [ -e /tmp/parentrol_$user.flag ]; then
            echo "User $user already warned"
        else
            touch /tmp/parentrol_$user.flag
            warn_user $user
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

    if last -R $user | grep -v "$(date +'%a %b %_d')" | grep -q "still logged in" ; then
        kill_user $user "still logged in since yesterday"
        return 0
    fi

    if last -R $user | grep -q "still logged in" ; then
        if check_logged_in_user $user $maxtime $gracetime $starttime $endtime; then
            return 0
        fi
    fi

    if last -R $user | grep -q "$(date +'%a %b %_d')"; then
        # user currently not logged in
        :
    elif [ $NOW -lt $starttime ]; then
        # user cannot log in yet (too early)
        $DO_IT && passwd -lq $user
    elif [ $NOW -gt $endtime ]; then
        # user cannot log in anymore (too late)
        $DO_IT && passwd -lq $user
    else
        # user either not logged in today or time not spent
        # (always do it to return to sane defaults)
        $DO_IT && grep -q "^$user:\!" /etc/shadow && passwd -uq $user
        rm -f /tmp/parentrol_$user.flag
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
