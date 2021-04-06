#!/usr/bin/node

"use strict"

const   Libbfa      =   require( process.env.BFAHOME + '/bin/libbfa.js');
const   BigInteger  =   require( 'big-integer' );
const   fs          =   require( 'fs' );
var     bfa         =   new Libbfa();
var     web3        =   bfa.newweb3();
// default
var     gasprice    =   BigInteger(10).pow(9);
// globals
var     accounts;
var     thecontract;

function cat(filename)
{
    try {
        return fs.readFileSync( filename ).toString();
    } catch (err) {
        throw( 'Errors: ' + err.syscall + ' ' + err.path + ': ' + err.code);
    }
}

function plural(num, one, many)
{
    if (num == 1)
        return one;
    return many;
}

function isittrue( thebool, errortext )
{
    return new Promise((resolve,reject) => {
        if ( undefined == thebool )
            reject( "thebool is undefined: " + errortext );
        else
        if ( thebool == true )
        {
            console.log( "Test OK: " + errortext );
            resolve();
        }
        else
            reject( errortext );
    })
}

function echo( txt )
{
    return new Promise((resolve,reject) => {
        console.log( txt );
        resolve();
    })
}

function getgasprice()
{
    return new Promise( (resolve, reject) => {
        web3.eth.getGasPrice()
        .then(
            (sat) => {
                gasprice        =   BigInteger(sat);
                resolve();
            },
            reject
        )
    })
}

function unlockall()
{
    return new Promise((resolve,reject) => {
        var     proms           =   new Array();
        accounts.forEach(
            (addr) => {
                proms.push(
                    web3.eth.personal.unlockAccount( addr, '', 600 )
                );
            }
        )
        Promise.all( proms )
        .then( resolve )
        .catch( reject );
    })
}

function gettestaccountnames()
{
    return new Promise( (resolve, reject) => {
        accounts        =   new Array();
        web3.bfa.personal.listWallets(
            ( walletlist ) => {
                walletlist.forEach(
                    ( wallet ) => {
                        wallet.accounts.forEach(
                            ( account ) => {
                                var addr    =   account.address;
                                if ( addr.startsWith('0x7e57') )
                                    accounts.push( addr );
                            }
                        )
                    }
                )
                accounts.sort();
                resolve();
            }
        );
    })
}

function getaccountbalances()
{
    return new Promise((resolve,reject) => {
        if ( accounts.length < 4 )
            throw( "Too few test accounts (found " + accounts.length + ", but need 4)." );
        var     proms       =   new Array();
        var     minimum     =   BigInteger(10).pow(9);
        var     failtxt;
        accounts.forEach(
            ( acct ) => {
                proms.push(
                    web3.eth.getBalance(acct)
                    .then(
                        ( bal ) => {
                            var     val     =   BigInteger( bal );
                            if ( val.lesser( minimum ) )
                            {
                                if ( undefined == failtxt )
                                    failtxt +=
                                        "The minimum balance on each test account must be at least "
                                        + minimum
                                        + " satoshi.\n"
                                failtxt +=
                                    "The account balance of "
                                    + accounts[i]
                                    + " is "
                                    + val
                                    + " satoshi.\n"
                            }
                        }
                    )
                )
            }
        );
        Promise.all( proms )
        .then(
            () => {
                if ( undefined == failtxt )
                    resolve();
                else
                    reject(
                        failtxt +
                        "Tests can not be performed without balance on the accounts."
                    );
            }
        );
    });
}

function councillistdetails()
{
    return new Promise((resolve,reject) => {
        thecontract.methods.councilLength.call()
        .then(
            (howmany) => {
                console.log(
                    'The council has '
                    + howmany
                    + ' member'
                    + plural(howmany,'','s')
                    + '.');
                return( howmany );
            }
        )
        .then(
            (howmany) => {
                var     proms   =   new Array();
                for ( var i=0 ; i<howmany ; i++ )
                    proms.push( thecontract.methods.council(i).call() );
                Promise.all( proms )
                .then( (addrlist) => {
                    addrlist.forEach( (addr)=>{console.log("Council member: "+addr)} );
                    resolve( howmany );
                });
            }
        );
    })
}

function voteslistdetails()
{
    return new Promise((resolve,reject) => {
        thecontract.methods.votesLength.call()
        .then(
            (howmany) => {
                console.log(
                    'There '
                    + plural(howmany,'is ','are ')
                    + howmany
                    + ' vote'
                    + plural(howmany,'','s')
                    + ' registered.');
                return( howmany );
            }
        )
        .then(
            (howmany) => {
                var     proms   =   new Array();
                for ( var i=0 ; i<howmany ; i++ )
                    proms.push( thecontract.methods.votes(i).call() );
                Promise.all( proms )
                .then( (list) => {
                    list.forEach( (obj)=>{
                        console.log(
                            'Lodged vote: '
                            + obj.voter
                            + ' has voted to '
                            + (obj.promotion?'promote':'demote')
                            + ' '
                            + obj.victim
                        );
                    } );
                    resolve( howmany );
                });
            }
        );
    })
}

function deploynew()
{
    return new Promise((resolve, reject) => {
        var     abi         =   JSON.parse( cat('Majority.abi').trim() );
        var     bin         =   cat('Majority.bin').trim();
        var     cAddress;
        var     fetus       =   new web3.eth.Contract( abi );
        console.log( "Deploying contract." );
        var     timeout     =   BigInteger( 86400 );
        fetus.deploy(
            {
                data:       '0x'+bin,
                arguments:  [ '0x'+timeout.toString(16) ]
            }
        )
        .send(
            {
                from:       accounts[0],
                gas:        3000000,
                gasPrice:   '0x'+gasprice.toString(16),
            }
        )
        .on( 'transactionHash', (hash) => {
            console.log( "Deployed in txhash " + hash + "." );
        })
        .on( 'confirmation', (num,obj) => {
            if ( undefined == cAddress )
            {
                cAddress    =   obj.contractAddress;
                thecontract =   new web3.eth.Contract( abi, cAddress );
                console.log( "Contract is at " + cAddress );
                resolve();
            }
        })
        .on( 'error', reject );
    });
}

