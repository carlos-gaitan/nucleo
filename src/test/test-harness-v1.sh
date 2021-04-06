#!/bin/bash

true ${BFAHOME:=$( echo ~bfa/bfa )}
source ${BFAHOME}/bin/libbfa.sh || exit 1

function testfatal
{
    test -n "$1" && echo $*
    exit 1
}

function testcleanup
{
    for filename in ${keyfiles}
    do
        test -f "${filename}"
        rm "${filename}"
    done
}

function writetestkeysto
{
    local destinationdirectory=$1
    for i in {1..4}
    do
        case $i in
            1)
                set 7e5705d6e4fd660ad6d2d6533f3b4b6647dbb0a2 ac6c3c3e7351f858a3ffd9db00dc70b72a16e5ab0723be0a3da6da228778ce29 717f2930a84107df56fcb3308c116cfe 64fc98daae4a96777b8c08396a92bc8dde1117d439c7eb0b9a016a11e512dc0a 89e869cae11f4a9b3d1f8d684119a64d6c1b25451152b5fb413c531813f83b0d 0643d804-b9df-4df9-8819-d38463480f15
                ;;
            2)
                set 7e57105001438399e318753387b061993753a545 3d3f422c4c227a37db5728e72c91e43cbd391f7e338fe6aaeb68b65416b33b48 676cf0e07562c52f6c933de714c0506f 8e9869dc6aab090ff389ecc84815d0abc108f437d11c1d56a91c83277c77acd5 87237d3a481ab6a1c50b9ef07b24c0118644e7bf3b27170766ec6b860300890d ee0c6421-b0f1-41db-934e-3cab0c419875
                ;;
            3)
                set 7e57215a8af47c70baca431c45ecf14199f4bd9a 84c5a655cdd6a402ef88ea1f64a4c427ce3cdaec88f352c0194254095b8b71c4 80e54ea9307624e2d4ec7179f2fcfa3c 9aaeba47fbb5e7ba8d327a1a544712184424021db8e4d238f60bdba81f02a4ca 7ef19ab55611ea649b65de754fb68d5f810550fe9ccfcfd2f067d3e56b4aee04 4b1c00d1-292f-4610-bbc0-2bb4d6489ea4
                ;;
            4)
                set 7e57348aec1b1fd574ef2c0702acaa197c46d613 2d6e3b21ab6c69ad789703acc967f93955690626333c667bc34e48650bf95d59 fc98dd18e1292cb5c6578ecbbc29cbb3 75cc35ea980da5b70aa146ac02fa9c3fd9d0015cdda8b6737ba17ba95f24cd8a fcb3ed29dfe7ec444c929e880ecc822af894ee497de7e29484ecccfcd7187b8b 05d45b22-185e-49d4-bc91-9ab684e8e75a
                ;;
            *)
                false
                ;;
        esac
        local address=$1
        local ciphertext=$2
        local iv=$3
        local salt=$4
        local mac=$5
        local id=$6
        local cipherparams="{\"iv\":\"${iv}\"}"
        local kdfparams="{\"dklen\":32,\"n\":262144,\"p\":1,\"r\":8,\"salt\":\"${salt}\"}"
        local crypto="{\"cipher\":\"aes-128-ctr\",\"ciphertext\":\"${ciphertext}\",\"cipherparams\":${cipherparams},\"kdf\":\"scrypt\",\"kdfparams\":${kdfparams},\"mac\":\"${mac}\"}"
        local thisfilename="${destinationdirectory}/UTC--2018-12-24T12-00-00.000000000Z--${address}"
        echo "{\"address\":\"${address}\",\"crypto\":${crypto},\"id\":\"${id}\",\"version\":3}" > ${thisfilename}
        keyfiles="${keyfiles} ${thisfilename}"
    done
}

keyfiles=
trap testfatal ERR
trap testcleanup EXIT
contractname=$( ls -1 *.sol | head -1 | sed 's/\.sol$//' )
test -f ${contractname}.sol
test -r ${contractname}.sol
solc --combined-json abi,bin ${contractname}.sol > ${contractname}.json
jq -r ".contracts.\"${contractname}.sol:${contractname}\".abi" < ${contractname}.json > ${contractname}.abi
jq -r ".contracts.\"${contractname}.sol:${contractname}\".bin" < ${contractname}.json > ${contractname}.bin
rm ${contractname}.json
writetestkeysto ${BFANODEDIR}/keystore
for tester in ${contractname}-test*
do
    if [ -n "${tester}" -a -x "${tester}" -a -r "${tester}" ]
    then
        ./${tester}
    fi
done
