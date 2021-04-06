#!/bin/bash

if [ -z "${BFAHOME}" ]; then echo "\$BFAHOME not set. Did you source bfa/bin/env ?" >&2; exit 1; fi
source ${BFAHOME}/bin/libbfa.sh || exit 1
test -e ${BFAHOME}/bin/env || cp -p ${BFANETWORKDIR}/env bin/env

enodeARIU="7ec4dd9d5e1a2b29d6b60aa9f95677c0c3a5f9306e73d65dd3bcbfda3737a8c509b02d1eab763ce39f18cfe96423df7ee544d6c36191ec17f59ade75bc99d358"
bootARIUv4="enode://${enodeARIU}@[170.210.45.179]:30301"
bootARIUv6="enode://${enodeARIU}@[2800:110:44:6300::aad2:2db3]:30301"

enodeUNC="82b66b13d7addcf9ffe1e4e972a105f6ccf50557161c4a0978a5d9ce595ababde609ea8a49897ae89b1d41e90551cb2e9241363238593e950ca68bd5af7c24d6"
bootUNCv4="enode://${enodeUNC}@[200.16.28.28]:30301"

enodeDGSI="ddbf37799e8d33b0c42dddbda713037b17d14696b29ecf424ca3d57bb47db78a467505e22c5f2b709a98c3d55ac8ecbf4610765385317dd51049438f498881c6"
bootDGSIv4="enode://${enodeDGSI}@[200.108.146.100]:30301"
bootnodes="${bootARIUv6},${bootARIUv4},${bootUNCv4},${bootDGSIv4}"

function getsyncmode
{
    local syncmode=$( cat "${BFANODEDIR}/syncmode" 2>/dev/null || true )
    syncmode=${syncmode:-full}
    echo "--syncmode ${syncmode}"
}

function startbootnode
{
    local   ERRTEXT="bootnode section failed"
    local   keyfile=${BFANETWORKDIR}/bootnode/key
    local   pidfile=${BFANETWORKDIR}/bootnode.pid
    which bootnode >/dev/null 2>&1  || return 0
    test -r $keyfile                || return 0
    (
        flock --nonblock --exclusive 9 || (
            echo "A bootnode is already running."
            false
        ) || exit
        if [ -t 1 ]
        then
            echo Starting bootnode.
        fi
        (
            echo ${BASHPID} > ${BFANETWORKDIR}/start-bootnode-loop.pid
            while :
            do
                echo
                echo '***'
                echo
                bootnode --nodekey $keyfile &
                echo $! > $pidfile
                wait
                sleep 60
            done
        ) 2>&1 | ${BFAHOME}/bin/log.sh ${BFANETWORKDIR}/bootnode/log &
    ) 9>> $pidfile
}

function startmonitor
{
    if [ -e "${BFANODEDIR}/opentx" ]
    then
        echo "Monitor uses functions which are disabled when running an opentx node, so monitor not started."
        return
    fi
    local   ERRTEXT="monitor section failed"
    local   pidfile=${BFANETWORKDIR}/monitor.pid
    (
        flock --nonblock --exclusive 9 || (
            echo "A monitor is already running."
            false
        ) || exit
        (
            echo ${BASHPID} > ${BFANETWORKDIR}/start-monitor-loop.pid
            while :
            do
                monitor.js &
                echo $! > $pidfile
                wait
                sleep 10
            done
        ) 2>&1 | ${BFAHOME}/bin/log.sh ${BFANODEDIR}/log &
    ) 9>> $pidfile
}

function geth_capab
{
    geth_version=$( geth --help | sed -n '/^VERSION:/{n;s/^ *//;s/-.*$//;p}' )
    # default to a dumb version
    test -n "${geth_version}" || geth_version=0.0.0
    v_major=${geth_version%%.*}
    tmp=${geth_version%.*}
    v_minor=${tmp#*.}
    v_patch=${geth_version##*.}
    unset tmp
    #
    # Determine capabilities
    # 0 legacy
    # 1 supports --allow-insecure-unlock
    cap=0
    if [ "${v_major}" -lt 1 ]
    then
        cap=0
    elif [ "${v_major}" -eq 1 ]
    then
        if [ "${v_minor}" -eq 8 ]
        then
                if [ "${v_patch}" -gt 28 ]
                then
                    cap=1
                fi
        elif [ "${v_minor}" -ge 9 ]
        then
            cap=1
        fi
    elif [ "${v_major}" -ge 2 ]
    then
        cap=1
    fi
    if [ ${cap} -ge 1 ]
    then
        flexargs="${flexargs} --allow-insecure-unlock"
    fi
}

function geth_args
{
    # (re)configure parameters (you never know if they changed)
    flexargs="$( getsyncmode )"
    geth_capab
    #
    # the basic modules
    local rpcapis="eth,net,web3,clique"
    if [ -e "${BFANODEDIR}/opentx" ]
    then
        local txhostnames dummy
        # If you want other hostnames, put them in this file (comma separated)
        read txhostnames dummy < ${BFANODEDIR}/opentx
        if [ "${txhostnames}" = "" ]
        then
            # but if you don't put any hostnames, these are the defaults
            txhostnames="localhost,opentx.bfa.ar"
        fi
        flexargs="${flexargs} --rpcvhosts ${txhostnames}"
        # INADDR_ANY - listen on all addresses
        flexargs="${flexargs} --rpcaddr 0.0.0.0"
        # Oh, and don't put your keys in / because we use that as a dummy directory
        flexargs="${flexargs} --keystore /"
    else
        # expose more modules, if we are a private node (localhost'ed)
        rpcapis="${rpcapis},admin,miner,personal"
    fi
    flexargs="${flexargs} --rpcapi ${rpcapis}"
}

function startgeth
{
    # Start the node.
    local   ERRTEXT="geth section failed"
    local   pidfile=${BFANETWORKDIR}/geth.pid
    which geth >/dev/null 2>&1        || return 0
    #
    (
        flock --nonblock --exclusive 9  || (
            echo "A geth is already running."
            false
        ) || exit 1
        if [ -t 1 ]
        then
            echo Starting geth
            echo Logging everything to ${BFANODEDIR}/log
            echo Consider running: bfalog.sh
        fi
        loop_counter=0
        (
            echo ${BASHPID} > ${BFANETWORKDIR}/start-geth-loop.pid
            while :
            do
                loop_counter=$(( ${loop_counter} + 1 ))
                ERRTEXT="geth"
                echo
                echo '***'
                echo "*** loop #${loop_counter}"
                echo '***'
                echo
                geth_args
                set -x
                geth			            \
	            --datadir ${BFANODEDIR}	            \
	            --networkid ${BFANETWORKID}         \
	            --rpc			            \
                    --gcmode archive                    \
	            ${flexargs}			    \
                    --rpccorsdomain \*                  \
	            --bootnodes "${bootnodes}"          &
                set +x
                echo $! > $pidfile
                rv=0
                wait -n || rv=$?
                sleep 60
            done
        ) 2>&1 | ${BFAHOME}/bin/log.sh ${BFANODEDIR}/log &
    ) 9>> $pidfile
}

startgeth
startbootnode
startmonitor