function isCouncil( acctpos )
{
    return new Promise((resolve,reject) => {
        var     acct            =   accounts[acctpos];
        thecontract.methods.isCouncil(acct).call()
        .then(
            (yesno) => {
                var     not     =   'not ';
                if (yesno)
                    not         =   '';
                console.log( acct + ' is ' + not + 'a council member.' );
                resolve(yesno);
            }
        )
        .catch( reject )
    })
}

function vote( voterpos, victimpos, promotion )
{
    return new Promise((resolve,reject) => {
        var     voter           =   accounts[voterpos];
        var     victim          =   accounts[victimpos];
        var     confirmed       =   false;
        var     demote          =   'demote';
        if (promotion)
            demote      =   'promote';
        console.log( voter + " voting to " + demote + " " + victim );
        thecontract.methods.vote( victim, promotion ).send({
            from:       voter,
            gasPrice:   "0x"+gasprice.toString(16),
            gas:        '0x'+BigInteger(10).pow(6).toString(16)
        })
        .on( 'transactionHash', (txhash) => {
            console.log( ' - txhash ' + txhash );
        })
        .on( 'receipt', (rcpt) => {
            console.log( ' - got a receipt' );
        })
        .on( 'confirmation', (num,obj) => {
            if ( ! confirmed )
            {
                confirmed       =   true;
                resolve();
            }
        })
        .on( 'error', reject )
    })
}

function mayVote(voterpos, victimpos, promotion)
{
    return new Promise((resolve,reject) => {
        var     voter           =   accounts[voterpos];
        var     victim          =   accounts[victimpos];
        var     demote          =   'demote';
        if (promotion)
            demote      =   'promote';
        thecontract.methods.mayVote( voter, victim, promotion ).call()
        .then( (may) => {
                var not     =   'not ';
                if ( may )
                    not     =   '';
                console.log( voter + " may " + not + "vote to " + demote + " " + victim );
                resolve( may );
            },
            reject
        );
    })
}

getgasprice()
.then( gettestaccountnames )
.then( getaccountbalances )
.then( unlockall )
.then( deploynew )

// initial conditions after deploying the contract
.then( councillistdetails )
.then( (n)  => {return isittrue( n==1, "There should be 1 account in the council list." )})
.then( voteslistdetails )
.then( (n)  => {return isittrue( n==0, "There should be no entries in the list of registered votes." )})
.then( ()   => {return isCouncil(0)} )
.then( (b)  => {return isittrue( b, "Account should be a voter." )})
.then( ()   => {return isCouncil(1)} )
.then( (b)  => {return isittrue( !b, "Account should not be a voter." )})

// Adding second account to the council - takes effect immediately, so votes.length == 0
.then( ()   => {return mayVote(0,1,true)} )
.then( (b)  => {return isittrue( b, "Account should be allowed to vote for the approval of the new account." )})
.then( ()   => {return vote(0,1,true)} )
.then( voteslistdetails )
.then( (n)  => {return isittrue( n==0, "There should be no entries in the list of registered votes." )})
.then( councillistdetails )
.then( (n)  => {return isittrue( n==2, "There should be 2 accounts in the council list." )})
// Start voting to include third account
.then( ()   => {return mayVote(1,2,true)} )
.then( (b)  => {return isittrue( b, "Account should be allowed to vote for the approval of the new account." )})
.then( ()   => {return vote(1,2,true)} )
.then( voteslistdetails )
.then( (n)  => {return isittrue( n==1, "There should be 1 entry in the list of registered votes." )})
.then( councillistdetails )
.then( (n)  => {return isittrue( n==2, "There should be 2 accounts in the council list." )})
// Start voting to remove second account (using second account)
.then( ()   => {return mayVote(1,1,false)} )
.then( (b)  => {return isittrue( b, "Account should be allowed to vote for the removal of the account." )})
.then( ()   => {return vote(1,1,false)} )
.then( voteslistdetails )
.then( (n)  => {return isittrue( n==2, "There should be 2 entries in the list of registered votes." )})
.then( councillistdetails )
.then( (n)  => {return isittrue( n==2, "There should be 2 accounts in the council list." )})
// Finalizing vote to remove second account
.then( ()   => {return mayVote(0,1,false)} )
.then( (b)  => {return isittrue( b, "Account should be allowed to vote for the removal of the account." )})
.then( ()   => {return vote(0,1,false)} )
.then( voteslistdetails )
.then( (n)  => {return isittrue( n==0, "There should be no entries in the list of registered votes." )})
.then( councillistdetails )
.then( (n)  => {return isittrue( n==1, "There should be 1 account in the council list." )})
// Vote to remove 3rd account.
.then( ()   => {return mayVote(0,2,true)} )
.then( (b)  => {return isittrue( b, "Account should be allowed to vote for the approval of the new account." )})
.then( ()   => {return vote(0,2,true)} )
.then( voteslistdetails )
.then( (n)  => {return isittrue( n==0, "There should be no entries in the list of registered votes." )})
.then( councillistdetails )
.then( (n)  => {return isittrue( n==2, "There should be 1 account in the council list." )})

// this should self-destruct the contract
.then( ()   => {return vote(0,0,false)} )
.catch( (x) => {bfa.fatal("Test FAIL: " + x)})
.finally( ()   => {
    console.log('** All tests completed successfully **');
    process.exit();
});
