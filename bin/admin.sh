#!/bin/bash
# Robert Martin-Legene <robert@nic.ar>

if [ -z "${BFAHOME}" ]; then echo "\$BFAHOME not set. Did you source bfa/bin/env ?" >&2; exit 1; fi
source ${BFAHOME}/bin/libbfa.sh || exit 1

defaultsyncmode="fast"

function modefilter
{
    case "$mode" in
        "full"|"fast"|"light")
            ;;
        *)
            echo "Unsupported mode."
            mode=""
            return
            ;;
    esac
    true
}

function    admin_syncmode
{
    echo "Available synchronization modes:"
    echo "  full : verify all blocks and all transactions since genesis (most secure)"
    echo "  fast : verify all blocks but not all transactions (faster than full, but less certain)"
    echo "  light: Makes this node into a light node which downloads almost"
    echo "         nothing, but relies on fast and full nodes in the network"
    echo "         to answer it's requests. This is the fastest and uses least"
    echo "         local resources, but outsources all trust to another node."
    echo "Default mode is fast, because for many, it is a healthy compromise"
    echo "between speed and paranoia. You can change the setting, according to"
    echo "your needs."

    mode=$( cat ${BFANODEDIR}/syncmode 2>/dev/null || true )
    mode=${mode:-${defaultsyncmode}}
    orgmode=$mode
    modefilter
    echo "Your current mode is set to ${mode}"
    killed=0
    mode=

    echo
    while [ -z "${mode}" ]
    do
        read -p "Which mode do you wish? : " mode
        modefilter
    done
    echo "Remembering your choice."
    echo $mode > ${BFANODEDIR}/syncmode
    if [ "$orgmode" = "fast" -a "$mode" = "full" ]
    then
        echo "You increased your paranoia level. The proper thing to do now,"
        echo "would be to delete your version of what you synchronized with"
        echo "fast mode, and revalidate everything in the entire blockchain."
        echo "This probably takes quite a long time and also requires downloading"
        echo "all blocks from the entire blockchain again."
        yesno n "Do you wish to delete all downloaded blocks and resynchronize?"
        if [ "$REPLY" = "y" ]
        then
            if [ -r "${BFANODEDIR}/geth.pid" ]
            then
                pid=$( cat ${BFANODEDIR}/geth.pid )
                kill -0 $pid 2>/dev/null &&
                    echo "Killing running geth." &&
                    killed=1
                while ! kill $pid 2>/dev/null
                do
                    sleep 1
                done
            fi
            rm -fr ${BFANODEDIR}/geth/chainstate ${BFANODEDIR}/geth/lightchainstate
            geth --cache 0 --datadir ${BFANODEDIR} init ${BFAHOME}/src/genesis.json
            test $killed -eq 1 &&
                echo &&
                echo "The startup.sh should restart your geth shortly."
        fi
    else
        echo "No further action taken."
    fi
}

function    admin_bootnode
{
    keyfile=${BFANETWORKDIR}/bootnode/key
    echo "Only very few wants to actually run a boot node."
    echo "If you have a keyfile for a bootnode, then you will"
    echo "automatically start one, when restarting your system."
    if [ -f $keyfile ]
    then
        echo "You are set up to run a boot node."
        echo "Deleting your bootnode keyfile disables your bootnode."
        yesno n "Do you want to delete your bootnode keyfile?"
        if [ "$REPLY" = "y" ]
        then
            rm $keyfile
        fi
        pidfile=${BFANETWORKDIR}/bootnode/pid
        if [ -r $pidfile ]
        then
            pid=`cat $pidfile`
            kill -0 $pid &&
            echo "Terminating your bootnode." &&
            kill `cat $pidfile` ||
            true
        fi
    else
        echo "You are not set up to run a boot node."
        yesno n "Do you want to create a keyfile for a bootnode?"
        if [ "$REPLY" = "y" ]
        then
            bootnode -genkey $keyfile
        fi
        echo "You can now start your bootnode by running start.sh"
    fi
}

function    create_account
{
    num=$( ls -1 ${BFANODEDIR}/keystore/*--* 2>/dev/null | wc -l )
    if [ $num -gt 0 ]
    then
        if [ $num -eq 1 ]
        then
            plural=""
        else
            plural="s"
        fi
        yesno n "You already have ${num} account${plural}. Do you wish to create an extra?"
        unset plural num
        if [ "$REPLY" = "n" ]
        then
            return
        fi
    fi
    unset num
    geth --cache 0 --datadir ${BFANODEDIR} --password /dev/null account new
}

case "$1" in
    bootnode)
        admin_bootnode
        ;;
    syncmode)
        admin_syncmode
        ;;
    account)
        create_account
        ;;
    *)
        echo Usage: `basename $0` "{bootnode|syncmode|account}"
        trap '' ERR
        exit 1
esac
