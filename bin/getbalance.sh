#!/bin/bash

if [ -z "${BFAHOME}" ]; then echo "\$BFAHOME not set. Did you source bfa/bin/env ?" >&2; exit 1; fi
source ${BFAHOME}/bin/libbfa.sh || exit 1

function usage
{
    fatal "Usage: $0 <addr> [...<addr>]"
}

prereq curl
test $# -ge 1 || usage

(
while [ -n "$1" ]
do
    echo "'$1'+' '+web3.fromWei(eth.getBalance('$1'), 'Ether');"
    shift
done
) | geth_attach
