#!/bin/bash

export DRY_RUN=${DRY_RUN:-true}
export ACTIVE=${ACTIVE:-true}
export TOOLSDIR=${TOOLSDIR:-$(dirname $(readlink -f $0))}
export ETCDIR=${ETCDIR:-$(dirname $(readlink -f $0))}

test -e $ETCDIR/default/parentrol && . $ETCDIR/default/parentrol

. $TOOLSDIR/_common.sh

$ACTIVE || {
    log "Not active"
    exit 0
}

test -d $ETCDIR/parentrol/users.d || {
    log "No users to watch"
    exit 0
}

log "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
log "Starting parentrol checking session (NOW=$NOW)"

pids=""
for userdef in $ETCDIR/parentrol/users.d/*; do
    test -d $userdef && {
        user=$(basename $userdef)

        maxtime=$(cat_or_default $userdef/maxtime $((2 * 60)))
        gracetime=$(cat_or_default $userdef/gracetime 5)
        starttime=$(cat_or_default $userdef/starttime 0)
        endtime=$(cat_or_default $userdef/endtime $((24 * 60)))

        check_user $user $maxtime $gracetime $starttime $endtime &
        pids="$pids $!"
    }
done

wait $pids

log "Finished."
