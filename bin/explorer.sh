#!/bin/bash
# 20180619 Robert Martin-Legene <robert@nic.ar>

if [ -z "${BFAHOME}" ]; then echo "\$BFAHOME not set. Did you source bfa/bin/env ?" >&2; exit 1; fi
source ${BFAHOME}/bin/libbfa.sh || exit 1

prereq tput curl
cd "${BFANETWORKDIR}"
width=$(	tput cols           )
height=$(	tput lines          )

function	showblock
{
        local hexblock
        if [ "$1" = "latest" ]
        then
            hexblock="latest"
        else
	    hexblock=$( printf '0x%x' $(( $1 )) )
        fi
        local json=$( geth_rpc eth_getBlockByNumber \"${hexblock}\" true )
        if [ "${_onscreen}" != "$( echo $json | jq .hash )" ]
        then
            hexblock=$( echo $json | jq -r .number )
	    printf '\e[H\e[JBlock %d (0x%x)\n' $(( $hexblock )) $(( $hexblock ))
            echo $json |
	        jq -C . |
	        fold --width=$width |
	        head -$(( $height - 2 ))
            _onscreen=$( echo $json | jq .hash )
	    printf '\e[mj=up k=down l=latest q=quit '
        fi
}

function    latest
{
    local json=$( geth_rpc eth_blockNumber )
    local num=$( echo "$json" | jq -r . )
    # This arithmetic expansion in bash converts a hex number prefixed with 0x to a decimal number
    echo $(( $num ))
}

function tm
{
    if [ "$block" = "latest" ]
    then
        timeout="-t 1"
    else
        timeout=
    fi
}


block=$1
maxblock=$( latest )
test -z "$block" &&
    block=latest
showblock $block
lastblock=
tm
while :
do
    read -r -s -n 1 ${timeout} || true
    maxblock=$( latest )
    case "${REPLY^^}" in
	Q)
	    echo
	    exit 0
            ;;
        K)
            if [ "$block" = "latest" -a $maxblock -gt 0 ]
            then
                block=$(( $maxblock - 1 ))
            else
                if [ $block -gt 0 ]
                then
		    block=$(( $block - 1 ))
                fi
            fi
            ;;
        J)
            if [ "$block" != "latest" ]
            then
		block=$(( $block + 1 ))
            fi
	    ;;
        L)
            block="latest"
            ;;
#        *)
#            continue
#            ;;
    esac
    lastblock=$block
    showblock $block
    tm
done
