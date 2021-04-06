#!/bin/bash

trap "echo Argh; exit 1" ERR

true ${MAXSIZE:=$((10*1024*1024))}

log=$1
test -n "$log" ||
    log=log

exec >> "$log"
while read
do
    echo "$REPLY"
    size=$( stat -c '%s' "${log}" )
    if [ $size -ge $MAXSIZE ]
    then
        for gen in 8 7 6 5 4 3 2 1
        do
            test -e "${log}.${gen}" &&
                mv -f "${log}.${gen}" "${log}.$(( ${gen} + 1 ))"
        done
        mv -f "${log}" "${log}.1"
        exec >> "$log"
    fi
done
