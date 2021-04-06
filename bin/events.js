#!/usr/bin/node
// 20200828 Robert Martin-Legene
// License: GPLv2-only
// (c) Secretaria Legal y Tecnica, Presidencia De La Nacion, Argentina

// Looks for the contract you're specifying as argument.
// Tries to show you all the events that contract has ever logged on the blockchain.
// The contract's ABI must be in a text file in ${BFANETWORKDIR}/contracts/${contractaddr}/abi

const Web3		= require( "web3" );
const fs		= require( "fs" );
const web3		= new Web3( "http://127.0.0.1:8545" );

function writeEvent(ev)
{
	console.log("");
	console.log( "Block number: " + ev.blockNumber );
	console.log( "TX hash: "      + ev.transactionHash );
	console.log( "Event name: "   + ev.event );
	Object.keys( ev.returnValues ).forEach(
		function writeEventValue( value )
		{
			// Will skip keys which are made entirely of digits.
			if ( ! value.match(/^[0-9]+$/) )
			{
				console.log( "* " + value + ": " + ev.returnValues[value] )
			}
		}
	);
}


function gotPastEvents( e, result )
{
	// We are called a single time.
	// Either success or failure.
	if ( e )
	{
		console.error( e );
		process.exit( 1 );
	}
	result.forEach( writeEvent );
	console.log( "\n" + result.length + " events." );
}

var	contractname	=	process.argv[2];
if ( contractname === undefined )
{
        console.error( "Usage: " + process.argv[1] + " <contractname|contractaddr>" );
        process.exit( 1 );
}
if ( process.env.BFANETWORKDIR === undefined ) 
{
	console.error( "$BFANETWORKDIR must be defined" );
	process.exit( 1 );
}
var	pathprefix	=	process.env.BFANETWORKDIR + "/contracts/";
var	filename;
if ( fs.existsSync( 		contractname ))
	filename	=	contractname;
else
if ( fs.existsSync( 		contractname.toLowerCase() ))
	filename	=	contractname.toLowerCase();
else
if ( fs.existsSync( 		pathprefix + contractname ))
	filename	=	pathprefix + contractname;
else
if ( fs.existsSync( 		pathprefix + contractname.toLowerCase() ))
	filename	=	pathprefix + contractname.toLowerCase();
if ( filename === undefined )
{
	console.error( "Contract not found." );
	process.exit( 1 );
}
var	contractaddr	=	filename;
var	dirname		=	"";
var	idx		=	filename.lastIndexOf("/");
if ( idx > -1 )
{
	dirname		=	filename.substr( 0, idx+1 );
	filename	=	filename.substr( idx+1    )
	contractaddr	=	filename;
}
var	stats		=	fs.lstatSync( dirname + filename );
if ( stats.isSymbolicLink() )
{
	let linkname	=	fs.readlinkSync( dirname + filename, { encoding: 'utf8' } );
	filename	=	dirname + linkname;
	contractaddr	=	linkname;
}
filename		+=	"/abi";
var	abi_str		=	fs.readFileSync( filename, { encoding: 'utf8' } );
var	abi		=	JSON.parse( abi_str );
var	contract	=	new web3.eth.Contract( abi, contractaddr );
console.log( "Address: "      + contractaddr );
contract.getPastEvents( "allEvents", { fromBlock: "earliest", toBlock: "latest" }, gotPastEvents);
