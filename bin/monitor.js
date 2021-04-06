#!/usr/bin/node
// vim:syntax:filetype=javascript:ai:sm
// vim:expandtab:backspace=indent,eol,start:softtabstop=4

"use strict"

const   Libbfa                  =   require( process.env.BFAHOME + '/bin/libbfa.js');
const   XMLHttpRequest          =   require("xmlhttprequest-ssl").XMLHttpRequest;
var     bfa                     =   new Libbfa();
var     web3                    =   bfa.newweb3();
var     lastUnlock              =   0;
var     netid                   =   0;
var     peerscache              =   bfa.networkdir + '/peers.cache';
if ( bfa.fs.existsSync( bfa.networkdir + '/cache' ) )
    peerscache                  =   bfa.networkdir + '/cache/peers.cache';

function    readPeersCache()
{
    if ( ! bfa.fs.existsSync(  peerscache ) )
        return [];
    var     data                =   bfa.fs.readFileSync( peerscache ).toString();
    var     p                   =   [];
    if ( data.length > 0 )
        p                       =   data.split(/\r?\n/);
    // for some odd reason, I keep seeing empty entries
    for ( var i = p.length; i > 0; i-- )
        if ( p[i] == '' )
            p.splice(i,1);
    return p;
}

function    writePeersCache( peers )
{
    // max 100 entries, FIFO
    if (peers.length > 100)
        peers.splice( 0, peers.length - 100 );
    // peers.cache is a list of peers we have connected out to in the past.
    var		txt		=	peers.join("\n");
    if (txt.length > 0 && (txt.substring(txt.length-1) != "\n"))
    	txt			+=	"\n";
    bfa.fs.writeFileSync( peerscache, txt, { mode: 0o644 } );
}

function    dnspeercachelookup()
{
    if ( netid == 0 )
        return;
    var     dnsquery            =   new XMLHttpRequest();
    // onreadystatechange is called when TCP things happen to the socket.
    // We set up the state before we send the query (such that they are
    // registered in the object)
    dnsquery.onreadystatechange = function() {
        // readyStates: 0=UNSENT, 1=OPEN, 2=SENT, 3=LOADING, 4=DONE
        if ( this.readyState == 4 )
        {
            if ( this.status == 200 ) {
                var     json    =   JSON.parse(this.responseText);
                if ( json.Status != 0 ) // 0 = NOERROR
                    return;
                var     i       =   Math.floor( Math.random() * json.Answer.length );
                if ( json.Answer[i].type != 16 ) // 16 = TXT
                    return;
                var     enode   =   json.Answer[i].data;
                // strip quotes
                if ( enode.substring(0,1) == '"' && enode.substring(enode.length-1) == '"' )
                    enode       =   enode.substring(1,enode.length-1);
                console.log(
                    "We have no peers, so will try to connect to "
                    + enode
                    + " found via DNS."
                );
                // Q: Can bad DNS data create a problem here?
                // A: Geth checks data input validity.
                web3.bfa.admin.addPeer( enode );
            }
        }
    };
    // Robert runs a private little cheat registry on his private domain
    // for fast update times. Can easily be moved to a hints.bfa.ar zone
    // if desired needed.
    // There are no new security aspects to consider, as this information
    // is public already via bootnodes.
    dnsquery.open( 'GET', 'https://cloudflare-dns.com/dns-query?name=hints.'+netid+'.bfa.martin-legene.dk&type=TXT' );
    dnsquery.setRequestHeader( 'accept', 'application/dns-json' );
    dnsquery.send();
}

function    writeStatus( peers )
{
    // write network/status
    bfa.fs.writeFileSync(
        bfa.networkdir + '/status', 
            "UTC: " + new Date().toUTCString() + "\n"
            + "BFA peers: " + peers.length + "\n"
            + peers.sort().join("\n") + "\n",
        { mode: 0o644 }
    );
}

function    parsenode( node )
{
    if ( !node || !node.protocols || typeof node.protocols.eth != 'object' )
        return;
    if ( ! node.network )
        return { info: "<"+node.id+">" };
    var     n                   =   {};
    if ( typeof node.network.inbound == 'boolean' )
	n.dir	                = 	node.network.inbound ? "in" : "out";
    if ( typeof node.enode == 'string' )
        n.info                  =   node.enode;
    else
    {
        if ( node.id )
            n.info              +=  "<" + node.id + ">";
        if ( node.network.remoteAddress )
        {
            if ( n.info )
                n.info          +=  "@";
            n.info              +=  node.network.remoteAddress;
        }
    }
    return n;
}

