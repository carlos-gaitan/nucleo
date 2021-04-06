#!/usr/bin/node

const   Libbfa          =   require( process.env.BFAHOME + '/bin/libbfa.js');
const	bfa	        =   new Libbfa();
const   Writable        =   require('stream').Writable;
var     mutableStdout   =   new Writable(
    {
        write:          function( chunk, encoding, callback )
            {
                if ( ! this.muted )
                    process.stdout.write(chunk, encoding);
                callback();
            }
    } );
mutableStdout.muted     =   false;
const   rl              =   require('readline').createInterface(
    {
        input:          process.stdin,
        output:         mutableStdout,
        terminal:       true,
        historySize:    0
    } );
var	web3            =   bfa.newweb3();

// First time we try to unlock, we will use this empty passphrase.
// Do not edit.
var     passphrase  =   "";

function atLeastOneFailedSoGetNewPass(x)
{
    if ( !process.stdin.isTTY )
        bye( 0, "Stdin is not a tty. Will not try with other passwords." );
    // first we print the question
    mutableStdout.muted         =   false;
    rl.question(
        "Enter another password to try: ",
        (answer) => {
            process.stdout.write( "\n" );
            mutableStdout.muted =   false;
            passphrase          =   answer;
            if ( answer == "" )
                bye( 0, "Bye." );
            unlockall();
        }
    );
    // Asking the question is an async event, so
    // we set the object to mute output while the
    // user types his password.
    mutableStdout.muted         =   true;
}

function bye( exitcode, msg )
{
    console.log( msg );
    rl.close();
    process.exit( exitcode );
}

function unlockall()
{
    var     wallets             =   new Array();
    web3.bfa.personal.listWallets(
        function pushone(err,x)
        {
            if ( err )
                bye( 1, err );
            if ( x == undefined )
                bye( 1, "wallets not defined" );
            var     failures    =   0;
            var     promises    =   new Array();
            var     i           =   x.length;
            while ( i-- > 0 )
                if ( x[i].status == "Locked" )
                    wallets.push( x[i] );
            i                   =   wallets.length;
            if ( i == 0 )
                bye( 0, "List of accounts to unlock is empty." );
            while ( i-- > 0 )
            {
                var     j       =   wallets[i].accounts.length;
                while ( j-- > 0 )
                {
                    var addr    =   wallets[i].accounts[j].address;
                    //console.log( "Trying to unlock " + addr + "." );
                    var promise =
                        web3.eth.personal.unlockAccount( addr, passphrase, 0 )
                        .catch(
                            error =>
                            {
                                failures++;
                                return error;
                            }
                        );
                    promises.push( promise );
                }
            }
            var     empty       =   "";
            if ( passphrase == "" )
                empty           =   " with an empty passphrase";
            console.log(
                "Attempting to unlock "
                + promises.length
                + " account" + ( promises.length == 1 ? '' : 's' )
                + empty + "."
            );
            Promise.all( promises )
            .then(
                function(x)
                {
                    if ( failures == 0 )
                        bye( 0, "OK." );
                    console.log( failures + " account" + (failures==1 ? " is" : "s are") + " still locked." );
                    atLeastOneFailedSoGetNewPass();
                },
                function(x)
                {
                    console.log( x );
                    bye( 1, "I can't imagine this text will ever be shown." );
                }
            );
        },
        function errWalletList(x)
        {
            bye( 1, x );
        }
    )
}

unlockall();
