#!/bin/bash

NODEJSPGP=0x68576280

# /root often does not have enough space, so we create a directory in /home
# for building, which we hope has more space.
NEW=/home/root/new

trap 'echo "The installation failed." >&2 ; exit 1' ERR
set -o errtrace
# Be verbose
set -e

if [ `id -u` -ne 0 ]
then
    echo "We are not root, but we need to be. Trying sudo now."
    exec sudo $0
fi

function    info
{
    echo
    echo '***'
    echo "*** $@"
    echo '***'
}

# Runs as the owner of the given directory, and in the given directory
function runasownerof
{
    local where=$1 precmd=
    shift 1
    pushd $where > /dev/null
    if [ $( stat --format=%u . ) -ne $UID ]
    then
        precmd="sudo --preserve-env --shell --set-home --user=$( stat --format=%U . ) PATH=${PATH}"
    fi
    ${precmd} "$@"
    local rv=$?
    popd > /dev/null
    return $rv
}

# For getting a recent nodejs
function nodejsinstall
{
    info nodejs
    # Nodejs software repository PGP key
    if [ `apt-key export ${NODEJSPGP} 2>&1 | wc -l` -le 50 ]
    then
        info "Adding nodejs software repository PGP key"
        apt-key adv --keyserver keyserver.ubuntu.com --recv ${NODEJSPGP}
    fi
    local file=/etc/apt/sources.list.d/nodesource.list
    if [ ! -r "$file" ]
    then
        info "Adding nodejs repository to apt sources."
        echo "deb https://deb.nodesource.com/node_10.x $(lsb_release -sc) main" > $file
        info "And now updating the software package list."
        apt update
    fi
    # nodejs also provides npm
    aptinstall nodejs
    info "Installing nodejs modules (will show many warnings)"
    runasownerof ${BFAHOME} npm install
    runasownerof ${BFAHOME} npm audit fix
}

function gethinstall
{
    install --verbose --owner=bfa --group=bfa --directory ${NEW}
    if [ -d ${NEW}/go-ethereum ]
    then
    	info "Running git pull to ensure that the local go-ethereum repo is up-to-date."
        runasownerof ${NEW}/go-ethereum git checkout master
        runasownerof ${NEW}/go-ethereum git pull
    else
    	info "Download geth source code."
        runasownerof ${NEW} git clone https://github.com/ethereum/go-ethereum
    fi
    runasownerof ${NEW}/go-ethereum git checkout ${geth_tag}
    chown -R bfa ${NEW}/go-ethereum
    info "Compiling geth tagged as ${geth_tag}"
    runasownerof ${NEW}/go-ethereum make all
    HISBINDIR=$( echo ~bfa/bin )
    install --verbose --owner=bfa --group=bfa --directory ${HISBINDIR}
    install --verbose --owner=bfa --group=bfa --target-directory=${HISBINDIR} ${NEW}/go-ethereum/build/bin/{geth,bootnode,abigen,ethkey,puppeth,rlpdump,wnode,swarm,swarm-smoke}
}

function initgenesis
{
    (
    	HOME=$( echo ~bfa )
        source ${BFAHOME}/bin/env
        BFANETWORKDIR=${BFANETWORKDIR:-${BFAHOME}/network}
        BFANODEDIR=${BFANODEDIR:-${BFANETWORKDIR}/node}
        if [ ! -d "${BFANODEDIR}" -o ! -d "${BFANODEDIR}/geth/chaindata" ]
        then 
            info "Node is not initialised. Initialising with genesis."
            runasownerof "${BFAHOME}" geth --networkid ${BFANETWORKID} --cache 0 --datadir "${BFANODEDIR}" init "${BFANETWORKDIR}/genesis.json"
            chown -R bfa:bfa ~bfa
        fi
    )
}

function aptinstall
{
    for pkg in $*
    do
        # consider apt install --install-suggests if you are masochist
        dpkg --verify $pkg 2>/dev/null ||
        (
            info "Installing $pkg"
            apt -y install $pkg
        )
    done
}

function usersetup
{
    if ! id bfa >/dev/null 2>&1
    then
        info "Adding required user \"bfa\""
        adduser --disabled-password --gecos 'Blockchain Federal Argentina' bfa
        info "Adding user \"bfa\" to group \"sudo\""
        adduser bfa sudo
    fi
    # If we're running inside a docker, this may already exist but
    # probably owned by root. Let's make sure things are proper.
    chown -R bfa:bfa ~bfa
    #
}

function userconfig
{
    if [ $( expand < ~bfa/.bashrc | grep -E "source ${BFAHOME}/bin/env" | wc -l ) -eq 0 ]
    then
        info "Adding to automatically source ${BFAHOME}/bin/env via .bashrc"
        echo "test -r ${BFAHOME}/bin/env && source ${BFAHOME}/bin/env" >> ~bfa/.bashrc
    fi
    # cloning if not done already, or just update (pull)
    if [ ! -d "${BFAHOME}" ]
    then
        # initial cloning
        runasownerof ${BFAHOME%/*} git clone https://gitlab.bfa.ar/blockchain/nucleo.git $BFAHOME
    else
        runasownerof "${BFAHOME}" git pull
    fi
    if [ ! -e "${BFAHOME}/bin/env" ]
    then
        cp -p ${BFAHOME}/$envfile ${BFAHOME}/bin/env
    fi
    PATH=${PATH}:${BFAHOME}/bin
    source ${BFAHOME}/lib/versions
}

function cronit
{
    if [ $( ( crontab -u bfa -l 2>/dev/null || true ) | grep -E "${BFAHOME#~bfa/}/bin/cron.sh" | wc -l ) -eq 0 ]
    then
        info "Install crontab to start automatically upon reboot"
        (( crontab -u bfa -l 2>/dev/null || true ) ; echo "@reboot ${BFAHOME#~bfa/}/bin/cron.sh" ) | crontab -u bfa -
    fi
}

function welcome
{
    info "(re)log in as user bfa"
}

function setupquestions
{
    if [ -t 0 ]
    then
        read -p "Donde quiere instalar (sera BFAHOME) [$( echo ~bfa/bfa )]? : " -t 300 BFAHOME
    fi
    if [ "$BFAHOME" = "" ]
    then
        BFAHOME=$( echo ~bfa/bfa )
    fi
    # Default to production
    envfile=network/env
    if [ ! -e "${BFAHOME}/bin/env" ]
    then
        REPLY=
        if [ -t 0 ]
        then
            while [ "$REPLY" != "1" -a "$REPLY" != "2" ]
            do
                echo "Quiere conectarse a la red BFA de produccion o prueba?"
                echo "1. Produccion"
                echo "2. Prueba (test2)"
                read -p "Red: " -t 60 -n 1
                echo
            done
        fi
        if [ "$REPLY" = "2" ]
        then
            envfile=test2network/env
        fi
    fi
}

usersetup
setupquestions
# Ubuntu necesita mas repos
grep -q Ubuntu /etc/issue && apt-add-repository multiverse
#
apt update
# development tools
aptinstall dirmngr apt-transport-https curl git curl build-essential sudo software-properties-common golang
aptinstall jq libjson-perl libwww-perl libclass-accessor-perl
userconfig
nodejsinstall
gethinstall
initgenesis
cronit
welcome