function gotAdminPeers( err, nodelist )
{
    var     nowpeers            =   [];
    var     peerscache          =   readPeersCache();
    var     newoutpeers         =   [];
    var     currentnodes        =   [];

    if ( err )
	return;
    // The nodelist also contains peers which are not yet validated
    // if they even belong to this network. Parsenode returns an
    // object or nothing, based on our criteria
    nodelist.forEach(
        function(node) {
            var n = parsenode(node);
            if ( n )
                currentnodes.push( n );
        }
    );
    currentnodes.forEach(
        function(n) {
            // Add to list of nowpeers (for stats file)
            nowpeers.push( "peer " + ( n.dir ? n.dir : '') + ": " + n.info );
            // See if this node reported by geth is already a known peers
            // from our peers.cache
            if (( peerscache.indexOf( n.info ) == -1 ) && ( n.dir == 'out' ))
                newoutpeers.push( n.info );
        }
    );
    writeStatus( nowpeers );
    writePeersCache( newoutpeers.concat(peerscache) );
    // Try to connect to a random node if we have very few peers
    if ( nowpeers.length < 5 )
    {
        var     candidate       =   [];
        // find candidate nodes which we can connect to
        // (it comes from peers.cache)
        peerscache.forEach(
            function(acachedpeer) {
                // Add "a cached peer" to "candidate" peers
                // if the cached peer is not in the list of currently
                // connected nodes.
                if ( ! currentnodes.includes( acachedpeer ) )
                {
                    candidate.push( acachedpeer );
                }
            }
        );
        if ( candidate.length > 0 )
        {
            var     i           =   Math.floor( Math.random() * candidate.length );
            var     enode       =   candidate[i];
            console.log(
                "We have "
                + nowpeers.length
                + " peer" + ( nowpeers.length==1 ? '' : 's' )
                + ", so will try to connect to "
                + enode
            );
            web3.bfa.admin.addPeer( enode );
        }
        else
            if ( nowpeers.length == 0 )
                dnspeercachelookup();
    }
}

function    peerlist()
{
    web3.bfa.admin.peers( gotAdminPeers );
}

function    mayseal()
// Function to determine if our defaultAccount is allowed to seal/mine.
// It will adjust the behaviour accordingly, i.e. stop or start mining.
{
    var me          =   web3.eth.defaultAccount;
    if ( undefined == me )
        // Failed to get default account information.
        me	    =	'xxxx'
    me              =   me.toLowerCase();
    web3.eth.isMining()
    .then(
        // returns a boolean whether or not we are currently mining/sealing.
        function( isMining )
        {
            // Get a list of clique.getSigners, so we can see if we are
            // in the list of authorized sealers.
            web3.bfa.clique.getSigners(
                function gotListOfSealers(e,x)
                {
		    if (e)
                    {
                        console.error( e );
                        return;
                    }
                    var lcsealers   =   x.map( name => name.toLowerCase() );
                    var isSigner    =   (lcsealers.indexOf(me) > -1);
                    if ( isSigner )
                    {
                        if ( ! isMining )
                        {
                            console.log( 'Started to seal.' );
                            web3.bfa.miner.start();
                        }
                    }
                    else
                    {
                        if ( isMining )
                        {
                            console.log( 'I was trying to seal, but am not authorized. Stopped trying.' );
                            web3.bfa.miner.stop();
                        }
                    }
                }
            );
        },
        function failedToGetIsMiningBool(x)
        {
            // Probably geth is not running.
            //throw new Error(x);
        }
    );
}

function    unlock()
{
    if ( lastUnlock + 600 > Date.now() / 1000 )
        return;
    var	    unlockedsomething	=   false;
    web3.bfa.personal.listWallets(
        function pushone(e,x)
        {
	    if (e) return;
            var     i           =   x.length;
            var     wallets     =   new Array();
            while ( i-- > 0 )
                if ( x[i].status == "Locked" )
                    wallets.push( x[i] );
            i                   =   wallets.length;
            if ( i == 0 )
                return;
            var     promises    =   new Array();
            while ( i-- > 0 )
            {
                var     j       =   wallets[i].accounts.length;
                while ( j-- > 0 )
                {
                    var addr    =   wallets[i].accounts[j].address;
                    var promise =
                        web3.eth.personal.unlockAccount( addr, "", 0 )
			.then(	x	=>    {
                            if ( x )
                            {
                                console.log( "Unlocked " + addr );
                            }
                        } )
                        .catch( error	=>    {} );
                    promises.push( promise );
                    unlockedsomething   =   true;
                }
            }
            Promise.all( promises )
            .then(
                function()
                {
                    if ( unlockedsomething )
                    {
                        web3.eth.isMining()
                        .then(
                            function()
                            {
    	                        web3.bfa.miner.stop();
    	                        mayseal();
                            }
                        )
                    }
                },
                function()
                {}
            );
        }
    );
    lastUnlock = Date.now() / 1000;
}

function    timer()
{
    if ( bfa.sockettype == 'ipc' && ! bfa.fs.existsSync( bfa.socketurl ) )
    {
        return;
    }
    if ( netid == 0 )
    {
        web3.eth.net.getId()
	.then( x => {
            netid = x;
        } )
	.catch( err => {
            console.log( "monitor.js waiting for geth to open socket." );
        });
        return;
    }
    peerlist();
    mayseal();
    unlock();
}

setTimeout(  timer,      5 * 1000   );
setInterval( timer,     60 * 1000   );
