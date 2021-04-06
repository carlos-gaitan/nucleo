#!/bin/bash

if [ -z "${BFAHOME}" ]; then echo "\$BFAHOME not set. Did you source bfa/bin/env ?" >&2; exit 1; fi
source ${BFAHOME}/bin/libbfa.sh || exit 1

function usage
{
    fatal "Usage: $0 <dest-addr> <amount-of-ether>"
}

test $# -eq 2 || usage

rcpt=$1
eth=$2

cat<<EOJS | geth_attach
eth.sendTransaction({from:eth.accounts[0], to: "${rcpt}", value: web3.toWei(${eth}, "ether")})
EOJS
