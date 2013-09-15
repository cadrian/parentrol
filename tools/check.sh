#!/bin/bash

export DRY_RUN=${DRY_RUN:-true}
export ACTIVE=${ACTIVE:-true}
export TOOLSDIR=${TOOLSDIR:-$(dirname $(readlink -f $0))}
export ETCDIR=${ETCDIR:-$(dirname $(readlink -f $0))}

test -e $ETCDIR/defaults/parentrol && . $ETCDIR/defaults/parentrol

. $TOOLSDIR/_common.sh

$ACTIVE || {
    log "parentrol: not active"
    exit 0
}

test -d $ETCDIR/users.d || {
    log "parentrol: no users to watch"
    exit 0
}

pids=""
for userdef in $ETCDIR/users.d/*; do
    test -d $userdef && {
        user=$(basename $userdef)

        maxtime=$(cat_or_default $userdef/maxtime 3600)
        gracetime=$(cat_or_default $userdef/gracetime 5)
        starttime=$(cat_or_default $userdef/starttime 0)
        endtime=$(cat_or_default $userdef/endtime 3600)

        check_user $user $maxtime $gracetime $starttime $endtime &
        pids="$pids $!"
    }
done

wait $pids
