// vim:syntax:filetype=javascript:ai:sm
// vim:expandtab:backspace=indent,eol,start:softtabstop=4

// How many blocks to step back.
var     backstep    =   6
// If we are syncing, there's no need to rewind (I think?)
if (!eth.syncing && eth.blockNumber > 10)
{
    var     max     =   0
    // Get the maximum difficulty of all valid connected peers
    for (x in admin.peers)
    {
        var xd      =   admin.peers[x].protocols.eth.difficulty
        if (admin.peers[x].protocols.eth!="handshake" && xd>max)
            max=xd
    }
    if (eth.blockNumber.totalDifficulty+200<max) {
        console.log(
            "Max total difficulty is "
            + max
            + ", but mine is just "
            + eth.blockNumber.totalDifficulty
            + " (in block "
            + eth.blockNumber
            + "). Rolling "
            + backstep+" blocks back, to block "
            + web3.toHex(eth.blockNumber-backstep)
        )
        // Rollback a bit and see if we weren't stuck just because we were stuck in a side fork.
        debug.setHead(web3.toHex(eth.blockNumber-backstep))
    }
}
