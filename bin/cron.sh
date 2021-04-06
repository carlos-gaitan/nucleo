#!/bin/bash

trap 'exit 1' ERR
# Go to script bin, 'cause we expect to find $BFAHOME/bin/env there
cd `dirname $0`
test -e "env" || cp -p ../network/env env

source ./env
./start.sh < /dev/null >&0 2>&0
