# This should only be sourced, not executed directly.
# 20180626 Robert Martin-Legene <robert@nic.ar>

trap "echo Argh! ; exit 1" ERR
set -o errtrace

function    fatal()
{
    echo "$@" >&2
    exit 1
}

function    errtrap
{
    fatal "${ERRTEXT:-Argh!}"
}

trap errtrap ERR
test -n "$BASH_VERSION"		                                ||
    fatal "This file must be source(d) from bash."
test "$( caller 2>/dev/null | awk '{print $1}' )" != "0"	||
    fatal "This file must be source(d), not executed."

function    yesno
{
    local   defreply=${1,,}
    local   yn=Yn
    test "$defreply" = "n" &&
        yn=yN
    shift
    REPLY=
    read -p "$* [${yn}]: " -n 1 -e
    REPLY=${REPLY,,}
    if [ "$REPLY" != "y" -a "$REPLY" != "n" ]
    then
        REPLY=$defreply
    fi
}

function    cleanup
{
    if  [ $# -gt 0 ]
    then
        trap cleanup EXIT
        cleanup_files="${cleanup_files} $@"
        return
    fi
    rm  -rf $cleanup_files
}

function    geth_attach
{
    geth --cache 0 "$@" attach ipc:${BFANODEDIR}/geth.ipc
}

function    geth_exec_file
{
    test    -r "$1"
    geth_attach --exec "loadScript(\"$1\")" </dev/null
}

function    geth_exec
{
    test    -n "$1"
    geth_attach --exec "$1" </dev/null
}

function    geth_rpc
{
    local   params= connectstring= cmd=$1
    shift
    test    -n "$cmd"
    rpc_counter=$(( $rpc_counter + 1 ))
    if [ $# -gt 0 ]
    then
        params=',"params":['
        while [ $# -gt 0 ]
        do
            params="${params}${1},"
            shift
        done
        # Eat the last comma and add a ]
        params=${params/%,/]}
    fi
    if [ "$BFASOCKETTYPE" = "ipc" ]
    then
        connectstring="--unix-socket ${BFASOCKETURL}"
    else
        connectstring="${BFASOCKETURL}"
    fi
    local   json=$(
        curl                                        \
            -H 'Content-type: application/json'     \
            -X POST                                 \
            --data "{\"jsonrpc\":\"2.0\",\"method\":\"${cmd}\"${params},\"id\":${rpc_counter}}"  \
            ${connectstring}                        \
            2>/dev/null
        )
    test -n "$json"
    if [ "$( echo "$json" | jq .error )" != "null" ]
    then
        echo "$json" | jq -r .error.message >&2
        false
    fi
    echo "$json" | jq .result
}

function    create_account
{
    geth --cache 0 --datadir ${BFANODEDIR} --password /dev/null account new
}

function	prereq
{
	local err=0
	while [ -n "$1" ]
	do
		if !  which $1 > /dev/null
		then
			echo "Need $1"
			err=1
		fi
		shift
	done
	test $err -eq 0
}

function contract
{
    local   contract="${BFANETWORKDIR}/contracts/${1}"
    local   realdir=$(  realpath "${contract}"      )
    test    -r "${realdir}"
    local   address=$(  basename "${realdir}"       )
    test    -n "${address}"
    abi=$(              cat ${contract}/abi         )
    test    -n "${abi}"
    echo    "eth.contract(${abi}).at(\"${address}\")"
}

function contractSendTx
{
    local   name=$1
    local   func=$2
    shift   2
    echo    "var contract = $( contract "${name}" );"
    local   args=
    for x in $*
    do
        args="${args}, ${x}"
    done
    args="${args:1},"
    if [ "$args" = "," ]
    then
        args=
    fi
    echo    "contract.${func}.sendTransaction(${args} {from: eth.accounts[0], gas: 1000000} )"
}

function bfainit
{
    rpc_counter=0
    ###############
    #   bfainit   #
    test    -n "${BFAHOME}" -a  \
            -d "${BFAHOME}"         ||
        fatal   "\$BFAHOME in your environment must point to a directory."
    #
    # BFANETWORKID
    test    -n "${BFANETWORKID}"    ||  BFANETWORKID=47525974938
    export BFANETWORKID
    #
    # BFANETWORKDIR
    test    -n "${BFANETWORKDIR}"   ||  BFANETWORKDIR="${BFAHOME}/network"
    mkdir   -p "${BFANETWORKDIR}"
    test    -d "${BFANETWORKDIR}"   ||  fatal "\$BFANETWORKDIR (\"${BFANETWORKDIR}\") not found."
    export BFANETWORKDIR
    #
    # BFANODEDIR
    test    -n "$BFANODEDIR"        ||  BFANODEDIR="${BFANETWORKDIR}/node"
    export BFANODEDIR
    #
    # Default to IPC connections, because we have more geth modules available.
    export ${BFASOCKETTYPE:=ipc}
    case "${BFASOCKETTYPE}" in
        ipc)
            true ${BFASOCKETURL:="ipc:${BFANODEDIR}/geth.ipc"}
            ;;
        http)
            true ${BFASOCKETURL:="http://127.0.0.1:8545"}
            ;;
        ws)
            true ${BFASOCKETURL:="ws://127.0.0.1:8546"}
            ;;
        *)
            echo "Unknown socket type. Supported types are http, ws, ipc" >&2
            exit 1
    esac
    # Init the blockchain with the genesis block
    if [ ! -d "${BFANODEDIR}/geth/chaindata" ]
    then
        mkdir -p "${BFANODEDIR}"
        echo "Node is not initialised. Initialising with genesis."
        geth --networkid ${BFANETWORKID} --cache 0 --datadir "${BFANODEDIR}" init "${BFANETWORKDIR}/genesis.json"
    fi
}

if [ -z "$SOURCED_BFAINIT_SH" ]
then
    export SOURCED_BFAINIT_SH=yes
    bfainit
fi
