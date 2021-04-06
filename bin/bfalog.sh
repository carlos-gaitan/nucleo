#!/bin/bash
# Robert Martin-Legene <robert@nic.ar>

if [ -z "${BFAHOME}" ]; then echo "\$BFAHOME not set. Did you source bfa/bin/env ?" >&2; exit 1; fi
source ${BFAHOME}/bin/libbfa.sh || exit 1

exec tail -n 100 -F ${BFANODEDIR}/log
