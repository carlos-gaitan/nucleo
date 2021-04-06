#!/bin/bash
# Robert Martin-Legene <robert@nic.ar>
# 2019

# You can start this as root or not - as long as $BFAHOME is set, it
# should work.

trap "exit 1" ERR
set -o errtrace
if [ -z "${BFAHOME}" ]; then echo "\$BFAHOME not set. Did you source bfa/bin/env ?" >&2; exit 1; fi
source ${BFAHOME}/bin/libbfa.sh || exit 1


function runasownerof
{
    path=$1
    precmd=
    shift 1
    pushd $path > /dev/null
    if [ $( stat --format=%u $path ) -ne $UID ]
    then
        precmd="sudo -u $( stat --format=%U $path )"
    fi
    unset path
    ${precmd} "$@"
    rv=$?
    popd > /dev/null
    unset precmd
    return $rv
}

function aptinstall
{
    for pkg in $*
    do
        dpkg --verify $pkg 2>/dev/null ||
        (
            runasownerof / apt -y install $pkg
        )
    done
}

set -x
if [ "$1" = "" ]
then
    # Pulling may update this script itself.
    # We pull an updated repository, including an updated version of
    # ourself, and then we execute the updates "us"
    # This first part of the if is static. Changes (updates to this
    # script) goes after the 'else'
    #
    # To keep things neat, make sure we pull as the user owning the
    # directory.
    chown -R bfa:bfa ${BFAHOME}
    runasownerof ${BFAHOME} git pull
    exec $0 wealreadypulled
else
    # make sure bfa is in group sudo
    id bfa | grep -q sudo || runasownerof / adduser bfa sudo
    aptinstall libclass-accessor-perl
    # rebuild installed modules
    runasownerof ${BFAHOME} npm rebuild
    # install new ones (if any)
    runasownerof ${BFAHOME} npm install
    # delete stale pid files
    runasownerof ${BFAHOME} find ${BFAHOME} -name '*.pid' -delete
    set +x
    echo "*** Now would be a good time to restart the server."
fi
