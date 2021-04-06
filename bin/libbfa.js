// 20180724 Robert Martin-Legene <robert@nic.ar>

"use strict"

var     request                         =   require('request');
var     net                             =   require('net');

module.exports = class Libbfa
{
    constructor() {
        this.fs                         =   require('fs');
        this.Web3                       =   require('web3');
        //
        // BFAHOME
        if ( undefined == process.env.BFAHOME )
            fatal( "$BFAHOME not set. Did you source bfa/bin/env ?" );
        // BFANETWORKID
        this.home                       =   process.env.BFAHOME;
        if ( undefined == process.env.BFANETWORKID )
            process.env.BFANETWORKID    =   47525974938;
        this.networkid                  =   process.env.BFANETWORKID;
        // BFANETWORKDIR
        if ( undefined == process.env.BFANETWORKDIR )
            process.env.BFANETWORKDIR   =   process.env.BFAHOME + '/network';
        this.networkdir                 =   process.env.BFANETWORKDIR;
        // BFANODEDIR
        if ( undefined == process.env.BFANODEDIR )
            process.env.BFANODEDIR      =   this.networkdir + "/node";
        this.nodedir                    =   process.env.BFANODEDIR;
        // ACCOUNT
        if ( undefined == process.env.BFAACCOUNT )
        {
            var     files               =   new Array();
            if ( this.fs.existsSync( process.env.BFANODEDIR + '/keystore' ) )
            {
                this.fs.readdirSync(   process.env.BFANODEDIR + '/keystore' ).forEach( function(filename) {
                    if ( filename.includes('--') )
                        files.push( filename );
                });
            }
            // found any?
            if ( files.length > 0 )
            {
                files.sort();
                process.env.BFAACCOUNT  =   '0x' + files[0].replace( /^.*--/, '' );
            }
        }
        //
        this.account                    =   process.env.BFAACCOUNT;
        this.netport                    =   30303;
        this.rpcport                    =   8545;
        this.sockettype                 =   'ipc';
        this.socketurl                  =   'http://127.0.0.1:' + this.rpcport; // old
        this.socketurl                  =   this.nodedir+'/geth.ipc'; // overwrite with newer ipc method
        if ( this.sockettype == 'ipc' ) {
            this.provider               =   new this.Web3.providers.IpcProvider( this.nodedir+'/geth.ipc', net );
            this.req_url                =   'http://unix:' + this.nodedir + '/geth.ipc:/';
        } else if ( this.sockettype == 'ws' ) {
            this.provider               =   new this.Web3.providers.WebsocketProvider( this.socketurl );
            this.req_url                =   this.socketurl;
        } else if ( this.sockettype == 'http') {
            this.provider               =   new this.Web3.providers.HttpProvider( this.socketurl );
            this.req_url                =   this.socketurl;
        } else {
            fatal("Unknown sockettype.");
        }
    }

    contract(w3, name)
    {
        var     contractdir             =   [ this.networkdir, 'contracts', name ].join('/');
        if ( ! this.fs.existsSync( contractdir ) )
	    this.fatal( 'The directory containing this contract ("' + contractdir + '") does not exist.' );
        var     contractaddress         =   this.fs.realpathSync( contractdir ).replace(/^.*\//, '');
        if ( undefined == contractaddress )
	    this.fatal( 'Contract address for "' + name + '" not found.' );
        var     abistr                  =   this.fs.readFileSync( contractdir + '/abi' ).toString();
        if ( undefined == abistr )
	    this.fatal( 'ABI for contract "' + name + '" not found' );
        var     abi                     =   JSON.parse( abistr );
        if ( undefined == abi )
	    this.fatal( 'Failed to convert ABI for contract "' + name + '" into JSON.' );
        var     c                       =   new w3.eth.Contract( abi, contractaddress );
        c.abi                           =   abi;
        c.contractaddress               =   contractaddress;
        return  c;
    }

    fatal( txt )
    {
        console.error( txt );
        process.exit( 1 );
    }

    newweb3()
    {
        var     w3              =   new this.Web3( this.provider );
        var     req_url         =   this.req_url;
        var     _bfa            =   this;
        // This could just remain the same number all the time.
        var     unneededcounter =   1;
        w3.jsonify              =   function( opname, params )
        {
            var     obj         =   {};
            obj.id              =   unneededcounter++;
            obj.jsonrpc         =   "2.0";
            obj.method          =   opname;
            obj.params          =   params;
            return obj;
        };
        w3.rpcreq               =   function( opname, params, callback )
        {
            request.post({
                uri:            req_url,
                json:           true,
                body:           w3.jsonify( opname, params ),
                callback:       function RPCresponse( err, obj )
                {
               	    var		r;
               	    var		e;
                    if ( err )
                        e = err;
   		    else
                    if ( obj.body.error && obj.body.error.code && obj.body.error.message )
                    	e = 'Error ' + obj.body.error.code + ": "+ obj.body.error.message;
                    else
                    	r = obj.body.result;
                    callback(e, r);
                }
            });
        };
        w3.req                  =   function( opname, params, callback )
        {
            if ( _bfa.sockettype == 'ipc' )
            {
                w3.ipcreq( opname, params, callback );
            }
            else
            {
                w3.rpcreq( opname, params, callback );
            }
        }
        w3.ipcreq               =   function( opname, params, callback )
        {
            var     socket      =   net.connect( _bfa.socketurl );
            var     result;
            var     err;
            socket.on("ready", () => {
                // When the socket has been established.
                // We create a new connection per request, because it
                // is easier than reliably handling JSON object boundaries
                // in a TCP stream .
                // Writes out data and closes our end of the connection. 
                // Geth will reply and then close it's end.
                socket.end( JSON.stringify( w3.jsonify(opname,params).valueOf()));
            });
            socket.on("data", (d) => {
                try {
                    result      =   JSON.parse( d.toString() );
                }
                catch {
                    err         =   d.toString();
                }
            });
            socket.on("timeout", () => {
                socket.close();
            });
            socket.on("error", (e) => {
                console.error(e);
                err             =   e;
            });
            socket.on("close", () => {
                if ( result === undefined )
                    err         =   'Error undefined (close)'
                else
                if ( result.error && result.error.code && result.error.message )
                    err         =   'Error ' + result.error.code + ": "+ result.error.message;
                else
                    result      =   result.result;
                callback( err, result );
            });
        }
        w3.bfa                  =   {
            clique:             {
                getSigners:         function clique_getSigners( cb )
                                    {   w3.req( 'clique_getSigners',   [], cb ) },
            },
            miner:              {
                start:              function miner_start()
                                    {   w3.req( 'miner_start',         [], function(){} ) },
                stop:               function miner_stop()
                                    {   w3.req( 'miner_stop',          [], function(){} ) }
            },
            admin:              {
                peers:              function admin_peers( cb )
                                    {   w3.req( 'admin_peers',         [], cb ) },
                addPeer:            function admin_addPeer( peer )
                                    {   w3.req( 'admin_addPeer', [ peer ], function(){} ) }
            },
            personal:           {
                listWallets:        function personal_listWallets( cb )
                                    {   w3.req( 'personal_listWallets', [], cb ) }
            }
        };
        if ( undefined != process.env.BFAACCOUNT ) {
            w3.eth.defaultAccount  =   this.account;
        }
        return w3;
    }
    isNumeric(n) {
        return !isNaN(parseFloat(n)) && isFinite(n);
    }

    isAddr(n) {
        return n.length == 42 && n.substring(0,2) == "0x";
    }

    setfromfile( filename, defval )
    {
        if ( this.fs.existsSync( filename ) )
            return this.fs.readFileSync( filename );
        return defval;
    }
}
