#!/bin/bash

# Parentrol: parental control
# Copyright (C) 2013-2016 Cyril Adrian <cyril.adrian@gmail.com>
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


export ETCDIR=${ETCDIR:-/etc}
test -e $ETCDIR/default/parentrol && . $ETCDIR/default/parentrol

export DRY_RUN=${DRY_RUN:-true}
export ACTIVE=${ACTIVE:-true}
export TOOLSDIR=${TOOLSDIR:-$(dirname $(readlink -f $0))}
export LOCKDIR=${LOCKDIR:-$(dirname $(readlink -f $0))}

. $TOOLSDIR/_common.sh

$ACTIVE || {
    log "Not active"
    exit 0
}

test -d $ETCDIR/parentrol/users.d || {
    log "No users to watch"
    exit 0
}

/usr/bin/dotlockfile -l -r 3 -p $LOCKDIR/parentrol.lock || {
    log "**** parentrol locked! ($LOCKDIR/parentrol.lock)"
    exit 0
}

log "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
log "Starting parentrol checking session (NOW=$NOW DAY=$DAY)"

pids=""
for userdef in $(
    if [ -f $(readlink -f $ETCDIR/parentrol/profile) ]; then
        echo $ETCDIR/parentrol/profiles.d/$(< $ETCDIR/parentrol/profile)/users.d/*
    else
        echo $ETCDIR/parentrol/users.d/*
    fi
); do
    test -d $userdef && {
        user=$(basename $userdef)

        test -e /var/log/$user.log || {
            touch /var/log/$user.log
            chown $user:$user /var/log/$user.log
        }

        maxtime=$(cat_or_default $userdef/maxtime 120)
        gracetime=$(cat_or_default $userdef/gracetime 5)
        starttime=$(cat_or_default $userdef/starttime 0)
        endtime=$(cat_or_default $userdef/endtime $((24 * 60)))
        ban=$(cat_or_default $userdef/ban 0)

        check_user $user $maxtime $gracetime $starttime $endtime $ban &
        pids="$pids $!"
    }
done

wait $pids

/usr/bin/dotlockfile -u $LOCKDIR/parentrol.lock

log "Finished."
